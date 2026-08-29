---
name: db-design
description: >
  데이터 계층 설계를 책임지는 최상위 스킬. 특정 스택에 락인하지 않고 대상
  서비스의 워크로드를 분석해 워크로드마다 최적 DB를 매칭(폴리글랏)하고,
  스키마·인덱스·정규화/비정규화·샤딩·무중단 마이그레이션까지 설계한 뒤
  Wave 전략으로 DDL·ORM 스키마·migration 실제 코드까지 생성한다.
  관계형/문서/키-값/와이드컬럼/그래프/시계열/검색/벡터/인메모리/데이터웨어하우스
  10종을 트레이드오프 기반으로 선택한다. 신규 설계(NEW)와 기존 진단(DIAGNOSE)
  두 mode를 지원한다. "DB 설계", "스키마 설계", "데이터베이스 뭐 써야",
  "인덱스 최적화", "샤딩", "정규화", "비정규화", "마이그레이션", "DB 최적화",
  "폴리글랏", "ERD", "데이터 모델링", "어떤 DB", "테이블 설계" 요청에 트리거.
---

**품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)

# DB Design — 폴리글랏 데이터 계층 설계 지능

대상 서비스의 워크로드를 분석해 **최적의 데이터 계층 구조**를 찾아 설계하고,
실제 스키마·마이그레이션 코드까지 생성하는 스킬. 디폴트 DB를 미리 깔지 않고
워크로드마다 진짜 최적인 DB를 매칭한다 — 서비스에 따라 처음부터 폴리글랏이
최적이면 그렇게 권고하고, 하나로 충분하면 하나로 간다. 유행도 관성도 아닌 **적합성**이 기준.

## When to use this skill

- 새 서비스/기능의 데이터 계층을 처음 설계할 때 (어떤 DB? 어떤 스키마?)
- 기존 스키마·쿼리를 진단하고 최적화할 때 (인덱스 누락·N+1·과정규화)
- "사용자 10배면 터질" 데이터 병목을 미리 진단·재설계할 때
- 폴리글랏(다중 DB) 도입 여부와 정합성 전략을 결정할 때
- 무중단 스키마 마이그레이션을 계획할 때
- "DB 설계", "스키마 설계", "어떤 DB 써야", "인덱스", "샤딩", "정규화",
  "마이그레이션", "데이터 모델링", "폴리글랏" 등 키워드

**경계**: 코드 구조 전반 = cto-review, 보안 취약점 = audit, UI = design.
이 스킬은 **데이터 모델의 정합성·성능·확장성**만 책임진다.

## 핵심 철학

1. **워크로드 최적 우선 (디폴트 DB 없음)** — 워크로드를 쪼개 각각에 진짜 최적인 DB를 매칭한다.
   두 실패를 동시에 경계: ① 조기 폴리글랏(추측성 다중화) ② PG-도그마(억지로 하나에 밀어넣기).
   DB 추가의 운영 비용을 성능·적합성 이득과 저울질해, 이득이 크면 처음부터 폴리글랏도 권고한다.
2. **증거 기반 설계** — 접근 패턴(쿼리 shape)에서 인덱스·샤드 키를 역산한다. 추측 금지.
3. **트레이드오프 명시** — 모든 선택에 근거와 포기한 대안을 기록한다.
4. **무중단 원칙** — 마이그레이션은 항상 expand-contract 4단계. 파괴적 변경 차단.
5. **성장 대비** — 현재 규모 + 10배 시나리오를 동시에 검토한다.

## 두 개의 mode

Phase 0에서 자동 판별한다. 기존 스키마/ORM 모델(schema.prisma, migrations/, models/,
CREATE TABLE 등)이 있으면 **DIAGNOSE**, 없으면 **NEW**. 애매하면 사용자에게 확인한다.

---

## NEW mode — 0→1 신규 데이터 계층 설계

### Phase 0 — 컨텍스트 로드
- `SKILL_PREAMBLE.md` + `references/db-selection-guide.md` Read.
- 기획서/요구사항(prd.md, docs/) 존재 시 로드. 없으면 사용자에게 서비스 개요 질문.

### Phase 1 — 워크로드 특성화
db-architect 에이전트를 투입해 다음을 정량화(불명확하면 사용자에게 질문):
엔티티·카디널리티 / 접근 패턴(쿼리 shape) / 읽기:쓰기 비율 / 일관성 SLA /
지연 예산(p99) / 규모·성장률 / PII·규제. → 워크로드 프로파일 산출.

### Phase 2 — 폴리글랏 매칭 (db-architect)
워크로드를 쪼개 각 조각에 최적 DB 유형 매칭. `db-selection-guide.md`의 결정 트리 +
CAP/PACELC 근거. 운영 복잡도 vs 성능을 저울질해 **최소 조합 + 확장 경로** 권고.
진실의 원천(SoT)과 파생 저장소 전파(CDC·이벤트·캐시 무효화) 방식 명시.

### Phase 3 — 스키마 설계 (db-architect)
선택된 DB별로 설계. 관련 레퍼런스 로드(relational/nosql/specialized).
ERD → 정규화·비정규화(근거) → 인덱스(쿼리 shape 역산) → 파티션/샤드 키 →
트랜잭션 경계 → PII·암호화·RLS. → **설계 리포트 저장** (`docs/db/DB_DESIGN.md`).

### Phase 4 — Wave 구현
설계를 파일 단위 task로 분해해 backend-dev/engine-dev를 Wave로 투입:
DDL / ORM 스키마(Prisma·Drizzle) / migration / seed. 충돌 제로 Wave(도메인별 격리).
Context7로 DDL·마이그레이션 API 문법 확인.

---

## DIAGNOSE mode — 기존 스키마 진단·최적화

### Phase 1 — 스키마·쿼리 스캔 (db-architect + Serena)
Serena로 모델/엔티티/쿼리 심볼 추적. `find_referencing_symbols`로 테이블별 쿼리 수집.
ORM 쿼리·raw SQL·인덱스 정의 패턴 검색. 실제 스키마 파일 로드.

### Phase 2 — 결함 진단
`references/schema-quality-checklist.md` 안티패턴 카탈로그로 스캔:
N+1 / 인덱스 누락 / 과·미정규화 / FK 누락 / 부정확한 타입 / 무한 증가 /
핫 파티션 / 락 경합 / SELECT * / 인덱스 없는 정렬·조인.

### Phase 3 — 처방
각 결함에 심각도·근거·수정법·마이그레이션 안전성 등급 부여. 우선순위 정렬.
→ 진단 리포트 저장 (`docs/db/DB_DIAGNOSIS.md`).

### Phase 4 — Wave 수정 (사용자 승인 후)
expand-contract 무중단 마이그레이션으로 자동 적용. 파괴적 변경은 4단계 분할.
Wave 1=CRITICAL(즉시), Wave 2=HIGH, Wave 3=MEDIUM 순.

---

## Phase 5 — 검증 게이트 (양 mode 공통)

db-architect 셀프리뷰: 스키마 정합성 / 인덱스가 모든 빈번 쿼리를 커버하는가 /
마이그레이션이 무중단인가 / 타입 정확성 / 성장 10배 시나리오 견디는가.
구현 후 `bats tests/` 또는 프로젝트 테스트로 회귀 확인.

## Phase 6 — 8-bit 시각 리포트 (필수 마무리, 양 mode 공통)

`../../references/common/REPORT_8BIT.md` 가이드대로
`docs/reports/db-design-{주제}-8bit.html`을 생성하고 `open`으로 브라우저에 띄운다.
STAGE 구성 예: 워크로드 → DB 매칭 컨베이어(폴리글랏 흐름) → ERD 카드 그리드 →
인덱스 커버리지 HUD 테이블 → 마이그레이션 4단계 게이트(expand-contract) →
10배 성장 씬 → 코드 맵. 트레이드오프(선택 근거 + 포기한 대안)를 반드시 담는다.

## 산출물

- `docs/db/DB_DESIGN.md` (NEW) 또는 `docs/db/DB_DIAGNOSIS.md` (DIAGNOSE) — 설계/진단 리포트
- `docs/reports/db-design-{주제}-8bit.html` — 8-bit 시각 리포트 (필수, 로컬 브라우저 오픈)
- 실제 스키마·마이그레이션 코드 (Wave 구현 시)
- devrule 호환 작업 리스트 (대규모 구현 시 `/wj-magic:loop plan` 연계)

## 통합 흐름

`venture/brainstorm(기획) → db-design(데이터 계층) → devrule(전체 구현)`

## 레퍼런스

| 문서 | 로드 시점 |
|------|----------|
| `references/db-selection-guide.md` | 항상 (유형 선택) |
| `references/relational-modeling.md` | 관계형 설계 시 |
| `references/nosql-modeling.md` | 문서/키-값/와이드컬럼 설계 시 |
| `references/specialized-stores.md` | 벡터·검색·시계열·그래프·DW 설계 시 |
| `references/scaling-migration.md` | 샤딩·마이그레이션 계획 시 |
| `references/schema-quality-checklist.md` | DIAGNOSE mode 진단 시 |
