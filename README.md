# clocz

A fast, multi-threaded command-line tool for counting lines of code, written in [Zig](https://ziglang.org/).

[![CI](https://github.com/christianhelle/clocz/actions/workflows/ci.yml/badge.svg)](https://github.com/christianhelle/clocz/actions/workflows/ci.yml)
[![Release](https://github.com/christianhelle/clocz/actions/workflows/release.yml/badge.svg)](https://github.com/christianhelle/clocz/actions/workflows/release.yml)

## Features

- Counts code, comment, and blank lines per language
- Multi-threaded directory scanning via Zig's `Thread.Pool`
- Supports 60+ languages out of the box
- Zero external dependencies
- Single static binary — no runtime needed
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
```

### Example output

```
------------------------------------------------------------------------
Language                          files    blank    comment       code
------------------------------------------------------------------------
Zig                                   6       45         22        340
Markdown                              1        8          0         30
------------------------------------------------------------------------
SUM:                                  7       53         22        370
------------------------------------------------------------------------
T=0.01s  (700.0 files/s)
```

### Options

```
Usage: clocz [options] [path]

Count lines of code in a directory tree.

Arguments:
  path          Directory to scan (default: current directory)

Options:
  -h, --help    Print this help and exit
  -v, --version Print version and exit
```

## License

MIT
