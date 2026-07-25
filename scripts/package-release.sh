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
BUNDLE_ROOT="aranet-cli.artifactbundle"

if [[ ! -x "$BINARY" ]]; then
    echo "error: executable binary not found at $BINARY" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -rf "${OUTPUT_DIR:?}/$ARCHIVE_ROOT" "${OUTPUT_DIR:?}/$BUNDLE_ROOT"
rm -f \
    "$OUTPUT_DIR/$ARCHIVE_ROOT.tar.gz" \
    "$OUTPUT_DIR/aranet-cli-$VERSION.artifactbundle.zip" \
    "$OUTPUT_DIR/SHA256SUMS.txt"
mkdir -p "$OUTPUT_DIR/$ARCHIVE_ROOT"
mkdir -p "$OUTPUT_DIR/$BUNDLE_ROOT/$ARCHIVE_ROOT/bin"

cp "$BINARY" "$OUTPUT_DIR/$ARCHIVE_ROOT/aranet-cli"
cp "$ROOT_DIR/LICENSE" "$ROOT_DIR/README.md" "$OUTPUT_DIR/$ARCHIVE_ROOT/"
cp "$BINARY" "$OUTPUT_DIR/$BUNDLE_ROOT/$ARCHIVE_ROOT/bin/aranet-cli"

cat >"$OUTPUT_DIR/$BUNDLE_ROOT/info.json" <<EOF
{
  "schemaVersion": "1.0",
  "artifacts": {
    "aranet-cli": {
      "type": "executable",
      "version": "$VERSION",
      "variants": [
        {
          "path": "$ARCHIVE_ROOT/bin/aranet-cli",
          "supportedTriples": [
            "arm64-apple-macosx"
          ]
        }
      ]
    }
  }
}
EOF

(
    cd "$OUTPUT_DIR"
    COPYFILE_DISABLE=1 tar -czf "$ARCHIVE_ROOT.tar.gz" "$ARCHIVE_ROOT"
    zip -q -r -X "aranet-cli-$VERSION.artifactbundle.zip" "$BUNDLE_ROOT"
    shasum -a 256 "$ARCHIVE_ROOT.tar.gz" "aranet-cli-$VERSION.artifactbundle.zip" >SHA256SUMS.txt
)

rm -rf "${OUTPUT_DIR:?}/$ARCHIVE_ROOT" "${OUTPUT_DIR:?}/$BUNDLE_ROOT"
