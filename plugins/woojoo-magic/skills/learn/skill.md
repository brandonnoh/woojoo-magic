---
name: learn
description: |
  개발 중 발견된 실수, 패턴, 교훈을 개발 규칙 파일과 references에 자동 반영하는 스킬.
  트리거: "기억해", "remember", "learn", "이거 규칙에 추가", "devrule 업데이트", "다음에도 이렇게 해",
  또는 버그 수정/트러블슈팅 완료 후 반복 가능한 교훈이 감지되었을 때 자동 트리거.
  실수를 반복하지 않도록 프로젝트 개발 규칙을 지속적으로 학습·축적하는 시스템.
---

## 품질 기준 (woojoo-magic 표준)

**반드시 참조: `../../shared-references/HIGH_QUALITY_CODE_STANDARDS.md`**

### 핵심 규칙
- 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드 + guard clause
- Branded Types 적용 (PlayerId, ChipAmount 등) — `../../shared-references/BRANDED_TYPES_PATTERN.md`
- Result<T,E> 패턴으로 에러 처리 — `../../shared-references/RESULT_PATTERN.md`
- Discriminated Union으로 상태 모델링 — `../../shared-references/DISCRIMINATED_UNION.md`
- 같은 패턴 2곳 이상 → 공통 유틸 추출
- CSS animation > JS animation (성능)
- Silent catch 금지

### MCP 필수 사용
- **serena**: 코드 탐색/수정 (symbolic tools)
- **context7**: 라이브러리 API 문서 조회
- **sequential-thinking**: 복잡한 리팩토링 계획

### 리팩토링 방지 시그널
파일 작성 중 다음 징후가 보이면 즉시 분할:
- 파일 200줄 돌파 → 300줄 넘기 전에 SRP 기준 분리
- 함수가 3가지 이상 책임 → 분해
- 같은 패턴 2곳 반복 → 공통 유틸
- Props 5개 초과 → 객체 그룹핑

**상세: `../../shared-references/REFACTORING_PREVENTION.md`**

# Learn - 개발 규칙 자동 학습 스킬

## 목적

버그 수정, 트러블슈팅, 코드 리뷰 과정에서 발견된 교훈을 **개발 규칙 파일에 영구 반영**하여 같은 실수를 반복하지 않게 한다.

## 트리거 조건

### 명시적 트리거
- 사용자가 "기억해", "learn", "규칙 추가", "devrule 업데이트" 등 요청

### 자동 트리거 (감지 시)
- 버그의 근본 원인이 프레임워크/라이브러리 특성에 기인한 **반복 가능한 패턴**일 때
- 같은 유형의 실수가 세션 내에서 2회 이상 발생했을 때
- 트러블슈팅 완료 후 교훈이 프로젝트 전반에 적용 가능할 때

## 실행 절차

### 1. 교훈 분류

| 분류 | 대상 파일 | 예시 |
|------|-----------|------|
| **Common Error** | `devrule/skill.md` Common errors 테이블 | 한 줄로 요약 가능한 에러→원인→해결 |
| **패턴/규칙** | `devrule/skill.md` 본문에 새 섹션 | WebSocket 재연결+상태 동기화 같은 구조적 규칙 |
| **기술 상세** | `devrule/references/WEB_DEV_REFERENCE.md` | API 사용법, 주의사항 |
| **트러블슈팅 상세** | `devrule/references/TROUBLESHOOTING.md` | 디버깅 과정, 재현 조건, 스택트레이스 |

### 2. 중복 확인

devrule skill.md와 references를 읽고 이미 동일한 내용이 있는지 확인한다.
- 있으면: 기존 내용을 보강/수정
- 없으면: 새로 추가

### 3. 업데이트 실행

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

#### References 업데이트 시
해당 references 파일을 읽고 적절한 위치에 추가.

### 4. MEMORY.md 동기화

devrule에 추가한 핵심 내용을 MEMORY.md에도 간략히 기록 (세션 간 빠른 참조용).
단, devrule이 원본(source of truth)이고 MEMORY.md는 요약본.

### 5. 완료 보고

사용자에게 업데이트 내용을 간결히 보고:
```
devrule 업데이트 완료:
- skill.md: [Common errors에 X 추가 / Y 섹션 신규 추가]
- references/TROUBLESHOOTING.md: [Z 항목 추가]
- MEMORY.md: 동기화 완료
```

## 대상 파일 경로

- `/.claude/skills/devrule/skill.md` — 메인 개발 규칙
- `/.claude/skills/devrule/references/WEB_DEV_REFERENCE.md` — 기술 개발 레퍼런스
- `/.claude/skills/devrule/references/TROUBLESHOOTING.md` — 트러블슈팅 상세
- 프로젝트의 MEMORY.md 파일 — 세션 간 메모리

## 주의사항

- devrule skill.md는 500줄 이내로 유지. 초과 시 references로 분리
- 현재 프로젝트에 특화된 교훈만 기록 (일반적인 프레임워크/라이브러리 지식은 제외)
- 코드 예시는 실제 프로젝트 코드 기반으로 작성
- 사용자가 "기억해"라고 했을 때 MEMORY.md만 업데이트하지 말 것 — **반드시 devrule도 업데이트**
