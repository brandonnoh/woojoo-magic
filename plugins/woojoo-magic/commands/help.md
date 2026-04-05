---
description: woojoo-magic 플러그인 전체 커맨드 목록과 사용법
---

# woojoo-magic (wj) — 커맨드 레퍼런스

사용자에게 아래 내용을 그대로 출력하라.

## 커맨드

| 커맨드 | 플래그 | 역할 |
|--------|--------|------|
| `/wj:help` | — | 이 가이드 출력 |
| `/wj:init` | `--force-code` `--force` `--no-backup` | Ralph v2 (재)설치 |
| `/wj:standards` ⭐ | — | 표준 문서 로드 + 세션 강제 적용 |
| `/wj:check` | — | 품질 전수 점검 (TS/Python 자동 감지) |
| `/wj:harness` | — | 하네스 건강 진단 |
| `/wj:brand` | — | Branded Types 점진 마이그레이션 (TS) |
| `/wj:result` | — | Result<T,E> 패턴 점진 도입 (TS) |
| `/wj:plan` | — | 300줄 초과 파일 리팩토링 계획 생성 |

---

## `/wj:init` — Ralph v2 설치/업그레이드

첫 세션에서 자동 부트스트랩되므로 수동 호출은 대부분 **업그레이드 용도**.

| 플래그 | CODE(ralph.sh, lib/, prompts/, schemas/) | DATA(prd.md, tests.json, progress.md) | 백업 |
|--------|------|------|------|
| *(없음)* | 없을 때만 생성 | 없을 때만 생성 | — |
| `--force-code` ⭐ | 백업 후 덮어쓰기 | 보존 | `.wj-backup-<ts>/` |
| `--force` ⚠️ | 백업 후 덮어쓰기 | 백업 후 덮어쓰기 | `.wj-backup-<ts>/` |
| `--no-backup` | `--force*`와 함께, 백업 생략 (권장 X) | — | 없음 |

```bash
/wj:init --force-code     # ⭐ Ralph 코드만 최신화, PRD 유지
/wj:init --force          # ⚠️ 전부 초기화
```

---

## `/wj:standards` ⭐ — 표준 강제 모드

`HIGH_QUALITY_CODE_STANDARDS.md` + 언어별 standards 로드 → 세션 전체 강제.

1. **언어 감지** — TS (`package.json`, `*.ts`) / Python (`pyproject.toml`, `*.py`)
2. **문서 Read** — 공통 원칙 + 해당 언어 standards
3. **적용 선언** — 감지 결과 + 적용 규칙 보고
4. **세션 강제** — 이후 모든 작성·수정·리뷰에 표준 준수, 검증 명령 필수

> 새 기능 구현·리팩토링·PR 준비 전에 호출.

---

## `/wj:check` — 품질 전수 점검

언어 자동 감지 후 해당 규칙 적용. 제외: `node_modules, .git, dist, build, .next, coverage, .venv, __pycache__, .pytest_cache`

### TypeScript/JavaScript (`*.ts, *.tsx, *.js, *.jsx`)
1. 300줄 초과 파일 (상위 20 + 총계)
2. `any` — `: any\b|<any>|as any\b`
3. `!.` non-null assertion
4. Silent catch — `catch(...) {}`
5. 중복 코드 10+ 라인 (휴리스틱)

### Python (`*.py`)
1. 400줄 초과 파일 (상위 20 + 총계)
2. `Any` — `: Any\b|[Any]|-> Any`
3. Bare/silent except — `except:`, `except ...: pass`
4. Mutable default — `def f(x=[])`, `def f(x={})`
5. 복잡도 > 10 — `ruff check --select C901`

출력: 치명 / 경고 / 권장 3단계.

---

## `/wj:harness` — 하네스 건강 진단

1. 스킬 로드 — `skills/` + `SKILL.md` 프론트매터
2. 에이전트 정의 — `name`/`model`/`description`, 중복 없음
3. MCP 연결 — `.mcp.json` / `~/.claude.json` 플러그인 MCP
4. tests.json 정합성 — 유효성, 필수 필드, 중복 id, 완료율
5. Ralph 루프 — `prd.md`, `progress.md` 존재

---

## `/wj:brand` — Branded Types (TS)

1. 후보 탐색 — `*Id, *Email, *Amount, *Token, *Hash` + `string|number` 빈도순 10~20개
2. 사용자 승인 — Brand 이름 제안 (`PlayerId`, `ChipAmount`)
3. 타입 생성 — `src/types/brand.ts`에 `Brand<T,B>` + 스마트 생성자
4. 호출부 업데이트 — `string` → `PlayerId`, 생성 지점 캐스트 삽입
5. 검증 — `pnpm turbo build && test`

---

## `/wj:result` — Result<T,E> (TS)

1. 후보 탐색 — `throw new` 사용 함수 호출 빈도순
2. 타입 정의 — `src/types/result.ts`에 `ok()`/`err()`
3. 전환 — 에러 DU → 시그니처 → 본문, 1~3개씩 승인 기반
4. 호출자 업데이트 — `try/catch` → `if (!result.ok)`, 누락 warning

---

## `/wj:plan` — 리팩토링 계획

1. 감지 — 300줄 초과 / 20줄 초과 함수 / God Class (메서드 15+)
2. 분할 제안 — SRP 기반 모듈 분리 + 이동 심볼
3. 의존성 순서 — import 그래프, 순환 경고
4. 출력 — 우선순위별 계획서

---

## 자동 동작 (수동 호출 불필요)

- **SessionStart** — MCP + Ralph v2 자동 부트스트랩
- **PreToolUse (Bash)** — `rm -rf /`, `sudo`, force push 차단
- **PostToolUse (Edit/Write)** — `any`, `!.`, 300줄 초과, silent catch 자동 감지

---

## Skills (13개)

`/devrule`, `/senior-frontend`, `/backend-dev-rules`, `/commit`, `/learn`, `/team`, `/ui-ux-pro-max`, `/cto-review`, `/init-prd`, `/ideation`, `/feedback-to-prd`, `/implement-next`, `/seo-optimizer`

## Agents (5개)

`frontend-dev` · `backend-dev` · `engine-dev` · `qa-reviewer` · `docs-keeper`

## Shared References (`shared-references/`)

- `HIGH_QUALITY_CODE_STANDARDS.md` — 공통 원칙 (언어 불문)
- `standards/typescript.md` — TS/JS 전용 (300줄/20줄, Branded, Result, DU)
- `standards/python.md` — Python 전용 (Ruff + Pyright strict, NewType, frozen dataclass, EAFP, 복잡도 ≤10)
- `BRANDED_TYPES_PATTERN.md` · `RESULT_PATTERN.md` · `DISCRIMINATED_UNION.md` · `NON_NULL_ELIMINATION.md` · `LIBRARY_TYPE_HARDENING.md` · `ZUSTAND_SLICE_PATTERN.md` · `REFACTORING_PREVENTION.md`

## Ralph v2 — 자율 개발 루프

```bash
bash ralph.sh --dry-run      # 5-stage 미리보기
bash ralph.sh --iter 10      # 자율 루프
bash ralph.sh --parallel 2   # 워커 2개 병렬
bash ralph.sh --strict       # 품질 회귀 시 중단
```

---

> "리팩토링은 실패의 신호다. 처음부터 제대로 짜면 리팩토링이 필요 없다."

repo: https://github.com/brandonnoh/woojoo-magic
