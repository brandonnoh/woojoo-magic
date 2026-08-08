# 아키텍처 스타일 결정 카탈로그

> 11대 아키텍처 스타일 + "언제 무엇을" 결정 트리. 출처: Fundamentals of Software Architecture(Richards/Ford), Software Architecture Patterns.
> 점수: 5=최고, 1=최저 (비용은 5=저비용/좋음). 바이브코딩 MVP의 진화 관점.

## 종합 비교 매트릭스

| 스타일 | 확장성 | 탄력성 | 배포용이 | 테스트 | 단순성 | 비용 | 성능 | 민첩성 | 적정 팀 |
|--------|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|--------|
| **Layered(N-tier)** | 1 | 1 | 1 | 4 | 5 | 5 | 2 | 1 | 1-5 |
| **Modular Monolith** | 2 | 1 | 3 | 4 | 4 | 5 | 4 | 3 | 5-30 |
| **Pipeline** | 1 | 1 | 2 | 3 | 5 | 5 | 3 | 2 | 1-5 |
| **Microkernel(Plugin)** | 1 | 1 | 4 | 4 | 5 | 5 | 4 | 4 | 3-15 |
| **Service-Based** | 3 | 2 | 4 | 4 | 4 | 4 | 3 | 4 | 10-30 |
| **Event-Driven** | 5 | 5 | 4 | 1 | 1 | 3 | 5 | 5 | 10-50+ |
| **Space-Based** | 5 | 5 | 4 | 1 | 1 | 1 | 5 | 5 | 20+ |
| **Microservices** | 5 | 5 | 5 | 4 | 1 | 1 | 2 | 5 | 50+ |
| **Serverless/FaaS** | 5 | 5 | 5 | 2 | 3 | 가변 | 3 | 4 | 1-20 |
| **CQRS** | 4 | 3 | 3 | 3 | 1 | 2 | 4 | 3 | 10+ |
| **Event Sourcing** | 4 | 3 | 3 | 2 | 1 | 2 | 3 | 3 | 10+ |

## 스타일별 요약

- **Layered**: 기술관심사 수평계층, 아래만 호출. MVP·CRUD·1-5명. 회피: 독립배포/스케일 필요. 함정: Architecture Sinkhole(로직 없이 계층만 통과). 예: WordPress.
- **Modular Monolith**: 단일 배포+강한 모듈경계. 5-30명, ACID 유지, 마이크로서비스 전 단계. **2025 트렌드: Shopify·Amazon Prime Video가 마이크로서비스→모듈러 회귀(비용 90%↓)**. "마이크로서비스는 조직 문제를 풀지 기술 문제를 풀지 않는다."
- **Pipeline**: 순차 필터 변환. ETL·스트림·문서변환. 단순·저비용. 회피: 비선형/분기 복잡. 예: Kafka 파이프라인, Unix 파이프.
- **Microkernel**: 최소 코어+플러그인. 제품형(IDE/브라우저/CMS), 커스터마이제이션. 예: VS Code, Jenkins, WordPress 플러그인.
- **Service-Based**: 4-12 굵은 서비스+공유DB. "마이크로서비스 라이트"(80% 이점/20% 복잡도), ACID 유지. 10-30명.
- **Event-Driven**: 비동기 이벤트(Broker 단순전달/Mediator 워크플로우). 고처리량·실시간·느슨한결합. 회피: 강한 일관성 필수, 단순 CRUD. 테스트 어려움. 예: Amazon 주문, Uber 매칭.
- **Space-Based**: 인메모리 그리드 복제+비동기 DB. 예측불가 폭주(티켓팅·경매·flash sale), 밀리초. 최고 비용/복잡도. 예: Hazelcast/Ignite.
- **Microservices**: 서비스별 자체DB+독립배포. 50명+, DevOps 성숙, 기술다양성. 회피: 30명 미만(운영오버헤드>이점), 지연민감(네트워크 홉). 함정: 분산 모놀리스. 예: Netflix 700+.
- **Serverless/FaaS**: 관리형 stateless 함수, 사용량 과금. 이벤트 비동기, 변동 극심, 비용최적. 회피: 지연민감(cold start), 장기실행(15분), stateful. 예: Lambda+API GW, Cloudflare Workers.
- **CQRS**: 읽기/쓰기 모델 분리. Read:Write 극단 비대칭, 협업 동시수정. 회피: 단순 CRUD. 예: 트레이딩, 호텔예약.
- **Event Sourcing**: 상태를 불변 이벤트 로그로. 완전 감사추적(금융/의료), 시간여행. 함정: 스키마 진화(upcaster), 이벤트 루프, 리플레이 성능(스냅샷). CQRS와 자주 결합하되 **분리 판단**(CQRS는 ES 없이 성립).

## 결정 트리 (팀규모 × 제품단계)

```
1-5명, MVP/PMF 검증:
  데이터 파이프라인? → Pipeline
  플러그인 확장형 제품? → Microkernel
  이벤트 비동기만? → Serverless/FaaS
  그 외(웹앱/SaaS) → Layered Monolith  ["PMF까지 가장 빠른 구조"]

5-15명, PMF 후 성장:
  배포 경합 발생? → Modular Monolith  ["도메인을 모듈로, 분산운영 역량은 아직 없다"]
  트래픽 스파이크 핵심? → Serverless(이벤트) + Modular Monolith(코어)
  특정 도메인만 독립배포? → Service-Based(4-12)

15-50명, 스케일업:
  읽기/쓰기 극단 비대칭? → CQRS
  감사추적/시간여행 법적필수? → Event Sourcing + CQRS
  실시간 반응성 핵심? → Event-Driven
  도메인팀 독립배포+DevOps 성숙? → Microservices  (미성숙? → Service-Based)
  예측불가 동시접속 폭주? → Space-Based

50명+, 대규모:
  기본 Microservices + 필요 시 Event-Driven/CQRS/ES 결합
  ["이 규모에선 조직구조가 아키텍처를 결정한다 — Conway's Law"]
```

## 진화 경로: 모놀리스 → 모듈러 → 마이크로서비스

```
Phase 1 Layered Monolith (0-5명, 0-12개월) "빠르게 빌드, PMF 검증"
  전환 신호: 배포 충돌 / 단일 변경에 전체 재테스트 / 코드 10만줄+
Phase 2 Modular Monolith (5-30명, 12-36개월) "도메인 경계를 코드로 강제" + Strangler Fig
  전환 신호: 특정 모듈만 10x 트래픽 / 모듈별 다른 배포주기 / 팀 30명+ / DevOps 성숙
Phase 3 Service-Based (10-50명, 대안) "공유DB로 ACID 유지"
Phase 4 Microservices (50명+, 36개월+) "서비스별 DB+파이프라인" + Saga
```

**핵심 원칙:**
1. 미래를 위해 과잉설계 말라. 현재 필요에 맞추되 진화 경로를 남겨라.
2. 마이크로서비스는 조직 문제 해결. 10명 미만은 모놀리스가 더 빠르다.
3. 가장 위험한 실수 = **분산 모놀리스**(마이크로서비스 운영복잡도 + 모놀리스 결합도).
4. Strangler Fig는 마이크로서비스 전용 아니라 "어떤 목표든" 점진 이행 전략.
5. DB 분리가 가장 어렵다 — "로직 분해는 쉽고, DB에서 마이그레이션이 멈춘다."
6. **과잉 분리(over-engineering)도 안티패턴** — 1인/MVP에 마이크로서비스·과도 추상화는 안 된다.
