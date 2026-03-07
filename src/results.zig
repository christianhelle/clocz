const std = @import("std");
const counter = @import("counter.zig");

pub const ReportFormat = enum {
    text,
    markdown,
    html,
};

pub fn reportFileName(format: ReportFormat) []const u8 {
    return switch (format) {
        .text => "clocz.txt",
        .markdown => "clocz.md",
        .html => "clocz.html",
    };
}

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

    const Summary = struct {
        rows: []Row,
        total: counter.Counts,
        elapsed_s: f64,
        files_per_s: f64,
    };

    fn buildSummary(self: *Results, allocator: std.mem.Allocator, elapsed_ns: u64) !Summary {
        var rows: std.ArrayList(Row) = .empty;
        errdefer rows.deinit(allocator);

        var total = counter.Counts{};
        var it = self.map.iterator();
        while (it.next()) |kv| {
            try rows.append(allocator, .{ .name = kv.key_ptr.*, .counts = kv.value_ptr.* });
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

        const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / 1e9;
        const files_per_s = if (elapsed_s > 0)
            @as(f64, @floatFromInt(self.files_scanned.load(.unordered))) / elapsed_s
        else
            0;

        return .{
            .rows = try rows.toOwnedSlice(allocator),
            .total = total,
            .elapsed_s = elapsed_s,
            .files_per_s = files_per_s,
        };
    }

    fn freeSummary(self: *Results, summary: Summary) void {
        self.allocator.free(summary.rows);
    }

    fn writeTextReport(_: *Results, w: *std.Io.Writer, summary: Summary) !void {
        const sep = "-" ** 72;

        try w.print("{s}\n", .{sep});
        try w.print("{s:<30} {s:>8} {s:>8} {s:>10} {s:>10}\n", .{
            "Language", "files", "blank", "comment", "code",
        });
        try w.print("{s}\n", .{sep});

        for (summary.rows) |row| {
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
            "SUM:", summary.total.files, summary.total.blank, summary.total.comment, summary.total.code,
        });
        try w.print("{s}\n", .{sep});
        try w.print("Time={d:.2}s  ({d:.1} files/s)\n", .{ summary.elapsed_s, summary.files_per_s });
    }

    fn writeMarkdownReport(_: *Results, w: *std.Io.Writer, summary: Summary) !void {
        try w.writeAll("# clocz report\n\n");
        try w.writeAll("| Language | Files | Blank | Comment | Code |\n");
        try w.writeAll("| --- | ---: | ---: | ---: | ---: |\n");

        for (summary.rows) |row| {
            try w.print("| {s} | {d} | {d} | {d} | {d} |\n", .{
                row.name,
                row.counts.files,
                row.counts.blank,
                row.counts.comment,
                row.counts.code,
            });
        }

        try w.print("| **SUM** | **{d}** | **{d}** | **{d}** | **{d}** |\n\n", .{
            summary.total.files,
            summary.total.blank,
            summary.total.comment,
            summary.total.code,
        });
        try w.print("- Time: {d:.2}s\n- Throughput: {d:.1} files/s\n", .{ summary.elapsed_s, summary.files_per_s });
    }

    fn writeHtmlEscaped(w: *std.Io.Writer, text: []const u8) !void {
        for (text) |ch| {
            switch (ch) {
                '&' => try w.writeAll("&amp;"),
                '<' => try w.writeAll("&lt;"),
                '>' => try w.writeAll("&gt;"),
                '"' => try w.writeAll("&quot;"),
                '\'' => try w.writeAll("&#39;"),
                else => try w.writeByte(ch),
            }
        }
    }

    fn writeHtmlRow(w: *std.Io.Writer, label: []const u8, counts: counter.Counts, is_total: bool) !void {
        if (is_total) {
            try w.writeAll("        <tr class=\"total\"><th scope=\"row\">");
        } else {
            try w.writeAll("        <tr><th scope=\"row\">");
        }
        try writeHtmlEscaped(w, label);
        try w.print("</th><td>{d}</td><td>{d}</td><td>{d}</td><td>{d}</td></tr>\n", .{
            counts.files,
            counts.blank,
            counts.comment,
            counts.code,
        });
    }

    fn writeHtmlReport(_: *Results, w: *std.Io.Writer, summary: Summary) !void {
        try w.writeAll("<!DOCTYPE html>\n" ++
            "<html lang=\"en\">\n" ++
            "<head>\n" ++
            "    <meta charset=\"utf-8\">\n" ++
            "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" ++
            "    <title>clocz report</title>\n" ++
            "    <style>\n" ++
            "        :root { color-scheme: light; font-family: Georgia, \"Times New Roman\", serif; }\n" ++
            "        * { box-sizing: border-box; }\n" ++
            "        body { margin: 0; color: #1f2933; background: linear-gradient(180deg, #f4efe6 0%, #ffffff 45%, #eef3f8 100%); }\n" ++
            "        main { max-width: 960px; margin: 0 auto; padding: 48px 20px 64px; }\n" ++
            "        h1 { margin: 0 0 12px; font-size: clamp(2.2rem, 4vw, 3.6rem); letter-spacing: -0.04em; }\n" ++
            "        p { margin: 0; line-height: 1.6; }\n" ++
            "        .hero { padding: 28px; border-radius: 24px; background: rgba(255,255,255,0.82); box-shadow: 0 18px 60px rgba(31,41,51,0.12); backdrop-filter: blur(10px); }\n" ++
            "        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 14px; margin: 28px 0; }\n" ++
            "        .metric { padding: 18px 20px; border-radius: 18px; background: #fffaf2; border: 1px solid rgba(148, 163, 184, 0.25); }\n" ++
            "        .metric strong { display: block; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.08em; color: #52606d; }\n" ++
            "        .metric span { display: block; margin-top: 8px; font-size: 1.9rem; }\n" ++
            "        .table-wrap { overflow-x: auto; padding: 8px; border-radius: 24px; background: rgba(255,255,255,0.8); box-shadow: 0 18px 60px rgba(31,41,51,0.1); }\n" ++
            "        table { width: 100%; border-collapse: collapse; min-width: 640px; }\n" ++
            "        thead th { text-align: left; font-size: 0.82rem; text-transform: uppercase; letter-spacing: 0.08em; color: #52606d; }\n" ++
            "        th, td { padding: 14px 16px; border-bottom: 1px solid rgba(148, 163, 184, 0.22); }\n" ++
            "        tbody th { text-align: left; font-weight: 600; }\n" ++
            "        td { text-align: right; font-variant-numeric: tabular-nums; }\n" ++
            "        tbody tr:hover { background: rgba(255, 250, 242, 0.9); }\n" ++
            "        .total { background: #f0f7ff; }\n" ++
            "        .footer { margin-top: 18px; color: #52606d; font-size: 0.96rem; }\n" ++
            "        @media (max-width: 640px) { main { padding: 28px 14px 40px; } .hero, .table-wrap { border-radius: 18px; } .metric span { font-size: 1.6rem; } }\n" ++
            "    </style>\n" ++
            "</head>\n" ++
            "<body>\n" ++
            "    <main>\n" ++
            "        <section class=\"hero\">\n" ++
            "            <h1>clocz report</h1>\n" ++
            "            <p>Language totals sorted by code lines, exported directly from the command line.</p>\n" ++
            "            <div class=\"metrics\">\n");

        try w.print(
            "                <div class=\"metric\"><strong>Files</strong><span>{d}</span></div>\n" ++
                "                <div class=\"metric\"><strong>Blank</strong><span>{d}</span></div>\n" ++
                "                <div class=\"metric\"><strong>Comment</strong><span>{d}</span></div>\n" ++
                "                <div class=\"metric\"><strong>Code</strong><span>{d}</span></div>\n",
            .{ summary.total.files, summary.total.blank, summary.total.comment, summary.total.code },
        );

        try w.writeAll("            </div>\n" ++
            "        </section>\n" ++
            "        <section class=\"table-wrap\">\n" ++
            "            <table>\n" ++
            "                <thead>\n" ++
            "                    <tr><th>Language</th><th>Files</th><th>Blank</th><th>Comment</th><th>Code</th></tr>\n" ++
            "                </thead>\n" ++
            "                <tbody>\n");

        for (summary.rows) |row| {
            try writeHtmlRow(w, row.name, row.counts, false);
        }
        try writeHtmlRow(w, "SUM", summary.total, true);

        try w.print(
            "                </tbody>\n" ++
                "            </table>\n" ++
                "        </section>\n" ++
                "        <p class=\"footer\">Time: {d:.2}s &middot; Throughput: {d:.1} files/s</p>\n" ++
                "    </main>\n" ++
                "</body>\n" ++
                "</html>\n",
            .{ summary.elapsed_s, summary.files_per_s },
        );
    }

    fn render(self: *Results, w: *std.Io.Writer, format: ReportFormat, elapsed_ns: u64) !void {
        const summary = try self.buildSummary(self.allocator, elapsed_ns);
        defer self.freeSummary(summary);

        switch (format) {
            .text => try self.writeTextReport(w, summary),
            .markdown => try self.writeMarkdownReport(w, summary),
            .html => try self.writeHtmlReport(w, summary),
        }
        try w.flush();
    }

    pub fn print(self: *Results, w: *std.Io.Writer, elapsed_ns: u64) !void {
        try self.render(w, .text, elapsed_ns);
    }

    pub fn writeReportFile(self: *Results, dir: std.fs.Dir, format: ReportFormat, elapsed_ns: u64) !void {
        const file_name = reportFileName(format);
        var file = try dir.createFile(file_name, .{ .truncate = true });
        defer file.close();

        var out_buf: [8192]u8 = undefined;
        var fw = file.writer(&out_buf);
        try self.render(&fw.interface, format, elapsed_ns);
    }
};

fn renderResults(allocator: std.mem.Allocator, format: ReportFormat) ![]u8 {
    var results = Results.init(allocator);
    defer results.deinit();

    results.add("Zig", .{ .files = 2, .blank = 4, .comment = 3, .code = 40 });
    results.add("Markdown", .{ .files = 1, .blank = 2, .comment = 0, .code = 12 });
    results.files_scanned.store(3, .unordered);

    var aw = std.Io.Writer.Allocating.init(allocator);
    defer aw.deinit();

    try results.render(&aw.writer, format, std.time.ns_per_s * 2);
    return try aw.toOwnedSlice();
}

test "report file names match formats" {
    try std.testing.expectEqualStrings("clocz.txt", reportFileName(.text));
    try std.testing.expectEqualStrings("clocz.md", reportFileName(.markdown));
    try std.testing.expectEqualStrings("clocz.html", reportFileName(.html));
}

test "text report output includes totals and timing" {
    const allocator = std.testing.allocator;
    const output = try renderResults(allocator, .text);
    defer allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "Language") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "SUM:") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Time=2.00s") != null);
}

test "markdown report output uses table format" {
    const allocator = std.testing.allocator;
    const output = try renderResults(allocator, .markdown);
    defer allocator.free(output);

    try std.testing.expect(std.mem.startsWith(u8, output, "# clocz report\n\n"));
    try std.testing.expect(std.mem.indexOf(u8, output, "| Language | Files | Blank | Comment | Code |") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "| **SUM** | **3** | **6** | **3** | **52** |") != null);
}

test "html report output contains document structure" {
    const allocator = std.testing.allocator;
    const output = try renderResults(allocator, .html);
    defer allocator.free(output);

    try std.testing.expect(std.mem.startsWith(u8, output, "<!DOCTYPE html>"));
    try std.testing.expect(std.mem.indexOf(u8, output, "<title>clocz report</title>") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "<th scope=\"row\">SUM</th>") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "Throughput: 1.5 files/s") != null);
}

test "report file is written to disk in selected format" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var results = Results.init(allocator);
    defer results.deinit();

    results.add("Zig", .{ .files = 2, .blank = 4, .comment = 3, .code = 40 });
    try results.writeReportFile(tmp.dir, .markdown, std.time.ns_per_s * 2);

    const output = try tmp.dir.readFileAlloc(allocator, reportFileName(.markdown), 64 * 1024);
    defer allocator.free(output);

    try std.testing.expect(std.mem.startsWith(u8, output, "# clocz report\n\n"));
    try std.testing.expect(std.mem.indexOf(u8, output, "| Zig | 2 | 4 | 3 | 40 |") != null);
}
