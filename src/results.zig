const std = @import("std");
const counter = @import("counter.zig");

pub const Results = struct {
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex = .{},
    map: std.StringHashMap(counter.Counts),
    files_scanned: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    pub fn init(allocator: std.mem.Allocator) Results {
        return .{
            .allocator = allocator,
            .map = std.StringHashMap(counter.Counts).init(allocator),
        };
    }

    pub fn deinit(self: *Results) void {
        self.map.deinit();
    }

    pub fn add(self: *Results, lang_name: []const u8, counts: counter.Counts) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const gop = self.map.getOrPut(lang_name) catch return;
        if (!gop.found_existing) {
            gop.value_ptr.* = counts;
        } else {
            gop.value_ptr.files += counts.files;
            gop.value_ptr.blank += counts.blank;
            gop.value_ptr.comment += counts.comment;
            gop.value_ptr.code += counts.code;
        }
    }

    const Row = struct { name: []const u8, counts: counter.Counts };

    pub fn print(self: *Results, w: *std.Io.Writer, elapsed_ns: u64) !void {
        var rows: std.ArrayList(Row) = .empty;
        defer rows.deinit(self.allocator);

        var total = counter.Counts{};
        var it = self.map.iterator();
        while (it.next()) |kv| {
            try rows.append(self.allocator, .{ .name = kv.key_ptr.*, .counts = kv.value_ptr.* });
            total.files += kv.value_ptr.files;
            total.blank += kv.value_ptr.blank;
            total.comment += kv.value_ptr.comment;
            total.code += kv.value_ptr.code;
        }

        std.mem.sort(Row, rows.items, {}, struct {
            fn lt(_: void, a: Row, b: Row) bool {
                return a.counts.code > b.counts.code;
            }
        }.lt);

        const sep = "-" ** 72;
        const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / 1e9;
        const files_per_s = if (elapsed_s > 0)
            @as(f64, @floatFromInt(total.files)) / elapsed_s
        else
            0;

        try w.print("{s}\n", .{sep});
        try w.print("{s:<30} {s:>8} {s:>8} {s:>10} {s:>10}\n", .{
            "Language", "files", "blank", "comment", "code",
        });
        try w.print("{s}\n", .{sep});

        for (rows.items) |row| {
            try w.print("{s:<30} {d:>8} {d:>8} {d:>10} {d:>10}\n", .{
                row.name,
                row.counts.files,
                row.counts.blank,
                row.counts.comment,
                row.counts.code,
            });
        }

        try w.print("{s}\n", .{sep});
        try w.print("{s:<30} {d:>8} {d:>8} {d:>10} {d:>10}\n", .{
            "SUM:", total.files, total.blank, total.comment, total.code,
        });
        try w.print("{s}\n", .{sep});
        try w.print("T={d:.2}s  ({d:.1} files/s)\n", .{ elapsed_s, files_per_s });
        try w.flush();
    }
};
