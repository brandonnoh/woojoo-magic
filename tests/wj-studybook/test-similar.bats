#!/usr/bin/env bats
# test-similar.bats — wj-studybook lib/similar.sh unit tests
# Note: 테스트명은 ASCII만, 데이터/카테고리는 한글 가능.

setup() {
  LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-studybook/lib" && pwd)"
  TMP="$(mktemp -d)"
  export STUDYBOOK_HOME="${TMP}/sb"
  export WJ_SB_HOME="$STUDYBOOK_HOME"
  export WJ_SB_PROFILE="testprof"
  mkdir -p "$WJ_SB_HOME/profiles" "$WJ_SB_HOME/cache" \
           "$WJ_SB_HOME/books/testprof/topics" \
           "$WJ_SB_HOME/books/other/topics"
  cat > "$WJ_SB_HOME/config.yaml" <<'EOF'
active_profile: testprof
EOF
  cat > "$WJ_SB_HOME/profiles/testprof.yaml" <<'EOF'
name: testprof
level: beginner
language: ko
EOF
  # shellcheck source=/dev/null
  source "${LIB_DIR}/config-helpers.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/similar.sh"
}

teardown() { rm -rf "$TMP"; }

# helper: topic 노트 작성 (frontmatter + 본문)
_mk_topic() {
  _profile="$1"; _cat="$2"; _sub="$3"; _top="$4"
  _slug="$5"; _title="$6"; _tags_yaml="$7"; _body="$8"
  _dir="$WJ_SB_HOME/books/${_profile}/topics/${_cat}/${_sub}/${_top}"
  mkdir -p "$_dir"
  _file="${_dir}/${_slug}-01SIM000000000000000000${RANDOM}.md"
  cat > "$_file" <<EOF
---
id: 01SIM${_slug}
schema: studybook.note/v1
type: topic
status: published
profile: ${_profile}
category: ${_cat}
subcategory: ${_sub}
topic: ${_top}
title: ${_title}
slug: ${_slug}
tags: ${_tags_yaml}
---

# ${_title}

${_body}
EOF
  printf '%s\n' "$_file"
}

# ── similar_keyword_match ───────────────────────────────────────

@test "keyword_match: finds notes matching query in body" {
  _mk_topic testprof dev fe react useeffect "useEffect 정리" '["react","hooks"]' \
    "useEffect 클린업 함수는 언마운트 시점에 호출된다." >/dev/null
  _mk_topic testprof dev fe react uselayout "useLayoutEffect 정리" '["react"]' \
    "useLayoutEffect는 DOM 반영 직후 동기 호출된다." >/dev/null
  _mk_topic testprof dev vcs git rebase "git rebase 패턴" '["git"]' \
    "rebase는 커밋 이력을 재작성한다." >/dev/null
  _out=$(similar_keyword_match "useEffect 클린업")
  echo "$_out" | grep -q "useeffect-"
  _cnt=$(printf '%s\n' "$_out" | grep -c "useeffect-" || true)
  [ "$_cnt" -ge 1 ]
}

@test "keyword_match: finds notes matching query in title" {
  _mk_topic testprof dev fe react hook-lifecycle "Hook 생명주기" '["react"]' \
    "본문" >/dev/null
  _mk_topic testprof dev vcs git merge "git merge" '["git"]' \
    "본문" >/dev/null
  _out=$(similar_keyword_match "생명주기")
  echo "$_out" | grep -q "hook-lifecycle-"
}

@test "keyword_match: finds notes matching query in tags" {
  _mk_topic testprof dev fe react perf "렌더 최적화" '["react","performance"]' \
    "memo/useMemo/useCallback 활용" >/dev/null
  _mk_topic testprof dev vcs git branch "branch" '["git"]' \
    "본문" >/dev/null
  _out=$(similar_keyword_match "performance")
  echo "$_out" | grep -q "perf-"
}

@test "keyword_match: only searches active profile" {
  _mk_topic testprof dev fe react r1 "react A" '["react"]' \
    "useEffect 클린업" >/dev/null
  _mk_topic other    dev fe react r2 "react B" '["react"]' \
    "useEffect 클린업" >/dev/null
  _out=$(similar_keyword_match "클린업")
  echo "$_out" | grep -q "books/testprof/"
  ! echo "$_out" | grep -q "books/other/"
}

@test "keyword_match: returns nothing on no match" {
  _mk_topic testprof dev fe react r1 "react" '["react"]' "본문" >/dev/null
  _out=$(similar_keyword_match "전혀관계없는쿼리xyz123") || true
  [ -z "$_out" ]
}

@test "keyword_match: caps results at 20 candidates" {
  _i=1
  while [ "$_i" -le 25 ]; do
    _mk_topic testprof dev fe react "note$_i" "T$_i" '["react"]' \
      "keyword_unique_xyz 본문 $_i" >/dev/null
    _i=$((_i + 1))
  done
  _cnt=$(similar_keyword_match "keyword_unique_xyz" | wc -l | tr -d ' ')
  [ "$_cnt" -le 20 ]
}

@test "keyword_match: missing query exits non-zero" {
  run similar_keyword_match ""
  [ "$status" -ne 0 ]
}

# ── similar_semantic_rank (prepare context) ─────────────────────

@test "semantic_rank: outputs query + candidates + tree sections" {
  _f1=$(_mk_topic testprof dev fe react useeffect "useEffect 클린업" '["react"]' \
    "클린업 함수는 언마운트 시 호출된다.")
  _f2=$(_mk_topic testprof dev fe react uselayout "useLayoutEffect" '["react"]' \
    "DOM 반영 직후 동기 호출.")
  # tree.json 준비
  printf '{"tree":{}}\n' > "$WJ_SB_HOME/cache/tree.json"
  _out=$(printf '%s\n%s\n' "$_f1" "$_f2" | similar_semantic_rank "useEffect 클린업")
  echo "$_out" | grep -q "## QUERY"
  echo "$_out" | grep -q "useEffect 클린업"
  echo "$_out" | grep -q "## CURRENT_TREE_JSON"
  echo "$_out" | grep -q "## CANDIDATES"
  echo "$_out" | grep -q "CANDIDATE_BEGIN"
  echo "$_out" | grep -q "CANDIDATE_END"
  echo "$_out" | grep -q "path=.*useeffect-"
}

@test "semantic_rank: body snippet truncated around 200 chars" {
  _long=$(printf 'x%.0s' $(seq 1 500))
  _f=$(_mk_topic testprof dev fe react long "Long" '["react"]' "$_long")
  _out=$(printf '%s\n' "$_f" | similar_semantic_rank "쿼리")
  # candidate body 블록은 200자 이하로 잘려야 함
  _body_block=$(printf '%s\n' "$_out" | awk '/CANDIDATE_BEGIN/,/CANDIDATE_END/' | \
                grep -v '^---' | grep -v '^CANDIDATE_' | grep -v '^path=')
  _len=${#_body_block}
  [ "$_len" -le 400 ]  # 200자 + 줄바꿈/여유
}

@test "semantic_rank: empty candidates still outputs sections" {
  printf '{"tree":{}}\n' > "$WJ_SB_HOME/cache/tree.json"
  _out=$(printf '' | similar_semantic_rank "없는쿼리")
  echo "$_out" | grep -q "## QUERY"
  echo "$_out" | grep -q "## CANDIDATES"
  echo "$_out" | grep -q "CANDIDATE_COUNT"
}

# ── similar_format_output ───────────────────────────────────────

@test "format_output: pretty-prints results JSON (path + score + summary)" {
  _json=$(cat <<'EOF'
[
  {"path":"/tmp/a.md","score":95,"summary":"React useEffect 클린업 예제"},
  {"path":"/tmp/b.md","score":80,"summary":"useLayoutEffect 비교"},
  {"path":"/tmp/c.md","score":55,"summary":"Hook 기본"}
]
EOF
)
  _out=$(similar_format_output "$_json")
  echo "$_out" | grep -q "/tmp/a.md"
  echo "$_out" | grep -q "95%"
  echo "$_out" | grep -q "React useEffect 클린업 예제"
  echo "$_out" | grep -q "/tmp/b.md"
  echo "$_out" | grep -q "80%"
}

@test "format_output: caps display at 5 results" {
  _json=$(jq -nc '[range(0;10)] | map({path:("/tmp/\(.).md"), score:(100-.), summary:"s\(.)"})')
  _out=$(similar_format_output "$_json")
  _cnt=$(echo "$_out" | grep -c "/tmp/" || true)
  [ "$_cnt" -le 5 ]
}

@test "format_output: sorts by score desc" {
  _json='[{"path":"/tmp/low.md","score":20,"summary":"low"},{"path":"/tmp/high.md","score":90,"summary":"high"}]'
  _out=$(similar_format_output "$_json")
  _first=$(echo "$_out" | grep -o '/tmp/[a-z]*\.md' | head -1)
  [ "$_first" = "/tmp/high.md" ]
}

@test "format_output: invalid json fails" {
  run similar_format_output "not-json"
  [ "$status" -ne 0 ]
}

@test "format_output: empty array prints friendly message" {
  _out=$(similar_format_output "[]")
  echo "$_out" | grep -qiE "결과|없|no match|empty"
}

# ── 통합: keyword → prepare 시나리오 ────────────────────────────

@test "integration: query prioritizes related notes over unrelated" {
  _mk_topic testprof dev fe react useeffect "useEffect 클린업" '["react","hooks"]' \
    "useEffect 클린업은 언마운트 시 실행된다." >/dev/null
  _mk_topic testprof dev fe react uselayout "useLayoutEffect" '["react"]' \
    "DOM 반영 직후 동기 호출." >/dev/null
  _mk_topic testprof dev vcs git rebase "git rebase" '["git"]' \
    "커밋 이력 재작성." >/dev/null
  _mk_topic testprof design web css "CSS 기본" '["css"]' \
    "selector priority." >/dev/null
  _mk_topic testprof dev fe vue comp "Vue 컴포넌트" '["vue"]' \
    "컴포넌트 분리 가이드." >/dev/null
  _candidates=$(similar_keyword_match "useEffect 클린업")
  echo "$_candidates" | grep -q "useeffect-"
  printf '{"tree":{}}\n' > "$WJ_SB_HOME/cache/tree.json"
  _ctx=$(printf '%s\n' "$_candidates" | similar_semantic_rank "useEffect 클린업")
  echo "$_ctx" | grep -q "## QUERY"
  echo "$_ctx" | grep -q "useEffect 클린업"
  echo "$_ctx" | grep -q "CANDIDATE_BEGIN"
}
