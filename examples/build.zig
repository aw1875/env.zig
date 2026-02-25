const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "env_examples",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const env = b.dependency("env", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("env", env.module("env"));

    const httpz = b.dependency("httpz", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("httpz", httpz.module("httpz"));

    const oauth2 = b.dependency("oauth2", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("oauth2", oauth2.module("oauth2"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the example app");
    run_step.dependOn(&run_cmd.step);
}
