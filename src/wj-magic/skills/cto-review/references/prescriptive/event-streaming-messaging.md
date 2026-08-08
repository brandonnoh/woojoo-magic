# 이벤트 스트리밍 · 메시징 처방 카탈로그

> 비동기 처리·이벤트 파이프라인·메시지 큐 설계 처방. "언제 Kafka, 언제 Postgres 큐/SQS"의 과잉 방지 판단이 핵심.

## 큐 기술 선택 (가장 먼저 볼 것)

| 기준 | Postgres 큐(pgmq/SKIP LOCKED) | AWS SQS | Kafka |
|------|------|------|------|
| 처리량 | ~1K msg/s (~500KB/s) | ~3K msg/s(표준) | 수십만~수백만 msg/s |
| 운영부담 | 0 (이미 PG 쓰면) | 0 (관리형) | 3+ 브로커 클러스터 |
| 재처리(replay) | 불가(소비 후 삭제) | 불가 | **오프셋 되감기 네이티브** |
| 다중 컨슈머 | 1 워커풀(경쟁) | 큐당 1그룹(SNS fan-out 필요) | **무제한 Consumer Group** |
| 순서보장 | FIFO(FOR UPDATE SKIP LOCKED) | FIFO 큐 옵션 | 파티션 내 보장 |
| 스키마 거버넌스 | 없음 | 없음 | Schema Registry 계약 강제 |

**판단 트리 (과잉 방지):**
1. 메시지 한 번 처리하고 끝(이메일·웹훅·잡)? → **Postgres SKIP LOCKED 또는 SQS**. Kafka 과잉.
2. 같은 데이터를 여러 팀/서비스가 독립 소비(fan-out)? → **Kafka** (본질적 이유). PG로 하면 shared-DB 안티패턴.
3. 과거 이벤트 재처리(이벤트소싱·감사·재계산)? → **Kafka** (불변 로그).
4. 초당 수만 건 이상? → **Kafka** (파티션 선형 확장). 수천 이하면 PG/SQS.
5. 데이터가 비즈니스 자산인가 단순 작업지시인가? 자산→Kafka, 작업지시→SQS/PG큐.

> 원칙: "아키텍처를 지루하게 유지". 시작은 PG큐/SQS. Kafka 승격 시점은 **다중팀 fan-out · 재처리 · 초고처리량** 중 하나가 현실 요구가 될 때.
> 정석 결합: **Postgres + Debezium CDC → Kafka**. 트랜잭션은 PG, 변경이벤트는 Kafka로 스트리밍(shared-DB 깨는 표준).
> MVP 대체: `pg_notify`/LISTEN은 최적화 시 60K/s 가능하나 순수 NOTIFY는 글로벌 락으로 ~2.9K/s 병목. Postgres SKIP LOCKED 큐는 4vCPU에서 ~2,885 msg/s, append-only라 MVCC bloat 없음.

## Kafka 핵심 개념 (Top 12 + 5)

| # | 개념 | 정의 | 안티패턴 | 핵심 config |
|---|------|------|----------|------------|
| 1 | **Topic** | 이벤트 스트림 논리 채널(불변 append-only 로그, 큐 아님) | catch-all 단일 토픽 | `auto.create.topics.enable=false`, 네이밍 `<domain>.<entity>.<event>` |
| 2 | **Partition** | 토픽 물리 분할 = 병렬성/순서 단위. 파티션 **내부**만 순서 보장 | 파티션 과다(브로커 힙·컨트롤러 CPU·리밸런싱 지연) / 과소(나중에 늘리면 키매핑 깨짐) | `num.partitions`=max(처리량/파티션처리량, 컨슈머수) |
| 3 | **Producer** | 발행 클라이언트. 파티셔닝·배치·재시도 | `linger.ms=0`(네트워크 폭증) / `acks=all`+`min.insync=1`(실질 acks=1) | `acks=all`, `linger.ms=5~10`, `compression=zstd`, `enable.idempotence=true` |
| 4 | **Consumer Group** | `group.id` 공유 집합. 파티션당 그룹 내 1 컨슈머. 독립 그룹=fan-out | poll 루프 내 무거운 처리→리밸런싱 폭풍 / 컨슈머>파티션(유휴) | `max.poll.interval.ms`, `session.timeout.ms`, `heartbeat=session/3` |
| 5 | **Offset** | 파티션 내 레코드 순번(책갈피). 커밋 전략=전달보장 | auto.commit True로 처리중 유실 / 영향 모르고 `--to-earliest` 되감기 | `enable.auto.commit=false`+수동커밋, `auto.offset.reset` |
| 6 | **Broker/Cluster** | Kafka 서버/3+ 집합. 최소 3대(1대 장애 허용) | 여러 브로커 동시 내림→`min.insync` 위반 쓰기불가 | `unclean.leader.election.enable=false` |
| 7 | **Replication/ISR** | 파티션 복제 + 동기화된 복제본 집합. `RF=3`+`min.insync=2`=1대 장애 허용 | ISR flapping(복제 부채) / min.insync=RF(1대만 죽어도 쓰기불가) | `replication.factor=3`, `min.insync.replicas=2` |
| 8 | **Retention/Compaction** | 시간·크기 후 삭제 / 키별 최신값만 유지 | `retention.ms=-1` 디스크폭발 / 너무 짧아 `OffsetOutOfRange` | `retention.ms`(기본 7일), `cleanup.policy=delete\|compact` |
| 9 | **Partition Key** | `hash(key)%파티션수`로 라우팅. 같은 키=같은 파티션=순서 | 핫 파티션(대형 키 편중) / UUID 키(사실상 랜덤, 엔티티 순서 깨짐) | `partitioner.class`, 비즈니스 키(orderId/userId) 사용 |
| 10 | **Rebalancing** | 그룹 멤버십 변경 시 파티션 재할당 | Eager(stop-the-world) / max.poll 초과로 정상 컨슈머 퇴출 | `CooperativeStickyAssignor`, `group.instance.id`(static membership), KIP-848(서버사이드, Kafka4.0) |
| 11 | **Exactly-Once(EOS)** | 멱등 프로듀서(PID+seq) + 트랜잭션. read-process-write 원자화 | 불필요한 곳에 EOS(처리량 10-20%↓) / transactional.id 중복→zombie fencing | `transactional.id`(인스턴스 고유), `isolation.level=read_committed`, Streams `processing.guarantee=exactly_once_v2` |
| 12 | **KRaft** | Kafka 자체 Raft 메타데이터(ZooKeeper 4.0서 완전 제거) | ZK 유지하며 4.0 업글 시도(불가) | `process.roles=broker,controller`, 컨트롤러 홀수(3/5) |
| 13 | **Schema Registry** | Avro/Protobuf 스키마 중앙관리 + 호환성 강제(계약) | BACKWARD 모드서 필드삭제→구 컨슈머 크래시 | 호환성 BACKWARD 기본 |
| 14 | **Kafka Connect** | 외부↔Kafka 스트리밍 프레임워크(Source/Sink). Debezium CDC | DLQ 미설정 | `errors.tolerance=all`+`errors.deadletterqueue.topic.name` |
| 15 | **Kafka Streams** | Kafka-to-Kafka 스트림 처리 **라이브러리**(별도 클러스터 불필요). KStream(INSERT)/KTable(UPDATE) | 대규모 stateful·다중소스 조인은 Flink가 적합 | RocksDB 상태저장 |
| 16 | **Dead Letter Topic** | 처리 실패 격리 토픽. 재시도→한도초과→DLT | DLT 방치(수개월 뒤 발견) | 체류시간(oldest age)이 depth보다 나은 SLO 지표 |
| 17 | **Consumer Lag** | 최신 오프셋 − 커밋 오프셋. 계속 증가=못 따라감→retention 삭제로 유실 | lag 알림 없이 운영 / lag=0인데 처리량0(프로듀서도 멈춤) | 시간기반 lag(SLO), Burrow/Datadog |

## 스트림 처리 엔진 선택
- **Kafka Streams**: Kafka-only 소스/싱크, 마이크로서비스 임베드, 별도 클러스터 불필요.
- **Flink**: 멀티소스, 복잡 CEP, 배치+스트림 통합. 별도 클러스터.
- **CDC(Debezium)**: WAL 기반 DB변경 스트리밍. dual-write 문제 근본 해결. Debezium Server(Quarkus)로 Kafka 없이도 가능.

## 브로커 기술 선택
- **Kafka(KRaft)**: 기업 백본, Connect 커넥터 200+, 멀티팀. 4.0서 ZK 제거로 운영 40%↓.
- **Redpanda**: C++ thread-per-core(GC 없음), 저지연, Kafka API 호환, 단일 바이너리.
- **Kinesis**: AWS 올인+관리형 필수+처리량 <수십MB/s. 샤드 과금이라 대규모 비쌈.

**안티패턴 통계**: Kafka 운영의 55%가 1MB/s 미만(벤더 자체 보고) — 대부분 과잉. Event Sourcing+CQRS 동시 도입 금물(CQRS는 ES 없이도 성립, 특정 bounded context에만 선택 적용).
