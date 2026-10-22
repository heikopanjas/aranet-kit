#!/bin/bash

# Runs the test suites with code coverage and fails when line coverage of
# Sources/ falls below COVERAGE_THRESHOLD (percent). The threshold is raised
# milestone by milestone as described in TEST_PLAN.md.
#
# Excluded files are listed in EXCLUDED_FILES with the reason next to them.
# They are the only deviation from full coverage and must stay small.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
THRESHOLD="${COVERAGE_THRESHOLD:-100}"

# CoreBluetoothCentral.swift forwards CBCentralManager and CBPeripheral delegate
# callbacks into BluetoothEvent values. Its methods take CBPeripheral, CBService,
# and CBCharacteristic arguments that cannot be created in a test process, and
# constructing a CBCentralManager would trigger the Bluetooth permission prompt
# on a CI runner. It is verified with the hardware checklist in TEST_PLAN.md.
EXCLUDED_FILES=(
    "Sources/AranetKit/Bluetooth/CoreBluetoothCentral.swift"
)

cd "$ROOT_DIR"

swift test --enable-code-coverage
CODECOV_JSON=$(swift test --show-codecov-path)

if [[ ! -f "$CODECOV_JSON" ]]; then
    echo "error: coverage export not found at $CODECOV_JSON" >&2
    exit 1
fi

PROFDATA="$(dirname "$CODECOV_JSON")/default.profdata"
TEST_BINARY=$(find "$(swift build --show-bin-path)" -path '*PackageTests.xctest/Contents/MacOS/*PackageTests' -type f | head -n 1 || true)

python3 -I - "$CODECOV_JSON" "$ROOT_DIR" "$THRESHOLD" "${TEST_BINARY:-}" "$PROFDATA" "${EXCLUDED_FILES[@]}" <<'PYTHON'
import json
import subprocess
import sys

codecov_path, root_dir, threshold_text, test_binary, profdata = sys.argv[1:6]
excluded = set(sys.argv[6:])
threshold = float(threshold_text)

with open(codecov_path, encoding="utf-8") as handle:
    export = json.load(handle)

sources_prefix = root_dir.rstrip("/") + "/Sources/"
rows = []
uncovered = {}


def uncovered_lines_from_llvm(filename):
    """Lines llvm-cov itself reports with an execution count of zero, or None when llvm-cov is unavailable."""
    if not test_binary:
        return None
    command = ["xcrun", "llvm-cov", "show", test_binary, "-instr-profile", profdata, filename]
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        return None
    lines = []
    for text in result.stdout.split("\n"):
        fields = text.split("|")
        if len(fields) >= 3 and fields[0].strip() == "0" and fields[1].strip().isdigit():
            lines.append(int(fields[1]))
    return lines


def uncovered_lines(segments):
    """Lines inside regions that never executed, from llvm-cov's [line, col, count, hasCount, isRegionEntry, ...] segments."""
    lines = set()
    ordered = sorted(segments, key=lambda s: (s[0], s[1]))
    for index, segment in enumerate(ordered):
        line, _, count, has_count = segment[0], segment[1], segment[2], segment[3]
        if not has_count or count > 0:
            continue
        end_line = ordered[index + 1][0] if index + 1 < len(ordered) else line
        lines.update(range(line, max(line, end_line) + 1))
    return sorted(lines)


def ranges(lines):
    text = []
    start = previous = None
    for line in lines + [None]:
        if start is not None and line == previous + 1:
            previous = line
            continue
        if start is not None:
            text.append(str(start) if start == previous else f"{start}-{previous}")
        start = previous = line
    return ", ".join(text)
total_lines = 0
covered_lines = 0
total_regions = 0
covered_regions = 0

for data in export.get("data", []):
    for entry in data.get("files", []):
        filename = entry.get("filename", "")
        if not filename.startswith(sources_prefix):
            continue
        relative = filename[len(root_dir.rstrip("/")) + 1:]
        summary = entry.get("summary", {})
        lines = summary.get("lines", {})
        regions = summary.get("regions", {})
        line_count = int(lines.get("count", 0))
        line_covered = int(lines.get("covered", 0))
        region_count = int(regions.get("count", 0))
        region_covered = int(regions.get("covered", 0))
        skipped = relative in excluded
        rows.append((relative, line_count, line_covered, region_count, region_covered, skipped))
        if not skipped and line_covered < line_count:
            exact = uncovered_lines_from_llvm(filename)
            uncovered[relative] = exact if exact is not None else uncovered_lines(entry.get("segments", []))
        if skipped:
            continue
        total_lines += line_count
        covered_lines += line_covered
        total_regions += region_count
        covered_regions += region_covered

def percent(covered, count):
    return 100.0 if count == 0 else 100.0 * covered / count

rows.sort()
width = max((len(row[0]) for row in rows), default=4)
print(f"{'File':<{width}}  {'Lines':>9}  {'Line %':>7}  {'Regions':>9}  {'Region %':>8}")
for relative, line_count, line_covered, region_count, region_covered, skipped in rows:
    note = "  (excluded)" if skipped else ""
    print(
        f"{relative:<{width}}  {line_covered:>4}/{line_count:<4}  {percent(line_covered, line_count):>6.1f}%  "
        f"{region_covered:>4}/{region_count:<4}  {percent(region_covered, region_count):>7.1f}%{note}"
    )

for relative in sorted(uncovered):
    if uncovered[relative]:
        print(f"uncovered in {relative}: lines {ranges(uncovered[relative])}")

line_percent = percent(covered_lines, total_lines)
region_percent = percent(covered_regions, total_regions)
print()
print(f"Line coverage:   {covered_lines}/{total_lines} = {line_percent:.2f}% (threshold {threshold:.2f}%)")
print(f"Region coverage: {covered_regions}/{total_regions} = {region_percent:.2f}% (reported, not gated)")

if line_percent + 1e-9 < threshold:
    print(f"error: line coverage {line_percent:.2f}% is below the threshold of {threshold:.2f}%", file=sys.stderr)
    sys.exit(1)
PYTHON
