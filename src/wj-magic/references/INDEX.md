# References Index — 언어 감지 → 레퍼런스 라우터

이 문서를 먼저 읽고, 프로젝트 언어에 해당하는 레퍼런스만 로드한다.

---

## 언어 감지 매트릭스

| 감지 파일 | 언어 | Lock 파일 | 패키지 매니저 |
|----------|------|----------|-------------|
| `tsconfig.json`, `tsconfig.*.json` | TypeScript | `pnpm-lock.yaml` / `yarn.lock` / `package-lock.json` | pnpm / yarn / npm |
| `package.json` (tsconfig 없이) | JavaScript | 동일 | 동일 |
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python | `poetry.lock` / `uv.lock` / `Pipfile.lock` | poetry / uv / pip |
| `go.mod` | Go | `go.sum` | go mod |
| `Cargo.toml` | Rust | `Cargo.lock` | cargo |
| `Package.swift`, `*.xcodeproj` | Swift | `Package.resolved` | SPM / CocoaPods |
| `build.gradle.kts`, `build.gradle` (kotlin) | Kotlin | `gradle.lockfile` | gradle |

> 복수 언어 프로젝트: 각 언어의 레퍼런스를 모두 로드. 파일 확장자 기준으로 규칙 적용.

---

## 필수 로드 (모든 언어)

| 파일 | 내용 |
|------|------|
| `common/HIGH_QUALITY_CODE_STANDARDS.md` | 공통 품질 원칙 (SRP, 타입 안전, 불변성, DRY, 복잡도) |
| `common/REFACTORING_PREVENTION.md` | 리팩토링 방지 시그널 |

## 디자인 레퍼런스 (UI 작업 시 로드)

프론트엔드/UI 관련 작업 시 아래 디자인 레퍼런스를 로드한다.

| 파일 | 내용 | 로드 시점 |
|------|------|----------|
| `design/DESIGN_QUALITY_STANDARDS.md` | 디자인 품질 공통 원칙, Hard Limits, 체크리스트 | **UI 작업 시 필수** |
| `design/ANTI_SLOP_PATTERNS.md` | AI 제네릭 패턴 목록 + 탐지 규칙 + 대안 | **UI 작업 시 필수** |
| `design/TYPOGRAPHY_SYSTEM.md` | 타이포 스케일, 위계, 가독성 규칙 | 텍스트/레이아웃 작업 시 |
| `design/COLOR_SYSTEM.md` | 컬러 구조, 접근성, 도메인별 가이드 | 색상/테마 작업 시 |
| `design/SPACING_RHYTHM.md` | 8px 그리드, 시각적 리듬, 컴포넌트별 가이드 | 레이아웃 작업 시 |
| `design/LAYOUT_PATTERNS.md` | 레이아웃 패턴, 반응형 전략, 컨테이너 | 페이지/컴포넌트 설계 시 |
| `design/MOTION_PRINCIPLES.md` | 애니메이션 원칙, easing, 지속 시간, 성능 | 인터랙션/전환 작업 시 |

**Hard limits**: 색상 대비 ≥ 4.5:1 / 동시 색상 ≤ 5개 / 클릭 영역 ≥ 44px / 폰트 ≤ 2패밀리 / 애니메이션 150~500ms

---

## 언어별 로드 맵

### TypeScript / JavaScript

| 파일 | 내용 | 로드 시점 |
|------|------|----------|
| `typescript/standards.md` | Hard limits, 타입 시스템, React, Zustand, 성능 | **필수** |
| `typescript/BRANDED_TYPES_PATTERN.md` | `string & { __brand }` 패턴 | 도메인 식별자 작업 시 |
| `typescript/RESULT_PATTERN.md` | `Result<T, E>` 에러 처리 | 에러 핸들링 작업 시 |
| `typescript/DISCRIMINATED_UNION.md` | `{ kind: 'x' }` 상태 모델링 | 상태/페이즈 설계 시 |
| `typescript/NON_NULL_ELIMINATION.md` | `!` 제거 패턴 | 기존 코드 수정 시 |
| `typescript/LIBRARY_TYPE_HARDENING.md` | 외부 라이브러리 타입 강화 | 라이브러리 통합 시 |
| `typescript/ZUSTAND_SLICE_PATTERN.md` | Zustand 슬라이스 분리 | 스토어 작업 시 |

**Hard limits**: 파일 300줄 / 함수 20줄 / `any` 금지 / `!` 금지

### Python

| 파일 | 내용 | 로드 시점 |
|------|------|----------|
| `python/standards.md` | Ruff + Pyright strict, EAFP, NewType, frozen dataclass | **필수** |

**Hard limits**: 파일 600줄 / 함수 50줄 / CC ≤ 10 / `Any` 금지 / bare except 금지

### Go

| 파일 | 내용 | 로드 시점 |
|------|------|----------|
| `go/standards.md` | error handling, interface 설계, goroutine, 테스트 | **필수** |

**Hard limits**: 파일 500줄 / 함수 40줄 / CC ≤ 10 / `interface{}` 금지 / `_ = err` 금지

### Rust

| 파일 | 내용 | 로드 시점 |
|------|------|----------|
| `rust/standards.md` | ownership, Result/Option, trait, unsafe, clippy | **필수** |

**Hard limits**: 파일 500줄 / 함수 40줄 / `unwrap()` 금지 / `unsafe` 최소화 / `clone()` 남용 금지

### Swift

| 파일 | 내용 | 로드 시점 |
|------|------|----------|
| `swift/standards.md` | Optional, protocol, actor, SwiftUI, 테스트 | **필수** |

**Hard limits**: 파일 400줄 / 함수 30줄 / force unwrap `!` 금지 / `Any` 금지 / implicitly unwrapped 금지

### Kotlin

| 파일 | 내용 | 로드 시점 |
|------|------|----------|
| `kotlin/standards.md` | null safety, coroutine, sealed class, Compose, 테스트 | **필수** |

**Hard limits**: 파일 400줄 / 함수 30줄 / `!!` 금지 / `Any` 금지 / `var` 최소화

---

## 빌드/검증 명령 매핑

| 언어 | 빌드 | 테스트 | 린트 | 타입체크 |
|------|------|--------|------|---------|
| TS (pnpm) | `pnpm build` | `pnpm test` | `pnpm lint` | `pnpm tsc --noEmit` |
| TS (turbo) | `pnpm turbo build` | `pnpm turbo test` | `pnpm turbo lint` | `pnpm turbo typecheck` |
| Python | — | `pytest --cov` | `ruff check .` | `pyright --strict` |
| Go | `go build ./...` | `go test ./...` | `golangci-lint run` | (컴파일러) |
| Rust | `cargo build` | `cargo test` | `cargo clippy -- -D warnings` | (컴파일러) |
| Swift | `swift build` | `swift test` | `swiftlint` | (컴파일러) |
| Kotlin | `./gradlew build` | `./gradlew test` | `./gradlew detekt` | (컴파일러) |

---

## 훅 연동

| 훅 | 지원 언어 | 검사 항목 |
|----|----------|----------|
| `gate-l1.sh` (L1 정적 감사) | TS/JS, Python, Go, Rust, Swift, Kotlin | 줄 수, 금지 패턴, silent error |
| `quality-check.sh` (PostToolUse) | 동일 | 실시간 경고 + 레퍼런스 포인터 |
| `gate-l2.sh` (L2 타입체크) | TS (`tsc`), Python (`pyright`), Go/Rust/Swift/Kotlin (컴파일) | 타입 에러 |
