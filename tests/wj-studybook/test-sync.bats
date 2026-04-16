#!/usr/bin/env bats
# test-sync.bats — wj-studybook lib/sync.sh unit tests (s16)
# Note: 테스트명은 ASCII만. 데이터/경로는 한글 가능.
# 핵심 제약: 외부 전송 없음 — symlink + 경로 안내만 검증.

setup() {
  LIB_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-studybook/lib" && pwd)"
  TMP="$(mktemp -d)"
  # HOME을 TMP로 고정 → iCloud 경로/홈 경계 검증을 모두 TMP 안에서 재현
  export HOME="$TMP/home"
  mkdir -p "$HOME"
  export STUDYBOOK_HOME="$HOME/.studybook"
  export WJ_SB_HOME="$STUDYBOOK_HOME"
  export WJ_SB_PROFILE="testprof"
  BOOK_DIR="${WJ_SB_HOME}/books/testprof"
  mkdir -p "$WJ_SB_HOME/profiles" "$BOOK_DIR"
  cat > "$WJ_SB_HOME/config.yaml" <<'EOF'
active_profile: testprof
EOF
  cat > "$WJ_SB_HOME/profiles/testprof.yaml" <<'EOF'
name: testprof
level: beginner
language: ko
publish:
  schedule: weekly
  sync_to: none
EOF
  # shellcheck source=/dev/null
  source "${LIB_DIR}/config-helpers.sh"
  # shellcheck source=/dev/null
  source "${LIB_DIR}/sync.sh"
}

teardown() { rm -rf "$TMP"; }

# helper: 프로필 yaml의 sync_to 값 교체 (awk, 라인 in-place)
_set_sync_to() {
  _s_val="$1"
  _s_f="$WJ_SB_HOME/profiles/testprof.yaml"
  awk -v v="$_s_val" '
    /^[[:space:]]+sync_to:/ { sub("sync_to:.*", "sync_to: " v); print; next }
    { print }
  ' "$_s_f" > "${_s_f}.tmp" && mv "${_s_f}.tmp" "$_s_f"
}

_mk_icloud_obsidian() {
  mkdir -p "${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents"
}

_mk_icloud_cloud_docs() {
  mkdir -p "${HOME}/Library/Mobile Documents/com~apple~CloudDocs"
}

# ── sync_detect_icloud_path ──────────────────────────────────────

@test "detect_icloud: obsidian vault parent wins over cloud docs" {
  _mk_icloud_obsidian
  _mk_icloud_cloud_docs
  run sync_detect_icloud_path
  [ "$status" -eq 0 ]
  [[ "$output" == *"iCloud~md~obsidian/Documents/Studybook"* ]]
}

@test "detect_icloud: fallback to com.apple.CloudDocs when no obsidian" {
  _mk_icloud_cloud_docs
  run sync_detect_icloud_path
  [ "$status" -eq 0 ]
  [[ "$output" == *"com~apple~CloudDocs/Studybook"* ]]
}

@test "detect_icloud: neither exists returns non-zero" {
  run sync_detect_icloud_path
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

# ── sync_create_symlink ──────────────────────────────────────────

@test "create_symlink: happy path creates link and parent dir" {
  _dst="${HOME}/Target/Studybook"
  run sync_create_symlink "$BOOK_DIR" "$_dst"
  [ "$status" -eq 0 ]
  [ -L "$_dst" ]
  [ "$(readlink "$_dst")" = "$BOOK_DIR" ]
}

@test "create_symlink: idempotent when dst already links to same src" {
  _dst="${HOME}/Target/Studybook"
  sync_create_symlink "$BOOK_DIR" "$_dst"
  run sync_create_symlink "$BOOK_DIR" "$_dst"
  [ "$status" -eq 0 ]
}

@test "create_symlink: rejects conflicting symlink with different target" {
  _dst="${HOME}/Target/Studybook"
  mkdir -p "${HOME}/other" "${HOME}/Target"
  ln -s "${HOME}/other" "$_dst"
  run sync_create_symlink "$BOOK_DIR" "$_dst"
  [ "$status" -ne 0 ]
  [[ "$output" == *"충돌"* ]]
}

@test "create_symlink: rejects real file/dir at dst" {
  _dst="${HOME}/Target/Studybook"
  mkdir -p "$_dst"
  run sync_create_symlink "$BOOK_DIR" "$_dst"
  [ "$status" -ne 0 ]
}

@test "create_symlink: rejects src that is not a directory" {
  run sync_create_symlink "${HOME}/nonexistent" "${HOME}/dst"
  [ "$status" -ne 0 ]
}

@test "create_symlink: rejects dst outside HOME (safety)" {
  _outside="${TMP}/outside"
  mkdir -p "$_outside"
  run sync_create_symlink "$BOOK_DIR" "${_outside}/Studybook"
  [ "$status" -ne 0 ]
  [[ "$output" == *"HOME"* ]]
}

@test "create_symlink: missing args fails" {
  run sync_create_symlink
  [ "$status" -ne 0 ]
}

# ── sync_run: target = none ──────────────────────────────────────

@test "run: default none prints book path" {
  run sync_run
  [ "$status" -eq 0 ]
  [[ "$output" == *"$BOOK_DIR"* ]]
  [[ "$output" == *"none"* ]]
}

@test "run: --target none overrides profile" {
  _set_sync_to icloud
  run sync_run --target none
  [ "$status" -eq 0 ]
  [[ "$output" == *"$BOOK_DIR"* ]]
}

# ── sync_run: target = icloud ────────────────────────────────────

@test "run: icloud creates symlink when path exists" {
  _mk_icloud_obsidian
  run sync_run --target icloud
  [ "$status" -eq 0 ]
  _exp="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/Studybook"
  [ -L "$_exp" ]
  [ "$(readlink "$_exp")" = "$BOOK_DIR" ]
}

@test "run: icloud without path prints guidance and non-zero" {
  run sync_run --target icloud
  [ "$status" -ne 0 ]
  [[ "$output" == *"iCloud"* ]]
  [[ "$output" == *"Mobile Documents"* ]]
}

@test "run: icloud with no book dir errors" {
  rm -rf "$BOOK_DIR"
  _mk_icloud_obsidian
  run sync_run --target icloud
  [ "$status" -ne 0 ]
  [[ "$output" == *"책 디렉토리"* ]]
}

@test "run: icloud uses profile sync_to when no --target" {
  _set_sync_to icloud
  _mk_icloud_obsidian
  run sync_run
  [ "$status" -eq 0 ]
  _exp="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/Studybook"
  [ -L "$_exp" ]
}

# ── sync_run: target = obsidian ──────────────────────────────────

@test "run: obsidian requires --vault" {
  run sync_run --target obsidian
  [ "$status" -ne 0 ]
  [[ "$output" == *"vault"* ]]
}

@test "run: obsidian creates symlink under vault" {
  _vault="${HOME}/Documents/MyVault"
  mkdir -p "$_vault"
  run sync_run --target obsidian --vault "$_vault"
  [ "$status" -eq 0 ]
  [ -L "${_vault}/Studybook" ]
  [ "$(readlink "${_vault}/Studybook")" = "$BOOK_DIR" ]
}

@test "run: obsidian rejects missing vault" {
  run sync_run --target obsidian --vault "${HOME}/does-not-exist"
  [ "$status" -ne 0 ]
}

@test "run: obsidian expands tilde" {
  mkdir -p "${HOME}/Documents/Vault2"
  run sync_run --target obsidian --vault "~/Documents/Vault2"
  [ "$status" -eq 0 ]
  [ -L "${HOME}/Documents/Vault2/Studybook" ]
}

# ── sync_run: target = git ───────────────────────────────────────

@test "run: git initializes repo in book dir" {
  command -v git >/dev/null 2>&1 || skip "git 미설치"
  run sync_run --target git
  [ "$status" -eq 0 ]
  [ -d "${BOOK_DIR}/.git" ]
  [[ "$output" == *"git init"* ]]
  [[ "$output" == *"수동"* ]]
}

@test "run: git is idempotent (second call skips)" {
  command -v git >/dev/null 2>&1 || skip "git 미설치"
  sync_run --target git >/dev/null
  run sync_run --target git
  [ "$status" -eq 0 ]
  [[ "$output" == *"이미"* ]]
}

@test "run: git without book dir errors" {
  rm -rf "$BOOK_DIR"
  command -v git >/dev/null 2>&1 || skip "git 미설치"
  run sync_run --target git
  [ "$status" -ne 0 ]
}

@test "run: git output mentions no auto push" {
  command -v git >/dev/null 2>&1 || skip "git 미설치"
  run sync_run --target git
  [ "$status" -eq 0 ]
  [[ "$output" == *"Local-first"* ]] || [[ "$output" == *"자동 push"* ]]
}

# ── sync_run: unknown target ─────────────────────────────────────

@test "run: unknown target returns non-zero" {
  run sync_run --target nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"지원하지 않는"* ]]
}

@test "run: unknown option returns non-zero" {
  run sync_run --foo bar
  [ "$status" -ne 0 ]
}

# ── sync_run: status 서브 ────────────────────────────────────────

@test "run status: prints profile and book path" {
  run sync_run status
  [ "$status" -eq 0 ]
  [[ "$output" == *"testprof"* ]]
  [[ "$output" == *"$BOOK_DIR"* ]]
}

@test "run status: reports normal dir when not symlinked" {
  run sync_run status
  [ "$status" -eq 0 ]
  [[ "$output" == *"일반 디렉토리"* ]]
}

@test "run status: reports symlink target when iCloud linked" {
  _mk_icloud_obsidian
  sync_run --target icloud >/dev/null
  run sync_run status
  [ "$status" -eq 0 ]
  [[ "$output" == *"icloud"* ]]
  [[ "$output" == *"$BOOK_DIR"* ]]
}

@test "run status: reports missing book dir" {
  rm -rf "$BOOK_DIR"
  run sync_run status
  [ "$status" -eq 0 ]
  [[ "$output" == *"발간"* ]]
}

# ── _sc_read_sync_to: YAML 파싱 ───────────────────────────────────

@test "sync_to reads nested publish.sync_to from profile yaml" {
  _set_sync_to obsidian
  # 내부 함수지만 노출되어 있으므로 직접 호출 가능 (bash source)
  run _sc_read_sync_to
  [ "$status" -eq 0 ]
  [ "$output" = "obsidian" ]
}

@test "sync_to falls back to empty when publish block missing" {
  cat > "$WJ_SB_HOME/profiles/testprof.yaml" <<'EOF'
name: testprof
level: beginner
EOF
  run _sc_read_sync_to
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ── P4 Local-first: 외부 전송 코드 금지 검증 ─────────────────────

@test "source: contains no external-transfer keywords (curl/wget/scp)" {
  # sync.sh 안에 curl/wget/scp 호출이 없어야 함
  _src="${LIB_DIR}/sync.sh"
  ! grep -Eq '(^|[^a-zA-Z_])curl[^a-zA-Z_]'    "$_src"
  ! grep -Eq '(^|[^a-zA-Z_])wget[^a-zA-Z_]'    "$_src"
  ! grep -Eq '(^|[^a-zA-Z_])scp[^a-zA-Z_]'     "$_src"
}

@test "source: no rsync to remote (only local symlink)" {
  _src="${LIB_DIR}/sync.sh"
  # rsync 호출 자체가 없어야 함 (로컬 rsync도 본 task 범위에서는 쓰지 않음)
  ! grep -Eq '(^|[^a-zA-Z_])rsync[^a-zA-Z_]' "$_src"
}

@test "source: no ssh invocation" {
  _src="${LIB_DIR}/sync.sh"
  ! grep -Eq '(^|[^a-zA-Z_])ssh[^a-zA-Z_]' "$_src"
}
