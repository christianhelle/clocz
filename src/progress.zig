const std = @import("std");
const results_mod = @import("results.zig");

pub const ProgressPrinter = struct {
    io: std.Io,
    results: *results_mod.Results,
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),

    pub fn loop(self: *ProgressPrinter) void {
        const stderr = std.Io.File.stderr();
        while (self.running.load(.acquire)) {
            _ = self.io.sleep(.fromNanoseconds(100 * std.time.ns_per_ms), .awake) catch {};
            if (!self.running.load(.acquire)) break;
            const n = self.results.files_scanned.load(.monotonic);
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "\rScanning... {d} files", .{n}) catch break;
            stderr.writeStreamingAll(self.io, msg) catch {};
        }
    }

    pub fn stop(self: *ProgressPrinter, thread: std.Thread) void {
        self.running.store(false, .release);
        thread.join();

        const n = self.results.files_scanned.load(.monotonic);
        var buf: [80]u8 = undefined;

        const msg = std.fmt.bufPrint(&buf, "\rScanned {d} files         \n", .{n}) catch "\n";
        std.Io.File.stderr().writeStreamingAll(self.io, msg) catch {};
    }
};
