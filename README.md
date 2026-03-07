# clocz

`clocz` is a fast, multi-threaded command-line tool for counting lines of code, written in [Zig](https://ziglang.org/). It scans a directory tree, groups files by language, and reports file, blank, comment, and code totals in formats that work well in terminals, documentation, and shared artifacts.

[![CI](https://github.com/christianhelle/clocz/actions/workflows/ci.yml/badge.svg)](https://github.com/christianhelle/clocz/actions/workflows/ci.yml)
[![Release](https://github.com/christianhelle/clocz/actions/workflows/release.yml/badge.svg)](https://github.com/christianhelle/clocz/actions/workflows/release.yml)

## Features

- Counts code, comment, and blank lines per language
- Multi-threaded directory scanning via Zig's `Thread.Pool`
- Supports 60+ languages out of the box
- Exports reports as text, markdown, or standalone HTML
- Zero external dependencies
- Single static binary - no runtime needed
- Cross-platform: Linux, macOS, Windows

## Installation

### Install script (Linux / macOS)

```sh
curl -fsSL https://raw.githubusercontent.com/christianhelle/clocz/main/install.sh | bash
```

### Install script (Windows PowerShell)

```powershell
irm https://raw.githubusercontent.com/christianhelle/clocz/main/install.ps1 | iex
```

### Snap

```sh
sudo snap install clocz
```

### Download from GitHub Releases

Pre-built binaries for Linux (x86_64, aarch64), macOS (x86_64, aarch64), and Windows (x86_64) are available on the [Releases](https://github.com/christianhelle/clocz/releases) page.

### Build from source

Requires [Zig 0.15.2+](https://ziglang.org/download/):

```sh
zig build -Doptimize=ReleaseFast
```

The binary is at `zig-out/bin/clocz`.

## Usage

```sh
# Count lines in the current directory
clocz

# Count lines in a specific directory
clocz /path/to/project

# Export a markdown report
clocz --report markdown /path/to/project > report.md

# Export a standalone HTML report
clocz --report html /path/to/project > report.html
```

### Example text report

```text
------------------------------------------------------------------------
Language                          files    blank    comment       code
------------------------------------------------------------------------
Zig                                   6       45         22        340
Markdown                              1        8          0         30
------------------------------------------------------------------------
SUM:                                  7       53         22        370
------------------------------------------------------------------------
Time=0.01s  (700.0 files/s)
```

### Example markdown report

```md
# clocz report

| Language | Files | Blank | Comment | Code |
| --- | ---: | ---: | ---: | ---: |
| Zig | 6 | 45 | 22 | 340 |
| Markdown | 1 | 8 | 0 | 30 |
| **SUM** | **7** | **53** | **22** | **370** |

- Time: 0.01s
- Throughput: 700.0 files/s
```

### Example HTML report

`clocz --report html` generates a standalone HTML document with summary metrics and a responsive table, so it can be opened directly in a browser or attached to CI artifacts.

### Options

```text
Usage: clocz [options] [path]

Count lines of code in a directory tree.

Arguments:
  path          Directory to scan (default: current directory)

Options:
  -h, --help    Print this help and exit
      --report  Export report as text, markdown, or html (default: text)
  -v, --version Print version and exit
```

### Report formats

- `text` is the default terminal-friendly table output
- `markdown` produces a table that can be pasted into issues, pull requests, and documentation
- `html` produces a standalone report with totals, styling, and a responsive layout for sharing in a browser

## What clocz reports

For each detected language, `clocz` reports:

- Number of files
- Blank lines
- Comment lines
- Code lines

The final summary also includes total counts across all languages, elapsed runtime, and throughput in files per second.

## License

MIT
