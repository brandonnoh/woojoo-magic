# AEO 점수 모델 (단일 진실원)

`scripts/aeo-score.py`는 이 문서를 그대로 구현한다. **문서와 코드가 어긋나면
이 문서가 기준**이며, 코드를 고친다.

> 이 점수는 wj-magic의 **자체 의견 모델**이다. isitagentready·Cloudflare Agent
> Readiness의 공식 점수가 아니다. 두 축을 분리하고 프로파일 가중을 적용한다는
> 점에서 의도적으로 다르다. 외부 점수와 숫자가 다른 것은 결함이 아니다.

## 1. 두 축

| 축 | 코드 | 의미 | 성과 지표 |
|---|---|---|---|
| AEO 축 | `aeo` | AI 답변에 인용되는가 | AI 유입·인용률 |
| Agent 축 | `agent` | 에이전트가 행동할 수 있는가 | 에이전트 트랜잭션 |

`overall = round(aeo * wA + agent * wB)`

## 2. 프로파일 가중치

| 프로파일 | wA (AEO) | wB (Agent) | 대표 |
|---|---|---|---|
| `content` | 0.85 | 0.15 | 블로그·미디어·커뮤니티 |
| `docs` | 0.70 | 0.30 | 개발자 문서·API 레퍼런스 |
| `saas-api` | 0.45 | 0.55 | 공개 API·SaaS 제품 |
| `commerce` | 0.50 | 0.50 | 쇼핑·예약·결제 |
| `hybrid` | 0.60 | 0.40 | 콘텐츠 + 제품 병행 |

## 3. AEO 축 체크 (12개)

| key | 레이어 | 배점 | 판정 기준 |
|---|---|---|---|
| `aiCrawlerAccess` | L1 | 18 | robots.txt가 주요 **검색계** AI 봇(OAI-SearchBot·PerplexityBot·Claude-SearchBot·Google-Extended)을 차단하지 않음 |
| `crawlerHttpAccess` | L1 | 8 | AI UA로 요청 시 2xx (403/429/봇월 없음) |
| `serverRendering` | L2 | 18 | JS 없는 raw HTML에 본문 텍스트가 존재 (본문 문자수 ≥ 임계, JS-only 렌더 아님) |
| `httpHygiene` | L2 | 6 | 200 응답, canonical 존재, 리다이렉트 체인 ≤1, `noindex` 없음 |
| `markdownNegotiation` | L3 | 8 | `Accept: text/markdown` 요청에 `text/markdown` 반환 |
| `llmsTxt` | L3 | 5 | `/llms.txt` 200 + H1 + 링크 목록 |
| `chunkability` | L3 | 9 | 질문형 H2 비율, 섹션 자기완결성, 표·리스트 사용, 헤딩 앵커 |
| `structuredData` | L4 | 15 | JSON-LD 존재 + 유효 `@type` + 핵심 타입 커버리지 |
| `answerBlocks` | L4 | 12 | 각 주요 섹션 첫 40~60단어 직답 블록 비율 |
| `entityAuthority` | L4 | 10 | Organization/Person + `sameAs`, 저자 표기, 출처 인용·통계 |
| `freshness` | L4 | 8 | `dateModified`/sitemap `lastmod` 최신성 |
| `metaFoundation` | L4 | 10 | title·description·canonical·OG·hreflang |

각 체크는 `0.0~1.0` 실수 점수를 반환한다(부분 점수 허용).
`aeo = Σ(score×weight) / Σ(applicable weight) × 100`.

## 4. Agent 축 체크 (24개, 5그룹)

isitagentready의 체크 키와 **동일한 이름**을 쓴다(대조 가능하도록).

| 그룹 | key | 배점 |
|---|---|---|
| discoverability | `robotsTxt` 6 · `sitemap` 6 · `linkHeaders` 6 · `dnsAid` 3 | 21 |
| contentAccessibility | `markdownNegotiation` 10 · `llmsTxt` 4 · `llmsFullTxt` 2 | 16 |
| botAccessControl | `robotsTxtAiRules` 8 · `contentSignals` 6 · `webBotAuth` 4 | 18 |
| discovery | `mcpServerCard` 10 · `apiCatalog` 8 · `a2aAgentCard` 6 · `agentSkills` 6 · `oauthDiscovery` 5 · `oauthProtectedResource` 5 · `ard` 4 · `webMcp` 4 · `authMd` 3 | 51 |
| commerce | `x402` 5 · `ucp` 4 · `acp` 4 · `mpp` 3 · `ap2` 2 | 18 |

## 5. N/A 규칙 (핵심)

프로파일에 무관한 체크는 **분모에서 제외**한다. 감점하지 않는다.

| 프로파일 | Agent 축 적용 범위 |
|---|---|
| `content` | discoverability(`robotsTxt`,`sitemap`,`linkHeaders`) + contentAccessibility 전체 + botAccessControl(`robotsTxtAiRules`,`contentSignals`) |
| `docs` | content 범위 + `agentSkills`, `mcpServerCard`, `apiCatalog` |
| `saas-api` | commerce 그룹 제외한 전체 |
| `commerce` | 전체 |
| `hybrid` | content 범위 + `mcpServerCard`, `apiCatalog`, `agentSkills`, `linkHeaders` |

AEO 축은 어떤 프로파일에서도 전부 적용된다 (AI 인용은 모든 서비스에 유효).
단 `llmsTxt`·`markdownNegotiation`은 두 축에 **동시 기여**한다 — 교집합 항목이기 때문.

## 6. 레이어 게이팅

L1(`aiCrawlerAccess`, `crawlerHttpAccess`)의 가중 평균이 `0.5` 미만이면
**L3·L4·L5 체크의 획득 점수에 ×0.5 캡**을 적용하고 리포트에 `gated: true`를 남긴다.

> 근거: 크롤러가 못 들어오면 스키마도 마크다운도 읽히지 않는다.
> 점수가 "실제로 인용될 가능성"을 반영해야 처방 우선순위가 올바르게 정렬된다.

L2(`serverRendering`)가 `0.3` 미만이면 L4 체크에 ×0.6 캡을 적용한다
(AI 크롤러는 JS를 실행하지 않으므로 CSR 전용 페이지의 JSON-LD는 도달하지 않는다).

## 7. 등급

| AEO 점수 | 등급 | 의미 |
|---|---|---|
| 95~100 | `S` | AI 인용 최적 |
| 85~94 | `A` | 우수 |
| 70~84 | `B` | 양호, 개선 여지 |
| 55~69 | `C` | 기본은 갖춤 |
| 40~54 | `D` | 구조적 결함 |
| 0~39 | `F` | AI에 사실상 비가시 |

Agent 축은 isitagentready의 레벨 0~5 정의를 그대로 재현한다
(`references/agent-readiness-standards.md` §레벨).

## 8. ROI 처방 정렬

`priority = impact × confidence / effort`

- `impact` 1~5 — 해당 프로파일의 성과 지표 기여도
- `effort` 1~5 — 구현 공수 (1=설정 한 줄, 5=아키텍처 변경)
- `confidence` 0.3~1.0 — 효과에 대한 근거 강도. **논쟁적 항목은 낮게 잡는다**
  (예: `llmsTxt` 0.4 — 채택률은 오르지만 주요 엔진 사용 근거 부족)

`NOW` = L1·L2 실패 항목 전부 + priority ≥ 4.0
`NEXT` = priority 1.5~4.0
`LATER` = priority < 1.5 또는 confidence < 0.5
