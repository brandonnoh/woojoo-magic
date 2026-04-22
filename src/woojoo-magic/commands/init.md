---
description: (wj-magic) 프로젝트 클린 스캐폴딩 — docs/ + .dev/ + CLAUDE.md
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
