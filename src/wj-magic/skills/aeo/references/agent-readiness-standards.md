# L5 — Agent-Readiness 표준 전수 명세

에이전트가 우리 서비스에서 **행동**하게 만드는 레이어. 콘텐츠 사이트에는
대부분 무관하다 — `scoring-model.md`의 N/A 규칙을 먼저 확인하고 들어온다.

체크 키는 isitagentready.com 스캐너와 **동일한 이름**을 쓴다(대조 가능하도록).
검증: `POST https://isitagentready.com/api/scan` `{"url":"https://YOUR-SITE.com"}`
또는 MCP 서버 `https://isitagentready.com/mcp`의 `scan_site` 툴.

## 레벨 정의 (isitagentready 0~5)

| Lv | 이름 | 요건 |
|---|---|---|
| 0 | Not Ready | robots.txt·sitemap·Link 헤더 중 2개 미만 |
| 1 | Basic Web Presence | 위 3개 중 2개 |
| 2 | Bot-Aware | Lv1 + robots.txt AI 봇 규칙 **및** Content Signals |
| 3 | Agent-Readable | Lv2 + 마크다운 콘텐츠 협상 |
| 4 | Agent-Integrated | Lv3 + (MCP Server Card / A2A Agent Card / Agent Skills / API Catalog) 중 1 |
| 5 | Agent-Native | Lv4 + (Web Bot Auth / 전체 통합 / 인증 메타데이터(OAuth 또는 Auth.md)) 중 2 |

## 그룹 1 — discoverability

### `robotsTxt` (RFC 9309)
`/robots.txt`를 `text/plain` 200으로 제공. `User-agent` + `Allow`/`Disallow`.
`Sitemap:` 참조 포함.

### `sitemap` (sitemaps.org)
`/sitemap.xml` 유효 XML 200. canonical `<url><loc>` 목록. `lastmod` 정확히 유지.
robots.txt에서 참조.

### `linkHeaders` (RFC 8288 / RFC 9727 §3)
홈페이지 응답에 `Link` 헤더로 기계판독 리소스를 가리킨다.
등록된 relation type 사용: `api-catalog`, `service-desc`, `service-doc`, `describedby`.

```
Link: </.well-known/api-catalog>; rel="api-catalog"
Link: </openapi.json>; rel="service-desc", </docs>; rel="service-doc"
```

Cloudflare의 Transform Rule 또는 Workers로 오리진 수정 없이 추가할 수 있다.

### `dnsAid` (DNS for AI Discovery)
도메인의 `_agents` 네임스페이스 아래 SVCB/HTTPS 레코드 게시.
`_index._agents.example.com`, `_a2a._agents.example.com`.
미등록 실험 파라미터는 숫자 `keyNNNNN` 사용. DNSSEC 서명 권장.

```dns
_a2a._agents.example.com. 3600 IN SVCB 1 agent.example.com. alpn="a2a" port=443 mandatory=alpn,port
```

스캐너는 DoH(`cloudflare-dns.com/dns-query`, 폴백 `dns.google/resolve`)로 검증한다.

## 그룹 2 — contentAccessibility

### `markdownNegotiation` (Markdown for Agents) ★ AEO와 교집합
`Accept: text/markdown` 요청에 마크다운 표현을 반환. 브라우저(HTML)는 기본 유지.

- `Content-Type: text/markdown; charset=utf-8`
- `Vary: Accept` **필수** (캐시가 변형을 분리 저장)
- 권장 헤더: `x-markdown-tokens`, `x-original-tokens`
- Cloudflare: AI Crawl Control에서 "Markdown for Agents" 활성화(Pro/Business),
  또는 API `PATCH /zones/{zone}/settings/content_converter` `{"value":"on"}`.
  경로 한정은 Configuration Rule로.
- 자체 구현: `templates/markdown-negotiation.worker.js` 참조

### `llmsTxt` / `llmsFullTxt` (llmstxt.org)
`/llms.txt` — H1 제목 + 요약 문단 + **설명이 붙은** 핵심 링크 큐레이션.
`/llms-full.txt` — 본문 인라인 확장판. **토큰 예산을 정하고** 만든다.

> 냉정한 평가: 2026년 9월 현재 커뮤니티 제안 단계이며(W3C 초안 논의 중),
> 주요 검색·답변 엔진이 이를 사용한다는 근거는 약하다. IDE 에이전트
> (Cursor·Claude Code·Copilot 등)가 문서 사이트에서 실제로 조회하므로
> **개발자 문서 사이트에서 실익이 가장 크다**. 저비용이라 하는 것이지
> 인용률 상승의 주요 수단이 아니다.

## 그룹 3 — botAccessControl

### `robotsTxtAiRules`
AI 크롤러에 대한 **명시적** `User-agent` 블록. 와일드카드만으로는 불충분.
대상: `GPTBot`, `OAI-SearchBot`, `ChatGPT-User`, `ClaudeBot`, `Claude-Web`,
`anthropic-ai`, `PerplexityBot`, `Google-Extended`, `Amazonbot`, `Bytespider`,
`CCBot`, `Applebot-Extended`, `meta-externalagent`, `cohere-ai`.
정책 설계는 `crawler-access-matrix.md` 참조 — **검색계를 막지 말 것**.

### `contentSignals` (contentsignals.org / IETF draft-romm-aipref-contentsignals)
robots.txt의 관련 `User-agent` 블록 아래에 선언.

```
Content-Signal: ai-train=no, search=yes, ai-input=yes
```

**선언이지 강제가 아니다.** Google은 미사용을 공식 확인했다.

### `webBotAuth` (IETF WebBotAuth WG)
우리가 **보내는** 봇/에이전트 요청에 서명해 신원을 증명하는 표준.

- `/.well-known/http-message-signatures-directory`에 JWKS 게시 (공개키 1개 이상)
- 발신 요청에 `Signature-Agent`, `Signature-Input` 헤더
- 수신 측 검증은 Cloudflare Bot Management의 Web Bot Auth 지원 사용
- **우리 사이트가 에이전트를 내보낼 때** 필요. 순수 콘텐츠 사이트는 무관

## 그룹 4 — discovery

### `mcpServerCard` (SEP-1649)
`/.well-known/mcp/server-card.json` 200 JSON.
`serverInfo{name,version}` + 트랜스포트 `endpoint`(예: `/mcp`) + `capabilities`
(tools/resources/prompts). → `templates/mcp-server-card.json.tmpl`

### `a2aAgentCard` (A2A Protocol)
`/.well-known/agent-card.json` 200 JSON.
`name`, `version`, `description`, `supportedInterfaces`(서비스 URL + 트랜스포트),
`capabilities`, `skills[{id,name,description}]`. → `templates/a2a-agent-card.json.tmpl`

### `agentSkills` (Cloudflare Agent Skills Discovery RFC v0.2.0)
`/.well-known/agent-skills/index.json` 200 JSON.

- `$schema`: `https://schemas.agentskills.io/discovery/0.2.0/schema.json`
- `skills[]`: `name`(소문자+하이픈), `type`(`skill-md` | `archive`), `description`,
  `url`, `digest`(`sha256:{hex}`)

→ `templates/agent-skills-index.json.tmpl` + `scripts/aeo-scan.sh`가 digest를 검증한다.

### `apiCatalog` (RFC 9727)
`/.well-known/api-catalog`, `Content-Type: application/linkset+json`, 200.
`linkset[]` 각 항목에 `anchor` + `service-desc`(OpenAPI) + `service-doc` +
선택 `status`. → `templates/api-catalog.json.tmpl`

### `oauthDiscovery` (RFC 8414 / OIDC Discovery)
`/.well-known/oauth-authorization-server` 또는 `/.well-known/openid-configuration`.
`issuer`, `authorization_endpoint`, `token_endpoint`, `jwks_uri`,
`grant_types_supported`, `response_types_supported`.

### `oauthProtectedResource` (RFC 9728)
`/.well-known/oauth-protected-resource` 200 JSON.
`resource`, `authorization_servers[]`, 선택 `scopes_supported`,
`bearer_methods_supported`(`header` 포함 권장).
401 응답에 `WWW-Authenticate: ... resource_metadata="..."` 반환 권장.

### `authMd` (Auth.md)
`/auth.md`를 마크다운으로 제공. H1에 `auth.md` 포함.
가능하면 PRM(RFC 9728)과 함께 게시하고, `agent_auth` 블록에 `skill`,
`register_uri`, 등록 방식(ID-JAG / verified email / anonymous)을 명시한다.

> **주의**: 수동 스캔 시 `POST /agent/auth`를 호출하지 않는다 — 실제 계정 생성,
> 메일 발송, 크레덴셜 발급이 일어날 수 있다. 공개 발견 문서만이 안전한 진실원이다.

### `ard` (Agentic Resource Discovery, v0.9 draft)
`/.well-known/ai-catalog.json` 200 JSON + `Access-Control-Allow-Origin: *`.
`specVersion`(ai-catalog 데이터 모델 버전) + `host{displayName,identifier}` +
`entries[]`. 각 엔트리: `identifier`(`urn:air:<fqdn>:<ns>:<name>`), `displayName`,
`type`(미디어 타입), **`url` 또는 `data` 중 정확히 하나**, `representativeQueries` 2~5개.
보조 발견 경로: robots.txt `Agentmap:`, HTML `<link rel="ai-catalog">`,
DNS `_catalog._agents` TXT. → `templates/ai-catalog.json.tmpl`

### `webMcp` (WebMCP API)
브라우저에서 `navigator.modelContext.registerTool()`로 사이트 액션을 노출.
각 툴에 `name`, `description`, `inputSchema`(JSON Schema), `execute` 콜백.
`AbortController` 시그널로 해제. **페이지 로드 시 실행**되어야 스캐너가 감지한다.

## 그룹 5 — commerce (커머스형만 해당)

| key | 경로/방식 | 요건 |
|---|---|---|
| `x402` | 미들웨어 (`@x402/express`, `@x402/hono`, `@x402/next`) | 보호 라우트가 HTTP 402 + 결제 요구사항 반환. facilitator URL + 지갑 주소 |
| `ucp` | `/.well-known/ucp` | `protocol_version`, `services`, `capabilities`, `endpoints` |
| `acp` | `/.well-known/acp.json` | `protocol.name="acp"`, `protocol.version`, `api_base_url`, `transports[]`, `capabilities.services[]` |
| `mpp` | `/openapi.json` | 결제 가능 오퍼레이션에 `x-payment-info`(`intent`, `method`, `amount`) |
| `ap2` | A2A Agent Card 기반 | A2A 카드가 전제 |

## 구현 순서 권장 (saas-api / commerce)

1. `robotsTxt` · `sitemap` · `linkHeaders` (Lv1)
2. `robotsTxtAiRules` · `contentSignals` (Lv2)
3. `markdownNegotiation` (Lv3) — AEO와 교집합이라 ROI가 가장 좋다
4. `mcpServerCard` 또는 `apiCatalog` (Lv4) — 실제 동작하는 MCP 서버부터
5. `oauthProtectedResource` + `authMd`, `webBotAuth` (Lv5)
6. 커머스 프로토콜은 실제 거래 시나리오가 있을 때만

> **빈 껍데기 금지**: 카드만 올리고 뒤에 서버가 없으면 스캐너는 pass여도
> 에이전트는 실패한다. 신뢰는 한 번 깨지면 회복이 어렵다.
