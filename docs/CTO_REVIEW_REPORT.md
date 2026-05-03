# CTO Review Report — 2026-04-17

## 도메인별 이슈 수

| 도메인 | CRITICAL | HIGH | MEDIUM | LOW | 합계 |
|--------|----------|------|--------|-----|------|
| woojoo-magic 코어 | 2 | 4 | 6 | 5 | 17 |
| wj-studybook lib | 2 | 6 | 9 | 5 | 22 |
| wj-studybook hooks/tests/config | 1 | 5 | 6 | 2 | 14 |
| **합계** | **5** | **15** | **21** | **12** | **53** |

---

## CRITICAL 이슈 전체 목록

### [CRITICAL-SEC-C1] index-update.sh — jq 경로 표현식 인젝션
- **위치**: `src/wj-studybook/lib/index-update.sh:63-80`
- Claude JSON에서 오는 `_cat`, `_sub`, `_top` 값이 jq 프로그램 문자열에 직접 보간됨. `category` 필드에 `"` 또는 `]` 포함 시 임의 jq 표현식 실행 가능.
- **수정**: `jq --arg`/`--argjson` + `getpath([$cat])` 방식으로 변경. category/slug 값에 `^[a-zA-Z0-9가-힣_-]+$` 검증 추가.

### [CRITICAL-SEC-C2] config-set.sh — yq eval 인젝션
- **위치**: `src/wj-studybook/lib/config-set.sh:67`
- `yq eval ".${_k} = \"${_v}\"" -i "$_f"` — `_v`가 사용자 입력. 큰따옴표 탈출 시 추가 표현식 실행 가능.
- **수정**: `yq e '.key = env(VALUE)'` + env 주입 방식 사용.

### [CRITICAL-ARCH-C3] gate-l1.sh — 300줄 자가 위반 (363줄)
- **위치**: `src/wj-magic/lib/gate-l1.sh`
- 6개 언어 검사(TS/JS/Python/Go/Rust/Swift/Kotlin)를 한 파일에서 처리. 플러그인이 강제하는 300줄 규칙을 스스로 위반.
- **수정**: `gate-l1-ts.sh`, `gate-l1-py.sh` 등 언어별 서브모듈로 분리 후 `gate-l1.sh`를 오케스트레이터로만 유지.

### [CRITICAL-QUAL-C4] stop-loop.sh — `local` 규약 위반
- **위치**: `src/wj-magic/hooks/stop-loop.sh:21-23, 47-48`
- `_run_l1()`, `_run_l2()` 함수 내 `local` 선언. CLAUDE.md 규칙("메인 루프에서 local 금지") 위반. 리턴값은 전역 변수로 내보내면서 파라미터는 local로 선언하는 설계 불일치.
- **수정**: `local` 제거하고 `_run_l1_files` 등 전역 변수로 통일.

### [CRITICAL-ARCH-C5] capture-session-end.sh — dedup hash trailing-newline 불일치
- **위치**: `src/wj-studybook/hooks/capture-session-end.sh:59-83, 121`
- `write_inbox_note`가 저장 시 trailing newline 포함, `_cse_hash_text`는 미포함으로 계산 → dedup 실패 → 동일 발화가 Stop + SessionEnd 양쪽에 중복 저장됨.
- **수정**: 두 경로의 hash 계산 방식을 통일 (파일 body 추출 시 trailing newline 제거 또는 양쪽 모두 trailing newline 포함).

---

## HIGH 이슈 상위 10개

1. **[HIGH-SEC-H1] topic-writer/digest — category/slug 경로 탐색 문자 미검증** (`src/wj-studybook/lib/topic-writer.sh:35`, `digest.sh:184`) — `../` 등 포함 시 topics 디렉토리 밖에 파일 생성 가능.
2. **[HIGH-SEC-H2] gate-l1.sh — xargs 인젝션 위험** (`src/wj-magic/lib/gate-l1.sh` 전반) — `xargs grep` 패턴에서 특수문자 파일명 오작동. `xargs -d '\n'` 추가 필요.
3. **[HIGH-SEC-H3] test-filter.bats — ghp_ 픽스처 FAKE 규약 미준수** (`tests/wj-studybook/test-filter.bats:162,168`) — `ghp_abcdefghij...` 실 prefix 사용. `ghp_FAKE_` 규약으로 교체 필요.
4. **[HIGH-ARCH-H4] hooks.json 래퍼 추가로 테스트 jq 쿼리 불일치** (`tests/wj-studybook/test-capture-stop.bats:36-45`, `test-capture-session-end.bats:59-68`) — `.Stop[0]` → `.hooks.Stop[0]`로 갱신 필요.
5. **[HIGH-ARCH-H5] studybook_dir/active_profile/profile_field 6개 파일 중복** — 환경변수 우선순위도 파일마다 미묘하게 다름. `config-helpers.sh`에 표준화 필요.
6. **[HIGH-ARCH-H6] now_iso() 4개 파일 중복** (`book-writer.sh`, `inbox-writer.sh`, `topic-writer.sh`, `index-update.sh`) — macOS fallback 불일치 포함. `config-helpers.sh`에 `get_iso_now()` 단일 구현.
7. **[HIGH-QUAL-H7] backfill.sh + inbox-writer.sh inbox 경로 하드코딩** — `${HOME}/.studybook/inbox` 고정 참조로 `STUDYBOOK_HOME` 테스트 격리 불가.
8. **[HIGH-QUAL-H8] quality-check.sh / session-summary.sh — 변수명 UPPER_CASE 혼용** — `INPUT`, `FILE`, `WARN` 등. `_prefix` 규약 위반으로 환경변수 충돌 위험.
9. **[HIGH-QUAL-H9] capture-session-end.sh — tmp 파일 정리 누락** (`L143-145`) — sed 실패 시 `.tmp.$$` 고아 파일 누적. `trap 'rm -f "$_tmp"' EXIT` 추가 필요.
10. **[HIGH-QUAL-H10] inbox-writer.sh — hook_source 하드코딩** (`L76`) — `WJ_SB_HOOK_SOURCE` 환경변수를 읽지 않아 sed 2-step 패치 필요. 함수 파라미터 또는 `${WJ_SB_HOOK_SOURCE:-stop}` 직접 읽기로 수정.

---

## 긍정적 평가

- **순환 참조 없음**: 두 플러그인 모두 의존 방향이 단방향으로 깨끗함 (hooks → lib).
- **set -euo pipefail 일관 준수**: 대부분의 스크립트가 선언 중.
- **ULID 기반 유니크 파일명**: 동시 실행 시 파일 충돌 없음.
- **hooks.json 구조 일관성**: 오늘 수정으로 woojoo-magic과 동일한 `"hooks"` 래퍼 구조 통일.
- **시크릿 패턴 대부분 준수**: `sk_test_FAKE_` 규약이 잘 적용되어 있으나 `ghp_` 하나 누락.

---

## Wave 수정 전략

### Wave 1 — 보안 패치 (P0, 즉시, 독립적)

| 에이전트 | 소유 파일 | 수정 내용 |
|---------|---------|---------|
| W1-A: woojoo-magic 보안 | `lib/gate-l1.sh`, `hooks/stop-loop.sh`, `hooks/quality-check.sh`, `hooks/session-summary.sh` | xargs `-d '\n'` 추가, `local` 제거, UPPER_CASE → `_prefix` 변수명 |
| W1-B: studybook 보안 | `lib/index-update.sh`, `lib/config-set.sh`, `lib/topic-writer.sh`, `lib/digest.sh`, `tests/wj-studybook/test-filter.bats` | jq/yq injection 패치, slug 검증, ghp_FAKE_ 교체 |

Wave 1-A, 1-B 는 파일 소유권이 겹치지 않으므로 **병렬 실행 가능**.

### Wave 2 — 버그 수정 (P1, Wave 1 완료 후)

| 에이전트 | 소유 파일 | 수정 내용 |
|---------|---------|---------|
| W2-A: hooks 버그 | `hooks/capture-session-end.sh`, `hooks/capture-stop.sh`, `hooks/hooks.json` | dedup hash 통일, tmp trap, hook_source 환경변수 읽기, tests jq 쿼리 수정 |
| W2-B: lib 버그 | `lib/inbox-writer.sh`, `lib/backfill.sh`, `lib/config-helpers.sh` | inbox 경로 hardcoding 제거, silent catch 제거, get_iso_now 통합 |
| W2-C: tests 버그 | `tests/wj-studybook/test-filter.bats`, `tests/wj-studybook/test-sync.bats` | teardown 추가, BOOK_DIR 정리 |

W2-A, 2-B, 2-C 병렬 실행 가능.

### Wave 3 — 리팩토링 (P2~P3, Wave 2 완료 후)

- `gate-l1.sh` 언어별 파일 분리 (gate-l1-ts.sh, gate-l1-py.sh 등)
- studybook_dir/active_profile/profile_field 중복 제거 → config-helpers.sh 표준화
- `stop-loop.sh` task 전이 로직 분리
- `studybook.md` argument-hint 갱신 (merge/backfill/sync 추가)
- `validate_note_schema`에 session_summary 타입 필수 필드 검증 추가
