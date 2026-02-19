#!/usr/bin/env bash
set -euo pipefail

REPO="christianhelle/clocz"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)  os="linux" ;;
        Darwin) os="macos" ;;
        *)      echo "Unsupported OS: $os" >&2; exit 1 ;;
    esac

    case "$arch" in
        x86_64|amd64)  arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *)             echo "Unsupported architecture: $arch" >&2; exit 1 ;;
    esac

    echo "${os}-${arch}"
}

main() {
    local platform artifact_name url tmp_dir

    platform="$(detect_platform)"
    artifact_name="clocz-${platform}.tar.gz"

    echo "Detecting platform: ${platform}"

    url="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
        | grep -o "\"browser_download_url\": *\"[^\"]*${artifact_name}\"" \
        | head -1 \
        | cut -d'"' -f4)"

    if [ -z "$url" ]; then
        echo "Error: could not find release asset ${artifact_name}" >&2
        exit 1
    fi

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    echo "Downloading ${url}..."
    curl -fsSL "$url" -o "${tmp_dir}/${artifact_name}"

    echo "Installing to ${INSTALL_DIR}..."
    tar xzf "${tmp_dir}/${artifact_name}" -C "$tmp_dir"
    install -d "$INSTALL_DIR"
    install -m 755 "${tmp_dir}/clocz" "$INSTALL_DIR/clocz"

    echo "clocz installed to ${INSTALL_DIR}/clocz"
}

main
