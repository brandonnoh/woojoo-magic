#!/usr/bin/env bats
# test-publish.bats — wj-studybook lib/publish.sh + book-writer.sh unit tests (s13)
# Note: 테스트명은 ASCII만. 데이터/카테고리는 한글 가능.

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
level: intermediate
language: ko
tone: neutral
age_group: adult
book_style: standard
EOF
  # shellcheck source=/dev/null
  source "${LIB_DIR}/schema.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/config-helpers.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/index-update.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/book-writer.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/publish.sh"
}

teardown() { rm -rf "$TMP"; }

# helper: 특정 captured_at 날짜로 topic 노트 작성
# args: cat, sub, top, slug, title, captured_at (YYYY-MM-DD), [body]
_mk_topic_at() {
  _mkt_cat="$1"; _mkt_sub="$2"; _mkt_top="$3"; _mkt_slug="$4"
  _mkt_title="$5"; _mkt_day="$6"; _mkt_body="${7:-본문 샘플 단어 반복 테스트.}"
  _mkt_dir="${PROFILE_ROOT}/${_mkt_cat}/${_mkt_sub}/${_mkt_top}"
  mkdir -p "$_mkt_dir"
  _mkt_id="01P${_mkt_slug}$(printf '%020d' $RANDOM)"
  _mkt_file="${_mkt_dir}/${_mkt_slug}-${_mkt_id}.md"
  cat > "$_mkt_file" <<EOF
---
id: ${_mkt_id}
schema: studybook.note/v1
type: topic
status: published
captured_at: ${_mkt_day}T10:00:00+09:00
profile: testprof
category: ${_mkt_cat}
subcategory: ${_mkt_sub}
topic: ${_mkt_top}
title: ${_mkt_title}
slug: ${_mkt_slug}
level: intermediate
language: ko
tags: ["t"]
sources: []
---

# ${_mkt_title}

${_mkt_body}

## 내 말로 정리
<!-- Generation Effect 슬롯 — 직접 작성 -->
EOF
  update_index_on_add "$_mkt_file"
  printf '%s\n' "$_mkt_file"
}

# 기본 profile yaml 교체 (level 변경 등)
_set_profile_level() {
  _spl_level="$1"; _spl_tone="${2:-neutral}"
  cat > "$WJ_SB_HOME/profiles/testprof.yaml" <<EOF
name: testprof
level: ${_spl_level}
language: ko
tone: ${_spl_tone}
age_group: adult
book_style: standard
EOF
}

# ── book_compute_period ────────────────────────────────────────

@test "compute_period: weekly emits YYYY-MM-DD start/end + year-wNN slug" {
  _out=$(book_compute_period weekly)
  _s=$(printf '%s\n' "$_out" | sed -n 1p)
  _e=$(printf '%s\n' "$_out" | sed -n 2p)
  _sl=$(printf '%s\n' "$_out" | sed -n 3p)
  echo "$_s" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  echo "$_e" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  echo "$_sl" | grep -qE '^[0-9]{4}-w[0-9]{2}$'
}

@test "compute_period: monthly emits YYYY-MM slug" {
  _out=$(book_compute_period monthly)
  _sl=$(printf '%s\n' "$_out" | sed -n 3p)
  echo "$_sl" | grep -qE '^[0-9]{4}-[0-9]{2}$'
}

@test "compute_period: invalid kind fails" {
  run book_compute_period garbage
  [ "$status" -ne 0 ]
}

# ── book_build_frontmatter ─────────────────────────────────────

@test "build_frontmatter: emits all required fields" {
  _fm=$(book_build_frontmatter \
    --id 01BOOK01 --kind weekly --profile testprof \
    --title "t" --level intermediate --language ko \
    --start 2026-04-10 --end 2026-04-16 \
    --chapters-json '[{"title":"c1","note_ids":["n1"]}]' \
    --stats-json '{"total_notes":1,"new_topics":1,"revisited_topics":0,"user_annotated":0,"applied_in_code":0}' \
    --estimated-minutes 5)
  echo "$_fm" | grep -q '^id: 01BOOK01$'
  echo "$_fm" | grep -q '^schema: studybook.book/v1$'
  echo "$_fm" | grep -q '^type: book$'
  echo "$_fm" | grep -q '^book_kind: weekly$'
  echo "$_fm" | grep -q '^profile: testprof$'
  echo "$_fm" | grep -q '^period_start: 2026-04-10$'
  echo "$_fm" | grep -q '^period_end: 2026-04-16$'
  echo "$_fm" | grep -q '^published_at:'
  echo "$_fm" | grep -q '^chapters:'
  echo "$_fm" | grep -q 'note_ids: \["n1"\]'
  echo "$_fm" | grep -q '^stats:'
  echo "$_fm" | grep -q 'total_notes: 1'
  echo "$_fm" | grep -q '^estimated_reading_minutes: 5$'
}

@test "build_frontmatter: required args missing fails" {
  run book_build_frontmatter --id x --kind weekly
  [ "$status" -ne 0 ]
}

# ── book_write ─────────────────────────────────────────────────

@test "book_write: writes file with --- wrapped frontmatter + body" {
  _out="${TMP}/out.md"
  _fm="id: X\nschema: studybook.book/v1\ntype: book"
  book_write "$_out" "$(printf 'id: X\nschema: studybook.book/v1\ntype: book')" "# 본문"
  [ -f "$_out" ]
  head -1 "$_out" | grep -q '^---$'
  grep -q '^# 본문$' "$_out"
}

# ── book_update_note_published_in ──────────────────────────────

@test "update_note_published_in: appends bid when field absent" {
  _f=$(_mk_topic_at dev fe react a1 "A1" 2026-04-14)
  book_update_note_published_in "$_f" "01BID0001"
  grep -q '^published_in: \["01BID0001"\]' "$_f"
}

@test "update_note_published_in: appends bid when field present" {
  _f=$(_mk_topic_at dev fe react a2 "A2" 2026-04-14)
  # 첫 번째 append
  book_update_note_published_in "$_f" "01BID0001"
  # 두 번째 append → 기존 + 신규
  book_update_note_published_in "$_f" "01BID0002"
  grep -q '"01BID0001"' "$_f"
  grep -q '"01BID0002"' "$_f"
}

@test "update_note_published_in: no duplicate when same bid" {
  _f=$(_mk_topic_at dev fe react a3 "A3" 2026-04-14)
  book_update_note_published_in "$_f" "01BID0003"
  book_update_note_published_in "$_f" "01BID0003"
  _cnt=$(grep -o '01BID0003' "$_f" | wc -l | tr -d ' ')
  [ "$_cnt" = "1" ]
}

@test "update_note_published_in: missing args fails" {
  run book_update_note_published_in "" ""
  [ "$status" -ne 0 ]
}

# ── publish_collect_notes ──────────────────────────────────────

@test "collect_notes: weekly selects notes within last 7 days" {
  _today=$(date +%Y-%m-%d)
  # BSD/GNU date 호환을 위해 book_compute_period로 경계 사용 — 그대로 안에 포함
  if date -j -f '%Y-%m-%d' "$_today" +%s >/dev/null 2>&1; then
    _yday=$(date -j -v-2d -f '%Y-%m-%d' "$_today" +%Y-%m-%d)
    _old=$(date -j -v-15d -f '%Y-%m-%d' "$_today" +%Y-%m-%d)
  else
    _yday=$(date -d "$_today - 2 day" +%Y-%m-%d)
    _old=$(date -d "$_today - 15 day" +%Y-%m-%d)
  fi
  _mk_topic_at dev fe react r1 "R1 recent" "$_yday" >/dev/null
  _mk_topic_at dev fe react r2 "R2 old"    "$_old"  >/dev/null
  _n=$(publish_collect_notes weekly | wc -l | tr -d ' ')
  [ "$_n" = "1" ]
}

@test "collect_notes: monthly includes 15-day-old note" {
  _today=$(date +%Y-%m-%d)
  if date -j -f '%Y-%m-%d' "$_today" +%s >/dev/null 2>&1; then
    _mid=$(date -j -v-15d -f '%Y-%m-%d' "$_today" +%Y-%m-%d)
  else
    _mid=$(date -d "$_today - 15 day" +%Y-%m-%d)
  fi
  _mk_topic_at dev fe react m1 "M1" "$_mid" >/dev/null
  _n=$(publish_collect_notes monthly | wc -l | tr -d ' ')
  [ "$_n" = "1" ]
}

# ── publish_prepare ────────────────────────────────────────────

@test "prepare: weekly context includes required sections" {
  _today=$(date +%Y-%m-%d)
  if date -j -f '%Y-%m-%d' "$_today" +%s >/dev/null 2>&1; then
    _yd=$(date -j -v-1d -f '%Y-%m-%d' "$_today" +%Y-%m-%d)
  else
    _yd=$(date -d "$_today - 1 day" +%Y-%m-%d)
  fi
  _mk_topic_at dev fe react p1 "P1" "$_yd" >/dev/null
  _out=$(publish_prepare weekly)
  echo "$_out" | grep -q "## ACTIVE_PROFILE"
  echo "$_out" | grep -q "testprof"
  echo "$_out" | grep -q "## PROFILE_YAML"
  echo "$_out" | grep -q "level: intermediate"
  echo "$_out" | grep -q "## BOOK_KIND"
  echo "$_out" | grep -q "weekly"
  echo "$_out" | grep -q "## PERIOD_START"
  echo "$_out" | grep -q "## PERIOD_END"
  echo "$_out" | grep -q "## NOTES"
  echo "$_out" | grep -q "NOTE_BEGIN"
  echo "$_out" | grep -q "## NOTE_COUNT"
  echo "$_out" | grep -q "## INSTRUCTIONS"
  echo "$_out" | grep -q "## OUTPUT_TEMPLATE"
}

@test "prepare: NOTE_COUNT matches actual collect count" {
  _today=$(date +%Y-%m-%d)
  if date -j -f '%Y-%m-%d' "$_today" +%s >/dev/null 2>&1; then
    _yd=$(date -j -v-1d -f '%Y-%m-%d' "$_today" +%Y-%m-%d)
  else
    _yd=$(date -d "$_today - 1 day" +%Y-%m-%d)
  fi
  _mk_topic_at dev fe react c1 "C1" "$_yd" >/dev/null
  _mk_topic_at dev fe react c2 "C2" "$_yd" >/dev/null
  _out=$(publish_prepare weekly)
  _cnt=$(echo "$_out" | awk '/^## NOTE_COUNT$/ {getline; print}')
  [ "$_cnt" = "2" ]
}

@test "prepare: invalid kind fails" {
  run publish_prepare bogus
  [ "$status" -ne 0 ]
}

@test "prepare: level=child profile passes friendly tone context to Claude" {
  _set_profile_level child friendly
  _today=$(date +%Y-%m-%d)
  if date -j -f '%Y-%m-%d' "$_today" +%s >/dev/null 2>&1; then
    _yd=$(date -j -v-1d -f '%Y-%m-%d' "$_today" +%Y-%m-%d)
  else
    _yd=$(date -d "$_today - 1 day" +%Y-%m-%d)
  fi
  _mk_topic_at dev fe react ch1 "CH1" "$_yd" >/dev/null
  _out=$(publish_prepare weekly)
  echo "$_out" | grep -q "level: child"
  echo "$_out" | grep -q "tone: friendly"
}

@test "prepare: level=advanced profile passes concise tone context to Claude" {
  _set_profile_level advanced concise
  _today=$(date +%Y-%m-%d)
  if date -j -f '%Y-%m-%d' "$_today" +%s >/dev/null 2>&1; then
    _yd=$(date -j -v-1d -f '%Y-%m-%d' "$_today" +%Y-%m-%d)
  else
    _yd=$(date -d "$_today - 1 day" +%Y-%m-%d)
  fi
  _mk_topic_at dev fe react ad1 "AD1" "$_yd" >/dev/null
  _out=$(publish_prepare weekly)
  echo "$_out" | grep -q "level: advanced"
  echo "$_out" | grep -q "tone: concise"
}

# ── book_compute_stats ─────────────────────────────────────────

@test "compute_stats: total_notes + new_topics count correctly" {
  _f1=$(_mk_topic_at dev fe react s1 "S1" 2026-04-14)
  _f2=$(_mk_topic_at dev fe react s2 "S2" 2026-04-14)
  _list="${TMP}/list.txt"
  printf '%s\n%s\n' "$_f1" "$_f2" > "$_list"
  _st=$(book_compute_stats "$_list")
  _tot=$(echo "$_st" | jq -r '.total_notes')
  _new=$(echo "$_st" | jq -r '.new_topics')
  [ "$_tot" = "2" ]
  [ "$_new" = "2" ]
}

@test "compute_stats: estimated_reading_minutes uses 250 wpm" {
  _f=$(_mk_topic_at dev fe react r1 "R1" 2026-04-14 \
    "$(for i in $(seq 1 500); do printf 'word '; done)")
  _list="${TMP}/l.txt"; printf '%s\n' "$_f" > "$_list"
  _st=$(book_compute_stats "$_list")
  _m=$(echo "$_st" | jq -r '.estimated_reading_minutes')
  # 500 단어 / 250wpm = 2분 (ceil)
  [ "$_m" -ge 2 ]
}

# ── publish_apply (end-to-end) ─────────────────────────────────

@test "apply: creates book file at expected path + updates published_in" {
  _today=$(date +%Y-%m-%d)
  if date -j -f '%Y-%m-%d' "$_today" +%s >/dev/null 2>&1; then
    _yd=$(date -j -v-1d -f '%Y-%m-%d' "$_today" +%Y-%m-%d)
  else
    _yd=$(date -d "$_today - 1 day" +%Y-%m-%d)
  fi
  _f1=$(_mk_topic_at dev fe react ap1 "AP1" "$_yd")
  _f2=$(_mk_topic_at dev fe react ap2 "AP2" "$_yd")
  _json="${TMP}/r.json"
  jq -nc --arg p1 "$_f1" --arg p2 "$_f2" '
    {
      title: "주간 학습 정리",
      body:  "# 주간 학습 정리\n\n## 들어가며\n요약\n\n## 1장. React\n본문",
      chapters: [{title:"React", note_ids:["01x","01y"]}],
      note_paths: [$p1, $p2]
    }' > "$_json"
  run publish_apply "$_json" weekly
  [ "$status" -eq 0 ]
  # 출력 경로: books/testprof/weekly/<연도-wXX>.md
  _book=$(find "$WJ_SB_HOME/books/testprof/weekly" -type f -name '*.md' | head -1)
  [ -n "$_book" ]
  head -1 "$_book" | grep -q '^---$'
  grep -q '^schema: studybook.book/v1$' "$_book"
  grep -q '^book_kind: weekly$' "$_book"
  grep -q '^profile: testprof$' "$_book"
  # published_in[] 역참조 갱신
  grep -q '^published_in:' "$_f1"
  grep -q '^published_in:' "$_f2"
}

@test "apply: stats computed from notes (total_notes = 2)" {
  _today=$(date +%Y-%m-%d)
  if date -j -f '%Y-%m-%d' "$_today" +%s >/dev/null 2>&1; then
    _yd=$(date -j -v-1d -f '%Y-%m-%d' "$_today" +%Y-%m-%d)
  else
    _yd=$(date -d "$_today - 1 day" +%Y-%m-%d)
  fi
  _f1=$(_mk_topic_at dev fe react st1 "ST1" "$_yd")
  _f2=$(_mk_topic_at dev fe react st2 "ST2" "$_yd")
  _json="${TMP}/r.json"
  jq -nc --arg p1 "$_f1" --arg p2 "$_f2" '
    {title:"t",body:"b",chapters:[],note_paths:[$p1,$p2]}' > "$_json"
  publish_apply "$_json" weekly >/dev/null
  _book=$(find "$WJ_SB_HOME/books/testprof/weekly" -type f -name '*.md' | head -1)
  grep -q 'total_notes: 2' "$_book"
  grep -q 'new_topics: 2' "$_book"
  grep -q 'revisited_topics: 0' "$_book"
}

@test "apply: outputs path message with published file" {
  _today=$(date +%Y-%m-%d)
  if date -j -f '%Y-%m-%d' "$_today" +%s >/dev/null 2>&1; then
    _yd=$(date -j -v-1d -f '%Y-%m-%d' "$_today" +%Y-%m-%d)
  else
    _yd=$(date -d "$_today - 1 day" +%Y-%m-%d)
  fi
  _f=$(_mk_topic_at dev fe react op1 "OP1" "$_yd")
  _json="${TMP}/r.json"
  jq -nc --arg p "$_f" '
    {title:"t",body:"b",chapters:[],note_paths:[$p]}' > "$_json"
  run publish_apply "$_json" weekly
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "발간 완료:"
  echo "$output" | grep -q "books/testprof/weekly"
}

@test "apply: missing json fails" {
  run publish_apply "" weekly
  [ "$status" -ne 0 ]
  run publish_apply "/nope/none.json" weekly
  [ "$status" -ne 0 ]
}

@test "apply: invalid kind fails" {
  _json="${TMP}/r.json"
  echo '{"title":"t","body":"b"}' > "$_json"
  run publish_apply "$_json" garbage
  [ "$status" -ne 0 ]
}

@test "apply: missing title/body in json fails" {
  _json="${TMP}/r.json"
  echo '{}' > "$_json"
  run publish_apply "$_json" weekly
  [ "$status" -ne 0 ]
}

@test "apply: second publish adds second bid to published_in" {
  _today=$(date +%Y-%m-%d)
  if date -j -f '%Y-%m-%d' "$_today" +%s >/dev/null 2>&1; then
    _yd=$(date -j -v-1d -f '%Y-%m-%d' "$_today" +%Y-%m-%d)
  else
    _yd=$(date -d "$_today - 1 day" +%Y-%m-%d)
  fi
  _f=$(_mk_topic_at dev fe react sp1 "SP1" "$_yd")
  _json="${TMP}/r.json"
  jq -nc --arg p "$_f" '{title:"t",body:"b",chapters:[],note_paths:[$p]}' > "$_json"
  publish_apply "$_json" weekly >/dev/null
  publish_apply "$_json" monthly >/dev/null
  _cnt=$(grep -c '^published_in:' "$_f")
  [ "$_cnt" = "1" ]
  # 두 개의 서로 다른 ULID가 모두 들어있어야 함
  _ids=$(grep '^published_in:' "$_f" | grep -oE '"[^"]+"' | wc -l | tr -d ' ')
  [ "$_ids" = "2" ]
}
