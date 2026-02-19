const std = @import("std");
const results_mod = @import("results.zig");

pub const ProgressPrinter = struct {
    results: *results_mod.Results,
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),

    pub fn loop(self: *ProgressPrinter) void {
        const stderr = std.fs.File.stderr();
        while (self.running.load(.acquire)) {
            std.Thread.sleep(100 * std.time.ns_per_ms);
            if (!self.running.load(.acquire)) break;
            const n = self.results.files_scanned.load(.monotonic);
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "\rScanning... {d} files", .{n}) catch break;
            stderr.writeAll(msg) catch {};
        }
    }

    pub fn stop(self: *ProgressPrinter, thread: std.Thread) void {
        self.running.store(false, .release);
        thread.join();

        const n = self.results.files_scanned.load(.monotonic);
        var buf: [80]u8 = undefined;

        const msg = std.fmt.bufPrint(&buf, "\rScanned {d} files\n", .{n}) catch "\n";
        std.fs.File.stderr().writeAll(msg) catch {};
    }
};
