---
description: 기존 tests.json 기반으로 누락 spec 일괄 생성 + 기존 spec 정합성 검증. 트리거 - spec 생성, spec 보충, spec 검증, specs 만들어줘, spec 없는 것 채워줘
---

# Spec 일괄 생성/검증

tests.json의 features를 순회하여 `specs/{task-id}.md` 파일을 일괄 생성하거나, 기존 spec의 정합성을 검증한다.

## 절차

### 1. tests.json 읽기
- tests.json이 없으면 → `⚠️ tests.json이 없습니다. /wj:init-prd를 먼저 실행하세요.` → 종료
- `features[]` 배열 전체를 읽는다

### 2. 누락 spec 일괄 생성
`features[]` 순회:
- `specs/{task-id}.md` **파일이 없으면** → 아래 템플릿으로 생성
- 생성 시 task의 `acceptance_criteria`, `affected_packages`, `depends_on`, `edge_cases`, `regression_check`, `affected_files`를 반영

### 3. 기존 spec 정합성 검증
`specs/{task-id}.md` **파일이 있으면**:
- tests.json의 `acceptance_criteria`와 spec 내용 대조
- acceptance_criteria에 있는데 spec에 반영 안 된 항목 → `⚠️ {task-id}: acceptance_criteria N건 미반영` → 누락 항목 append
- spec에 "## 설계" 섹션이 비어있으면 → `⚠️ {task-id}: 설계 섹션 비어있음`

### 4. 결과 요약
```
[spec-init] 생성: N개, 검증OK: M개, 업데이트: K개
```

## Spec 템플릿

```markdown
# {task-id}: {title}

## 배경
왜 이 기능이 필요한지, 어떤 문제를 해결하는지.

## Acceptance Criteria
- [ ] {acceptance_criteria[0]}
- [ ] {acceptance_criteria[1]}
- ...

## 설계
- 데이터 흐름 / 상태 변화
- API 엔드포인트 (해당 시)
- 컴포넌트 구조 (UI 해당 시)
- 타입 정의 (새로 추가하거나 수정하는 타입)

## 구현 가이드
- 핵심 로직 설명
- 사용할 패턴 (Result, Branded Types 등)
- 주의사항 / 함정

## 파일 변경 목록
- {affected_files[0]}
- {affected_files[1]}
- ...

## UI/UX (해당 시)
- 와이어프레임 또는 레이아웃 설명
- 인터랙션 흐름
- 반응형 고려사항

## Edge Cases
- {edge_cases[0]}
- {edge_cases[1]}
- ...

## 회귀 체크
- {regression_check[0]}
- {regression_check[1]}
- ...

## 의존성
- depends_on: {depends_on}
- affected_packages: {affected_packages}
```

## Guardrails
- tests.json의 `acceptance_criteria`가 spec에 **전부** 반영되어야 함
- 추측으로 설계 섹션을 채우지 말고, Serena/코드 탐색으로 실제 파일 구조 확인 후 작성
- status가 `passing`인 task의 spec도 검증 대상 (이미 구현됐더라도 문서 정합성은 유지)

---

## ⚡ 즉시 실행

**대기하지 마라. 이 프롬프트를 받는 즉시 위 절차대로 실행하라.**
