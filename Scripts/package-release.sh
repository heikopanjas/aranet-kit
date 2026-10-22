#!/bin/bash

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "usage: $0 <version> <binary> [output-directory]" >&2
    exit 64
fi

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION=$1
BINARY=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
OUTPUT_DIR=${3:-$ROOT_DIR/dist}
ARCHIVE_ROOT="aranet-cli-$VERSION-macos-arm64"

if [[ ! -x "$BINARY" ]]; then
    echo "error: executable binary not found at $BINARY" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
find "${OUTPUT_DIR:?}" -maxdepth 1 \
    \( \
        -type f \
        \( \
            -name 'aranet-cli-*-macos-arm64.tar.gz' -o \
            -name 'aranet-cli-*.artifactbundle.zip' -o \
            -name 'SHA256SUMS.txt' \
        \) -o \
        -type d \
        \( \
            -name 'aranet-cli-*-macos-arm64' -o \
            -name 'aranet-cli.artifactbundle' \
        \) \
    \) \
    -exec rm -rf {} +
mkdir -p "$OUTPUT_DIR/$ARCHIVE_ROOT"

cp "$BINARY" "$OUTPUT_DIR/$ARCHIVE_ROOT/aranet-cli"
cp "$ROOT_DIR/LICENSE" "$ROOT_DIR/README.md" "$OUTPUT_DIR/$ARCHIVE_ROOT/"

(
    cd "$OUTPUT_DIR"
    COPYFILE_DISABLE=1 tar -czf "$ARCHIVE_ROOT.tar.gz" "$ARCHIVE_ROOT"
    shasum -a 256 "$ARCHIVE_ROOT.tar.gz" >SHA256SUMS.txt
)

rm -rf "${OUTPUT_DIR:?}/$ARCHIVE_ROOT"
