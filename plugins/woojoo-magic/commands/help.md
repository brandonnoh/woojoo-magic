---
description: woojoo-magic 플러그인 전체 커맨드 목록과 사용법
---

# woojoo-magic (wj) — 전체 커맨드 가이드

사용자에게 아래 내용을 그대로 출력하라. 커맨드별 플래그·사용 예시를 포함한 상세 가이드다.

## 커맨드 요약

| 커맨드 | 플래그 | 역할 |
|--------|--------|------|
| `/wj:help` | — | 이 가이드 출력 |
| `/wj:init` | `--force-code` `--force` `--no-backup` | Ralph v2 (재)설치 |
| `/wj:check` | — | 프로젝트 품질 전수 점검 |
| `/wj:harness` | — | 하네스 건강 진단 |
| `/wj:brand` | — | Branded Types 점진 마이그레이션 |
| `/wj:result` | — | Result<T,E> 패턴 점진 도입 |
| `/wj:plan` | — | 300줄 초과 파일 리팩토링 계획 생성 |

---

## `/wj:init` — Ralph v2 설치/업그레이드

첫 세션에서 자동 부트스트랩되므로 수동 호출은 대부분 **업그레이드 용도**.

### 플래그

| 플래그 | CODE(ralph.sh, lib/, prompts/, schemas/) | DATA(prd.md, tests.json, progress.md) | 백업 |
|--------|------------------------------------------|---------------------------------------|------|
| *(없음)* | 없을 때만 생성 | 없을 때만 생성 | — |
| `--force-code` ⭐ | **백업 후 덮어쓰기** | 보존 | `.wj-backup-<timestamp>/` |
| `--force` ⚠️ | **백업 후 덮어쓰기** | **백업 후 덮어쓰기** | `.wj-backup-<timestamp>/` |
| `--no-backup` | `--force-code`/`--force`와 함께, 백업 생략 (권장 X) | 동일 | 없음 |

### 사용 시나리오

```bash
/wj:init                  # 새 프로젝트 (부트스트랩으로 자동)
/wj:init --force-code     # ⭐ Ralph 코드만 최신화, PRD/tests.json 유지
/wj:init --force          # ⚠️ 전부 초기화
/wj:init --force --no-backup  # 복구 불가, 위험
```

---

## `/wj:check` — 품질 전수 점검

플래그 없음. 다음을 자동 스캔하여 리포트:

1. **300줄 초과 파일** (상위 20개 + 총 개수)
2. **`any` 사용 위치** — `: any\b | <any> | as any\b`
3. **`!.` (non-null assertion)** 위치
4. **Silent catch** — `catch (...) {}` 빈 블록
5. **중복 코드 패턴** (10+ 라인 휴리스틱, 확신 없으면 "후보" 표기)

제외: `node_modules, .git, dist, build, .next, coverage`
대상: `*.ts, *.tsx, *.js, *.jsx`

---

## `/wj:harness` — 하네스 건강 진단

플래그 없음. 다음 점검:

1. **스킬 로드** — `skills/` 디렉터리 및 `SKILL.md` 프론트매터 유효성
2. **에이전트 정의** — `name`/`model`/`description` 존재, 이름 중복 없음
3. **MCP 연결** — `.mcp.json` / `~/.claude.json`에서 플러그인 MCP 확인, 누락 목록
4. **tests.json 정합성** — JSON 유효성, `id`/`status`/`acceptance_criteria` 보유, 중복 id, 완료 비율
5. **Ralph 루프 설정** — `prd.md`, `progress.md` 존재

---

## `/wj:brand` — Branded Types 점진 마이그레이션

플래그 없음. 대화형 절차:

1. **후보 탐색** — `*Id, *Email, *Amount, *Token, *Hash` 네이밍 + `string|number` 사용 지점 빈도순 상위 10~20개
2. **사용자 승인** — 각 후보에 Brand 이름 제안 (`PlayerId`, `ChipAmount`)
3. **타입 생성** — `src/types/brand.ts`에 `Brand<T,B>` + 스마트 생성자 (`createPlayerId`)
4. **호출부 업데이트** — `string` → `PlayerId`, 생성 지점에 `createPlayerId(...)` 삽입
5. **검증** — `pnpm turbo build && pnpm turbo test`

---

## `/wj:result` — Result<T,E> 패턴 점진 도입

플래그 없음. 대화형 절차:

1. **후보 탐색** — `throw new` 사용 함수를 호출 빈도 순으로
2. **Result 타입 정의** — `src/types/result.ts`에 `ok()`/`err()` 생성자
3. **함수별 전환 계획** — 에러 DU 설계 → 시그니처 변경 → 본문 교체, 사용자 승인 후 1~3개씩 적용
4. **호출자 업데이트** — `try/catch` → `if (!result.ok) ...`, 핸들링 누락 warning

---

## `/wj:plan` — 리팩토링 계획 자동 생성

플래그 없음. 다음 순서로 작업:

1. **감지** — 300줄 초과 파일, 20줄 초과 함수, 메서드 15+ God Class 휴리스틱
2. **분할 제안** — 파일별로 SRP 기반 모듈 분리 + 이동할 심볼 목록
3. **의존성 순서** — import 그래프 기반 우선순위, 순환 의존성 경고
4. **출력** — 우선순위별 리팩토링 계획서

---

## 자동 동작 (수동 호출 불필요)

- **SessionStart 부트스트랩** — 첫 세션 시 MCP + Ralph v2 자동 설치
- **PreToolUse (Bash)** — `rm -rf /`, `sudo`, force push 등 위험 명령 자동 차단
- **PostToolUse (Edit/Write)** — 편집 파일의 `any`, `!.`, 300줄 초과, Silent catch 자동 감지

## Skills (13개)

`/devrule`, `/senior-frontend`, `/backend-dev-rules`, `/commit`, `/learn`, `/team`, `/ui-ux-pro-max`, `/cto-review`, `/init-prd`, `/ideation`, `/feedback-to-prd`, `/implement-next`, `/seo-optimizer`

## Agents (5개)

- `frontend-dev` — React/Vue/Svelte UI 전문
- `backend-dev` — Express/Fastify/NestJS 서버 전문
- `engine-dev` — 순수 함수/비즈니스 로직 (IO 금지)
- `qa-reviewer` — Creator-Reviewer의 Reviewer
- `docs-keeper` — 코드 변경 시 문서 자동 동기화

## Shared References (8개 품질 가이드)

플러그인 내 `shared-references/`:
- `HIGH_QUALITY_CODE_STANDARDS.md` — 파일/함수 크기, 타입 안전, 성능
- `BRANDED_TYPES_PATTERN.md` — PlayerId/ChipAmount 경계 캐스트
- `RESULT_PATTERN.md` — throw → Result + tryAsync
- `DISCRIMINATED_UNION.md` — wrapSetWithPhase 무침습 패턴
- `NON_NULL_ELIMINATION.md` — guard clause + 로컬 변수
- `LIBRARY_TYPE_HARDENING.md` — viem 등 any 제거 (Context7 필수)
- `ZUSTAND_SLICE_PATTERN.md` — 도메인 슬라이스 + actions
- `REFACTORING_PREVENTION.md` — 리팩토링 방지 시그널

## Ralph v2 — 자율 개발 루프

```bash
bash ralph.sh --dry-run        # 5-stage 파이프라인 미리보기
bash ralph.sh --iter 10        # 자율 루프 시작
bash ralph.sh --parallel 2     # 워커 2개 병렬
bash ralph.sh --strict         # 품질 회귀 시 즉시 중단
```

## 철학

> "리팩토링은 실패의 신호다. 처음부터 제대로 짜면 리팩토링이 필요 없다."

repo: https://github.com/brandonnoh/woojoo-magic
