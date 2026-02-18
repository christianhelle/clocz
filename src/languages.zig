const std = @import("std");

pub const Language = struct {
    name: []const u8,
    single_line_comment: ?[]const u8 = null,
    block_comment_start: ?[]const u8 = null,
    block_comment_end: ?[]const u8 = null,
};

const Entry = struct {
    ext: []const u8,
    lang: Language,
};

fn cStyle(name: []const u8) Language {
    return .{ .name = name, .single_line_comment = "//", .block_comment_start = "/*", .block_comment_end = "*/" };
}

fn hashStyle(name: []const u8) Language {
    return .{ .name = name, .single_line_comment = "#" };
}

fn dashStyle(name: []const u8) Language {
    return .{ .name = name, .single_line_comment = "--" };
}

const entries = [_]Entry{
    // C family
    .{ .ext = "c",        .lang = cStyle("C") },
    .{ .ext = "h",        .lang = cStyle("C") },
    .{ .ext = "cpp",      .lang = cStyle("C++") },
    .{ .ext = "cc",       .lang = cStyle("C++") },
    .{ .ext = "cxx",      .lang = cStyle("C++") },
    .{ .ext = "hpp",      .lang = cStyle("C++") },
    .{ .ext = "hxx",      .lang = cStyle("C++") },
    .{ .ext = "cs",       .lang = cStyle("C#") },
    .{ .ext = "java",     .lang = cStyle("Java") },
    // Web
    .{ .ext = "js",       .lang = cStyle("JavaScript") },
    .{ .ext = "mjs",      .lang = cStyle("JavaScript") },
    .{ .ext = "cjs",      .lang = cStyle("JavaScript") },
    .{ .ext = "jsx",      .lang = cStyle("JSX") },
    .{ .ext = "ts",       .lang = cStyle("TypeScript") },
    .{ .ext = "mts",      .lang = cStyle("TypeScript") },
    .{ .ext = "cts",      .lang = cStyle("TypeScript") },
    .{ .ext = "tsx",      .lang = cStyle("TSX") },
    .{ .ext = "html",     .lang = .{ .name = "HTML", .block_comment_start = "<!--", .block_comment_end = "-->" } },
    .{ .ext = "htm",      .lang = .{ .name = "HTML", .block_comment_start = "<!--", .block_comment_end = "-->" } },
    .{ .ext = "xml",      .lang = .{ .name = "XML", .block_comment_start = "<!--", .block_comment_end = "-->" } },
    .{ .ext = "css",      .lang = .{ .name = "CSS", .block_comment_start = "/*", .block_comment_end = "*/" } },
    .{ .ext = "scss",     .lang = cStyle("SCSS") },
    .{ .ext = "sass",     .lang = .{ .name = "Sass", .single_line_comment = "//" } },
    .{ .ext = "less",     .lang = cStyle("Less") },
    .{ .ext = "svelte",   .lang = .{ .name = "Svelte", .single_line_comment = "//", .block_comment_start = "<!--", .block_comment_end = "-->" } },
    .{ .ext = "vue",      .lang = .{ .name = "Vue", .single_line_comment = "//", .block_comment_start = "<!--", .block_comment_end = "-->" } },
    // Systems
    .{ .ext = "zig",      .lang = cStyle("Zig") },
    .{ .ext = "rs",       .lang = cStyle("Rust") },
    .{ .ext = "go",       .lang = cStyle("Go") },
    .{ .ext = "swift",    .lang = cStyle("Swift") },
    .{ .ext = "d",        .lang = cStyle("D") },
    // JVM
    .{ .ext = "kt",       .lang = cStyle("Kotlin") },
    .{ .ext = "kts",      .lang = cStyle("Kotlin") },
    .{ .ext = "scala",    .lang = cStyle("Scala") },
    .{ .ext = "groovy",   .lang = cStyle("Groovy") },
    .{ .ext = "gradle",   .lang = cStyle("Groovy") },
    // Scripting
    .{ .ext = "py",       .lang = hashStyle("Python") },
    .{ .ext = "pyw",      .lang = hashStyle("Python") },
    .{ .ext = "rb",       .lang = hashStyle("Ruby") },
    .{ .ext = "rake",     .lang = hashStyle("Ruby") },
    .{ .ext = "sh",       .lang = hashStyle("Shell") },
    .{ .ext = "bash",     .lang = hashStyle("Shell") },
    .{ .ext = "zsh",      .lang = hashStyle("Shell") },
    .{ .ext = "fish",     .lang = hashStyle("Shell") },
    .{ .ext = "pl",       .lang = hashStyle("Perl") },
    .{ .ext = "pm",       .lang = hashStyle("Perl") },
    .{ .ext = "r",        .lang = hashStyle("R") },
    .{ .ext = "php",      .lang = cStyle("PHP") },
    .{ .ext = "lua",      .lang = .{ .name = "Lua", .single_line_comment = "--", .block_comment_start = "--[[", .block_comment_end = "]]" } },
    // Data / Config
    //.{ .ext = "json",     .lang = .{ .name = "JSON" } },
    //.{ .ext = "jsonc",    .lang = .{ .name = "JSON", .single_line_comment = "//" } },
    //.{ .ext = "yaml",     .lang = hashStyle("YAML") },
    //.{ .ext = "yml",      .lang = hashStyle("YAML") },
    //.{ .ext = "toml",     .lang = hashStyle("TOML") },
    //.{ .ext = "ini",      .lang = .{ .name = "INI", .single_line_comment = ";" } },
    //.{ .ext = "env",      .lang = hashStyle("Env") },
    // Markup / Docs
    .{ .ext = "md",       .lang = .{ .name = "Markdown" } },
    .{ .ext = "markdown", .lang = .{ .name = "Markdown" } },
    .{ .ext = "rst",      .lang = .{ .name = "reStructuredText" } },
    .{ .ext = "tex",      .lang = .{ .name = "LaTeX", .single_line_comment = "%" } },
    // Shell / DevOps
    .{ .ext = "ps1",      .lang = .{ .name = "PowerShell", .single_line_comment = "#", .block_comment_start = "<#", .block_comment_end = "#>" } },
    .{ .ext = "psm1",     .lang = .{ .name = "PowerShell", .single_line_comment = "#", .block_comment_start = "<#", .block_comment_end = "#>" } },
    .{ .ext = "psd1",     .lang = .{ .name = "PowerShell", .single_line_comment = "#", .block_comment_start = "<#", .block_comment_end = "#>" } },
    .{ .ext = "tf",       .lang = .{ .name = "Terraform", .single_line_comment = "#", .block_comment_start = "/*", .block_comment_end = "*/" } },
    .{ .ext = "tfvars",   .lang = hashStyle("Terraform") },
    .{ .ext = "dockerfile", .lang = hashStyle("Dockerfile") },
    // Database
    .{ .ext = "sql",      .lang = .{ .name = "SQL", .single_line_comment = "--", .block_comment_start = "/*", .block_comment_end = "*/" } },
    // Functional / Other
    .{ .ext = "dart",     .lang = cStyle("Dart") },
    .{ .ext = "ex",       .lang = hashStyle("Elixir") },
    .{ .ext = "exs",      .lang = hashStyle("Elixir") },
    .{ .ext = "erl",      .lang = .{ .name = "Erlang", .single_line_comment = "%" } },
    .{ .ext = "hrl",      .lang = .{ .name = "Erlang", .single_line_comment = "%" } },
    .{ .ext = "hs",       .lang = .{ .name = "Haskell", .single_line_comment = "--", .block_comment_start = "{-", .block_comment_end = "-}" } },
    .{ .ext = "ml",       .lang = .{ .name = "OCaml", .block_comment_start = "(*", .block_comment_end = "*)" } },
    .{ .ext = "mli",      .lang = .{ .name = "OCaml", .block_comment_start = "(*", .block_comment_end = "*)" } },
    .{ .ext = "clj",      .lang = .{ .name = "Clojure", .single_line_comment = ";" } },
    .{ .ext = "cljs",     .lang = .{ .name = "Clojure", .single_line_comment = ";" } },
    .{ .ext = "vim",      .lang = .{ .name = "Vim Script", .single_line_comment = "\"" } },
    .{ .ext = "f90",      .lang = .{ .name = "Fortran", .single_line_comment = "!" } },
    .{ .ext = "f95",      .lang = .{ .name = "Fortran", .single_line_comment = "!" } },
    .{ .ext = "f03",      .lang = .{ .name = "Fortran", .single_line_comment = "!" } },
    .{ .ext = "jl",       .lang = .{ .name = "Julia", .single_line_comment = "#", .block_comment_start = "#=", .block_comment_end = "=#" } },
    .{ .ext = "nim",      .lang = .{ .name = "Nim", .single_line_comment = "#" } },
    .{ .ext = "cr",       .lang = hashStyle("Crystal") },
    .{ .ext = "proto",    .lang = cStyle("Protobuf") },
    .{ .ext = "graphql",  .lang = .{ .name = "GraphQL", .single_line_comment = "#" } },
    .{ .ext = "gql",      .lang = .{ .name = "GraphQL", .single_line_comment = "#" } },
};

pub fn detect(path: []const u8) ?Language {
    const ext = std.fs.path.extension(path);
    if (ext.len <= 1) return null;
    const ext_no_dot = ext[1..];

    // Lowercase into a small stack buffer (extensions are short)
    var buf: [32]u8 = undefined;
    if (ext_no_dot.len > buf.len) return null;
    const ext_lower = std.ascii.lowerString(buf[0..ext_no_dot.len], ext_no_dot);

    for (entries) |entry| {
        if (std.mem.eql(u8, entry.ext, ext_lower)) return entry.lang;
    }
    return null;
}

test "detect zig" {
    const lang = detect("main.zig");
    try std.testing.expect(lang != null);
    try std.testing.expectEqualStrings("Zig", lang.?.name);
}

test "detect unknown" {
    try std.testing.expect(detect("main.xyz123") == null);
}
