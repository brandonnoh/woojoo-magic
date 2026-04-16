#!/usr/bin/env bats
# test-profile-mgmt.bats — wj-studybook lib/profile-mgmt.sh
# Covers: profile_list / profile_use / profile_new / profile_delete

setup() {
  LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-studybook/lib" && pwd)"
  TMP="$(mktemp -d)"
  export STUDYBOOK_HOME="$TMP/.studybook"
  # shellcheck source=/dev/null
  source "$LIB_DIR/config-helpers.sh"
  # shellcheck source=/dev/null
  source "$LIB_DIR/config-wizard.sh"
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-mgmt.sh"
}

teardown() {
  rm -rf "$TMP"
  unset STUDYBOOK_HOME
}

# ── profile_list ─────────────────────────────────────────────────

@test "list: zero state shows guidance message" {
  run profile_list
  [ "$status" -eq 0 ]
  [[ "$output" == *"프로필 없음"* ]]
}

@test "list: shows all profile names" {
  wizard_create_profile aaa adult intermediate ko "" friendly y
  wizard_create_profile bbb adult intermediate ko "" friendly y
  run profile_list
  [ "$status" -eq 0 ]
  [[ "$output" == *"aaa"* ]]
  [[ "$output" == *"bbb"* ]]
}

@test "list: active profile is marked with star" {
  wizard_create_profile aaa adult intermediate ko "" friendly y
  wizard_create_profile bbb adult intermediate ko "" friendly y
  wizard_set_active aaa
  run profile_list
  [[ "$output" == *"★ aaa"* ]]
  [[ "$output" != *"★ bbb"* ]]
}

# ── profile_use ──────────────────────────────────────────────────

@test "use: switches active_profile" {
  wizard_create_profile aaa adult intermediate ko "" friendly y
  wizard_create_profile bbb adult intermediate ko "" friendly y
  wizard_set_active aaa
  run profile_use bbb
  [ "$status" -eq 0 ]
  _active=$(get_active_profile)
  [ "$_active" = "bbb" ]
}

@test "use: nonexistent profile fails" {
  run profile_use ghost
  [ "$status" -ne 0 ]
  [[ "$output" == *"존재하지 않는"* ]]
}

@test "use: empty arg fails" {
  run profile_use ""
  [ "$status" -ne 0 ]
}

@test "use: prints active profile message" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  run profile_use woojoo
  [[ "$output" == *"활성 프로필: woojoo"* ]]
}

# ── profile_new ──────────────────────────────────────────────────

@test "new: delegates to wizard_main (zero state cancels with 0)" {
  run bash -c "
    export STUDYBOOK_HOME='$STUDYBOOK_HOME'
    source '$LIB_DIR/profile-mgmt.sh'
    echo 0 | profile_new
  "
  [ "$status" -eq 0 ]
}

# ── profile_delete ───────────────────────────────────────────────

@test "delete: removes yaml with default keep-books" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  [ -f "$STUDYBOOK_HOME/profiles/woojoo.yaml" ]
  [ -d "$STUDYBOOK_HOME/books/woojoo" ]
  run profile_delete woojoo
  [ "$status" -eq 0 ]
  [ ! -f "$STUDYBOOK_HOME/profiles/woojoo.yaml" ]
  [ -d "$STUDYBOOK_HOME/books/woojoo" ]
}

@test "delete: --keep-books preserves books dir" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  run profile_delete woojoo --keep-books
  [ "$status" -eq 0 ]
  [ -d "$STUDYBOOK_HOME/books/woojoo" ]
}

@test "delete: --purge removes books dir" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  [ -d "$STUDYBOOK_HOME/books/woojoo" ]
  run profile_delete woojoo --purge
  [ "$status" -eq 0 ]
  [ ! -d "$STUDYBOOK_HOME/books/woojoo" ]
  [ ! -f "$STUDYBOOK_HOME/profiles/woojoo.yaml" ]
}

@test "delete: nonexistent profile fails" {
  run profile_delete ghost --purge
  [ "$status" -ne 0 ]
  [[ "$output" == *"존재하지 않는"* ]]
}

@test "delete: invalid mode fails" {
  wizard_create_profile woojoo adult intermediate ko "" friendly y
  run profile_delete woojoo --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"지원하지 않는 옵션"* ]]
  # 안전: 잘못된 옵션 시 yaml 보존
  [ -f "$STUDYBOOK_HOME/profiles/woojoo.yaml" ]
}

@test "delete: empty name fails" {
  run profile_delete "" --purge
  [ "$status" -ne 0 ]
}

@test "delete: removes active_profile line if deleting active" {
  wizard_create_profile aaa adult intermediate ko "" friendly y
  wizard_set_active aaa
  _cfg="$STUDYBOOK_HOME/config.yaml"
  grep -q '^active_profile: aaa$' "$_cfg"
  run profile_delete aaa --purge
  [ "$status" -eq 0 ]
  ! grep -q '^active_profile:' "$_cfg"
}

@test "delete: keeps active_profile line if deleting non-active" {
  wizard_create_profile aaa adult intermediate ko "" friendly y
  wizard_create_profile bbb adult intermediate ko "" friendly y
  wizard_set_active aaa
  run profile_delete bbb --purge
  [ "$status" -eq 0 ]
  _active=$(get_active_profile)
  [ "$_active" = "aaa" ]
}
