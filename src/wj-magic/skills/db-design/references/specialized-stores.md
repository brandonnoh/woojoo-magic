# 특수 목적 저장소 처방 (벡터 / 검색 / 시계열 / 그래프 / 데이터웨어하우스)

> **범용 DB로 안 되는 지점에서만 특수 저장소를 도입한다.** 5종 모두 "PostgreSQL로 어디까지 버티는가"를 먼저 묻고, 그 경계를 넘을 때만 전용 스토어를 얹는다. 특수 저장소는 예외 없이 **원본(Source of Truth) 옆에 붙는 파생 인덱스** — SoT는 관계형/문서 DB에 두고, 특수 스토어는 CDC로 동기화되는 조회 최적화 사본이다. 기준: pgvector 0.8 / pgvectorscale, Elasticsearch 9.x / OpenSearch 3.x, TimescaleDB 2.24 (TigerData), InfluxDB 3, Neo4j 2026.x, Snowflake / BigQuery / ClickHouse (2025~2026).

## 0. 공통 원칙 — 특수 스토어는 파생물이다

| 축 | 처방 |
|---|---|
| **SoT 분리** | 원본은 관계형/문서 DB. 특수 스토어는 **파생 인덱스** — 유실돼도 SoT에서 재구축 가능해야 한다 |
| **동기화** | 앱에서 SoT + 특수스토어 이중 쓰기(dual-write) 금지. **CDC(Debezium/WAL) 또는 Transactional Outbox**로 최종 동기화 |
| **도입 시점** | "PostgreSQL로 안 되는 명확한 이유"가 생긴 뒤 도입. 선제 도입은 운영 부담만 추가 |
| **워크로드 격리** | 무거운 분석/검색이 OLTP 트랜잭션과 자원 경합하지 않도록 물리 분리 |

**과잉 도입 신호**: 데이터 100만 건 미만인데 전용 벡터DB·검색엔진·DW를 각각 세운다. → 대부분 pgvector + PG FTS + read replica로 커버되며, 운영 대상만 4배로 늘어난다.

## 1. 벡터 DB (Pinecone, Weaviate, Milvus, Qdrant, pgvector)

### 1-1. 임베딩 차원 & 거리 메트릭

임베딩 모델이 차원과 정규화 여부를 결정하고, 그것이 메트릭 선택을 강제한다.

| 모델 | 차원 | 비고 |
|---|---|---|
| all-MiniLM-L6-v2 | **384** | 경량 셀프호스트 기본, 256토큰 상한 |
| OpenAI 3-small / Cohere v3 / BGE-m3 | **1024~1536** | 3-small=1536, Cohere v3=1024, bge-m3=1024(dense+sparse 동시 출력) |
| OpenAI 3-large / Gemini embedding-001 | **3072** | Matryoshka(MRL) — 앞 N차원 잘라 저장·RAM 절감, 재임베딩 불필요 |

- **거리 메트릭**: **cosine**(각도만, 텍스트 기본·안전) / **dot·IP**(각도+크기, 정규화 벡터에선 cosine과 동일 랭킹인데 정규화 스텝이 없어 **더 빠름**) / **L2**(거리, 이미지·공간).
- **핵심 항등식**: 단위 정규화 벡터에서 **cosine == dot product**. OpenAI 모델은 정규화 출력이라 아무 메트릭이나 랭킹 동일 → 속도 위해 IP 선택. E5/BGE/MiniLM은 cosine 학습 → cosine(또는 정규화 후 dot).
- **주의**: Gemini 등 MRL 모델을 3072 미만으로 잘라 쓰면 **수동 L2 정규화 필수**(안 하면 랭킹 깨짐).

### 1-2. ANN 인덱스 — HNSW vs IVFFlat vs DiskANN

정확도(recall@k) × 속도(QPS/지연) × 메모리의 3자 트레이드오프. **recall@k** = 근사 검색이 반환한 것 중 진짜 top-k의 비율(recall@10=0.95 → 평균 9.5개 적중).

| 인덱스 | 핵심 파라미터 | 특성 | 언제 |
|---|---|---|---|
| **HNSW** | `m`(노드당 최대 엣지), `ef_construction`(빌드 후보수), `ef_search`(쿼리 후보수, 런타임 조정) | 95%+ recall 기본, 삽입 흡수(재빌드 불필요), **메모리 2~5배**, 빌드 느림 | **기본 선택** — 활성 쓰기 + recall 우선, ~1000만 벡터 이하 |
| **IVFFlat** | `nlist`(k-means 클러스터), `nprobe`(쿼리 시 탐색 클러스터 수) | 빌드 빠름·메모리 적음, 데이터 변하면 recall 표류(중심 재학습 필요) | 대량(>5000만)·정적·메모리/빌드시간 제약 |
| **DiskANN** | Vamana 그래프 + SSD/NVMe | 그래프 대부분을 디스크에, 압축분만 RAM | **1억~10억+ 벡터**, in-RAM HNSW가 비용 초과할 때 |

- **HNSW 튜닝**: `m`↑ → recall↑·메모리↑·빌드느림(pgvector 기본 16, 텍스트 16~32). `ef_construction`↑ → recall↑·빌드느림(기본 64, ≥2*m). `ef_search`↑ → recall↑·지연↑ (기본 40, 재빌드 없이 100~400까지 상향, ≥k). **정확도 부족하면 먼저 `ef_search`부터 올린다** — 재인덱싱 없이 조정 가능.
- **IVFFlat 튜닝**: `nlist ≈ sqrt(rows)`(100만행→1000), 데이터 적재 **후** 빌드(중심 학습에 데이터 필요). `nprobe`는 1~1000만 벡터에 8~16 시작. recall 부족하면 nprobe↑(지연 대가).
- **DiskANN 계열**: pgvectorscale **StreamingDiskANN** — 필터 쿼리 + 증분 삽입을 재빌드 없이 지원, SBQ(통계적 이진 양자화)로 노드당 ~5000만 벡터 p95<50ms. Milvus/Qdrant도 DiskANN 제공.

### 1-3. RAG 스키마 설계

| 항목 | 처방 |
|---|---|
| **청킹 전략** | **recursive character split**(문단→문장→단어) 권장 기본. semantic(임베딩 유사도 하락점서 분할)은 정확도 +15~25%지만 연산 3~5배. fixed-size는 경계 무시 |
| **청크 크기** | **256~512 토큰** 스위트스팟(context-heavy는 ~1024). recursive @400~512로 시작 |
| **오버랩** | 청크의 **10~20%(~50~100 토큰)** 슬라이딩 윈도우 — 경계 문맥 손실 방지 |
| **메타데이터** | 청크당 `source_doc_id`, `chunk_index`, `page/section`, `created_at` + 도메인 필터 필드. **하이브리드 필터링**(메타데이터 pre/post-filter + ANN) |
| **원문 연결** | 청크→원본 문서 FK 유지 → 인용(citation)·재조회. 청크는 파생물, 원문이 SoT |
| **재인덱싱** | 변경 문서만 델타 재색인. **IVFFlat은 주기적 전체 재빌드 필요**(중심 표류), HNSW/DiskANN은 증분 삽입 허용 |

- **하이브리드 검색**(dense + sparse): 벡터(의미) + BM25/SPLADE(정확 매칭)를 병렬 검색 후 **RRF(Reciprocal Rank Fusion)**로 융합. `RRF = Σ 1/(k+rank)`, **k=60** 관례(낮추면 top-1 정밀도, 높이면 recall). 고유명사·코드·희귀어에서 순수 벡터의 약점을 메운다.
- **Contextual Retrieval**(Anthropic): 청크마다 LLM 생성 문맥 50~100토큰 prepend 후 임베딩+BM25 → 검색 실패 ~35% 감소(리랭킹 병행 시 ~49%). 코퍼스가 ~200K 토큰(≈500p) 미만이면 RAG 없이 프롬프트 캐싱으로 전체 인입도 고려.

### 1-4. pgvector로 충분 vs 전용 벡터DB

| pgvector(+pgvectorscale)로 충분 | 전용 벡터DB 필요 |
|---|---|
| 이미 Postgres 스택, **~1000만 벡터 이하** | **1억+ 벡터**, 초고 QPS |
| SQL 조인·트랜잭션 일관성과 함께 필터링 | 고급 양자화(PQ/BQ/RaBitQ)·GPU 인덱스 |
| 중간 QPS, 메타데이터 필터가 관계형과 얽힘 | 메모리 비용이 지배적, 관리형 오토스케일 필요 |

- **pgvector 0.8**: HNSW+IVFFlat, `<=>`(cosine)/`<#>`(neg IP)/`<->`(L2). **iterative index scan**(0.8 신규)이 "WHERE 필터 후 결과 부족" 문제를 자동 해결(`hnsw.iterative_scan`). **대부분의 앱은 여기서 끝난다.**
- **전용 선택지**: Pinecone(서버리스 기본, RU/WU 과금), Weaviate(내장 하이브리드+RRF), Milvus(최다 인덱스·RaBitQ 1-bit로 인덱스 1/32·billion-scale), Qdrant(Rust·payload 필터·양자화 32배 압축).
- **과잉 도입**: 벡터 수만~수십만 건인데 전용 벡터DB 세팅 → pgvector로 충분하고 조인까지 공짜. 벤더 성능 주장(pgvectorscale "Pinecone 대비 28배 저지연" 등)은 **벤더 벤치마크**이므로 자체 데이터로 검증.

## 2. 검색 엔진 (Elasticsearch, OpenSearch, Solr, Meilisearch, Typesense)

### 2-1. 역색인 · 매핑 · 애널라이저 · 한국어 형태소

- **역색인(inverted index)**: `단어 → posting list`(정렬된 doc ID + 위치/빈도). 관계형 `LIKE '%...%'`가 전체 스캔인 반면, 역색인은 단어에서 문서로 바로 도달.
- **매핑(mapping = 스키마)**: `text`(분석·토큰화, 전문검색용) vs `keyword`(정확 매칭, 원문 그대로 — 필터·집계·정렬용). 한 필드를 둘 다로 색인하는 multi-field 흔함.
- **애널라이저 = tokenizer + token filter**(색인·검색 양쪽 적용): tokenizer(`standard`/`nori_tokenizer`) → filter 체인(`lowercase`, `stop`, `stemmer`, `synonym_graph`, `asciifolding`).
- **한국어 형태소(Nori)**: 한국어는 띄어쓰기가 단어 경계가 아니므로 표준 토크나이저 부적합. **Nori**(`analysis-nori`, Lucene 내장, mecab-ko-dic 기반)가 표준 처방. `decompound_mode`: `none`/`discard`(기본, 복합어 분해+원형 제거)/`mixed`(분해+원형 유지). `user_dictionary`(신조어·고유명사), `nori_part_of_speech`(조사·어미 제거), `nori_readingform`.

### 2-2. BM25 스코어링 · 샤드/레플리카

- **BM25**(ES v5+ 기본 유사도): **TF 포화**(같은 단어 반복의 수확 체감) + **IDF**(희귀어 가중) + **문서 길이 정규화**(짧은 문서 우대). 파라미터 `k1=1.2`(TF 포화율, 0.5~2.0 튜닝), `b=0.75`(길이 정규화 강도, 0=끔/1=최대).
- **샤드/레플리카**: **primary**(권위본, 생성 시 개수 고정 → 변경은 reindex/split/shrink) + **replica**(사본, 동적 조정 — HA + 읽기 처리량).
  - **샤드 크기**: 목표 **10~50GB/샤드, 50GB 미만 유지**(검색 ~20GB, 로그 ~50GB). ≤ ~2억 doc/샤드.
  - **오버샤딩(anti)**: 작은 샤드 남발 → 힙 낭비(샤드당 클러스터 상태 오버헤드). **힙당 ~20샤드 이하**, **힙 상한 ~31GB**(32GB 넘으면 compressed oops 손실).
- **색인 vs 검색 트레이드오프**: 애널라이저·n-gram·많은 필드는 색인 크기·쓰기 비용↑ 대신 검색 유연성↑. 정확 매칭만 필요하면 `keyword`로 색인 비용 절감.

### 2-3. 제품 선택 & PostgreSQL FTS 경계

| 선택 | 조건 |
|---|---|
| **Elasticsearch / OpenSearch** | 웹스케일 검색, 로그·관측성 분석, 지리공간, 집계, 복잡한 relevance 튜닝 |
| **Meilisearch / Typesense** | instant/오타 허용 search-as-you-type, **~5000만 doc 이하**, 빠른 세팅, JVM 튜닝 회피(Typesense=단일 바이너리·무의존) |
| **PostgreSQL FTS** | 데이터가 이미 PG에 있고 동기화 시스템 회피, 중소 코퍼스, 기본 불리언/구문 |

- **ES vs OpenSearch(라이선스)**: ES는 2021년 Apache 2.0 → SSPL/ELv2, **2024년 AGPLv3 추가**(OSI 승인, "오픈소스" 라벨 복원, 단 네트워크 카피레프트). **OpenSearch**는 AWS가 7.10.2에서 포크한 **순수 Apache 2.0**(2024 Linux Foundation 산하로 이관, 벤더 중립). 관리형 서비스로 제공하거나 제약 없는 오픈소스가 필요하면 OpenSearch. 현재: ES 9.x, OpenSearch 3.x.
- **PostgreSQL FTS로 충분**: `to_tsvector`/`tsquery`/`@@` + **GIN 인덱스**(역색인) + `ts_rank`, `setweight`(A/B/C/D 필드 가중). 수백만 doc 서브초. **전용 검색엔진 필요 시점**: 수천만+ doc·샤딩, 고쓰기 처리량, 고급 relevance(BM25 튜닝·커스텀 애널라이저), 패싯/집계, 오타 허용, 다국어 형태소(Nori), 동의어. (참고: **ParadeDB `pg_search`**가 Postgres 안 BM25로 격차를 좁힘.)
- **SoT → 검색엔진 동기화(CDC)**: **Debezium**(WAL/binlog tail → Kafka → ES sink connector, ms 지연, DELETE·스키마 변경 포착). Logstash JDBC는 폴링·**DELETE 미포착**이라 배치 재색인용. **이중 쓰기 금지** → 앱에서 DB+검색엔진 순차 쓰기는 원자성 없어 부분 실패 시 분기. **Transactional Outbox**: 비즈니스 데이터 + 이벤트를 단일 트랜잭션으로 outbox에 기록 → Debezium이 릴레이(커밋 성공 시에만 발행).

## 3. 시계열 DB (InfluxDB, TimescaleDB, Prometheus, ClickHouse)

### 3-1. 하이퍼테이블 · 청크 · 연속 집계

- **하이퍼테이블 & 청크(TimescaleDB)**: 하이퍼테이블 = 시간으로 자동 파티셔닝된 가상 테이블, 물리 청크(자식 테이블)로 분할. `chunk_time_interval` = 시간 파티션 폭(**기본 7일**). 사이징 규칙: **활성 청크가 RAM의 ~25%에 맞도록**. 선택적 공간/해시 파티셔닝(`add_dimension`)은 주로 멀티디스크 병렬 I/O용 — 과파티셔닝은 오히려 해롭다.
- **연속 집계(Continuous Aggregate, CAgg)**: 구체화 뷰인데 **증분 리프레시** — 새/변경된 time bucket만 재계산. 일반 PG `MATERIALIZED VIEW`는 `REFRESH` 시 **전체 재계산**이라 시계열엔 부적합. `WITH (timescaledb.continuous)` + `time_bucket()`, `add_continuous_aggregate_policy`로 자동화. **계층형 CAgg**(1m→1h→1d) 지원.
- **실시간 집계**: CAgg 결과 = 구체화된 bucket **UNION 아직 미구체화된 최근 원본** → 항상 최신. v2.13+ 기본 `materialized_only=true`(실시간 OFF)이므로 병합 원하면 `false` 설정.

### 3-2. 리텐션 · 다운샘플링 · 압축 · 카디널리티

- **리텐션/다운샘플링**: `drop_chunks(older_than => INTERVAL '7 days')` = 즉시 메타데이터 드롭(`DELETE`보다 압도적으로 싸고 압축 청크에도 동작). `add_retention_policy`로 자동화(**하이퍼테이블당 정책 1개**). **다운샘플링 패턴**: 원본은 짧게 보관 + 롱텀 CAgg로 집계 유지. 드롭 구간이 CAgg 리프레시 오프셋과 겹치지 않게.
- **압축**: 청크별 컬럼형 압축, 비율 **~90~98%**. `compress_segmentby`(유계 그룹 컬럼, 예: `device_id`) + `compress_orderby`(보통 `time DESC`). **Hypercore**(v2.18): 핫 로우는 rowstore, 노후 청크는 자동 columnstore 전환.
- **카디널리티 폭발(tag)**: 고유 ID를 태그/인덱스 차원에 넣으면 시리즈 수가 폭발 → RAM·쿼리 지연이 **스캔 행 수가 아니라 인덱스 크기에 비례**해 붕괴. **완화**: 무계 ID는 인덱스 태그가 아닌 **값(field)**으로. InfluxDB 1.x/2.x의 in-RAM 역색인 문제 → **InfluxDB 3**(Rust 재작성, Apache Arrow+DataFusion+Parquet, 컬럼형·per-series 인메모리 인덱스 제거)가 "무제한 카디널리티" 표방. Prometheus는 스크랩 시 고카디널리티 라벨 drop/relabel.

### 3-3. 제품 선택 — PG로 충분 vs ClickHouse

| 선택 | 조건 |
|---|---|
| **PostgreSQL + TimescaleDB** | 이미 PG, 관계형+시계열 한 시스템, **실시간 소배치 인입**, 중간 규모/카디널리티, 운영 단순성 |
| **ClickHouse** | **OLAP급 볼륨**(수십억 행·TB+), 대규모 집계 스캔, 초고 카디널리티, 전용 분석/관측성 플랫폼 |
| **Prometheus** | 인프라/앱 **모니터링·알림**(범용 TS 스토어 아님). 롱텀은 Thanos/Mimir/VictoriaMetrics로 remote_write |
| **InfluxDB 3** | 전용 시계열·IoT, SQL/InfluxQL, 객체 스토리지 기반 컬럼형 |

- **TimescaleDB vs ClickHouse**: ClickHouse는 고볼륨 집계 처리량 압도하나 **소배치 실시간 인입 약함**(쓰기 버퍼링 ~400ms flush). TimescaleDB는 소배치 실시간 인입 + 저지연 포인트 쿼리 우세. ClickHouse 엔진은 **MergeTree**(Replacing/Aggregating/Summing) + 구체화 뷰(insert-time 트리거) + 시계열 코덱(Delta/DoubleDelta/Gorilla).
- **과잉 도입**: 초당 수천 포인트·중간 카디널리티인데 ClickHouse 클러스터 구축 → TimescaleDB로 충분하고 SQL·조인 유지. 반대로 수십억 행 집계를 TimescaleDB로 억지로 하면 스캔 지옥.

## 4. 그래프 DB (Neo4j, Amazon Neptune, ArangoDB)

### 4-1. 프로퍼티 그래프 모델 · 순회 vs 재귀 조인

- **프로퍼티 그래프**: 노드(1+ 레이블 + 속성), 엣지/관계(방향성, 정확히 1개 타입, weight/timestamp/amount 등 속성 보유). 쿼리 언어 **Cypher/openCypher**(선언형 `(a)-[:REL]->(b)`), **Gremlin**(TinkerPop 명령형), **GQL**(ISO/IEC 39075:2024 — SQL 이후 첫 ISO 쿼리 언어 표준).
- **순회 vs 관계형 재귀 조인**: 관계형 다단계는 `WITH RECURSIVE` CTE / 엣지 테이블 self-join(홉당 1조인). 그래프는 **index-free adjacency** — 각 노드가 인접 노드의 **물리 포인터**를 직접 보유 → **홉당 O(1), 그래프 크기 무관**(앵커 노드만 인덱스 조회). 관계형 조인 비용은 테이블 크기에 따라 증가.
- **관계형이 깨지는 지점**: 재귀 CTE는 중간 결과가 **지수적으로 팽창**, **~3~4홉+**에서 대형/조밀 그래프에서 급격히 저하. 그래프 순회는 홉당 거의 일정.

### 4-2. 언제 그래프DB가 정말 필요한가

| 그래프DB 필요 | 관계형으로 충분 |
|---|---|
| **다단계/가변 길이 순회**, 경로 탐색(최단경로·Dijkstra·A*·도달성) | **1~2홉 조인**, 대부분 테이블형/집계 |
| **추천 엔진**, 사기 링(known-bad에서 N홉), 지식 그래프/GraphRAG | 스타 스키마 리포팅, OLAP |
| 네트워크/IT 토폴로지(의존성·근본원인) | 관계가 부차적인 CRUD |

- **과잉 도입 신호**: 관계가 대부분 1~2홉이고 집계 중심인데 그래프DB 도입 → 관계형/`WITH RECURSIVE`로 충분하고 운영 대상만 늘어난다. **참고**: PostgreSQL **Apache AGE** 확장이 openCypher를 PG에 추가(그래프+SQL 한 DB, 단 깊은 순회는 네이티브 엔진보다 약함) — 얕은 그래프 요구엔 이걸로 충분.

### 4-3. 인덱스 · 슈퍼노드 문제

- **Neo4j 인덱스**(2026.x, CalVer): **RANGE**(기본), **TEXT**, **POINT**(공간), **FULL-TEXT**(Lucene), **VECTOR**(ANN, GraphRAG 핵심), TOKEN LOOKUP. 노드 레이블+속성 및 관계 타입+속성에 적용.
- **슈퍼노드(dense node) 문제**: 관계 수백만 개를 가진 노드 → 순회 시 전부 평가하며 저하. **완화**: Cypher에서 관계 **타입+방향 명시**, **덜 조밀한 쪽에서** 쿼리 시작(슈퍼노드를 관통하지 말고 향하도록), 중간/프록시 노드 도입, 시간/카테고리로 파티션.
- **제품**: **Neo4j**(GDS 65+ 알고리즘 — PageRank·Louvain·Dijkstra·Node2Vec, 벡터 인덱스로 GraphRAG). **Amazon Neptune**(프로퍼티 그래프 Gremlin/openCypher + RDF SPARQL, Neptune Analytics 인메모리+벡터). **ArangoDB**(멀티모델 그래프+문서+KV+벡터, 단일 AQL). **Memgraph**(인메모리·스트리밍·서브ms). 5.26이 마지막 LTS 웨이포인트(스킵 불가).

## 5. 데이터웨어하우스 (Snowflake, BigQuery, Redshift, ClickHouse)

### 5-1. OLAP vs OLTP · 컬럼스토어

| 축 | OLTP | OLAP(DW) |
|---|---|---|
| 워크로드 | 쓰기 중심, 1~few 행 짧은 원자 트랜잭션, sub-50ms | 읽기 중심, 수백만~수십억 행 스캔/집계 |
| 저장 | **행 스토어** | **컬럼 스토어** |
| 정규화 | 3NF | 비정규화(스타/스노우플레이크) |
| 일관성 | 엄격 ACID | 완화 |

- **컬럼스토어가 분석에서 이기는 이유**: **컬럼 프루닝**(참조 컬럼만 읽음), **압축**(동일 타입 컬럼에 dictionary/RLE/delta, ~5~10배), **벡터화/SIMD**(~1000~4000 값 배치), 캐시 지역성 + predicate/partition pushdown. 순효과 분석 쿼리 자릿수 개선.

### 5-2. 모델링 · ELT · 워크로드 격리

- **스타 vs 스노우플레이크**: 스타 = 중앙 팩트 + **비정규화 디멘전**(조인 적음·빠름, 클라우드 DW 선호). 스노우플레이크 = 정규화 디멘전 계층(중복↓·조인↑). **팩트**(정량 measure + FK), **디멘전**(서술 속성). **grain**(행 의미)을 설계 전 선언("주문 라인당 1행"), grain 혼합 금지. 디멘전엔 **surrogate key**(정수 PK, SCD Type 2 필수).
- **ELT(모던 기본)**: Extract → 원본 Load → 웨어하우스 안에서 Transform(**dbt** 표준). **배치 vs 스트리밍** 인입. **Medallion**: Bronze(원본)→Silver(정제)→Gold(집계). 과거 ETL은 로드 전 변환이라 유연성·재처리 약함.
- **OLTP에서 분리하는 이유(워크로드 격리)**: 무거운 스캔이 트랜잭션과 자원 경합(락·캐시 thrashing) → 별도 OLAP를 두고 **CDC로 연결**(single-digit-second 지연). 2025~2026 정설은 융합 HTAP보다 **전용 OLTP + 전용 OLAP over CDC**(Databricks의 Neon, Snowflake의 Crunchy Data 인수가 이 방향을 방증).

### 5-3. 제품 선택

| 제품 | 특성 | 언제 |
|---|---|---|
| **Snowflake** | 스토리지/컴퓨트 분리, 가상 웨어하우스 XS~6XL(초당 과금·60s 최소), 멀티클러스터 동시성 격리 | 범용 클라우드 DW, 팀별 동시성 격리 |
| **BigQuery** | 서버리스(Colossus 스토리지 + Dremel 컴퓨트), Capacitor 컬럼형, slot 과금(온디맨드 ~$6.25/TiB) | spiky/ad-hoc, 무인프라, GCP 네이티브 |
| **Redshift** | 프로비저닝 vs 서버리스(RPU), RA3(컴퓨트+RMS 분리 과금) | steady=프로비저닝, spiky/dev=서버리스, AWS 네이티브 |
| **ClickHouse** | OSS 셀프호스트 컬럼형 OLAP, MergeTree | 실시간 저지연 고처리량 분석, 고객대면 대시보드, 고인입 이벤트 |

- **과잉 도입**: 데이터 수GB·리포팅 몇 개인데 Snowflake/BigQuery 계약 → **read replica + 컬럼형 인덱스**나 로컬 ClickHouse로 충분. 반대로 OLTP DB에서 대형 분석 스캔을 돌리면 트랜잭션 지연·락 경합으로 서비스가 흔들린다(격리 필요 신호).

---

## 상호 참조

- **DB 종류 선택** (관계형 vs NoSQL vs 특수 스토어 결정): [db-selection-guide.md](./db-selection-guide.md)
- **관계형 모델링** (정규화·인덱스·재귀 CTE): [relational-modeling.md](./relational-modeling.md)
- **NoSQL 모델링** (문서·KV·와이드컬럼, CDC/Outbox 동기화): [nosql-modeling.md](./nosql-modeling.md)
- **확장·마이그레이션** (샤딩·복제·무중단 전환): [scaling-migration.md](./scaling-migration.md)
- **스키마 품질 체크리스트**: [schema-quality-checklist.md](./schema-quality-checklist.md)
