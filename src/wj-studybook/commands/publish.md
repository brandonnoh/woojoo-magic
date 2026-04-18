---
description: 주간/월간 마크다운 책 발간 (Claude 2-step)
argument-hint: "[weekly | monthly] [prepare | apply <json_file>]"
---

`$ARGUMENTS`를 파싱해 서브커맨드로 분기:

| 명령 | 동작 |
|------|------|
| (인자 없음) / weekly | 주간 발간 컨텍스트 출력 (기본) |
| monthly | 월간 발간 컨텍스트 출력 |
| weekly prepare / monthly prepare | 발간 컨텍스트 출력 (명시적) |
| weekly apply \<json\> / monthly apply \<json\> | Claude 결과 적용 |
| apply \<json\> \<weekly\|monthly\> | Claude 결과 적용 (역순 인자) |
| prepare \<weekly\|monthly\> | 발간 컨텍스트 출력 (역순 인자) |

## 라우팅

```bash
set -euo pipefail
_args="${ARGUMENTS:-}"
_a1="$(printf '%s\n' "$_args" | awk '{print $1}')"
_a2="$(printf '%s\n' "$_args" | awk '{print $2}')"
_a3="$(printf '%s\n' "$_args" | awk '{print $3}')"

# shellcheck source=/dev/null
. "${CLAUDE_PLUGIN_ROOT}/lib/publish.sh"

case "$_a1" in
  ""|weekly|monthly)
    # 인자 없으면 weekly 기본
    _pbk="${_a1:-weekly}"
    case "$_a2" in
      apply)
        publish_apply "$_a3" "$_pbk"
        ;;
      prepare|"")
        publish_prepare "$_pbk"
        ;;
      *)
        echo "사용법: publish <weekly|monthly> [prepare|apply <json>]" >&2
        exit 2
        ;;
    esac
    ;;
  apply)
    # publish apply <json> <weekly|monthly>
    publish_apply "$_a2" "$_a3"
    ;;
  prepare)
    # publish prepare <weekly|monthly>
    publish_prepare "$_a2"
    ;;
  *)
    echo "사용법: publish <weekly|monthly> [prepare|apply <json>]" >&2
    exit 2
    ;;
esac
```

## Claude 작업 지시

`/wj-studybook:publish weekly` 또는 `/wj-studybook:publish monthly` 실행 시 Claude(본 세션)는 다음을 수행한다:

0. **digest 먼저 실행** — publish 전에 반드시 `/wj-studybook:digest`를 먼저 실행해 inbox 분류를 완료한다.
   quarantine 아이템도 이 단계에서 검토·승격된다.
   digest 완료 후 publish 단계로 진행한다.

1. 기본 라우팅은 `publish_prepare <weekly|monthly>`를 실행해 Claude에 전달할 컨텍스트를 stdout으로 출력한다.
   -> 출력에는 `ACTIVE_PROFILE`, `PROFILE_YAML`, `BOOK_KIND`, `PERIOD_START`, `PERIOD_END`,
   `NOTES` (`NOTE_BEGIN` / `NOTE_END` 블록), `NOTE_COUNT`, `INSTRUCTIONS`, `OUTPUT_TEMPLATE` 섹션이 포함된다.
2. Claude는 PROFILE_YAML의 `level/tone/language/age_group/book_style`에 맞춰 `NOTES`를
   한 권의 책으로 다듬는다. 원칙:
   - 관련 주제를 챕터로 묶고 입문 -> 심화 순서로 재배치
   - 각 챕터에 도입글 + 원본 노트 본문 통합
   - 원본 노트의 `## 내 말로 정리` 사용자 주석이 있으면 "#### 내 말로 정리"로 보존
   - `level=child/beginner`: 친절한 비유, 쉬운 어휘 / `level=advanced`: 간결/전문 톤
3. 결과를 아래 JSON 형식으로 작성:
   ```json
   {
     "title": "<책 제목>",
     "body":  "<OUTPUT_TEMPLATE 구조의 markdown 본문>",
     "chapters": [
       {"title": "<챕터 제목>", "note_ids": ["<ulid>", ...]}
     ],
     "note_paths": ["<NOTE_BEGIN path= 의 경로 그대로>", ...]
   }
   ```
4. JSON을 임시 파일에 저장한 뒤 `/wj-studybook:publish apply <tmp_file> <weekly|monthly>` 호출로 파일 시스템에 적용.
   -> `publish_apply`가 `books/<profile>/<weekly|monthly>/<slug>.md` 생성, frontmatter(stats 자동 계산 + chapters) 작성,
   각 노트의 `published_in[]` 역참조 추가를 모두 처리한다.

직접 호출용 서브커맨드:
- `/wj-studybook:publish weekly` / `publish weekly prepare` -- 주간 발간 컨텍스트 출력
- `/wj-studybook:publish monthly` / `publish monthly prepare` -- 월간 발간 컨텍스트 출력
- `/wj-studybook:publish apply <json_file> <weekly|monthly>` -- Claude 결과 적용
