# 기능 유형별 아키텍처 처방 카탈로그

> "이 기능을 만들 때 어떤 구조가 최적인가"의 청사진. 각 케이스: 언제 → 최적구조 → 안티패턴 → 기술선택 → 규모진화(MVP→대규모).
> 공통 원칙: **대부분 Postgres/Supabase로 시작하고, 전용 기술은 구체적 병목이 증명될 때만.**

## A. 실시간 (Real-time)

**전송 프로토콜 선택**: 기본값 **SSE**(단방향: 알림·피드·LLM 스트리밍, HTTP/2 멀티플렉싱). 양방향 빈번(채팅·게임·협업)만 **WebSocket**. Long Polling은 폴백 전용. WebTransport는 시기상조.

**실시간 서비스**: Supabase Realtime(MVP, 500~10K 동시) → Centrifugo 셀프호스트/Ably(10K+). Pusher는 일일 캡 주의.
- `postgres_changes`=영구 상태변경(메시지), `broadcast`=휘발성(타이핑·커서), `presence`=온라인(채널당 100명 제한).
- ⚠️ Supabase Realtime 함정: postgres_changes 싱글스레드 병목(1000+ ins/s 과부하), 구독자당 RLS N배 읽기, `removeChannel` 누락→500 커넥션 소진, presence stale(visibilitychange re-track 필수).

**1:1/그룹 채팅**: `conversations`+`conversation_members`+`messages(client_generated_id 멱등)`. persist(write-ahead)→큐(partition by conversation_id 순서보장)→WS 전달→오프라인은 push fallback. 읽음=last_read_at+broadcast, 주기 batch. 안티패턴: DB 저장 없이 WS만(재시작 유실), 전체 본문 broadcast. 진화: postgres_changes(소규모)→broadcast 분리→Centrifugo+Kafka+Cassandra(10K+).

**실시간 알림**: 5계층(수집→fan-out/라우팅→채널 디스패처→인박스 저장→추적). 우선순위 4단(Critical 즉시 멀티채널/High WS+10s push fallback/Medium 배칭/Low 이메일). 배칭("12개 새 댓글">12개 개별), quiet hours 큐잉, 과부하 시 low 먼저 shed. 상태머신 CREATED→QUEUED→SENT→DELIVERED→READ. 진화: postgres_changes+FCM(동기 OK)→Bull 큐+채널워커→Kafka+독립 디스패처/Novu·OneSignal.

**프레즌스**: Redis Hash `presence:{ch}` TTL 60s+하트비트. 200ms 디바운스·최대 5회/s. 안티패턴: DB 저장(쓰기폭증), visibilitychange 미처리(유령). 진화: Supabase Presence(≤100)→Redis TTL→전용(Centrifugo).

**협업 커서/공동편집**: 커서만=broadcast 200ms 디바운스(DB 저장 X). 편집=CRDT(신규 기본)>OT(중앙서버 기존). 라이브러리: **Yjs**(프로덕션 기본, 18KB, Tiptap/Hocuspocus 에코시스템) / Automerge(Git-like 히스토리, 320KB) / Loro(최고성능, 에코시스템 미성숙). 서버: Hocuspocus4+DB영속 / Y-Sweet+S3 / Liveblocks(관리형). ⚠️ Supabase Realtime을 CRDT 전송계층으로 쓰지 말 것(순서보장 없음). y-supabase는 프로덕션 비권장.

## B. 피드/타임라인

**Fan-out 전략**: Push(on-write, 팔로워수 쓰기·O(1)읽기) vs Pull(on-read, O(1)쓰기·머지읽기) vs **Hybrid(정석)**. 분기점 ~10K 팔로워: <10K push, 셀럽(≥10K) read-merge, 비활성(30일) fan-out 스킵. 셀럽 문제: Katy Perry 8천만 동시쓰기→하이브리드로 해결.
- 3계층: 불변 이벤트 캡처(Kafka emit)→서빙뷰(사전물질화/조립)→하이드레이션(ID만 저장, 서빙 시 batch fetch).
- 기술: 타임라인=Redis Sorted Set/Cassandra, 소셜그래프=샤딩 adjacency list(그래프DB 아님), 실시간=SSE.
- 안티패턴: 그래프DB를 타임라인 스토어로(정렬리스트 조회 느림), 타임라인에 풀오브젝트 저장, 개별 하이드레이션(N+1→dataloader).
- 진화: PG만(팔로잉 IN 쿼리, ~1K)→MV/Redis Sorted Set+push(~100K)→Kafka+Redis+Cassandra 하이브리드(1M+).

**랭킹 피드**: 4단 파이프라인(후보생성→프리랭킹 경량→헤비랭커 ML→리랭킹 다양성/정책). MVP는 ML 없이 SQL 점수공식(좋아요×3+댓글×5+조회×0.1)/(age_h+2)^1.5. 진화: SQL+MV→Redis Sorted Set 사전계산(1~5분)→Feature Store+ML 실시간추론.

**무한스크롤**: **Keyset/커서**(`WHERE (created_at,id)<(cursor) LIMIT n`+복합인덱스). OFFSET 금지(10만행+ 초단위 지연·중복/누락). 커서=base64(created_at,id). COUNT(*) 제공 시도 금지(풀스캔). 진화: 커서로 시작(마이그레이션 비용0)→복합커서(score,created_at,id)→Redis ZRANGEBYSCORE.

## C. 검색

**단계 진화**: Postgres FTS(tsvector+GIN, MVP)→+pg_trgm(자동완성/오타)→PGroonga(한국어 형태소, Supabase 확장)→Meilisearch(한국어+오타+자동완성)→Elasticsearch+Nori(수십억).
- 한국어: `'english'`/`'korean'`(없음) 금지. PGroonga `&@~` 또는 mecab(textsearch_ko, 셀프호스트) 또는 Meilisearch(사전기반). Typesense는 CJK 약함.
- 자동완성: debounce 150-300ms + pg_trgm(`title % '치킨'`) → Meilisearch search-as-you-type.
- 하이브리드(키워드+시맨틱): Supabase RRF(Reciprocal Rank Fusion) SQL 함수, FTS+pgvector 결합. Phase 3+, 콘텐츠 1만+.
- **전용 검색엔진 비교(한국어 관점)**: **Elasticsearch/OpenSearch**(Nori 형태소분석 = 한국어 최상, 복합어분해·한자변환·사용자사전; 운영부담 큼 JVM클러스터 노드당 4-16GB·3노드 HA; Elastic Cloud $99+/월; 페타바이트급) / **Meilisearch**(MIT, 셀프호스팅 최쉬움 Docker단일·$6-15/월 VPS, 한국어 중간(Charabia 공백기반, Nori보다 열등), 제로설정 오타허용(단 한국어선 비활성 보고), p50 12-20ms, Cloud $30/월) / **Typesense**(GPL-3 상용주의, C++ 인메모리 최고속 p50~5ms·p99~20ms, 한국어 최하(외부토크나이저 필요), Raft HA 오픈소스 포함, Cloud $7/월). **소규모 한국어=Meilisearch 균형점, 최고품질=ES+Nori, 최고속도=Typesense(단 한국어 약점).** 동기화: PGSync/Debezium CDC(WAL→엔진).
- **한국어 FTS 벤치**: MeCab기반 PostgreSQL RRF 하이브리드 MIRACL NDCG **0.77·p50 1.79ms** > ES 8.17 하이브리드 NDCG 0.75·p50 5.18ms — PG가 DB내부 RRF로 네트워크 제거해 2-5배 빠름. textsearch_ko(MeCab, NDCG 0.64, ES Nori 동등; **C확장이라 Supabase Cloud 불가·셀프호스트만**). Supabase Cloud는 **PGroonga만** 가능(`CREATE EXTENSION pgroonga`, `&@~`). FTS 성능: 1M행 GIN 인덱스 13.8초→39ms(99.7%↓). Supabase 내장 gte-small 임베딩은 영어전용→한국어는 bge-m3/multilingual-e5-large 외부 임베딩.
- 안티패턴: `LIKE '%kw%'`(GIN 무시 풀스캔), tsvector 컬럼 없이 매 쿼리 to_tsvector, 검색 로그 미수집(제로결과 = 콘텐츠 갭 발견 핵심).

**벡터 검색**: pgvector HNSW(≤2M, Supabase $25) → 튜닝(2M) → Qdrant 셀프호스트/Pinecone 서버리스(2M~5M) → 필수(5M+, pgvector p95 80-140ms). 2M 이하에서 Pinecone은 과잉(3-8x 비용). HNSW `ef_search` 튜닝, 관계형 조인 필요하면 pgvector(단일 DB).

## D. 추천/랭킹

**단계**: 규칙기반 SQL(0-100명, 같은끼니/주수/인기)→Item-based CF(500명+·상호작용 5K+, MV 야간배치 co-like 코사인)→Switching Hybrid(1K+, 신규=콘텐츠·기존=CF70%+콘텐츠30%)→Two-Tower+Feature Store(50K+).
- 인기/트렌딩: HN `(votes-1)/(age_h+2)^1.8` / Reddit log스케일 / Wilson score(신뢰구간) / **지수감쇠**(`e^(rate*t_like)`, 좋아요 시에만 행 업데이트-전체 재계산 불필요, 가장 효율적).
- 안티패턴: 100명 미만에 ML(데이터부족), 매 요청 실시간 계산(MV 미활용), 다양성 없는 순수 점수(한 작성자 독점), 콜드스타트 무시.
- 피처스토어: SQL view(MVP)→MV(user_features)→Redis+PG오프라인→Feast(팀 10명+)→Tecton. 1000명 미만 Feast는 과잉.
- A/B: 로깅만(<1K DAU)→PostHog/GrowthBook(1K-10K)→Statsig(10K+). CTR만 보지 말고 다양성·리텐션.

## E. 결제/정산 (정합성 최우선)

**단건 결제**: 클라 멱등성키(UUID)→서버 DB UNIQUE→상태머신(Created→Authorized→Captured→Settled). Webhook: `verify→enqueue→ACK(200,<5s)`, 실제작업 비동기. PCI: Stripe Elements로 카드가 서버 미경유(범위 축소).
- ⚠️ 치명 안티패턴: **서버에서 멱등성키 생성**(재시도 시 새 키→중복방지 무력화), Check-then-Act 레이스(`SELECT FOR UPDATE`/version 필수), **멱등키를 Redis 별도 저장**(PG 커밋 전 에러→TTL만료→이중결제; 멱등키 INSERT와 비즈니스로직 같은 트랜잭션), webhook 서명 미검증, 동기 webhook(타임아웃 재시도 폭주).
- PG 선택: Stripe(글로벌, 한국결제수단X) / 토스페이먼츠(한국 전 수단) / 포트원V2(멀티PG, Idempotency-Key 헤더).

**구독**: PG가 invoice/renewal/proration/dunning 관리, 앱DB는 plan/entitlement/feature flag. Smart Retry(15-40% 복구), grace period 7-14일. 필수 webhook: invoice.paid/payment_failed/upcoming/subscription.updated. 안티패턴: 구독상태 앱DB만 관리(drift→유료가 무료로), dunning 직접 구현, proration 수동계산.

**복식부기 원장**: append-only journal_entries + accounts. SUM(debits)=SUM(credits) 불변식. 잔액=SUM(entries)(mutable balance 컬럼 금지-레이스). 다중 엔트리 단일 트랜잭션. 환불=reversing entry. 정수(센트)/DECIMAL(부동소수점 금지). 기술: PG 커스텀(초중기)→TigerBeetle(대규모)/Temporal/Lago.

**Saga/보상**: Compensable→Pivot(go/no-go)→Retryable. Transactional Outbox(비즈니스+이벤트 같은 트랜잭션→릴레이 발행). Fail-closed(결제확인 실패 시 거부가 안전). 기술: Temporal/Inngest(Next.js)/Trigger.dev/직접(Outbox+cron).

## F. 파일/미디어

**Presigned 직접업로드**: 서버 검증(크기/MIME magic bytes/quota)→presigned URL(TTL 5-15분)→클라 PUT 직접→완료확인 후 DB. 서버 바이패스(메모리/대역폭 병목 제거). 안티패턴: 서버경유(formData Server Action→OOM), 무기한 URL, 클라 MIME 신뢰, 완료확인 없이 DB기록. 기술: Supabase Storage/S3+CloudFront/R2/Uploadthing.

**청크/재개(50MB+)**: TUS 프로토콜(Supabase Storage 6MB 청크 고정, 50GB까지). tus-js-client/Uppy, retryDelays, findPreviousUploads. 안티패턴: 단일 PUT 대용량(끊기면 처음부터), 서버 메모리 버퍼링, 재개 미구현.

**비동기 후처리**: Storage 이벤트/DB트리거→큐(Inngest/Trigger.dev/BullMQ)→썸네일(sharp)/AI분석/트랜스코딩. 상태추적(pending→processing→completed→failed)+Realtime UI. ⚠️ Supabase `after()`에서 일반 클라이언트 쓰면 auth.uid()=null → `createServiceClient()` 필수. 무한루프(bucket_id 체크). 기술: Edge Function(경량<60s)→Inngest/Trigger.dev→BullMQ+워커/AWS MediaConvert.

**이미지 CDN**: 사전생성(sharp thumb/display, 런타임비용0) vs 온디맨드(원본만, 무한변형·포맷협상) vs 하이브리드. 기술: Cloudflare Images/imgproxy(셀프, 고볼륨)/Vercel Image/Supabase Transform(극소량). `format=auto`(AVIF/WebP), 허용 파라미터만(cache bust 공격 방지).

**동영상 HLS/DASH**: 업로드→트랜스코딩(Mux/MediaConvert/FFmpeg)→ABR 래더(240/480/720/1080)→CMAF(HLS+DASH 동시, 비용 절반)→CDN→hls.js. 안티패턴: 서버 직접 스트리밍(CDN 캐싱 불가), 단일 해상도, Lambda 장시간 트랜스코딩(15분 제한), HLS/DASH 분리인코딩. 기술: Mux(빠른출시, per-title encoding)/Cloudflare Stream/자체 FFmpeg(ECS 대규모).

## G. 알림 발송 (위 A 실시간 알림과 연계)

멀티채널 5계층. 채널별 독립 큐 격리(이메일 SMTP 타임아웃이 푸시 막으면 안 됨). FCM: 1분 600K Quota, 5-10분 분산 발송, 점진 증가(1%→100%). 재시도: 429(retry-after)/500(지수백오프+지터)/4xx(즉시중단). 무효토큰 정리(410). 선호도 엔진 5단 체크(카테고리/채널/조용시간/rate/필수오버라이드). 채널 폴백(푸시 실패→SMS 에스컬레이션)+DLQ. 기술: pgmq+pg_cron+Edge(0-10K)→Novu/QStash→Kafka 자체.

## H. 지도/위치

**근접검색**: PostGIS `geography(Point,4326)`+GiST 인덱스+`ST_DWithin`. KNN `<->`. geometry(평면,빠름,왜곡) vs geography(구면,정확,느림). 도시규모 geometry OK, 글로벌 geography. 안티패턴: GiST 없이 ST_DWithin(풀스캔). 진화: PostGIS(0-100K POI)→geohash 프리필터+ST_DWithin(100K-10M)→H3/S2+PostGIS(10M+).
**공간인덱싱**: Geohash(직사각형, Redis GEO) / S2(구면 사각형, Google) / **H3**(육각형, 이웃탐색 최적, Uber, h3-pg). 하이브리드: H3/geohash 프리필터(O(1))→PostGIS 정밀.
**실시간 추적/지오펜싱**: GPS(3-5s)→WS/MQTT→PostGIS/Redis GEORADIUS→상태머신(Outside/Enter/Inside/Exit/Dwell)+히스테리시스 디바운싱→FCM/WS. 목표 5초 이내. 안티패턴: HTTP 폴링(WS/MQTT 필수), GPS 최대빈도(배터리; OS significant-change), 디바운싱 없음(enter/exit 반복). 진화: Supabase Broadcast+PostGIS(<50K)→Socket.io+Redis→MQTT(EMQX)+Kafka+H3.

## I. 백그라운드 작업 / 크론

**큐 선택**: pgmq(Supabase 네이티브, 0-10K/일) → pg-boss/QStash(10K-100K) → BullMQ+Redis(100K+) → Inngest/Temporal(복잡 워크플로우). ACID 필요=pg-boss/pgmq, 우선순위/DAG=BullMQ/Inngest.
**멱등 처리**: 3계층(제출 시 dedup job_id UNIQUE / 원자적 클레임 BLMOVE·SKIP LOCKED / 멱등키 TTL 기록). Exactly-once=at-least-once+멱등처리(브로커 강제 불가능). 비가역 부작용=Transactional Outbox.
**스케줄러**: pg_cron+pg_net(Supabase) / BullMQ repeat. 안티패턴: setInterval(재시작 유실), jobId 미지정(중복등록), 동시실행 방지 미흡.
**Supabase 3계층**: 수집(pg_cron→Edge 큐적재)→분배(유형별 큐 라우팅)→처리(단일아이템, 타임아웃 내). try/finally 완료표시(무한재시도 방지), 가시성 타임아웃>작업시간.
모니터링: P95/P99, 큐 depth×나이, DLQ depth(1차 실패지표), 재시도 스파이크, 크론 하트비트 갭.
