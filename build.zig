const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const search_mod = b.createModule(.{
        .root_source_file = b.path("src/search.zig"),
        .target = target,
        .optimize = optimize,
    });

    search_mod.linkSystemLibrary("objc", .{});
    search_mod.linkFramework("MapKit", .{});
    search_mod.linkFramework("Foundation", .{});

    const exe = b.addExecutable(.{
        .name = "nearme",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "search", .module = search_mod },
            },
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run nearme");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    run_step.dependOn(&run_cmd.step);
}
