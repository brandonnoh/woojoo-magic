---
description: Result<T,E> 패턴 점진 도입 (throw 제거, 실패 명시)
---

현재 프로젝트의 `throw` 기반 에러 처리를 `Result<T, E>` 패턴으로 점진 전환한다.

절차:

1. **후보 탐색**
   - `throw new` 패턴 사용 함수 목록
   - 상위 호출 빈도 순으로 정렬 (grep 기반 추정)

2. **Result 타입 정의 (없으면 생성)**
   ```ts
   export type Result<T, E> =
     | { ok: true; value: T }
     | { ok: false; error: E };
   export const ok = <T>(value: T): Result<T, never> => ({ ok: true, value });
   export const err = <E>(error: E): Result<never, E> => ({ ok: false, error });
   ```
   - 위치: `src/types/result.ts` (또는 프로젝트 관습)

3. **함수별 전환 계획**
   - 각 후보 함수에 대해: 에러 타입 DU 설계 → 시그니처 변경 → 본문 교체
   - 사용자 승인 후 1~3개씩 적용

4. **호출자 업데이트**
   - `try/catch` → `if (!result.ok) ...`
   - 에러 핸들링 누락 지점 warning 리포트

5. **검증**
   - 빌드 + 테스트 통과 확인
   - 전수 검사: 남은 `throw` 카운트 감소 확인

주의:
- **경계 함수는 throw 허용** (최상위 핸들러, 테스트 도우미 등은 예외)
- 도메인/엔진 계층을 우선 Result 화
