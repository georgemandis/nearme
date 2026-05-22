const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const search_mod = b.createModule(.{
        .root_source_file = b.path("src/search.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Cross-compilation SDK paths (e.g. -Dtarget=x86_64-macos on aarch64 host)
    const is_native = target.query.isNativeOs() and target.query.isNativeCpu();
    if (!is_native and target.result.os.tag == .macos) {
        const macos_sdk = b.option([]const u8, "macos-sdk", "Path to macOS SDK for cross-compilation");
        if (macos_sdk) |sdk| {
            search_mod.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/usr/lib", .{sdk}) });
            search_mod.addFrameworkPath(.{ .cwd_relative = b.fmt("{s}/System/Library/Frameworks", .{sdk}) });
        }
    }

    search_mod.linkSystemLibrary("objc", .{});
    search_mod.linkFramework("MapKit", .{});
    search_mod.linkFramework("Foundation", .{});

    const categories_mod = b.createModule(.{
        .root_source_file = b.path("src/categories.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "nearme",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "search", .module = search_mod },
                .{ .name = "categories", .module = categories_mod },
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
