#!/usr/bin/env bats
# test-digest.bats — wj-studybook lib/digest.sh + topic-writer.sh unit tests
# Note: 테스트명은 ASCII만, 데이터/카테고리는 한글 가능.

setup() {
  LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-studybook/lib" && pwd)"
  TMP="$(mktemp -d)"
  export STUDYBOOK_HOME="${TMP}/sb"
  export WJ_SB_HOME="$STUDYBOOK_HOME"
  export WJ_SB_PROFILE="testprof"
  mkdir -p "$WJ_SB_HOME/inbox" "$WJ_SB_HOME/profiles" "$WJ_SB_HOME/cache" \
           "$WJ_SB_HOME/books/testprof/topics"
  # 활성 프로필 yaml + config
  cat > "$WJ_SB_HOME/config.yaml" <<'EOF'
active_profile: testprof
EOF
  cat > "$WJ_SB_HOME/profiles/testprof.yaml" <<'EOF'
name: testprof
level: beginner
language: ko
tone: friendly
EOF
  # shellcheck source=/dev/null
  source "${LIB_DIR}/schema.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/index-update.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/topic-writer.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/digest.sh"
}

teardown() { rm -rf "$TMP"; }

# helper: 샘플 inbox 노트 작성
_mk_inbox() {
  _id="$1"; _type="${2:-inbox}"; _content="${3:-test body}"
  _file="$WJ_SB_HOME/inbox/$(date +%Y-%m-%d)-${_id}.md"
  cat > "$_file" <<EOF
---
id: ${_id}
schema: studybook.note/v1
type: ${_type}
status: raw
captured_at: 2026-04-15T00:00:00+09:00
session_id: sess-${_id}
project: testproj
project_path: /tmp/testproj
git_branch: main
model: claude-opus-4-6
hook_source: stop
user_prompt: ""
related_files: []
detected_keywords: []
language_hints: []
estimated_value: null
---

${_content}
EOF
  printf '%s\n' "$_file"
}

# ── digest_collect_inbox ────────────────────────────────────────

@test "collect: counts inbox notes excluding processed and session_summary" {
  _mk_inbox 01ID0000000000000000000001 inbox          "react useEffect 정리" >/dev/null
  _mk_inbox 01ID0000000000000000000002 inbox          "git rebase 패턴" >/dev/null
  _mk_inbox 01ID0000000000000000000003 inbox          "css cascade 원리" >/dev/null
  _mk_inbox 01ID0000000000000000000004 session_summary "session summary" >/dev/null
  _mk_inbox 01ID0000000000000000000005 inbox          "another inbox" >/dev/null
  # processed 폴더에 1개 (collect에서 제외되어야 함)
  mkdir -p "$WJ_SB_HOME/inbox/processed/2026-04-14"
  cp "$WJ_SB_HOME/inbox/$(date +%Y-%m-%d)-01ID0000000000000000000001.md" \
     "$WJ_SB_HOME/inbox/processed/2026-04-14/old.md"
  _n=$(digest_collect_inbox | wc -l | tr -d ' ')
  [ "$_n" = "4" ]
}

@test "collect: empty inbox returns nothing" {
  _n=$(digest_collect_inbox | wc -l | tr -d ' ')
  [ "$_n" = "0" ]
}

# ── digest_prepare ──────────────────────────────────────────────

@test "prepare: includes profile, tree, inbox sections" {
  init_tree_cache
  _mk_inbox 01PREP00000000000000000001 inbox "react hook 동작 원리" >/dev/null
  _out=$(digest_prepare)
  echo "$_out" | grep -q "ACTIVE_PROFILE"
  echo "$_out" | grep -q "testprof"
  echo "$_out" | grep -q "PROFILE_YAML"
  echo "$_out" | grep -q "level: beginner"
  echo "$_out" | grep -q "CURRENT_TREE_JSON"
  echo "$_out" | grep -q "INBOX_NOTES"
  echo "$_out" | grep -q "INBOX_BEGIN id=01PREP00000000000000000001"
  echo "$_out" | grep -q "react hook 동작 원리"
  echo "$_out" | grep -q "INBOX_COUNT"
}

@test "prepare: INBOX_COUNT matches actual collect count" {
  _mk_inbox 01CNT0000000000000000000001 inbox "n1" >/dev/null
  _mk_inbox 01CNT0000000000000000000002 inbox "n2" >/dev/null
  _mk_inbox 01CNT0000000000000000000003 session_summary "skip" >/dev/null
  _out=$(digest_prepare)
  _cnt_line=$(echo "$_out" | awk '/^## INBOX_COUNT$/ {getline; print}')
  [ "$_cnt_line" = "2" ]
}

# ── topic-writer: write_topic_note ──────────────────────────────

@test "write_topic_note: creates file at expected path with frontmatter" {
  _src=$(jq -nc '[{inbox_id:"01ABC",captured_at:"2026-04-15T00:00:00+09:00",session_id:"s1",model:"m"}]')
  _file=$(write_topic_note \
    --profile testprof --category dev --subcategory fe --topic react \
    --title "useEffect 정리" --slug "useeffect" \
    --tags "react,hooks" --body "본문" \
    --sources-json "$_src" --level beginner --language ko)
  [ -f "$_file" ]
  echo "$_file" | grep -q "books/testprof/topics/dev/fe/react/useeffect-"
  validate_note_schema "$_file"
}

@test "write_topic_note: inserts Generation Effect slot" {
  _src=$(jq -nc '[{inbox_id:"01XYZ",captured_at:"x",session_id:"s",model:"m"}]')
  _file=$(write_topic_note \
    --profile testprof --category dev --subcategory fe --topic react \
    --title "T" --slug "t" --body "본문" --sources-json "$_src")
  grep -q "## 내 말로 정리" "$_file"
  grep -q "Generation Effect 슬롯" "$_file"
}

@test "write_topic_note: triggers update_index_on_add (tree.json + _index.md)" {
  _src=$(jq -nc '[{inbox_id:"01IDX",captured_at:"x",session_id:"s",model:"m"}]')
  write_topic_note \
    --profile testprof --category dev --subcategory fe --topic react \
    --title "T" --slug "t" --body "b" --sources-json "$_src" >/dev/null
  _cnt=$(jq -r '.tree.dev.subtopics.fe.subtopics.react.note_count' \
    "$WJ_SB_HOME/cache/tree.json")
  [ "$_cnt" = "1" ]
  [ -f "$WJ_SB_HOME/books/testprof/topics/dev/fe/react/_index.md" ]
  [ -f "$WJ_SB_HOME/books/testprof/topics/dev/fe/_index.md" ]
  [ -f "$WJ_SB_HOME/books/testprof/topics/dev/_index.md" ]
}

# ── digest_apply ────────────────────────────────────────────────

@test "apply: 5 notes → 5 topic files + processed move + tree.json sync" {
  init_tree_cache
  update_tree_unsorted_set 5
  _mk_inbox 01APPLY000000000000000001 inbox "react hook 정리" >/dev/null
  _mk_inbox 01APPLY000000000000000002 inbox "git rebase 패턴" >/dev/null
  _mk_inbox 01APPLY000000000000000003 inbox "css cascade 원리" >/dev/null
  _mk_inbox 01APPLY000000000000000004 inbox "tcp handshake 흐름" >/dev/null
  _mk_inbox 01APPLY000000000000000005 inbox "함수형 프로그래밍 immutability" >/dev/null
  _json="$TMP/results.json"
  cat > "$_json" <<'JSONEOF'
[
  {"inbox_id":"01APPLY000000000000000001","category":"dev","subcategory":"fe","topic":"react","title":"useEffect 정리","slug":"useeffect","tags":["react","hooks"],"body":"react useEffect는 ..."},
  {"inbox_id":"01APPLY000000000000000002","category":"dev","subcategory":"vcs","topic":"git","title":"git rebase 패턴","slug":"git-rebase","tags":["git"],"body":"rebase는 ..."},
  {"inbox_id":"01APPLY000000000000000003","category":"design","subcategory":"web","topic":"css","title":"CSS cascade 원리","slug":"css-cascade","tags":["css"],"body":"cascade는 ..."},
  {"inbox_id":"01APPLY000000000000000004","category":"dev","subcategory":"network","topic":"tcp","title":"TCP handshake","slug":"tcp-handshake","tags":["tcp"],"body":"3-way handshake ..."},
  {"inbox_id":"01APPLY000000000000000005","category":"dev","subcategory":"paradigm","topic":"fp","title":"불변성","slug":"immutability","tags":["fp"],"body":"immutability는 ..."}
]
JSONEOF
  digest_apply "$_json"
  # 5개 topic 노트 생성
  _files=$(find "$WJ_SB_HOME/books/testprof/topics" -type f -name '*.md' ! -name '_index.md' | wc -l | tr -d ' ')
  [ "$_files" = "5" ]
  # 인덱스 동기화 (dev=4건, design=1건)
  _dev=$(jq -r '.tree.dev.note_count' "$WJ_SB_HOME/cache/tree.json")
  [ "$_dev" = "4" ]
  _design=$(jq -r '.tree.design.note_count' "$WJ_SB_HOME/cache/tree.json")
  [ "$_design" = "1" ]
  # inbox/processed 이동
  _proc=$(find "$WJ_SB_HOME/inbox/processed" -type f -name '*.md' | wc -l | tr -d ' ')
  [ "$_proc" = "5" ]
  # 원본 inbox 5개는 사라져야 함
  _remain=$(find "$WJ_SB_HOME/inbox" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')
  [ "$_remain" = "0" ]
  # unsorted_count 감소: 5 → 0
  _u=$(jq -r '.unsorted_count' "$WJ_SB_HOME/cache/tree.json")
  [ "$_u" = "0" ]
}

@test "apply: sources[] contains original inbox metadata" {
  _mk_inbox 01SRC0000000000000000000001 inbox "테스트 본문" >/dev/null
  _json="$TMP/r.json"
  cat > "$_json" <<'JSONEOF'
[{"inbox_id":"01SRC0000000000000000000001","category":"dev","subcategory":"fe","topic":"react","title":"T","slug":"t","tags":[],"body":"b"}]
JSONEOF
  digest_apply "$_json"
  _f=$(find "$WJ_SB_HOME/books/testprof/topics/dev/fe/react" -type f -name '*.md' ! -name '_index.md' | head -1)
  [ -n "$_f" ]
  _yaml=$(read_frontmatter "$_f")
  echo "$_yaml" | grep -q "sources:"
  # sources YAML 라인의 JSON에 inbox_id, session_id, model 모두 포함
  _sline=$(echo "$_yaml" | grep '^sources:' | sed 's/^sources:[[:space:]]*//')
  echo "$_sline" | jq -e '.[0].inbox_id == "01SRC0000000000000000000001"'
  echo "$_sline" | jq -e '.[0].session_id == "sess-01SRC0000000000000000000001"'
  echo "$_sline" | jq -e '.[0].model == "claude-opus-4-6"'
  echo "$_sline" | jq -e '.[0].captured_at == "2026-04-15T00:00:00+09:00"'
}

@test "apply: Generation Effect slot present in every applied note" {
  _mk_inbox 01GEN0000000000000000000001 inbox "본문1" >/dev/null
  _mk_inbox 01GEN0000000000000000000002 inbox "본문2" >/dev/null
  _json="$TMP/r.json"
  cat > "$_json" <<'JSONEOF'
[
  {"inbox_id":"01GEN0000000000000000000001","category":"dev","subcategory":"fe","topic":"react","title":"T1","slug":"t1","tags":[],"body":"b1"},
  {"inbox_id":"01GEN0000000000000000000002","category":"dev","subcategory":"fe","topic":"vue","title":"T2","slug":"t2","tags":[],"body":"b2"}
]
JSONEOF
  digest_apply "$_json"
  while IFS= read -r _f; do
    grep -q "## 내 말로 정리" "$_f"
  done < <(find "$WJ_SB_HOME/books/testprof/topics" -type f -name '*.md' ! -name '_index.md')
}

@test "apply: parent _index.md aggregates from update_index_on_add" {
  _mk_inbox 01PAR0000000000000000000001 inbox "n1" >/dev/null
  _mk_inbox 01PAR0000000000000000000002 inbox "n2" >/dev/null
  _json="$TMP/r.json"
  cat > "$_json" <<'JSONEOF'
[
  {"inbox_id":"01PAR0000000000000000000001","category":"dev","subcategory":"fe","topic":"react","title":"T","slug":"t1","tags":[],"body":"b"},
  {"inbox_id":"01PAR0000000000000000000002","category":"dev","subcategory":"fe","topic":"react","title":"T","slug":"t2","tags":[],"body":"b"}
]
JSONEOF
  digest_apply "$_json"
  _leaf=$(grep '^note_count:' "$WJ_SB_HOME/books/testprof/topics/dev/fe/react/_index.md" | awk '{print $2}')
  [ "$_leaf" = "2" ]
  _sub=$(grep '^note_count:' "$WJ_SB_HOME/books/testprof/topics/dev/fe/_index.md" | awk '{print $2}')
  [ "$_sub" = "2" ]
  _cat=$(grep '^note_count:' "$WJ_SB_HOME/books/testprof/topics/dev/_index.md" | awk '{print $2}')
  [ "$_cat" = "2" ]
}

@test "apply: korean category names work end-to-end" {
  _mk_inbox 01KO00000000000000000000001 inbox "한글 테스트" >/dev/null
  _json="$TMP/r.json"
  cat > "$_json" <<'JSONEOF'
[{"inbox_id":"01KO00000000000000000000001","category":"개발","subcategory":"프론트엔드","topic":"react","title":"한글","slug":"hangul","tags":[],"body":"본문"}]
JSONEOF
  digest_apply "$_json"
  _f=$(find "$WJ_SB_HOME/books/testprof/topics/개발/프론트엔드/react" -type f -name '*.md' ! -name '_index.md' | head -1)
  [ -n "$_f" ]
  _cnt=$(jq -r '.tree."개발".subtopics."프론트엔드".subtopics.react.note_count' "$WJ_SB_HOME/cache/tree.json")
  [ "$_cnt" = "1" ]
}

@test "apply: invalid json (not array) fails" {
  _json="$TMP/bad.json"
  echo '{"x":1}' > "$_json"
  run digest_apply "$_json"
  [ "$status" -ne 0 ]
}

@test "apply: missing inbox_id fails clearly" {
  _json="$TMP/missing.json"
  cat > "$_json" <<'JSONEOF'
[{"inbox_id":"01NOTEXIST00000000000000000","category":"dev","subcategory":"fe","topic":"react","title":"T","slug":"t","tags":[],"body":"b"}]
JSONEOF
  run digest_apply "$_json"
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "inbox_id 매칭 실패"
}

# ── digest_archive_inbox 단독 ───────────────────────────────────

@test "archive: moves inbox file to processed/<date>/" {
  _mk_inbox 01ARCH00000000000000000001 inbox "x" >/dev/null
  digest_archive_inbox 01ARCH00000000000000000001
  _today=$(date +%Y-%m-%d)
  _moved=$(find "$WJ_SB_HOME/inbox/processed/${_today}" -type f -name '*.md' | wc -l | tr -d ' ')
  [ "$_moved" = "1" ]
  _orig=$(find "$WJ_SB_HOME/inbox" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')
  [ "$_orig" = "0" ]
}
