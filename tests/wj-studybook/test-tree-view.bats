#!/usr/bin/env bats
# test-tree-view.bats — wj-studybook lib/tree-view.sh unit tests
# Note: 테스트명은 ASCII만, 데이터/카테고리는 한글 가능.

setup() {
  LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-studybook/lib" && pwd)"
  TMP="$(mktemp -d)"
  export STUDYBOOK_HOME="${TMP}/sb"
  export WJ_SB_HOME="$STUDYBOOK_HOME"
  export WJ_SB_PROFILE="woojoo"
  mkdir -p "$WJ_SB_HOME/profiles" "$WJ_SB_HOME/cache"
  cat > "$WJ_SB_HOME/config.yaml" <<'EOF'
active_profile: woojoo
EOF
  cat > "$WJ_SB_HOME/profiles/woojoo.yaml" <<'EOF'
name: woojoo
level: intermediate
language: ko
EOF
  # shellcheck source=/dev/null
  source "${LIB_DIR}/config-helpers.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/tree-view.sh"

  TREE_FILE="$WJ_SB_HOME/cache/tree.json"
}

teardown() { rm -rf "$TMP"; }

# helper: spec 예시 수준의 tree.json 작성 (subtopics 구조)
_mk_tree_full() {
  cat > "$TREE_FILE" <<'EOF'
{
  "schema": "studybook.tree/v1",
  "generated_at": "2026-04-16T15:01:00+09:00",
  "active_profile": "woojoo",
  "unsorted_count": 5,
  "tree": {
    "개발": {
      "note_count": 47,
      "subtopics": {
        "프론트엔드": {
          "note_count": 24,
          "subtopics": {
            "react": { "note_count": 18, "subtopics": {} },
            "css":   { "note_count": 6,  "subtopics": {} }
          }
        },
        "백엔드": {
          "note_count": 23,
          "subtopics": {
            "api-design": { "note_count": 10, "subtopics": {} },
            "database":   { "note_count": 13, "subtopics": {} }
          }
        }
      }
    },
    "알고리즘": {
      "note_count": 8,
      "subtopics": {
        "다이나믹-프로그래밍": { "note_count": 8, "subtopics": {} }
      }
    }
  }
}
EOF
}

# helper: 빈 트리 (unsorted만 있음)
_mk_tree_empty() {
  cat > "$TREE_FILE" <<'EOF'
{
  "schema": "studybook.tree/v1",
  "generated_at": "2026-04-16T09:00:00+09:00",
  "active_profile": "woojoo",
  "unsorted_count": 0,
  "tree": {}
}
EOF
}

# ── tree_render: 기본 동작 ──────────────────────────────────────

@test "render: missing tree.json returns non-zero with stderr" {
  run tree_render "$TREE_FILE" 3
  [ "$status" -ne 0 ]
  [[ "$output" == *"tree-view.sh"* ]]
}

@test "render: default depth shows profile header with level/language" {
  _mk_tree_full
  run tree_render "$TREE_FILE" 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"woojoo"* ]]
  [[ "$output" == *"intermediate"* ]]
  [[ "$output" == *"ko"* ]]
}

@test "render: shows unsorted inbox count when > 0" {
  _mk_tree_full
  run tree_render "$TREE_FILE" 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"미분류 inbox: 5"* ]]
}

@test "render: omits unsorted inbox when 0" {
  _mk_tree_empty
  run tree_render "$TREE_FILE" 3
  [ "$status" -eq 0 ]
  [[ "$output" != *"미분류 inbox:"* ]]
}

@test "render: shows last updated timestamp" {
  _mk_tree_full
  run tree_render "$TREE_FILE" 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"마지막 갱신"* ]]
  [[ "$output" == *"2026-04-16"* ]]
}

# ── depth 제한 ─────────────────────────────────────────────────

@test "render: depth=0 shows only profile header" {
  _mk_tree_full
  run tree_render "$TREE_FILE" 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"woojoo"* ]]
  [[ "$output" != *"개발"* ]]
  [[ "$output" != *"프론트엔드"* ]]
  [[ "$output" != *"react"* ]]
}

@test "render: depth=1 shows categories only" {
  _mk_tree_full
  run tree_render "$TREE_FILE" 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"개발"* ]]
  [[ "$output" == *"알고리즘"* ]]
  [[ "$output" == *"(47)"* ]]
  [[ "$output" == *"(8)"* ]]
  [[ "$output" != *"프론트엔드"* ]]
  [[ "$output" != *"react"* ]]
}

@test "render: depth=2 shows categories and subcategories" {
  _mk_tree_full
  run tree_render "$TREE_FILE" 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"개발"* ]]
  [[ "$output" == *"프론트엔드"* ]]
  [[ "$output" == *"백엔드"* ]]
  [[ "$output" == *"다이나믹-프로그래밍"* ]]
  [[ "$output" != *"react"* ]]
  [[ "$output" != *"api-design"* ]]
}

@test "render: depth=3 shows full tree including topics" {
  _mk_tree_full
  run tree_render "$TREE_FILE" 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"개발"* ]]
  [[ "$output" == *"프론트엔드"* ]]
  [[ "$output" == *"react"* ]]
  [[ "$output" == *"css"* ]]
  [[ "$output" == *"api-design"* ]]
  [[ "$output" == *"database"* ]]
  [[ "$output" == *"(18)"* ]]
  [[ "$output" == *"(13)"* ]]
}

# ── ASCII 박스 드로잉 문자 ─────────────────────────────────────

@test "render: uses box-drawing branch characters" {
  _mk_tree_full
  run tree_render "$TREE_FILE" 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"├──"* ]]
  [[ "$output" == *"└──"* ]]
}

@test "render: uses book emoji for root and folder emoji for categories" {
  _mk_tree_full
  run tree_render "$TREE_FILE" 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"📚"* ]]
  [[ "$output" == *"📁"* ]]
}

# ── JSON 모드 ──────────────────────────────────────────────────

@test "render_json: dumps tree.json pretty" {
  _mk_tree_full
  run tree_render_json "$TREE_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"schema\""* ]]
  [[ "$output" == *"studybook.tree/v1"* ]]
  [[ "$output" == *"개발"* ]]
  [[ "$output" == *"react"* ]]
}

@test "render_json: missing file returns non-zero" {
  run tree_render_json "$TREE_FILE"
  [ "$status" -ne 0 ]
}

# ── CLI 엔트리 ─────────────────────────────────────────────────

@test "cli: no args prints default depth-3 tree" {
  _mk_tree_full
  run tree_cli
  [ "$status" -eq 0 ]
  [[ "$output" == *"woojoo"* ]]
  [[ "$output" == *"개발"* ]]
  [[ "$output" == *"react"* ]]
}

@test "cli: --depth 1 limits output" {
  _mk_tree_full
  run tree_cli --depth 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"개발"* ]]
  [[ "$output" != *"프론트엔드"* ]]
}

@test "cli: --depth 2 shows through subcategories" {
  _mk_tree_full
  run tree_cli --depth 2
  [ "$status" -eq 0 ]
  [[ "$output" == *"프론트엔드"* ]]
  [[ "$output" != *"react"* ]]
}

@test "cli: --json mode outputs JSON" {
  _mk_tree_full
  run tree_cli --json
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"schema\""* ]]
  [[ "$output" == *"\"tree\""* ]]
}

@test "cli: invalid --depth returns non-zero" {
  _mk_tree_full
  run tree_cli --depth abc
  [ "$status" -ne 0 ]
}

@test "cli: missing tree.json shows friendly error" {
  run tree_cli
  [ "$status" -ne 0 ]
  [[ "$output" == *"tree-view.sh"* ]]
}

# ── 엣지 케이스 ─────────────────────────────────────────────────

@test "render: empty tree shows only header (no category rows)" {
  _mk_tree_empty
  run tree_render "$TREE_FILE" 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"woojoo"* ]]
  [[ "$output" != *"├──"* ]]
  [[ "$output" != *"└──"* ]]
}

@test "render: last sibling uses elbow connector" {
  _mk_tree_full
  run tree_render "$TREE_FILE" 1
  [ "$status" -eq 0 ]
  # '알고리즘'이 마지막 카테고리 → └── 로 시작하는 라인 존재
  printf '%s\n' "$output" | grep -q '└── 📁 알고리즘'
}

@test "render: non-last sibling uses tee connector" {
  _mk_tree_full
  run tree_render "$TREE_FILE" 1
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -q '├── 📁 개발'
}

@test "render: nested vertical pipe for depth 3 children under non-last parent" {
  _mk_tree_full
  run tree_render "$TREE_FILE" 3
  [ "$status" -eq 0 ]
  # '개발'은 마지막 아님 → 자식 라인은 '│'로 시작
  printf '%s\n' "$output" | grep -q '│'
}

@test "render: utf-8 category name safe" {
  cat > "$TREE_FILE" <<'EOF'
{
  "schema": "studybook.tree/v1",
  "generated_at": "2026-04-16T10:00:00+09:00",
  "active_profile": "woojoo",
  "unsorted_count": 0,
  "tree": {
    "한글카테고리": {
      "note_count": 3,
      "subtopics": {
        "하위-주제": { "note_count": 3, "subtopics": {} }
      }
    }
  }
}
EOF
  run tree_render "$TREE_FILE" 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"한글카테고리"* ]]
  [[ "$output" == *"하위-주제"* ]]
  [[ "$output" == *"(3)"* ]]
}
