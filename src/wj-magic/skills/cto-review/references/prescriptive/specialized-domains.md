# 특수 도메인 아키텍처 카탈로그

> 시계열·그래프·ML/벡터·분석. 핵심 질문: **"언제 Postgres로 충분하고 언제 전용 기술로 넘어가나"**(과잉 방지).
> (이벤트 스트리밍은 event-streaming-messaging.md 참조)

## "Postgres로 충분한가?" 전환선 요약

| 도메인 | Postgres로 충분 | 전용 기술 전환선 |
|--------|----------------|----------------|
| 시계열 | <1M rows/day, BRIN+파티셔닝, 보존<1년 | >1M rows/day, 연속집계, 다운샘플링, 고카디널리티 |
| 그래프 | depth 2-3, <1M 노드, 재귀CTE<500ms | depth 5+, >1M 노드, 그래프 알고리즘, sub-50ms |
| 벡터/ML | <10M 벡터(pgvector), API 직접호출, 모델 1-2개 | >50M 벡터, 멀티모델 피처공유, 자체 모델서빙 |
| 분석 | MV+cron, 쿼리<5초, 소스 1-2개 | 쿼리>5초, 3+소스 JOIN, 프로덕션 영향, >10M events/월 |

## 시계열 (Time-Series)

**트리거**: 일 >1M rows + 1년+ 보존 + sub-second 집계 / IoT 100대+ 매초 / 다운샘플링·연속집계 / 카디널리티 >100K.
**기술**: TimescaleDB(SQL+관계형 JOIN, PG 확장, 바닐라 대비 10-20x) / InfluxDB 3.0(순수 IoT, Parquet, 무제한 카디널리티, JOIN 불가) / QuestDB(초고속+SQL, 금융) / ClickHouse(시계열+분석, 열지향).
**MVP 대체**: Postgres + pg_partman + **BRIN 인덱스**(일<1M rows) / MV+cron(간단 집계) / Prometheus+Grafana(인프라 메트릭).
**안티패턴**: 고카디널리티 태그 폭발(인덱스 메모리), 바닐라 PG에 B-tree 타임스탬프(쓰기마다 재구성-BRIN 써야), 다운샘플링 없이 raw 무기한 보존, TSDB에 OLTP 혼재.
**다운샘플링**: raw 7-30일, 1분/1시간/1일 rollup 무기한. TimescaleDB continuous aggregates + 보존정책.

## 그래프 (Graph)

**트리거**: depth 5+ 순회 반복 / 실시간 최단경로·커뮤니티·PageRank / 엔티티 100+·관계 50+ 지식그래프 / sub-50ms 10+ hop.
**기술**: Neo4j(표준, index-free adjacency O(1)/hop, Cypher, GDS) / Apache AGE(PG 확장 Cypher, 3-4 hop OK 10hop 타임아웃) / **Postgres 재귀CTE**(2-3 hop 수백만행 sub-second) / pgGraph(in-memory CSR, Panama Papers 2M노드 최단경로 4ms, Neo4j 대비 메모리 34x 절약).
**MVP 대체**: 재귀CTE(depth 2-3, 10K노드<10ms), adjacency list+앱레벨 BFS(재귀CTE 47초 걸린 335K노드를 227ms 해결 사례), Apache AGE(Neo4j 전 중간).
**전환선**: 재귀CTE가 depth 3에서 >500ms / 노드>1M+depth 4+가 핵심UX / 그래프 알고리즘이 비즈니스 요구.
**안티패턴**: 모든 데이터를 그래프DB(대부분 JOIN이 효율), 재귀CTE depth 5+(지수비용), 그래프DB에 집계(SUM/GROUP BY 약함), 소규모 소셜에 Neo4j.

## ML / 벡터 / AI

**벡터DB(2026 벤치)**: pgvectorscale(50M 1536d: 471 QPS@99% recall, 10M 이하 전용DB와 동등+) / Qdrant(멀티테넌트 필터·분산) / Pinecone(관리형, pgvectorscale 대비 p95 28x·처리량 16x 열세). **컨센서스: pgvector로 시작, 전환 증거 나올 때만 전용.** HNSW(기본, p99<10ms@5M) / IVFFlat(빌드빠름·메모리효율·recall↓).
**피처스토어**: SQL view(MVP)→MV(user/meal features)→Redis+PG오프라인→Feast(팀 3+ 모델 3+)→Tecton. 1-2명·모델1-2개엔 과잉.
**모델 서빙 런타임**: **vLLM**(단일 LLM 기본, ~20분 배포, continuous batching, 85-95 tok/s@batch8, p95~450ms/H100) → **TensorRT-LLM**(20-40% 처리량↑, AOT 엔진빌드 per 모델·하드웨어·config, 첫 배포 ~1주 엔지니어링, 토큰비용 지배 대규모만) → **Triton**(vLLM/TensorRT + 비LLM 모델(임베딩·비전·분류) 혼합 플릿 단일 API) / BentoML·KServe(패키징·표준 인터페이스 레이어). **배치 vs 온라인**: 사용자 대면 <500ms·입력 예측불가=온라인 / 스케줄 계산 가능(일별 추천·이탈점수)=배치(더 싸고 단순, 서빙 인프라 불필요). MVP: 호스팅 API(OpenAI/Anthropic/Gemini) 또는 서버리스 GPU. **지속 GPU 활용률이 per-token API보다 싸질 때까지 vLLM/Triton 자체호스팅 금지.** 안티패턴: 단일 LLM에 Triton 오버헤드, PMF 전 TensorRT 컴파일, 나이틀리 배치로 충분한데 실시간 서빙.
**MLOps 최소 스택**: 오케스트레이션 + 모델 레지스트리 + 서빙 + 모니터링. MLflow(실험추적+레지스트리, K8s 불필요) 또는 클라우드 네이티브 레지스트리, GitHub Actions CI/CD, Evidently+Prometheus(드리프트). **드리프트는 라벨 전에 proxy(예측분포·피처드리프트)로 며칠~주 먼저 감지.** 트리거: 모델 2+ 프로덕션 / 재학습자 다수 / 배포 재현 불가. 안티패턴: 모델 1개에 Kubeflow 전체 플랫폼, 실험추적 없음(재현 불가), 라벨 정확도 기다리다 드리프트 방치.
**LLM 앱**: 시맨틱 캐싱(비용 73%↓, $47K→$12.7K/월 사례) + 모델 라우팅(간단=Haiku·복잡=Opus) + 가드레일(Portkey) + **Eval 필수**(측정 팀과 안 하는 팀의 품질차 대부분이 측정 여부).
**RAG 프로덕션**: 나이브(chunk-embed-retrieve-stuff)는 불가. **리랭커 최고 ROI**(top-3 precision 12-25p↑, 모델 교체 없이 최대 개선). 청킹이 병목(올바른 청킹 정확도 64%→89%). 하이브리드 검색+sentence window chunking이 2026 시작점.
**MVP 대체**: pgvector+OpenAI API 직접(첫 6개월 충분), SQL MV(피처스토어 대신), Git+스프레드시트(MLflow 대신), API 직접호출(서빙 파이프라인 대신).
**안티패턴**: RAG 정확도 측정 없이 배포, 나이브 청킹(고정 500토큰-문맥파괴), 시맨틱 캐시 임계 과도완화(잘못된 응답), 50M 미만에 Pinecone.

## 분석 / 데이터 (Analytics)

**OLTP/OLAP 분리(2025 컨센서스)**: Databricks의 Neon 인수·Snowflake의 Crunchy 인수 = "OLTP와 OLAP 분리가 정답".
**기술**: ClickHouse(실시간·로그, 100M rows 10-100x, pg_clickhouse drop-in) / BigQuery·Snowflake(페타바이트·거버넌스) / **DuckDB**("analytics의 SQLite", 로컬/CI 무비용, 수GB까지 BigQuery보다 빠름, Parquet/Arrow 네이티브, postgres_scanner로 read replica 직접쿼리-OLTP 영향0).
**ETL/ELT**: dbt+Fivetran("웨어하우스와 데이터늪의 차이는 dbt") / Airbyte(OSS 350+커넥터) / 오케스트레이션 Dagster>Airflow>Prefect.
**이벤트 트래킹**: PostHog(셀프호스팅, 제품분석+세션리플레이+A/B, 무료 1M/월) / Amplitude(SaaS 행동분석) / Segment·Rudderstack(CDP).
**MVP 대체**: PG MV+cron(첫 1년, 리포트 몇 개), DuckDB+Parquet(Snowflake 비용 80%↓ 사례), PostHog 무료(1M events), 스프레드시트+SQL(PMF 전).
**안티패턴**: **프로덕션 DB에서 분석쿼리**(버퍼풀 축출·락경합·WAL부하→장애), pre-seed에 Snowflake(10K events/day에 50-layer dbt 과잉), 이벤트 트래킹 나중에("런치 전 안 하면 영원한 사각지대"), ClickHouse에 OLTP(UPDATE/DELETE 비효율).
