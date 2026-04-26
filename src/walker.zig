const std = @import("std");
const languages = @import("languages.zig");
const counter = @import("counter.zig");
const results_mod = @import("results.zig");

/// Maximum file size we are willing to read into memory (128 MB).
const MAX_FILE_SIZE = 128 * 1024 * 1024;

const JobContext = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    limiter: *std.Io.Semaphore,
    /// Heap-allocated full path; ownership is transferred to the job.
    path: []const u8,
    results: *results_mod.Results,
};

fn processFile(ctx: JobContext) void {
    defer ctx.allocator.free(ctx.path);
    defer ctx.limiter.post(ctx.io);
    defer _ = ctx.results.files_scanned.fetchAdd(1, .monotonic);

    const lang = languages.detect(ctx.path) orelse return;

    const buf = std.Io.Dir.cwd().readFileAlloc(ctx.io, ctx.path, ctx.allocator, .limited(MAX_FILE_SIZE)) catch return;
    defer ctx.allocator.free(buf);

    if (counter.isBinary(buf)) return;

    const counts = counter.countLines(buf, lang);
    ctx.results.add(lang.name, counts);
}

fn walkDir(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    dir_path: []const u8,
    results: *results_mod.Results,
    limiter: *std.Io.Semaphore,
    threads: *std.ArrayList(std.Thread),
) !void {
    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
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
                var sub_dir = dir.openDir(io, entry.name, .{ .iterate = true, .follow_symlinks = false }) catch continue;
                defer sub_dir.close(io);
                try walkDir(allocator, io, sub_dir, entry_path, results, limiter, threads);
            },
            .file => {
                // Ownership of entry_path transfers to the job; the job frees it.
                limiter.waitUncancelable(io);
                const thread = std.Thread.spawn(.{}, processFile, .{JobContext{
                    .allocator = allocator,
                    .io = io,
                    .limiter = limiter,
                    .path = entry_path,
                    .results = results,
                }}) catch {
                    limiter.post(io);
                    allocator.free(entry_path);
                    continue;
                };
                errdefer thread.join();
                try threads.append(allocator, thread);
            },
            else => allocator.free(entry_path),
        }
    }
}

pub fn walk(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    results: *results_mod.Results,
) !void {
    var threads: std.ArrayList(std.Thread) = .empty;
    defer threads.deinit(allocator);
    defer for (threads.items) |thread| thread.join();

    var limiter: std.Io.Semaphore = .{ .permits = @max(std.Thread.getCpuCount() catch 1, 1) };
    var dir = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
    defer dir.close(io);
    try walkDir(allocator, io, dir, path, results, &limiter, &threads);
}
