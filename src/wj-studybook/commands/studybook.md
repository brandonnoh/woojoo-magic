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
  digest)
    # digest는 Claude(메인 세션)가 수행하는 2-step.
    # 이 branch는 "준비 컨텍스트"를 stdout으로 출력한다.
    # Claude는 아래 instruction을 읽고 분류 → 임시 JSON 파일 작성 → `digest apply <file>` 재호출.
    case "$_a2" in
      apply)
        # shellcheck source=/dev/null
        . "${CLAUDE_PLUGIN_ROOT}/lib/digest.sh"
        digest_apply "$_a3"
        ;;
      prepare|"")
        # shellcheck source=/dev/null
        . "${CLAUDE_PLUGIN_ROOT}/lib/digest.sh"
        digest_prepare
        ;;
      *)
        echo "사용법: digest [prepare|apply <json>]" >&2
        exit 2
        ;;
    esac
    ;;
  *)
    echo "지원하지 않는 명령: $_args" >&2
    echo "사용 가능: config [init|profile ...|set ...|edit] | digest (이후 task에서 추가)" >&2
    exit 2
    ;;
esac
```

## digest 분기 Claude 작업 지시

`/wj:studybook digest` 실행 시 Claude(본 세션)는 다음을 수행한다:

1. `bash ${CLAUDE_PLUGIN_ROOT}/lib/digest.sh` 소스 후 `digest_prepare` 호출 —
   또는 슬래시 커맨드 라우팅(`digest` 또는 `digest prepare`)으로 동일 결과 획득.
   → 출력에는 `ACTIVE_PROFILE`, `PROFILE_YAML`, `CURRENT_TREE_JSON`, `INBOX_NOTES`, `INBOX_COUNT` 섹션이 포함된다.
2. 컨텍스트를 읽고 각 `INBOX_BEGIN ... INBOX_END` 블록을 분류. 원칙:
   - `CURRENT_TREE_JSON`의 기존 카테고리를 우선 재사용하고 신설은 보수적으로.
   - 프로필 `level`/`language`/`tone`에 맞춰 `body`를 다듬는다.
   - 본문 끝 `## 내 말로 정리` 섹션은 `topic-writer.sh`가 자동 삽입하므로 Claude가 추가할 필요 없음.
3. 결과를 아래 JSON 배열 형식으로 작성:
   ```json
   [
     {
       "inbox_id": "<inbox 노트의 id 값>",
       "category": "<top>",
       "subcategory": "<mid>",
       "topic": "<leaf>",
       "subtopic": "<optional>",
       "title": "<한 줄 제목>",
       "slug": "<kebab-case 영문 slug>",
       "tags": ["tag1", "tag2"],
       "body": "<학습자 수준에 맞춘 본문 markdown (Generation Effect 슬롯 제외)>"
     }
   ]
   ```
4. JSON을 임시 파일에 저장한 뒤 `/wj:studybook digest apply <tmp_file>` 호출로 파일 시스템에 적용.
   → `digest_apply`가 topic 노트 생성, `sources[]` 누적, inbox/processed 이동, `update_index_on_add`, `unsorted_count` 감소를 모두 처리한다.

호출 방식 선택 (spec 기준):
- `INBOX_COUNT` ≤ 20 → 메인 세션에서 즉시 분류.
- `INBOX_COUNT` > 20 → Task(Agent) 도구로 subagent에 위임.
