# s2-schema: 6개 데이터 스키마 정의 + frontmatter helper

## 배경
모든 데이터 파일(노트/책/인덱스/설정/프로필/트리)에 표준화된 YAML frontmatter를 강제한다. 이 표준이 없으면 후속 모든 task가 ad-hoc하게 frontmatter를 다루게 되어 호환성 깨짐. 또한 향후 자체 UI/뷰어/다른 도구와의 호환을 위해 스키마 버전 관리가 필수.

## 변경 범위

| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| `src/wj-studybook/references/SCHEMAS.md` | 신규 | 6개 스키마 명세 (사람 + Claude가 읽음) |
| `src/wj-studybook/lib/schema.sh` | 신규 | frontmatter 함수 라이브러리 |
| `tests/wj-studybook/test-schema.bats` | 신규 | 단위 테스트 |

## 6개 스키마 명세 (SCHEMAS.md 핵심 발췌)

### 1. studybook.note/v1
inbox와 topic 노트 공용. type 필드로 구분.

```yaml
---
id: 01HXKZ8R5T7A2B3C4D5E6F7G8H        # ULID, 26자, base32
schema: studybook.note/v1
type: inbox | topic                    # 필수
status: raw | classified | published   # 필수

# 수집 메타 (inbox에서 필수, topic에서는 sources[]로 이동)
captured_at: 2026-04-16T14:32:18+09:00
session_id: <uuid>
project: <name>
project_path: <abs path>
git_branch: <branch>
model: claude-opus-4-6
hook_source: stop | session_end | backfill | manual
user_prompt: "..."
related_files: ["a.ts", "b.sh"]
detected_keywords: [...]
language_hints: [bash, json]
estimated_value: 0.78                  # 0~1

# topic 전용 추가 필드
category: 개발                          # 대주제
subcategory: 프론트엔드                 # 중주제 (선택)
topic: react                           # 소주제 (선택)
subtopic: hooks                        # 4계층 (선택)
profile: <name>                        # 발간 프로필
level: beginner | intermediate | advanced
language: ko | en | ko-en
title: "..."
slug: "..."
created_at: ...
updated_at: ...
version: 1
sources:                               # 원천 추적
  - inbox_id: <ulid>
    captured_at: ...
    session_id: ...
    model: ...
verification:
  status: unverified | user_verified | external_verified
  confidence: low | medium | high
  flagged: false
  notes: ""
tags: [react, hooks]
related: ["[[other-note]]"]
prerequisites: ["[[base-concept]]"]
review:                                # SR (v2+ 사용, v1은 스키마만)
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

### 2. studybook.book/v1
주간/월간/주제별 책.

```yaml
---
id: <ulid>
schema: studybook.book/v1
type: book
book_kind: weekly | monthly | topical | backfill
title: "2026년 16주차 학습 노트"
profile: <name>
level: beginner | intermediate | advanced
language: ko | en
period_start: 2026-04-13
period_end: 2026-04-19
published_at: ...
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

### 3. studybook.index/v1
폴더별 _index.md.

```yaml
---
schema: studybook.index/v1
type: index
category: 개발
subcategory: 프론트엔드        # 선택
topic: react                  # 선택
note_count: 24
last_updated: ...
subtopics: ["hooks", "lifecycle"]
---
```

### 4. studybook.config/v1
~/.studybook/config.yaml.

```yaml
schema: studybook.config/v1
active_profile: woojoo
storage:
  inbox_dir: ~/.studybook/inbox
  books_dir: ~/.studybook/books
  retention_days: 90
sync:
  target: icloud | obsidian | git | none
  path: ~/...
```

### 5. studybook.profile/v1
~/.studybook/profiles/<name>.yaml.

```yaml
schema: studybook.profile/v1
name: woojoo
created_at: ...
learner:
  age_group: child | teen | adult
  level: none | beginner | intermediate | advanced
  interests: [react, bash]
  language: ko | en | ko-en
book_style:
  tone: 친절 | 정중 | 캐주얼
  use_emoji: true | false
  code_explanation: 상세 | 간결
  add_quiz: true | false
  add_glossary: true | false
capture:
  mode: auto | filtered | explicit
  redact_sensitive: true
  exclude_patterns: ["**/secrets/**"]
publish:
  schedule: weekly | monthly | manual
  output_dir: ~/Documents/Studybook
  format: single | by-topic | by-session
  sync_to: icloud | obsidian | git | none
```

### 6. studybook.tree/v1
~/.studybook/cache/tree.json — 분류 트리 캐시 (LLM 컨텍스트 주입용).

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

## 구현 방향 (lib/schema.sh)

### emit_frontmatter(yaml_string)
표준 입력 또는 인자로 받은 yaml 블록을 `---\n<yaml>\n---\n` 형태로 출력.

### read_frontmatter(file_path)
파일에서 첫 `---`...`---` 블록을 추출하여 stdout으로 출력 (yq로 파싱 가능한 yaml).

### ulid_generate()
26자 ULID (base32) 생성. 외부 의존 없이 순수 bash + /dev/urandom + date로 구현. 또는 가능하면 `uuidgen` fallback.

```bash
# 의사 코드
_ts=$(printf '%010X' $(($(date +%s%N)/1000000)))
_rand=$(head -c 16 /dev/urandom | base32 | tr -d '=' | head -c 16)
echo "${_ts}${_rand}" | tr '[:lower:]' '[:upper:]' | head -c 26
```

### validate_note_schema(file_path)
파일을 읽어 frontmatter 추출 → 다음 검증:
- schema 필드 존재 + 형식 `studybook.note/v\d+`
- 필수 필드: id, type, status, captured_at
- type=topic이면 추가: category, profile, sources

실패 시 stderr에 위반 항목 출력 + exit 1.

## 의존 관계

- 이 라이브러리를 사용하는 곳: s3, s4, s5, s6, s9, s10, s12, s13, s14 (거의 모든 후속 task)
- 외부 의존: `jq`, `yq` (없으면 schema.sh에서 friendly 에러)

## 검증 명령

```bash
# 라이브러리 로드
source src/wj-studybook/lib/schema.sh

# ULID 생성 테스트
ulid=$(ulid_generate)
echo "$ulid" | grep -E '^[0-9A-Z]{26}$'  # 통과해야 함

# 라운드트립 테스트
emit_frontmatter "id: $ulid\nschema: studybook.note/v1\ntype: inbox\nstatus: raw\ncaptured_at: $(date -Iseconds)" > /tmp/test.md
echo "본문" >> /tmp/test.md
read_frontmatter /tmp/test.md | yq '.id' | grep "$ulid"

# 검증 함수
validate_note_schema /tmp/test.md  # exit 0
echo "id: bad" > /tmp/bad.md
validate_note_schema /tmp/bad.md   # exit 1

# bats 테스트
bats tests/wj-studybook/test-schema.bats
```
