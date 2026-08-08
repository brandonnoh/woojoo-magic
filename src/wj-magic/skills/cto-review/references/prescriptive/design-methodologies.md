# 아키텍처 설계 방법론 카탈로그

> 아키텍처를 설계·문서화·검증하는 표준 방법론. 1인/소규모 눈높이로 경량화한 실전 적용법 포함.

## 상황별 방법론 선택

| 질문 | 방법론 |
|------|--------|
| 코드를 어떤 단위로 나눌까 | DDD(Bounded Context) + Event Storming |
| 시스템 구조를 어떻게 그릴까 | C4 Model(Context/Container) |
| 왜 이 기술을 골랐는지 기록 | ADR(Y-Statement or Nygard) |
| 빠뜨린 품질속성 없나 | Well-Architected(6 Pillars) |
| 배포/운영 원칙이 맞나 | 12-Factor App |
| 아키텍처 문서 전체 구조 | arc42(12섹션 or Canvas) |
| 아키텍처 규칙 자동 검증 | Fitness Functions |
| 직접 만들 것 vs 갖다 쓸 것 | Wardley Mapping |
| 큰 결정 전 의견수렴 | RFC Process |

## 각 방법론 (경량 적용법)

**DDD (Domain-Driven Design)**: 비즈니스 도메인 언어·구조를 코드에 반영. 전략적(Bounded Context Map·Ubiquitous Language·Context 관계 ACL/Shared Kernel)+전술적(Aggregate·Entity/VO·Domain Event·Repository). 경량: BC 식별+용어집만 해도 70% 가치. 1인 적용: 용어 10-20개 정의→폴더를 BC 단위로(log/table/chat/seo), 전술 패턴은 복잡도 충분할 때만.

**C4 Model**: 4단 줌(L1 System Context/L2 Container/L3 Component/L4 Code). 경량: L1+L2만으로 커뮤니케이션 80%. 적용: Mermaid/PlantUML로 L1(5분), L2에 배포단위(Next.js/Supabase DB/Storage/Cron), README·CLAUDE.md 인라인. L4는 IDE가 보여주니 생략.

**ADR (Architecture Decision Records)**: "왜 골랐나" 기록. Nygard(Title/Status/Context/Decision/Consequences) / MADR(+Drivers/Options/Pros-Cons) / **Y-Statement(초경량)**: "In the context of X, facing Y, we decided Z, to achieve W, accepting [trade-off]." 경량: Y-Statement를 CLAUDE.md에(이 프로젝트가 이미 "개발 교훈"으로 함). 1페이지 이내, "고려한 대안+왜 버렸나" 필수.

**AWS Well-Architected (6 Pillars)**: Operational Excellence/Security/Reliability/Performance/Cost/Sustainability. 경량: 배포 전 기둥별 "가장 큰 리스크 1개씩"(30분). 소규모는 보안+신뢰성+비용 3개 집중. CTO 리뷰 게이트에 기둥별 1문항.

**12-Factor App**: Codebase/Dependencies/Config(env)/Backing Services/Build-Release-Run/Processes(stateless)/Port/Concurrency/Disposability/Dev-Prod Parity/Logs(stream)/Admin. +13th Identity. 소규모 자주 위반: #3 Config 하드코딩, #10 Dev/Prod 불일치, #6 상태 남기기.

**arc42**: 12섹션(Intro&Goals/Constraints/Context/Solution Strategy/Building Block/Runtime/Deployment/Crosscutting/Decisions/Quality/Risks/Glossary). 경량: Canvas 1페이지 + Section 3(Context)+5(Building Block)+9(Decisions). CLAUDE.md가 사실상 arc42 축약판.

**4+1 View (Kruchten)**: Logical(개발자)/Process(동시성)/Development(폴더구조)/Physical(배포)/+1 Scenarios(유스케이스). 경량: Development+Scenarios 2개. C4가 4+1을 흡수.

**Fitness Functions**: 아키텍처 규칙을 자동 테스트로. ArchUnit(Java)/eslint-plugin-boundaries/dependency-cruiser(Node). 5차원(Atomic/Holistic, Triggered/Continual, Static/Dynamic, Automated/Manual, Temporal). 경량: ESLint+`tsc`가 이미 기초. 추가: dependency-cruiser 모듈경계 규칙, Lighthouse CI threshold. **"아키텍처 결정을 문서가 아니라 실행 가능한 테스트로 보호."**

**Wardley Mapping**: 가치사슬을 진화단계(Genesis→Custom→Product→Commodity)에 배치. Build vs Buy vs Adopt. 예: AI분석=Genesis(직접투자), 인증=Commodity(Supabase Auth), DB=Product. Genesis/Custom=직접개발 핵심, Commodity=외부서비스. ADR에 Wardley Map 첨부하면 "왜 직접 안 만들었나" 자명.

**RFC Process**: 결정 전 제안+비동기 토론(ADR은 결정 후 기록). Problem/Solution/Alternatives/Migration/Risks/Open Questions. 경량: 1인은 ADR+고무오리로 충분. 2인+는 "RFC 1장→하루 코멘트→결정"(사후 분쟁 40%↓). 핵심가치: 작성 강제 자체가 설계품질↑.

**Event Storming (DDD 보조)**: 도메인 이벤트 중심 프로세스 발견 워크숍. 오렌지(Event)/파랑(Command)/노랑(Aggregate)/분홍(External)/보라(Hotspot). 경량: 혼자 FigJam 30분("사용자가 앱 열면→로그 로드→오늘 혈당 조회→..."). 이벤트 밀도 높은 곳=핵심 도메인=BC 경계.

**TOGAF (경량 발췌)**: 엔터프라이즈 아키텍처 전체 사이클(ADM 8단계). 소규모엔 과잉. Capability Map 개념만 차용("우리 서비스가 갖춰야 할 역량" 1페이지). Well-Architected가 클라우드 맥락의 실전 대체재.
