//! Build helper that copies a compiled binary into the user's install directory.
//! Usage: install <source> <dest_name>
//! The destination directory is resolved from INSTALL_DIR, then HOME/.local/bin,
//! then USERPROFILE/.local/bin.

const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);
    if (args.len != 3) fatal("usage: install <source> <dest_name>", .{});

    const dest_dir = installDir(arena, init.environ_map) orelse
        fatal("unable to determine install directory: set HOME, USERPROFILE, or INSTALL_DIR", .{});
    const dest_path = try std.fs.path.join(arena, &.{ dest_dir, args[2] });

    const cwd = std.Io.Dir.cwd();
    _ = cwd.updateFile(io, args[1], cwd, dest_path, .{}) catch |err|
        fatal("failed to install {s} to {s}: {t}", .{ args[1], dest_path, err });

    std.log.info("installed {s}", .{dest_path});
}

fn installDir(arena: std.mem.Allocator, env: *const std.process.Environ.Map) ?[]const u8 {
    if (env.get("INSTALL_DIR")) |dir| {
        if (dir.len > 0) return dir;
    }
    for ([_][]const u8{ "HOME", "USERPROFILE" }) |name| {
        if (env.get(name)) |home| {
            if (home.len > 0) return std.fs.path.join(arena, &.{ home, ".local", "bin" }) catch @panic("OOM");
        }
    }
    return null;
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}

fn expectInstallDir(expected: ?[]const u8, vars: []const [2][]const u8) !void {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var env = std.process.Environ.Map.init(arena);
    for (vars) |kv| try env.put(kv[0], kv[1]);
    const actual = installDir(arena, &env);
    if (expected) |e| {
        try std.testing.expectEqualStrings(e, actual orelse return error.TestExpectedEqual);
    } else {
        try std.testing.expectEqual(@as(?[]const u8, null), actual);
    }
}

test "INSTALL_DIR takes precedence over HOME and USERPROFILE" {
    try expectInstallDir("/opt/bin", &.{ .{ "INSTALL_DIR", "/opt/bin" }, .{ "HOME", "/home/u" }, .{ "USERPROFILE", "/users/u" } });
}

test "empty INSTALL_DIR falls back to HOME" {
    const expected = try std.fs.path.join(std.testing.allocator, &.{ "/home/u", ".local", "bin" });
    defer std.testing.allocator.free(expected);
    try expectInstallDir(expected, &.{ .{ "INSTALL_DIR", "" }, .{ "HOME", "/home/u" } });
}

test "HOME takes precedence over USERPROFILE" {
    const expected = try std.fs.path.join(std.testing.allocator, &.{ "/home/u", ".local", "bin" });
    defer std.testing.allocator.free(expected);
    try expectInstallDir(expected, &.{ .{ "HOME", "/home/u" }, .{ "USERPROFILE", "/users/u" } });
}

test "empty HOME falls back to USERPROFILE" {
    const expected = try std.fs.path.join(std.testing.allocator, &.{ "/users/u", ".local", "bin" });
    defer std.testing.allocator.free(expected);
    try expectInstallDir(expected, &.{ .{ "HOME", "" }, .{ "USERPROFILE", "/users/u" } });
}

test "no usable variables yields null" {
    try expectInstallDir(null, &.{ .{ "INSTALL_DIR", "" }, .{ "HOME", "" } });
    try expectInstallDir(null, &.{});
}
