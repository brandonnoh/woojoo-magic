#!/usr/bin/env bats
# test-backfill.bats — /wj:studybook backfill 구현 테스트 (s14)
# Covers acceptance criteria:
#   1. --since <date> 라우팅
#   2. ~/.claude/projects/<encoded-cwd>/*.jsonl 전수 스캔
#   3. 지정 날짜 이후 assistant text 블록 추출
#   4. is_educational 통과 → inbox에 ULID 부여 + dedup
#   5. 진행률 출력 (N/M sessions, K notes)
#   6. 완료 메시지 + digest 권장

setup() {
  _ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  BACKFILL_SH="${_ROOT}/src/wj-studybook/lib/backfill.sh"
  STUDYBOOK_CMD="${_ROOT}/src/wj-studybook/commands/studybook.md"

  TMP="$(mktemp -d)"
  export HOME="$TMP"
  mkdir -p "$HOME/.studybook/inbox"
  mkdir -p "$HOME/.claude/projects"
  export CLAUDE_PLUGIN_ROOT="${_ROOT}/src/wj-studybook"
}

teardown() {
  rm -rf "$TMP"
}

# Helper: encoded project dir path (leading / → -, every / → -)
_enc() {
  printf '%s' "$1" | sed -e 's|^/|-|' -e 's|/|-|g'
}

# Helper: write a simple jsonl session with N educational + M action blocks
_make_session() {
  _path="$1"; shift
  _tsbase="${1:-2026-04-15T10:00:00Z}"; shift
  _kind="${1:-edu}"; shift || true
  case "$_kind" in
    edu)
      {
        printf '{"type":"user","timestamp":"%s","message":{"content":"why"}}\n' "$_tsbase"
        printf '{"type":"assistant","timestamp":"%s","message":{"model":"claude-opus","content":[{"type":"text","text":"%s"}]}}\n' \
          "$_tsbase" \
          "Repository 패턴은 데이터 접근 추상화 기법으로, 도메인 로직과 영속화 계층을 분리하는 설계 원리입니다."
        printf '{"type":"assistant","timestamp":"%s","message":{"model":"claude-opus","content":[{"type":"text","text":"%s"}]}}\n' \
          "$_tsbase" \
          "useEffect cleanup 함수는 메모리 누수 방지를 위한 필수 패턴입니다. 컴포넌트 언마운트 시 호출됩니다."
      } > "$_path"
      ;;
    action)
      {
        printf '{"type":"user","timestamp":"%s","message":{"content":"do"}}\n' "$_tsbase"
        printf '{"type":"assistant","timestamp":"%s","message":{"model":"m","content":[{"type":"text","text":"네."}]}}\n' \
          "$_tsbase"
        printf '{"type":"assistant","timestamp":"%s","message":{"model":"m","content":[{"type":"text","text":"확인했습니다."}]}}\n' \
          "$_tsbase"
      } > "$_path"
      ;;
  esac
}

# ── backfill_find_sessions ──────────────────────────────────────

@test "find_sessions: finds all jsonl under projects (no filter)" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  _d1="$HOME/.claude/projects/$(_enc /Users/woojoo/Documents/GitHub/woojoo-magic)"
  _d2="$HOME/.claude/projects/$(_enc /Users/woojoo/Documents/GitHub/other)"
  mkdir -p "$_d1" "$_d2"
  _make_session "$_d1/s1.jsonl" 2026-04-14T10:00:00Z edu
  _make_session "$_d1/s2.jsonl" 2026-04-15T10:00:00Z edu
  _make_session "$_d2/s3.jsonl" 2026-04-15T10:00:00Z edu
  _out=$(backfill_find_sessions --since 2026-01-01)
  _n=$(printf '%s\n' "$_out" | grep -c '\.jsonl$' || true)
  [ "$_n" -eq 3 ]
}

@test "find_sessions: --project filters by encoded basename suffix" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  _d1="$HOME/.claude/projects/$(_enc /Users/woojoo/Documents/GitHub/woojoo-magic)"
  _d2="$HOME/.claude/projects/$(_enc /Users/woojoo/Documents/GitHub/other)"
  mkdir -p "$_d1" "$_d2"
  _make_session "$_d1/s1.jsonl" 2026-04-15T10:00:00Z edu
  _make_session "$_d2/s2.jsonl" 2026-04-15T10:00:00Z edu
  _out=$(backfill_find_sessions --since 2026-01-01 --project woojoo-magic)
  _n=$(printf '%s\n' "$_out" | grep -c '\.jsonl$' || true)
  [ "$_n" -eq 1 ]
  printf '%s\n' "$_out" | grep -q 'woojoo-magic'
}

@test "find_sessions: --all skips date validation (returns every jsonl)" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  _d="$HOME/.claude/projects/$(_enc /tmp/p)"
  mkdir -p "$_d"
  _make_session "$_d/a.jsonl" 2020-01-01T00:00:00Z edu
  _make_session "$_d/b.jsonl" 2026-04-15T00:00:00Z edu
  _out=$(backfill_find_sessions --all)
  _n=$(printf '%s\n' "$_out" | grep -c '\.jsonl$' || true)
  [ "$_n" -eq 2 ]
}

@test "find_sessions: invalid --since format → non-zero exit" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  run backfill_find_sessions --since 20260101
  [ "$status" -ne 0 ]
}

@test "find_sessions: missing --since (no --all) → non-zero exit" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  run backfill_find_sessions
  [ "$status" -ne 0 ]
}

# ── backfill_process_session ────────────────────────────────────

@test "process_session: educational blocks become inbox notes tagged backfill" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  _d="$HOME/.claude/projects/$(_enc /tmp/p)"
  mkdir -p "$_d"
  _make_session "$_d/s.jsonl" 2026-04-15T10:00:00Z edu
  _added=$(backfill_process_session "$_d/s.jsonl" 2026-01-01)
  [ "$_added" -eq 2 ]
  _n=$(ls "$HOME/.studybook/inbox/" | wc -l | tr -d ' ')
  [ "$_n" -eq 2 ]
  # hook_source=backfill 태깅 확인
  for _f in "$HOME/.studybook/inbox/"*.md; do
    grep -q "^hook_source: backfill$" "$_f"
  done
}

@test "process_session: action-only session → 0 added" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  _d="$HOME/.claude/projects/$(_enc /tmp/p)"
  mkdir -p "$_d"
  _make_session "$_d/a.jsonl" 2026-04-15T10:00:00Z action
  _added=$(backfill_process_session "$_d/a.jsonl" 2026-01-01)
  [ "$_added" -eq 0 ]
}

@test "process_session: --since filters out old timestamps" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  _d="$HOME/.claude/projects/$(_enc /tmp/p)"
  mkdir -p "$_d"
  _make_session "$_d/old.jsonl" 2025-01-01T10:00:00Z edu
  _added=$(backfill_process_session "$_d/old.jsonl" 2026-01-01)
  [ "$_added" -eq 0 ]
}

@test "process_session: idempotent — second run adds 0 notes" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  _d="$HOME/.claude/projects/$(_enc /tmp/p)"
  mkdir -p "$_d"
  _make_session "$_d/s.jsonl" 2026-04-15T10:00:00Z edu
  _first=$(backfill_process_session "$_d/s.jsonl" 2026-01-01)
  [ "$_first" -eq 2 ]
  _second=$(backfill_process_session "$_d/s.jsonl" 2026-01-01)
  [ "$_second" -eq 0 ]
  # inbox에는 여전히 2개만
  _n=$(ls "$HOME/.studybook/inbox/" | wc -l | tr -d ' ')
  [ "$_n" -eq 2 ]
}

# ── backfill_run (orchestrator) ─────────────────────────────────

@test "run: multi-session, progress on stderr, completion message on stdout" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  _d="$HOME/.claude/projects/$(_enc /tmp/p)"
  mkdir -p "$_d"
  _make_session "$_d/s1.jsonl" 2026-04-14T10:00:00Z edu
  _make_session "$_d/s2.jsonl" 2026-04-15T10:00:00Z edu
  _tmp_out=$(mktemp)
  _tmp_err=$(mktemp)
  backfill_run --since 2026-01-01 >"$_tmp_out" 2>"$_tmp_err"
  # stdout: 완료 메시지 + digest 권장
  grep -q "inbox" "$_tmp_out"
  grep -q "digest" "$_tmp_out"
  # stderr: [N/M] 진행률
  grep -qE '\[1/2\]' "$_tmp_err"
  grep -qE '\[2/2\]' "$_tmp_err"
  rm -f "$_tmp_out" "$_tmp_err"
}

@test "run: idempotent — second run adds 0 (completion message says 0)" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  _d="$HOME/.claude/projects/$(_enc /tmp/p)"
  mkdir -p "$_d"
  _make_session "$_d/s.jsonl" 2026-04-15T10:00:00Z edu
  backfill_run --since 2026-01-01 >/dev/null 2>&1
  _count_after_first=$(ls "$HOME/.studybook/inbox/" | wc -l | tr -d ' ')
  _out=$(backfill_run --since 2026-01-01 2>/dev/null)
  # "0개" 포함
  echo "$_out" | grep -q "0개"
  _count_after_second=$(ls "$HOME/.studybook/inbox/" | wc -l | tr -d ' ')
  [ "$_count_after_first" = "$_count_after_second" ]
}

@test "run: --project filters sessions" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  _d1="$HOME/.claude/projects/$(_enc /tmp/p1)"
  _d2="$HOME/.claude/projects/$(_enc /tmp/p2)"
  mkdir -p "$_d1" "$_d2"
  _make_session "$_d1/s1.jsonl" 2026-04-15T10:00:00Z edu
  _make_session "$_d2/s2.jsonl" 2026-04-15T10:00:00Z edu
  backfill_run --since 2026-01-01 --project p1 >/dev/null 2>&1
  # p1 세션만 처리됨: 2개 inbox 노트
  _n=$(ls "$HOME/.studybook/inbox/" | wc -l | tr -d ' ')
  [ "$_n" -eq 2 ]
}

@test "run: no sessions found → exit 0 with friendly message" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  run bash -c "source '$BACKFILL_SH' && backfill_run --since 2026-01-01"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "세션|0개|없"
}

@test "run: --all processes every jsonl regardless of date" {
  # shellcheck source=/dev/null
  source "$BACKFILL_SH"
  _d="$HOME/.claude/projects/$(_enc /tmp/p)"
  mkdir -p "$_d"
  _make_session "$_d/old.jsonl" 2020-01-01T00:00:00Z edu
  backfill_run --all >/dev/null 2>&1
  _n=$(ls "$HOME/.studybook/inbox/" | wc -l | tr -d ' ')
  [ "$_n" -eq 2 ]
}

# ── 라우팅 (studybook.md) ───────────────────────────────────────

@test "routing: studybook.md contains backfill case" {
  grep -q "backfill)" "$STUDYBOOK_CMD"
}

@test "routing: studybook.md sources backfill.sh" {
  grep -q "backfill.sh" "$STUDYBOOK_CMD"
}
