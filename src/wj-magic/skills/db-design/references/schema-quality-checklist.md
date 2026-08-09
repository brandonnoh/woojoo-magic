# 스키마 품질 진단 체크리스트 (안티패턴 카탈로그)

> **증상이 아니라 신호를 본다.** DIAGNOSE mode는 "느리다"는 호소를 코드·EXPLAIN·pg_stat 증거로 환원한다. 각 결함을 **탐지 신호 → 왜 문제 → 수정법 → MIG 안전성**으로 카탈로그화하고, 영향도 × 수정비용으로 Wave 분류한다. 추측 금지 — 모든 판정은 심볼 추적·쿼리 로그·실측 플랜에 근거한다. 기준: PostgreSQL 16/17/18, MySQL 8, Prisma 6/7 · Drizzle · TypeORM (2025~2026).

## 0. 진단 방법론 — 세 층위로 증거를 모은다

진단은 **정적(코드) → 통계(누적) → 실측(플랜)** 3층으로 교차 검증한다. 한 층만으로 판정하지 않는다.

| 층위 | 도구 | 무엇을 잡나 |
|---|---|---|
| **정적** | Serena 심볼 추적, Grep(ORM/raw SQL 패턴) | 루프 내 쿼리(N+1), `SELECT *`, 하드코딩 enum, float 금액 |
| **통계** | `pg_stat_statements`, `pg_stat_user_tables`, `pg_stat_user_indexes` | 느린 쿼리 랭킹, Seq Scan 비율, 미사용 인덱스 |
| **실측** | `EXPLAIN (ANALYZE, BUFFERS)`, `auto_explain` | 실제 실행 계획, 실 행수 vs 추정 행수, 버퍼 히트 |

### 0-1. 정적 — 모델→쿼리 매핑

1. Serena `get_symbols_overview`로 모델/엔티티 정의(스키마 파일, `@Entity`, Prisma `model`, Drizzle `pgTable`)를 수집.
2. `find_referencing_symbols`로 각 모델을 참조하는 쿼리 호출부를 추적 → **루프·`map`·`forEach` 내부의 쿼리 호출**을 N+1 후보로 표시.
3. `search_for_pattern`으로 raw SQL·ORM 관용구를 스캔:

```
N+1 후보:   \.findUnique\(|\.findFirst\(|await .+\.(find|get)\w*\(.+\).*(for|map|forEach)
SELECT *:   SELECT\s+\*|\.select\(\)(?!\.)   # 컬럼 미지정
오프셋:     OFFSET\s+\d{3,}|\.skip\(\s*\w+\s*\)
앞와일드:   LIKE\s+'%|ILIKE\s+'%
float 금액: (price|amount|balance|total)\s+(float|double|real|FLOAT|DOUBLE)
```

### 0-2. 통계 — 누적 지표로 우선순위

```sql
-- 느린 쿼리 Top 50 (mean 기준). PG 13+는 total_exec_time/mean_exec_time
SELECT calls, round(total_exec_time::numeric,1) total_ms,
       round(mean_exec_time::numeric,2) mean_ms, rows, query
FROM pg_stat_statements WHERE calls > 10
ORDER BY mean_exec_time DESC LIMIT 50;

-- 인덱스 없이 스캔되는 테이블 (seq_scan 많고 idx_scan 적음 = 인덱스 후보)
SELECT relname, seq_scan, seq_tup_read, idx_scan,
       seq_tup_read / GREATEST(seq_scan,1) AS avg_rows_per_seq
FROM pg_stat_user_tables
WHERE seq_scan > 0 ORDER BY seq_tup_read DESC LIMIT 30;

-- 미사용 인덱스 (idx_scan=0, PK/UNIQUE 제외). 통계 리셋 후 최소 1개월 관찰
SELECT s.relname, s.indexrelname, s.idx_scan,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size
FROM pg_stat_user_indexes s JOIN pg_index i ON i.indexrelid = s.indexrelid
WHERE s.idx_scan = 0 AND NOT i.indisunique AND NOT i.indisprimary
ORDER BY pg_relation_size(s.indexrelid) DESC;
```

### 0-3. 실측 — EXPLAIN으로 확정

- `EXPLAIN (ANALYZE, BUFFERS)`로 실행. `ANALYZE`는 실제로 쿼리를 돌리므로 **쓰기 쿼리는 트랜잭션으로 감싸 롤백**. `Seq Scan on <bigtable>` + 높은 `rows` = 인덱스 누락 확정. **추정 행수 vs 실 행수(`rows=N ... actual rows=M`) 괴리 10배 이상**이면 `ANALYZE <table>`로 통계 갱신 필요.
- 상시 수집: `auto_explain`(`log_min_duration`, `log_analyze`)으로 프로덕션 느린 쿼리 플랜을 자동 로깅.

### 0-4. 심각도 정의

| 심각도 | 기준 | 처리 |
|---|---|---|
| **CRITICAL** | 데이터 무결성 붕괴(FK/UNIQUE 부재로 고아·중복), 금액 정밀도 손실, 프로덕션 장애 유발 락/톰스톤 | Wave 1 즉시 |
| **HIGH** | 핵심 경로 N+1·풀스캔으로 p95 SLA 위협, 무한 성장 테이블, 나쁜 샤드 키 | Wave 2 |
| **MEDIUM** | 국소적 오버페칭, 미사용 인덱스, 과대 varchar, soft-delete 남용 | 백로그 |
| **LOW** | 스타일·미세 최적화, 근사 카운트 미도입 | 여유 시 |

---

## 1. 쿼리 접근 결함 (N+1 · 오버페칭 · 페이지네이션)

### 1-1. N+1 쿼리 — lazy loading 폭발

| 항목 | 내용 |
|---|---|
| **탐지 신호** | 로그에 동일 형태 쿼리가 부모 건수만큼 반복(`WHERE id = $1` × N). 정적: 루프/`map` 내부 쿼리 호출. `pg_stat_statements`에서 `calls` 비정상적으로 큰 단순 SELECT. ORM별 아래 참조 |
| **왜 문제** | 부모 1 + 자식 N = N+1 라운드트립. 네트워크 RTT × N으로 지연 선형 증가, 커넥션 풀 고갈 |
| **수정법** | eager/join fetch, DataLoader 배칭, `IN (...)` 단일 쿼리로 재작성 |
| **MIG 안전성** | ✅ 안전 — 쿼리 코드만 변경, 스키마 무변경. 배포 즉시 반영 |

**ORM별 탐지·수정 (2025~2026):**

| ORM | N+1 발생 지점 | 수정 관용구 |
|---|---|---|
| **Prisma** | 관계를 루프에서 개별 접근. `include` 없이 나중에 `.posts` 접근 | `include: { posts: true }` / `select`로 필요 관계 한 번에. 로그: `log: ['query']`로 반복 SELECT 확인 |
| **Drizzle** | Relational API `.with` 누락, 또는 결과를 루프 돌며 재쿼리 | `db.query.users.findMany({ with: { posts: true } })` 또는 Select API `.leftJoin` — Drizzle은 명시적이라 단일 최적 SQL 생성 가능 |
| **TypeORM** | lazy relation(`Promise` 타입) 접근, `find`에 `relations` 누락 | `relations: ['posts']` 또는 `QueryBuilder.leftJoinAndSelect`. 대량 행은 클래스 인스턴스화 비용도 별도 병목 |

> N+1은 대개 코드 수정만으로 끝나지만, join 재작성 후 **JOIN/WHERE 컬럼에 인덱스가 없으면** 2-1 결함으로 전이한다 — 반드시 EXPLAIN 재확인.

### 1-2. SELECT * / 오버페칭

| 항목 | 내용 |
|---|---|
| **탐지 신호** | `SELECT *`, ORM `.select()` 무인자, 응답 DTO보다 훨씬 많은 컬럼 페치. TOAST 컬럼(대형 text/jsonb)까지 매번 읽음 |
| **왜 문제** | 불필요 I/O·네트워크, **커버링 인덱스(index-only scan) 무력화**, 대형 컬럼 동반 페치로 버퍼 압박 |
| **수정법** | 필요한 컬럼만 명시. 자주 함께 읽는 소수 컬럼은 커버링 인덱스(`INCLUDE`)로 index-only scan 유도 |
| **MIG 안전성** | ✅ 안전 — 쿼리 변경. 커버링 인덱스 추가는 `CREATE INDEX CONCURRENTLY` |

### 1-3. OFFSET 딥 페이지네이션 (대용량)

| 항목 | 내용 |
|---|---|
| **탐지 신호** | `OFFSET <큰수>` 또는 ORM `.skip(n)`. 페이지 깊어질수록 응답 느림. `pg_stat_statements`에서 같은 쿼리의 지연이 파라미터에 따라 편차 큼 |
| **왜 문제** | OFFSET은 버려질 앞 N행을 **모두 스캔** → 깊이에 따라 O(n). 1M 행 테이블에서 offset 0은 ~0.3ms, offset 999,990은 ~138ms. 게다가 스크롤 중 삽입/삭제 시 **행 누락·중복** |
| **수정법** | **Keyset(cursor) 페이지네이션** — `WHERE (created_at, id) < ($last_ts, $last_id) ORDER BY created_at DESC, id DESC LIMIT n`. 정렬 컬럼 복합 인덱스 필수. O(1) 유지 |
| **MIG 안전성** | ✅ 안전 — 쿼리·API 계약 변경(cursor 토큰). 정렬키 복합 인덱스 `CONCURRENTLY` 추가 |

### 1-4. LIKE '%x%' 앞 와일드카드 & 인덱스 없는 정렬/조인

| 항목 | 내용 |
|---|---|
| **탐지 신호** | `LIKE '%term%'`(선행 `%`), `ORDER BY`/`JOIN` 컬럼에 인덱스 없음 → EXPLAIN에 `Seq Scan` + `Sort`(external merge Disk) |
| **왜 문제** | 선행 와일드카드는 B-tree 무력 → 풀스캔. 인덱스 없는 정렬은 디스크 정렬로 `work_mem` 초과 |
| **수정법** | 부분 일치는 `pg_trgm` GIN 인덱스 또는 전용 검색엔진(→ specialized-stores). 정렬/조인 컬럼에 인덱스. 정렬은 ESR 순서 복합 인덱스로 커버 |
| **MIG 안전성** | ✅ 안전 — `CREATE INDEX CONCURRENTLY`. GIN/pg_trgm은 확장 설치 필요 |

### 1-5. COUNT(*) 남발 (N+1 카운트)

| 항목 | 내용 |
|---|---|
| **탐지 신호** | 목록마다 `SELECT COUNT(*)`, 페이지네이션 total을 매 요청 계산. 대형 테이블 카운트가 상위 느린 쿼리 |
| **왜 문제** | MVCC 상 정확 `COUNT(*)`는 조건에 맞는 행 전수 방문 → 대형 테이블에서 고비용 |
| **수정법** | (1) 정확성 불필요 시 `pg_class.reltuples` 근사 (2) 자주 쓰는 카운트는 **카운터 캐시**(트리거/앱에서 증감) (3) "다음 페이지 존재 여부"는 `LIMIT n+1`로 대체 |
| **MIG 안전성** | ⚠️ 주의 — 카운터 컬럼 추가 시 백필 + 트리거. 백필 중 정합성 윈도우 관리 |

---

## 2. 인덱스 결함

### 2-1. 인덱스 누락 (풀스캔)

| 항목 | 내용 |
|---|---|
| **탐지 신호** | EXPLAIN에 `Seq Scan on <bigtable>`. `pg_stat_user_tables`에서 `seq_scan` 크고 `idx_scan` 작음. `WHERE`/`JOIN`/`ORDER BY` 컬럼에 대응 인덱스 부재 |
| **왜 문제** | 매 쿼리 전체 테이블 스캔 → 데이터 증가에 따라 선형 악화, 버퍼·CPU 낭비 |
| **수정법** | 필터·조인·정렬 컬럼에 인덱스. 복합은 **ESR(Equality→Sort→Range)** 순서. 조건 편중 시 부분 인덱스(`WHERE deleted_at IS NULL`) |
| **MIG 안전성** | ✅ 안전 — 반드시 `CREATE INDEX CONCURRENTLY`(테이블 락 회피). 단 트랜잭션 밖에서 실행, 실패 시 `INVALID` 인덱스 정리 |

### 2-2. FK 인덱스 누락

| 항목 | 내용 |
|---|---|
| **탐지 신호** | FK 컬럼(`*_id`)에 인덱스 없음. 부모 삭제/업데이트가 느림, 자식 방향 조인이 Seq Scan |
| **왜 문제** | PostgreSQL은 FK 참조 컬럼에 인덱스를 **자동 생성하지 않는다**. 부모 DELETE 시 자식 전수 스캔, 조인 성능 저하 |
| **수정법** | 모든 FK 컬럼에 인덱스 추가 |
| **MIG 안전성** | ✅ 안전 — `CREATE INDEX CONCURRENTLY` |

### 2-3. 과도한 인덱스 (쓰기 비용)

| 항목 | 내용 |
|---|---|
| **탐지 신호** | `pg_stat_user_indexes.idx_scan = 0`(PK/UNIQUE 제외), 통계 리셋 후 **1개월+ 관찰**. 중복 인덱스(`(a)`와 `(a,b)` 중 앞쪽 잉여), 쓰기 지연 증가 |
| **왜 문제** | 인덱스마다 INSERT/UPDATE/DELETE에 유지 비용, 디스크·캐시 낭비, HOT update 방해 |
| **수정법** | 미사용·중복 인덱스 `DROP INDEX CONCURRENTLY`. 삭제 전 idx_scan 0 확인 + 스탠바이/피크에서도 미사용인지 교차 확인 |
| **MIG 안전성** | ⚠️ 주의 — `DROP INDEX CONCURRENTLY`. 삭제 후 특정 쿼리 회귀 가능 → 먼저 `INVISIBLE`(MySQL) 또는 사전 EXPLAIN로 의존 여부 검증 |

---

## 3. 정규화·무결성 결함

### 3-1. 과정규화 vs 미정규화

| 축 | 과정규화 | 미정규화 |
|---|---|---|
| **탐지** | 단순 조회에 5+ 테이블 조인, 조인 폭발 | 같은 값이 여러 행/테이블에 중복, 갱신 시 일부만 바뀜 |
| **왜 문제** | 조인 비용·플래너 부담, 읽기 지연 | 갱신 이상(update anomaly), 데이터 갈라짐 |
| **수정법** | 읽기 핫패스만 선별적 비정규화(계산 컬럼·요약 테이블), 원본은 정규화 유지 | 3NF로 분해, 파생값은 생성 컬럼/뷰/트리거로 단일 원천화 |
| **MIG 안전성** | ⚠️ 비정규화 컬럼 추가+백필+동기화 트리거 | ⚠️ 테이블 분해는 다단계(신규 테이블→이중 쓰기→백필→컷오버) |

> 판단 기준: **읽기 지연이 문제면 선택적 비정규화, 무결성이 문제면 정규화.** 둘 다면 정규화를 원천으로 두고 읽기 전용 파생을 추가한다.

### 3-2. FK 누락 (고아 레코드)

| 항목 | 내용 |
|---|---|
| **탐지 신호** | 논리적 참조(`user_id`)에 `REFERENCES` 제약 없음. 부모 없는 자식 행 존재(`LEFT JOIN ... WHERE parent.id IS NULL` 검출) |
| **왜 문제** | 무결성이 앱 코드에만 의존 → 버그·경합·수동 SQL로 고아 레코드 발생, 집계 왜곡 |
| **수정법** | `FOREIGN KEY ... REFERENCES` + 적절한 `ON DELETE`(RESTRICT/CASCADE/SET NULL). 추가 전 기존 고아 정리 |
| **MIG 안전성** | ⚠️ 위험 — FK 추가 시 전체 검증 락. `ADD CONSTRAINT ... NOT VALID` 먼저 → `VALIDATE CONSTRAINT`(락 짧음) 2단계. 고아 존재 시 실패 |

### 3-3. 누락된 제약 (UNIQUE · CHECK · NOT NULL)

| 항목 | 내용 |
|---|---|
| **탐지 신호** | 비즈니스상 유일해야 할 값(email, slug)에 UNIQUE 없음, nullable이면 안 될 컬럼이 nullable, 상태값 범위 검증 부재 |
| **왜 문제** | 중복 가입·경합으로 인한 중복 행, NULL 폭탄, 잘못된 enum 값 유입 |
| **수정법** | `UNIQUE`(부분 유니크 가능), `CHECK`, `NOT NULL`. 앱 검증은 방어선이지 원천이 아님 |
| **MIG 안전성** | ⚠️ NOT NULL/UNIQUE 추가는 검증 스캔. PG는 `CHECK ... NOT VALID`→`VALIDATE` 2단계로 락 최소화. NOT NULL은 기본값 백필 선행 |

---

## 4. 타입·모델링 결함

### 4-1. 부정확한 타입

| 결함 | 탐지 신호 | 왜 문제 | 수정법 |
|---|---|---|---|
| **금액을 float/double** | `price float`, `amount double` | 이진 부동소수 → 반올림 오차, 합계 불일치(회계 결함) | `NUMERIC(precision, scale)` 또는 정수 최소단위(cents) |
| **시각을 tz 없이** | `timestamp`(=`without time zone`), `datetime` | 서버/클라 타임존 뒤섞임, DST 버그 | `timestamptz`(UTC 저장·표시 변환) |
| **문자열 PK** | 자연키 문자열을 PK로 | 넓은 인덱스, 조인 비용, 변경 시 연쇄 | 대리키(`bigint`/UUIDv7) + 자연키는 UNIQUE |
| **과대 varchar** | `varchar(255)` 관성 지정 | 잘못된 상한, 검증 착각 | 실제 도메인 상한 또는 PG는 `text`+CHECK(길이 제약은 CHECK로) |
| **enum 하드코딩** | 앱 상수와 DB 문자열 이중 관리, 오타 유입 | 정합성 붕괴, 값 추가 시 양쪽 수정 | PG `ENUM` 타입 또는 참조 테이블(FK) — 확장 잦으면 참조 테이블 |

**MIG 안전성**: float→numeric, timestamp→timestamptz는 **타입 변환 시 전체 테이블 재작성 + 락**. 안전 절차 — 신규 컬럼 추가 → 이중 쓰기 → 백필(배치) → 읽기 전환 → 구컬럼 제거. `timestamp`→`timestamptz`는 세션 타임존 해석에 주의(UTC 가정 명시).

### 4-2. UUIDv4 PK 인덱스 단편화

| 항목 | 내용 |
|---|---|
| **탐지 신호** | PK가 `uuid`이고 애플리케이션이 **UUIDv4(랜덤)** 생성. 인덱스 팽창·낮은 heap correlation, 쓰기 처리량 저하 |
| **왜 문제** | 랜덤 UUID는 B-tree 삽입 위치가 매번 흩어져 **페이지 분할·단편화**, 최근 삽입 페이지가 물리적으로 인접하지 않아 shared buffer 캐시 무력화 |
| **수정법** | **UUIDv7(시간순, RFC 9562)** 채택 — heap correlation ≈ 1, 단편화·범위 스캔 개선. PG 18은 `uuidv7()` 내장. 순수 순번이면 `bigint identity` |
| **MIG 안전성** | ⚠️ 기존 PK 타입 유지 시 신규 행부터 UUIDv7 생성으로 점진 개선. PK 재발급은 대규모 마이그레이션(참조 무결성 연쇄) — 신규 테이블·신규 서비스부터 적용 권장 |

### 4-3. JSONB 남용 (관계형을 JSON에)

| 항목 | 내용 |
|---|---|
| **탐지 신호** | 자주 쿼리·조인·집계하는 구조화 데이터를 통째 `jsonb`에. `->>`로 필터·정렬, JSON 내부 값에 무결성 제약 불가 |
| **왜 문제** | 부분 갱신 비효율(전체 재기록), 인덱싱 제약, FK·UNIQUE·CHECK 불가, 스키마 드리프트 |
| **수정법** | 안정적·관계형 필드는 정규 컬럼으로 승격. JSONB는 **진짜 가변/희소/반정형**(설정 blob, 외부 페이로드)에 한정. 필요 시 GIN 인덱스 또는 표현식 인덱스 |
| **MIG 안전성** | ⚠️ JSON 키→컬럼 승격은 신규 컬럼+백필(`data->>'k'` 추출)+이중 쓰기+읽기 전환 |

### 4-4. Soft delete 오남용

| 항목 | 내용 |
|---|---|
| **탐지 신호** | 모든 테이블에 `deleted_at`, 모든 쿼리에 `WHERE deleted_at IS NULL` 강제. 인덱스가 삭제 행까지 포함, UNIQUE가 삭제 행과 충돌 |
| **왜 문제** | 테이블 무한 팽창, 모든 인덱스·쿼리에 필터 부담, "재사용 불가 email" 같은 UNIQUE 충돌, 실수로 삭제 행 노출 |
| **수정법** | 정말 이력 필요 시에만. **부분 인덱스**(`WHERE deleted_at IS NULL`)로 활성 행만 인덱싱, 부분 UNIQUE로 재사용 허용. 대량 이력은 아카이브 테이블로 물리 이동 |
| **MIG 안전성** | ✅ 부분 인덱스 교체는 `CONCURRENTLY`. 아카이브 이동은 배치 |

---

## 5. 규모·동시성 결함

### 5-1. 무한 증가 테이블 (로그·이벤트)

| 항목 | 내용 |
|---|---|
| **탐지 신호** | events/logs/audit 테이블이 파티션·아카이빙·TTL 없이 수억 행. VACUUM·인덱스·백업 시간 폭증 |
| **왜 문제** | 단일 거대 테이블 → 인덱스 비대, autovacuum 지연, 오래된 데이터가 핫 쿼리 방해 |
| **수정법** | **선언적 파티셔닝**(시간 RANGE, 예: 월별). 오래된 파티션은 `DETACH`+아카이브 또는 `DROP`(톰스톤 없이 즉시 회수). 시계열은 TimescaleDB/전용 스토어 고려 |
| **MIG 안전성** | ⚠️ 기존 테이블→파티션 전환은 다단계(신규 파티션 부모 생성→데이터 이관→어태치). PG 무중단 전환은 신중한 계획 필요 |

### 5-2. 핫 파티션 / 나쁜 샤드 키

| 항목 | 내용 |
|---|---|
| **탐지 신호** | 파티션/샤드 키가 저카디널리티(`status`, `country`)나 단조증가(현재 시각·순번) → 특정 파티션에 쓰기 집중. 한 노드 CPU/IO만 포화 |
| **왜 문제** | 저카디널리티는 데이터 편중, 단조증가는 항상 마지막 파티션에 쓰기 몰림(hot spot), 확장 무력화 |
| **수정법** | 고카디널리티·균등 분포 키. 단조 키는 해시/버킷 접미사로 분산. 접근 패턴이 파티션 pruning을 활용하도록 키 설계 |
| **MIG 안전성** | ⚠️ 위험 — 샤드/파티션 키 변경은 재분산. 신규 스키마로 재적재하는 대공사 |

### 5-3. 락 경합 / 긴 트랜잭션

| 항목 | 내용 |
|---|---|
| **탐지 신호** | `pg_stat_activity`에 `wait_event_type='Lock'`, `pg_locks` 대기 체인, 데드락 로그, `idle in transaction` 장수 세션. `deadlock_timeout` 초과 로그 |
| **왜 문제** | 긴 트랜잭션이 락 보유·오래된 스냅샷 유지 → autovacuum 방해(테이블 팽창), 동시성 붕괴, 데드락 |
| **수정법** | 트랜잭션 짧게(외부 I/O를 트랜잭션 밖으로), 일관된 락 순서로 데드락 회피, `SELECT ... FOR UPDATE` 범위 최소화, `lock_timeout`/`idle_in_transaction_session_timeout` 설정 |
| **MIG 안전성** | ✅ 코드/설정 변경. DDL 자체가 락 유발 → 마이그레이션에 `lock_timeout` 짧게 걸고 재시도 패턴 |

---

## 6. 진단 보고 형식

code-analyst 스타일의 순위 표로 보고한다. 각 행은 **증거(EXPLAIN/pg_stat/심볼 경로)를 반드시 포함**한다.

```markdown
### 스키마 진단 결과

**진단 범위:** <스캔한 스키마/테이블/쿼리>
**증거 소스:** pg_stat_statements(Top50) + EXPLAIN ANALYZE + Serena 모델→쿼리 매핑

| 순위 | 위치 | 결함 | 심각도 | 근거(증거) | 수정법 | MIG 안전성 |
|---|---|---|---|---|---|---|
| 1 | `orders.amount` | 금액 float | CRITICAL | 컬럼 타입 `double`, 합계 오차 재현 | NUMERIC(12,2)로 변환 | ⚠️ 재작성·이중쓰기 |
| 2 | `posts` 목록 API | N+1 (author) | HIGH | 로그 SELECT×N, `map` 내 findUnique | Prisma include | ✅ 쿼리만 |
| 3 | `events(created_at)` | 인덱스 누락 | HIGH | EXPLAIN Seq Scan, seq_scan 2.1M | CONCURRENTLY 인덱스 | ✅ 온라인 |
| 4 | `users.email` | UNIQUE 부재 | CRITICAL | 중복 email 12건 검출 | 부분 UNIQUE | ⚠️ 중복 정리 선행 |
| 5 | `idx_posts_tmp` | 미사용 인덱스 | MEDIUM | idx_scan=0, 관찰 34일 | DROP CONCURRENTLY | ⚠️ 사전 EXPLAIN |

**데이터 흐름 서술:** <API 엔드포인트> → <ORM 쿼리> → <실행 계획 병목>
```

## 7. 우선순위화 — Wave 분류

**우선순위 = 영향도(성능·무결성·확장성) ÷ 수정 비용.** 무결성 결함은 조용히 데이터를 오염시키므로 성능보다 앞선다.

| Wave | 포함 | 판단 기준 | MIG 특성 |
|---|---|---|---|
| **Wave 1 (CRITICAL 즉시)** | 금액 float, FK/UNIQUE 부재로 무결성 붕괴, 프로덕션 락/데드락 | 데이터 손상·장애 진행 중 | ⚠️ 대개 위험 마이그레이션 → NOT VALID 2단계·이중쓰기·백필로 안전화 |
| **Wave 2 (HIGH)** | 핫패스 N+1, 풀스캔 인덱스 누락, 무한 성장 테이블, 나쁜 샤드 키 | SLA p95 위협·확장 한계 | 인덱스는 ✅ 온라인(CONCURRENTLY), 파티션/샤드는 ⚠️ 다단계 |
| **Wave 3 (MEDIUM 백로그)** | 오버페칭, 미사용 인덱스, 과대 varchar, soft-delete 정리, OFFSET→keyset | 국소 개선·유지비 절감 | 대부분 ✅ 온라인 |
| **Wave 4 (LOW)** | 근사 카운트 도입, enum 정리, 스타일 | 여유 시 | ✅ 안전 |

**실행 원칙:** (1) 같은 테이블을 건드리는 마이그레이션은 락 충돌 방지를 위해 직렬화. (2) 위험 마이그레이션은 항상 온라인 패턴(신규 컬럼→이중쓰기→백필→컷오버→구컬럼 제거)으로 분해. (3) 각 Wave 후 `pg_stat_statements` 리셋·EXPLAIN 재측정으로 개선 검증(→ verify).

---

## 상호 참조

- **DB 종류 선택** (관계형 vs NoSQL 결정): [db-selection-guide.md](./db-selection-guide.md)
- **관계형 모델링** (정규화·인덱스·제약 설계 원칙): [relational-modeling.md](./relational-modeling.md)
- **NoSQL 모델링** (문서·KV·와이드컬럼 안티패턴): [nosql-modeling.md](./nosql-modeling.md)
- **특수 스토어** (검색·그래프·벡터·시계열 진단): [specialized-stores.md](./specialized-stores.md)
- **확장·마이그레이션** (무중단 스키마 전환·샤딩·복제): [scaling-migration.md](./scaling-migration.md)
