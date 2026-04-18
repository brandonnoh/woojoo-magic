---
description: 학습자 프로필 + 설정 관리
argument-hint: "[init | profile list | profile use <name> | profile new | profile delete <name> [--purge|--keep-books] | set <key.path> <value> | edit]"
---

아래 스크립트를 실행하고 **출력 결과를 그대로 사용자에게 보여주세요.** 요약하거나 생략하지 마세요.

`$ARGUMENTS`를 파싱해 서브커맨드로 분기:

| 명령 | 동작 |
|------|------|
| init | 프로필 마법사 |
| (인자 없음) | 활성 프로필 + 전역 설정 yaml dump |
| profile list | 프로필 목록 + 활성 표시 |
| profile use \<name\> | active_profile 갱신 |
| profile new | 신규 프로필 마법사 |
| profile delete \<name\> [--purge\|--keep-books] | 프로필 삭제 |
| set \<key.path\> \<value\> | 활성 프로필 yaml 단일 값 변경 |
| edit | $EDITOR로 활성 프로필 yaml 편집 |

## 라우팅

```bash
set -euo pipefail
_args="${ARGUMENTS:-}"
_a1="$(printf '%s\n' "$_args" | awk '{print $1}')"
_a2="$(printf '%s\n' "$_args" | awk '{print $2}')"
_a3="$(printf '%s\n' "$_args" | awk '{print $3}')"
_a4="$(printf '%s\n' "$_args" | awk '{print $4}')"

case "$_a1" in
  init)
    # shellcheck source=/dev/null
    . "${CLAUDE_PLUGIN_ROOT}/lib/config-wizard.sh"
    wizard_main
    ;;
  profile)
    # shellcheck source=/dev/null
    . "${CLAUDE_PLUGIN_ROOT}/lib/profile-mgmt.sh"
    case "$_a2" in
      list)   profile_list ;;
      use)    profile_use "$_a3" ;;
      new)    profile_new ;;
      delete) profile_delete "$_a3" "${_a4:---keep-books}" ;;
      *)
        echo "사용법: config profile {list|use <name>|new|delete <name> [--purge|--keep-books]}" >&2
        exit 2
        ;;
    esac
    ;;
  set)
    # shellcheck source=/dev/null
    . "${CLAUDE_PLUGIN_ROOT}/lib/config-set.sh"
    config_set "$_a2" "$_a3"
    ;;
  edit)
    # shellcheck source=/dev/null
    . "${CLAUDE_PLUGIN_ROOT}/lib/config-set.sh"
    config_edit
    ;;
  ""|*)
    # 인자 없음 → show
    # shellcheck source=/dev/null
    . "${CLAUDE_PLUGIN_ROOT}/lib/config-set.sh"
    config_show
    ;;
esac
```
