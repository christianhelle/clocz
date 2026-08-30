const std = @import("std");
const cli_mod = @import("cli.zig");
const progress_mod = @import("progress.zig");
const results_mod = @import("results.zig");
const walker = @import("walker.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    const cli = try cli_mod.Cli.init(allocator, args, io);
    defer cli.deinit();

    if (cli.options.help) {
        try cli_mod.show_help(io);
        return;
    } else if (cli.options.version) {
        try cli_mod.show_version(io);
        return;
    }

    var results = results_mod.Results.init(allocator, io);
    defer results.deinit();

    var progress = progress_mod.ProgressPrinter{ .io = io, .results = &results };
    const progress_thread = try std.Thread.spawn(.{}, progress_mod.ProgressPrinter.loop, .{&progress});

    const started = std.Io.Clock.Timestamp.now(io, .awake);

    walker.walk(allocator, io, cli.path, &results) catch |err| {
        progress.stop(progress_thread);
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "error: cannot open '{s}': {s}\n", .{ cli.path, @errorName(err) });
        std.Io.File.stderr().writeStreamingAll(io, msg) catch {};
        std.process.exit(1);
    };

    progress.stop(progress_thread);

    const elapsed_ns: u64 = @intCast(started.durationTo(std.Io.Clock.Timestamp.now(io, .awake)).raw.toNanoseconds());

    if (cli.options.report_requested) {
        results.writeReportFile(std.Io.Dir.cwd(), io, cli.options.report_format, elapsed_ns) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "warning: failed to write report file: {s}\n", .{@errorName(err)});
            std.Io.File.stderr().writeStreamingAll(io, msg) catch {};
        };
    }

    var out_buf: [8192]u8 = undefined;
    var fw = std.Io.File.stdout().writer(io, &out_buf);
    try results.print(&fw.interface, elapsed_ns);
}

test "imports compile" {
    _ = @import("cli.zig");
    _ = @import("languages.zig");
    _ = @import("counter.zig");
    _ = @import("results.zig");
    _ = @import("walker.zig");
    _ = @import("progress.zig");
}
