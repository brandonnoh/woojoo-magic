---
name: learn
description: >
  개발 중 발견된 실수·패턴·교훈을 영구 반영하는 스킬.
  같은 실수가 반복되지 않도록 배운 것을 규칙으로 굳힐 때 반드시 사용하라.
  "기억해", "remember", "learn", "이거 규칙에 추가", "devrule 업데이트",
  "다음에도 이렇게 해", 버그 수정 후 반복 가능한 교훈이 발견됐을 때 자동 트리거.
---

**품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)

# Learn - 개발 규칙 자동 학습 스킬

## 목적

버그 수정, 트러블슈팅, 코드 리뷰 과정에서 발견된 교훈을 **적절한 범위의 규칙 파일에 영구 반영**하여 같은 실수를 반복하지 않게 한다.

## 트리거 조건

### 명시적 트리거
- 사용자가 "기억해", "learn", "규칙 추가", "devrule 업데이트" 등 요청

### 자동 트리거 (감지 시)
- 버그의 근본 원인이 프레임워크/라이브러리 특성에 기인한 **반복 가능한 패턴**일 때
- 같은 유형의 실수가 세션 내에서 2회 이상 발생했을 때
- 트러블슈팅 완료 후 교훈이 프로젝트 전반에 적용 가능할 때

## 실행 절차

### 1. 교훈 범위 판단 (가장 중요)

교훈을 기록하기 전, 먼저 **범용인가 vs 프로젝트 특화인가**를 판단한다.

| 범용 (Cross-project) | 프로젝트 특화 (Project-specific) |
|---------------------|--------------------------------|
| OS/플랫폼 동작 차이 (macOS vs Linux) | 이 프로젝트의 아키텍처 패턴 |
| 언어/런타임 특성 (bash, TS, Python) | 프로젝트의 특정 기술 스택 선택 이유 |
| 범용 개발 원칙 (이름 추측 금지 등) | 프로젝트 내 특정 API 계약/구조 |
| 툴링 버그/주의사항 (bats 1.13.0 등) | 팀 컨벤션, 프로젝트 전용 커맨드 |

**판단 기준**: "다른 프로젝트에서도 동일하게 적용되는가?" → Yes = 범용, No = 프로젝트 특화

### 2. 범용 교훈 → 글로벌 devrule 업데이트

**대상 파일:**
- `~/.claude/skills/devrule/skill.md` — 메인 개발 원칙
- `~/.claude/skills/devrule/references/MACOS_DEV_REFERENCE.md` — OS/플랫폼 기술 레퍼런스
- `~/.claude/skills/devrule/references/TROUBLESHOOTING.md` — 범용 트러블슈팅

**분류:**

| 분류 | 대상 파일 | 예시 |
|------|-----------|------|
| **Common Error** | `devrule/skill.md` Common errors 테이블 | 한 줄로 요약 가능한 에러→원인→해결 |
| **패턴/원칙** | `devrule/skill.md` 본문에 새 섹션 | OS 동작 차이, 언어 특성 기반 규칙 |
| **기술 상세** | `devrule/references/MACOS_DEV_REFERENCE.md` | API 사용법, 주의사항 |
| **트러블슈팅** | `devrule/references/TROUBLESHOOTING.md` | 디버깅 과정, 재현 조건, 스택트레이스 |

> **주의**: 범용 규칙임에도 특정 프로젝트에 연결된 내용(프로젝트명, 경로, API 엔드포인트 등)은 **절대 포함하지 않는다**. 글로벌 devrule은 어떤 프로젝트에서 읽어도 의미 있어야 한다.

#### Common errors 테이블 추가 시
```
| [에러 현상] | [근본 원인] | [해결 방법] |
```
테이블 마지막 행에 추가.

#### 새 섹션 추가 시 (skill.md 본문)
Common errors 테이블과 References 섹션 사이에 추가. 구조:
```markdown
## [규칙 제목]

[1~2줄 설명]

### 증상
- [사용자가 겪는 현상]

### 해결 패턴
[코드 예시]

### 적용 대상
[어떤 상황에서 이 규칙을 적용해야 하는지]
```

### 3. 프로젝트 특화 교훈 → 프로젝트 CLAUDE.md 업데이트

현재 프로젝트의 루트 `CLAUDE.md`에 기록한다.

**기존 `## 개발 교훈` 섹션이 있으면 거기에 추가, 없으면 파일 끝에 새 섹션 추가:**

```markdown
## 개발 교훈

### [날짜] [교훈 제목]

[교훈 내용 — 왜 이 결정을 했는지, 다음에 어떻게 해야 하는지]
```

**CLAUDE.md가 없는 프로젝트**: `## 개발 교훈` 섹션만 포함한 CLAUDE.md 생성 금지 — 사용자에게 알리고 다른 방법 제안.

### 4. MEMORY.md 동기화 (선택적)

세션 간 빠른 참조가 필요한 내용만 MEMORY.md에 요약 기록.
- MEMORY.md는 요약본, devrule/CLAUDE.md가 원본(source of truth)
- MEMORY.md 200줄 제한 — 이미 가득 찬 경우 추가하지 않고 devrule만 업데이트

### 5. 완료 보고

사용자에게 업데이트 내용을 간결히 보고:
```
learn 완료:
- [범용] devrule/skill.md: Common errors에 X 추가
- [범용] devrule/references/TROUBLESHOOTING.md: Y 항목 추가
- [프로젝트] CLAUDE.md: ## 개발 교훈에 Z 추가
- MEMORY.md: 동기화 완료 (선택적)
```

## 주의사항

- devrule skill.md는 500줄 이내로 유지. 초과 시 references로 분리
- **글로벌 devrule에 프로젝트 특화 내용 절대 금지** — 검증: "다른 프로젝트에서도 이 규칙이 의미 있는가?"
- 코드 예시는 범용적으로 작성 (프로젝트 특화 경로/이름 제외)
- 사용자가 "기억해"라고 했을 때 MEMORY.md만 업데이트하지 말 것 — **반드시 devrule 또는 CLAUDE.md도 업데이트**
- **파일 크기 제한, Branded Types, Result 패턴 등 공통 품질 기준은 learn 대상이 아님** — `references/common/AGENT_QUICK_REFERENCE.md`(플러그인 레벨)에서 관리
