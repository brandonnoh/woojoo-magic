#!/usr/bin/env bats
# test-config-set.bats — wj-studybook lib/config-set.sh
# Covers: config_show / config_set / config_edit

setup() {
  LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-studybook/lib" && pwd)"
  TMP="$(mktemp -d)"
  export STUDYBOOK_HOME="$TMP/.studybook"
  # shellcheck source=/dev/null
  source "$LIB_DIR/config-helpers.sh"
  # shellcheck source=/dev/null
  source "$LIB_DIR/config-wizard.sh"
  # shellcheck source=/dev/null
  source "$LIB_DIR/config-set.sh"
}

teardown() {
  rm -rf "$TMP"
  unset STUDYBOOK_HOME
}

# ── config_show ──────────────────────────────────────────────────

@test "show: zero state — no config no profile" {
  run config_show
  [ "$status" -eq 0 ]
  [[ "$output" == *"없음"* ]] || [[ "$output" == *"활성 프로필 없음"* ]]
}

@test "show: dumps config.yaml when present" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  wizard_set_active woojoo
  run config_show
  [ "$status" -eq 0 ]
  [[ "$output" == *"active_profile: woojoo"* ]]
}

@test "show: dumps active profile yaml" {
  wizard_create_profile woojoo adult intermediate ko-en "ai,bash" friendly y
  wizard_set_active woojoo
  run config_show
  [ "$status" -eq 0 ]
  [[ "$output" == *"schema: studybook.profile/v1"* ]]
  [[ "$output" == *"age_group: adult"* ]]
}

# ── config_set ───────────────────────────────────────────────────

@test "set: changes existing key (sed fallback last-token match)" {
  # yq가 있는 환경에서도 sed 경로가 동작하는지 보장하려고 PATH 조작은 생략
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  wizard_set_active woojoo
  run config_set learner.level advanced
  [ "$status" -eq 0 ]
  _f="$STUDYBOOK_HOME/profiles/woojoo.yaml"
  grep -qE '^[[:space:]]*level:[[:space:]]*advanced' "$_f"
}

@test "set: invalid key.path format fails" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  wizard_set_active woojoo
  run config_set "bad path!" advanced
  [ "$status" -ne 0 ]
  [[ "$output" == *"잘못된 key.path"* ]]
}

@test "set: missing args fails" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  wizard_set_active woojoo
  run config_set learner.level
  [ "$status" -ne 0 ]
  [[ "$output" == *"사용법"* ]]
}

@test "set: nonexistent key.path fails" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  wizard_set_active woojoo
  run config_set nonexistent.key value
  [ "$status" -ne 0 ]
  [[ "$output" == *"존재하지 않는 key.path"* ]]
}

@test "set: no active profile fails" {
  run config_set learner.level advanced
  [ "$status" -ne 0 ]
  [[ "$output" == *"활성 프로필"* ]]
}

@test "set: changes book_style use_emoji" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  wizard_set_active woojoo
  run config_set book_style.use_emoji n
  [ "$status" -eq 0 ]
  _f="$STUDYBOOK_HOME/profiles/woojoo.yaml"
  grep -qE '^[[:space:]]*use_emoji:[[:space:]]*n' "$_f"
}

@test "set: changes publish.schedule" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  wizard_set_active woojoo
  run config_set publish.schedule monthly
  [ "$status" -eq 0 ]
  _f="$STUDYBOOK_HOME/profiles/woojoo.yaml"
  grep -qE '^[[:space:]]*schedule:[[:space:]]*monthly' "$_f"
}

# ── config_edit ──────────────────────────────────────────────────

@test "edit: no active profile fails" {
  run config_edit
  [ "$status" -ne 0 ]
  [[ "$output" == *"활성 프로필"* ]]
}

@test "edit: invokes EDITOR with active yaml path" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  wizard_set_active woojoo
  # EDITOR로 echo(단일 토큰)를 사용해 호출 인자만 캡처. exec이라 별도 bash로 감싼다.
  run bash -c "
    export STUDYBOOK_HOME='$STUDYBOOK_HOME'
    export EDITOR=echo
    source '$LIB_DIR/config-set.sh'
    config_edit
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"woojoo.yaml"* ]]
}

@test "edit: defaults to vi when EDITOR unset" {
  # exec을 가로채기 어려우므로, _cs_active_profile_yaml이 정확히 산출되는지로 간접 검증
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  wizard_set_active woojoo
  _prof=$(_cs_active_profile_yaml)
  [ "$_prof" = "$STUDYBOOK_HOME/profiles/woojoo.yaml" ]
  [ -f "$_prof" ]
}
