const std = @import("std");
const cli_mod = @import("cli.zig");
const progress_mod = @import("progress.zig");
const results_mod = @import("results.zig");
const walker = @import("walker.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cli = try cli_mod.Cli.init(allocator);
    defer cli.deinit();

    if (cli.options.help) {
        try cli_mod.show_help();
        return;
    } else if (cli.options.version) {
        try cli_mod.show_version();
        return;
    }

    var results = results_mod.Results.init(allocator);
    defer results.deinit();

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = allocator, .n_jobs = null });

    var progress = progress_mod.ProgressPrinter{ .results = &results };
    const progress_thread = try std.Thread.spawn(.{}, progress_mod.ProgressPrinter.loop, .{&progress});

    var timer = try std.time.Timer.start();

    walker.walk(allocator, cli.path, &results, &pool) catch |err| {
        progress.stop(progress_thread);
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "error: cannot open '{s}': {s}\n", .{ cli.path, @errorName(err) });
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
