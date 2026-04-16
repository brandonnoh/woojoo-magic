# s11-similar: /wj:studybook similar — 유사 노트 검색

## 배경
신규 노트 분류 또는 사용자 검색 시 "이미 비슷한 노트가 있는가" 확인.

## 변경 범위
- `commands/studybook.md` (similar 라우팅)
- `lib/similar.sh` 신규
- `tests/wj-studybook/test-similar.bats`

## 흐름
```
1. 입력: <쿼리 텍스트>
2. 1차 후보: ripgrep으로 books/<profile>/topics/ 풀텍스트 매칭 (제목/태그/본문)
   → Top 20개 후보 추출
3. 2차 정제 (후보 > 5개 시): tree.json + 후보 본문 일부(첫 200자)를 Claude에 전달
   → 의미적 유사도 Top 5 + 1줄 요약
4. 출력:
   파일경로 (유사도%) — 1줄 요약
   ...
```

## 핵심 함수
- `similar_keyword_match(query)` — ripgrep 1차
- `similar_semantic_rank(query, candidates)` — Claude 호출 2차
- `similar_format_output(results)` — 사용자 친화 출력

## 의존
- s10 (topics 존재해야)

## 검증
```bash
bats tests/wj-studybook/test-similar.bats
# 시나리오: 쿼리에 매칭되는 노트 5개 준비 → similar 호출 → 우선순위 검증
```
