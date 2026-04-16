#!/usr/bin/env bats
# test-index-update.bats — wj-studybook lib/index-update.sh unit tests
# Note: 테스트명은 ASCII만 사용 (bats가 멀티바이트 테스트명을 처리 못함).
#       데이터/카테고리 값에는 한글을 사용하여 실제 도메인 시나리오 검증.

setup() {
  LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-studybook/lib" && pwd)"
  SCHEMA_SH="${LIB_DIR}/schema.sh"
  IDX_SH="${LIB_DIR}/index-update.sh"
  TMP="$(mktemp -d)"
  export WJ_SB_HOME="${TMP}/sb"
  export WJ_SB_PROFILE="testprof"
  PROFILE_ROOT="${WJ_SB_HOME}/books/testprof/topics"
  mkdir -p "$PROFILE_ROOT"
  # shellcheck source=/dev/null
  source "$SCHEMA_SH"
  # shellcheck source=/dev/null
  source "$IDX_SH"
}

teardown() {
  rm -rf "$TMP"
}

# helper: 테스트용 노트 frontmatter 생성
_mknote() {
  _path="$1"; _cat="$2"; _sub="$3"; _top="$4"
  mkdir -p "$(dirname "$_path")"
  cat > "$_path" <<EOF
---
schema: studybook.note/v1
id: 01TESTNOTE0000000000000000
type: topic
status: active
captured_at: 2026-04-15T00:00:00+09:00
category: ${_cat}
subcategory: ${_sub}
topic: ${_top}
profile: testprof
sources: []
---

# test note
EOF
}

# ── init_tree_cache ─────────────────────────────────────────────

@test "init: creates tree.json with schema fields" {
  init_tree_cache
  [ -f "${WJ_SB_HOME}/cache/tree.json" ]
  _schema=$(jq -r '.schema' "${WJ_SB_HOME}/cache/tree.json")
  [ "$_schema" = "studybook.tree/v1" ]
  _profile=$(jq -r '.active_profile' "${WJ_SB_HOME}/cache/tree.json")
  [ "$_profile" = "testprof" ]
  _unsorted=$(jq -r '.unsorted_count' "${WJ_SB_HOME}/cache/tree.json")
  [ "$_unsorted" = "0" ]
}

@test "init: idempotent does not overwrite" {
  init_tree_cache
  _t1=$(jq -r '.generated_at' "${WJ_SB_HOME}/cache/tree.json")
  sleep 1
  init_tree_cache
  _t2=$(jq -r '.generated_at' "${WJ_SB_HOME}/cache/tree.json")
  [ "$_t1" = "$_t2" ]
}

# ── update_index_on_add ─────────────────────────────────────────

@test "add: 10 notes yields topic note_count 10" {
  for _i in $(seq 1 10); do
    _path="${PROFILE_ROOT}/dev/fe/react/note-${_i}.md"
    _mknote "$_path" "dev" "fe" "react"
    update_index_on_add "$_path"
  done
  _cnt=$(jq -r '.tree.dev.subtopics.fe.subtopics.react.note_count' \
    "${WJ_SB_HOME}/cache/tree.json")
  [ "$_cnt" = "10" ]
}

@test "add: parent _index.md note_count accumulates" {
  for _i in $(seq 1 3); do
    _path="${PROFILE_ROOT}/dev/fe/react/n${_i}.md"
    _mknote "$_path" "dev" "fe" "react"
    update_index_on_add "$_path"
  done
  _leaf=$(grep '^note_count:' "${PROFILE_ROOT}/dev/fe/react/_index.md" | awk '{print $2}')
  [ "$_leaf" = "3" ]
  _sub=$(grep '^note_count:' "${PROFILE_ROOT}/dev/fe/_index.md" | awk '{print $2}')
  [ "$_sub" = "3" ]
  _cat=$(grep '^note_count:' "${PROFILE_ROOT}/dev/_index.md" | awk '{print $2}')
  [ "$_cat" = "3" ]
}

@test "add: tree.json all ancestor nodes get +1" {
  _path="${PROFILE_ROOT}/dev/fe/react/x.md"
  _mknote "$_path" "dev" "fe" "react"
  update_index_on_add "$_path"
  _f="${WJ_SB_HOME}/cache/tree.json"
  [ "$(jq -r '.tree.dev.note_count' "$_f")" = "1" ]
  [ "$(jq -r '.tree.dev.subtopics.fe.note_count' "$_f")" = "1" ]
  [ "$(jq -r '.tree.dev.subtopics.fe.subtopics.react.note_count' "$_f")" = "1" ]
}

@test "add: korean category names work" {
  _p="${PROFILE_ROOT}/개발/프론트엔드/react/k.md"
  _mknote "$_p" "개발" "프론트엔드" "react"
  update_index_on_add "$_p"
  _cnt=$(jq -r '.tree."개발".subtopics."프론트엔드".subtopics.react.note_count' \
    "${WJ_SB_HOME}/cache/tree.json")
  [ "$_cnt" = "1" ]
}

# ── update_index_on_remove ──────────────────────────────────────

@test "remove: 10 add then 5 remove yields note_count 5" {
  for _i in $(seq 1 10); do
    _p="${PROFILE_ROOT}/dev/fe/react/n${_i}.md"
    _mknote "$_p" "dev" "fe" "react"
    update_index_on_add "$_p"
  done
  for _i in $(seq 1 5); do
    _p="${PROFILE_ROOT}/dev/fe/react/n${_i}.md"
    update_index_on_remove "$_p"
    rm -f "$_p"
  done
  _cnt=$(jq -r '.tree.dev.subtopics.fe.subtopics.react.note_count' \
    "${WJ_SB_HOME}/cache/tree.json")
  [ "$_cnt" = "5" ]
  _leaf=$(grep '^note_count:' "${PROFILE_ROOT}/dev/fe/react/_index.md" | awk '{print $2}')
  [ "$_leaf" = "5" ]
}

@test "remove: parent _index.md also -1" {
  _p1="${PROFILE_ROOT}/dev/fe/react/a.md"
  _p2="${PROFILE_ROOT}/dev/fe/react/b.md"
  _mknote "$_p1" "dev" "fe" "react"
  _mknote "$_p2" "dev" "fe" "react"
  update_index_on_add "$_p1"
  update_index_on_add "$_p2"
  update_index_on_remove "$_p1"; rm -f "$_p1"
  _sub=$(grep '^note_count:' "${PROFILE_ROOT}/dev/fe/_index.md" | awk '{print $2}')
  [ "$_sub" = "1" ]
}

# ── update_index_on_move ────────────────────────────────────────

@test "move: both folders _index.md updated" {
  _from="${PROFILE_ROOT}/dev/fe/react/m.md"
  _mknote "$_from" "dev" "fe" "react"
  update_index_on_add "$_from"
  _to="${PROFILE_ROOT}/dev/fe/vue/m.md"
  _mknote "$_to" "dev" "fe" "vue"
  update_index_on_move "$_from" "$_to"
  rm -f "$_from"
  _f="${WJ_SB_HOME}/cache/tree.json"
  [ "$(jq -r '.tree.dev.subtopics.fe.subtopics.react.note_count' "$_f")" = "0" ]
  [ "$(jq -r '.tree.dev.subtopics.fe.subtopics.vue.note_count' "$_f")" = "1" ]
  [ "$(jq -r '.tree.dev.subtopics.fe.note_count' "$_f")" = "1" ]
}

# ── unsorted ────────────────────────────────────────────────────

@test "unsorted: 3x increment yields 3" {
  update_tree_unsorted_increment
  update_tree_unsorted_increment
  update_tree_unsorted_increment
  _u=$(jq -r '.unsorted_count' "${WJ_SB_HOME}/cache/tree.json")
  [ "$_u" = "3" ]
}

@test "unsorted: decrement floors at 0" {
  update_tree_unsorted_increment
  update_tree_unsorted_decrement
  update_tree_unsorted_decrement
  update_tree_unsorted_decrement
  _u=$(jq -r '.unsorted_count' "${WJ_SB_HOME}/cache/tree.json")
  [ "$_u" = "0" ]
}

@test "unsorted: set absolute value" {
  update_tree_unsorted_set 42
  _u=$(jq -r '.unsorted_count' "${WJ_SB_HOME}/cache/tree.json")
  [ "$_u" = "42" ]
}

# ── full rebuild ────────────────────────────────────────────────

@test "rebuild: incremental result matches rebuild result (consistency)" {
  for _i in $(seq 1 5); do
    _p="${PROFILE_ROOT}/dev/fe/react/r${_i}.md"
    _mknote "$_p" "dev" "fe" "react"
    update_index_on_add "$_p"
  done
  for _i in $(seq 1 3); do
    _p="${PROFILE_ROOT}/design/typo/serif/d${_i}.md"
    _mknote "$_p" "design" "typo" "serif"
    update_index_on_add "$_p"
  done
  _incr=$(jq -S '.tree' "${WJ_SB_HOME}/cache/tree.json")
  update_tree_full_rebuild "testprof"
  _rebuilt=$(jq -S '.tree' "${WJ_SB_HOME}/cache/tree.json")
  [ "$_incr" = "$_rebuilt" ]
}

@test "rebuild: preserves unsorted_count" {
  update_tree_unsorted_set 7
  _p="${PROFILE_ROOT}/dev/fe/react/x.md"
  _mknote "$_p" "dev" "fe" "react"
  update_index_on_add "$_p"
  update_tree_full_rebuild "testprof"
  _u=$(jq -r '.unsorted_count' "${WJ_SB_HOME}/cache/tree.json")
  [ "$_u" = "7" ]
}

# ── _index.md AUTO region preservation ──────────────────────────

@test "auto: user content preserved, only AUTO region updated" {
  _p="${PROFILE_ROOT}/dev/fe/react/u.md"
  _mknote "$_p" "dev" "fe" "react"
  update_index_on_add "$_p"
  _idx="${PROFILE_ROOT}/dev/fe/react/_index.md"
  cat >> "$_idx" <<'USEREOF'

## user memo
this region must never disappear.
USEREOF
  _p2="${PROFILE_ROOT}/dev/fe/react/u2.md"
  _mknote "$_p2" "dev" "fe" "react"
  update_index_on_add "$_p2"
  grep -q "user memo" "$_idx"
  grep -q "this region must never disappear" "$_idx"
  _cnt=$(grep '^note_count:' "$_idx" | awk '{print $2}')
  [ "$_cnt" = "2" ]
}

# ── idempotency ────────────────────────────────────────────────

@test "idempotency: add then remove same note nets to 0" {
  _p="${PROFILE_ROOT}/dev/fe/react/i.md"
  _mknote "$_p" "dev" "fe" "react"
  update_index_on_add "$_p"
  update_index_on_remove "$_p"
  _cnt=$(jq -r '.tree.dev.subtopics.fe.subtopics.react.note_count' \
    "${WJ_SB_HOME}/cache/tree.json")
  [ "$_cnt" = "0" ]
}

# ── concurrency (lockfile) ──────────────────────────────────────

@test "concurrency: parallel add 10 yields exactly 10 (no race)" {
  _pids=""
  for _i in $(seq 1 10); do
    _p="${PROFILE_ROOT}/dev/fe/react/c${_i}.md"
    _mknote "$_p" "dev" "fe" "react"
    ( source "$SCHEMA_SH"; source "$IDX_SH"; update_index_on_add "$_p" ) &
    _pids="$_pids $!"
  done
  for _pid in $_pids; do wait "$_pid"; done
  _cnt=$(jq -r '.tree.dev.subtopics.fe.subtopics.react.note_count' \
    "${WJ_SB_HOME}/cache/tree.json")
  [ "$_cnt" = "10" ]
}
