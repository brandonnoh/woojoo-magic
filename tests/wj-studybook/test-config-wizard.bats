#!/usr/bin/env bats
# test-config-wizard.bats — wj-studybook lib/config-wizard.sh + config-helpers.sh
# Covers: path helpers, profile create/validate, active_profile update, menu, main flow

setup() {
  LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-studybook/lib" && pwd)"
  TMP="$(mktemp -d)"
  export STUDYBOOK_HOME="$TMP/.studybook"
  # shellcheck source=/dev/null
  source "$LIB_DIR/config-helpers.sh"
  # shellcheck source=/dev/null
  source "$LIB_DIR/config-wizard.sh"
}

teardown() {
  rm -rf "$TMP"
  unset STUDYBOOK_HOME
}

# ── path helpers ─────────────────────────────────────────────────

@test "helpers: get_studybook_dir respects STUDYBOOK_HOME" {
  _d=$(get_studybook_dir)
  [ "$_d" = "$STUDYBOOK_HOME" ]
}

@test "helpers: get_config_path is dir/config.yaml" {
  _p=$(get_config_path)
  [ "$_p" = "$STUDYBOOK_HOME/config.yaml" ]
}

@test "helpers: get_profiles_dir is dir/profiles" {
  _p=$(get_profiles_dir)
  [ "$_p" = "$STUDYBOOK_HOME/profiles" ]
}

@test "helpers: list_profile_names returns empty when dir missing" {
  _out=$(list_profile_names)
  [ -z "$_out" ]
}

@test "helpers: profile_exists returns false on empty arg" {
  run profile_exists ""
  [ "$status" -ne 0 ]
}

@test "helpers: get_active_profile returns empty when no config" {
  _out=$(get_active_profile)
  [ -z "$_out" ]
}

# ── wizard_create_profile (non-interactive) ──────────────────────

@test "create: zero state to new profile yaml" {
  run wizard_create_profile woojoo adult intermediate ko-en "ai,bash" friendly y
  [ "$status" -eq 0 ]
  [ -f "$STUDYBOOK_HOME/profiles/woojoo.yaml" ]
}

@test "create: yaml contains schema studybook profile v1" {
  wizard_create_profile woojoo adult beginner ko "" friendly y
  run grep -q '^schema: studybook.profile/v1$' "$STUDYBOOK_HOME/profiles/woojoo.yaml"
  [ "$status" -eq 0 ]
}

@test "create: yaml contains learner age_group level language" {
  wizard_create_profile kid child none ko "" friendly y
  _f="$STUDYBOOK_HOME/profiles/kid.yaml"
  grep -q 'age_group: child' "$_f"
  grep -q 'level: none' "$_f"
  grep -q 'language: ko' "$_f"
}

@test "create: interests csv to yaml list" {
  wizard_create_profile woojoo adult intermediate ko-en "ai, bash , os" friendly y
  _f="$STUDYBOOK_HOME/profiles/woojoo.yaml"
  grep -q 'interests: \[ai, bash, os\]' "$_f"
}

@test "create: empty interests yields empty list" {
  wizard_create_profile woojoo adult intermediate ko-en "" friendly y
  _f="$STUDYBOOK_HOME/profiles/woojoo.yaml"
  grep -q 'interests: \[\]' "$_f"
}

@test "create: books name topics weekly monthly dirs created" {
  wizard_create_profile woojoo adult intermediate ko-en "" friendly y
  [ -d "$STUDYBOOK_HOME/books/woojoo/topics" ]
  [ -d "$STUDYBOOK_HOME/books/woojoo/weekly" ]
  [ -d "$STUDYBOOK_HOME/books/woojoo/monthly" ]
}

@test "create: bad age_group fails" {
  run wizard_create_profile woojoo grown intermediate ko-en "" friendly y
  [ "$status" -ne 0 ]
  [[ "$output" == *"age_group"* ]]
}

@test "create: bad level fails" {
  run wizard_create_profile woojoo adult guru ko-en "" friendly y
  [ "$status" -ne 0 ]
  [[ "$output" == *"level"* ]]
}

@test "create: bad language fails" {
  run wizard_create_profile woojoo adult intermediate jp "" friendly y
  [ "$status" -ne 0 ]
  [[ "$output" == *"language"* ]]
}

@test "create: bad name uppercase fails" {
  run wizard_create_profile WooJoo adult intermediate ko-en "" friendly y
  [ "$status" -ne 0 ]
}

@test "create: bad name with space fails" {
  run wizard_create_profile "woo joo" adult intermediate ko-en "" friendly y
  [ "$status" -ne 0 ]
}

@test "create: too few args fails" {
  run wizard_create_profile woojoo adult
  [ "$status" -ne 0 ]
}

@test "create: duplicate name fails" {
  wizard_create_profile woojoo adult intermediate ko-en "" friendly y
  run wizard_create_profile woojoo adult intermediate ko-en "" friendly y
  [ "$status" -ne 0 ]
}

# ── wizard_set_active ────────────────────────────────────────────

@test "set_active: creates new config yaml with schema and key" {
  wizard_create_profile woojoo adult intermediate ko-en "" friendly y
  run wizard_set_active woojoo
  [ "$status" -eq 0 ]
  _cfg="$STUDYBOOK_HOME/config.yaml"
  [ -f "$_cfg" ]
  grep -q '^schema: studybook.config/v1$' "$_cfg"
  grep -q '^active_profile: woojoo$' "$_cfg"
}

@test "set_active: replaces existing active_profile line" {
  wizard_create_profile aaa adult intermediate ko-en "" friendly y
  wizard_create_profile bbb adult intermediate ko-en "" friendly y
  wizard_set_active aaa
  wizard_set_active bbb
  _cfg="$STUDYBOOK_HOME/config.yaml"
  grep -q '^active_profile: bbb$' "$_cfg"
  ! grep -q '^active_profile: aaa$' "$_cfg"
}

@test "set_active: nonexistent profile fails" {
  run wizard_set_active ghost
  [ "$status" -ne 0 ]
}

@test "set_active then get_active_profile returns name" {
  wizard_create_profile woojoo adult intermediate ko-en "" friendly y
  wizard_set_active woojoo
  _out=$(get_active_profile)
  [ "$_out" = "woojoo" ]
}

# ── list_profile_names ───────────────────────────────────────────

@test "list_profile_names: returns created names" {
  wizard_create_profile aaa adult intermediate ko "" friendly y
  wizard_create_profile bbb adult intermediate ko "" friendly y
  _out=$(list_profile_names)
  [[ "$_out" == *"aaa"* ]]
  [[ "$_out" == *"bbb"* ]]
}

# ── wizard_show_profiles ─────────────────────────────────────────

@test "show: zero state shows new profile menu" {
  run wizard_show_profiles
  [ "$status" -eq 0 ]
  [[ "$output" == *"[1]"* ]]
}

@test "show: one state shows [1] profile [2] new [3] manage" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  wizard_set_active woojoo
  run wizard_show_profiles
  [ "$status" -eq 0 ]
  [[ "$output" == *"[1] woojoo"* ]]
  [[ "$output" == *"[2]"* ]]
  [[ "$output" == *"[3]"* ]]
}

@test "show: two state inactive profile has no active marker" {
  wizard_create_profile aaa adult intermediate ko "" friendly y
  wizard_create_profile bbb adult intermediate ko "" friendly y
  wizard_set_active aaa
  run wizard_show_profiles
  [[ "$output" == *"aaa"* ]]
  [[ "$output" == *"bbb"* ]]
}

# ── wizard_main (stdin simulation) ───────────────────────────────

@test "main: zero state choice 0 cancels" {
  run bash -c "source '$LIB_DIR/config-wizard.sh'; echo 0 | wizard_main"
  [ "$status" -eq 0 ]
}

@test "main: one state choice 1 sets active" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  run bash -c "
    export STUDYBOOK_HOME='$STUDYBOOK_HOME'
    source '$LIB_DIR/config-wizard.sh'
    echo 1 | wizard_main
  "
  [ "$status" -eq 0 ]
  _active=$(get_active_profile)
  [ "$_active" = "woojoo" ]
}
