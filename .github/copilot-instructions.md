# clocz – Copilot Instructions

`clocz` is a fast, multi-threaded "count lines of code" CLI tool written in Zig (minimum version 0.15.2). It has no external dependencies.

## Build, run, and test

```sh
zig build              # compile → zig-out/bin/clocz
zig build run          # build + run against current directory
zig build run -- path  # build + run against a specific path
zig build test         # run all tests
```

There is no per-file test runner; 
individual test blocks are inline in their source files. To iterate on a single module's tests, 
temporarily set `root_source_file` in the `test_exe` step in `build.zig` to that file (e.g. `src/counter.zig`), 
or just run `zig build test` — it's fast.

## Architecture

All source files live flat in `src/`. The data flow is:

```
main.zig  →  walker.zig  →  counter.zig
                  ↓               ↓
            results.zig  ←────────┘
                  ↑
           progress.zig (background thread → stderr)
```

| File | Responsibility |
|---|---|
| `main.zig` | CLI arg parsing; owns the `GeneralPurposeAllocator`, `Thread.Pool`, and `ProgressPrinter`; wires everything together |
| `walker.zig` | Recursive directory walk; dispatches one `Thread.Pool` job per file (`processFile`) |
| `counter.zig` | Single-pass line counter producing `Counts{files, blank, comment, code}`; binary detection via null-byte scan |
| `languages.zig` | Extension → `Language` mapping; `Language` carries comment-syntax markers |
| `results.zig` | Thread-safe `StringHashMap` accumulator (mutex-guarded `add()`); formatted table output sorted by code lines descending |
| `progress.zig` | Background thread that polls `files_scanned` (atomic u64) every 100 ms and writes `\rScanning... N files` to stderr |

## Key conventions

**Tests are inline.** Every `.zig` file that has logic contains `test` blocks directly in that file.
`main.zig` has a single `test "imports compile"` block that imports all other modules,
ensuring the test binary transitively covers all inline tests when `src/main.zig` is the test root.

**Ownership of `entry_path` transfers to the pool job.** In `walker.zig`,
the heap-allocated path string is freed by `processFile` via `defer ctx.allocator.free(ctx.path)`.
If `pool.spawn` fails, the caller frees it immediately — do not double-free.

**Thread-safety model:** `Results.add()` holds a mutex. 
`Results.files_scanned` is an atomic value and must only be updated with `.fetchAdd(..., .monotonic)` (no mutex needed).

**Language detection is linear and extension-based.** `languages.detect()` lowercases the file extension into a 32-byte stack buffer and walks the `entries` array. Data/config formats (JSON, YAML, TOML, INI, etc.) are intentionally commented out in `entries`; uncomment to enable them.

**Helper constructors for common comment styles:** Use `cStyle()`, `hashStyle()`, or `dashStyle()` when adding new languages to `languages.zig` rather than spelling out the full `Language` struct literal.

**Skipped directories:** `walker.zig` silently skips hidden entries (name starts with `.`) and the hard-coded names `node_modules` and `vendor`.

**Output buffering:** stdout output is buffered through a stack-allocated `[8192]u8` buffer passed to `std.fs.File.stdout().writer()`; always call `flush()` at the end of `Results.print()`.

**Source control:** Commit progress to git in small logical chunks with clear one-liner messages. Always create a branch for new features or bug fixes. Use descriptive commit messages that explain the "why" behind changes, not just the "what". For example, "Refactor counter to single-pass design for performance" is better than "Change counter logic". When working locally, do not change the committer to Copilot and do not add a Co-Author line — the commit history should reflect your work, not Copilot's suggestions.

