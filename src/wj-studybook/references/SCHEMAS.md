# wj-studybook 데이터 스키마 명세 (v1)

> 모든 노트/책/인덱스/설정/프로필/트리 파일은 이 스키마를 강제한다.
> 스키마 위반 시 `lib/schema.sh`의 `validate_*` 함수가 실패해야 한다.
> 스키마 버전(`/v1`, `/v2`)은 호환성 깨질 때만 올린다.

## 공통 규칙

- 모든 마크다운 파일은 `---` 로 감싼 YAML frontmatter로 시작한다.
- ID 필드는 모두 ULID(26자, Crockford base32 — `0-9A-Z` 중 `I/L/O/U` 제외).
- 시간 필드는 RFC3339 / ISO8601 (`2026-04-16T14:32:18+09:00`).
- `schema` 필드는 `<도메인>/<버전>` 형식 (예: `studybook.note/v1`).
- 스키마에 정의되지 않은 필드는 무시되지만, 추가 시 PR로 명세 갱신 필수.

---

## 1. studybook.note/v1

inbox 노트와 topic 노트 공용. `type` 필드로 구분.

### 필수 필드 (공통)

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | ULID | 노트 식별자 |
| `schema` | string | 항상 `studybook.note/v1` |
| `type` | enum | `inbox` \| `topic` \| `session_summary` |
| `status` | enum | `raw` \| `classified` \| `published` |
| `captured_at` | datetime | 수집 시각 |

### type=session_summary 추가 필드

SessionEnd hook이 생성하는 세션 단위 메타 노트. digest 분류 대상에서 자동 제외.

| 필드 | 타입 | 설명 |
|------|------|------|
| `session_id` | string | Claude Code 세션 UUID |
| `started_at` | datetime | 첫 transcript 레코드 timestamp |
| `ended_at` | datetime | 마지막 transcript 레코드 timestamp |
| `total_messages` | int | JSONL 라인 수 |
| `captured_count` | int | 이 세션에서 새로 inbox에 추가된 노트 수 |
| `end_reason` | string | Claude Code가 전달한 종료 사유 |

### type=topic 추가 필수 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `category` | string | 대주제 (예: `개발`) |
| `profile` | string | 발간 프로필명 |
| `sources` | list | 원천 inbox 추적 (각 항목 `inbox_id` 필수) |

### 전체 예시

```yaml
---
id: 01HXKZ8R5T7A2B3C4D5E6F7G8H        # ULID 26자
schema: studybook.note/v1
type: inbox                            # inbox | topic
status: raw                            # raw | classified | published

# 수집 메타 (inbox 필수, topic은 sources[]로 이동)
captured_at: 2026-04-16T14:32:18+09:00
session_id: <uuid>
project: <name>
project_path: <abs path>
git_branch: <branch>
model: claude-opus-4-6
hook_source: stop                      # stop | session_end | backfill | manual
                                       # stop:        Stop hook (응답 단위)
                                       # session_end: SessionEnd hook (세션 전수 복원)
                                       # backfill:    과거 세션 소급 (s14)
user_prompt: "..."
related_files: ["a.ts", "b.sh"]
detected_keywords: [...]
language_hints: [bash, json]
estimated_value: 0.78                  # 0~1

# topic 전용 추가 필드
category: 개발
subcategory: 프론트엔드                 # 선택
topic: react                           # 선택
subtopic: hooks                        # 4계층 (선택)
profile: woojoo
level: beginner                        # beginner | intermediate | advanced
language: ko                           # ko | en | ko-en
title: "..."
slug: "..."
created_at: ...
updated_at: ...
version: 1
sources:
  - inbox_id: <ulid>
    captured_at: ...
    session_id: ...
    model: ...
verification:
  status: unverified                   # unverified | user_verified | external_verified
  confidence: low                      # low | medium | high
  flagged: false
  notes: ""
tags: [react, hooks]
related: ["[[other-note]]"]
prerequisites: ["[[base-concept]]"]
review:                                # SR (v2+ 활성, v1은 스키마만)
  difficulty: 0.65
  last_reviewed: null
  next_review: null
  recall_count: 0
user_annotations:
  has_personal_summary: false
  highlight_count: 0
  applied_in_code: []
published_in: []                       # 발간된 책 id 목록
---
```

---

## 2. studybook.book/v1

주간/월간/주제별/백필 책. inbox/topic을 묶어 발간한 결과물.

### 필수 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | ULID | 책 식별자 |
| `schema` | string | 항상 `studybook.book/v1` |
| `type` | string | 항상 `book` |
| `book_kind` | enum | `weekly` \| `monthly` \| `topical` \| `backfill` |
| `title` | string | 책 제목 |
| `profile` | string | 발간 프로필 |
| `chapters` | list | `[{title, note_ids:[<ulid>]}]` — `publish_apply`(s13)가 자동 작성 |
| `stats.total_notes` | int | 수록 노트 수 |
| `stats.new_topics` | int | 이번 기간 신규 토픽 수 |
| `stats.revisited_topics` | int | 재방문 토픽 수 |
| `stats.user_annotated` | int | 사용자 주석 포함 노트 수 |
| `stats.applied_in_code` | int | `applied_in_code` 기록 노트 수 |
| `estimated_reading_minutes` | int | 추정 읽기 시간 (분) |

### 예시

```yaml
---
id: 01HXKZBOOK001
schema: studybook.book/v1
type: book
book_kind: weekly                      # weekly | monthly | topical | backfill
title: "2026년 16주차 학습 노트"
profile: woojoo
level: beginner
language: ko
period_start: 2026-04-13
period_end: 2026-04-19
published_at: 2026-04-20T10:00:00+09:00
chapters:
  - title: "..."
    note_ids: [<ulid>, ...]
stats:
  total_notes: 12
  new_topics: 3
  revisited_topics: 5
  user_annotated: 4
  applied_in_code: 7
estimated_reading_minutes: 18
table_of_contents_depth: 2
---
```

---

## 3. studybook.index/v1

폴더별 `_index.md` — 카테고리/서브카테고리/토픽 폴더의 메타.

### 필수 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `schema` | string | 항상 `studybook.index/v1` |
| `type` | string | 항상 `index` |
| `category` | string | 대주제 |

### 예시

```yaml
---
schema: studybook.index/v1
type: index
category: 개발
subcategory: 프론트엔드                 # 선택
topic: react                           # 선택
note_count: 24
last_updated: 2026-04-16T15:00:00+09:00
subtopics: ["hooks", "lifecycle"]
---
```

---

## 4. studybook.config/v1

`~/.studybook/config.yaml` — 전역 설정.

### 예시

```yaml
schema: studybook.config/v1
active_profile: woojoo
storage:
  inbox_dir: ~/.studybook/inbox
  books_dir: ~/.studybook/books
  retention_days: 90
sync:
  target: icloud                       # icloud | obsidian | git | none
  path: ~/...
```

---

## 5. studybook.profile/v1

`~/.studybook/profiles/<name>.yaml` — 학습자 프로필 + 발간 스타일.

### 예시

```yaml
schema: studybook.profile/v1
name: woojoo
created_at: 2026-04-15T00:00:00+09:00
learner:
  age_group: adult                     # child | teen | adult
  level: intermediate                  # none | beginner | intermediate | advanced
  interests: [react, bash]
  language: ko                         # ko | en | ko-en
book_style:
  tone: 친절                            # 친절 | 정중 | 캐주얼
  use_emoji: true
  code_explanation: 상세                # 상세 | 간결
  add_quiz: true
  add_glossary: true
capture:
  mode: auto                           # auto | filtered | explicit
  redact_sensitive: true
  exclude_patterns: ["**/secrets/**"]
publish:
  schedule: weekly                     # weekly | monthly | manual
  output_dir: ~/Documents/Studybook
  format: single                       # single | by-topic | by-session
  sync_to: icloud                      # icloud | obsidian | git | none
```

---

## 6. studybook.tree/v1

`~/.studybook/cache/tree.json` — 분류 트리 캐시.
LLM 컨텍스트 주입용. JSON 포맷 (frontmatter 아님).
`tree-view.sh`(s15)의 `tree_render`가 jq 1-pass 재귀로 ASCII 트리 렌더. `--json` 옵션 시 jq pretty print.

### 예시

```json
{
  "schema": "studybook.tree/v1",
  "generated_at": "2026-04-16T15:01:42+09:00",
  "active_profile": "woojoo",
  "unsorted_count": 12,
  "tree": {
    "개발": {
      "note_count": 47,
      "subtopics": {
        "프론트엔드": {
          "note_count": 24,
          "subtopics": {
            "react": { "note_count": 18, "subtopics": {} },
            "css": { "note_count": 6, "subtopics": {} }
          }
        }
      }
    }
  }
}
```

---

## 라이브러리 사용 (lib/schema.sh)

```bash
source src/wj-studybook/lib/schema.sh

# 1. ULID 생성
ulid=$(ulid_generate)
# → 01HXKZ8R5T7A2B3C4D5E6F7G8H

# 2. frontmatter 작성
emit_frontmatter "id: $ulid
schema: studybook.note/v1
type: inbox
status: raw
captured_at: $(date +%Y-%m-%dT%H:%M:%S%z)" > note.md
echo "본문" >> note.md

# 3. frontmatter 읽기
read_frontmatter note.md

# 4. 검증
validate_note_schema note.md && echo OK || echo FAIL
```

## 의존 도구

- 필수: bash, awk, od, /dev/urandom, date
- 선택: jq (트리/책 통계용 — 후속 task에서)
- 미사용: yq (POSIX 도구로 충분)
