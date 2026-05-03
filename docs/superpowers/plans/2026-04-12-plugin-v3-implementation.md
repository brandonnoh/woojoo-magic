# woojoo-magic v3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** External Ralph loop을 삭제하고, Stop hook 기반 세션 내 자동 iteration 루프 + 클린 스캐폴딩으로 전환한다.

**Architecture:** 플러그인 소스를 `plugins/` → `src/`로 이동, Ralph 외부 파이프라인(ralph.sh + lib/ + prompts/ + schemas/) 전체 삭제, Stop hook(`stop-loop.sh`)이 L1/L2/L3 경량 게이트를 거쳐 자동 재프롬프트하는 세션 내 루프 시스템으로 대체. 유저 프로젝트에는 `/wj:init`이 `docs/`, `.dev/`, `CLAUDE.md` 3개 엔트리만 생성.

**Tech Stack:** Bash (hooks/lib), Markdown (commands/skills), JSON (hooks.json, tasks.json), bats (tests)

**Spec:** `docs/superpowers/specs/2026-04-11-plugin-v3-redesign.md`

---

## File Map

### 이동/유지 (기존 → 새 경로)

| 기존 | 새 경로 | 변경 내용 |
|---|---|---|
| `plugins/woojoo-magic/` 전체 | `src/wj-magic/` | 디렉토리 이동 |
| `plugins/woojoo-magic/shared-references/` | `src/wj-magic/references/` | 이름 변경 |
| `.claude-plugin/marketplace.json` | `.claude-plugin/marketplace.json` | `source` 경로만 `./src/wj-magic`로 변경 |

### 삭제

| 대상 | 이유 |
|---|---|
| `src/wj-magic/templates/ralph-starter-kit/` | 외부 루프 폐기 |
| `src/wj-magic/commands/{brand,harness,plan,result,smoke-init,spec-init,standards}.md` | Ralph 종속 or 통합됨 |
| `src/wj-magic/skills/{init-prd,implement-next,feedback-to-prd,seo-optimizer,ui-ux-pro-max,senior-frontend,backend-dev-rules}/` | 프루닝 |
| `src/wj-magic/hooks/install-mcp.sh` | bootstrap과 중복 |
| `.ralph-state/` (레포 루트) | 레포 자체의 Ralph 상태 |

### 신규 생성

| 파일 | 역할 |
|---|---|
| `src/wj-magic/lib/gate-l1.sh` | 정적 grep 감사 (<1초) |
| `src/wj-magic/lib/gate-l2.sh` | tsc 증분 타입체크 (2~10초) |
| `src/wj-magic/lib/gate-l3.sh` | targeted test (5~30초) |
| `src/wj-magic/lib/journal.sh` | .dev/journal/ append |
| `src/wj-magic/lib/loop-state.sh` | .dev/state/loop.state 관리 |
| `src/wj-magic/lib/tasks-sync.sh` | tasks.json 읽기/검증/다음 task 선별 |
| `src/wj-magic/hooks/stop-loop.sh` | Stop hook 메인 — L1/L2/L3 + journal + 태스크 전진 |
| `src/wj-magic/commands/loop.md` | `/wj:loop start/stop/status` |
| `src/wj-magic/commands/verify.md` | `/wj:verify [--smoke]` |
| `src/wj-magic/templates/CLAUDE.template.md` | /wj:init용 스켈레톤 |
| `src/wj-magic/templates/docs/prd.template.md` | /wj:init --with-prd용 |
| `src/wj-magic/templates/.dev/tasks.template.json` | /wj:init용 빈 레지스트리 |
| `tests/hooks/stop-loop.bats` | Stop hook 회귀 테스트 |
| `tests/lib/gate-l1.bats` | L1 게이트 테스트 |
| `tests/commands/init.bats` | /wj:init 시나리오 테스트 |
| `tests/fixtures/minimal-ts/` | 테스트 픽스처 |
| `docs/ARCHITECTURE.md` | 플러그인 설계 개요 |
| `docs/MIGRATION.md` | v2 → v3 가이드 |

### 재작성 (기존 파일, 내용 교체)

| 파일 | 변경 |
|---|---|
| `src/wj-magic/hooks/bootstrap.sh` | 176줄 → ~30줄 (자동 복사/패치/commit 전부 제거) |
| `src/wj-magic/hooks/hooks.json` | Stop hook 추가 |
| `src/wj-magic/commands/init.md` | 클린 스캐폴딩으로 전면 재작성 |
| `src/wj-magic/commands/help.md` | 새 커맨드 반영 |
| `src/wj-magic/.claude-plugin/plugin.json` | version 3.0.0, description 업데이트 |
| `src/wj-magic/settings.json` | 변경 없음 (유지) |

---

## Task 1: 레포 구조 이동

**Files:**
- Move: `plugins/woojoo-magic/` → `src/wj-magic/`
- Move: `src/wj-magic/shared-references/` → `src/wj-magic/references/`
- Modify: `.claude-plugin/marketplace.json`
- Delete: `.ralph-state/`

- [ ] **Step 1: plugins/ → src/ 이동**

```bash
git mv plugins/woojoo-magic src/wj-magic
```

- [ ] **Step 2: shared-references → references 이름 변경**

```bash
git mv src/wj-magic/shared-references src/wj-magic/references
```

- [ ] **Step 3: marketplace.json source 경로 업데이트**

`.claude-plugin/marketplace.json`에서 `source` 필드 변경:

```json
{
  "name": "wj-tools",
  "owner": { "name": "woojoo" },
  "metadata": {
    "description": "Silicon Valley 수준 개발 환경 — 리팩토링이 필요 없도록 처음부터 고품질 코딩을 강제하는 플러그인",
    "version": "3.0.0"
  },
  "plugins": [
    {
      "name": "wj",
      "source": "./src/wj-magic",
      "description": "5 commands + 7 skills + 5 agents + Stop hook 세션 내 자율 루프 + 품질 게이트(L1/L2/L3) + 언어별 Quality Standards",
      "version": "3.0.0"
    }
  ]
}
```

- [ ] **Step 4: 레포 루트 .ralph-state/ 삭제**

```bash
rm -rf .ralph-state/
```

`.gitignore`에 `.ralph-state/` 참조가 있으면 제거.

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "refactor: plugins/ → src/ 구조 이동 + shared-references → references 이름 변경"
```

---

## Task 2: Ralph 외부 루프 삭제

**Files:**
- Delete: `src/wj-magic/templates/ralph-starter-kit/` (전체)

- [ ] **Step 1: ralph-starter-kit 디렉토리 삭제**

```bash
rm -rf src/wj-magic/templates/ralph-starter-kit
```

- [ ] **Step 2: 커밋**

```bash
git add -A
git commit -m "feat!(ralph): 외부 Ralph v2 루프 전체 삭제 — 세션 내 Stop hook으로 대체 예정"
```

---

## Task 3: 불필요 커맨드 + 스킬 삭제

**Files:**
- Delete: `src/wj-magic/commands/{brand,harness,plan,result,smoke-init,spec-init,standards}.md`
- Delete: `src/wj-magic/skills/{init-prd,implement-next,feedback-to-prd,seo-optimizer,ui-ux-pro-max,senior-frontend,backend-dev-rules}/`
- Delete: `src/wj-magic/hooks/install-mcp.sh`

- [ ] **Step 1: Ralph 종속 + 레거시 커맨드 삭제**

```bash
rm src/wj-magic/commands/brand.md
rm src/wj-magic/commands/harness.md
rm src/wj-magic/commands/plan.md
rm src/wj-magic/commands/result.md
rm src/wj-magic/commands/smoke-init.md
rm src/wj-magic/commands/spec-init.md
rm src/wj-magic/commands/standards.md
```

- [ ] **Step 2: 프루닝 대상 스킬 삭제**

```bash
rm -rf src/wj-magic/skills/init-prd
rm -rf src/wj-magic/skills/implement-next
rm -rf src/wj-magic/skills/feedback-to-prd
rm -rf src/wj-magic/skills/seo-optimizer
rm -rf src/wj-magic/skills/ui-ux-pro-max
rm -rf src/wj-magic/skills/senior-frontend
rm -rf src/wj-magic/skills/backend-dev-rules
```

- [ ] **Step 3: install-mcp.sh 삭제**

```bash
rm src/wj-magic/hooks/install-mcp.sh
```

- [ ] **Step 4: 커밋**

```bash
git add -A
git commit -m "feat!(prune): 커맨드 7개 + 스킬 7개 + install-mcp 삭제 — v3 프루닝"
```

---

## Task 4: bootstrap.sh 경량화

**Files:**
- Rewrite: `src/wj-magic/hooks/bootstrap.sh`

기존 176줄 → ~30줄. 자동 Ralph 설치, 자동 MCP 주입, 자동 git commit 전부 제거. 세션 시작 시 `WOOJOO_MAGIC_SKIP_BOOTSTRAP` 체크만 하고 종료.

- [ ] **Step 1: bootstrap.sh 전면 재작성**

`src/wj-magic/hooks/bootstrap.sh`:

```bash
#!/usr/bin/env bash
# woojoo-magic v3: 세션 시작 부트스트랩
# - 프로젝트에 파일을 복사하지 않음
# - .gitignore, .mcp.json을 수정하지 않음
# - 자동 git commit을 하지 않음
#
# 비활성화: WOOJOO_MAGIC_SKIP_BOOTSTRAP=1
set -euo pipefail

if [[ "${WOOJOO_MAGIC_SKIP_BOOTSTRAP:-0}" == "1" ]]; then
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# .dev/state/ 디렉토리 보장 (Stop hook loop에 필요)
if [[ -d "${PROJECT_ROOT}/.dev" ]]; then
  mkdir -p "${PROJECT_ROOT}/.dev/state"
  mkdir -p "${PROJECT_ROOT}/.dev/journal"
fi

exit 0
```

- [ ] **Step 2: 커밋**

```bash
git add src/wj-magic/hooks/bootstrap.sh
git commit -m "refactor(bootstrap): 자동 복사/패치/commit 전부 제거 — .dev/state 보장만"
```

---

## Task 5: /wj:init 템플릿 + 커맨드 재작성

**Files:**
- Create: `src/wj-magic/templates/CLAUDE.template.md`
- Create: `src/wj-magic/templates/docs/prd.template.md`
- Create: `src/wj-magic/templates/.dev/tasks.template.json`
- Rewrite: `src/wj-magic/commands/init.md`

- [ ] **Step 1: CLAUDE.template.md 작성**

`src/wj-magic/templates/CLAUDE.template.md`:

```markdown
# {프로젝트 이름}

> 이 파일은 ~100줄 이내 프로젝트 지도. 상세는 docs/와 .claude/rules/를 참조.

## 개요
- 한 줄 설명:
- 기술 스택:
- 패키지 매니저:

## 구조
- `src/` — 비즈니스 로직
- `docs/` — 사람이 관리하는 문서 (PRD, specs, ADR)
- `.dev/` — AI 작업 흔적 (tasks.json, journal, learnings)
- `tests/` — 테스트

## 규칙 포인팅
- 코딩 표준: `.claude/rules/` 참조
- 비즈니스 룰: `docs/` 참조

## 빠른 참조
- 빌드: `npm run build`
- 테스트: `npm test`
- 린트: `npm run lint`
```

- [ ] **Step 2: prd.template.md 작성**

`src/wj-magic/templates/docs/prd.template.md`:

```markdown
# PRD — {프로젝트 이름}

> 세션 내 루프가 읽는 task 목록. `- [ ]` 미완료 / `- [x]` 완료.
> acceptance criteria는 `.dev/tasks.json`, 상세 기획은 `docs/specs/{task-id}.md` 참조.

## 개요
- 비전:
- 타겟 사용자:
- 핵심 가치:

## Phase 1 — 기반
- [ ] infra-001 모노레포 + 빌드 파이프라인 세팅
- [ ] infra-002 타입 시스템 + lint 설정

## Phase 2 — 코어
- [ ] core-001 도메인 모델 정의
- [ ] core-002 핵심 유즈케이스 구현

## 참고
- 구현 전 반드시 `.dev/tasks.json`의 `depends_on` 확인
- 각 task의 상세 기획은 `docs/specs/{task-id}.md`에 작성
```

- [ ] **Step 3: tasks.template.json 작성**

`src/wj-magic/templates/.dev/tasks.template.json`:

```json
{
  "summary": {
    "total": 0,
    "done": 0,
    "in_progress": 0,
    "pending": 0
  },
  "features": []
}
```

- [ ] **Step 4: commands/init.md 전면 재작성**

`src/wj-magic/commands/init.md`:

```markdown
---
description: 프로젝트 클린 스캐폴딩 — docs/ + .dev/ + CLAUDE.md
argument-hint: "[--with-prd]"
---

현재 프로젝트에 woojoo-magic v3 스캐폴딩을 설정한다.

## 핵심 원칙

- **최소 생성**: docs/, .dev/, CLAUDE.md 3개 엔트리만
- **기존 보존**: 이미 있는 파일은 절대 덮어쓰지 않음
- **무단 수정 금지**: .gitignore, .mcp.json을 건드리지 않음
- **자동 커밋 금지**: 파일 생성만 하고 커밋은 사용자에게 맡김

## 사용자 인자

`$ARGUMENTS`:

| 인자 | 동작 |
|------|------|
| (없음) | docs/, .dev/, CLAUDE.md 생성 (없는 것만) |
| `--with-prd` | 추가로 docs/prd.md 템플릿 생성 |

## 실행 절차

### Step 1: v2 설치 감지

프로젝트 루트에 `ralph.sh` 또는 `.ralph-state/`가 있으면 마이그레이션 안내 출력:

```
⚠️ v2.x Ralph 설치 감지됨. 마이그레이션 필요:
  1. ralph.sh, lib/, prompts/, schemas/ 삭제
  2. prd.md → docs/prd.md 이동
  3. tests.json → .dev/tasks.json 이동
  4. specs/ → docs/specs/ 이동
  5. progress.md → .dev/journal/ 이동
  6. .ralph-state/ → .dev/state/ 이동 또는 삭제
```

**v2 감지 후에도 스캐폴딩은 정상 진행**한다 (새 구조와 병존 가능).

### Step 2: 디렉토리 + 파일 생성

다음을 순서대로 실행. **이미 존재하면 skip + 로그**.

1. `docs/` 디렉토리 (없으면 생성)
2. `docs/specs/` 디렉토리 (없으면 생성)
3. `.dev/` 디렉토리 (없으면 생성)
4. `.dev/state/` 디렉토리 (없으면 생성)
5. `.dev/journal/` 디렉토리 (없으면 생성)
6. `.dev/tasks.json` — 없으면 빈 레지스트리 (`templates/.dev/tasks.template.json` 복사)
7. `CLAUDE.md` — 없으면 스켈레톤 (`templates/CLAUDE.template.md` 복사)
8. `--with-prd` 플래그 시: `docs/prd.md` — 없으면 템플릿 복사

### Step 3: 권장 사항 출력

```
✅ woojoo-magic v3 스캐폴딩 완료

📁 docs/          — 비즈니스 문서 (사람이 관리)
📁 .dev/          — AI 작업 흔적 (자동 생성)
📄 CLAUDE.md      — 프로젝트 지도 (~100줄)

💡 권장:
  - .gitignore에 `.dev/` 추가
  - CLAUDE.md를 프로젝트에 맞게 편집
  - docs/prd.md에 task 정의 후 /wj:loop start

🚀 다음: /wj:loop start
```

## 하지 않을 일

- ❌ .gitignore 수정
- ❌ .mcp.json 생성/수정
- ❌ ralph.sh, lib/, prompts/, schemas/ 복사
- ❌ LESSONS.md 빈 파일 생성
- ❌ 자동 git commit
- ❌ 기존 파일 덮어쓰기 (--force 옵션 없음)

## ⚡ 즉시 실행
```

- [ ] **Step 5: 커밋**

```bash
git add src/wj-magic/templates/ src/wj-magic/commands/init.md
git commit -m "feat(init): v3 클린 스캐폴딩 — docs/ + .dev/ + CLAUDE.md 3개 엔트리만 생성"
```

---

## Task 6: lib/gate-l1.sh — 정적 감사

**Files:**
- Create: `src/wj-magic/lib/gate-l1.sh`

L1은 이번 턴에서 편집된 TS/JS 파일에 대해 5종 정적 grep 감사를 수행한다. 빌드/테스트 없이 grep만 사용하므로 <1초.

- [ ] **Step 1: gate-l1.sh 작성**

`src/wj-magic/lib/gate-l1.sh`:

```bash
#!/usr/bin/env bash
# gate-l1.sh — L1 정적 감사 (grep only, <1초)
# 인자: 파일 목록 (stdin, 한 줄에 하나) 또는 $1로 단일 파일
# 출력: 실패 시 위반 내역을 stdout에 출력하고 exit 1
# 성공 시 exit 0
set -euo pipefail

_files=""
if [[ $# -gt 0 && -f "$1" ]]; then
  _files="$1"
else
  _files="$(cat || true)"
fi

[[ -n "$_files" ]] || exit 0

# TS/JS 파일만 필터
_ts_files=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *.ts|*.tsx|*.mts|*.cts|*.js|*.jsx) ;;
    *) continue ;;
  esac
  # 제외: .d.ts, __tests__, *.test.*, *.spec.*, node_modules, dist
  case "$f" in
    *.d.ts|*__tests__*|*.test.*|*.spec.*|*node_modules*|*dist/*) continue ;;
  esac
  [[ -f "$f" ]] || continue
  _ts_files="${_ts_files}${f}"$'\n'
done <<< "$_files"

_ts_files="$(echo "$_ts_files" | sed '/^$/d')"
[[ -n "$_ts_files" ]] || exit 0

_fail=0
_messages=""

# 1) 300줄 초과
while IFS= read -r f; do
  _lines=$(wc -l < "$f" | tr -d ' ')
  if (( _lines > 300 )); then
    _messages="${_messages}  300줄 초과: ${f} (${_lines}줄)"$'\n'
    _fail=1
  fi
done <<< "$_ts_files"

# 2) any 금지
_any_hits=$(echo "$_ts_files" | xargs grep -HnE ':\s*any\b|<any>|\bas\s+any\b' 2>/dev/null | grep -v '// @ts-' || true)
if [[ -n "$_any_hits" ]]; then
  _messages="${_messages}  any 타입 감지:"$'\n'
  _messages="${_messages}$(echo "$_any_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi

# 3) non-null assertion
_nn_hits=$(echo "$_ts_files" | xargs grep -HnE '[A-Za-z0-9_\)\]]!\.' 2>/dev/null || true)
if [[ -n "$_nn_hits" ]]; then
  _messages="${_messages}  non-null assertion(!.) 감지:"$'\n'
  _messages="${_messages}$(echo "$_nn_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi

# 4) silent catch
_sc_hits=$(echo "$_ts_files" | xargs grep -HnE 'catch\s*\(\s*\w*\s*\)\s*\{\s*\}' 2>/dev/null || true)
if [[ -n "$_sc_hits" ]]; then
  _messages="${_messages}  silent catch {} 감지:"$'\n'
  _messages="${_messages}$(echo "$_sc_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi

# 5) eslint-disable no-explicit-any
_ed_hits=$(echo "$_ts_files" | xargs grep -Hn 'eslint-disable.*no-explicit-any' 2>/dev/null || true)
if [[ -n "$_ed_hits" ]]; then
  _messages="${_messages}  eslint-disable no-explicit-any 감지:"$'\n'
  _messages="${_messages}$(echo "$_ed_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi

if (( _fail == 1 )); then
  echo "[L1] 정적 감사 실패:"
  echo "$_messages"
  exit 1
fi

echo "[L1] OK"
exit 0
```

- [ ] **Step 2: 실행 권한 부여**

```bash
chmod +x src/wj-magic/lib/gate-l1.sh
```

- [ ] **Step 3: 로컬 테스트**

```bash
# 통과 케이스 — 빈 입력
echo "" | bash src/wj-magic/lib/gate-l1.sh
# Expected: exit 0 (no output or "[L1] OK")

# 실패 케이스 — 300줄 초과 파일이 있다면
# find . -name "*.ts" | bash src/wj-magic/lib/gate-l1.sh
```

- [ ] **Step 4: 커밋**

```bash
git add src/wj-magic/lib/gate-l1.sh
git commit -m "feat(gate): L1 정적 감사 — 300줄/any/!./silent-catch/eslint-disable grep"
```

---

## Task 7: lib/gate-l2.sh — tsc 증분 타입체크

**Files:**
- Create: `src/wj-magic/lib/gate-l2.sh`

L2는 프로젝트의 tsc를 증분 모드로 실행해 타입 에러를 잡는다. `.dev/state/`에 tsbuildinfo를 보관해 콜드 스타트를 제거한다.

- [ ] **Step 1: gate-l2.sh 작성**

`src/wj-magic/lib/gate-l2.sh`:

```bash
#!/usr/bin/env bash
# gate-l2.sh — L2 tsc 증분 타입체크 (2~10초)
# 인자: $1=프로젝트 루트 (기본: $PWD)
# 출력: 실패 시 타입 에러를 stdout에 출력하고 exit 1
set -euo pipefail

_root="${1:-$PWD}"
cd "$_root"

# TS 프로젝트가 아니면 skip
if [[ ! -f "tsconfig.json" && ! -f "tsconfig.app.json" ]]; then
  echo "[L2] skip (tsconfig 없음)"
  exit 0
fi

_tsconfig="tsconfig.json"
[[ -f "$_tsconfig" ]] || _tsconfig="tsconfig.app.json"

# tsc 바이너리 탐색
_tsc=""
if [[ -x "node_modules/.bin/tsc" ]]; then
  _tsc="node_modules/.bin/tsc"
elif command -v npx >/dev/null 2>&1; then
  _tsc="npx tsc"
else
  echo "[L2] skip (tsc 바이너리 없음)"
  exit 0
fi

# turbo monorepo → pnpm turbo typecheck 시도
if [[ -f "turbo.json" ]] && command -v pnpm >/dev/null 2>&1; then
  _typecheck_script=$(jq -r '.scripts.typecheck // empty' package.json 2>/dev/null || true)
  if [[ -n "$_typecheck_script" ]]; then
    echo "[L2] turbo typecheck 실행"
    _log=$(mktemp)
    if pnpm turbo typecheck --cache-dir=.dev/state/.turbo 2>&1 | tee "$_log" | tail -5; then
      echo "[L2] OK (turbo)"
      rm -f "$_log"
      exit 0
    else
      echo "[L2] 타입 에러 (마지막 20줄):"
      tail -20 "$_log"
      rm -f "$_log"
      exit 1
    fi
  fi
fi

# 단일 프로젝트: tsc --noEmit --incremental
mkdir -p .dev/state

echo "[L2] tsc --noEmit 실행"
_log=$(mktemp)
if $_tsc --noEmit -p "$_tsconfig" \
    --incremental --tsBuildInfoFile .dev/state/tsbuildinfo 2>&1 | tee "$_log" | tail -5; then
  echo "[L2] OK"
  rm -f "$_log"
  exit 0
else
  echo "[L2] 타입 에러 (마지막 20줄):"
  tail -20 "$_log"
  rm -f "$_log"
  exit 1
fi
```

- [ ] **Step 2: 실행 권한 + 커밋**

```bash
chmod +x src/wj-magic/lib/gate-l2.sh
git add src/wj-magic/lib/gate-l2.sh
git commit -m "feat(gate): L2 tsc 증분 타입체크 — turbo/단일 프로젝트 지원"
```

---

## Task 8: lib/gate-l3.sh — targeted test

**Files:**
- Create: `src/wj-magic/lib/gate-l3.sh`

L3는 편집 파일에 매칭되는 테스트만 실행한다. 전체 스위트/빌드/smoke는 절대 실행하지 않음.

- [ ] **Step 1: gate-l3.sh 작성**

`src/wj-magic/lib/gate-l3.sh`:

```bash
#!/usr/bin/env bash
# gate-l3.sh — L3 targeted test (5~30초)
# 인자: stdin으로 편집 파일 목록
# 출력: 실패 시 테스트 에러를 stdout에 출력하고 exit 1
set -euo pipefail

_root="${1:-$PWD}"
cd "$_root"

_files="$(cat || true)"
[[ -n "$_files" ]] || { echo "[L3] skip (파일 목록 없음)"; exit 0; }

# 편집 파일 → 테스트 파일 매핑
_test_files=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  # 이미 테스트 파일이면 그대로
  case "$f" in
    *.test.*|*.spec.*|*__tests__*) _test_files="${_test_files}${f}"$'\n'; continue ;;
  esac
  # TS/JS가 아니면 skip
  case "$f" in
    *.ts|*.tsx|*.js|*.jsx) ;;
    *) continue ;;
  esac
  # 같은 디렉토리의 .test. 파일 탐색
  _dir=$(dirname "$f")
  _base=$(basename "$f" | sed 's/\.[^.]*$//')
  _ext=$(basename "$f" | sed 's/.*\.//')
  for _pattern in \
    "${_dir}/${_base}.test.${_ext}" \
    "${_dir}/${_base}.spec.${_ext}" \
    "${_dir}/__tests__/${_base}.test.${_ext}" \
    "${_dir}/__tests__/${_base}.spec.${_ext}"; do
    if [[ -f "$_pattern" ]]; then
      _test_files="${_test_files}${_pattern}"$'\n'
    fi
  done
done <<< "$_files"

_test_files="$(echo "$_test_files" | sort -u | sed '/^$/d')"
if [[ -z "$_test_files" ]]; then
  echo "[L3] skip (매칭되는 테스트 없음)"
  exit 0
fi

echo "[L3] 대상 테스트:"
echo "$_test_files" | sed 's/^/  - /'

# 테스트 러너 감지
_runner=""
if [[ -f "vitest.config.ts" || -f "vitest.config.js" || -f "vitest.config.mts" ]]; then
  _runner="vitest"
elif [[ -f "jest.config.ts" || -f "jest.config.js" || -f "jest.config.cjs" ]]; then
  _runner="jest"
elif jq -e '.devDependencies.vitest // .dependencies.vitest' package.json >/dev/null 2>&1; then
  _runner="vitest"
elif jq -e '.devDependencies.jest // .dependencies.jest' package.json >/dev/null 2>&1; then
  _runner="jest"
else
  echo "[L3] skip (테스트 러너 감지 실패)"
  exit 0
fi

# 파일 목록을 인자로 전달
_file_args=$(echo "$_test_files" | tr '\n' ' ')

_log=$(mktemp)
case "$_runner" in
  vitest)
    echo "[L3] vitest run ${_file_args}"
    if npx vitest run $_file_args --reporter=verbose 2>&1 | tee "$_log" | tail -10; then
      echo "[L3] OK"
      rm -f "$_log"
      exit 0
    fi
    ;;
  jest)
    echo "[L3] jest ${_file_args}"
    if npx jest $_file_args --verbose 2>&1 | tee "$_log" | tail -10; then
      echo "[L3] OK"
      rm -f "$_log"
      exit 0
    fi
    ;;
esac

echo "[L3] 테스트 실패 (마지막 20줄):"
tail -20 "$_log"
rm -f "$_log"
exit 1
```

- [ ] **Step 2: 실행 권한 + 커밋**

```bash
chmod +x src/wj-magic/lib/gate-l3.sh
git add src/wj-magic/lib/gate-l3.sh
git commit -m "feat(gate): L3 targeted test — 편집 파일 매칭 테스트만 실행"
```

---

## Task 9: lib/loop-state.sh + journal.sh + tasks-sync.sh

**Files:**
- Create: `src/wj-magic/lib/loop-state.sh`
- Create: `src/wj-magic/lib/journal.sh`
- Create: `src/wj-magic/lib/tasks-sync.sh`

### 9A: loop-state.sh

- [ ] **Step 1: loop-state.sh 작성**

`src/wj-magic/lib/loop-state.sh`:

```bash
#!/usr/bin/env bash
# loop-state.sh — .dev/state/loop.state 관리
# Usage:
#   loop-state.sh start [task-id]   → active=true
#   loop-state.sh stop              → active=false
#   loop-state.sh status            → JSON 출력
#   loop-state.sh get <field>       → 특정 필드 값
#   loop-state.sh set <field> <val> → 특정 필드 업데이트
#   loop-state.sh inc-failure       → consecutive_failures++
#   loop-state.sh reset-failure     → consecutive_failures=0
#   loop-state.sh inc-iter          → iteration++
set -euo pipefail

_state_dir="${CLAUDE_PROJECT_DIR:-.}/.dev/state"
_state_file="${_state_dir}/loop.state"
mkdir -p "$_state_dir"

_ensure_jq() {
  command -v jq >/dev/null 2>&1 || { echo "jq 필요"; exit 1; }
}

_read_state() {
  if [[ -f "$_state_file" ]]; then
    cat "$_state_file"
  else
    echo '{"active":false,"started_at":null,"current_task":null,"iteration":0,"consecutive_failures":0,"same_error_hash":null,"last_gate_result":null,"stop_reason":null}'
  fi
}

_write_state() {
  echo "$1" > "$_state_file"
}

_ensure_jq

case "${1:-status}" in
  start)
    _task="${2:-}"
    _now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    _state=$(_read_state | jq --arg t "$_task" --arg n "$_now" \
      '.active=true | .started_at=$n | .current_task=$t | .iteration=0 | .consecutive_failures=0 | .same_error_hash=null | .last_gate_result=null | .stop_reason=null')
    _write_state "$_state"
    echo "$_state"
    ;;
  stop)
    _reason="${2:-manual}"
    _state=$(_read_state | jq --arg r "$_reason" '.active=false | .stop_reason=$r')
    _write_state "$_state"
    echo "$_state"
    ;;
  status)
    _read_state
    ;;
  get)
    _read_state | jq -r ".${2}" 2>/dev/null
    ;;
  set)
    _state=$(_read_state | jq --arg v "$3" ".${2}=\"$3\"")
    _write_state "$_state"
    ;;
  inc-failure)
    _state=$(_read_state | jq '.consecutive_failures += 1')
    _write_state "$_state"
    echo "$_state"
    ;;
  reset-failure)
    _state=$(_read_state | jq '.consecutive_failures = 0 | .same_error_hash = null')
    _write_state "$_state"
    ;;
  inc-iter)
    _state=$(_read_state | jq '.iteration += 1')
    _write_state "$_state"
    echo "$_state"
    ;;
  *)
    echo "Usage: loop-state.sh {start|stop|status|get|set|inc-failure|reset-failure|inc-iter}"
    exit 1
    ;;
esac
```

### 9B: journal.sh

- [ ] **Step 2: journal.sh 작성**

`src/wj-magic/lib/journal.sh`:

```bash
#!/usr/bin/env bash
# journal.sh — .dev/journal/YYYY-MM-DD.md에 턴 기록 append
# Usage: journal.sh <iter> <task_id> <gate_result> [note]
set -euo pipefail

_iter="${1:-0}"
_task="${2:-unknown}"
_gate="${3:-unknown}"
_note="${4:-}"

_journal_dir="${CLAUDE_PROJECT_DIR:-.}/.dev/journal"
mkdir -p "$_journal_dir"

_today=$(date +"%Y-%m-%d")
_time=$(date +"%H:%M:%S")
_journal_file="${_journal_dir}/${_today}.md"

# 파일이 없으면 헤더 생성
if [[ ! -f "$_journal_file" ]]; then
  echo "# Journal — ${_today}" > "$_journal_file"
  echo "" >> "$_journal_file"
fi

# 변경된 파일 목록 (최근 커밋 또는 unstaged)
_changed=""
if command -v git >/dev/null 2>&1; then
  _changed=$(git diff --name-only HEAD 2>/dev/null | head -10 | sed 's/^/  - /' || true)
  if [[ -z "$_changed" ]]; then
    _changed=$(git diff --name-only 2>/dev/null | head -10 | sed 's/^/  - /' || true)
  fi
fi

{
  echo "## iter-${_iter} — ${_time}"
  echo "- task: ${_task}"
  echo "- gate: ${_gate}"
  if [[ -n "$_changed" ]]; then
    echo "- files:"
    echo "$_changed"
  fi
  if [[ -n "$_note" ]]; then
    echo "- note: ${_note}"
  fi
  echo ""
} >> "$_journal_file"

echo "[journal] ${_journal_file} 기록"
```

### 9C: tasks-sync.sh

- [ ] **Step 3: tasks-sync.sh 작성**

`src/wj-magic/lib/tasks-sync.sh`:

```bash
#!/usr/bin/env bash
# tasks-sync.sh — .dev/tasks.json 읽기/검증/다음 task 선별
# Usage:
#   tasks-sync.sh validate            → 구조 검증
#   tasks-sync.sh current             → current_task의 status
#   tasks-sync.sh next [current_id]   → 다음 eligible task id
#   tasks-sync.sh count               → done/total 카운트
set -euo pipefail

_tasks_file="${CLAUDE_PROJECT_DIR:-.}/.dev/tasks.json"

_ensure_jq() {
  command -v jq >/dev/null 2>&1 || { echo "jq 필요"; exit 1; }
}

_ensure_jq

if [[ ! -f "$_tasks_file" ]]; then
  echo '{"error":"tasks.json 없음","path":"'"$_tasks_file"'"}'
  exit 1
fi

case "${1:-validate}" in
  validate)
    # features 배열 존재 확인
    _feat_count=$(jq '.features | length' "$_tasks_file" 2>/dev/null || echo -1)
    if (( _feat_count < 0 )); then
      echo '{"valid":false,"error":"features 배열 없음 또는 JSON 파싱 실패"}'
      exit 1
    fi
    echo "{\"valid\":true,\"feature_count\":${_feat_count}}"
    ;;
  current)
    _task_id="${2:-}"
    if [[ -z "$_task_id" ]]; then
      echo '{"error":"task_id 필요"}'
      exit 1
    fi
    jq --arg id "$_task_id" '.features[] | select(.id == $id)' "$_tasks_file" 2>/dev/null || echo '{"error":"task not found"}'
    ;;
  next)
    _current="${2:-}"
    # status가 "pending" 또는 "in_progress"인 task 중 첫 번째
    # depends_on이 모두 "done"인 것만 eligible
    _next=$(jq -r --arg cur "$_current" '
      [.features[] | select(.status == "pending" or .status == "in_progress")] |
      [.[] | select(
        (.depends_on // []) as $deps |
        if ($deps | length) == 0 then true
        else
          [input_line_number] | length > 0
        end
      )] |
      [.[] | select(.id != $cur)] |
      first | .id // empty
    ' "$_tasks_file" 2>/dev/null || true)
    # depends_on 체크가 jq에서 복잡하므로, 간단 버전: pending/in_progress 중 첫 번째
    if [[ -z "$_next" ]]; then
      _next=$(jq -r --arg cur "$_current" '
        [.features[] | select(.status == "pending" or .status == "in_progress") | select(.id != $cur)] |
        first | .id // empty
      ' "$_tasks_file" 2>/dev/null || true)
    fi
    if [[ -n "$_next" ]]; then
      echo "$_next"
    else
      echo ""
    fi
    ;;
  count)
    jq '{
      total: (.features | length),
      done: ([.features[] | select(.status == "done")] | length),
      in_progress: ([.features[] | select(.status == "in_progress")] | length),
      pending: ([.features[] | select(.status == "pending")] | length)
    }' "$_tasks_file" 2>/dev/null
    ;;
  *)
    echo "Usage: tasks-sync.sh {validate|current|next|count}"
    exit 1
    ;;
esac
```

- [ ] **Step 4: 실행 권한 + 커밋**

```bash
chmod +x src/wj-magic/lib/loop-state.sh src/wj-magic/lib/journal.sh src/wj-magic/lib/tasks-sync.sh
git add src/wj-magic/lib/
git commit -m "feat(lib): loop-state + journal + tasks-sync — 세션 내 루프 기반 유틸"
```

---

## Task 10: hooks/stop-loop.sh + hooks.json 업데이트

**Files:**
- Create: `src/wj-magic/hooks/stop-loop.sh`
- Modify: `src/wj-magic/hooks/hooks.json`

Stop hook의 심장. 매 Claude 응답 종료 시 실행되어 L1→L2→L3 게이트 + journal + 태스크 전진을 수행한다.

- [ ] **Step 1: stop-loop.sh 작성**

`src/wj-magic/hooks/stop-loop.sh`:

```bash
#!/usr/bin/env bash
# stop-loop.sh — 세션 내 Ralph 루프의 Stop hook
# Claude 응답 종료 시 실행. loop.state가 active일 때만 동작.
#
# 출력 형식 (JSON):
#   block:    {"decision":"block","reason":"..."}
#   continue: (빈 출력 또는 일반 텍스트)
set -euo pipefail

_plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
_project_root="${CLAUDE_PROJECT_DIR:-$PWD}"
_lib="${_plugin_root}/lib"

# loop.state 확인
_state_file="${_project_root}/.dev/state/loop.state"
if [[ ! -f "$_state_file" ]]; then
  exit 0
fi

_active=$(jq -r '.active' "$_state_file" 2>/dev/null || echo "false")
if [[ "$_active" != "true" ]]; then
  exit 0
fi

# 30분 타임아웃 체크
_started=$(jq -r '.started_at // empty' "$_state_file" 2>/dev/null || true)
if [[ -n "$_started" ]]; then
  _started_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$_started" +%s 2>/dev/null || date -d "$_started" +%s 2>/dev/null || echo 0)
  _now_epoch=$(date +%s)
  _elapsed=$(( _now_epoch - _started_epoch ))
  if (( _elapsed > 1800 )); then
    bash "$_lib/loop-state.sh" stop "timeout-30min"
    echo '{"decision":"block","reason":"[wj:loop] 30분 타임아웃 — 루프 자동 중단. /wj:loop start로 재시작 가능."}'
    exit 0
  fi
fi

# 현재 상태 읽기
_task=$(jq -r '.current_task // ""' "$_state_file")
_iter=$(jq -r '.iteration // 0' "$_state_file")
_consecutive=$(jq -r '.consecutive_failures // 0' "$_state_file")

# iteration 증가
bash "$_lib/loop-state.sh" inc-iter >/dev/null

# 변경 파일 감지 (git diff)
_changed_files=$(git -C "$_project_root" diff --name-only HEAD 2>/dev/null || true)
if [[ -z "$_changed_files" ]]; then
  _changed_files=$(git -C "$_project_root" diff --name-only 2>/dev/null || true)
fi

# === L1: 정적 감사 ===
_l1_exit=0
_l1_result=""
if [[ -n "$_changed_files" ]]; then
  _l1_result=$(echo "$_changed_files" | bash "$_lib/gate-l1.sh" 2>&1) || _l1_exit=$?
fi

if [[ $_l1_exit -ne 0 ]]; then
  bash "$_lib/loop-state.sh" inc-failure >/dev/null
  _consecutive=$(( _consecutive + 1 ))

  # 연속 3회 실패 → 자동 중단
  if (( _consecutive >= 3 )); then
    bash "$_lib/loop-state.sh" stop "consecutive-failures"
    bash "$_lib/journal.sh" "$_iter" "$_task" "L1-fail-stop" "연속 ${_consecutive}회 실패로 중단" 2>/dev/null || true
    cat <<STOP_JSON
{"decision":"block","reason":"[wj:loop] 연속 ${_consecutive}회 게이트 실패 — 루프 자동 중단.\n\n${_l1_result}\n\n수동으로 문제를 해결한 후 /wj:loop start로 재시작하세요."}
STOP_JSON
    exit 0
  fi

  bash "$_lib/journal.sh" "$_iter" "$_task" "L1-fail" "$_l1_result" 2>/dev/null || true
  cat <<FAIL_JSON
{"decision":"block","reason":"[wj:loop] task=${_task} iter=${_iter} — L1 게이트 실패:\n\n${_l1_result}\n\n이 문제를 먼저 수정하세요. 수정 후 자동으로 다음 게이트를 진행합니다."}
FAIL_JSON
  exit 0
fi

# === L2: tsc 증분 (TS 파일 편집 시만) ===
_has_ts=$(echo "$_changed_files" | grep -E '\.(ts|tsx|mts|cts)$' || true)
if [[ -n "$_has_ts" ]]; then
  _l2_exit=0
  _l2_result=$(bash "$_lib/gate-l2.sh" "$_project_root" 2>&1) || _l2_exit=$?

  if [[ $_l2_exit -ne 0 ]]; then
    bash "$_lib/loop-state.sh" inc-failure >/dev/null
    _consecutive=$(( _consecutive + 1 ))
    if (( _consecutive >= 3 )); then
      bash "$_lib/loop-state.sh" stop "consecutive-failures"
      bash "$_lib/journal.sh" "$_iter" "$_task" "L2-fail-stop" "연속 ${_consecutive}회 실패로 중단" 2>/dev/null || true
      cat <<STOP_JSON
{"decision":"block","reason":"[wj:loop] 연속 ${_consecutive}회 게이트 실패 — 루프 자동 중단.\n\n${_l2_result}\n\n수동으로 문제를 해결한 후 /wj:loop start로 재시작하세요."}
STOP_JSON
      exit 0
    fi

    bash "$_lib/journal.sh" "$_iter" "$_task" "L2-fail" "" 2>/dev/null || true
    cat <<FAIL_JSON
{"decision":"block","reason":"[wj:loop] task=${_task} iter=${_iter} — L2 타입체크 실패:\n\n${_l2_result}\n\n이 타입 에러부터 수정하세요."}
FAIL_JSON
    exit 0
  fi
fi

# === L3: targeted test (loop 모드 전용) ===
if [[ -n "$_changed_files" && -n "$_task" ]]; then
  _l3_exit=0
  _l3_result=$(echo "$_changed_files" | bash "$_lib/gate-l3.sh" "$_project_root" 2>&1) || _l3_exit=$?

  if [[ $_l3_exit -ne 0 && "$_l3_result" != *"skip"* ]]; then
    bash "$_lib/loop-state.sh" inc-failure >/dev/null
    _consecutive=$(( _consecutive + 1 ))
    if (( _consecutive >= 3 )); then
      bash "$_lib/loop-state.sh" stop "consecutive-failures"
      bash "$_lib/journal.sh" "$_iter" "$_task" "L3-fail-stop" "연속 ${_consecutive}회 실패로 중단" 2>/dev/null || true
      cat <<STOP_JSON
{"decision":"block","reason":"[wj:loop] 연속 ${_consecutive}회 게이트 실패 — 루프 자동 중단.\n\n${_l3_result}\n\n수동으로 문제를 해결한 후 /wj:loop start로 재시작하세요."}
STOP_JSON
      exit 0
    fi

    bash "$_lib/journal.sh" "$_iter" "$_task" "L3-fail" "" 2>/dev/null || true
    cat <<FAIL_JSON
{"decision":"block","reason":"[wj:loop] task=${_task} iter=${_iter} — L3 테스트 실패:\n\n${_l3_result}\n\n실패한 테스트를 먼저 수정하세요."}
FAIL_JSON
    exit 0
  fi
fi

# === 게이트 전체 통과 ===
bash "$_lib/loop-state.sh" reset-failure >/dev/null

# task 완료 여부 확인
_task_status=""
if [[ -n "$_task" ]]; then
  _task_status=$(jq -r --arg id "$_task" '.features[] | select(.id == $id) | .status // "pending"' "${_project_root}/.dev/tasks.json" 2>/dev/null || echo "pending")
fi

if [[ "$_task_status" == "done" ]]; then
  # 다음 eligible task
  _next=$(bash "$_lib/tasks-sync.sh" next "$_task" 2>/dev/null || true)

  if [[ -n "$_next" ]]; then
    # current_task 업데이트
    jq --arg t "$_next" '.current_task=$t' "$_state_file" > "$_state_file.tmp" && mv "$_state_file.tmp" "$_state_file"
    bash "$_lib/journal.sh" "$_iter" "$_task" "pass" "완료 → 다음: $_next" 2>/dev/null || true

    # spec 파일 존재 여부 확인
    _spec_hint=""
    if [[ -f "${_project_root}/docs/specs/${_next}.md" ]]; then
      _spec_hint="docs/specs/${_next}.md를 먼저 읽고 "
    fi

    cat <<NEXT_JSON
{"decision":"block","reason":"[wj:loop] task=${_task} 완료 ✅ (L1/L2/L3 통과)\n\n다음 eligible task: ${_next}\n\n${_spec_hint}TDD로 구현하세요. 완료되면 .dev/tasks.json에서 이 task의 status를 done으로 업데이트하세요."}
NEXT_JSON
    exit 0
  else
    # 모든 task 완료
    _counts=$(bash "$_lib/tasks-sync.sh" count 2>/dev/null || echo '{}')
    bash "$_lib/loop-state.sh" stop "all-done"
    bash "$_lib/journal.sh" "$_iter" "$_task" "all-done" "전체 완료" 2>/dev/null || true
    cat <<DONE_JSON
{"decision":"block","reason":"[wj:loop] 🎉 모든 task 완료!\n\n${_counts}\n\n/wj:verify로 전체 빌드+테스트를 실행하세요."}
DONE_JSON
    exit 0
  fi
else
  # task 미완료 — 이어서 구현
  bash "$_lib/journal.sh" "$_iter" "$_task" "pass" "이어서 구현" 2>/dev/null || true

  # 동일 task 8회 반복 체크
  _same_task_iters=$(jq -r '.iteration // 0' "$_state_file")
  if (( _same_task_iters >= 8 )); then
    cat <<LONG_JSON
{"decision":"block","reason":"[wj:loop] task=${_task} — ${_same_task_iters}회 iteration 경과. task가 너무 크거나 blocker가 있을 수 있습니다.\n\ntask를 더 작게 쪼개거나, blocker를 보고하세요. 현재 status: ${_task_status}"}
LONG_JSON
    exit 0
  fi

  cat <<CONTINUE_JSON
{"decision":"block","reason":"[wj:loop] task=${_task} 게이트 통과 ✅ — 이어서 구현을 계속하세요.\n\n완료되면 .dev/tasks.json에서 이 task의 status를 done으로 업데이트하세요."}
CONTINUE_JSON
  exit 0
fi
```

- [ ] **Step 2: hooks.json에 Stop hook 추가**

`src/wj-magic/hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/bootstrap.sh"
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-summary.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/block-dangerous.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/quality-check.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/stop-loop.sh"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: 실행 권한 + 커밋**

```bash
chmod +x src/wj-magic/hooks/stop-loop.sh
git add src/wj-magic/hooks/
git commit -m "feat(loop): Stop hook 세션 내 Ralph — L1/L2/L3 게이트 + 자동 태스크 전진"
```

---

## Task 11: /wj:loop + /wj:verify 커맨드

**Files:**
- Create: `src/wj-magic/commands/loop.md`
- Create: `src/wj-magic/commands/verify.md`

- [ ] **Step 1: commands/loop.md 작성**

`src/wj-magic/commands/loop.md`:

```markdown
---
description: 세션 내 자율 개발 루프 — start/stop/status
argument-hint: "start [task-id] | stop | status"
---

세션 내 Ralph 루프를 제어한다. Stop hook이 매 턴 종료 시 L1/L2/L3 게이트를 거쳐 자동 재프롬프트한다.

## 사용법

| 명령 | 동작 |
|------|------|
| `/wj:loop start` | 다음 eligible task로 루프 시작 |
| `/wj:loop start <task-id>` | 특정 task로 루프 시작 |
| `/wj:loop stop` | 루프 즉시 중단 |
| `/wj:loop status` | 현재 루프 상태 표시 |

## 실행 절차

`$ARGUMENTS`를 파싱해 첫 단어로 분기:

### start

1. `.dev/tasks.json` 존재 확인. 없으면:
   ```
   ⚠️ .dev/tasks.json이 없습니다. /wj:init --with-prd 후 tasks를 정의하세요.
   ```

2. task-id 인자가 있으면 해당 task, 없으면 다음 eligible task 자동 선택:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/loop-state.sh" start "<task-id>"
   ```

3. 선택된 task 정보 출력:
   ```
   🚀 루프 시작: task=<task-id>

   Stop hook이 매 턴 종료 시 L1/L2/L3 게이트를 실행합니다.
   게이트 통과 + task 완료 시 자동으로 다음 task로 전진합니다.

   중단: /wj:loop stop
   ```

4. `docs/specs/<task-id>.md`가 있으면 **반드시 먼저 읽고** 구현 시작. 없으면 `.dev/tasks.json`의 acceptance criteria를 참조해 TDD로 구현 시작.

### stop

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/loop-state.sh" stop "manual"
```

출력:
```
⏹ 루프 중단됨. 일반 대화 모드로 복귀.
```

### status

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/loop-state.sh" status
```

출력 예시:
```
📊 루프 상태:
  active: true
  task: engine-auth-005
  iteration: 3
  연속 실패: 0
  시작: 2026-04-12T14:32:00Z
```

## ⚡ 즉시 실행
```

- [ ] **Step 2: commands/verify.md 작성**

`src/wj-magic/commands/verify.md`:

```markdown
---
description: 전체 빌드 + 테스트 수동 실행 (커밋 전 최종 검증)
argument-hint: "[--smoke]"
---

세션 내 루프는 L1/L2/L3 경량 게이트만 실행한다. 커밋 전 전체 빌드+테스트 최종 검증은 이 커맨드로 수동 실행.

## 실행 절차

### Step 1: 스택 감지

`package.json`에서 빌드/테스트 명령 추출:

```bash
BUILD_CMD=$(jq -r '.scripts.build // empty' package.json)
TEST_CMD=$(jq -r '.scripts.test // empty' package.json)
```

turbo monorepo면 `pnpm turbo build`, `pnpm turbo test` 사용.

### Step 2: 빌드 실행

```bash
${PM:-npm} run build
```

실패 시 에러 출력 후 중단.

### Step 3: 테스트 실행

```bash
${PM:-npm} test
```

실패 시 에러 출력 후 중단.

### Step 4: Smoke (--smoke 플래그 시)

`$ARGUMENTS`에 `--smoke`가 포함되고 `scripts/smoke.sh`가 존재하면:

```bash
bash scripts/smoke.sh
```

### Step 5: 결과 출력

```
✅ /wj:verify 완료
  빌드: OK
  테스트: OK (N개 통과)
  Smoke: {OK / skip}
```

## ⚡ 즉시 실행
```

- [ ] **Step 3: 커밋**

```bash
git add src/wj-magic/commands/loop.md src/wj-magic/commands/verify.md
git commit -m "feat(commands): /wj:loop + /wj:verify — 세션 내 루프 제어 + 전체 빌드 검증"
```

---

## Task 12: help.md + plugin.json 업데이트

**Files:**
- Rewrite: `src/wj-magic/commands/help.md`
- Modify: `src/wj-magic/.claude-plugin/plugin.json`

- [ ] **Step 1: help.md 재작성**

`src/wj-magic/commands/help.md`:

```markdown
---
description: woojoo-magic 플러그인 전체 커맨드 목록과 사용법
---

# woojoo-magic (wj) v3 — 커맨드 레퍼런스

사용자에게 아래 내용을 그대로 출력하라.

## 커맨드

| 커맨드 | 인자 | 역할 |
|--------|------|------|
| `/wj:help` | — | 이 가이드 출력 |
| `/wj:init` | `[--with-prd]` | 클린 스캐폴딩 (docs/ + .dev/ + CLAUDE.md) |
| `/wj:loop` | `start [id] \| stop \| status` | 세션 내 자율 루프 |
| `/wj:verify` | `[--smoke]` | 전체 빌드+테스트 최종 검증 |
| `/wj:check` | — | 품질 전수 점검 (TS/Python 자동 감지) |

## 스킬

| 스킬 | 역할 |
|------|------|
| `/wj:commit` | 한글 커밋 메시지 자동 생성 |
| `/wj:devrule` | 프로젝트 구조 적용 개발 |
| `/wj:learn` | 교훈 → 규칙에 반영 |
| `/wj:standards` | 고품질 코드 표준 강제 참조 |
| `/wj:cto-review` | 코드베이스 전수 점검 |
| `/wj:ideation` | 전문가 스쿼드 기획 논의 |
| `/wj:team` | 에이전트 팀 구성 병렬 작업 |

## 워크플로

```
1. /wj:init --with-prd      → 스캐폴딩 + PRD 템플릿
2. docs/prd.md 편집          → task 정의
3. .dev/tasks.json 작성      → acceptance criteria 정의
4. /wj:loop start            → 자율 루프 시작
5. (자동) L1→L2→L3 게이트    → 품질 통과 시 다음 task
6. /wj:loop stop             → 중단
7. /wj:verify                → 전체 빌드 최종 검증
8. /wj:commit                → 커밋
```

## 아키텍처

- `docs/` — 사람이 관리하는 비즈니스 문서
- `.dev/` — AI가 남기는 작업 흔적 (tasks.json, journal/, state/)
- `CLAUDE.md` — 프로젝트 지도 (~100줄)
- Stop hook — 매 턴 종료 시 L1(grep)/L2(tsc)/L3(test) 게이트 자동 실행
```

- [ ] **Step 2: plugin.json 업데이트**

`src/wj-magic/.claude-plugin/plugin.json`:

```json
{
  "name": "wj",
  "version": "3.0.0",
  "description": "클린 스캐폴딩 + 세션 내 자율 루프(Stop hook L1/L2/L3 게이트) + 5 commands + 7 skills + 5 agents + 언어별 Quality Standards",
  "author": { "name": "woojoo" },
  "keywords": ["standards", "quality", "session-loop", "clean-scaffolding", "refactoring-prevention", "typescript", "python"]
}
```

- [ ] **Step 3: 커밋**

```bash
git add src/wj-magic/commands/help.md src/wj-magic/.claude-plugin/plugin.json
git commit -m "docs(help): v3 커맨드 레퍼런스 + plugin.json v3.0.0 업데이트"
```

---

## Task 13: bats 테스트 스위트

**Files:**
- Create: `tests/lib/gate-l1.bats`
- Create: `tests/hooks/stop-loop.bats`
- Create: `tests/commands/init.bats`
- Create: `tests/fixtures/minimal-ts/`

- [ ] **Step 1: bats 설치 확인**

```bash
# bats가 없으면 설치
command -v bats || brew install bats-core
```

- [ ] **Step 2: 테스트 픽스처 생성**

`tests/fixtures/minimal-ts/package.json`:
```json
{
  "name": "test-project",
  "scripts": { "build": "echo ok", "test": "echo ok" }
}
```

`tests/fixtures/minimal-ts/tsconfig.json`:
```json
{
  "compilerOptions": { "strict": true, "noEmit": true }
}
```

`tests/fixtures/minimal-ts/src/clean.ts`:
```typescript
export function add(a: number, b: number): number {
  return a + b;
}
```

`tests/fixtures/minimal-ts/src/dirty.ts` (의도적 위반):
```typescript
export function bad(x: any): any {
  const result = x!.value;
  try { JSON.parse("{}"); } catch (e) {}
  return result;
}
```

`tests/fixtures/minimal-ts/src/long.ts`:
301줄짜리 파일 (자동 생성):

```bash
mkdir -p tests/fixtures/minimal-ts/src
printf 'export const lines = [\n' > tests/fixtures/minimal-ts/src/long.ts
for i in $(seq 1 299); do printf "  \"line-%d\",\n" "$i" >> tests/fixtures/minimal-ts/src/long.ts; done
printf '];\n' >> tests/fixtures/minimal-ts/src/long.ts
```

- [ ] **Step 3: gate-l1.bats 작성**

`tests/lib/gate-l1.bats`:

```bash
#!/usr/bin/env bats

setup() {
  GATE_L1="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-magic/lib" && pwd)/gate-l1.sh"
  FIXTURES="$(cd "$(dirname "$BATS_TEST_FILENAME")/../fixtures/minimal-ts" && pwd)"
}

@test "L1: clean TS file → 통과" {
  echo "${FIXTURES}/src/clean.ts" | bash "$GATE_L1"
}

@test "L1: any 사용 → 실패" {
  run bash -c "echo '${FIXTURES}/src/dirty.ts' | bash '$GATE_L1'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"any"* ]]
}

@test "L1: 300줄 초과 → 실패" {
  run bash -c "echo '${FIXTURES}/src/long.ts' | bash '$GATE_L1'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"300줄"* ]]
}

@test "L1: 빈 입력 → 통과" {
  echo "" | bash "$GATE_L1"
}

@test "L1: .d.ts 파일 → skip (통과)" {
  echo "foo.d.ts" | bash "$GATE_L1"
}

@test "L1: .test.ts 파일 → skip (통과)" {
  echo "foo.test.ts" | bash "$GATE_L1"
}
```

- [ ] **Step 4: stop-loop.bats 작성**

`tests/hooks/stop-loop.bats`:

```bash
#!/usr/bin/env bats

setup() {
  export CLAUDE_PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-magic" && pwd)"
  export CLAUDE_PROJECT_DIR="$(mktemp -d)"
  mkdir -p "$CLAUDE_PROJECT_DIR/.dev/state"
  mkdir -p "$CLAUDE_PROJECT_DIR/.dev/journal"
  # 빈 tasks.json
  echo '{"summary":{"total":0,"done":0},"features":[]}' > "$CLAUDE_PROJECT_DIR/.dev/tasks.json"
  # git init for diff detection
  git -C "$CLAUDE_PROJECT_DIR" init -q
  git -C "$CLAUDE_PROJECT_DIR" commit --allow-empty -m "init" -q
}

teardown() {
  rm -rf "$CLAUDE_PROJECT_DIR"
}

@test "Stop hook: loop.state 없음 → exit 0 (일반 세션)" {
  bash "$CLAUDE_PLUGIN_ROOT/hooks/stop-loop.sh"
}

@test "Stop hook: active=false → exit 0" {
  echo '{"active":false}' > "$CLAUDE_PROJECT_DIR/.dev/state/loop.state"
  bash "$CLAUDE_PLUGIN_ROOT/hooks/stop-loop.sh"
}

@test "Stop hook: active=true + no changes → 이어서 구현" {
  echo '{"active":true,"started_at":"2099-01-01T00:00:00Z","current_task":"test-001","iteration":0,"consecutive_failures":0}' \
    > "$CLAUDE_PROJECT_DIR/.dev/state/loop.state"
  run bash "$CLAUDE_PLUGIN_ROOT/hooks/stop-loop.sh"
  [[ "$output" == *"이어서 구현"* ]]
}
```

- [ ] **Step 5: init.bats 작성**

`tests/commands/init.bats`:

```bash
#!/usr/bin/env bats

setup() {
  export TEST_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "init: 빈 디렉토리 → docs/, .dev/, CLAUDE.md 생성" {
  # init.md는 Claude가 해석하는 프롬프트이므로, 실제 테스트는
  # 템플릿 파일 존재 여부만 확인
  TEMPLATES="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-magic/templates" && pwd)"
  [ -f "$TEMPLATES/CLAUDE.template.md" ]
  [ -f "$TEMPLATES/.dev/tasks.template.json" ]
}

@test "init: prd 템플릿 존재" {
  TEMPLATES="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-magic/templates" && pwd)"
  [ -f "$TEMPLATES/docs/prd.template.md" ]
}
```

- [ ] **Step 6: 테스트 실행**

```bash
bats tests/lib/gate-l1.bats
bats tests/hooks/stop-loop.bats
bats tests/commands/init.bats
```

Expected: 모든 테스트 통과

- [ ] **Step 7: 커밋**

```bash
git add tests/
git commit -m "test: bats 테스트 스위트 — gate-l1 + stop-loop + init"
```

---

## Task 14: 문서 작성

**Files:**
- Create: `docs/ARCHITECTURE.md`
- Create: `docs/MIGRATION.md`
- Rewrite: `CLAUDE.md` (레포 루트)
- Rewrite: `README.md`

- [ ] **Step 1: ARCHITECTURE.md 작성**

`docs/ARCHITECTURE.md`:

```markdown
# woojoo-magic v3 Architecture

## 철학

1. **사람 문서 vs AI 문서 분리** — `docs/`는 사람이 관리, `.dev/`는 AI 흔적
2. **최소 침투** — 유저 프로젝트에 3개 엔트리만 생성 (docs/, .dev/, CLAUDE.md)
3. **세션 내 루프** — 외부 프로세스 없이 Stop hook으로 자동 iteration
4. **경량 게이트** — L1(grep <1초) + L2(tsc 2~10초) + L3(targeted test 5~30초)

## 레이어

```
src/wj-magic/
├── hooks/          ← 자동 안전장치 (SessionStart, PreToolUse, PostToolUse, Stop)
├── lib/            ← Stop hook이 호출하는 bash 유틸
├── commands/       ← 사용자 슬래시 커맨드 (/wj:init, /wj:loop, etc.)
├── skills/         ← 반복 작업 레시피 (/wj:commit, /wj:devrule, etc.)
├── agents/         ← 전문가 서브에이전트
├── rules/          ← glob 조건부 로드 규칙
├── references/     ← 고품질 코드 표준 문서
└── templates/      ← /wj:init이 복사할 스켈레톤
```

## 유저 프로젝트 구조 (after /wj:init)

```
my-project/
├── docs/           ← 사람이 관리 (prd.md, specs/, ADR)
├── .dev/           ← AI 흔적 (tasks.json, journal/, state/, learnings.md)
├── CLAUDE.md       ← 프로젝트 지도 (~100줄)
└── (기존 소스)
```

## Stop Hook 루프 흐름

```
사용자: /wj:loop start
  → loop.state active=true
  → Claude가 task 구현
  → Claude 응답 종료
  → Stop hook 발동
  → L1(grep) → L2(tsc) → L3(test)
  → 통과: 다음 task 전진 or 이어서 구현
  → 실패: "이것부터 고쳐" 재프롬프트
  → 연속 3회 실패: 자동 중단
  → 30분 타임아웃: 자동 중단
  → /wj:loop stop: 수동 중단
```
```

- [ ] **Step 2: MIGRATION.md 작성**

`docs/MIGRATION.md`:

```markdown
# v2 → v3 마이그레이션 가이드

## Breaking Changes

1. 외부 Ralph 루프 삭제 (ralph.sh, lib/, prompts/, schemas/)
2. 유저 프로젝트 루트의 Ralph 파일 더 이상 자동 생성 안 됨
3. 커맨드 7개 삭제 (brand, harness, plan, result, smoke-init, spec-init, standards)
4. 스킬 7개 삭제 (init-prd, implement-next, feedback-to-prd, seo-optimizer, ui-ux-pro-max, senior-frontend, backend-dev-rules)

## 마이그레이션 순서

기존 v2 프로젝트에서:

1. 플러그인 업데이트 (v3.0.0 설치)
2. `/wj:init` 실행 → 새 docs/, .dev/ 구조 생성
3. 기존 파일 이동:

| 기존 위치 | 새 위치 | 명령 |
|---|---|---|
| `prd.md` | `docs/prd.md` | `mv prd.md docs/` |
| `specs/` | `docs/specs/` | `mv specs docs/` |
| `tests.json` | `.dev/tasks.json` | `mv tests.json .dev/tasks.json` |
| `progress.md` | `.dev/journal/` | `mv progress.md .dev/journal/legacy-progress.md` |
| `LESSONS.md` | `.dev/learnings.md` | `mv LESSONS.md .dev/learnings.md` |
| `.ralph-state/` | `.dev/state/` | `mv .ralph-state .dev/state` 또는 삭제 |

4. 삭제 대상:

```bash
rm -f ralph.sh smoke-test.sh
rm -rf lib/ prompts/ schemas/
```

5. `.gitignore`에서 Ralph 관련 블록 정리, `.dev/` 추가:

```gitignore
.dev/
!.dev/tasks.json
```

6. 커밋
```

- [ ] **Step 3: 레포 루트 CLAUDE.md 업데이트**

`CLAUDE.md`:

```markdown
# woojoo-magic

> Claude Code 플러그인 — 클린 스캐폴딩 + 세션 내 자율 루프

## 구조
- `src/wj-magic/` — 플러그인 소스
- `docs/` — 설계 문서, 마이그레이션 가이드
- `tests/` — bats 회귀 테스트
- `.dev/` — 개발 흔적

## 빠른 참조
- 플러그인 구조: `docs/ARCHITECTURE.md`
- v2→v3 마이그레이션: `docs/MIGRATION.md`
- 설계서: `docs/superpowers/specs/2026-04-11-plugin-v3-redesign.md`
- 테스트: `bats tests/`

## 규칙
- bash 스크립트: `set -euo pipefail` 필수
- 메인 루프에서 `local` 금지, `_prefix` 변수명 사용
- 한글 커밋 메시지
```

- [ ] **Step 4: README.md 핵심 섹션 업데이트**

README.md 상단을 v3 내용으로 교체 (기존 v2 내용 제거):

- 설치, 사용법, 커맨드 목록, 워크플로를 v3 기준으로 재작성
- help.md와 동일한 커맨드 테이블 사용

- [ ] **Step 5: 커밋**

```bash
git add docs/ARCHITECTURE.md docs/MIGRATION.md CLAUDE.md README.md
git commit -m "docs: v3 아키텍처 + 마이그레이션 가이드 + CLAUDE.md 업데이트"
```

---

## Task 15: 릴리스

**Files:**
- Modify: `CHANGELOG.md`
- Verify: `.claude-plugin/marketplace.json` (Task 1에서 이미 업데이트)
- Verify: `src/wj-magic/.claude-plugin/plugin.json` (Task 12에서 이미 업데이트)

- [ ] **Step 1: 테스트 전체 실행**

```bash
bats tests/lib/gate-l1.bats tests/hooks/stop-loop.bats tests/commands/init.bats
```

Expected: 전체 통과

- [ ] **Step 2: CHANGELOG.md에 v3.0.0 섹션 추가**

CHANGELOG.md 상단에:

```markdown
## [3.0.0] — 2026-04-12

### Breaking
- 외부 Ralph v2 루프 전체 삭제 (ralph.sh, lib/, prompts/, schemas/)
- 커맨드 7개 삭제 (brand, harness, plan, result, smoke-init, spec-init, standards)
- 스킬 7개 삭제 (init-prd, implement-next, feedback-to-prd, seo-optimizer, ui-ux-pro-max, senior-frontend, backend-dev-rules)
- 플러그인 소스 plugins/ → src/ 이동
- shared-references/ → references/ 이름 변경
- /wj:init 완전 재설계 — docs/ + .dev/ + CLAUDE.md 3개 엔트리만 생성
- bootstrap.sh 자동 복사/패치/commit 전부 제거

### Added
- `/wj:loop` — 세션 내 자율 개발 루프 (Stop hook 기반)
- `/wj:verify` — 전체 빌드+테스트 수동 실행
- L1/L2/L3 경량 품질 게이트 (gate-l1.sh, gate-l2.sh, gate-l3.sh)
- .dev/journal/ 일지 자동 기록
- .dev/state/loop.state 루프 상태 머신
- bats 테스트 스위트

### Changed
- help.md v3 커맨드 반영
- bootstrap.sh 경량화 (176줄 → 30줄)
```

- [ ] **Step 3: marketplace.json 버전 확인**

Task 1에서 이미 `3.0.0`으로 업데이트 완료. 재확인만.

- [ ] **Step 4: 최종 커밋**

```bash
git add CHANGELOG.md
git commit -m "release: v3.0.0 — 세션 내 Ralph + 클린 스캐폴딩"
```

- [ ] **Step 5: 태그 + 푸시 (사용자 승인 후)**

```bash
git tag v3.0.0
git push origin main --tags
```

---

## Dependency Graph

```
Task 1 (구조 이동)
  ├── Task 2 (Ralph 삭제)
  ├── Task 3 (스킬 프루닝)
  ├── Task 4 (bootstrap 경량화)
  └── Task 5 (init 재작성)
        ↓
Task 6 (gate-l1) ─┐
Task 7 (gate-l2) ─┤── 병렬 가능
Task 8 (gate-l3) ─┘
        ↓
Task 9 (loop-state + journal + tasks-sync)
        ↓
Task 10 (stop-loop.sh + hooks.json)
        ↓
Task 11 (loop + verify commands)
        ↓
Task 12 (help + plugin.json)
        ↓
Task 13 (tests)
        ↓
Task 14 (docs)
        ↓
Task 15 (release)
```

**병렬 실행 가능 구간:**
- Task 2, 3은 Task 1 직후 병렬 실행 가능
- Task 4, 5는 Task 1 직후 병렬 실행 가능
- Task 6, 7, 8은 서로 독립 → 병렬 실행 가능
- Task 14(docs)는 Task 12 이후 언제든 병렬 가능
