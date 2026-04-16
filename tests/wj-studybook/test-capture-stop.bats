#!/usr/bin/env bats
# test-capture-stop.bats — Stop hook integration tests
# Covers:
#   - normal input (last_assistant_message) -> file created + frontmatter
#   - empty message -> no file created
#   - fallback (no last_assistant_message, extracted from transcript)
#   - hooks.json registration check (wj coexistence)

setup() {
  _ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  CAPTURE_SH="${_ROOT}/src/wj-studybook/hooks/capture-stop.sh"
  HOOKS_JSON="${_ROOT}/src/wj-studybook/hooks/hooks.json"
  SCHEMA_SH="${_ROOT}/src/wj-studybook/lib/schema.sh"

  # Test isolation: HOME -> tempdir
  TMP="$(mktemp -d)"
  export HOME="$TMP"
  mkdir -p "$HOME/.studybook/inbox"

  # CLAUDE_PLUGIN_ROOT explicit (capture-stop.sh source path resolution)
  export CLAUDE_PLUGIN_ROOT="${_ROOT}/src/wj-studybook"
}

teardown() {
  rm -rf "$TMP"
}

# Helper: first .md file in inbox
_first_inbox_file() {
  ls "$HOME/.studybook/inbox/"*.md 2>/dev/null | head -n1
}

# -- hooks.json checks ----------------------------------------------

@test "hooks json: capture-stop.sh registered in Stop array" {
  run jq -r '.Stop[0].hooks[0].command' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  [[ "$output" == *"capture-stop.sh"* ]]
}

@test "hooks json: Stop key is array (wj coexistence safe)" {
  run jq -r '.Stop | type' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  [ "$output" = "array" ]
}

# -- normal input ---------------------------------------------------

@test "normal: file created with body content" {
  _payload='{
    "session_id": "sess-abc",
    "transcript_path": "/dev/null",
    "cwd": "/tmp",
    "last_assistant_message": "useEffect cleanup runs on unmount."
  }'
  run bash -c "echo '$_payload' | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  _f=$(_first_inbox_file)
  [ -n "$_f" ]
  run grep -q "useEffect cleanup" "$_f"
  [ "$status" -eq 0 ]
}

@test "normal: all required frontmatter keys present" {
  _payload='{"session_id":"s1","transcript_path":"/dev/null","cwd":"/tmp","last_assistant_message":"hi"}'
  echo "$_payload" | bash "$CAPTURE_SH"
  _f=$(_first_inbox_file)
  [ -n "$_f" ]
  for _key in id schema type status captured_at session_id project project_path git_branch model hook_source user_prompt related_files; do
    run grep -qE "^${_key}:" "$_f"
    [ "$status" -eq 0 ] || { echo "missing key: $_key"; return 1; }
  done
}

@test "normal: schema=studybook.note/v1, type=inbox, status=raw, hook_source=stop" {
  _payload='{"session_id":"s2","transcript_path":"/dev/null","cwd":"/tmp","last_assistant_message":"x"}'
  echo "$_payload" | bash "$CAPTURE_SH"
  _f=$(_first_inbox_file)
  grep -q "^schema: studybook.note/v1$" "$_f"
  grep -q "^type: inbox$" "$_f"
  grep -q "^status: raw$" "$_f"
  grep -q "^hook_source: stop$" "$_f"
}

@test "normal: validate_note_schema passes" {
  _payload='{"session_id":"s3","transcript_path":"/dev/null","cwd":"/tmp","last_assistant_message":"valid body"}'
  echo "$_payload" | bash "$CAPTURE_SH"
  _f=$(_first_inbox_file)
  # shellcheck source=/dev/null
  source "$SCHEMA_SH"
  run validate_note_schema "$_f"
  [ "$status" -eq 0 ]
}

@test "normal: filename matches YYYY-MM-DD-<26ULID>.md pattern" {
  _payload='{"session_id":"s4","transcript_path":"/dev/null","cwd":"/tmp","last_assistant_message":"y"}'
  echo "$_payload" | bash "$CAPTURE_SH"
  _f=$(_first_inbox_file)
  _name=$(basename "$_f")
  [[ "$_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9A-HJKMNP-TV-Z]{26}\.md$ ]]
}

# -- empty message --------------------------------------------------

@test "empty: empty last_assistant_message -> no file" {
  _payload='{"session_id":"s5","transcript_path":"/dev/null","cwd":"/tmp","last_assistant_message":""}'
  run bash -c "echo '$_payload' | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  _count=$(ls "$HOME/.studybook/inbox/" 2>/dev/null | wc -l | tr -d ' ')
  [ "$_count" -eq 0 ]
}

@test "empty: missing field with no transcript -> no file" {
  _payload='{"session_id":"s6","cwd":"/tmp"}'
  run bash -c "echo '$_payload' | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  _count=$(ls "$HOME/.studybook/inbox/" 2>/dev/null | wc -l | tr -d ' ')
  [ "$_count" -eq 0 ]
}

@test "empty: stdin empty -> exit 0, no file" {
  run bash -c ": | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  _count=$(ls "$HOME/.studybook/inbox/" 2>/dev/null | wc -l | tr -d ' ')
  [ "$_count" -eq 0 ]
}

# -- fallback: extract from transcript ------------------------------

@test "fallback: no last_assistant_message extracts last assistant text from transcript" {
  _tr="$TMP/transcript.jsonl"
  {
    echo '{"type":"user","message":{"content":"prompt-1"}}'
    echo '{"type":"assistant","message":{"model":"claude-test-model","content":[{"type":"text","text":"This is the last assistant response."}]}}'
  } > "$_tr"
  _payload="{\"session_id\":\"s7\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\"}"
  run bash -c "echo '$_payload' | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  _f=$(_first_inbox_file)
  [ -n "$_f" ]
  grep -q "last assistant response" "$_f"
  grep -q "^model: claude-test-model$" "$_f"
}

@test "fallback: transcript user prompt is captured into user_prompt frontmatter" {
  _tr="$TMP/transcript2.jsonl"
  {
    echo '{"type":"user","message":{"content":"why useEffect?"}}'
    echo '{"type":"assistant","message":{"model":"m","content":[{"type":"text","text":"answer body"}]}}'
  } > "$_tr"
  _payload="{\"session_id\":\"s8\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\"}"
  echo "$_payload" | bash "$CAPTURE_SH"
  _f=$(_first_inbox_file)
  grep -q "why useEffect" "$_f"
}

@test "fallback: transcript with only tool_use (no text) -> no file" {
  _tr="$TMP/transcript3.jsonl"
  {
    echo '{"type":"user","message":{"content":"do it"}}'
    echo '{"type":"assistant","message":{"model":"m","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{}}]}}'
  } > "$_tr"
  _payload="{\"session_id\":\"s9\",\"transcript_path\":\"$_tr\",\"cwd\":\"/tmp\"}"
  run bash -c "echo '$_payload' | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  _count=$(ls "$HOME/.studybook/inbox/" 2>/dev/null | wc -l | tr -d ' ')
  [ "$_count" -eq 0 ]
}

# -- meta fields ----------------------------------------------------

@test "meta: session_id and project_path recorded verbatim in frontmatter" {
  _payload='{"session_id":"my-sess-xyz","transcript_path":"/dev/null","cwd":"/tmp","last_assistant_message":"x"}'
  echo "$_payload" | bash "$CAPTURE_SH"
  _f=$(_first_inbox_file)
  grep -q "^session_id: my-sess-xyz$" "$_f"
  grep -q "^project_path: /tmp$" "$_f"
  grep -q "^project: tmp$" "$_f"
}
