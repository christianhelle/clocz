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
