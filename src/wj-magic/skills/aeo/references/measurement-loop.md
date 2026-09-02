# 측정 루프 — AEO는 프로젝트가 아니라 운영이다

한 번 구현하고 끝내면 6개월 뒤 표준이 바뀌어 조용히 깨진다. **재측정 루프가 본체다.**

## 0. 측정 계층 (증거의 강도 순)

| 강도 | 지표 | 획득 방법 |
|---|---|---|
| ★★★ | **AI 유입 세션** | 리퍼러/UTM 기반 실제 방문 (아래 §2) |
| ★★★ | **인용 발생** | 답변 엔진 질의 → 우리 도메인 인용 여부 샘플링 |
| ★★☆ | **AI 크롤러 히트** | 서버·CDN 로그의 AI UA 요청 수·경로 |
| ★★☆ | **크롤 성공률** | AI UA 요청 중 2xx 비율 (403/429 비율) |
| ★☆☆ | **AEO 점수** | `aeo-score.py` 자체 점수 |
| ★☆☆ | **외부 스캐너 레벨** | isitagentready 레벨 |

> 자체 점수는 **선행 지표**일 뿐이다. 점수가 올랐는데 크롤러 히트와 인용이
> 안 움직이면 그 처방은 효과가 없었던 것이다. 정직하게 기록한다.

## 1. AI 크롤러 히트 집계

```bash
# 액세스 로그(nginx/CloudFront/CF Logpush 등)에서 AI UA 집계
bash scripts/aeo-crawler-log.sh /var/log/nginx/access.log --out .dev/aeo/crawlers.json
zcat logs/*.gz | bash scripts/aeo-crawler-log.sh - --out .dev/aeo/crawlers.json
```

산출: 봇별 요청 수 / 2xx·403·429 분포 / 상위 경로 / 유형(train·search·user)별 합계.

**읽는 법**

| 관찰 | 해석 | 조치 |
|---|---|---|
| 검색계(`OAI-SearchBot` 등) 히트 0 | 차단 중이거나 발견되지 않음 | L1 재검증 → sitemap·내부링크 |
| 403/429 비율 높음 | WAF·레이트리밋이 차단 | 봇 정책·레이트리밋 예외 |
| 히트는 많은데 인용 없음 | L2~L4 문제 (렌더링·구조·권위) | 렌더링 갭 → 콘텐츠 구조 순 |
| 특정 경로만 크롤 | 내부 링크·sitemap 커버리지 부족 | 사이트 구조 보강 |
| 히트 급감 | robots 변경·차단 사고·CDN 규칙 | 변경 이력 대조 |

Cloudflare 사용 시 AI Crawl Control의 Analyze AI Traffic이 같은 데이터를 준다.

## 2. AI 유입 세션 추적

AI 답변에서 온 방문은 리퍼러로 구분된다. 분석 도구에 세그먼트를 만든다.

```
chat.openai.com | chatgpt.com | perplexity.ai | claude.ai | copilot.microsoft.com
gemini.google.com | bing.com/chat | you.com | phind.com
```

- 리퍼러가 비는 경우가 많으므로 **직접 유입 증가와 교차 확인**
- 브랜드 검색량 증가도 AI 노출의 간접 신호
- 도메인 인지 → 검색이라는 경로가 흔하므로 **단일 지표로 판단하지 않는다**

## 3. 인용 샘플링 (가장 직접적인 지표)

우리 주제의 핵심 질의 20~50개를 고정 목록으로 만들고 **주기적으로 수동/자동 질의**해
우리 도메인이 인용되는지 기록한다.

```
.dev/aeo/queries.txt      질의 목록 (고정)
.dev/aeo/citations/{YYYYMMDD}.json   엔진별 인용 여부·순서·인용 문장
```

- 엔진별로 따로 측정한다 (ChatGPT / Perplexity / AI Overviews / Claude)
- **인용된 문장을 그대로 기록**한다 — 어떤 청크가 먹히는지가 최고의 학습 데이터
- 인용되지 않았다면 어떤 도메인이 인용됐는지 기록 (경쟁 분석)

> 자동화 시 각 서비스의 이용약관을 확인한다. 스크래핑이 금지된 곳은 수동 샘플링
> 또는 공식 API만 사용한다.

## 4. 재측정 주기

| 주기 | 작업 |
|---|---|
| 배포마다 | `aeo-scan.sh` + `aeo-content-audit.sh` (회귀 방지) |
| 주 1회 | 크롤러 로그 집계 + 대시보드 갱신 |
| 월 1회 | 인용 샘플링 + 처방 효과 판정 |
| 분기 1회 | 표준 변경 추적 (아래 §5) + 전체 재감사 |

CI에 넣을 최소 게이트:

```bash
# 배포 후 스모크 — L1/L2가 깨지면 실패시킨다
bash scripts/aeo-scan.sh "$SITE_URL" --out /tmp/aeo.json --quick
python3 scripts/aeo-score.py --scan /tmp/aeo.json --profile content \
  --out /tmp/score.json --fail-under 60
```

## 5. 표준 변경 추적 (분기 1회)

이 영역은 빠르게 움직인다. 다음을 확인한다.

- isitagentready 체크 목록 변경 (`/.well-known/agent-skills/index.json` 재조회)
- Cloudflare AI Crawl Control 기능 추가·이름 변경
- llms.txt의 W3C 표준화 진행 상황
- 새 AI 크롤러 UA 등장 (특히 검색계) → `crawler-access-matrix.md` 갱신
- MCP / A2A / WebMCP 스펙 버전 변경

변경 발견 시 `references/` 문서를 갱신하고 `learn` 스킬로 교훈을 적재한다.

## 6. 효과 판정 기록

처방마다 before/after를 남긴다. **효과 없음도 기록**해야 다음에 같은 공수를 반복하지 않는다.

```
.dev/aeo/history/{YYYYMMDD-HHMM}.json   점수 스냅샷
docs/aeo/AEO_REPORT.md                  처방·판정 누적 기록
```

| 처방 | 적용일 | 점수 Δ | 크롤러 히트 Δ | 인용 Δ | 판정 |
|---|---|---|---|---|---|
| 검색봇 차단 해제 | 2026-09-02 | +18 | +340% | +6건 | 효과 큼 |
| llms.txt 추가 | 2026-09-02 | +4 | ±0 | ±0 | 효과 미확인 |
