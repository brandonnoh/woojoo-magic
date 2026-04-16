#!/usr/bin/env bats
# test-schema.bats — wj-studybook lib/schema.sh unit tests
# Covers: ulid_generate, emit_frontmatter, read_frontmatter, validate_note_schema

setup() {
  SCHEMA_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-studybook/lib" && pwd)/schema.sh"
  TMP="$(mktemp -d)"
  # shellcheck source=/dev/null
  source "$SCHEMA_SH"
}

teardown() {
  rm -rf "$TMP"
}

# ── ulid_generate ────────────────────────────────────────────────

@test "ulid: length is 26" {
  _ulid=$(ulid_generate)
  [ "${#_ulid}" -eq 26 ]
}

@test "ulid: only Crockford base32 chars (no I L O U)" {
  _ulid=$(ulid_generate)
  [[ "$_ulid" =~ ^[0-9A-HJKMNP-TV-Z]{26}$ ]]
}

@test "ulid: monotonic across sleep (lexicographic)" {
  _u1=$(ulid_generate)
  sleep 0.01
  _u2=$(ulid_generate)
  [[ "$_u1" < "$_u2" ]] || [[ "$_u1" == "$_u2" ]]
}

@test "ulid: 100 generations are all unique" {
  _seen=$(for _i in $(seq 1 100); do ulid_generate; done | sort -u | wc -l | tr -d ' ')
  [ "$_seen" -eq 100 ]
}

# ── emit_frontmatter ─────────────────────────────────────────────

@test "emit_frontmatter: wraps with --- delimiters" {
  _out=$(emit_frontmatter "id: 01ABC")
  [[ "$_out" == *"---"* ]]
  [[ "$_out" == *"id: 01ABC"* ]]
}

@test "emit_frontmatter: first and last line are ---" {
  _out=$(emit_frontmatter "key: value")
  _first=$(echo "$_out" | head -n1)
  _last=$(echo "$_out" | tail -n1)
  [ "$_first" = "---" ]
  [ "$_last" = "---" ]
}

# ── read_frontmatter ─────────────────────────────────────────────

@test "read_frontmatter: extracts first frontmatter block" {
  _f="${TMP}/note.md"
  {
    echo "---"
    echo "id: 01XYZ"
    echo "type: inbox"
    echo "---"
    echo "body line"
  } > "$_f"
  _out=$(read_frontmatter "$_f")
  [[ "$_out" == *"id: 01XYZ"* ]]
  [[ "$_out" == *"type: inbox"* ]]
  [[ "$_out" != *"body"* ]]
}

@test "read_frontmatter: roundtrip write then read returns same payload" {
  _f="${TMP}/round.md"
  _payload="id: 01ULID"$'\n'"type: inbox"$'\n'"status: raw"
  emit_frontmatter "$_payload" > "$_f"
  echo "body" >> "$_f"
  _out=$(read_frontmatter "$_f")
  [[ "$_out" == *"id: 01ULID"* ]]
  [[ "$_out" == *"type: inbox"* ]]
  [[ "$_out" == *"status: raw"* ]]
}

@test "read_frontmatter: file without frontmatter exits 1" {
  _f="${TMP}/plain.md"
  echo "body only" > "$_f"
  run read_frontmatter "$_f"
  [ "$status" -ne 0 ]
}

@test "read_frontmatter: missing file exits 1" {
  run read_frontmatter "${TMP}/nope.md"
  [ "$status" -ne 0 ]
}

# ── validate_note_schema ─────────────────────────────────────────

@test "validate_note_schema: valid inbox note passes" {
  _f="${TMP}/inbox.md"
  _ulid=$(ulid_generate)
  {
    echo "---"
    echo "id: $_ulid"
    echo "schema: studybook.note/v1"
    echo "type: inbox"
    echo "status: raw"
    echo "captured_at: 2026-04-16T14:32:18+09:00"
    echo "---"
    echo "body"
  } > "$_f"
  run validate_note_schema "$_f"
  [ "$status" -eq 0 ]
}

@test "validate_note_schema: valid topic note passes" {
  _f="${TMP}/topic.md"
  _ulid=$(ulid_generate)
  {
    echo "---"
    echo "id: $_ulid"
    echo "schema: studybook.note/v1"
    echo "type: topic"
    echo "status: classified"
    echo "captured_at: 2026-04-16T14:32:18+09:00"
    echo "category: dev"
    echo "profile: woojoo"
    echo "sources:"
    echo "  - inbox_id: $_ulid"
    echo "---"
  } > "$_f"
  run validate_note_schema "$_f"
  [ "$status" -eq 0 ]
}

@test "validate_note_schema: missing id fails" {
  _f="${TMP}/bad.md"
  {
    echo "---"
    echo "schema: studybook.note/v1"
    echo "type: inbox"
    echo "status: raw"
    echo "captured_at: 2026-04-16T14:32:18+09:00"
    echo "---"
  } > "$_f"
  run validate_note_schema "$_f"
  [ "$status" -ne 0 ]
  [[ "$output" == *"id"* ]]
}

@test "validate_note_schema: invalid schema field format fails" {
  _f="${TMP}/badschema.md"
  {
    echo "---"
    echo "id: 01ABC"
    echo "schema: wrong/v1"
    echo "type: inbox"
    echo "status: raw"
    echo "captured_at: 2026-04-16T14:32:18+09:00"
    echo "---"
  } > "$_f"
  run validate_note_schema "$_f"
  [ "$status" -ne 0 ]
  [[ "$output" == *"schema"* ]]
}

@test "validate_note_schema: topic missing category fails" {
  _f="${TMP}/topicbad.md"
  _ulid=$(ulid_generate)
  {
    echo "---"
    echo "id: $_ulid"
    echo "schema: studybook.note/v1"
    echo "type: topic"
    echo "status: classified"
    echo "captured_at: 2026-04-16T14:32:18+09:00"
    echo "profile: woojoo"
    echo "sources:"
    echo "  - inbox_id: $_ulid"
    echo "---"
  } > "$_f"
  run validate_note_schema "$_f"
  [ "$status" -ne 0 ]
  [[ "$output" == *"category"* ]]
}

@test "validate_note_schema: topic missing profile fails" {
  _f="${TMP}/topicnoprof.md"
  _ulid=$(ulid_generate)
  {
    echo "---"
    echo "id: $_ulid"
    echo "schema: studybook.note/v1"
    echo "type: topic"
    echo "status: classified"
    echo "captured_at: 2026-04-16T14:32:18+09:00"
    echo "category: dev"
    echo "sources:"
    echo "  - inbox_id: $_ulid"
    echo "---"
  } > "$_f"
  run validate_note_schema "$_f"
  [ "$status" -ne 0 ]
  [[ "$output" == *"profile"* ]]
}

@test "validate_note_schema: topic missing sources fails" {
  _f="${TMP}/topicnosrc.md"
  _ulid=$(ulid_generate)
  {
    echo "---"
    echo "id: $_ulid"
    echo "schema: studybook.note/v1"
    echo "type: topic"
    echo "status: classified"
    echo "captured_at: 2026-04-16T14:32:18+09:00"
    echo "category: dev"
    echo "profile: woojoo"
    echo "---"
  } > "$_f"
  run validate_note_schema "$_f"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sources"* ]]
}

@test "validate_note_schema: missing file exits 1" {
  run validate_note_schema "${TMP}/nope.md"
  [ "$status" -ne 0 ]
}
