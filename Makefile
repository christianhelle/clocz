.PHONY: build test install clean help

# Default target
help:
	@echo "clocz Makefile targets:"
	@echo "  make build      - Build release binary optimized for speed"
	@echo "  make test       - Run all unit tests"
	@echo "  make install    - Build and install to /usr/local/bin"
	@echo "  make clean      - Remove build artifacts"

# Build release binary optimized for speed
build:
	zig build --release=fast

# Run all unit tests
test:
	zig build test -Doptimize=ReleaseFast

# Build and install binary
install: build
	@mkdir -p $(INSTALL_DIR)
	cp zig-out/bin/clocz $(INSTALL_DIR)/clocz
	@echo "Installed clocz to $(INSTALL_DIR)/clocz"

# Clean build artifacts
clean:
	rm -rf zig-out .zig-cache

# Set default install directory (can be overridden: make install INSTALL_DIR=~/.local/bin)
INSTALL_DIR ?= /usr/local/bin
