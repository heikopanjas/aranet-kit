#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TOOL_VERSION=$("$ROOT_DIR/scripts/extract-version.sh")
CHANGELOG_VERSION=$(awk '
    /^## \[[0-9]+\.[0-9]+\.[0-9]+\] - / {
        version = $0
        sub(/^## \[/, "", version)
        sub(/\] - .*/, "", version)
        print version
        exit
    }
' "$ROOT_DIR/CHANGELOG.md")

if [[ -z "$CHANGELOG_VERSION" ]]; then
    echo "error: CHANGELOG.md has no released version section" >&2
    exit 1
fi

if [[ "$TOOL_VERSION" != "$CHANGELOG_VERSION" ]]; then
    echo "error: toolVersion $TOOL_VERSION does not match latest CHANGELOG version $CHANGELOG_VERSION" >&2
    exit 1
fi

"$ROOT_DIR/scripts/changelog-section.sh" "$TOOL_VERSION" >/dev/null
printf '%s\n' "$TOOL_VERSION"
