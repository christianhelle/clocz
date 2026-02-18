const std = @import("std");
const walker = @import("walker.zig");
const results_mod = @import("results.zig");

const VERSION = "0.1.0";

const HELP =
    \\Usage: zcloc [options] [path]
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

/// Background thread: prints a "Scanning… N files" status line to stderr every
/// 100 ms using \r so it overwrites itself in a real terminal.
const ProgressPrinter = struct {
    results: *results_mod.Results,
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),

    fn loop(self: *ProgressPrinter) void {
        const stderr = std.fs.File.stderr();
        while (self.running.load(.acquire)) {
            std.Thread.sleep(100 * std.time.ns_per_ms);
            // Re-check after sleep so we never print after stop() is called.
            if (!self.running.load(.acquire)) break;
            const n = self.results.files_scanned.load(.monotonic);
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "\rScanning... {d} files", .{n}) catch break;
            stderr.writeAll(msg) catch {};
        }
    }

    fn stop(self: *ProgressPrinter, thread: std.Thread) void {
        self.running.store(false, .release);
        thread.join();
        // Replace the progress line with a permanent summary (ends with \n so
        // the results table starts on a fresh line).
        const n = self.results.files_scanned.load(.monotonic);
        var buf: [80]u8 = undefined;
        // Trailing spaces overwrite any longer previous progress text.
        const msg = std.fmt.bufPrint(&buf, "\rScanned {d} files                    \n", .{n}) catch "\n";
        std.fs.File.stderr().writeAll(msg) catch {};
    }
};

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
            try fw.interface.print("zcloc {s}\n", .{VERSION});
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

    var progress = ProgressPrinter{ .results = &results };
    const progress_thread = try std.Thread.spawn(.{}, ProgressPrinter.loop, .{&progress});

    var timer = try std.time.Timer.start();

    walker.walk(allocator, scan_path, &results, &pool) catch |err| {
        progress.stop(progress_thread);
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "error: cannot open '{s}': {s}\n", .{ scan_path, @errorName(err) });
        std.fs.File.stderr().writeAll(msg) catch {};
        pool.deinit();
        std.process.exit(1);
    };

    // Wait for all file-processing jobs to complete.
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
}
