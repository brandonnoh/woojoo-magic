# s14-backfill: /wj:studybook backfill — 과거 세션 소급 적용

## 배경
플러그인 설치 전의 과거 Claude Code 세션도 학습 자료로 살리기. `~/.claude/projects/`에 보존된 모든 jsonl 파일 스캔.

## 변경 범위
- `commands/studybook.md` (backfill 라우팅)
- `lib/backfill.sh` 신규
- `tests/wj-studybook/test-backfill.bats`

## 명령어
```
/wj:studybook backfill --since 2026-01-01
/wj:studybook backfill --since 2026-01-01 --project woojoo-magic
/wj:studybook backfill --all
```

## 흐름
```
1. ~/.claude/projects/<encoded-cwd>/*.jsonl 모두 스캔
   (옵션 --project 시 특정 디렉토리만)
2. 각 jsonl 파일 → assistant text 블록 모두 추출 (s9의 함수 재사용)
3. captured_at 추정 (각 메시지 timestamp)
4. --since 이후만 필터
5. filter.sh의 is_educational 통과한 것만 후보
6. SHA256 hash로 inbox 중복 검사 (idempotent)
7. 신규만 inbox에 ULID 부여 → 추가
8. 진행률 표시 (N/M sessions, K notes added)
9. 완료 후 메시지: "K개 노트가 inbox에 추가되었습니다. /wj:studybook digest로 분류하세요."
```

## 핵심 함수
- `backfill_find_sessions(since, project_filter)` — jsonl 파일 목록
- `backfill_process_session(jsonl_path, since)` — 세션 1개 처리
- `backfill_progress(current, total)` — 진행률 표시

## 의존
- s4 (filter)
- s9 (transcript 파싱 함수 재사용)
- s10 (digest 권장 메시지)

## 검증
```bash
bats tests/wj-studybook/test-backfill.bats
# 시나리오:
#   1) 샘플 jsonl 5개 (오늘+어제) → backfill --since 어제
#   2) 재실행 (idempotency 검증) → 추가 0
#   3) --project 필터 검증
```
