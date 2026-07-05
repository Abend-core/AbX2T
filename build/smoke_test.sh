#!/usr/bin/env bash
# AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Smoke test: converts build/testdata/sample.docx to PDF and TXT with a real Abx2t
# run (extraction + font generation + x2t) and checks the outputs are plausible.
# This is the end-to-end gate for CI and for validating a machine or a bundle bump.
#
# Usage: bash build/smoke_test.sh [path/to/Abx2t]
#   Without argument, runs the project through `dotnet run` (JIT, no publish needed).
#   With an argument, tests that exact executable (e.g. the published NativeAOT exe)
#   from a fresh temp directory, exercising the first-run extraction as end users see it.

set -uo pipefail

repo=$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sample="$repo/build/testdata/sample.docx"
out=$(mktemp -d "${TMPDIR:-/tmp}/abx2t_smoke.XXXXXX")
trap 'rm -rf "$out"' EXIT

fail() { echo "SMOKE TEST FAILED: $1" >&2; exit 1; }

if [[ $# -ge 1 ]]; then
  # Copy the exe to a fresh dir so the first-run extraction is exercised too.
  [[ -f "$1" ]] || fail "executable not found: $1"
  cp "$1" "$out/Abx2t"
  chmod +x "$out/Abx2t"
  run() { "$out/Abx2t" "$@"; }
else
  command -v dotnet >/dev/null || fail "dotnet not found (pass a built Abx2t path instead)"
  run() { dotnet run --project "$repo/src" -c Release -- "$@"; }
fi

echo "== --version"
run --version || fail "--version exited with $?"

echo "== docx -> pdf"
run --timeout 10 "$sample" "$out/sample.pdf" || fail "docx->pdf conversion exited with $?"
[[ -f "$out/sample.pdf" ]] || fail "sample.pdf missing"
head -c 4 "$out/sample.pdf" | grep -q '%PDF' || fail "sample.pdf does not start with %PDF"
[[ $(wc -c < "$out/sample.pdf") -gt 1000 ]] || fail "sample.pdf suspiciously small"

echo "== docx -> txt"
run --timeout 10 "$sample" "$out/sample.txt" || fail "docx->txt conversion exited with $?"
grep -q "quick brown fox" "$out/sample.txt" || fail "converted text does not contain the sample sentence"

echo "== error paths"
run "$sample" "$sample" >/dev/null 2>&1 && fail "source==output should be refused"
[[ $? -eq 1 ]] || fail "source==output should exit 1"
run "$out/missing.docx" "$out/x.pdf" >/dev/null 2>&1
[[ $? -eq 1 ]] || fail "missing source should exit 1"

echo ""
echo "SMOKE TEST OK"
