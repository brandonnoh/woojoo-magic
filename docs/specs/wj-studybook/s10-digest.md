# s10-digest: /wj:studybook digest — Claude 호출로 inbox → topics 분류

## 배경 (★ Phase 3 핵심)
inbox에 쌓인 raw 노트들을 Claude로 분류 → 학습자 프로필에 맞는 톤으로 다듬어서 topics/ 트리에 atomic 노트로 저장. Generation Effect 슬롯 자동 삽입.

## 변경 범위
- `commands/studybook.md` (digest 라우팅)
- `lib/digest.sh` 신규
- `lib/topic-writer.sh` 신규 (topic 노트 쓰기 헬퍼)
- `tests/wj-studybook/test-digest.bats`

## 흐름

```
1. ~/.studybook/inbox/*.md 스캔 (processed/ 제외) → N개
2. ~/.studybook/cache/tree.json 로드 (현재 분류 트리)
3. 활성 프로필 로드 (level, language, tone, age_group)
4. 메인 세션 또는 Agent 도구 호출:
   - 입력: tree.json + N개 inbox 노트 + 프로필 컨텍스트
   - 프롬프트: "기존 트리를 참고해 각 노트를 분류해줘. 새 카테고리 신설은 보수적으로. 각 노트는 학습자 수준(${level})에 맞는 톤으로 다듬어줘. 마지막에 '## 내 말로 정리' 빈 섹션 필수 추가."
   - 출력 형식: JSON (각 inbox_id → {category, subcategory, topic, subtopic, title, slug, tags[], body})
5. 각 분류 결과를 topic 노트로 저장:
   - 경로: books/<active_profile>/topics/<category>/<subcategory>/<topic>/<slug>-<ulid>.md
   - frontmatter: schema=studybook.note/v1, type=topic, status=published, sources=[{inbox_id, captured_at, session_id, model}], category, profile, level, language, tags, ...
   - 본문 끝에 "## 내 말로 정리\n<!-- ✏️ Generation Effect 슬롯 -->\n\n" 필수
6. 각 topic 노트 추가 후 update_index_on_add 호출 → _index.md + tree.json 동기화
7. 처리된 inbox 항목 → inbox/processed/<YYYY-MM-DD>/로 이동
8. tree.json unsorted_count -= 처리 수
9. 결과 요약 출력 (N개 분류, 신규 카테고리 K개, 등)
```

## 호출 방식 결정 (메인 세션 vs Agent)
- 노트 수 적음 (≤ 20): 메인 세션 (Claude가 즉시 분류)
- 많음 (> 20): Agent 도구 (subagent 위임, 컨텍스트 절약)

## 핵심 함수
- `digest_collect_inbox()` — 미분류 노트 목록
- `digest_build_prompt(notes, tree, profile)` — 프롬프트 구성
- `digest_apply_results(json_results)` — 분류 결과 → topic 파일 저장 + 인덱스 갱신
- `digest_archive_inbox(processed_ids)` — inbox/processed/ 이동

## 의존
- s5 (index update — 핵심)
- s7 (active profile)

## 검증
```bash
# 샘플 inbox 5개 준비
# /wj:studybook digest 실행 (또는 직접 호출)
# books/<profile>/topics/ 아래에 5개 노트 생성 확인
# tree.json note_count 갱신 확인
# 각 노트에 "## 내 말로 정리" 섹션 존재 확인
# inbox/processed/<오늘날짜>/에 원본 5개 이동 확인

bats tests/wj-studybook/test-digest.bats
```
