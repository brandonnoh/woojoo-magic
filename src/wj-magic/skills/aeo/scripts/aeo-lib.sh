#!/usr/bin/env bash
# aeo-lib.sh — AEO 스크립트 공용 상수·헬퍼
# 다른 스크립트에서 `source`로 로드한다. 단독 실행하지 않는다.
set -euo pipefail

# ── AI 크롤러 카탈로그 ───────────────────────────────────────────
# 단일 진실원은 aeo-bots.json이다 (bash·python 공용). 여기서 중복 정의하지 않는다.
# 유형(search/user/train) 구분이 핵심 — search/user를 막으면 AI 인용이 사라진다.
AEO_BOTS_JSON="${AEO_BOTS_JSON:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aeo-bots.json}"

# 봇 토큰 목록을 한 줄씩 출력한다. 사용: aeo_bot_tokens
aeo_bot_tokens() {
  python3 -c 'import json,sys
data=json.load(open(sys.argv[1]))
print("\n".join(b["token"] for b in data["bots"]))' "$AEO_BOTS_JSON"
}

# 봇 토큰 → 유형(kind) 매핑을 "토큰<TAB>유형" 으로 출력한다.
aeo_bot_kinds() {
  python3 -c 'import json,sys
data=json.load(open(sys.argv[1]))
print("\n".join(b["token"] + "\t" + b["kind"] for b in data["bots"]))' "$AEO_BOTS_JSON"
}

# 실제 HTTP 접근성을 실측할 대표 UA (전수는 과한 부하)
AEO_PROBE_UA_SEARCH='Mozilla/5.0 (compatible; OAI-SearchBot/1.0; +https://openai.com/searchbot)'
AEO_PROBE_UA_PERPLEXITY='Mozilla/5.0 (compatible; PerplexityBot/1.0; +https://perplexity.ai/perplexitybot)'
AEO_PROBE_UA_TRAIN='Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; GPTBot/1.1; +https://openai.com/gptbot'
AEO_PROBE_UA_BROWSER='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36'

# ── 원격 수집 대상 경로 ──────────────────────────────────────────
# 형식: "키|경로"
AEO_PROBE_PATHS=(
  "robotsTxt|/robots.txt"
  "sitemap|/sitemap.xml"
  "llmsTxt|/llms.txt"
  "llmsFullTxt|/llms-full.txt"
  "authMd|/auth.md"
  "openapi|/openapi.json"
  "apiCatalog|/.well-known/api-catalog"
  "mcpServerCard|/.well-known/mcp/server-card.json"
  "mcpServerCardAlt|/.well-known/mcp.json"
  "a2aAgentCard|/.well-known/agent-card.json"
  "agentSkills|/.well-known/agent-skills/index.json"
  "oidcConfig|/.well-known/openid-configuration"
  "oauthAuthServer|/.well-known/oauth-authorization-server"
  "oauthProtectedResource|/.well-known/oauth-protected-resource"
  "ard|/.well-known/ai-catalog.json"
  "webBotAuth|/.well-known/http-message-signatures-directory"
  "ucp|/.well-known/ucp"
  "acp|/.well-known/acp.json"
)

AEO_CURL_TIMEOUT="${AEO_CURL_TIMEOUT:-15}"
AEO_CURL_MAXSIZE="${AEO_CURL_MAXSIZE:-3000000}"

aeo_die() { printf '[aeo] %s\n' "$*" >&2; exit 1; }
aeo_log() { [[ "${AEO_QUIET:-0}" == "1" ]] || printf '[aeo] %s\n' "$*" >&2; }

# 필수 도구 확인 — 없으면 즉시 실패시킨다(조용한 부분 실패 금지)
aeo_require() {
  for _lib_tool in "$@"; do
    command -v "$_lib_tool" >/dev/null 2>&1 || aeo_die "필수 도구 없음: $_lib_tool"
  done
}

# URL을 스킴+호스트로 정규화한다
aeo_origin() {
  printf '%s' "$1" | sed -E 's#^(https?://[^/]+).*#\1#'
}

aeo_host() {
  printf '%s' "$1" | sed -E 's#^https?://##; s#/.*$##; s#:.*$##'
}

# 헤더와 본문을 각각 파일로 저장하고 "status<TAB>content_type<TAB>bytes<TAB>final_url" 출력
# 사용: aeo_fetch <url> <head_file> <body_file> [ua] [accept]
aeo_fetch() {
  _lib_url="$1"; _lib_hf="$2"; _lib_bf="$3"
  _lib_ua="${4:-$AEO_PROBE_UA_BROWSER}"
  _lib_accept="${5:-*/*}"
  _lib_meta=$(curl -sS -L --max-redirs 5 \
    --max-time "$AEO_CURL_TIMEOUT" --max-filesize "$AEO_CURL_MAXSIZE" \
    -A "$_lib_ua" -H "Accept: $_lib_accept" \
    -D "$_lib_hf" -o "$_lib_bf" \
    -w '%{http_code}\t%{content_type}\t%{size_download}\t%{url_effective}' \
    "$_lib_url" 2>/dev/null) || _lib_meta=$'000\t\t0\t'"$_lib_url"
  printf '%s' "$_lib_meta"
}

# HEAD만 — 접근성 실측용 (본문 다운로드 없이 상태코드 확인)
# 사용: aeo_probe_status <url> <ua> <head_file>
aeo_probe_status() {
  _lib_url="$1"; _lib_ua="$2"; _lib_hf="$3"
  curl -sS -I -L --max-redirs 5 --max-time "$AEO_CURL_TIMEOUT" \
    -A "$_lib_ua" -D "$_lib_hf" -o /dev/null -w '%{http_code}' "$_lib_url" 2>/dev/null || printf '000'
}

# DNS-over-HTTPS 조회 — SVCB(64) 레코드
# 사용: aeo_doh <name> <type> <out_file>
aeo_doh() {
  _lib_name="$1"; _lib_type="$2"; _lib_out="$3"
  curl -sS --max-time "$AEO_CURL_TIMEOUT" \
    -H 'accept: application/dns-json' \
    "https://cloudflare-dns.com/dns-query?name=${_lib_name}&type=${_lib_type}" \
    -o "$_lib_out" 2>/dev/null \
  || curl -sS --max-time "$AEO_CURL_TIMEOUT" \
       "https://dns.google/resolve?name=${_lib_name}&type=${_lib_type}" \
       -o "$_lib_out" 2>/dev/null \
  || printf '{}' > "$_lib_out"
}

# 경로 키를 안전한 파일명으로 변환
aeo_slug() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'; }
