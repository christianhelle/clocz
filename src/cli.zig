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
    \\      --report  Export report as text, markdown, or html (default: text)
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
    report_format: results_mod.ReportFormat,
    version: bool,
};

pub fn parseReportFormat(arg: []const u8) ?results_mod.ReportFormat {
    if (std.mem.eql(u8, arg, "text")) return .text;
    if (std.mem.eql(u8, arg, "markdown")) return .markdown;
    if (std.mem.eql(u8, arg, "html")) return .html;
    return null;
}

fn failParse(comptime fmt: []const u8, args: anytype) noreturn {
    var buf: [512]u8 = undefined;
    var fw = std.fs.File.stderr().writer(&buf);
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

    pub fn init(allocator: std.mem.Allocator) !Cli {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        var options = CliOptions{
            .help = false,
            .report_format = .text,
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
                i += 1;
                if (i >= args.len) {
                    failParse("Missing value for --report. Expected one of: text, markdown, html", .{});
                }

                options.report_format = parseReportFormat(args[i]) orelse {
                    failParse("Invalid value for --report: {s}. Expected one of: text, markdown, html", .{args[i]});
                };
            } else if (std.mem.startsWith(u8, arg, "--report=")) {
                const value = arg["--report=".len..];
                options.report_format = parseReportFormat(value) orelse {
                    failParse("Invalid value for --report: {s}. Expected one of: text, markdown, html", .{value});
                };
            } else if (arg.len > 0 and arg[0] != '-') {
                path = arg;
            } else {
                failParse("Unknown option: {s}", .{arg});
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

test "parse report format values" {
    try std.testing.expectEqual(results_mod.ReportFormat.text, parseReportFormat("text").?);
    try std.testing.expectEqual(results_mod.ReportFormat.markdown, parseReportFormat("markdown").?);
    try std.testing.expectEqual(results_mod.ReportFormat.html, parseReportFormat("html").?);
    try std.testing.expect(parseReportFormat("pdf") == null);
}
