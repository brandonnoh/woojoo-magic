# s12-merge: /wj:studybook merge — 주제 병합

## 배경
시간 지나면 동의어/유사 폴더 누적 (react ↔ 리액트, dp ↔ 다이나믹프로그래밍 등). 병합 자동 탐지 + 사용자 확인 후 통합.

## 변경 범위
- `commands/studybook.md` (merge 라우팅)
- `lib/merge.sh` 신규
- `tests/wj-studybook/test-merge.bats`

## 명령어
| 명령 | 동작 |
|------|------|
| `/wj:studybook merge --auto-detect` | tree.json 분석 + Claude로 동의어 후보 탐지 → 병합 제안 (사용자 y/n) |
| `/wj:studybook merge <폴더A경로> <폴더B경로>` | 강제 병합 (A로 통합, B 삭제) |

## 흐름 (auto-detect)
```
1. tree.json 카테고리 트리 dump
2. Claude에 전달: "동의어/유사 폴더 후보를 찾아줘 (예: react ↔ 리액트)"
   → 출력: [{a, b, reason, confidence}, ...]
3. 각 후보 사용자 확인:
   "[1] '개발/프론트엔드/react/' (24개) ↔ '개발/리액트/' (8개) — 동일 주제 → 병합?  [y/n/skip]"
4. y인 경우:
   - 모든 노트를 한쪽 (note_count 더 많은 쪽)으로 mv
   - 각 노트 frontmatter의 category 경로 갱신
   - update_index_on_move 호출 → 양쪽 _index.md + tree.json 동기화
   - 빈 폴더 삭제
```

## 핵심 함수
- `merge_detect_candidates()` — tree → Claude 후보 탐지
- `merge_apply(from, to)` — 노트 이동 + frontmatter 갱신 + 인덱스 동기화
- `merge_confirm_prompt(candidate)` — 사용자 확인

## 의존
- s5 (index update — update_index_on_move)
- s10 (topics 존재 전제)

## 검증
```bash
bats tests/wj-studybook/test-merge.bats
# 시나리오: 동의어 폴더 2개 준비 → auto-detect → 병합 → 검증
```
