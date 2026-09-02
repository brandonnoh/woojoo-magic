#!/usr/bin/env bats
# AEO 스킬 파이프라인 테스트 — 네트워크를 타지 않고 픽스처로만 검증한다.

setup() {
  SCRIPTS="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-magic/skills/aeo/scripts" && pwd)"
  FIX="$(cd "$(dirname "$BATS_TEST_FILENAME")/../fixtures/aeo" && pwd)"
  WORK="$BATS_TEST_TMPDIR/aeo"
  mkdir -p "$WORK"
}

assess() {
  python3 "$SCRIPTS/aeo-assess.py" --raw "$FIX/$1/raw" \
    --target "https://$1.test/" --origin "https://$1.test" --host "$1.test" \
    --out "$WORK/$1-scan.json"
}

score() {
  python3 "$SCRIPTS/aeo-score.py" --scan "$WORK/$1-scan.json" \
    --profile "$2" --out "$WORK/$1-$2-score.json"
}

jq_py() {
  python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(eval(sys.argv[2]))" "$1" "$2"
}

# ── 판정기 ────────────────────────────────────────────────────
@test "assess: search-tier crawlers allowed -> pass" {  # assess: good 픽스처의 검색계 크롤러 접근이 pass
  assess good
  [ "$(jq_py "$WORK/good-scan.json" "d['checks']['aiCrawlerAccess']['status']")" = "pass" ]
}

@test "assess: blocking train bots keeps citation path open" {  # assess: 학습 봇만 차단해도 인용 경로는 pass로 유지된다
  assess good
  run jq_py "$WORK/good-scan.json" "[b['token'] for b in d['bots'] if b['policy']=='disallow']"
  [[ "$output" == *"GPTBot"* ]]
  [[ "$output" != *"PerplexityBot"* ]]
}

@test "assess: wildcard full block -> aiCrawlerAccess fail" {  # assess: 와일드카드 전면 차단은 aiCrawlerAccess fail
  assess blocked
  [ "$(jq_py "$WORK/blocked-scan.json" "d['checks']['aiCrawlerAccess']['status']")" = "fail" ]
}

@test "assess: 403 to AI UA -> crawlerHttpAccess fail" {  # assess: AI UA에 403이면 crawlerHttpAccess fail
  assess blocked
  [ "$(jq_py "$WORK/blocked-scan.json" "d['checks']['crawlerHttpAccess']['status']")" = "fail" ]
}

@test "assess: JS shell page -> serverRendering fail" {  # assess: JS 셸 페이지는 serverRendering fail
  assess blocked
  [ "$(jq_py "$WORK/blocked-scan.json" "d['checks']['serverRendering']['status']")" = "fail" ]
}

@test "assess: server-rendered JSON-LD detected" {  # assess: 서버 렌더 JSON-LD를 structuredData로 인식
  assess good
  run jq_py "$WORK/good-scan.json" "d['checks']['structuredData']['evidence']['types']"
  [[ "$output" == *"Article"* ]]
  [[ "$output" == *"FAQPage"* ]]
}

@test "assess: markdown negotiation with Vary Accept -> pass" {  # assess: 마크다운 협상 + Vary Accept면 pass
  assess good
  [ "$(jq_py "$WORK/good-scan.json" "d['checks']['markdownNegotiation']['status']")" = "pass" ]
}

@test "assess: described llms.txt -> pass" {  # assess: 설명 붙은 llms.txt는 pass
  assess good
  [ "$(jq_py "$WORK/good-scan.json" "d['checks']['llmsTxt']['status']")" = "pass" ]
}

@test "assess: explicit AI bot groups -> robotsTxtAiRules pass" {  # assess: 명시적 AI 봇 블록을 robotsTxtAiRules로 인식
  assess good
  [ "$(jq_py "$WORK/good-scan.json" "d['checks']['robotsTxtAiRules']['status']")" = "pass" ]
}

@test "assess: three-axis Content-Signal -> pass" {  # assess: Content-Signal 3축 선언이면 pass
  assess good
  [ "$(jq_py "$WORK/good-scan.json" "d['checks']['contentSignals']['status']")" = "pass" ]
}

@test "assess: missing well-known doc -> fail" {  # assess: 없는 well-known 문서는 fail로 보고된다
  assess good
  [ "$(jq_py "$WORK/good-scan.json" "d['checks']['mcpServerCard']['status']")" = "fail" ]
}

# ── 점수 모델 ──────────────────────────────────────────────────
@test "score: content profile marks discovery checks N/A" {  # score: content 프로파일은 에이전트 발견 체크를 N/A로 제외한다
  assess good
  score good content
  run jq_py "$WORK/good-content-score.json" \
    "[r['key'] for r in d['rows'] if r['axis']=='agent' and not r['applicable']]"
  [[ "$output" == *"mcpServerCard"* ]]
  [[ "$output" == *"oauthDiscovery"* ]]
  [[ "$output" == *"x402"* ]]
}

@test "score: saas-api profile applies mcpServerCard" {  # score: saas-api 프로파일은 MCP 카드를 적용 대상으로 본다
  assess good
  score good saas-api
  run jq_py "$WORK/good-saas-api-score.json" \
    "[r['applicable'] for r in d['rows'] if r['key']=='mcpServerCard'][0]"
  [ "$output" = "True" ]
}

@test "score: same scan scores higher for content than saas-api" {  # score: 동일 스캔에서 content 프로파일 점수가 saas-api보다 높다
  assess good
  score good content
  score good saas-api
  _content="$(jq_py "$WORK/good-content-score.json" "d['overall']")"
  _saas="$(jq_py "$WORK/good-saas-api-score.json" "d['overall']")"
  run python3 -c "print(float('$_content') > float('$_saas'))"
  [ "$output" = "True" ]
}

@test "score: L1 failure caps upper layers" {  # score: L1 실패 시 상위 레이어에 캡이 걸린다
  assess blocked
  score blocked content
  [ "$(jq_py "$WORK/blocked-content-score.json" "d['gates']['upperCap']")" = "0.5" ]
}

@test "score: L1 failures land in NOW bucket" {  # score: L1 실패 항목은 NOW 버킷에 들어간다
  assess blocked
  score blocked content
  run jq_py "$WORK/blocked-content-score.json" "[p['key'] for p in d['prescriptions']['NOW']]"
  [[ "$output" == *"aiCrawlerAccess"* ]]
}

@test "score: dual-axis checks are prescribed once" {  # score: 두 축에 걸친 체크의 처방은 중복되지 않는다
  assess good
  score good docs
  run python3 -c "
import json,sys
d=json.load(open('$WORK/good-docs-score.json'))
keys=[p['key'] for b in d['prescriptions'].values() for p in b]
print(len(keys)==len(set(keys)))"
  [ "$output" = "True" ]
}

@test "score: fail-under threshold exits 1" {  # score: --fail-under 임계 미달이면 종료코드 1
  assess blocked
  run python3 "$SCRIPTS/aeo-score.py" --scan "$WORK/blocked-scan.json" \
    --profile content --out "$WORK/x.json" --fail-under 90
  [ "$status" -eq 1 ]
}

@test "score: unknown profile is rejected" {  # score: 알 수 없는 프로파일은 거부된다
  assess good
  run python3 "$SCRIPTS/aeo-score.py" --scan "$WORK/good-scan.json" \
    --profile nonsense --out "$WORK/x.json"
  [ "$status" -ne 0 ]
}

# ── 대시보드 ───────────────────────────────────────────────────
@test "dashboard: emits single HTML with no script tags" {  # dashboard: JS 없는 단일 HTML을 생성한다
  assess good
  score good content
  python3 "$SCRIPTS/aeo-dashboard.py" --score "$WORK/good-content-score.json" \
    --out "$WORK/dash.html"
  [ -f "$WORK/dash.html" ]
  run grep -c '<script' "$WORK/dash.html"
  [ "$output" = "0" ]
}

@test "dashboard: renders 7 stage panels" {  # dashboard: STAGE 패널 7개와 종합 점수를 포함한다
  assess good
  score good content
  python3 "$SCRIPTS/aeo-dashboard.py" --score "$WORK/good-content-score.json" \
    --out "$WORK/dash.html"
  # 패널이 한 줄에 몰려 있을 수 있으므로 줄 수가 아니라 출현 횟수를 센다
  run bash -c "grep -o 'class=\"panel\"' '$WORK/dash.html' | wc -l | tr -d ' '"
  [ "$output" = "7" ]
  grep -q "AEO CONTROL PANEL" "$WORK/dash.html"
}

@test "dashboard: one card per check key" {  # dashboard: 체크 카드가 키별로 한 번만 나온다
  assess good
  score good docs
  python3 "$SCRIPTS/aeo-dashboard.py" --score "$WORK/good-docs-score.json" \
    --out "$WORK/dash.html"
  run grep -c '<b>markdownNegotiation</b>' "$WORK/dash.html"
  [ "$output" = "1" ]
}

# ── 크롤러 로그 ────────────────────────────────────────────────
@test "crawler: classifies bot kinds and warns on blocks" {  # crawler: 봇 유형을 구분하고 차단을 경고한다
  cat > "$WORK/access.log" <<'LOG'
1.1.1.1 - - [01/Sep/2026:10:00:00 +0900] "GET /a HTTP/1.1" 200 10 "-" "compatible; OAI-SearchBot/1.0"
1.1.1.2 - - [01/Sep/2026:10:01:00 +0900] "GET /b HTTP/1.1" 403 0 "-" "compatible; PerplexityBot/1.0"
1.1.1.3 - - [01/Sep/2026:10:02:00 +0900] "GET /c HTTP/1.1" 200 10 "https://chatgpt.com/" "Chrome/130.0"
LOG
  python3 "$SCRIPTS/aeo-crawler-parse.py" --out "$WORK/crawlers.json" < "$WORK/access.log"
  [ "$(jq_py "$WORK/crawlers.json" "d['botHits']")" = "2" ]
  [ "$(jq_py "$WORK/crawlers.json" "d['aiReferrals']['chatgpt.com']")" = "1" ]
  run jq_py "$WORK/crawlers.json" "d['warnings']"
  [[ "$output" == *"PerplexityBot"* ]]
}

# ── 사이트맵 추출 ──────────────────────────────────────────────
@test "sitemap: extracts loc up to limit" {  # sitemap: loc를 limit 개수만큼 뽑는다
  run python3 "$SCRIPTS/aeo-sitemap-urls.py" "$FIX/good/raw/sitemap.body" 1
  [ "$status" -eq 0 ]
  [ "$output" = "https://example.test/" ]
}

@test "sitemap: missing file does not abort audit" {  # sitemap: 파일이 없어도 감사를 중단시키지 않는다
  run python3 "$SCRIPTS/aeo-sitemap-urls.py" "$WORK/nope.xml" 5
  [ "$status" -eq 0 ]
}

# ── 봇 카탈로그 ────────────────────────────────────────────────
@test "lib: bot catalog exposes search and train kinds" {  # lib: 봇 카탈로그가 검색·학습 유형을 모두 제공한다
  run bash -c "source '$SCRIPTS/aeo-lib.sh' && aeo_bot_kinds"
  [[ "$output" == *"OAI-SearchBot"$'\t'"search"* ]]
  [[ "$output" == *"GPTBot"$'\t'"train"* ]]
}

@test "lib: bot catalog JSON is valid" {  # lib: 봇 카탈로그 JSON이 유효하다
  run python3 -c "
import json
d=json.load(open('$SCRIPTS/aeo-bots.json'))
kinds={b['kind'] for b in d['bots']}
print(kinds <= {'search','user','train'} and len(d['bots']) >= 15)"
  [ "$output" = "True" ]
}
