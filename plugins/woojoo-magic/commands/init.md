---
description: Ralph v2 자율 개발 루프 설치 (--force-code로 안전한 코드 업그레이드)
argument-hint: "[--force-code] [--force] [--no-backup]"
---

현재 프로젝트에 woojoo-magic의 Ralph v2 자율 개발 루프를 설치하라.

## 사용자 인자

`$ARGUMENTS` — 다음 옵션 해석:

| 인자 | 동작 |
|------|------|
| (없음) | **safe**: 기존 파일 전부 보존 |
| `--force-code` | **코드만** 덮어쓰기 (ralph.sh, lib/, prompts/, schemas/). PRD/tests.json/progress.md는 보존 ⭐ 권장 |
| `--force` | **전체** 덮어쓰기 (코드 + PRD + tests.json + progress.md) ⚠️ 주의 |
| `--no-backup` | 백업 생략 (`--force-code` 또는 `--force`와 함께, 권장 안 함) |

## 실행 방법

사용자 인자를 그대로 전달해서 install.sh를 Bash 도구로 실행하라:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/templates/ralph-starter-kit/install.sh" $ARGUMENTS
```

## 파일 카테고리

**CODE (플러그인 소스, 업그레이드 안전)**
- `ralph.sh` — 메인 오케스트레이터
- `lib/` — bash 모듈 (pre-gate, quality-gate, metrics, rollback, detect-stack 등)
- `prompts/` — Claude 프롬프트 (planner, worker, reviewer)
- `schemas/` — JSON 스키마

**DATA (사용자 작성, 업그레이드 위험)**
- `prd.md` — 제품 요구사항 (사용자가 작성한 PRD)
- `tests.json` — 태스크 큐 (진행 상태 포함)
- `progress.md` — iteration 기록

## 모드별 동작

| 모드 | CODE | DATA | 백업 |
|------|------|------|------|
| (없음) | 없을 때만 생성 | 없을 때만 생성 | 없음 |
| `--force-code` | **백업 후 덮어쓰기** | 스킵 (보존) | `.wj-backup-<timestamp>/` |
| `--force` | **백업 후 덮어쓰기** | **백업 후 덮어쓰기** | `.wj-backup-<timestamp>/` |
| `--force --no-backup` | 바로 덮어쓰기 | 바로 덮어쓰기 | 없음 (복구 불가) |

## 실행 후 할 일

- 설치 결과 요약 출력 (복사/스킵/백업 개수)
- 백업이 생성됐다면 백업 경로 명시
- 사용자가 --force-code 사용했다면 PRD/tests.json이 유지됐음을 확인해주기
- **다음 단계 안내 (순서대로):**

```
✅ Ralph v2 설치 완료

📋 다음 단계:
  1. /wj:init-prd        → prd.md + tests.json + specs/ 생성 (태스크 정의)
  2. /wj:smoke-init      → smoke-test.sh 생성 (E2E 핵심 플로우 검증, 선택)
  3. bash ralph.sh --dry-run  → 파이프라인 미리보기
  4. bash ralph.sh --iter 10  → 자율 루프 시작
```

- 신규 프로젝트라면 1~2번을 반드시 안내
- `--force-code`로 업그레이드만 한 경우에는 기존 prd.md/tests.json 유지됐으므로 3번부터 안내

## 실전 권장 사용 시나리오

### 시나리오 A: 완전히 새 프로젝트
```
/wj:init
```
(부트스트랩으로 이미 자동 설치됨. 수동 호출 거의 불필요)

### 시나리오 B: Ralph 코드만 최신 버전으로 업그레이드 ⭐
```
/wj:init --force-code
```
→ 기존 PRD, tests.json (진행 상태), progress.md는 그대로 유지
→ Ralph 실행 코드(ralph.sh, lib/, prompts/, schemas/)만 최신 버전으로 교체
→ 기존 코드는 `.wj-backup-<timestamp>/`에 자동 백업

### 시나리오 C: 전부 초기화 (위험)
```
/wj:init --force
```
→ PRD/tests.json/progress.md 포함 전부 덮어쓰기
→ 기존 모든 파일은 백업되지만, 복원하려면 수동 작업 필요
