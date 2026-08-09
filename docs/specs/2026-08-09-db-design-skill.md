# /wj-magic:db-design — 세계 최고 수준 DB 설계 지능 설계서

## 개요

wj-magic에 **데이터 계층 설계를 책임지는 최상위 스킬**을 신설한다. 특정 스택에 락인하지
않고, 대상 서비스의 워크로드를 분석해 **워크로드마다 최적 DB를 매칭(폴리글랏)**하고,
스키마·인덱스·샤딩·마이그레이션까지 설계한 뒤 Wave 전략으로 실제 코드까지 생성한다.

두 mode를 지원한다:
- **NEW** — 요구사항/기획서에서 0→1 신규 데이터 계층 설계
- **DIAGNOSE** — 기존 스키마·쿼리를 감사하고 최적화 (cto-review의 DB 특화판)

## 근거

- 입력 자료 "10 Types of Databases" 카루셀 — 관계형·문서·키-값·와이드컬럼·그래프·
  시계열·검색·벡터·인메모리·데이터웨어하우스 10종의 트레이드오프·유스케이스 매칭.
- 바이브코딩 MVP는 "일단 PostgreSQL 하나"로 시작하지만, 사용자·데이터가 늘면 캐시·검색·
  벡터·시계열이 필요해진다. **DB 유형 선택 실수는 나중에 가장 비싼 재작업**을 만든다.
- 기존 스킬 공백: cto-review는 코드 구조를, audit은 보안을 본다. **데이터 모델의 정합성·
  성능·확장성을 책임지는 전문 스킬이 없다.**

## 전제 조건

- 기존 패턴 재사용: cto-review(Wave 전략·처방 카탈로그), audit(2-pass 검증), devrule(규모별 실행).
- 구현(스키마 파일 작성)은 **기존 backend-dev/engine-dev를 Wave로 재사용** — 중복 에이전트 신설 금지.
- 품질 기준: `references/common/HIGH_QUALITY_CODE_STANDARDS.md` 준거.
- 스킬/에이전트는 디렉터리 규칙으로 자동 등록 (manifest 열거 불필요). 릴리스 시 버전·설명 갱신.

## 아키텍처

```
/wj-magic:db-design [자연어 요청]
   │
   ├─ Phase 0  컨텍스트 로드 + mode 판별
   │           · 기존 스키마/ORM 모델 존재? → DIAGNOSE, 없으면 → NEW
   │           · SKILL_PREAMBLE + 관련 레퍼런스 로드
   │
   ├─ [NEW mode] ─────────────────────────────────────────────
   │   Phase 1  워크로드 특성화 (Workload Characterization)
   │            엔티티·관계 / 접근 패턴(쿼리 shape) / 읽기:쓰기 비율 /
   │            일관성 SLA / 지연 예산 / 데이터 규모·성장률 / 카디널리티
   │   Phase 2  폴리글랏 매칭 (db-architect 에이전트)
   │            워크로드를 쪼개 각각 최적 DB 유형 매칭 → 트레이드오프 스코어링 →
   │            운영 복잡도 vs 성능 저울질 → 최소 조합 권고 (CAP/PACELC 근거)
   │   Phase 3  스키마 설계
   │            ERD / 정규화·비정규화(근거 명시) / 인덱스(쿼리 shape 기반) /
   │            파티션·샤드 키 / 트랜잭션 경계 / PII·암호화·RLS
   │   Phase 4  Wave 구현 (backend-dev/engine-dev)
   │            DDL / ORM 스키마(Prisma·Drizzle) / migration 파일 / seed
   │
   ├─ [DIAGNOSE mode] ────────────────────────────────────────
   │   Phase 1  스키마·쿼리 스캔 (Serena 심볼 추적)
   │   Phase 2  결함 진단 (schema-quality-checklist 루브릭)
   │            N+1 / 인덱스 누락 / 과·미정규화 / 무한 증가 / FK 누락 /
   │            타입 부정확 / 핫 파티션 / 풀스캔 / 락 경합
   │   Phase 3  처방 — 우선순위별 개선안 + 마이그레이션 안전성 등급
   │   Phase 4  Wave 수정 — expand-contract 무중단 마이그레이션 자동 적용
   │
   └─ Phase 5  검증 게이트 (2-pass)
               db-architect 셀프리뷰 → 스키마 정합성·인덱스 커버리지·
               마이그레이션 안전성 재확인 → 설계 리포트 저장
```

**폴리글랏이 핵심**: Phase 2는 "PostgreSQL 하나"가 아니라 — 핵심 트랜잭션=PG,
세션/캐시=Redis, 상품검색=Elasticsearch, 추천/시맨틱=벡터DB 처럼 워크로드를 쪼개
각각 최적 매칭한다. 단, **운영 복잡도**를 비용으로 계상해 불필요한 다중화는 배제한다(YAGNI).

## 생성할 파일 목록

### 1. 스킬: `skills/db-design/SKILL.md`
- frontmatter(name·description·트리거 키워드) + 2-mode 파이프라인 + Phase별 지시.
- 서두에 `references/common/SKILL_PREAMBLE.md` Read 강제.

### 2. 에이전트: `agents/db-architect.md`
- DB 설계·진단 전문가. model: opus.
- MCP 강제(Sequential-thinking·Serena·Context7).
- 폴리글랏 선택 + 스키마/인덱스/샤딩 설계 + DDL 산출. 코드 직접 수정은 Wave 위임.

### 3. 스킬 레퍼런스: `skills/db-design/references/`
| 문서 | 내용 |
|------|------|
| `db-selection-guide.md` | 폴리글랏 결정 트리 · 10종 유형별 트레이드오프·유스케이스 · CAP/PACELC · 일관성 모델 · 조합 패턴 |
| `relational-modeling.md` | 정규화 1NF~BCNF · 의도적 비정규화 · 인덱스(B-tree/Hash/GIN/GiST/BRIN) · 제약 · 트랜잭션 격리수준 · 파티셔닝 |
| `nosql-modeling.md` | 문서(embed vs reference·집계 경계) · 와이드컬럼(파티션/클러스터링 키·핫스팟) · 키-값 접근 패턴 · 인메모리 |
| `specialized-stores.md` | 벡터(차원·ANN 인덱스 HNSW/IVF·RAG 스키마) · 검색(매핑·애널라이저·역색인) · 시계열(리텐션·다운샘플·연속집계) · 그래프(프로퍼티 그래프·순회) · 데이터웨어하우스(스타/스노우플레이크 스키마·컬럼스토어) |
| `scaling-migration.md` | 수평/수직 샤딩 · 파티셔닝 · 읽기 복제본 · CDC · 무중단 마이그레이션(expand-contract·dual-write·backfill·cutover) · 용량 산정 |
| `schema-quality-checklist.md` | DIAGNOSE 진단 루브릭 — 안티패턴 카탈로그(심각도·탐지법·수정법) |

### 4. 릴리스 반영
- plugin.json 설명·버전, marketplace.json 버전, CHANGELOG.md (release 스킬로 일괄).

## 세계 최고 수준을 위한 핵심 원칙 (레퍼런스·에이전트에 관통)

1. **증거 기반** — 접근 패턴(쿼리 shape)에서 인덱스를 역산. "일단 걸어두는 인덱스" 금지.
   EXPLAIN/실행계획으로 검증 지향.
2. **트레이드오프 명시** — 모든 선택(정규화 수준, DB 조합, 샤드 키)에 근거와 포기한 대안 기록.
3. **운영 복잡도 계상** — 폴리글랏은 성능뿐 아니라 운영 비용(백업·모니터링·정합성)까지 저울질.
4. **무중단 원칙** — 마이그레이션은 항상 expand-contract 4단계. 파괴적 변경 자동 차단.
5. **성장 대비** — 현재 규모 + 10배 시나리오 동시 검토(카디널리티·핫 파티션·무한 증가).
6. **보안 내장** — PII 식별·암호화·RLS·최소권한을 스키마 설계 단계에서 결정.

## 통합

- 흐름: `venture/brainstorm(기획) → db-design(데이터 계층) → devrule(전체 구현)`.
- 신규 command 없음 — 스킬(`/wj-magic:db-design`)로 충분.
- 트리거: "DB 설계", "스키마 설계", "데이터베이스 뭐 써야", "인덱스 최적화", "샤딩",
  "정규화", "마이그레이션", "DB 최적화", "폴리글랏", "ERD", "데이터 모델링".

## 검증 기준

- SKILL.md/에이전트 frontmatter 유효, 트리거 키워드 중복 없음.
- 레퍼런스 6종 모두 10 DB 유형을 커버하고 상호 링크.
- 기존 스킬(cto-review/audit) 컨벤션과 일관.
- `bats tests/` 회귀 통과 (기존 테스트 깨지지 않음).
```
```
