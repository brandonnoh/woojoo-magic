# PRD — {프로젝트 이름}

> Ralph v2가 읽는 task 목록. `- [ ]` 미완료 / `- [x]` 완료.
> 세부 acceptance criteria는 `tests.json` 참고.

## 개요
- 비전:
- 타겟 사용자:
- 핵심 가치:

## Phase 1 — 기반
- [ ] infra-001 모노레포 + 빌드 파이프라인 세팅
- [ ] infra-002 타입 시스템 + lint 설정
- [ ] infra-003 테스트 러너 연결

## Phase 2 — 코어
- [ ] core-001 도메인 모델 정의
- [ ] core-002 핵심 유즈케이스 구현

## Phase 3 — UI/UX
- [ ] ui-001 기본 레이아웃

## Phase 4 — 통합
- [ ] int-001 E2E 시나리오

## 참고
- 구현 전 반드시 `tests.json`의 `depends_on` 확인
- `affected_packages`에 누락된 소비자 패키지가 없는지 Cross-Package 분석
