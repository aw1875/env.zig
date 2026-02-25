const std = @import("std");

const httpz = @import("httpz");

const Context = @import("../context.zig");
const env = @import("../env.zig").env;

pub fn createRouteGroup(router: *httpz.Router(*Context, *const fn (*Context, *httpz.Request, *httpz.Response) anyerror!void)) void {
    var public_routes = router.group("/public", .{});

    public_routes.get("/hello", helloHandler, .{});
}

fn helloHandler(_: *Context, _: *httpz.Request, res: *httpz.Response) !void {
    res.body = env.vars.PUBLIC_MESSAGE;
    res.setStatus(.ok);
}
