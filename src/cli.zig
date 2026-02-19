const std = @import("std");

const VERSION = "0.1.0";
const HELP =
    \\Usage: clocz [options] [path]
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

pub fn show_help() !void {
    try std.fs.File.stdout().writeAll(HELP);
}

pub fn show_version() !void {
    var buf: [32]u8 = undefined;
    var fw = std.fs.File.stdout().writer(&buf);
    try fw.interface.print("clocz {s}\n", .{VERSION});
    try fw.interface.flush();
}

pub const CliOptions = struct {
    help: bool,
    version: bool,
};

pub const Cli = struct {
    options: CliOptions,
    path: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Cli {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        var options = CliOptions{
            .help = false,
            .version = false,
        };

        var path: []const u8 = ".";

        for (args[1..]) |arg| {
            if (std.mem.startsWith(u8, arg, "-h") or std.mem.startsWith(u8, arg, "--help")) {
                options.help = true;
            } else if (std.mem.startsWith(u8, arg, "-v") or std.mem.startsWith(u8, arg, "--version")) {
                options.version = true;
            } else if (arg.len > 0 and arg[0] != '-') {
                path = arg;
            } else {
                var buf: [256]u8 = undefined;
                var fw = std.fs.File.stdout().writer(&buf);
                try fw.interface.print("Unknown option: {s}\n\n{s}", .{ arg, HELP });
                try fw.interface.flush();
                std.process.exit(1);
            }
        }

        return Cli{
            .allocator = allocator,
            .options = options,
            .path = try allocator.dupe(u8, path),
        };
    }

    pub fn deinit(self: Cli) void {
        self.allocator.free(self.path);
    }
};
