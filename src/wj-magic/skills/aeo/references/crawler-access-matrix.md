# L1·L2 — 크롤러 접근 매트릭스 & 렌더링 갭

AEO의 **전제조건 레이어**. 여기가 깨지면 아래 모든 투자가 0이 된다.

## 1. AI 봇은 세 종류다 — 이걸 구분 못 하면 인용이 통째로 사라진다

| 유형 | 하는 일 | 막으면 | 대표 UA |
|---|---|---|---|
| **학습(train)** | 파운데이션 모델 학습 데이터 수집 | 학습 데이터에서 빠짐. **인용에는 영향 적음** | `GPTBot`, `ClaudeBot`, `Google-Extended`, `CCBot`, `Applebot-Extended`, `Bytespider`, `meta-externalagent`, `Amazonbot`, `anthropic-ai` |
| **검색(search)** | 실시간 인덱싱 → 답변에 인용 | **AI 답변에서 사라짐. 치명적** | `OAI-SearchBot`, `PerplexityBot`, `Claude-SearchBot` |
| **사용자 개시(user)** | 사용자가 URL을 주면 그때 방문 | 사용자가 링크를 줘도 못 읽음 | `ChatGPT-User`, `Perplexity-User`, `Claude-User` |

> **가장 흔한 자해**: "AI 학습 싫으니 AI 봇 다 막자" → `OAI-SearchBot`·`PerplexityBot`까지
> 막혀 AI 답변 인용이 0이 된다. 학습은 막고 검색은 허용하는 게 대부분 서비스의 정답이다.

## 2. 권장 robots.txt 정책 (콘텐츠·문서형 기본값)

```
# ── 검색·인용 계열: 허용 (AEO의 생명줄) ──
User-agent: OAI-SearchBot
User-agent: PerplexityBot
User-agent: Claude-SearchBot
Allow: /

# ── 사용자 개시: 허용 ──
User-agent: ChatGPT-User
User-agent: Perplexity-User
User-agent: Claude-User
Allow: /

# ── 학습 계열: 정책에 따라 (아래는 "학습 거부" 예시) ──
User-agent: GPTBot
User-agent: ClaudeBot
User-agent: Google-Extended
User-agent: CCBot
User-agent: Bytespider
User-agent: Applebot-Extended
User-agent: meta-externalagent
Disallow: /
Content-Signal: ai-train=no, search=yes, ai-input=yes

User-agent: *
Allow: /
Content-Signal: search=yes, ai-input=yes, ai-train=no

Sitemap: https://example.com/sitemap.xml
```

**주의**: 학습을 전면 차단하면 모델의 장기 브랜드 인지도에서 불리해질 수 있다.
브랜드 노출이 성과인 서비스는 `ai-train=yes` + 허용이 유리한 경우가 많다.
이건 **비즈니스 판단**이므로 스킬이 임의로 정하지 말고 사용자에게 선택지를 제시한다.

## 3. Content Signals의 실체 (과대평가 금지)

`Content-Signal: search=yes, ai-train=no, ai-input=no`는 **선언이지 강제가 아니다**.
Google은 이 디렉티브를 인식·사용하지 않는다고 공개적으로 밝혔고, 다른 주요 크롤러의
준수 근거도 약하다. Cloudflare 관리형 robots.txt는 이를 자동 삽입한다.

- **의미 있는 것**: 법적·정책적 의사표시, 향후 표준화 대비, Agent-Readiness 점수
- **의미 없는 것**: 실제 차단. 강제는 WAF / Bot Management / AI Crawl Control이 한다

## 4. HTTP 레벨 차단 — robots.txt보다 흔한 진짜 원인

robots.txt가 허용해도 아래에서 막히면 인용은 발생하지 않는다. 반드시 실측한다.

| 원인 | 증상 | 확인 |
|---|---|---|
| WAF/봇 매니지먼트 봇 스코어 | AI UA에 403/503 | AI UA로 curl → 상태코드 |
| Rate limit | 429 | 연속 요청 시 429 |
| 지역 차단 / CDN 지오펜스 | 특정 리전 403 | 다른 리전 확인 |
| 로그인 벽·쿠키 게이트 | 200이지만 본문이 로그인 폼 | 본문 텍스트 검사 |
| Cloudflare 챌린지 | `cf-mitigated: challenge` | 응답 헤더 |
| `X-Robots-Tag: noindex` | 200이지만 색인 거부 | 응답 헤더 |

```bash
curl -sSI -A "Mozilla/5.0 (compatible; OAI-SearchBot/1.0; +https://openai.com/searchbot)" https://example.com/
curl -sSI -A "PerplexityBot/1.0" https://example.com/
```

## 5. L2 — JavaScript 렌더링 갭 (조용한 살인자)

**AI 크롤러는 JavaScript를 실행하지 않는다.**

- Vercel×MERJ의 GPTBot 5억+ 페치 분석: JS 실행 증거 **0건**. JS 파일을 내려받는
  경우(약 11.5%)에도 실행하지 않았다.
- ClaudeBot·PerplexityBot·Bytespider·meta-externalagent도 동일. 초기 HTML만 파싱한다.
- Googlebot은 렌더링하지만 **AI Overviews의 인용 후보 선정 단계**에서는 raw HTML의
  텍스트가 절대적으로 유리하다.

### 결과

| 렌더링 방식 | AI 가시성 |
|---|---|
| SSR / SSG / ISR | 온전 |
| RSC (React Server Components) 서버 렌더 | 온전 |
| 하이드레이션 후 채워지는 CSR | **빈 페이지** |
| 클라이언트 fetch로 로드되는 본문 | 안 보임 |
| 클라이언트에서 주입하는 JSON-LD | 안 읽힘 → **JSON-LD는 반드시 서버 렌더** |
| 무한 스크롤 전용 목록 | 첫 배치만 |
| 탭·아코디언 안에 숨긴 본문 | DOM에 있으면 읽힘, 지연 로드면 안 됨 |

### 진단 방법 (둘 다 해야 정확하다)

1. **raw HTML 본문 실측** — JS 없이 텍스트가 얼마나 나오는가
   (`scripts/aeo-content-audit.sh`가 태그를 벗겨 문자수를 센다)
2. **렌더 후와 비교** — Playwright MCP로 JS 켠 본문 길이를 재고 비율 산출.
   `raw / rendered < 0.3`이면 심각한 렌더링 갭

`scripts/aeo-content-audit.sh --render-gap <url>`이 1번을 자동화하고,
2번의 비교 기준값을 함께 출력한다.

### 처방 우선순위

1. 본문·제목·JSON-LD를 **서버 렌더**로 이동 (Next.js App Router 서버 컴포넌트,
   Nuxt SSR, Astro, Remix loader 등)
2. 최소한 **핵심 콘텐츠만이라도** SSG/ISR로 사전 생성
3. 그것도 어려우면 AI 크롤러 UA에 한해 프리렌더 응답 제공 — 단
   **동일 콘텐츠의 다른 전달 형식**이어야 한다. 내용이 다르면 클로킹으로 정책 위반

## 6. 검증 체크리스트

- [ ] robots.txt가 검색계 AI 봇을 차단하지 않는다
- [ ] AI UA로 요청 시 2xx가 온다 (403/429/챌린지 없음)
- [ ] `X-Robots-Tag`에 `noindex`가 없다
- [ ] raw HTML 본문 문자수가 렌더 후 대비 70% 이상
- [ ] JSON-LD가 raw HTML에 존재한다
- [ ] 리다이렉트 체인이 1회 이하이고 canonical이 자기 자신
- [ ] sitemap.xml이 robots.txt에서 참조되고 실제 200
