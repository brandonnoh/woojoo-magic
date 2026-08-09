# 관계형 DB 모델링 처방 (PostgreSQL 중심)

> 정규화로 시작해 **측정된** 병목에만 비정규화한다. 무결성은 앱이 아니라 DB에서 강제한다. 인덱스는 쿼리 shape에서 역산한다. 기준: PostgreSQL 16/17 (2025~2026).

## 1. 정규화 1NF~BCNF — 어디까지 갈 것인가

| 정규형 | 조건 | 위반 시 나타나는 이상(anomaly) |
|---|---|---|
| **1NF** | 원자값, 반복그룹 금지, 행 순서 무의미 | `tags='a,b,c'` CSV 컬럼, `phone1/phone2/phone3` |
| **2NF** | 1NF + 부분 함수종속 제거 (복합 PK 일부에만 종속되는 컬럼 없음) | `(order_id, product_id)` PK인데 `product_name`이 `product_id`에만 종속 |
| **3NF** | 2NF + 이행 종속 제거 (비키 → 비키 종속 없음) | `zipcode`로 `city`가 결정됨 (`emp → dept → dept_location`) |
| **BCNF** | 3NF + 모든 결정자가 후보키 | 후보키가 겹치는 다중 결정자 (강사 1명=1과목 규칙 등) |

**세 가지 이상**을 구체적으로: `orders` 테이블에 고객 주소를 중복 저장하면 — **갱신 이상**(고객이 이사하면 N개 주문 행 전부 수정, 하나라도 누락 시 불일치), **삽입 이상**(주문 없는 고객은 주소 저장 불가), **삭제 이상**(마지막 주문 삭제 시 고객 정보 소실).

**처방**: **디폴트는 3NF까지.** 3NF는 이론적 이상을 거의 다 제거하면서 조인 비용이 실무적으로 감당 가능하다. **BCNF는 3NF로 못 잡는 잔여 이상이 실제로 데이터를 오염시킬 때만** 간다 — 후보키가 여러 개 겹치고 그 사이에 종속이 존재하는 드문 경우(예약 스케줄, 강사-과목-시간대). BCNF 분해는 종종 조인이 하나 늘고 일부 FD 강제가 어려워지므로, 이상이 관측되지 않으면 3NF에 멈춘다. **4NF/5NF**(다치 종속/조인 종속)는 다대다-다대다 교차에서만 실전 의미가 있고 대부분 오버엔지니어링이다.

## 2. 의도적 비정규화 — 최적화이지 디폴트가 아니다

**전제**: 3NF 스키마를 먼저 만들고, `EXPLAIN ANALYZE`로 **측정된 읽기 병목**이 있을 때만 비정규화한다. "조인이 많아 보여서"는 근거가 아니다 — PostgreSQL은 인덱스된 조인을 매우 잘한다.

| 기법 | 용도 | 갱신 이상 관리 |
|---|---|---|
| **카운터 캐시** (`post.comment_count`) | COUNT(*) 실시간 집계 회피 (500M 엣지) | **트리거**로 원자 증감 or 배치 재계산 크론 |
| **집계 컬럼** (`invoice.total`) | 라인아이템 SUM 반복 회피 | 라인 변경 트리거 or 앱 레이어 재계산 |
| **중복 컬럼** (`order.customer_name` 스냅샷) | 조인 제거 + **역사적 정확성**(주문 시점 값 동결) | 스냅샷은 의도된 것 — 절대 소스와 동기화하지 않음 |
| **역정규 조회 컬럼** (`comment.author_name`) | 피드 하이드레이션 조인 감소 | 트리거 or CDC 이벤트 |
| **materialized view** | 무거운 리포팅 집계 | `REFRESH MATERIALIZED VIEW CONCURRENTLY` (스케줄) |

**동기화 전략 선택**:
- **트리거**(DB 내부): 강한 일관성, 앱 우회 INSERT에도 안전. 단 쓰기 경합 시 hot row 병목 — 고빈도 카운터는 트리거보다 배치가 낫다.
- **애플리케이션**: 유연하지만 모든 쓰기 경로가 지켜야 하고 우회 시 drift. 결제 like 크리티컬엔 부적합.
- **배치 재계산**: 최종 일관성 허용 시 최선. `comment_count`는 5분 지연 OK → 크론으로 SELECT COUNT → UPDATE. drift 자가치유.

**철칙**: 비정규화 컬럼은 **진실의 원천이 아니다**. 원천 테이블은 정규화 상태로 남기고, 비정규 값은 언제든 재구축 가능한 캐시로 취급한다. 스냅샷(역사값)과 캐시(파생값)를 코드/주석으로 명확히 구분하라.

## 3. 인덱스 전략 — 핵심

### 인덱스 타입별 처방

| 타입 | 언제 | 임계/주의 |
|---|---|---|
| **B-tree** (기본) | `=`, `<`, `>`, `BETWEEN`, `IN`, `ORDER BY`, prefix `LIKE 'abc%'` | 사실상 디폴트. 카디널리티 낮으면(성별 등) 무의미 |
| **Hash** | 오직 `=` 등호 | B-tree가 등호+범위+정렬 다 커버하므로 **거의 안 씀**. 대형 텍스트 등호에서 인덱스 크기만 이득 |
| **GIN** | 다중값 포함: `jsonb @>`, 배열 `&&`, 전문검색 `tsvector`, `pg_trgm` | 쓰기 느림(빌드 비용↑). `jsonb_path_ops`(경로+값 해시, 포함질의만) vs `jsonb_ops`(키별, 존재질의 지원) |
| **GiST** | 범위·기하: `tsrange &&`, PostGIS, 최근접(KNN), 배제 제약 | 손실적(recheck 발생 가능), 오버랩/근접 질의의 왕도 |
| **BRIN** | **물리 정렬된 대용량**: append-only 시계열의 `created_at` | 인덱스 크기 극소(수십 KB/수억 행). 삽입 순서≈값 순서일 때만. 정렬 깨지면 무용 |
| **SP-GiST** | 비균형 공간분할: 계층 IP(`inet`), 텍스트 prefix 트리, 포인트 | 특수. 편향 분포에서 GiST보다 유리 |

### 복합 인덱스 컬럼 순서 (가장 흔한 실수)

**규칙: 등호(=) 컬럼 → 정렬(ORDER BY) 컬럼 → 범위(<,>) 컬럼.** 범위 컬럼 뒤의 컬럼은 인덱스로 정렬/필터에 못 쓴다.

```sql
-- 쿼리: WHERE tenant_id = ? AND status = ? AND created_at > ? ORDER BY created_at DESC
CREATE INDEX ON orders (tenant_id, status, created_at DESC);
--                       └등호──┘  └등호─┘  └범위+정렬┘   ← 범위는 반드시 맨 뒤
```

카디널리티는 순서 결정의 2차 기준(등호끼리 묶인 뒤 선택도 높은 것을 앞). 하지만 **접근 패턴이 우선** — 멀티테넌트는 선택도와 무관하게 `tenant_id`가 선두여야 파티션처럼 동작한다.

### 커버링 / 부분 / 표현식

```sql
-- 커버링(INCLUDE): 인덱스만으로 응답 → Index Only Scan. 키에 없는 컬럼을 리프에 실음
CREATE INDEX ON orders (tenant_id, status) INCLUDE (total, created_at);

-- 부분(partial): 조건 만족 행만 인덱싱 → 크기↓ 쓰기비용↓. soft-delete/활성 상태에 강력
CREATE INDEX ON orders (created_at) WHERE deleted_at IS NULL;

-- 표현식: 함수 결과를 인덱싱. 함수는 반드시 IMMUTABLE (PG가 강제)
CREATE INDEX ON users (lower(email));  -- WHERE lower(email) = ? 가속
```

### 쿼리 shape에서 인덱스 역산하는 법

느린 쿼리를 잡으면 WHERE/JOIN/ORDER BY를 분해한다: **(1) 등호 조건 컬럼들** → 인덱스 선두, **(2) ORDER BY 컬럼** → 중간(방향까지 일치), **(3) 범위 조건** → 맨 뒤, **(4) SELECT 컬럼이 소수면** INCLUDE로 커버링. 자주 나오는 상태 필터는 partial로.

### 과인덱싱 비용 & EXPLAIN 읽기

- 인덱스 하나당 **모든 INSERT/UPDATE/DELETE가 그 인덱스도 갱신** → 쓰기 지연 + WAL 증가 + `autovacuum` 부담. 테이블당 인덱스는 통상 **5~7개 이내**로 관리, 중복/미사용(`pg_stat_user_indexes.idx_scan=0`) 인덱스는 제거.
- `EXPLAIN (ANALYZE, BUFFERS)` 요점: **Seq Scan on 대형테이블 = 위험신호**. `estimated rows` vs `actual rows` 괴리 크면 통계 부실(`ANALYZE` 실행). `Rows Removed by Filter` 크면 인덱스가 안 걸린 것. `shared read`(디스크) vs `shared hit`(캐시). `Nested Loop`가 대량 행에 반복되면 인덱스 부재 or 조인 순서 문제.

## 4. 제약과 무결성 — 앱이 아니라 DB에서 강제

**철칙**: 애플리케이션 검증은 UX용, **DB 제약은 진실의 최후 방어선**. 앱은 버그가 나고 여러 경로로 우회되지만 제약은 안 뚫린다.

| 제약 | 처방 |
|---|---|
| **NOT NULL** | 기본값. nullable은 "값 없음"이 도메인상 의미 있을 때만 |
| **FK** | 참조 무결성 필수. `ON DELETE`: `RESTRICT`(기본, 안전) / `CASCADE`(소유관계만) / `SET NULL`. **cascade 남용은 대량삭제 사고** |
| **UNIQUE** | 비즈니스 유일성. `NULLS NOT DISTINCT`(PG15+)로 NULL 중복도 차단 가능 |
| **CHECK** | 도메인 규칙 (`amount >= 0`, `status IN (...)`, `end > start`) |
| **EXCLUDE** | 범위 겹침 금지 — 예약 double-booking 방어의 정석: `EXCLUDE USING gist (room WITH =, during WITH &&)` |

**외래키 인덱스**: PostgreSQL은 **FK 참조 컬럼에 인덱스를 자동 생성하지 않는다.** 참조 측(자식) FK 컬럼은 반드시 수동 인덱싱 — 없으면 부모 삭제/갱신 시 자식 전체 Seq Scan, 조인도 느림. 이것이 실무 최다 성능 함정.

## 5. 타입 정확성 — 여기서 틀리면 영구 부채

| 도메인 | 처방 | 금지 |
|---|---|---|
| **금액** | `NUMERIC(precision, scale)` 또는 **정수 최소단위**(cents `BIGINT`) | ❌ `float/double` — 0.1+0.2 오차, 반올림 사고 |
| **시각** | `timestamptz` (UTC 저장, 세션 TZ로 변환) | ❌ `timestamp`(naive) — TZ 소실로 오프바이-9시간 |
| **식별자** | 아래 §8 참조 | |
| **범주값** | 소수·안정적 → `enum` 타입 / 다수·변동·메타데이터 필요 → **lookup 테이블+FK** | enum은 값 삭제/재정렬 어려움(`ALTER TYPE`만 추가 가능) |
| **반구조 데이터** | `JSONB` (바이너리, 인덱싱 가능). 스키마 불확정/희소 속성/외부 페이로드 | ❌ 관계로 표현 가능한 걸 JSONB로 — 조인·제약·타입 다 포기하게 됨 |
| **문자열** | `text` (기본). 길이 제약은 `CHECK (length(x) <= N)` | ❌ `varchar(n)` 습관적 사용 — PG에선 `text`와 성능 동일, n만 유연성 저해 |

**JSONB 사용 기준**: 컬럼으로 쿼리·정렬·제약이 필요하면 정규 컬럼. 통째로 읽고 가끔 GIN으로 포함검색만 하면 JSONB. **핵심 필드를 JSONB에 숨기면** 인덱스·FK·NOT NULL을 전부 잃는다. `enum vs lookup`: 상태머신처럼 코드가 아는 고정값은 enum, 사용자가 관리하거나 부가정보(라벨/색/정렬순)가 붙으면 lookup 테이블.

## 6. 트랜잭션과 격리 수준

| 수준 | 방지하는 이상 | 스냅샷 (PG 내부) |
|---|---|---|
| **Read Committed** (PG **기본값**) | dirty read | **문장마다** 새 스냅샷 → non-repeatable/phantom 허용 |
| **Repeatable Read** | dirty + non-repeatable + (PG는 phantom도) | **트랜잭션당 1** 스냅샷. 충돌 시 `40001` serialization failure → **앱 재시도 필수** |
| **Serializable** | 전부 | RR 스냅샷 + **predicate lock**(SSI). write skew까지 방어. 최고 안전·최고 abort율 |

> PostgreSQL은 표준의 Read Uncommitted를 Read Committed로 승격하고, MVCC로 읽기가 쓰기를 막지 않는다. RR/Serializable은 `40001`을 던질 수 있으므로 **그 두 수준을 쓸 땐 재시도 루프가 코드에 있어야 한다.**

**락 선택**:
- **비관적**: `SELECT ... FOR UPDATE`(행 잠금, 기본 대기). `NOWAIT`(즉시 에러), `SKIP LOCKED`(잠긴 행 건너뜀 — **작업 큐 디스패치의 정석**). 재고 차감·잔액 이체처럼 경합이 확실할 때.
- **낙관적**: `version` 컬럼 + `UPDATE ... WHERE version = ?` → 영향행 0이면 재시도. 경합이 드물 때 락 오버헤드 회피.
- **데드락 회피**: 여러 행/테이블을 **항상 같은 순서로 잠근다**(예: id 오름차순). PostgreSQL은 데드락을 감지해 한쪽을 abort하므로, 재시도 가능한 트랜잭션으로 설계. 트랜잭션은 **짧게** — 사용자 입력 대기 중 락 보유 금지.

## 7. 파티셔닝 — 대용량의 관리 단위

PG 선언적 파티셔닝: 부모는 `PARTITION BY`, 자식은 `FOR VALUES`. **파티션 키는 모든 PK/UNIQUE 제약에 포함돼야 한다**(전역 유니크 인덱스 부재).

| 방식 | 언제 | 키 선택 |
|---|---|---|
| **RANGE** | 시계열 로그/이벤트, 날짜 아카이빙 | `created_at` 월/일 단위. 오래된 파티션 `DETACH`로 즉시 삭제(DELETE 불필요) |
| **LIST** | 명시적 범주: 리전, 국가, 멀티테넌트 | `region`, 대형 테넌트 전용 파티션 |
| **HASH** | 자연 경계 없이 균등 분산만 필요 | `hash(tenant_id)` N버킷 — 핫스팟 완화 |

```sql
CREATE TABLE events (id bigint, tenant_id int, created_at timestamptz, ...)
  PARTITION BY RANGE (created_at);
CREATE TABLE events_2026_08 PARTITION OF events
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
```

**프루닝**: WHERE에 파티션 키가 있어야 플래너가 무관 파티션을 스캔에서 제외(`enable_partition_pruning`, 기본 on). 키 없는 쿼리는 **전체 파티션 스캔** → 파티셔닝 이득 상실. **처방: 파티션은 "수억 행 + 명확한 시간/테넌트 접근 패턴"에서만.** 소규모에 도입하면 관리 복잡도만 늘고 이득 없다. 파티션 생성/삭제 자동화(`pg_partman`) 필수.

## 8. 키 설계

- **자연키 vs 대리키**: 대리키(`IDENTITY`/UUID) 기본. 자연키(이메일, ISBN)는 변할 수 있고 PK 변경은 재앙 → **자연키는 UNIQUE 제약으로, PK는 대리키로.**
- **BIGINT `GENERATED ALWAYS AS IDENTITY`**: 8바이트, 순차 → 인덱스 지역성 최상, 쓰기 빠름. 단점: 값이 예측 가능(열거 공격), 분산 생성 불가. `serial`은 레거시 — **`IDENTITY` 권장.**
- **UUID v4 vs v7**: v4는 완전 랜덤 → **B-tree 페이지 단편화**(삽입이 인덱스 전체에 흩어져 WAL·캐시미스↑). **v7은 앞부분이 타임스탬프**라 시간순 정렬 → 삽입 지역성이 BIGINT급으로 회복. **분산 ID가 필요하면 v4가 아니라 v7을 쓴다.** 저장은 `uuid` 타입(16B), 절대 `text`(36B) 금지.
- **트레이드오프 요약**: `BIGINT IDENTITY` = 최고 성능·최소 저장, 단일 DB 중앙 생성. `UUID v7` = 분산 생성·비열거성 + 준수한 지역성(16B). `UUID v4` = 완전 분산 랜덤이나 인덱스 단편화 대가.
- **복합 PK**: 순수 조인/연결 테이블(`(order_id, product_id)`)에 적합·명확. 단 FK로 참조될 땐 자식마다 두 컬럼을 끌고 다녀야 하므로, 참조가 많으면 대리키 + 복합 UNIQUE가 낫다.

---

## 상호 참조

- **[db-selection-guide.md](./db-selection-guide.md)** — 관계형 vs NoSQL vs NewSQL, 엔진 선택 기준
- **[nosql-modeling.md](./nosql-modeling.md)** — 문서/KV/와이드컬럼 모델링, 접근패턴 우선 설계
- **[scaling-migration.md](./scaling-migration.md)** — 읽기복제/샤딩, 무중단 스키마 마이그레이션(expand-contract)
- **[schema-quality-checklist.md](./schema-quality-checklist.md)** — 스키마 리뷰 체크리스트, 안티패턴 감사
