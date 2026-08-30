const std = @import("std");
const results_mod = @import("results.zig");

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
    \\      --report  Optionally set format: text, markdown, or html (default: text)
    \\  -v, --version Print version and exit
    \\
;

pub const CliOptions = struct {
    help: bool,
    report_format: results_mod.ReportFormat,
    report_requested: bool,
    version: bool,
};

pub fn parseReportFormat(arg: []const u8) ?results_mod.ReportFormat {
    if (std.mem.eql(u8, arg, "text")) return .text;
    if (std.mem.eql(u8, arg, "markdown")) return .markdown;
    if (std.mem.eql(u8, arg, "html")) return .html;
    return null;
}

pub fn show_help(io: std.Io) !void {
    try std.Io.File.stdout().writeStreamingAll(io, HELP);
}

pub fn show_version(io: std.Io) !void {
    var buf: [32]u8 = undefined;
    var fw = std.Io.File.stdout().writer(io, &buf);
    try fw.interface.print("clocz {s}\n", .{VERSION});
    try fw.interface.flush();
}

fn failParse(io: std.Io, comptime fmt: []const u8, args: anytype) noreturn {
    var buf: [512]u8 = undefined;
    var fw = std.Io.File.stderr().writer(io, &buf);
    fw.interface.print(fmt, args) catch {};
    fw.interface.writeAll("\n\n") catch {};
    fw.interface.writeAll(HELP) catch {};
    fw.interface.flush() catch {};
    std.process.exit(1);
}

pub const Cli = struct {
    options: CliOptions,
    path: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, args: []const [:0]const u8, io: std.Io) !Cli {
        var options = CliOptions{
            .help = false,
            .report_format = .text,
            .report_requested = false,
            .version = false,
        };

        var path: []const u8 = ".";

        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                options.help = true;
            } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                options.version = true;
            } else if (std.mem.eql(u8, arg, "--report")) {
                options.report_requested = true;
                if (i + 1 < args.len) {
                    const next_arg = args[i + 1];
                    if (parseReportFormat(next_arg)) |format| {
                        options.report_format = format;
                        i += 1;
                    } else {
                        options.report_format = .text;
                    }
                } else {
                    options.report_format = .text;
                }
            } else if (std.mem.startsWith(u8, arg, "--report=")) {
                options.report_requested = true;
                const value = arg["--report=".len..];
                options.report_format = parseReportFormat(value) orelse {
                    failParse(io, "Invalid value for --report: {s}. Expected one of: text, markdown, html", .{value});
                };
            } else if (arg.len > 0 and arg[0] != '-') {
                path = arg;
            } else {
                failParse(io, "Unknown option: {s}", .{arg});
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

test "report file is not requested by default" {
    const allocator = std.testing.allocator;
    const argv = [_][:0]const u8{"clocz"};

    const cli = try Cli.init(allocator, &argv, std.testing.io);
    defer cli.deinit();

    try std.testing.expect(!cli.options.report_requested);
}

test "parse report format values" {
    try std.testing.expectEqual(results_mod.ReportFormat.text, parseReportFormat("text").?);
    try std.testing.expectEqual(results_mod.ReportFormat.markdown, parseReportFormat("markdown").?);
    try std.testing.expectEqual(results_mod.ReportFormat.html, parseReportFormat("html").?);
    try std.testing.expect(parseReportFormat("pdf") == null);
}

test "bare --report defaults to text" {
    const allocator = std.testing.allocator;
    const argv = [_][:0]const u8{ "clocz", "--report" };

    const cli = try Cli.init(allocator, &argv, std.testing.io);
    defer cli.deinit();

    try std.testing.expectEqual(results_mod.ReportFormat.text, cli.options.report_format);
    try std.testing.expect(cli.options.report_requested);
}

test "--report followed by path keeps text format" {
    const allocator = std.testing.allocator;
    const argv = [_][:0]const u8{ "clocz", "--report", "src" };

    const cli = try Cli.init(allocator, &argv, std.testing.io);
    defer cli.deinit();

    try std.testing.expectEqual(results_mod.ReportFormat.text, cli.options.report_format);
    try std.testing.expectEqualStrings("src", cli.path);
}

test "--report followed by unknown option still errors later" {
    try std.testing.expect(parseReportFormat("--bogus") == null);
}
