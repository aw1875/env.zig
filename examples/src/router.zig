const std = @import("std");

const httpz = @import("httpz");

const Context = @import("context.zig");

const PublicRoutes = @import("routes/public.zig");
const AuthRoutes = @import("routes/auth.zig");

/// Setup all routes in a central location
pub fn setupRoutes(server: *httpz.Server(*Context)) !void {
    const router = try server.router(.{});

    PublicRoutes.createRouteGroup(router);
    AuthRoutes.createRouteGroup(router);
}
