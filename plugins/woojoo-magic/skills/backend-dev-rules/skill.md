---
name: backend-dev-rules
description: >
  Cross-platform app + cloud backend development rules for data model consistency,
  sync logic, serialization, and architecture. Apply when building or reviewing code
  involving: (1) shared data models across platforms (iOS/macOS/Android/Web),
  (2) cloud sync with BaaS (Supabase, Firebase, etc.) or REST/GraphQL APIs,
  (3) widget/extension data sharing via App Groups or shared storage,
  (4) DTO/domain model separation and conversion logic,
  (5) retry/error handling for network operations,
  (6) realtime subscription and event deduplication.
  Triggers: "백엔드 규칙", "backend rules", "sync review", "모델 정합성",
  "데이터 동기화", "크로스플랫폼 모델", "DTO 분리", "위젯 데이터 공유",
  "이중 집계", "Realtime 루프", "CodingKeys 검토", "스키마 변경 체크리스트".
  Also trigger during code review of sync services, cloud models, or shared data layers.
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

# Backend Development Rules

Cross-platform app + cloud backend 프로젝트를 위한 범용 개발 규칙.

## When Applied

- 새 모델/DTO 생성 또는 수정 시
- 동기화 서비스 구현/리뷰 시
- 위젯/Extension 데이터 공유 구현 시
- DB 스키마 변경 시
- PR 리뷰 시 정합성 체크

## Core Rules (Always Apply)

### 1. Single Source of Truth for Models

공유 모델은 반드시 **한 곳에서만 정의**. 플랫폼별 중복 정의 금지.

```
❌ PlatformA/DailyStatsRow.swift + PlatformB/iOSDailyStatsRow.swift
✅ Shared/DTOs/Rows/DailyStatsRow.swift (양쪽 import)
```

플랫폼 고유 로직은 extension으로 확장.

### 2. DTO / Domain Model Separation

```
Shared/Models/     ← 도메인 모델 (앱 내부 로직)
Shared/DTOs/Rows/  ← DB SELECT 결과 (Decodable)
Shared/DTOs/Params/← RPC/POST 파라미터 (Encodable)
Shared/Converters/ ← Row ↔ Model 변환 (단일 구현)
```

### 3. Converter Pattern

변환 로직을 서비스 내부에 인라인 작성 금지. 반드시 Converter에 집중.

```swift
// ❌ 서비스 내부에 private static func mergeDailyStats()
// ✅ CloudDataConverter.rowsToDailyStats() — Shared에 정의
```

### 4. Atomic Storage

관련 데이터를 여러 키에 분산 저장 금지. 단일 구조체로 원자적 저장.

```swift
// ❌ defaults.set(focused, "key1"); defaults.set(sessions, "key2")
// ✅ defaults.set(try encoder.encode(widgetData), "widgetData")
```

### 5. Read/Write Parity

SELECT하는 필드에는 반드시 대응하는 INSERT/UPDATE 존재. SELECT 후 사용하지 않는 필드는 쿼리에서 제거.

## 코드 품질 기준

**상세 기준: `references/HIGH_QUALITY_CODE_STANDARDS.md` 참조** — 범용 코드 품질 기준 (필수)

### 핵심 요약
- 파일 300줄 / 함수 20줄 / 클래스 300줄 — 초과 시 무조건 분할
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드
- 클래스 = 얇은 facade (300줄 이하, 10개 이하 private 필드)
- Silent catch 금지 → 최소 로깅 + 사용자 피드백
- 같은 패턴 2곳 이상 → 공통 유틸 추출
- Discriminated Union, Branded Types, Result<T,E> 패턴 적극 활용

## Detailed References

상세 규칙과 코드 예시는 references 디렉토리 참조:

- **[HIGH_QUALITY_CODE_STANDARDS.md](references/HIGH_QUALITY_CODE_STANDARDS.md)** — 범용 코드 품질 기준 (모든 프로젝트 공통)
- **[models.md](references/models.md)** — 모델 정의, 디렉토리 구조, 죽은 모델 삭제 규칙
- **[serialization.md](references/serialization.md)** — CodingKeys, Optional 통일, Encoder 중앙화
- **[sync.md](references/sync.md)** — 이중 집계 방지, 읽기/쓰기 역할 분리, 재시도, Realtime 루프 방지
- **[storage.md](references/storage.md)** — 원자적 저장, 위젯 공유, 마이그레이션
- **[error-handling.md](references/error-handling.md)** — 3단계 에러 전략, 로깅 통일
- **[checklists.md](references/checklists.md)** — 스키마 변경, PR 리뷰, Anti-Pattern 목록

## Quick Checklist (PR Review)

### Models
- [ ] 새 모델이 Shared에 정의되었는가?
- [ ] CodingKeys가 DB 스키마와 일치하는가?
- [ ] Optional 타입이 DB NULL 허용과 일치하는가?

### Sync
- [ ] 변환 로직이 Converter에 있는가?
- [ ] 재시도 로직이 공유 RetryPolicy를 사용하는가?
- [ ] 이중 집계 방지 공식이 단일 구현인가?

### Storage
- [ ] 위젯 데이터가 단일 키로 원자적 저장되는가?
- [ ] 마이그레이션 코드에 삭제 예정 버전이 명시되었는가?

### Read/Write Parity
- [ ] 새로 SELECT하는 필드에 대응하는 쓰기가 있는가?
- [ ] SELECT한 필드를 실제로 사용하는가?
- [ ] 접근 권한 매트릭스가 업데이트되었는가?
