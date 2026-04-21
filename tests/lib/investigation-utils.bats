#!/usr/bin/env bats

setup() {
  UTILS="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/woojoo-magic/lib" && pwd)/investigation-utils.sh"
  TMP_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_DIR"
}

# ── git-recent-changes ────────────────────────────────────────────────────────

@test "git-recent-changes: 인자 없으면 기본값으로 실행됨 (에러 없음)" {
  run bash "$UTILS" git-recent-changes
  [ "$status" -eq 0 ]
}

@test "git-recent-changes: 숫자 인자 받으면 에러 없음" {
  run bash "$UTILS" git-recent-changes 3
  [ "$status" -eq 0 ]
}

# ── git-suspects ──────────────────────────────────────────────────────────────

@test "git-suspects: 파일 경로 없으면 에러" {
  run bash "$UTILS" git-suspects
  [ "$status" -ne 0 ]
  [[ "$output" == *"파일 경로 필요"* ]]
}

@test "git-suspects: 존재하지 않는 파일이면 에러" {
  run bash "$UTILS" git-suspects "/nonexistent/path/file.ts"
  [ "$status" -ne 0 ]
  [[ "$output" == *"파일 없음"* ]]
}

@test "git-suspects: 실제 파일로 실행 시 TSV 형식 출력 또는 빈 줄" {
  # 현재 저장소에서 실제 파일로 테스트
  _test_file="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/src/woojoo-magic/lib/patterns.sh"
  run bash "$UTILS" git-suspects "$_test_file" 3
  [ "$status" -eq 0 ]
  # 출력이 있으면 탭 구분자 형식이어야 함
  if [[ -n "$output" ]]; then
    echo "$output" | while IFS= read -r _line; do
      # 탭 구분자 4필드 (SHA, author, timestamp, content)
      _field_count=$(echo "$_line" | awk -F'\t' '{print NF}')
      [ "$_field_count" -ge 3 ]
    done
  fi
}

# ── bisect-test ───────────────────────────────────────────────────────────────

@test "bisect-test: 인자 부족하면 에러" {
  run bash "$UTILS" bisect-test
  [ "$status" -ne 0 ]
  [[ "$output" == *"필요"* ]]
}

@test "bisect-test: good == bad 이면 즉시 종료" {
  _head=$(git rev-parse HEAD 2>/dev/null || echo "HEAD")
  run bash "$UTILS" bisect-test "$_head" "$_head" "exit 0"
  [ "$status" -eq 0 ]
  [[ "$output" == *"good == bad"* ]]
}

# ── report-init ───────────────────────────────────────────────────────────────

@test "report-init: 출력 파일 인자 없으면 에러" {
  run bash "$UTILS" report-init
  [ "$status" -ne 0 ]
  [[ "$output" == *"output_file 필요"* ]]
}

@test "report-init: issue_summary 없으면 에러" {
  run bash "$UTILS" report-init "$TMP_DIR/report.md"
  [ "$status" -ne 0 ]
  [[ "$output" == *"issue_summary 필요"* ]]
}

@test "report-init: 출력 파일 생성됨" {
  run bash "$UTILS" report-init "$TMP_DIR/report.md" "로그인 버그"
  [ "$status" -eq 0 ]
  [ -f "$TMP_DIR/report.md" ]
}

@test "report-init: 필수 섹션 포함" {
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

@test "report-init: issue_summary가 파일에 포함됨" {
  bash "$UTILS" report-init "$TMP_DIR/report.md" "테스트 이슈 문자열"
  _content=$(cat "$TMP_DIR/report.md")
  [[ "$_content" == *"테스트 이슈 문자열"* ]]
}

@test "report-init: 날짜 헤더 포함됨" {
  bash "$UTILS" report-init "$TMP_DIR/report.md" "날짜 테스트"
  _today=$(date +"%Y-%m-%d")
  _content=$(cat "$TMP_DIR/report.md")
  [[ "$_content" == *"$_today"* ]]
}

# ── 알 수 없는 커맨드 ─────────────────────────────────────────────────────────

@test "알 수 없는 서브커맨드는 usage 출력 후 종료" {
  run bash "$UTILS" unknown-command
  [ "$status" -ne 0 ]
}
