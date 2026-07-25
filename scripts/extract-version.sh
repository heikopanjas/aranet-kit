#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION_FILE="$ROOT_DIR/Sources/AranetCli/AranetCli.swift"

VERSION=$(sed -nE 's/^[[:space:]]*static let toolVersion = "([^"]+)".*/\1/p' "$VERSION_FILE")

if [[ -z "$VERSION" ]]; then
    echo "error: toolVersion was not found in $VERSION_FILE" >&2
    exit 1
fi

if [[ $(printf '%s\n' "$VERSION" | wc -l | tr -d ' ') != "1" ]]; then
    echo "error: multiple toolVersion declarations were found in $VERSION_FILE" >&2
    exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: toolVersion '$VERSION' is not a semantic version" >&2
    exit 1
fi

printf '%s\n' "$VERSION"
