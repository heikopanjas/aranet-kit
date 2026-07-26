#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <version>" >&2
    exit 64
fi

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHANGELOG_FILE="$ROOT_DIR/CHANGELOG.md"
VERSION=$1

SECTION=$(awk -v version="$VERSION" '
    index($0, "## [" version "] - ") == 1 {
        found = 1
    }
    found == 1 && /^## \[/ && index($0, "## [" version "] - ") != 1 {
        exit
    }
    found == 1 {
        print
    }
' "$CHANGELOG_FILE")

if [[ -z "$SECTION" ]]; then
    echo "error: CHANGELOG.md has no section for version $VERSION" >&2
    exit 1
fi

printf '%s\n' "$SECTION"
