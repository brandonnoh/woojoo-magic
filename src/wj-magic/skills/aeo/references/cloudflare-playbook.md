# Cloudflare AEO 플레이북 — 오리진을 건드리지 않고 얹는 레이어

Cloudflare를 쓰는 서비스는 **애플리케이션 코드 수정 없이** AEO/Agent 레이어의
상당 부분을 엣지에서 처리할 수 있다. 오리진 배포 리스크 없이 실험하고 되돌릴 수 있는
것이 최대 장점이다.

> 요금제·기능명은 변동이 잦다. 구현 전 `mcp__context7` 또는 공식 문서로
> **현재 상태를 반드시 재확인**한다. 기억으로 설정하지 않는다.

## 1. 기능 지도

| Cloudflare 기능 | 해결하는 체크 | 레이어 |
|---|---|---|
| AI Crawl Control — Manage AI Crawlers | `robotsTxtAiRules`, `aiCrawlerAccess` | L1 |
| AI Crawl Control — 관리형 robots.txt | `robotsTxt`, `contentSignals` | L1 |
| AI Crawl Control — Analyze AI Traffic | 측정 루프 (크롤러 히트) | 측정 |
| AI Crawl Control — robots.txt 준수 추적 | 위반 크롤러 탐지·차단 규칙 | L1 |
| AI Crawl Control — Pay Per Crawl (private beta) | 크롤 수익화 | 정책 |
| Markdown for Agents (content converter) | `markdownNegotiation` | L3 |
| Transform Rule (Modify Response Header) | `linkHeaders` | L4 |
| Workers | 모든 well-known 파일, 마크다운 협상 자체 구현 | L3·L5 |
| Bot Management — Web Bot Auth 검증 | `webBotAuth` (수신 측) | L5 |
| Cloudflare Access | `oauthDiscovery`, `oauthProtectedResource` | L5 |
| Agents SDK | MCP 서버 / A2A 에이전트 구축 | L5 |
| AI Search / AI Index | 도메인 AI 인덱스 + MCP·llms.txt·검색 API 자동 노출 | L3·L5 |
| Radar — Agent Readiness 데이터셋 | 업계 벤치마크 비교 | 측정 |

## 2. Markdown for Agents (최우선 — AEO와 Agent 양축 교집합)

**대시보드**
1. 존 선택 → AI Crawl Control
2. "Markdown for Agents" 활성화 (Pro/Business 이상)
3. 특정 서브도메인·경로만 적용하려면 Configuration Rule로 경로 표현식 + On

**API**

```
PATCH /client/v4/zones/{zone_tag}/settings/content_converter
{"value": "on"}
```

**엣지가 하는 일**: 오리진에서 HTML을 받아 마크다운으로 변환해 응답한다.

- `Content-Type: text/markdown; charset=utf-8`
- `Vary: Accept` 추가 (캐시 변형 분리)
- `Content-Length` 재계산
- `Content-Encoding`·`Content-Range`·`Transfer-Encoding`·`ETag`·`Last-Modified` 제거
- HSTS·CSP·CORS·캐시 지시자는 보존
- `x-markdown-tokens` / `x-original-tokens` 추가 (변환 전후 추정 토큰 수)
- `content-signal` 기본값 `ai-train=yes, search=yes, ai-input=yes` — 오리진이
  지정하면 그 값이 우선. **정책과 다르면 오리진에서 명시적으로 설정할 것**

**검증**

```bash
curl -sSI -H 'Accept: text/markdown' https://example.com/ | grep -i -E 'content-type|vary|x-markdown'
curl -sSI https://example.com/ | grep -i content-type   # HTML이 기본이어야 정상
```

**주의**: 자동 변환 품질은 페이지 구조에 좌우된다. 네비·푸터·광고가 마크다운에
그대로 실려 나오면 이득이 반감된다. 시맨틱 HTML(`<article>`, `<main>`)로
본문 경계를 명확히 하는 것이 선행 작업이다.

## 3. Link 헤더 (Transform Rule)

오리진 수정 없이 응답 헤더를 추가한다.

- Rules → Transform Rules → Modify Response Header → Set static
- Header name: `Link`
- Value: `</.well-known/api-catalog>; rel="api-catalog", </openapi.json>; rel="service-desc", </docs>; rel="service-doc"`
- 표현식 예: `http.request.uri.path eq "/"` (홈페이지 한정)

## 4. Workers로 well-known 파일 서빙

오리진 라우팅을 건드리지 않고 정적 발견 문서를 제공한다.
`templates/` 아래 템플릿을 채워 하나의 Worker에 매핑한다.

```js
// templates/wellknown.worker.js 참조 — 경로 → 정적 JSON 매핑
const ROUTES = {
  '/.well-known/mcp/server-card.json': [MCP_CARD, 'application/json'],
  '/.well-known/agent-card.json':      [A2A_CARD, 'application/json'],
  '/.well-known/api-catalog':          [API_CATALOG, 'application/linkset+json'],
  '/.well-known/ai-catalog.json':      [AI_CATALOG, 'application/json'],
  '/llms.txt':                         [LLMS_TXT, 'text/plain; charset=utf-8'],
};
```

## 5. AI Crawl Control — 정책과 측정

- **Manage AI Crawlers**: 크롤러별 allow/block. `crawler-access-matrix.md`의
  "학습은 막고 검색은 허용" 정책을 여기서 집행한다 (robots.txt는 선언, 여기가 강제)
- **Analyze AI Traffic**: 크롤러별 요청 수·경로 패턴. **AEO 측정 루프의 1차 데이터원**
- **robots.txt 준수 추적**: 선언을 어기는 크롤러 식별 → WAF 규칙으로 승격
- **Pay Per Crawl**: 크롤 유료화(비공개 베타). 콘텐츠 사업자의 수익화 옵션이지만
  **인용 유입을 원한다면 검색계 크롤러에는 적용하지 않는다**

## 6. AI Index / AI Search

도메인에 대한 AI 최적화 인덱스를 자동 생성하고 MCP 서버 · `llms.txt` · 검색 API를
표준 도구로 노출하는 방향의 기능군. 우리 손으로 만들 `llms.txt`·MCP 서버와 **중복될 수
있으므로**, 도입 시 어느 쪽을 진실원으로 삼을지 먼저 정한다. 둘 다 켜고 내용이
어긋나면 에이전트가 모순된 정보를 읽는다.

## 7. 도입 순서 (Cloudflare 사용 서비스)

1. AI Crawl Control에서 **현재 크롤러 트래픽부터 관측** (정책 변경 전 베이스라인)
2. 크롤러 정책 확정 → Manage AI Crawlers + 관리형 robots.txt
3. Markdown for Agents 활성화 → 변환 품질 육안 확인
4. Transform Rule로 `Link` 헤더
5. Workers로 well-known 문서 (프로파일이 요구할 때만)
6. Bot Management / Access는 실제 에이전트 인증 요구가 생길 때

## 8. 함정

| 함정 | 결과 |
|---|---|
| 봇 파이트 모드·챌린지 전역 적용 | AI 검색 크롤러까지 차단 → 인용 소멸 |
| Markdown 변환만 켜고 시맨틱 HTML 방치 | 네비·광고가 섞인 마크다운 |
| 관리형 robots.txt와 오리진 robots.txt 동시 운영 | 어느 쪽이 나가는지 모호 |
| `content-signal` 기본값 방치 | 의도한 정책과 다른 신호가 나감 |
| AI Index와 자체 llms.txt 동시 운영 | 에이전트가 모순 정보 수신 |
| 엣지 캐시에 `Vary: Accept` 누락 | 브라우저에 마크다운, 에이전트에 HTML이 섞여 나감 |
