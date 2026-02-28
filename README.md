# env.zig

Type-safe environment variable loading for Zig. Define your schema once and get validated, typed access to environment variables across your entire app.

## Features

- Schema-driven — declare the variables your app needs as a struct
- Type coercion — strings, integers, and floats are parsed automatically
- Fail-fast — logs every missing variable and returns an error at startup
- `.env` file support in Debug builds

## Installation

```sh
zig fetch --save git+https://github.com/aw1875/env.zig
```

Then add the module in your `build.zig`:

```zig
const env = b.dependency("env", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("env", env.module("env"));
```

## Usage

Create a file in your project (e.g. `src/env.zig`) that defines your schema:

```zig
// src/env.zig
pub const env = @import("env").Env(struct {
    GOOGLE_CLIENT_ID: []const u8,
    GOOGLE_CLIENT_SECRET: []const u8,
    GOOGLE_CALLBACK_URL: []const u8,
    APP_PORT: u16,
});
```

Call `init` once at startup, typically in `main`:

```zig
// src/main.zig
const env = @import("env.zig").env;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer if (gpa.deinit() != .ok) @panic("Failed to deinitialize allocator");
    const allocator = gpa.allocator();

    try env.init(allocator);
    defer env.deinit(allocator);
}
```

Then access variables from anywhere in your app:

```zig
const env = @import("env.zig").env;

std.debug.print("{s}", .{env.vars.GOOGLE_CLIENT_ID});
```

If any required variables are missing at startup, each one is logged and `error.MissingEnvVar` is returned:

```
error(env.zig): Missing required environment variable: GOOGLE_CLIENT_SECRET ([]const u8)
error(env.zig): Missing required environment variable: APP_PORT (u16)
```

## Examples

See the [examples](./examples) directory for a full web server example using GitHub OAuth2 authentication.

## Supported types

| Zig type | Behavior |
|---|---|
| `[]const u8` | Copied from the environment as-is |
| `u8`, `i32`, `u16`, etc. | Parsed with `std.fmt.parseInt` |
| `f32`, `f64`, etc. | Parsed with `std.fmt.parseFloat` |

## `.env` files

In `Debug` builds, env.zig automatically loads a `.env` file from the current working directory before reading the process environment. The process environment always takes precedence.

```sh
# .env
GOOGLE_CLIENT_ID=my_client_id
GOOGLE_CLIENT_SECRET="my_client_secret"
APP_PORT=8080
```

Lines beginning with `#` and blank lines are ignored. Values may optionally be wrapped in double quotes.

The `.env` file is silently ignored if it does not exist.
