# clocz

`clocz` is a fast, multi-threaded command-line tool for counting lines of code, written in [Zig](https://ziglang.org/). It scans a directory tree, groups files by language, prints a text summary to standard output, and writes a report file you can keep, share, or publish.

[![CI](https://github.com/christianhelle/clocz/actions/workflows/ci.yml/badge.svg)](https://github.com/christianhelle/clocz/actions/workflows/ci.yml)
[![Release](https://github.com/christianhelle/clocz/actions/workflows/release.yml/badge.svg)](https://github.com/christianhelle/clocz/actions/workflows/release.yml)

## Features

- Counts code, comment, and blank lines per language
- Multi-threaded directory scanning via Zig's `Thread.Pool`
- Supports 60+ languages out of the box
- Always prints a terminal-friendly text summary
- Writes report files as text, markdown, or standalone HTML
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
# Count lines in the current directory and write clocz.text
clocz

# Count lines in a specific directory and write clocz.text
clocz /path/to/project

# Print the normal text summary and write clocz.markdown
clocz --report markdown /path/to/project

# Print the normal text summary and write clocz.html
clocz --report html /path/to/project
```

`clocz` always prints the standard text table to stdout. It also writes the selected report to the current working directory using one of these filenames:

- `clocz.text`
- `clocz.markdown`
- `clocz.html`

### Example text output

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

### Example markdown report file

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

### Example HTML report file

`clocz --report html` writes a standalone HTML document with summary metrics and a responsive table to `clocz.html`, ready to open in a browser or attach to CI artifacts.

### Options

```text
Usage: clocz [options] [path]

Count lines of code in a directory tree.

Arguments:
  path          Directory to scan (default: current directory)

Options:
  -h, --help    Print this help and exit
      --report  Write clocz.text, clocz.markdown, or clocz.html (default: text)
  -v, --version Print version and exit
```

### Report formats

- `text` writes `clocz.text` while stdout remains the normal text summary
- `markdown` writes `clocz.markdown` for issues, pull requests, and documentation
- `html` writes `clocz.html` as a standalone report with totals, styling, and a responsive layout

## What clocz reports

For each detected language, `clocz` reports:

- Number of files
- Blank lines
- Comment lines
- Code lines

The final summary also includes total counts across all languages, elapsed runtime, and throughput in files per second.

## License

MIT
