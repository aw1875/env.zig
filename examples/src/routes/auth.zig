const std = @import("std");

const httpz = @import("httpz");
const oauth2 = @import("oauth2");

const Context = @import("../context.zig");
const env = @import("../env.zig").env;

const OAuthProfile = struct {
    id: i64,
    login: []const u8,
    name: ?[]const u8,
    email: ?[]const u8,
    avatar_url: ?[]const u8,
};

pub fn createRouteGroup(router: *httpz.Router(*Context, *const fn (*Context, *httpz.Request, *httpz.Response) anyerror!void)) void {
    var auth_routes = router.group("/auth", .{});

    auth_routes.get("/github", handleLogin, .{});
    auth_routes.get("/github/callback", handleCallback, .{});
}

fn handleLogin(ctx: *Context, _: *httpz.Request, res: *httpz.Response) !void {
    const state = try oauth2.createStateNonce(res.arena);
    const url = try ctx.github_provider.createAuthorizationUrl(res.arena, state, &[_][]const u8{ "read:user", "user:email" });

    const session_id = try oauth2.createStateNonce(res.arena);

    // NOTE: in a production app, you'd want to use a more robust session management strategy, potentially with a proper database, redis, etc. This is just a simple in-memory store for demonstration purposes.
    try ctx.session_store.put(session_id, .{
        .state = state,
        .expiration = @intCast(std.time.milliTimestamp() + (60 * 5 * 1000)), // 5 minutes
    });

    try res.setCookie("github.sid", session_id, .{ .path = "/", .http_only = true, .max_age = 60 * 5 }); // 5 minutes

    res.headers.add("Location", url);
    res.setStatus(.found);
}

fn handleCallback(ctx: *Context, req: *httpz.Request, res: *httpz.Response) !void {
    const query = try req.query();

    if (query.get("error") != null) return error.OAuthError;

    const code = query.get("code") orelse return error.BadRequest;
    const state = query.get("state") orelse return error.BadRequest;
    const session_id = req.cookies().get("github.sid") orelse return error.BadRequest;
    const session_data = ctx.session_store.get(session_id) orelse return error.BadRequest;

    // Clear the session cookie
    try res.setCookie("github.sid", "", .{ .path = "/", .http_only = true, .max_age = 0 }); // Expire immediately

    if (std.time.milliTimestamp() > session_data.expiration or !std.mem.eql(u8, state, session_data.state)) return res.setStatus(.unauthorized);

    const tokens = try ctx.github_provider.validateAuthorizationCode(res.arena, code);

    const user_profile = try getUserProfile(res.arena, "https://api.github.com/user", tokens.access_token);
    defer user_profile.deinit(); // Free is technically not needed since we're using the response arena, but we'll do it for good measure

    return try res.json(
        .{
            .profile = user_profile.value,
            .special_message = env.vars.SPECIAL_MESSAGE,
        },
        .{},
    );
}

fn getUserProfile(allocator: std.mem.Allocator, url: []const u8, access_token: []const u8) !std.json.Parsed(OAuthProfile) {
    var http_client = std.http.Client{ .allocator = allocator };
    defer http_client.deinit();

    var body_writer: std.Io.Writer.Allocating = .init(allocator);
    defer body_writer.deinit();

    const response = try http_client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .headers = .{
            // NOTE: we're using allocPrint directly here without freeing because we're using the response arena, which will be freed after the request is handled. In a long-running context, you'd want to manage this memory more carefully.
            .authorization = .{ .override = try std.fmt.allocPrint(allocator, "Bearer {s}", .{access_token}) },
        },
        .extra_headers = &[_]std.http.Header{
            .{ .name = "User-Agent", .value = "env.zig" },
            .{ .name = "Accept", .value = "application/json" },
        },
        .response_writer = &body_writer.writer,
    });

    if (response.status != .ok) return error.HttpError;

    const body = try body_writer.toOwnedSlice();
    defer allocator.free(body);

    return try std.json.parseFromSlice(OAuthProfile, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
}
