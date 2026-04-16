# l5-help-phantom: help.md에서 없는 스킬 참조 제거

> 우선순위: LOW
> 날짜: 2026-04-13

## 현황

`src/woojoo-magic/commands/help.md`에 나열된 `/wj:` 커맨드/스킬 중 일부가 실제로 존재하지 않는다.

### help.md에 나열된 전체 `/wj:` 참조

#### 커맨드 (9~17행 테이블)

| 참조 | 실제 파일 | 존재 여부 |
|------|----------|----------|
| `/wj:help` | `commands/help.md` | 존재 |
| `/wj:init` | `commands/init.md` | 존재 |
| `/wj:loop` | `commands/loop.md` | 존재 |
| `/wj:verify` | `commands/verify.md` | 존재 |
| `/wj:check` | `commands/check.md` | 존재 |

#### 스킬 (21~29행 테이블)

| 참조 | 실제 디렉토리 | 존재 여부 |
|------|-------------|----------|
| `/wj:commit` | `skills/commit/` | 존재 |
| `/wj:devrule` | `skills/devrule/` | 존재 |
| `/wj:learn` | `skills/learn/` | 존재 |
| `/wj:standards` | — | **존재하지 않음** |
| `/wj:cto-review` | `skills/cto-review/` | 존재 |
| `/wj:ideation` | `skills/ideation/` | 존재 |
| `/wj:team` | `skills/team/` | 존재 |

### 실제 디렉토리 현황

```
commands/: check.md, help.md, init.md, loop.md, verify.md
skills/:   commit/, cto-review/, devrule/, ideation/, learn/, team/
```

## 문제

**`/wj:standards` 스킬이 help.md에 나열되어 있지만 실제로 존재하지 않는다.**

- `skills/standards/` 디렉토리 없음
- `commands/standards.md` 파일 없음
- 사용자가 `/wj:standards`를 실행하면 에러 발생

help.md **27행**:
```markdown
| `/wj:standards` | 고품질 코드 표준 강제 참조 |
```

## 수정 방안

### 방안 A: 팬텀 참조 제거 (권장)

`/wj:standards`는 별도 스킬이 아니라, `references/common/HIGH_QUALITY_CODE_STANDARDS.md` 문서를 직접 참조하면 되는 내용이다. 또한 모든 skill과 agent의 프리앰블에 이미 이 참조가 포함되어 있다.

**파일: `src/woojoo-magic/commands/help.md`**

**현재 (19~29행):**
```markdown
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
```

**변경 후 (19~28행):**
```markdown
## 스킬

| 스킬 | 역할 |
|------|------|
| `/wj:commit` | 한글 커밋 메시지 자동 생성 |
| `/wj:devrule` | 프로젝트 구조 적용 개발 |
| `/wj:learn` | 교훈 → 규칙에 반영 |
| `/wj:cto-review` | 코드베이스 전수 점검 |
| `/wj:ideation` | 전문가 스쿼드 기획 논의 |
| `/wj:team` | 에이전트 팀 구성 병렬 작업 |
```

### 변경 전/후 diff

```diff
--- a/src/woojoo-magic/commands/help.md
+++ b/src/woojoo-magic/commands/help.md
@@ -24,7 +24,6 @@
 | `/wj:commit` | 한글 커밋 메시지 자동 생성 |
 | `/wj:devrule` | 프로젝트 구조 적용 개발 |
 | `/wj:learn` | 교훈 → 규칙에 반영 |
-| `/wj:standards` | 고품질 코드 표준 강제 참조 |
 | `/wj:cto-review` | 코드베이스 전수 점검 |
 | `/wj:ideation` | 전문가 스쿼드 기획 논의 |
 | `/wj:team` | 에이전트 팀 구성 병렬 작업 |
```

핵심: **27행** `| `/wj:standards` | 고품질 코드 표준 강제 참조 |` 행을 삭제한다.

### 방안 B: 스킬 실제 생성 (대안)

`skills/standards/skill.md`를 신규 생성하여 `references/common/HIGH_QUALITY_CODE_STANDARDS.md`를 강제 참조하는 스킬을 만들 수도 있다. 그러나 이미 모든 skill의 프리앰블에 품질 기준 참조가 포함되어 있으므로, 별도 스킬의 실용성은 낮다.

## 권장

**방안 A 채택** — 팬텀 행 삭제. 이유:
- 품질 기준은 이미 모든 스킬/에이전트에 내장됨
- 별도 스킬을 만들면 중복 관리 부담 발생
- 최소 변경으로 정합성 확보

## 검증

1. help.md에서 `/wj:standards` 참조가 제거되었는지 확인:
   ```bash
   grep -n 'standards' src/woojoo-magic/commands/help.md
   ```
   결과: 매치 없어야 함

2. 나머지 6개 스킬이 모두 존재하는지 확인:
   ```bash
   for skill in commit devrule learn cto-review ideation team; do
     test -f "src/woojoo-magic/skills/$skill/skill.md" && echo "$skill: OK" || echo "$skill: MISSING"
   done
   ```
   결과: 모두 OK

3. 나머지 5개 커맨드가 모두 존재하는지 확인:
   ```bash
   for cmd in help init loop verify check; do
     test -f "src/woojoo-magic/commands/$cmd.md" && echo "$cmd: OK" || echo "$cmd: MISSING"
   done
   ```
   결과: 모두 OK
