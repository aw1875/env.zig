const std = @import("std");

const httpz = @import("httpz");
const oauth2 = @import("oauth2");

const SessionData = struct {
    state: []const u8,
    expiration: u64,
};

const Context = @This();

github_provider: *oauth2.GitHubProvider,
session_store: std.StringHashMap(SessionData),

pub fn uncaughtError(_: *Context, _: *httpz.Request, res: *httpz.Response, e: anyerror) void {
    std.log.err("Error: {s}", .{@errorName(e)});

    res.setStatus(.internal_server_error);
    res.body = @errorName(e);
}
