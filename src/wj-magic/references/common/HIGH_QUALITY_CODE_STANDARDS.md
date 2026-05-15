# High-Quality Code Standards (v3)

## 용도
- 모든 wj-magic 스킬/에이전트가 참조하는 **최상위 품질 기준**
- 코드 작성 전, 리뷰 전, PR 제출 전 체크
- "리팩토링이 필요 없도록 처음부터 고품질로" — 실리콘밸리 수준

---

## 언어별 상세 규칙

프로젝트 언어에 따라 아래 문서를 반드시 함께 참조:

| 언어 | 문서 | 핵심 |
|------|------|------|
| TypeScript / JavaScript | [`standards/typescript.md`](./standards/typescript.md) | 파일 300줄 / 함수 20줄 (hard), Branded Types, Result<T,E>, DU, `any`/`!` 금지 |
| Python | [`standards/python.md`](./standards/python.md) | Cyclomatic Complexity ≤ 10, NewType, frozen dataclass + match, EAFP, Ruff + Pyright strict |

> **언어가 섞인 프로젝트**는 두 문서를 모두 적용. 언어별 파일에만 해당 규칙 강제.
> **다른 언어(Rust/Go/Swift 등)**는 공통 원칙을 준수하되 언어 관용구를 존중.

---

## 공통 원칙 (언어 불문)

모든 언어에 적용되는 **불변 원칙**. 언어별 문서는 이 원칙을 각 언어 관용구로 번역한 것.

### 1. 단일 책임 (SRP)
- 파일/함수/클래스/모듈은 **한 가지 일**만 한다
- 여러 책임이 섞이면 즉시 분할
- God class, God module, God function 금지

### 2. 타입 안전성 최대화
- 정적 타입 체커를 **가장 엄격한 모드**로 (`strict: true` / `--strict`)
- 도메인 식별자는 구조적으로 구분 (Branded Types / NewType)
- 상태는 Discriminated Union / ADT로 모델링
- 경계(외부 I/O)에서만 검증 후 내부 도메인 타입으로 승격
- `any` / `Any` / `unknown`으로 도피하지 않는다

### 3. 불변성 기본
- 기본값은 불변. 가변은 명시적 선택
- 불변 업데이트 패턴 사용 (spread / `replace` / `dataclasses.replace`)
- 전역 가변 상태 금지

### 4. 순수성 & 레이어 분리
- 도메인 로직 = 순수 함수. I/O 없음
- I/O는 경계 레이어(infrastructure)로 밀어낸다
- 의존성 방향: `domain ← application ← infrastructure/interface`

### 5. Silent Failure 금지
- 에러를 삼키지 않는다 (`!` / `except: pass` / `catch {}` 모두 금지)
- 예외 체인 보존 (`raise ... from e`)
- 최소 로깅 + 사용자 피드백

### 6. 복잡도 제어
- **Cyclomatic Complexity ≤ 10** (산업 표준)
- 4단 이상 중첩 금지 → 가드 클로즈 + 함수 분리
- 매개변수 많으면 config 객체로 묶기

### 7. DRY
- 같은 패턴 2곳 → 공통 유틸 추출
- 같은 패턴 3곳 → 반드시 추출 (리뷰 거부 사유)
- 매직 값(넘버/문자열) → 상수화

### 8. 테스트 우선
- 새 로직 = 새 테스트
- 커버리지 80%+
- 순수 함수는 단위 테스트, I/O는 경계 테스트

### 9. 검증 전 완료 주장 금지
- "됐다"고 말하기 전에 반드시 빌드/테스트/린트/타입체크 실행
- 증거 없는 성공 주장 금지

---

## 리팩토링 방지 시그널 (공통)

"이미 늦었다"는 신호를 **코드 작성 중에** 감지하고 즉시 대응:

| 시그널 | 대응 |
|--------|------|
| 파일이 soft limit 2/3 돌파 | 즉시 분리 계획 수립 |
| 함수가 3가지 책임을 가짐 | SRP 위반 — 분할 |
| 같은 로직 2곳 등장 | 즉시 유틸 추출 |
| 매개변수 5개 초과 | 객체 그룹핑 |
| 타입 회피(`any`/`Any`/`cast`) 등장 | 타입 설계 재고 |
| 중첩 4단 이상 | 가드 클로즈 + 함수 분리 |
| 복잡도 > 10 | 즉시 분할 |

→ `./REFACTORING_PREVENTION.md` 참조

---

## 공통 코드 리뷰 체크리스트

**언어 무관** 체크 항목. 언어별 추가 항목은 각 standards 문서 참조.

### 구조
- [ ] 단일 책임 준수 (파일/함수/클래스)
- [ ] Cyclomatic Complexity ≤ 10
- [ ] 레이어 분리 (domain은 I/O 없음)
- [ ] 매개변수 묶음 (5개 초과 시 객체)

### 타입 안전성
- [ ] strict 모드 통과
- [ ] 타입 회피 0개
- [ ] 도메인 식별자 타입 분리

### 에러 처리
- [ ] Silent failure 0개
- [ ] 예외/에러 체인 보존
- [ ] 경계에서만 catch

### 중복/매직
- [ ] 중복 코드 없음
- [ ] 매직 값 → 상수

### 불변성
- [ ] 전역 가변 상태 없음
- [ ] 불변 업데이트 사용

### 테스트/빌드
- [ ] 새 로직 → 테스트 추가
- [ ] 빌드/린트/타입체크/테스트 모두 통과
- [ ] 커버리지 80%+

---

## 관련 참조 문서

- `./standards/typescript.md` — TS/JS 전용 규칙
- `./standards/python.md` — Python 전용 규칙
- `./BRANDED_TYPES_PATTERN.md` — Branded Types 실전 (TS)
- `./RESULT_PATTERN.md` — Result<T,E> (TS)
- `./DISCRIMINATED_UNION.md` — DU + wrapSetWithPhase (TS)
- `./NON_NULL_ELIMINATION.md` — `!` 제거 패턴 (TS)
- `./LIBRARY_TYPE_HARDENING.md` — 외부 라이브러리 타입 강화
- `./ZUSTAND_SLICE_PATTERN.md` — Zustand 슬라이스 (TS)
- `./REFACTORING_PREVENTION.md` — 리팩토링 방지 시그널
