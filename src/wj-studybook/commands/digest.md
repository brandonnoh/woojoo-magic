---
description: inbox 노트 -> topics 자동 분류 (Claude 2-step)
argument-hint: "[prepare | apply <json_file>]"
---

`$ARGUMENTS`를 파싱해 서브커맨드로 분기:

| 명령 | 동작 |
|------|------|
| (인자 없음) / prepare | inbox 노트 + 트리 컨텍스트 출력 (Claude가 분류 수행) |
| apply \<json_file\> | Claude 결과 JSON을 파일 시스템에 적용 |

## 라우팅

```bash
set -euo pipefail
_args="${ARGUMENTS:-}"
_a1="$(printf '%s\n' "$_args" | awk '{print $1}')"
_a2="$(printf '%s\n' "$_args" | awk '{print $2}')"

case "$_a1" in
  apply)
    # shellcheck source=/dev/null
    . "${CLAUDE_PLUGIN_ROOT}/lib/digest.sh"
    digest_apply "$_a2"
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
```

## Claude 작업 지시

`/wj-studybook:digest` 실행 시 Claude(본 세션)는 다음을 수행한다:

1. 라우팅(`digest` 또는 `digest prepare`)으로 `digest_prepare` 호출.
   -> 출력에는 `ACTIVE_PROFILE`, `PROFILE_YAML`, `CURRENT_TREE_JSON`, `INBOX_NOTES`, `INBOX_COUNT` 섹션이 포함된다.
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
4. JSON을 임시 파일에 저장한 뒤 `/wj-studybook:digest apply <tmp_file>` 호출로 파일 시스템에 적용.
   -> `digest_apply`가 topic 노트 생성, `sources[]` 누적, inbox/processed 이동, `update_index_on_add`, `unsorted_count` 감소를 모두 처리한다.

호출 방식 선택 (spec 기준):
- `INBOX_COUNT` <= 20 -> 메인 세션에서 즉시 분류.
- `INBOX_COUNT` > 20 -> Task(Agent) 도구로 subagent에 위임.
