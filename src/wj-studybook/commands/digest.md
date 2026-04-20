---
description: inbox 노트 -> topics 쪽 페이지 자동 분류/편집/발간
argument-hint: "[auto | prepare | apply <json_file> | bucket <topic_key>]"
---

`$ARGUMENTS`를 파싱해 서브커맨드로 분기:

| 명령 | 동작 |
|------|------|
| (인자 없음) / auto | **전체 자동 파이프라인** — 라우팅 → 토픽별 병렬 서브에이전트 → apply (쪽 페이지 = 발간물) |
| prepare | inbox 노트 + 트리 컨텍스트 출력 (디버깅용, Claude 수동 분류) |
| apply \<json_file\> | Claude 결과 JSON을 파일 시스템에 적용 |
| bucket \<topic_key\> | 특정 토픽 버킷 prepare (서브에이전트용 컨텍스트 출력) |

## 라우팅

```bash
set -euo pipefail
_args="${ARGUMENTS:-}"
_a1="$(printf '%s\n' "$_args" | awk '{print $1}')"
_a2="$(printf '%s\n' "$_args" | awk '{print $2}')"

# shellcheck source=/dev/null
. "${CLAUDE_PLUGIN_ROOT}/lib/digest.sh"

case "$_a1" in
  apply)
    digest_apply "$_a2"
    ;;
  prepare)
    digest_prepare
    ;;
  bucket)
    digest_prepare_bucket "$_a2"
    ;;
  ""|auto)
    digest_prepare
    ;;
  *)
    echo "사용법: digest [auto|prepare|apply <json>|bucket <topic_key>]" >&2
    exit 2
    ;;
esac
```

## Claude 작업 지시 (auto 모드)

`/wj-studybook:digest` 또는 `/wj-studybook:digest auto` 실행 시 Claude는 다음을 **한 세션 안에서 전부 수행**한다.

inbox 노트들은 **독립적으로 발간되는 "쪽 페이지"**가 된다 — 한 권의 책이 아니라 주제 폴더에 속한 한 장의 지식 카드. 제목/요약/본문/see-also가 단독으로 읽혀야 하며, 관련 노트는 `sources[]`가 아니라 본문 끝의 see-also 링크로 암시만 한다.

### 1단계. 라우팅 테이블 작성 (메인 세션, 경량)

`digest_prepare` 결과의 각 INBOX 블록은 **frontmatter + 본문 첫 200자**만 포함된다. 이것으로 분류를 결정하면 충분하다 (본문 전체는 에이전트가 직접 읽음):

- `CURRENT_TREE_JSON`의 기존 카테고리를 우선 재사용. 신설은 보수적으로.
- 각 inbox에 `(category, subcategory, topic, subtopic?)` 좌표를 부여.
- 학습 가치 없는 노트 (상태 보고, 커밋 완료 알림, 시장 데이터 덤프 등)는 `"skip": true` 표시.

라우팅 결과를 다음 JSON 배열로 작성:

```json
[
  {"inbox_id": "<ulid>", "path": "<절대경로>", "category": "<top>", "subcategory": "<mid>", "topic": "<leaf>", "subtopic": ""}
]
```

> **`path` 필드 필수** — INBOX 블록의 `path=...` 값을 그대로 복사. 에이전트가 파일을 직접 읽을 때 사용.

### 2단계. 토픽 버킷팅

라우팅 결과를 `<category>/<subcategory>/<topic>` 키로 버킷팅한다. 버킷별 inbox 개수를 집계해 병렬 배분 결정:

- 버킷이 1개뿐이거나 전체 INBOX_COUNT ≤ 5 → 메인 세션에서 단일 실행 (3단계 직접)
- 그 외 → 버킷별 에이전트 병렬 투입 (최대 `WJ_SB_DIGEST_PARALLEL`개, 기본 4)

### 3단계. 토픽별 쪽 페이지 재작성 (병렬)

각 버킷마다 **Task 도구로 서브에이전트를 병렬 투입**한다. 에이전트에게 전달할 내용:

- 담당 토픽 버킷의 `{inbox_id, path}` 목록
- 프로필 정보 (level, language, tone)
- 아래 재작성 원칙

에이전트 작업: 각 `path` 파일을 **Read 도구로 직접 읽고** 쪽 페이지 재작성 (`/wj-studybook:digest bucket` 커맨드 불필요):

1. Read 도구로 `path` 파일 읽기 (전체 본문 필요)
2. 각 inbox를 **독립된 쪽 페이지**로 재작성:
   - `body`는 원문을 옮기지 않고 **담긴 지식의 교훈**으로 재작성:
     - "이 작업에서 X를 했다" → 금지. 작업 기록·경과·결과가 아님.
     - "X라는 개념은 이런 원리로 동작하고, 이럴 때 쓰면 좋다" → 목표.
     - 프로젝트명·제품명·특정 코드베이스 참조 등 맥락 한정 정보는 모두 제거.
     - 프로필 `level`/`language`/`tone`에 맞춰 설명 깊이와 어조를 조정.
   - 본문은 `## 핵심 개념 / ## 언제 쓰는가 / ## 주의점` 등 독립 발간 형식으로 구성해도 좋음 (필수 아님).
   - 본문 끝 `## 내 말로 정리` 슬롯은 `topic-writer.sh`가 자동 삽입하므로 Claude가 추가하지 않음.
3. 결과 JSON 배열 반환 (아래 형식의 부분 결과).

메인 세션은 서브에이전트 결과를 전부 받아 단일 JSON 배열로 병합한다.

### 4단계. apply

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
    "body": "<쪽 페이지 본문 markdown (Generation Effect 슬롯 제외)>"
  }
]
```

JSON을 임시 파일에 저장한 뒤 `/wj-studybook:digest apply <tmp_file>` 호출로 파일 시스템에 적용.
`digest_apply`가 topic 노트(= 쪽 페이지) 생성, `sources[]` 누적, inbox/processed 이동, `update_index_on_add`, `unsorted_count` 감소를 처리한다.

### 자동 실행 주의사항

- 이 커맨드는 SessionEnd hook이 백그라운드(`setsid nohup claude -p ...`)에서 호출할 수 있다. 즉 **사용자 상호작용 없이 완결**되어야 한다.
- 파일 쓰기는 반드시 메인 세션의 `apply` 1회로 직렬 처리 — 서브에이전트는 JSON만 반환한다 (동시 파일 쓰기 충돌 방지).
- 실패해도 다음 SessionEnd에 inbox가 남아있으면 자연 재시도된다.
