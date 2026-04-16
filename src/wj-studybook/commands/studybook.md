---
description: 세션 자동 학습 노트화 — config/digest/publish/similar/merge/backfill/tree/sync
argument-hint: "config [init|profile list|profile use <n>|profile new|profile delete <n> [--purge|--keep-books]|set <k.p> <v>|edit] | digest | publish weekly | similar <쿼리> | tree"
---

`$ARGUMENTS`를 파싱해 첫 단어로 분기:

| 명령 | 동작 | 구현 task |
|------|------|----------|
| config init | 프로필 마법사 | s6 |
| config | 활성 프로필 + 전역 설정 yaml dump | s8 |
| config profile list | 프로필 목록 + ★ 활성 표시 | s7 |
| config profile use \<name\> | active_profile 갱신 | s7 |
| config profile new | 신규 프로필 마법사 | s7 |
| config profile delete \<name\> [--purge\|--keep-books] | 프로필 삭제 | s7 |
| config set \<key.path\> \<value\> | 활성 프로필 yaml 단일 값 변경 | s8 |
| config edit | $EDITOR로 활성 프로필 yaml 편집 | s8 |
| digest | inbox → topics 분류 | s10 |
| publish weekly | 주간 책 발간 | s13 |
| similar \<쿼리\> | 유사 노트 검색 | s11 |
| merge | 주제 병합 | s12 |
| backfill --since \<날짜\> | 과거 세션 소급 | s14 |
| tree | 분류 트리 시각화 | s15 |
| sync | 동기화 경로 안내 | s16 |

각 서브커맨드는 `${CLAUDE_PLUGIN_ROOT}/lib/<feature>.sh`로 위임.

## 라우팅

```bash
set -euo pipefail
_args="${ARGUMENTS:-}"
# 토큰화 (POSIX awk)
_a1="$(printf '%s\n' "$_args" | awk '{print $1}')"
_a2="$(printf '%s\n' "$_args" | awk '{print $2}')"
_a3="$(printf '%s\n' "$_args" | awk '{print $3}')"
_a4="$(printf '%s\n' "$_args" | awk '{print $4}')"
_a5="$(printf '%s\n' "$_args" | awk '{print $5}')"

case "$_a1" in
  config)
    case "$_a2" in
      init)
        # shellcheck source=/dev/null
        . "${CLAUDE_PLUGIN_ROOT}/lib/config-wizard.sh"
        wizard_main
        ;;
      profile)
        # shellcheck source=/dev/null
        . "${CLAUDE_PLUGIN_ROOT}/lib/profile-mgmt.sh"
        case "$_a3" in
          list)   profile_list ;;
          use)    profile_use "$_a4" ;;
          new)    profile_new ;;
          delete) profile_delete "$_a4" "${_a5:---keep-books}" ;;
          *)
            echo "사용법: config profile {list|use <name>|new|delete <name> [--purge|--keep-books]}" >&2
            exit 2
            ;;
        esac
        ;;
      set)
        # shellcheck source=/dev/null
        . "${CLAUDE_PLUGIN_ROOT}/lib/config-set.sh"
        config_set "$_a3" "$_a4"
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
    ;;
  *)
    echo "지원하지 않는 명령: $_args" >&2
    echo "사용 가능: config [init|profile ...|set ...|edit] (이후 task에서 추가)" >&2
    exit 2
    ;;
esac
```
