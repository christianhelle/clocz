const std = @import("std");
const languages = @import("languages.zig");
const counter = @import("counter.zig");
const results_mod = @import("results.zig");

/// Maximum file size we are willing to read into memory (128 MB).
const MAX_FILE_SIZE = 128 * 1024 * 1024;

const JobContext = struct {
    allocator: std.mem.Allocator,
    /// Heap-allocated full path; ownership is transferred to the job.
    path: []const u8,
    results: *results_mod.Results,
};

fn processFile(ctx: JobContext) void {
    defer ctx.allocator.free(ctx.path);
    defer _ = ctx.results.files_scanned.fetchAdd(1, .monotonic);

    const lang = languages.detect(ctx.path) orelse return;

    const file = std.fs.cwd().openFile(ctx.path, .{}) catch return;
    defer file.close();

    const buf = file.readToEndAlloc(ctx.allocator, MAX_FILE_SIZE) catch return;
    defer ctx.allocator.free(buf);

    if (counter.isBinary(buf)) return;

    const counts = counter.countLines(buf, lang);
    ctx.results.add(lang.name, counts);
}

fn walkDir(
    allocator: std.mem.Allocator,
    dir: std.fs.Dir,
    dir_path: []const u8,
    results: *results_mod.Results,
    pool: *std.Thread.Pool,
) !void {
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        // Skip hidden entries (e.g., .git, .DS_Store).
        if (entry.name.len > 0 and entry.name[0] == '.')
            continue;

        // Skip node modules and vendor directories, which can be huge and are unlikely to contain source code we want to count.
        if (std.mem.eql(u8, entry.name, "node_modules") or
            std.mem.eql(u8, entry.name, "vendor"))
            continue;

        const entry_path = try std.fs.path.join(allocator, &.{ dir_path, entry.name });

        switch (entry.kind) {
            .directory => {
                defer allocator.free(entry_path);
                var sub_dir = dir.openDir(entry.name, .{ .iterate = true, .no_follow = true }) catch continue;
                defer sub_dir.close();
                try walkDir(allocator, sub_dir, entry_path, results, pool);
            },
            .file => {
                // Ownership of entry_path transfers to the job; the job frees it.
                pool.spawn(processFile, .{JobContext{
                    .allocator = allocator,
                    .path = entry_path,
                    .results = results,
                }}) catch {
                    allocator.free(entry_path);
                };
            },
            else => allocator.free(entry_path),
        }
    }
}

pub fn walk(
    allocator: std.mem.Allocator,
    path: []const u8,
    results: *results_mod.Results,
    pool: *std.Thread.Pool,
) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();
    try walkDir(allocator, dir, path, results, pool);
}
