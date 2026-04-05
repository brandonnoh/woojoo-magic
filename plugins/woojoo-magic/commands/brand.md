---
description: Branded Types 점진 마이그레이션 (도메인 식별자 타입 안전화)
---

현재 프로젝트에서 `string` / `number`로 표현된 도메인 식별자를 Branded Types로 점진 교체한다.

절차:

1. **후보 탐색**
   - 네이밍 기반: `*Id`, `*Email`, `*Amount`, `*Token`, `*Hash` 등
   - 함수 파라미터/반환 타입, 필드 타입에서 `string|number` 사용 지점 수집
   - 상위 후보 10~20개 제안 (빈도순)

2. **사용자 승인**
   - 각 후보에 대해 제안 Brand 이름 (예: `PlayerId`, `ChipAmount`) 제시
   - 사용자가 선택한 것만 진행

3. **타입 생성**
   - `src/types/brand.ts` (또는 프로젝트 관습) 에 공통 `Brand<T, B>` 유틸 정의
   - 선택된 Brand 타입 + 스마트 생성자 (`createPlayerId`) + 검증 로직 생성

4. **호출부 업데이트**
   - `string` → `PlayerId` 로 타입 교체
   - 생성 지점에 `createPlayerId(...)` 삽입
   - 빌드 에러 발생 지점 순차 수정

5. **검증**
   - `pnpm turbo build && pnpm turbo test` (또는 프로젝트 빌드/테스트)

주의:
- 한 번에 전부 바꾸지 말고 **한 Brand 씩** 적용
- 외부 I/O 경계(JSON 파싱, DB, API)에서만 스마트 생성자 호출, 내부는 Brand로 흘려보냄
