# s13-publish: /wj:studybook publish weekly|monthly — 책 발간

## 배경 (★ 사용자 핵심 가치)
모인 노트들을 사용자 수준에 맞는 톤으로 다듬어 한 권의 책으로 발간. 모바일에서 책처럼 읽음.

## 변경 범위
- `commands/studybook.md` (publish 라우팅)
- `lib/publish.sh` 신규
- `lib/book-writer.sh` 신규
- `tests/wj-studybook/test-publish.bats`

## 명령어
| 명령 | 동작 |
|------|------|
| `/wj:studybook publish weekly` | 지난 7일 topics 노트 → 1권 |
| `/wj:studybook publish monthly` | 지난 30일 → 1권 |
| `/wj:studybook publish topical <주제>` | 특정 주제만 → 1권 (선택 기능) |

## 흐름
```
1. 활성 프로필 로드 (level, language, tone, age_group, book_style)
2. 기간 내 topics/ 노트 수집 (created_at 기준)
3. Claude 호출:
   - 입력: 노트들 + 프로필 컨텍스트
   - 프롬프트:
     "이 노트들로 학습자(${level}, ${age_group})가 책처럼 읽을 수 있는 책을 만들어줘.
      - 챕터 구조 (관련 노트 묶기, 입문 → 심화 순)
      - 각 챕터에 도입글 (왜 이 주제인가)
      - ${tone} 톤
      - ${language} 언어
      - 코드 옆 설명: ${code_explanation}
      - 챕터 끝 퀴즈: ${add_quiz}
      - 용어집: ${add_glossary}"
   - 출력: 책 markdown (frontmatter + 본문)
4. 책 파일 저장:
   - 경로: books/<profile>/<weekly|monthly>/<연도-wXX 또는 연도-월>.md
   - 스키마: studybook.book/v1
5. 각 포함된 노트의 frontmatter.published_in[]에 책 id 추가
6. stats 자동 계산:
   - total_notes
   - new_topics (이번 책에 처음 등장한 주제)
   - revisited_topics (이전 책에도 있던 주제)
   - user_annotated (Generation Effect 슬롯 채워진 수)
   - applied_in_code (frontmatter.applied_in_code 길이 합산)
   - estimated_reading_minutes (단어 수 / 분당 250)
7. 발간 완료 메시지 + 파일 경로 출력
```

## 책 본문 구조 (Claude에 요청할 템플릿)

```markdown
# {제목}

> {기간}, {N}개 학습 노트 · 약 {M}분 읽기

## 들어가며
{이번 주/월 배운 것 1줄 요약 + 흐름}

## 1장. {주제 그룹 1}
{도입글}

### {노트 1 제목}
{노트 본문 (level/tone 적용)}

#### 내 말로 정리
{원본 노트의 사용자 주석 (있으면)}

### {노트 2 제목}
...

## 2장. {주제 그룹 2}
...

## 용어집 (옵션)
- {term}: {정의}

## 다음에 배울 것 (Claude 추천)
- ...
```

## 핵심 함수
- `publish_collect_notes(period_start, period_end, profile)` — 노트 수집
- `publish_build_prompt(notes, profile)` — Claude 프롬프트
- `publish_compute_stats(notes)` — 통계
- `publish_write_book(content, frontmatter, path)` — 파일 저장 + 노트 published_in 갱신

## 의존
- s10 (topics 존재 전제)

## 검증
```bash
bats tests/wj-studybook/test-publish.bats
# 시나리오:
#   1) level=child 프로필 + 노트 5개 → 친절한 톤 책 생성
#   2) level=advanced 프로필 + 같은 노트 5개 → 간결/전문 톤 책 생성
#   3) stats 정확성 검증
#   4) published_in[] 갱신 검증
```
