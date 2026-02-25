const std = @import("std");

const httpz = @import("httpz");
const oauth2 = @import("oauth2");

const Context = @import("context.zig");
const Router = @import("router.zig");
const env = @import("env.zig").env;

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer if (gpa.deinit() != .ok) @panic("Failed to deinitialize allocator");
    const allocator = gpa.allocator();

    try env.init(allocator);
    defer env.deinit(allocator);

    var github = try oauth2.GitHubProvider.init(allocator, .{
        .client_id = env.vars.GITHUB_CLIENT_ID,
        .client_secret = env.vars.GITHUB_CLIENT_SECRET,
        .redirect_uri = env.vars.GITHUB_CALLBACK_URL,
    });

    var ctx = Context{
        .github_provider = &github,
        .session_store = .init(allocator),
    };

    var server = try httpz.Server(*Context).init(
        allocator,
        .{
            .address = .localhost(env.vars.PORT),
        },
        &ctx,
    );
    defer {
        ctx.session_store.deinit();
        server.stop();
        server.deinit();
    }

    try Router.setupRoutes(&server);
    std.log.info("Starting server on port {d}", .{env.vars.PORT});
    try server.listen();
}
