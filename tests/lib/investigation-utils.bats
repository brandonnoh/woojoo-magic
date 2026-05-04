#!/usr/bin/env bats

setup() {
  UTILS="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-magic/lib" && pwd)/investigation-utils.sh"
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ── git-recent-changes ────────────────────────────────────────────────────────

@test "git-recent-changes: no args runs with defaults" {
  run bash "$UTILS" git-recent-changes
  [ "$status" -eq 0 ]
}

@test "git-recent-changes: numeric arg succeeds" {
  run bash "$UTILS" git-recent-changes 3
  [ "$status" -eq 0 ]
}

# ── git-suspects ──────────────────────────────────────────────────────────────

@test "git-suspects: no file arg returns error" {
  run bash "$UTILS" git-suspects
  [ "$status" -ne 0 ]
  [[ "$output" == *"파일 경로 필요"* ]]
}

@test "git-suspects: nonexistent file returns error" {
  run bash "$UTILS" git-suspects "/nonexistent/path/file.ts"
  [ "$status" -ne 0 ]
  [[ "$output" == *"파일 없음"* ]]
}

@test "git-suspects: real file outputs TSV or empty" {
  _test_file="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/src/wj-magic/lib/patterns.sh"
  run bash "$UTILS" git-suspects "$_test_file" 3
  [ "$status" -eq 0 ]
  if [[ -n "$output" ]]; then
    echo "$output" | while IFS= read -r _line; do
      _field_count=$(echo "$_line" | awk -F'\t' '{print NF}')
      [ "$_field_count" -ge 3 ]
    done
  fi
}

# ── bisect-test ───────────────────────────────────────────────────────────────

@test "bisect-test: too few args returns error" {
  run bash "$UTILS" bisect-test
  [ "$status" -ne 0 ]
  [[ "$output" == *"필요"* ]]
}

@test "bisect-test: good == bad exits immediately" {
  _head=$(git rev-parse HEAD 2>/dev/null || echo "HEAD")
  run bash "$UTILS" bisect-test "$_head" "$_head" "exit 0"
  [ "$status" -eq 0 ]
  [[ "$output" == *"good == bad"* ]]
}

# ── report-init ───────────────────────────────────────────────────────────────

@test "report-init: no output file arg returns error" {
  run bash "$UTILS" report-init
  [ "$status" -ne 0 ]
  [[ "$output" == *"output_file 필요"* ]]
}

@test "report-init: no issue_summary returns error" {
  run bash "$UTILS" report-init "$TMP_DIR/report.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"issue_summary 필요"* ]]
}

@test "report-init: creates output file" {
  run bash "$UTILS" report-init "$TMP_DIR/report.md" "로그인 버그"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/report.md" ]
}

@test "report-init: contains required sections" {
  bash "$UTILS" report-init "$TMP_DIR/report.md" "API 느림"
  _content=$(cat "$TMP_DIR/report.md")
  [[ "$_content" == *"Investigation Report"* ]]
  [[ "$_content" == *"Agent Findings"* ]]
  [[ "$_content" == *"web-researcher"* ]]
  [[ "$_content" == *"code-analyst"* ]]
  [[ "$_content" == *"security-auditor"* ]]
  [[ "$_content" == *"perf-analyst"* ]]
  [[ "$_content" == *"regression-hunter"* ]]
  [[ "$_content" == *"Root Cause Analysis"* ]]
  [[ "$_content" == *"Verification"* ]]
  [[ "$_content" == *"Memory Graph"* ]]
}

@test "report-init: issue_summary appears in file" {
  bash "$UTILS" report-init "$TMP_DIR/report.md" "테스트 이슈 문자열"
  _content=$(cat "$TMP_DIR/report.md")
  [[ "$_content" == *"테스트 이슈 문자열"* ]]
}

@test "report-init: date header included" {
  bash "$UTILS" report-init "$TMP_DIR/report.md" "날짜 테스트"
  _today=$(date +"%Y-%m-%d")
  _content=$(cat "$TMP_DIR/report.md")
  [[ "$_content" == *"$_today"* ]]
}

# ── unknown command ───────────────────────────────────────────────────────────

@test "unknown subcommand exits with usage" {
  run bash "$UTILS" unknown-command
  [ "$status" -ne 0 ]
}
