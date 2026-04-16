#!/usr/bin/env bats
# test-merge.bats — wj-studybook lib/merge.sh unit tests (s12)
# Note: 테스트명은 ASCII만, 데이터/카테고리는 한글 가능.

setup() {
  LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-studybook/lib" && pwd)"
  TMP="$(mktemp -d)"
  export STUDYBOOK_HOME="${TMP}/sb"
  export WJ_SB_HOME="$STUDYBOOK_HOME"
  export WJ_SB_PROFILE="testprof"
  PROFILE_ROOT="${WJ_SB_HOME}/books/testprof/topics"
  mkdir -p "$WJ_SB_HOME/profiles" "$WJ_SB_HOME/cache" "$PROFILE_ROOT"
  cat > "$WJ_SB_HOME/config.yaml" <<'EOF'
active_profile: testprof
EOF
  cat > "$WJ_SB_HOME/profiles/testprof.yaml" <<'EOF'
name: testprof
level: beginner
language: ko
EOF
  # shellcheck source=/dev/null
  source "${LIB_DIR}/schema.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/config-helpers.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/index-update.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/merge.sh"
}

teardown() { rm -rf "$TMP"; }

# helper: topic 노트 작성 (frontmatter + 본문) + tree.json/_index.md 갱신
# 주의: 변수명은 라이브러리 함수들과 충돌하지 않도록 _mkt_* 네임스페이스 사용.
_mk_topic() {
  _mkt_cat="$1"; _mkt_sub="$2"; _mkt_top="$3"; _mkt_slug="$4"; _mkt_title="$5"
  _mkt_dir="${PROFILE_ROOT}/${_mkt_cat}/${_mkt_sub}/${_mkt_top}"
  mkdir -p "$_mkt_dir"
  _mkt_file="${_mkt_dir}/${_mkt_slug}-01MG$(printf '%020d' $RANDOM).md"
  cat > "$_mkt_file" <<EOF
---
id: 01MG${_mkt_slug}
schema: studybook.note/v1
type: topic
status: published
profile: testprof
category: ${_mkt_cat}
subcategory: ${_mkt_sub}
topic: ${_mkt_top}
title: ${_mkt_title}
slug: ${_mkt_slug}
level: beginner
language: ko
tags: ["t"]
sources: []
---

# ${_mkt_title}

본문 샘플.
EOF
  update_index_on_add "$_mkt_file"
  printf '%s\n' "$_mkt_file"
}

# ── merge_detect_prepare: Claude 컨텍스트 패키징 ────────────────

@test "detect_prepare: outputs TREE_DUMP + FOLDERS sections" {
  _mk_topic "개발" "프론트엔드" "react" "r1" "React T1" >/dev/null
  _mk_topic "개발" "프론트엔드" "리액트" "r2" "리액트 T2" >/dev/null
  _out=$(merge_detect_prepare)
  echo "$_out" | grep -q "## ACTIVE_PROFILE"
  echo "$_out" | grep -q "testprof"
  echo "$_out" | grep -q "## TREE_DUMP"
  echo "$_out" | grep -q "## FOLDERS"
  echo "$_out" | grep -q "react"
  echo "$_out" | grep -q "리액트"
  echo "$_out" | grep -q "## INSTRUCTIONS"
}

@test "detect_prepare: lists folder paths with note counts" {
  _mk_topic "개발" "프론트엔드" "react" "r1" "R1" >/dev/null
  _mk_topic "개발" "프론트엔드" "react" "r2" "R2" >/dev/null
  _mk_topic "개발" "프론트엔드" "리액트" "r3" "R3" >/dev/null
  _out=$(merge_detect_prepare)
  echo "$_out" | grep -Eq "react.*notes=2|note_count=2"
  echo "$_out" | grep -Eq "리액트.*notes=1|note_count=1"
}

@test "detect_prepare: works with empty tree (no folders)" {
  _out=$(merge_detect_prepare)
  echo "$_out" | grep -q "## FOLDERS"
  echo "$_out" | grep -q "## INSTRUCTIONS"
}

# ── merge_apply: 강제 병합 ──────────────────────────────────────

@test "apply: moves all notes from 'from' to 'to' with --yes" {
  _f1=$(_mk_topic "개발" "프론트엔드" "리액트" "n1" "N1")
  _f2=$(_mk_topic "개발" "프론트엔드" "리액트" "n2" "N2")
  _ka=$(_mk_topic "개발" "프론트엔드" "react" "k1" "K1")

  _tf_from="${PROFILE_ROOT}/개발/프론트엔드/리액트"
  _tf_to="${PROFILE_ROOT}/개발/프론트엔드/react"

  merge_apply "$_tf_from" "$_tf_to" --yes

  # 원 from 디렉토리에는 노트가 남지 않아야 함
  [ ! -f "$_f1" ]
  [ ! -f "$_f2" ]
  # to 디렉토리에 노트 3개 있어야 함
  _cnt=$(find "$_tf_to" -type f -name '*.md' ! -name '_index.md' | wc -l | tr -d ' ')
  [ "$_cnt" = "3" ]
}

@test "apply: from folder removed when empty after merge" {
  _mk_topic "개발" "프론트엔드" "리액트" "n1" "N1" >/dev/null
  _mk_topic "개발" "프론트엔드" "react" "k1" "K1" >/dev/null
  _tf_from="${PROFILE_ROOT}/개발/프론트엔드/리액트"
  _tf_to="${PROFILE_ROOT}/개발/프론트엔드/react"
  merge_apply "$_tf_from" "$_tf_to" --yes
  [ ! -d "$_tf_from" ]
}

@test "apply: updates frontmatter category/subcategory/topic on moved notes" {
  _f1=$(_mk_topic "개발" "프론트엔드" "리액트" "n1" "N1")
  _mk_topic "개발" "프론트엔드" "react" "k1" "K1" >/dev/null

  _tf_from="${PROFILE_ROOT}/개발/프론트엔드/리액트"
  _tf_to="${PROFILE_ROOT}/개발/프론트엔드/react"
  merge_apply "$_tf_from" "$_tf_to" --yes

  # moved 파일은 to 하위에 존재해야 함 (basename 동일)
  _moved=$(find "$_tf_to" -type f -name "$(basename "$_f1")")
  [ -n "$_moved" ]
  grep -q "^topic: react" "$_moved"
  grep -q "^category: 개발" "$_moved"
  grep -q "^subcategory: 프론트엔드" "$_moved"
}

@test "apply: tree.json reflects merged counts" {
  _mk_topic "개발" "프론트엔드" "리액트" "n1" "N1" >/dev/null
  _mk_topic "개발" "프론트엔드" "리액트" "n2" "N2" >/dev/null
  _mk_topic "개발" "프론트엔드" "react" "k1" "K1" >/dev/null

  _tf_from="${PROFILE_ROOT}/개발/프론트엔드/리액트"
  _tf_to="${PROFILE_ROOT}/개발/프론트엔드/react"
  merge_apply "$_tf_from" "$_tf_to" --yes

  _tf="${WJ_SB_HOME}/cache/tree.json"
  _react=$(jq -r '.tree."개발".subtopics."프론트엔드".subtopics.react.note_count' "$_tf")
  [ "$_react" = "3" ]
  _ria=$(jq -r '.tree."개발".subtopics."프론트엔드".subtopics."리액트".note_count // 0' "$_tf")
  [ "$_ria" = "0" ]
}

@test "apply: to _index.md note_count accumulates" {
  _mk_topic "개발" "프론트엔드" "리액트" "n1" "N1" >/dev/null
  _mk_topic "개발" "프론트엔드" "react" "k1" "K1" >/dev/null
  _tf_from="${PROFILE_ROOT}/개발/프론트엔드/리액트"
  _tf_to="${PROFILE_ROOT}/개발/프론트엔드/react"
  merge_apply "$_tf_from" "$_tf_to" --yes
  _cnt=$(grep '^note_count:' "${_tf_to}/_index.md" | awk '{print $2}')
  [ "$_cnt" = "2" ]
}

@test "apply: nonexistent from directory fails" {
  mkdir -p "${PROFILE_ROOT}/개발/프론트엔드/react"
  run merge_apply "${PROFILE_ROOT}/없는경로/없음" "${PROFILE_ROOT}/개발/프론트엔드/react" --yes
  [ "$status" -ne 0 ]
}

@test "apply: same from and to fails" {
  _mk_topic "개발" "프론트엔드" "react" "k1" "K1" >/dev/null
  _tf_to="${PROFILE_ROOT}/개발/프론트엔드/react"
  run merge_apply "$_tf_to" "$_tf_to" --yes
  [ "$status" -ne 0 ]
}

@test "apply: empty from directory merges to empty but succeeds" {
  mkdir -p "${PROFILE_ROOT}/개발/프론트엔드/리액트"
  _mk_topic "개발" "프론트엔드" "react" "k1" "K1" >/dev/null
  _tf_from="${PROFILE_ROOT}/개발/프론트엔드/리액트"
  _tf_to="${PROFILE_ROOT}/개발/프론트엔드/react"
  run merge_apply "$_tf_from" "$_tf_to" --yes
  [ "$status" -eq 0 ]
  [ ! -d "$_tf_from" ]
}

@test "apply: missing args fails" {
  run merge_apply ""
  [ "$status" -ne 0 ]
  run merge_apply "$PROFILE_ROOT/a"
  [ "$status" -ne 0 ]
}

@test "apply: creates to directory if not exists" {
  _f1=$(_mk_topic "개발" "프론트엔드" "리액트" "n1" "N1")
  _tf_from="${PROFILE_ROOT}/개발/프론트엔드/리액트"
  _tf_to="${PROFILE_ROOT}/개발/프론트엔드/react"
  # react 폴더가 처음엔 없음
  [ ! -d "$_tf_to" ]
  merge_apply "$_tf_from" "$_tf_to" --yes
  [ -d "$_tf_to" ]
  _cnt=$(find "$_tf_to" -type f -name '*.md' ! -name '_index.md' | wc -l | tr -d ' ')
  [ "$_cnt" = "1" ]
}

# ── 통합 시나리오 ──────────────────────────────────────────────

@test "integration: detect_prepare lists two synonym folders, apply merges them" {
  _mk_topic "개발" "프론트엔드" "리액트" "n1" "N1" >/dev/null
  _mk_topic "개발" "프론트엔드" "리액트" "n2" "N2" >/dev/null
  _mk_topic "개발" "프론트엔드" "react" "k1" "K1" >/dev/null
  _mk_topic "개발" "프론트엔드" "react" "k2" "K2" >/dev/null
  _mk_topic "개발" "프론트엔드" "react" "k3" "K3" >/dev/null

  _ctx=$(merge_detect_prepare)
  echo "$_ctx" | grep -q "react"
  echo "$_ctx" | grep -q "리액트"

  # 사용자/Claude가 병합 결정 → apply (react로 통합, 노트가 더 많은 쪽 관례)
  _tf_from="${PROFILE_ROOT}/개발/프론트엔드/리액트"
  _tf_to="${PROFILE_ROOT}/개발/프론트엔드/react"
  merge_apply "$_tf_from" "$_tf_to" --yes

  _tf="${WJ_SB_HOME}/cache/tree.json"
  _cnt=$(jq -r '.tree."개발".subtopics."프론트엔드".subtopics.react.note_count' "$_tf")
  [ "$_cnt" = "5" ]
  [ ! -d "$_tf_from" ]
}
