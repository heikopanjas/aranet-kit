#!/bin/bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "usage: $0 <binary> [expected-architecture]" >&2
    exit 64
fi

BINARY=$1
EXPECTED_ARCHITECTURE=${2:-arm64}

if [[ ! -x "$BINARY" ]]; then
    echo "error: executable binary not found at $BINARY" >&2
    exit 1
fi

ARCHITECTURES=$(lipo -archs "$BINARY")
if [[ "$ARCHITECTURES" != "$EXPECTED_ARCHITECTURE" ]]; then
    echo "error: expected $EXPECTED_ARCHITECTURE binary, found $ARCHITECTURES" >&2
    exit 1
fi

printf '%s\n' "$ARCHITECTURES"
