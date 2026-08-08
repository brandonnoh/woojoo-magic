# 서비스 유형별 참조 아키텍처 카탈로그

> 서비스 종류마다 정형화된 청사진: 핵심 엔티티·경계 → 참조 구조 → 유형 특유의 난제 → MVP 시작점 → 확장 경로 → 기술스택.

## 1. SaaS / 멀티테넌트
- **엔티티**: Tenant(격리단위)·User·Subscription·Plan·Role/Permission·Invoice.
- **격리 모델**: Shared DB+RLS(MVP~중, 2026 기본) / Separate Schema(규제) / Separate DB(엔터프라이즈) / **Hybrid(권장: Free/Pro=공유+RLS, Enterprise=전용DB)**.
- **Plan Enforcement**: tenant context→cached entitlements(60s TTL)→atomic quota 예약(Redis INCRBY)→policy gate(block 402/throttle 429/bill). entitlements=`{planId, limits(null=무제한), features}`.
- **난제**: 테넌트 데이터 누출(tenant_id 필터 누락→앱스코핑+RLS 이중방어), 빌링 webhook 역동기화, 다운그레이드 초과리소스(사용자 선택), Plan 하드코딩(`if plan==='pro'` 분산), 스토어 장애 시 fail-open(무제한 허용 위험).
- **MVP→확장**: Shared DB+RLS+Stripe Checkout+3-tier → 사용량 미터링+webhook sync+플래그 → Hybrid DB+ABAC+SOC2 → 멀티리전+커스텀도메인.
- **스택**: PG+RLS, Redis(quota), Stripe/Paddle, WorkOS/Clerk(auth+SSO).

## 2. 이커머스
- **엔티티**: Product/SKU·Cart·Order·Inventory·Payment·Shipment·Customer.
- **모델**: Monolithic(<1K주문/일)→Headless(1K-50K)→Microservices(>10K)→MACH(Enterprise).
- **재고 동시성**: Optimistic(version, 저경합) / Pessimistic(FOR UPDATE, 비권장 병목) / Segmented Locking(bucket, 플래시세일) / Redis Lock(분산) / **Hybrid(권장: 큐 피크완화+Redis 사전차감)**. `UPDATE inventory SET stock=stock-?, version=version+1 WHERE version=? AND stock>=?`.
- **주문 상태머신**: Created→Paid→Processing→Shipped→Delivered (분기 Cancelled/Refunded/Returned).
- **난제**: 재고 동시성(플래시세일 수천 동시차감), 분산 트랜잭션(결제+재고+주문 원자성→Saga), 카트 abandonment(재고 10-15분 TTL), 부분환불/분할배송(OMS 복잡도).
- **MVP→확장**: Monolithic+Stripe+<500 SKU → 검색분리(Algolia)+Redis+CDN+큐 → Headless+OMS분리+재고서비스 → MACH.
- **스택**: PG/MySQL, Redis(cart/inventory), Algolia/ES, Stripe/Adyen, Kafka/RabbitMQ.

## 3. 소셜 / 커뮤니티
- **엔티티**: User/Profile(카운트 비정규화)·Post/Media·Follow(adjacency)·Reaction·Comment·Notification·Block/Mute.
- **피드**: Fan-out on Write/Read/**Hybrid**(일반=push Redis Sorted Set, 셀럽=read-merge, 임계 10K-100K). CQRS(Write=PG+이벤트, Read=Redis Sorted Set 비정규화, Hydration=참조+MGET).
- **알림**: 배치집약("50 likes/1min=1 alert"), APNs+FCM, SSE(피드 stateless)+WS(채팅 stateful). 모더레이션: Pre(동기 텍스트 50-100ms·이미지 200-500ms) + Post(비동기 리포트→휴먼큐). EU DSA/UK OSA로 "launch day부터 필수".
- **미디어**: Presigned→S3직접→큐→썸네일+트랜스코딩+EXIF제거→CDN. "절대 API서버로 프록시 금지".
- **난제**: "100K=DB, 1M=fan-out 전략, 10M=모더레이션". 팔로우 500M 엣지 COUNT 비용>비정규화, 커서 페이지네이션 필수, read-your-own-writes(쓰기 후 500ms primary).
- **MVP→확장**: 프로필+팔로우+시간순피드+좋아요/댓글(PG+Redis+큐) → 푸시+검색+모더레이션(이벤트버스 조기투자) → 트렌딩+Kafka/NATS → 알고리즘 랭킹(데이터 축적 후)+ML 모더레이션+샤딩.
- **스택**: PG+Redis Sorted Sets, Kafka/NATS, ES, S3+CDN, APNs/FCM.

## 4. 마켓플레이스
- **엔티티**: Seller(KYC)·Buyer·Listing(유연스키마)·Order·Escrow·Review(양방향 동시공개)·Dispute.
- **모듈**: Listing&Inventory·Search(Algolia/Typesense)·**Matching**(Browse Etsy/Request Upwork/Real-time Uber)·Payment&Escrow(Stripe Connect+Hold-Release)·Trust&Safety(KYC+모더레이션+Radar)·Dispute·Admin("Day 1부터 필요").
- **에스크로**: Buyer commit→auth→Seller confirm→capture&hold→fulfillment→dispute window→release payout. 환불=커미션 역전.
- **난제**: **Cold Start(닭-달걀)**(지리집중·카테고리집중·단일플레이어기능·파운더 수동매칭·외부공급 임포트), 양면신뢰(KYC+배경조사+AI모더레이션 Day 1), 커미션 로직(프라이싱/정산/환불 전부 의존), 결제인프라(런칭 후 교체 비용 높음).
- **MVP→확장**($120K-300K, 16-28주): 단일 카테고리/지역+Stripe Connect Express+Browse → AI모더레이션+추천+지역확장 → 실시간매칭+동적프라이싱. 단일앱 대비 50-100% 추가비용.
- **스택**: PG+Redis, Stripe Connect/Adyen, Algolia/ES, Checkr(배경), OpenAI Moderation, Stripe Radar.

## 5. 콘텐츠 / 미디어
- **엔티티**: Content·Media Asset(원본+트랜스코딩+DRM)·Catalog·Subscription·User Profile(멀티)·Recommendation.
- **모듈**: Ingestion(Kafka)·Transcoding(per-title encoding 대역폭 40%↓)·Metadata(Headless CMS/Cassandra)·Discovery(ES+추천, 참여 40%↑)·Billing(SVOD 80%/AVOD/TVOD)·Paywall(Metered/Dynamic/Hard/Hybrid)·CDN(Open Connect 모델·ABR HLS/DASH).
- **Netflix 패턴**: API GW(Zuul)·Discovery(Eureka)·Circuit Breaker(Hystrix)·Polyglot(Cassandra/EVCache/MySQL/S3)·하루 수천 배포(immutable+blue/green+canary).
- **난제**: 트랜스코딩 병목(비디오 항상 비동기), 라이브 vs VOD(라이브 실시간 인코딩), DRM 복잡도(Widevine/FairPlay/PlayReady), 콘텐츠비용 vs 추천정밀도.
- **MVP→확장**: Headless CMS+Mux/Cloudflare Stream+Stripe → 자체 트랜스코딩+추천v1+멀티POP → per-title+DRM+동적페이월 → 자체CDN+실시간+AI개인화.
- **스택**: Contentful/Hygraph, Mux/Cloudflare Stream, Cassandra, Redis/EVCache, ES, Kafka, CDN, Stripe.

## 6. 예약 / 스케줄링
- **엔티티**: Property/Resource·Room Type/Slot·**DailyAvailability**(진실의 원천)·Reservation·Pricing Rule·Guest.
- **모듈**: Search&Availability(PostGIS+멀티레이어 캐시 CDN 5-10min+Redis)·Inventory·Reservation(**Two-Phase Hold** 10-15분)·Pricing·Channel Manager(OTA 동기화).
- **상태머신**: PENDING→HELD(10-15min TTL)→CONFIRMED→CHECKED_IN→COMPLETED (분기 EXPIRED/CANCELLED/NO_SHOW).
- **동시성**: Optimistic(version graceful retry) / Pessimistic(FOR UPDATE on DailyAvailability) / 분산락(멀티날짜). 의도적 오버부킹(취소/노쇼 예상 5-10% 마진).
- **난제**: Double Booking(row lock+version), OTA 채널동기화(크로스채널 오버부킹), 멀티날짜 예약(3박=3행 원자잠금), 캐시 vs 정확성(검색=CDN stale, 예약=실시간 DB).
- **MVP→확장**: 단일DB+Optimistic+Stripe → Redis+ES검색+동적프라이싱 → OTA채널매니저+분산락+대기열 → 멀티프로퍼티+ML수요예측.
- **스택**: PG(FOR UPDATE), Redis(캐시+분산락), ES, PostGIS, Stripe/Adyen, CDN.

## 7. 협업 SaaS
- **엔티티**: Workspace/Org(격리)·Project/Channel·Document/Board·Member·Permission(문서단위 ACL)·Presence·Comment.
- **모듈**: Real-time Sync(CRDT/OT)·Presence(커서/온라인/타이핑)·Permission Engine(State Tree+capability 토큰+RBAC+문서 ACL)·Collaboration UI·Notification·Audit&History.
- **CRDT vs OT**: OT(중앙서버 필수, Google Docs) / CRDT(서버 optional·오프라인, Figma/Linear). 라이브러리: Yjs(기본, 26-156K ops/s) / Automerge3(JSON, 메모리 10x↓) / Loro(고성능) / Velt·Liveblocks(관리형).
- **Permission**: State Tree(각 편집에 Capability 서명), 세분화 토큰(comment/edit/propose), 기본 Role+문서 override.
- **난제**: 충돌해결(CRDT 수학적 보장+UI 레이어), 오프라인→온라인 대량 머지, Permission 실시간 반영, Role Explosion(→ABAC), low-level CRDT(수개월) vs 관리형(수일, 벤더종속).
- **MVP→확장**: WS+Yjs+RBAC 3역할+프로젝트 격리 → Presence+인라인코멘트+이력 → 오프라인퍼스트+세분화Permission+SSO → 멀티워크스페이스+감사로그.
- **스택**: Yjs/Automerge, WebSocket, PG, Redis(presence), WorkOS, S3.

## 8. 온디맨드 / O2O
- **엔티티**: Rider·Driver(위치/가용)·Trip·Location(시계열)·Fare/Pricing(서지)·Payment(양측)·Rating.
- **모듈(독립 마이크로서비스)**: Location(WS/Socket.io+Redis GEOADD)·Dispatch(Redis GEORADIUS 수초)·Trip·Pricing(서지 Redis)·Payment·Notification·Analytics.
- **실시간 위치**: Redis Geospatial(GEOADD/GEORADIUS ms) + PostGIS(지오펜싱) + TimescaleDB/InfluxDB(위치 시계열-일반RDB 부적합) + WebSocket.
- **매칭**: NP-Hard(조합최적화), LSH 기반 실시간, 레이턴시 100ms 이내. 서지: 수요신호→Kafka→Pricing→Redis 캐시.
- **난제**: 실시간 매칭 레이턴시(수천 동시+지리클러스터+100ms), 수요예측+플릿효율(대기 15-50%↓), NP-Hard(정확해 vs 빠른근사), 시계열 위치(RDB로 처리하면 붕괴), 양면+관리자 3 프론트엔드.
- **MVP→확장**($80K-300K): 단일도시+GPS매칭+Google Maps+고정요금+Stripe → 서지+예약+애널리틱스 → ML수요예측+동적배차+멀티도시+풀링 → 자체매핑+자율주행.
- **스택**: React Native/Flutter+Mapbox, Node(I/O)+Go(dispatch)+Java(결제), PG+Redis(geo)+Kafka+TimescaleDB, Docker+K8s.
