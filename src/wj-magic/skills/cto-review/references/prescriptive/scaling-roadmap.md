# 규모 단계별 진화 로드맵 (1K → 10M 유저)

> "지금은 되는데 사용자 늘면 뭘 해야 하나"의 순서·타이밍. Supabase/Postgres + Next.js 기준.
> 핵심 원칙: **$0 인덱스가 $200/월 compute를 이긴다 — 인프라 전에 쿼리 최적화 먼저.**

## 단계별 진화 테이블

| 유저 | 터지는 병목 | 도입할 것 | 트리거 지표 | 하지 말 것 |
|------|----------|----------|------------|-----------|
| **~1K** | 없음 | 단일 서버(앱+DB), 모니터링 세팅, 인덱스 최적화 | 대시보드만 세팅 | K8s·마이크로서비스·샤딩·멀티리전 |
| **~10K** | DB CPU↑, SPOF, 지연 시작 | 앱-DB 분리, 커넥션풀(Supavisor), CDN, 단일 Redis | DB CPU>50%, p95>500ms, 동시>100 | 샤딩·마이크로서비스·멀티리전 |
| **~100K** | DB 읽기 포화, 앱서버 한계 | LB+앱 2+인스턴스, **Read Replica**, Redis 본격, 비동기 큐 | DB CPU>70%, 읽기 80%+, RPS>1000, 백그라운드>500ms 블로킹 | stateful 앱(세션 로컬), DB 샤딩 |
| **~1M** | 모놀리스 배포병목, DB 쓰기 한계, 글로벌 지연 | 서비스 모듈화, DB 파티셔닝, 메시지큐(Kafka/SQS), 글로벌 CDN | 배포>30분, 테이블>1억행, VACUUM 지연, 해외 TTFB>800ms | 한 번에 마이크로서비스 전환, 강한 일관성 고집 |
| **~10M** | 지리 지연, DB 수직 천장, 서비스 의존성 복잡 | 멀티리전 replica, DB 샤딩(불가피 시), 서비스 분리, rate limit, chaos eng | 16XL 천장($3,730/월), 리전 p99>2s, 단일테이블 수억행+TXID wraparound | 모든 서비스 동시 분리, 글로벌 강한 일관성 |

## 확장 기법별 상세 (언제·왜·주의)

**A. 커넥션 풀링(Supavisor/PgBouncer)**: DB 커넥션이 max_connections 70% 도달 시. 서버리스는 함수당 커넥션 열어 수백 명부터 필요. Supabase 내장(무료), 16코어 400커넥션으로 25만 동시접속. 주의: 세션 vs 트랜잭션 모드(prepared statement는 트랜잭션 모드서 깨질 수 있음). `Direct+Supavisor+PgBouncer ≤ max_connections`.

**B. Read Replica**: DB CPU>70% 지속 + 쿼리최적화 후에도 개선 안 됨 + 읽기 80%+ + 16XL 미만이면 compute 업글이 단순, 16XL이면 replica가 유일 수평옵션. Supavisor 자동 LB(읽기 분산·쓰기 primary). 주의: 복제지연(쓰기 직후 읽기 stale), 쓰기헤비엔 도움 안 됨. 비용: 4XL+2XL replica($1,370) < 8XL 단일($1,870), 고티어서 경제적.

**C. 캐시(Redis)**: 반복 쿼리 패턴 + 응답>200ms. DB 부하 80-90%↓. Read-through 패턴. Next.js 멀티인스턴스는 파일시스템 대신 Redis 필수(인스턴스별 캐시=불일치). 주의: 히트율>90%·응답<1ms 목표, 1MB 이하 엔트리, 풀 API 응답 캐싱은 오히려 느림(전처리 후 캐시).

**D. CDN**: 정적에셋이 대역폭 상당 + 해외 유저 있으면 즉시. CDN ~30ms vs 오리진 ~120ms. Next.js 자체호스팅은 Cache-Control 준수(public/s-maxage/stale-while-revalidate/immutable). 주의: 동적/인증 요청 캐시되면 보안사고(private 필수), ISR 무효화 검증.

**E. 메시지큐/비동기**: 요청 중 500ms+ 작업(이미지·알림·AI) 또는 백그라운드가 API와 CPU/커넥션 경쟁. 10ms 응답+워커 비동기. pgmq+pg_cron(소)→BullMQ(중)→SQS/Kafka(대). 워커를 앱서버에서 분리 배포. 트리거: 큐 depth>1000 5분 지속, 실패>10%, p95>5분.

**F. DB 샤딩**: 수직확장 한계(64코어/512GB도 못 감당) + 파티셔닝으로도 부족. Notion: 480 논리샤드/32 물리DB, workspace_id 파티션, TXID wraparound 위험 시. **조기 샤딩은 최악 안티패턴**(크로스샤드 조인 불가·복잡도 급증·리밸런싱). "250M행에서 파티셔닝이 샤딩의 80% 효과를 20% 고통으로." Postgres 네이티브 파티셔닝 먼저. **16XL($3,730) 도달 전 고려 금지**. 마이그레이션 6개월+.

**G. 멀티리전**: 해외 TTFB>800ms, p99>2s. Read Replica를 타겟 리전 배치→리전별 앱이 로컬 replica 읽기. 주의: "글로벌 집계가 지역 장애를 숨긴다"(리전별 모니터링), 강한 일관성 요구 시 복잡도 급증(CAP), 리전간 쓰기는 eventual consistency.

## "지금 어느 단계인가" 진단 지표

| 지표 | 측정 | 1K | 10K | 100K | 1M+ |
|------|------|----|-----|------|-----|
| DB CPU(user) | Dashboard/pg_stat_activity | <30% | 30-50% | 50-70% | >70% |
| DB 커넥션 | `count(*) pg_stat_activity` | <20 | 20-100 | 100-500 | >500 |
| p95 응답 | APM | <200ms | 200-500 | 500ms-1s | >1s |
| 캐시 히트율 | Redis INFO | N/A | >80% | >90% | >95% |
| 읽기:쓰기 | pg_stat_user_tables | 파악 | 70:30 | 80:20 | 90:10 |
| 최대 테이블 행 | pg_stat_user_tables | <10만 | <100만 | <1000만 | >1억 |

**진단 쿼리**: 느린쿼리 `pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20`, 읽기/쓰기 `seq_scan+idx_scan vs n_tup_*`, 커넥션 `count(*),state FROM pg_stat_activity GROUP BY state`, Seq Scan은 EXPLAIN ANALYZE.

## 조기 도입 안티패턴 (Anti-Slop)

- "Kubernetes Killed Our Startup": 수천 명에 K8s+Service Mesh+GitOps → 기능 대신 인프라에 수개월. **PMF 전엔 PaaS(Vercel/Railway/Fly.io), $10K+ MRR 후 K8s.**
- 1K에 마이크로서비스(팀 3명이 10서비스=운영부채), 1K에 샤딩(감당 못 할 데이터 없음), 10K에 멀티리전(유저 90% 한국이면 CDN으로 충분), 100K 전 Kafka(BullMQ로 충분).
- **공통: 인프라 투자로 유저 확보를 대체하려는 시도.**
