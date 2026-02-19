const std = @import("std");
const walker = @import("walker.zig");
const results_mod = @import("results.zig");
const progress_mod = @import("progress.zig");

const VERSION = "0.1.0";
const HELP =
    \\Usage: clocz [options] [path]
    \\
    \\Count lines of code in a directory tree.
    \\
    \\Arguments:
    \\  path          Directory to scan (default: current directory)
    \\
    \\Options:
    \\  -h, --help    Print this help and exit
    \\  -v, --version Print version and exit
    \\
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var scan_path: []const u8 = ".";

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            try std.fs.File.stdout().writeAll(HELP);
            return;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
            var buf: [32]u8 = undefined;
            var fw = std.fs.File.stdout().writer(&buf);
            try fw.interface.print("clocz {s}\n", .{VERSION});
            try fw.interface.flush();
            return;
        } else if (arg.len > 0 and arg[0] != '-') {
            scan_path = arg;
        } else {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "Unknown option: {s}\n\n{s}", .{ arg, HELP });
            try std.fs.File.stderr().writeAll(msg);
            std.process.exit(1);
        }
    }

    var results = results_mod.Results.init(allocator);
    defer results.deinit();

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = allocator, .n_jobs = null });

    var progress = progress_mod.ProgressPrinter{ .results = &results };
    const progress_thread = try std.Thread.spawn(.{}, progress_mod.ProgressPrinter.loop, .{&progress});

    var timer = try std.time.Timer.start();

    walker.walk(allocator, scan_path, &results, &pool) catch |err| {
        progress.stop(progress_thread);
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "error: cannot open '{s}': {s}\n", .{ scan_path, @errorName(err) });
        std.fs.File.stderr().writeAll(msg) catch {};
        pool.deinit();
        std.process.exit(1);
    };

    pool.deinit();

    progress.stop(progress_thread);

    const elapsed_ns = timer.read();

    var out_buf: [8192]u8 = undefined;
    var fw = std.fs.File.stdout().writer(&out_buf);
    try results.print(&fw.interface, elapsed_ns);
}

test "imports compile" {
    _ = @import("languages.zig");
    _ = @import("counter.zig");
    _ = @import("results.zig");
    _ = @import("walker.zig");
    _ = @import("progress.zig");
}
