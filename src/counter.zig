const std = @import("std");
const languages = @import("languages.zig");

pub const Counts = struct {
    files: u64 = 0,
    blank: u64 = 0,
    comment: u64 = 0,
    code: u64 = 0,
};

/// Returns true if the buffer looks like a binary file (null byte in first 8KB).
pub fn isBinary(buf: []const u8) bool {
    const check = @min(buf.len, 8192);
    return std.mem.indexOfScalar(u8, buf[0..check], 0) != null;
}

/// Single-pass line counter. Counts blank, comment, and code lines.
/// Uses a heuristic: tracks block-comment state across lines.
pub fn countLines(buf: []const u8, lang: languages.Language) Counts {
    var counts = Counts{ .files = 1 };
    var in_block = false;

    // Strip a trailing newline so we don't count an extra blank line for it.
    const data = if (buf.len > 0 and buf[buf.len - 1] == '\n') buf[0 .. buf.len - 1] else buf;

    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |raw_line| {
        // Trim \r for Windows line endings and leading/trailing whitespace.
        const line = std.mem.trim(u8, raw_line, " \t\r");

        if (line.len == 0) {
            counts.blank += 1;
            continue;
        }

        // Inside a block comment.
        if (in_block) {
            counts.comment += 1;
            if (lang.block_comment_end) |bce| {
                if (std.mem.indexOf(u8, line, bce) != null) {
                    in_block = false;
                }
            }
            continue;
        }

        // Line starts a block comment.
        if (lang.block_comment_start) |bcs| {
            if (std.mem.startsWith(u8, line, bcs)) {
                counts.comment += 1;
                if (lang.block_comment_end) |bce| {
                    // Does the block comment also end on this line?
                    const after_open = line[@min(bcs.len, line.len)..];
                    if (std.mem.indexOf(u8, after_open, bce) == null) {
                        in_block = true;
                    }
                }
                continue;
            }
        }

        // Line starts with a single-line comment.
        if (lang.single_line_comment) |slc| {
            if (std.mem.startsWith(u8, line, slc)) {
                counts.comment += 1;
                continue;
            }
        }

        // It's a code line.
        counts.code += 1;

        // Check whether a block comment opens mid-line (e.g. `x = 1; /* start`).
        if (lang.block_comment_start) |bcs| {
            if (std.mem.indexOf(u8, line, bcs)) |bcs_pos| {
                if (lang.block_comment_end) |bce| {
                    const after_open = line[@min(bcs_pos + bcs.len, line.len)..];
                    if (std.mem.indexOf(u8, after_open, bce) == null) {
                        in_block = true;
                    }
                }
            }
        }
    }

    return counts;
}

test "blank lines" {
    const lang = languages.Language{ .name = "Test" };
    const buf = "\n   \n\t\n";
    const c = countLines(buf, lang);
    try std.testing.expectEqual(@as(u64, 3), c.blank);
    try std.testing.expectEqual(@as(u64, 0), c.code);
}

test "single-line comments" {
    const lang = languages.Language{ .name = "Test", .single_line_comment = "//" };
    const buf = "// comment\ncode\n// another\n";
    const c = countLines(buf, lang);
    try std.testing.expectEqual(@as(u64, 2), c.comment);
    try std.testing.expectEqual(@as(u64, 1), c.code);
}

test "block comments" {
    const lang = languages.Language{
        .name = "Test",
        .single_line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
    };
    const buf = "/* start\n middle\n end */\ncode\n";
    const c = countLines(buf, lang);
    try std.testing.expectEqual(@as(u64, 3), c.comment);
    try std.testing.expectEqual(@as(u64, 1), c.code);
}

test "isBinary detects null byte" {
    const buf = "hello\x00world";
    try std.testing.expect(isBinary(buf));
}

test "isBinary clean text" {
    const buf = "const x = 1;\n";
    try std.testing.expect(!isBinary(buf));
}
