---
name: aeo
description: >
  AI 답변 엔진에 인용되고(AEO/GEO) AI 에이전트가 실행할 수 있는(Agent-Readiness)
  서비스로 만드는 5레이어 최적화 스킬. 두 축을 명확히 분리해 서비스 프로파일
  (콘텐츠형/문서형/SaaS-API형/커머스형)별 가중치로 점수화하고, 무관한 표준을
  강요하지 않는다. 실측 스캔 → 프로파일 가중 점수 → ROI 처방 → Wave 구현 →
  재측정 → 로컬 8-bit 대시보드까지 수행한다. robots.txt AI 규칙, Content Signals,
  llms.txt, Markdown for Agents(content negotiation), JSON-LD 스키마, 답변 블록,
  SSR 렌더링 갭, Link 헤더, sitemap, MCP Server Card, A2A Agent Card, Agent Skills
  Index, API Catalog(RFC 9727), OAuth 디스커버리, Auth.md, ARD, WebMCP, Web Bot Auth,
  DNS-AID, x402/UCP/ACP/MPP 커머스 프로토콜을 다룬다.
  "AEO", "GEO", "AI 검색 최적화", "AI에 검색 잘 걸리게", "ChatGPT에 인용", "AI 노출",
  "answer engine optimization", "에이전트 최적화", "agent ready", "agent readiness",
  "isitagentready", "llms.txt", "robots.txt AI", "AI 크롤러", "Cloudflare AI",
  "마크다운 협상", "MCP 서버 카드", "AEO 점수", "AEO 대시보드" 요청에 트리거.
---

**품질 기준**: `../../references/common/SKILL_PREAMBLE.md` 참조 (반드시 Read로 로드)

# AEO — AI 가시성 · 에이전트 준비도 최적화

## ⛔ 가장 먼저 이해할 것: 이건 하나가 아니라 두 개다

많은 팀이 여기서 공수를 태운다. **AEO와 Agent-Readiness는 목표가 다르다.**

| | **AEO / GEO** | **Agent-Readiness** |
|---|---|---|
| 목표 | 우리 콘텐츠가 **AI 답변에 인용**된다 | 에이전트가 우리 사이트에서 **행동**한다 |
| 소비 주체 | 답변 엔진(ChatGPT·Perplexity·AI Overviews·Claude) | 자율 에이전트(MCP 클라이언트, A2A, 브라우저 에이전트) |
| 성과 지표 | 인용률·AI 유입·브랜드 언급 | 에이전트 트랜잭션·API 호출·결제 |
| 대표 수단 | 크롤러 허용, SSR, JSON-LD, 답변 블록, 엔티티 | MCP 카드, A2A 카드, API Catalog, OAuth, x402 |
| 콘텐츠 사이트 | **직결** | 대부분 무관 |
| API/SaaS | 보조 | **직결** |

**교집합(둘 다 이득)**: `robots.txt` AI 규칙 · `sitemap.xml` · `llms.txt` ·
Markdown for Agents · `Link` 헤더 · Content Signals.

> **이 스킬의 원칙**: 스캐너 점수를 만점 만드는 게 목적이 아니다.
> **그 서비스의 성과 지표에 기여하는 것만** 처방한다. 콘텐츠 사이트에
> OAuth 디스커버리를 붙여 "pass"를 만드는 건 유입 기여 0의 공수다 —
> 이 스킬은 그런 항목을 **N/A로 제외**하고 점수에서 빼지 않는다.

## When to use this skill

- "AI 검색에 안 잡힌다", "ChatGPT가 우리를 인용 안 한다"
- 새 서비스 런칭 전 AI 가시성 기반 공사
- isitagentready / Cloudflare Agent Readiness 점수를 받았는데 뭘 할지 모를 때
- MCP·A2A로 우리 서비스를 에이전트에 노출하고 싶을 때
- AEO 현황을 **한 화면 대시보드**로 보고 싶을 때

**경계**: 전통 SEO 순위 전술 = `seo-optimizer`, 프론트 성능·접근성 실측 =
`qa-frontend`, 아키텍처 = `cto-review`. 이 스킬은 **AI/에이전트가 우리를
읽고·믿고·쓰는가**만 책임진다.

---

## 5레이어 모델 (겹겹이)

아래로 갈수록 상위 레이어에 의존한다. **L1이 깨지면 L3~L5는 전부 무의미하다.**

```
L1 ACCESS      크롤러가 들어올 수 있는가        robots.txt / AI 봇 규칙 / WAF / 403 / Content Signals
L2 RENDER      들어와서 본문이 보이는가          SSR·raw HTML 본문 / JS 렌더링 갭 / status·redirect
L3 REPRESENT   보기 좋은 형태로 주는가           Markdown 협상 / llms.txt / 시맨틱 HTML / 청크 구조
L4 MEANING     의미·신뢰를 기계가 읽는가         JSON-LD / 엔티티 / 저자·출처 / 답변 블록 / 신선도
L5 ACT         에이전트가 행동할 수 있는가       MCP·A2A·Agent Skills / API Catalog / OAuth / 커머스
```

- **L1~L2 = 전제조건**. 여기 실패면 다른 모든 투자가 0이 된다. 최우선.
- **L3~L4 = AEO 본체**. 인용률을 실제로 움직인다.
- **L5 = Agent-Readiness**. 서비스 프로파일이 맞을 때만 의미.

**L2가 조용한 살인자다**: GPTBot·ClaudeBot·PerplexityBot은 **JavaScript를 실행하지 않는다**
(Vercel×MERJ의 GPTBot 5억 건 분석에서 JS 실행 증거 0건). CSR SPA는 AI에게 빈 페이지다.
자세한 내용은 `references/crawler-access-matrix.md`.

---

## Phase 0 — 컨텍스트 로드 + 서비스 프로파일 판별

1. `SKILL_PREAMBLE.md` + `references/scoring-model.md` Read.
2. 대상 확정: 운영 URL(있으면) + 로컬 코드베이스 경로.
3. **프로파일 판별** — 성과 지표가 무엇인지로 결정한다.

| 프로파일 | 판별 신호 | AEO : Agent 가중 |
|---|---|---|
| `content` | 블로그·매거진·미디어·커뮤니티. 유입=성과 | 85 : 15 |
| `docs` | 개발자 문서·API 레퍼런스. 에이전트도 읽음 | 70 : 30 |
| `saas-api` | 공개 API·대시보드 제품. 에이전트 연동이 성과 | 45 : 55 |
| `commerce` | 판매·예약·결제. 에이전트 거래가 성과 | 50 : 50 |
| `hybrid` | 콘텐츠 + 제품 병행 | 60 : 40 |

Serena `get_symbols_overview` + `find_symbol`로 라우팅·robots·sitemap·메타 생성부를
실제로 찾아 근거를 확보한다. 추측 금지. 애매하면 사용자에게 **한 번만** 확인한다.

## Phase 1 — 5레이어 실측 스캔 (병렬)

**로컬 코드 스캔**과 **운영 URL 스캔**을 모두 돌린다. 둘은 서로를 검증한다
(코드엔 있는데 배포엔 없는 케이스가 가장 흔한 결함).

```bash
# 운영 URL — L1/L2/L3/L5 원격 실측 (well-known 24종, 헤더, 마크다운 협상, DNS-AID)
bash scripts/aeo-scan.sh https://example.com --out .dev/aeo/scan.json

# 로컬 코드 — L2/L3/L4 정적 감사 (SSR 여부, JSON-LD, 답변 블록, 청크 구조)
bash scripts/aeo-content-audit.sh . --out .dev/aeo/content.json

# 선택: 서버/Cloudflare 로그에서 실제 AI 크롤러 히트 집계 (증거의 최상위)
bash scripts/aeo-crawler-log.sh <logfile|-> --out .dev/aeo/crawlers.json
```

**보강 스캔 (에이전트 병렬 투입)** — 규모가 M 이상이면:

| 에이전트 | 담당 |
|---|---|
| `aeo-auditor` | 원격 스캔 실행·evidence 정합성 검증·오탐 제거 |
| `aeo-content-optimizer` | L3/L4 콘텐츠 레이어 심층 감사 (샘플 URL 10~20개 실독) |
| `aeo-infra-engineer` | L1/L2/L5 인프라·헤더·well-known·CDN 계층 감사 |
| `web-researcher` | 해당 버티컬의 최신 인용 패턴·경쟁사 실측 비교 |

Playwright MCP로 **JS 끈 상태 vs 켠 상태 본문 diff**를 실측하면 L2 렌더링 갭이
정확히 잡힌다 (`aeo-content-audit.sh --render-gap` 참조).

## Phase 2 — 점수 산출 (프로파일 가중)

```bash
python3 scripts/aeo-score.py \
  --scan .dev/aeo/scan.json --content .dev/aeo/content.json \
  --profile content --out .dev/aeo/score.json
```

산식·가중치·N/A 규칙은 `references/scoring-model.md`가 단일 진실원이다.
핵심 규칙 셋:

1. **N/A는 분모에서 뺀다** — 프로파일에 무관한 체크는 감점하지 않고 회색 처리.
2. **레이어 게이팅** — L1이 fail이면 L3~L5 점수에 `×0.5` 캡을 건다. 못 들어오는데
   안이 예쁜 건 의미가 없다. 점수가 현실을 반영하게 만드는 장치.
3. **증거 없는 pass 금지** — 모든 체크 결과에 요청/응답 근거를 남긴다.

## Phase 3 — ROI 처방 (Impact × Effort)

갭마다 `impact`(성과 기여) × `effort`(공수) × `confidence`(효과 근거의 확실성)로
정렬한다. 근거가 약한 항목(예: llms.txt의 실효성 논쟁)은 **약하다고 명시**하고
과대평가하지 않는다. `references/aeo-content-playbook.md`의 처방 카탈로그를 쓴다.

출력은 3단 구조: **NOW**(전제조건·즉시) / **NEXT**(본체) / **LATER**(선택·실험).

## Phase 4 — Wave 구현

충돌 제로 Wave로 나눠 위임한다. 템플릿(`templates/`)을 그대로 쓰되 서비스 실제
데이터로 채운다. 빈 껍데기 파일 배포는 **금지** — 스캐너는 통과해도 에이전트가
쓰레기를 읽는다.

| Wave | 내용 | 담당 |
|---|---|---|
| W1 | L1/L2 전제조건 (robots AI 규칙, 크롤러 허용, SSR 전환, 상태코드) | `aeo-infra-engineer` |
| W2 | L3/L4 콘텐츠 (JSON-LD, 답변 블록, 질문형 H2, 메타·canonical, 신선도) | `aeo-content-optimizer` |
| W3 | L3 표현 (llms.txt, Markdown 협상, Link 헤더, Content Signals) | `aeo-infra-engineer` |
| W4 | L5 에이전트 (MCP/A2A 카드, Agent Skills, API Catalog, OAuth, 커머스) | `backend-dev` + `aeo-infra-engineer` |
| W5 | 측정 루프 (크롤러 로그 파이프라인, 재스캔 크론, 인용 추적) | `aeo-auditor` |

프로파일이 `content`면 W4는 기본적으로 **건너뛴다**. 사용자가 명시적으로
에이전트 트랜잭션을 원할 때만 실행한다.

## Phase 5 — 재측정 회귀 게이트

구현 후 Phase 1~2를 **동일 커맨드로** 다시 돌려 before/after를 남긴다.
`.dev/aeo/history/{YYYYMMDD-HHMM}.json`에 스냅샷을 적재해 추세를 만든다.
점수가 오르지 않은 처방은 **효과 없음으로 기록**한다 (`learn` 스킬 연계).

## Phase 6 — 로컬 AEO 대시보드 (필수 마무리)

```bash
python3 scripts/aeo-dashboard.py --score .dev/aeo/score.json \
  --history .dev/aeo/history --out docs/reports/aeo-dashboard.html --open
```

`../../references/common/REPORT_8BIT.md` 규격의 8-bit 단일 HTML. 구성:

- **HEADER**: 종합 점수 게이지 + 프로파일 + 레벨 + 전회 대비 델타
- **STAGE 1 · 5레이어 스택**: L1~L5 컨베이어, 실패 레이어는 붉게 차단 표시
- **STAGE 2 · 두 축 분리**: AEO 축 / Agent 축 각각의 점수·가중치·N/A 개수
- **STAGE 3 · 체크 도감**: 30+ 체크 카드 그리드 (pass/fail/neutral/N-A + 근거)
- **STAGE 4 · 크롤러 접근 매트릭스**: AI 봇별 allow/block/미지정 HUD 테이블
- **STAGE 5 · ROI 처방 큐**: NOW/NEXT/LATER 게이트 시퀀스 (impact×effort)
- **STAGE 6 · 추세**: 스냅샷 히스토리 스파크라인 (CSS/SVG, JS 없음)
- **footer**: 근거 파일 경로 + 스캔 시각

상시 확인용 로컬 서버가 필요하면:
```bash
bash scripts/aeo-serve.sh          # http://localhost:8907 + 60초 주기 갱신
```

---

## 위험 신호

| 위험 신호 | 현실 |
|---|---|
| "스캐너 만점 만들자" | 프로파일 무관 항목은 유입 기여 0. N/A로 빼는 게 정답 |
| "llms.txt만 올리면 AI에 뜬다" | 효과 논쟁적이고 Google은 사용 안 함. 저비용이라 하는 것뿐 |
| "JSON-LD 넣었으니 끝" | 크롤러가 못 들어오거나 CSR이면 스키마도 안 읽힌다. L1→L2 먼저 |
| "AI 봇 다 막자" | 학습 봇(GPTBot)과 검색 봇(OAI-SearchBot)은 별개. 검색 봇을 막으면 인용이 사라진다 |
| "빈 템플릿이라도 배포" | 에이전트가 실제로 읽는다. 껍데기 카드는 신뢰 손상 |
| "한 번 하고 끝" | 표준이 분기 단위로 바뀐다. Phase 5 재측정 루프가 본체다 |

## 산출물

- `docs/aeo/AEO_REPORT.md` — 진단·처방 텍스트 리포트
- `docs/reports/aeo-dashboard.html` — **로컬 8-bit 대시보드 (필수, 브라우저 자동 오픈)**
- `.dev/aeo/{scan,content,score}.json` + `.dev/aeo/history/` — 원본 근거·추세
- 실제 구현물 (robots.txt, llms.txt, well-known 파일, JSON-LD, Worker 등)

## 통합 흐름

`aeo(진단·처방) → devrule(구현) → qa-frontend(렌더·성능 검증) → aeo(재측정)`

## 레퍼런스

| 문서 | 로드 시점 |
|---|---|
| `references/scoring-model.md` | 항상 (Phase 0·2) |
| `references/crawler-access-matrix.md` | L1/L2 진단 시 (거의 항상) |
| `references/aeo-content-playbook.md` | L3/L4 처방 시 (콘텐츠·문서형 필수) |
| `references/structured-data-playbook.md` | JSON-LD 설계·구현 시 |
| `references/agent-readiness-standards.md` | L5 처방 시 (saas-api·commerce) |
| `references/cloudflare-playbook.md` | Cloudflare 사용 서비스일 때 |
| `references/measurement-loop.md` | Phase 5 측정 루프 구축 시 |
