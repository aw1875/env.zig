const std = @import("std");
const builtin = @import("builtin");

const log = std.log.scoped(.@"env.zig");

/// Creates a namespace for typed, validated environment variable access.
///
/// `T` is a struct where each field represents a required environment variable.
/// Field names must match the environment variable names exactly.
///
/// Supported field types:
/// - `[]const u8` — read as-is
/// - `int` types — parsed with `std.fmt.parseInt`
/// - `float` types — parsed with `std.fmt.parseFloat`
///
/// In Debug builds, variables are also loaded from a `.env` file in the
/// current working directory before the process environment is checked.
/// The process environment takes precedence.
///
/// Example:
/// ```zig
/// // env.zig
/// pub const env = Env(struct {
///   GOOGLE_CLIENT_ID: []const u8,
///   GOOGLE_CLIENT_SECRET: []const u8,
///   GOOGLE_CALLBACK_URL: []const u8,
///   APP_PORT: u16,
/// });
///
/// // In main:
/// const env = @import("env.zig").env;
///
/// try env.init(allocator);
/// defer env.deinit(allocator);
///
/// // Anywhere in the app (after importing env file):
/// std.debug.print("{s}", .{env.vars.GOOGLE_CLIENT_ID});
/// ```
pub fn Env(comptime T: type) type {
    return struct {
        /// The populated environment variables. Undefined until `init` is called.
        pub var vars: T = undefined;

        /// Loads and validates all environment variables defined in `T`.
        /// Must be called before accessing `vars`.
        /// Returns `error.MissingEnvVar` if any required variables are absent.
        pub fn init(allocator: std.mem.Allocator) !void {
            vars = try loadEnv(allocator);
        }

        /// Frees any heap-allocated fields in `vars` (i.e. `[]const u8` fields).
        /// Must be called with the same allocator passed to `init`.
        pub fn deinit(allocator: std.mem.Allocator) void {
            inline for (std.meta.fields(T)) |field| {
                switch (@typeInfo(field.type)) {
                    .pointer => {
                        const field_ptr = &@field(vars, field.name);
                        allocator.free(field_ptr.*);
                    },
                    else => {},
                }
            }
        }

        fn loadEnv(allocator: std.mem.Allocator) !T {
            var map = try std.process.getEnvMap(allocator);
            defer map.deinit();

            if (builtin.mode == .Debug) try mergeDotEnv(&map);

            return loadFromMap(allocator, &map);
        }

        fn loadFromMap(allocator: std.mem.Allocator, map: *std.process.EnvMap) !T {
            var missing_vars: std.ArrayList([]const u8) = .empty;
            defer missing_vars.deinit(allocator);

            inline for (std.meta.fields(T)) |field| {
                if (map.get(field.name) == null) {
                    try missing_vars.append(allocator, field.name);
                    log.err("Missing required environment variable: {s} ({s})", .{ field.name, @typeName(field.type) });
                }
            }

            if (missing_vars.items.len > 0) {
                return error.MissingEnvVar;
            }

            var result: T = undefined;
            inline for (std.meta.fields(T)) |field| {
                const raw = map.get(field.name).?; // We know it's present from the check above

                const value = switch (@typeInfo(field.type)) {
                    .int, .comptime_int => try std.fmt.parseInt(field.type, raw, 10),
                    .float, .comptime_float => try std.fmt.parseFloat(field.type, raw),
                    else => try allocator.dupe(u8, raw),
                };

                const field_ptr = &@field(result, field.name);
                field_ptr.* = value;
            }

            return result;
        }

        fn mergeDotEnv(map: *std.process.EnvMap) !void {
            var file = std.fs.cwd().openFile(".env", .{}) catch |err| switch (err) {
                error.FileNotFound => return, // It's fine if .env doesn't exist
                else => return err,
            };
            defer file.close();

            var buf: [1024]u8 = undefined;
            var reader = file.reader(&buf);

            while (try reader.interface.takeDelimiter('\n')) |line| {
                try parseLine(map, line);
            }
        }

        fn parseLine(map: *std.process.EnvMap, line: []const u8) !void {
            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0 or trimmed[0] == '#') return;

            var parts = std.mem.splitScalar(u8, trimmed, '=');
            try map.put(parts.first(), std.mem.trim(u8, parts.rest(), "\""));
        }
    };
}
