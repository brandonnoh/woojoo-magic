#!/usr/bin/env bats
# test-capture-session-end.bats — SessionEnd hook integration tests
# Covers acceptance criteria:
#   1. capture-session-end.sh exists
#   2. transcript JSONL 전체 파싱 → 모든 assistant text 추출
#   3. 누락 발화 보완 (filter pass + inbox 미존재)
#   4. 세션 요약 노트 생성 (~/.studybook/inbox/session-<id>.md, type=session_summary)
#   5. frontmatter 6개 필수 필드
#   6. hooks.json 등록
#   7. end_reason=resume → skip

setup() {
  _ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  CAPTURE_SH="${_ROOT}/src/wj-studybook/hooks/capture-session-end.sh"
  HOOKS_JSON="${_ROOT}/src/wj-studybook/hooks/hooks.json"
  PARSER_SH="${_ROOT}/src/wj-studybook/lib/transcript-parser.sh"

  TMP="$(mktemp -d)"
  export HOME="$TMP"
  mkdir -p "$HOME/.studybook/inbox"
  export CLAUDE_PLUGIN_ROOT="${_ROOT}/src/wj-studybook"
}

teardown() {
  rm -rf "$TMP"
}

# Helper: 표본 transcript 생성 (assistant text 5개 — 3 학습+2 액션, user 5개)
_make_sample_transcript() {
  _tr="$1"
  {
    echo '{"type":"user","timestamp":"2026-04-15T10:00:00Z","message":{"content":"why useEffect cleanup?"}}'
    printf '{"type":"assistant","timestamp":"2026-04-15T10:00:05Z","message":{"model":"claude-opus","content":[{"type":"text","text":"%s"}]}}\n' \
      "useEffect cleanup 함수는 메모리 누수 방지를 위한 필수 패턴입니다. 컴포넌트 언마운트 시 호출됩니다."
    echo '{"type":"user","timestamp":"2026-04-15T10:01:00Z","message":{"content":"action please"}}'
    printf '{"type":"assistant","timestamp":"2026-04-15T10:01:05Z","message":{"model":"claude-opus","content":[{"type":"text","text":"%s"}]}}\n' \
      "네."
    echo '{"type":"user","timestamp":"2026-04-15T10:02:00Z","message":{"content":"explain pattern"}}'
    printf '{"type":"assistant","timestamp":"2026-04-15T10:02:05Z","message":{"model":"claude-opus","content":[{"type":"text","text":"%s"}]}}\n' \
      "Repository 패턴은 데이터 접근 추상화 기법으로, 도메인 로직과 영속화 계층을 분리하는 설계 원리입니다."
    echo '{"type":"user","timestamp":"2026-04-15T10:03:00Z","message":{"content":"do it"}}'
    printf '{"type":"assistant","timestamp":"2026-04-15T10:03:05Z","message":{"model":"claude-opus","content":[{"type":"text","text":"%s"}]}}\n' \
      "확인했습니다."
    echo '{"type":"user","timestamp":"2026-04-15T10:04:00Z","message":{"content":"more design"}}'
    printf '{"type":"assistant","timestamp":"2026-04-15T10:04:05Z","message":{"model":"claude-opus","content":[{"type":"text","text":"%s"}]}}\n' \
      "Strategy 패턴은 알고리즘을 캡슐화하여 런타임에 교체 가능하게 하는 행위 디자인 패턴입니다. 의존성 역전과 함께 자주 쓰입니다."
  } > "$_tr"
}

# -- acceptance #1: file exists --------------------------------------

@test "acceptance #1: capture-session-end.sh exists and is executable" {
  [ -f "$CAPTURE_SH" ]
  [ -x "$CAPTURE_SH" ]
}

# -- acceptance #6: hooks.json registration --------------------------

@test "acceptance #6: hooks.json SessionEnd registers capture-session-end.sh" {
  run jq -r '.SessionEnd[0].hooks[0].command' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  [[ "$output" == *"capture-session-end.sh"* ]]
}

@test "acceptance #6: hooks.json SessionEnd is array (coexistence safe)" {
  run jq -r '.SessionEnd | type' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "array" ]
}

# -- acceptance #7: end_reason=resume → skip -------------------------

@test "acceptance #7: end_reason=resume → no inbox/summary created" {
  _tr="$TMP/tr.jsonl"
  _make_sample_transcript "$_tr"
  _payload="{\"session_id\":\"sess-r\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\",\"end_reason\":\"resume\"}"
  run bash -c "echo '$_payload' | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  _count=$(ls "$HOME/.studybook/inbox/" 2>/dev/null | wc -l | tr -d ' ')
  [ "$_count" -eq 0 ]
}

@test "acceptance #7: end_reason=logout → processed (summary created)" {
  _tr="$TMP/tr.jsonl"
  _make_sample_transcript "$_tr"
  _payload="{\"session_id\":\"sess-l1\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\",\"end_reason\":\"logout\"}"
  run bash -c "echo '$_payload' | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.studybook/inbox/session-sess-l1.md" ]
}

@test "acceptance #7: end_reason=clear → processed (summary created)" {
  _tr="$TMP/tr.jsonl"
  _make_sample_transcript "$_tr"
  _payload="{\"session_id\":\"sess-c1\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\",\"end_reason\":\"clear\"}"
  run bash -c "echo '$_payload' | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.studybook/inbox/session-sess-c1.md" ]
}

# -- acceptance #2 + #3: extract & supplement missing utterances ------

@test "acceptance #2 #3: extract assistant texts and filter only educational (block actions)" {
  _tr="$TMP/tr.jsonl"
  _make_sample_transcript "$_tr"
  _payload="{\"session_id\":\"sess-e1\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\",\"end_reason\":\"logout\"}"
  echo "$_payload" | bash "$CAPTURE_SH"
  # inbox: session 요약 1 + 학습 가치 텍스트 3 = 4 (액션 2개는 차단)
  _count=$(ls "$HOME/.studybook/inbox/" | wc -l | tr -d ' ')
  [ "$_count" -eq 4 ]
  # captured_count: 3
  grep -q "^captured_count: 3$" "$HOME/.studybook/inbox/session-sess-e1.md"
}

@test "acceptance #3: new inbox notes have hook_source=session_end" {
  _tr="$TMP/tr.jsonl"
  _make_sample_transcript "$_tr"
  _payload="{\"session_id\":\"sess-h1\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\",\"end_reason\":\"logout\"}"
  echo "$_payload" | bash "$CAPTURE_SH"
  # 일반 노트 (session-*.md 제외) 1개 이상은 hook_source: session_end
  for _f in "$HOME/.studybook/inbox/"*.md; do
    case "$(basename "$_f")" in
      session-*) continue ;;
    esac
    grep -q "^hook_source: session_end$" "$_f"
    return 0
  done
  return 1
}

# -- 중복 검사 (acceptance #3 보완) ---------------------------------

@test "dedup: re-run with same transcript yields zero new captures (captured_count=0)" {
  _tr="$TMP/tr.jsonl"
  _make_sample_transcript "$_tr"
  # 1차 실행
  _p1="{\"session_id\":\"sess-d1\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\",\"end_reason\":\"logout\"}"
  echo "$_p1" | bash "$CAPTURE_SH"
  _first=$(ls "$HOME/.studybook/inbox/" | wc -l | tr -d ' ')
  # 2차 실행 (다른 session_id, 같은 내용)
  _p2="{\"session_id\":\"sess-d2\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\",\"end_reason\":\"logout\"}"
  echo "$_p2" | bash "$CAPTURE_SH"
  _second=$(ls "$HOME/.studybook/inbox/" | wc -l | tr -d ' ')
  # 차이는 정확히 1 (요약 노트만 추가)
  [ "$((_second - _first))" -eq 1 ]
  # 2차 captured_count = 0
  grep -q "^captured_count: 0$" "$HOME/.studybook/inbox/session-sess-d2.md"
}

# -- acceptance #4 + #5: session summary --------------------------------

@test "acceptance #4: session summary file is type=session_summary" {
  _tr="$TMP/tr.jsonl"
  _make_sample_transcript "$_tr"
  _payload="{\"session_id\":\"sess-s1\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\",\"end_reason\":\"logout\"}"
  echo "$_payload" | bash "$CAPTURE_SH"
  _f="$HOME/.studybook/inbox/session-sess-s1.md"
  [ -f "$_f" ]
  grep -q "^type: session_summary$" "$_f"
  grep -q "^schema: studybook.note/v1$" "$_f"
}

@test "acceptance #5: session summary frontmatter contains 6 required fields" {
  _tr="$TMP/tr.jsonl"
  _make_sample_transcript "$_tr"
  _payload="{\"session_id\":\"sess-s2\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\",\"end_reason\":\"logout\"}"
  echo "$_payload" | bash "$CAPTURE_SH"
  _f="$HOME/.studybook/inbox/session-sess-s2.md"
  for _key in session_id started_at ended_at total_messages captured_count end_reason; do
    run grep -qE "^${_key}:" "$_f"
    [ "$status" -eq 0 ] || { echo "missing required field: $_key"; return 1; }
  done
}

@test "acceptance #5: session summary captures correct meta values" {
  _tr="$TMP/tr.jsonl"
  _make_sample_transcript "$_tr"
  _payload="{\"session_id\":\"sess-meta\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\",\"end_reason\":\"logout\"}"
  echo "$_payload" | bash "$CAPTURE_SH"
  _f="$HOME/.studybook/inbox/session-sess-meta.md"
  grep -q "^session_id: sess-meta$" "$_f"
  grep -q "^started_at: 2026-04-15T10:00:00Z$" "$_f"
  grep -q "^ended_at: 2026-04-15T10:04:05Z$" "$_f"
  grep -q "^total_messages: 10$" "$_f"
  grep -q "^end_reason: logout$" "$_f"
}

# -- transcript-parser.sh standalone tests ---------------------------

@test "parser: extract_all_assistant_texts returns NUL-delimited records" {
  _tr="$TMP/tr.jsonl"
  _make_sample_transcript "$_tr"
  # shellcheck source=/dev/null
  source "$PARSER_SH"
  _records=$(extract_all_assistant_texts "$_tr" | tr '\0' '\n' | grep -c .)
  # 5 assistant text blocks
  [ "$_records" -eq 5 ]
}

@test "parser: extract_user_prompts returns 5 records (string + array forms)" {
  _tr="$TMP/tr.jsonl"
  _make_sample_transcript "$_tr"
  # shellcheck source=/dev/null
  source "$PARSER_SH"
  _records=$(extract_user_prompts "$_tr" | tr '\0' '\n' | grep -c .)
  [ "$_records" -eq 5 ]
}

@test "parser: get_session_meta returns 4 lines (started, ended, total, model)" {
  _tr="$TMP/tr.jsonl"
  _make_sample_transcript "$_tr"
  # shellcheck source=/dev/null
  source "$PARSER_SH"
  _meta=$(get_session_meta "$_tr")
  [ "$(printf '%s\n' "$_meta" | wc -l | tr -d ' ')" -eq 4 ]
  [ "$(printf '%s\n' "$_meta" | sed -n 1p)" = "2026-04-15T10:00:00Z" ]
  [ "$(printf '%s\n' "$_meta" | sed -n 2p)" = "2026-04-15T10:04:05Z" ]
  [ "$(printf '%s\n' "$_meta" | sed -n 3p)" = "10" ]
  [ "$(printf '%s\n' "$_meta" | sed -n 4p)" = "claude-opus" ]
}

@test "parser: missing transcript file → non-zero exit" {
  # shellcheck source=/dev/null
  source "$PARSER_SH"
  run extract_all_assistant_texts "$TMP/does-not-exist.jsonl"
  [ "$status" -ne 0 ]
}

# -- edge cases ------------------------------------------------------

@test "edge: empty stdin → exit 0, no file" {
  run bash -c ": | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  _count=$(ls "$HOME/.studybook/inbox/" 2>/dev/null | wc -l | tr -d ' ')
  [ "$_count" -eq 0 ]
}

@test "edge: missing transcript_path → exit 0 (graceful skip)" {
  _payload='{"session_id":"sess-x","cwd":"/tmp","end_reason":"logout"}'
  run bash -c "echo '$_payload' | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
}

@test "edge: transcript with only tool_use (no text) → no inbox notes, summary still created" {
  _tr="$TMP/tr-tool.jsonl"
  {
    echo '{"type":"user","timestamp":"2026-04-15T11:00:00Z","message":{"content":"do it"}}'
    echo '{"type":"assistant","timestamp":"2026-04-15T11:00:05Z","message":{"model":"m","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{}}]}}'
  } > "$_tr"
  _payload="{\"session_id\":\"sess-tool\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\",\"end_reason\":\"logout\"}"
  echo "$_payload" | bash "$CAPTURE_SH"
  _f="$HOME/.studybook/inbox/session-sess-tool.md"
  [ -f "$_f" ]
  grep -q "^captured_count: 0$" "$_f"
  # 일반 노트는 0개 (요약만 존재)
  _general=0
  for _f in "$HOME/.studybook/inbox/"*.md; do
    [ -f "$_f" ] || continue
    case "$(basename "$_f")" in
      session-*) ;;
      *) _general=$((_general + 1)) ;;
    esac
  done
  [ "$_general" -eq 0 ]
}
