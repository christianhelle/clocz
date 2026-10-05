const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "clocz",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    addAppIcon(b, exe);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
    const run_step = b.step("run", "Run clocz");
    run_step.dependOn(&run_cmd.step);

    const test_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tests = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const installer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/install.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(installer_tests).step);

    const installer = b.addExecutable(.{
        .name = "install",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/install.zig"),
            .target = b.graph.host,
        }),
    });
    addInstallStep(b, target, installer, "install-release", "Build ReleaseSmall and install to $HOME/.local/bin", .small);
    addInstallStep(b, target, installer, "install-release-safe", "Build ReleaseSafe and install to $HOME/.local/bin", .safe);
    addInstallStep(b, target, installer, "install-release-fast", "Build ReleaseFast and install to $HOME/.local/bin", .fast);
    addInstallStep(b, target, installer, "install-debug", "Build Debug and install to $HOME/.local/bin", .debug);
}

fn addInstallStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    installer: *std.Build.Step.Compile,
    step_name: []const u8,
    description: []const u8,
    optimize: std.lang.Optimize,
) void {
    const exe = b.addExecutable(.{
        .name = "clocz",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    addAppIcon(b, exe);
    const install = b.addRunArtifact(installer);
    install.addFileArg(exe.getEmittedBin());
    install.addArg(exe.out_filename);
    install.has_side_effects = true;
    const install_step = b.step(step_name, description);
    install_step.dependOn(&install.step);
}

fn addAppIcon(b: *std.Build, exe: *std.Build.Step.Compile) void {
    if (exe.rootModuleTarget().os.tag != .windows) return;
    exe.root_module.addWin32ResourceFile(.{ .file = b.path("assets/clocz.rc") });
}
