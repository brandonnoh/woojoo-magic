#!/usr/bin/env bash
# aeo-scan.sh — 운영 URL 원격 실측 수집기 (L1·L2·L3·L4·L5)
#
# 사용법:
#   bash aeo-scan.sh https://example.com [--out .dev/aeo/scan.json] [--quick] [--keep-raw]
#
# --quick : well-known 전수 조회를 건너뛰고 L1·L2·L3 핵심만 (CI 스모크용)
# 수집만 담당하고 판정은 aeo-assess.py가 한다 (수집/판정 분리).
set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aeo-lib.sh
source "${_script_dir}/aeo-lib.sh"

aeo_require curl python3

_target=""
_out=".dev/aeo/scan.json"
_quick=0
_keep_raw=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) _out="$2"; shift 2 ;;
    --quick) _quick=1; shift ;;
    --keep-raw) _keep_raw=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) _target="$1"; shift ;;
  esac
done

[[ -n "$_target" ]] || aeo_die "대상 URL을 지정하세요. 예: aeo-scan.sh https://example.com"
[[ "$_target" =~ ^https?:// ]] || _target="https://${_target}"

_origin="$(aeo_origin "$_target")"
_host="$(aeo_host "$_target")"
_raw="$(dirname "$_out")/raw"
mkdir -p "$_raw" "$(dirname "$_out")"

aeo_log "스캔 대상: ${_target} (origin=${_origin})"

# ── 1. 홈(또는 지정 URL) HTML 수집 ──────────────────────────────
aeo_log "L2 홈 HTML 수집"
_home_meta="$(aeo_fetch "$_target" "${_raw}/home.head" "${_raw}/home.body" \
  "$AEO_PROBE_UA_BROWSER" 'text/html,application/xhtml+xml')"
printf 'home\t%s\n' "$_home_meta" > "${_raw}/meta.tsv"

# ── 2. 마크다운 콘텐츠 협상 ─────────────────────────────────────
aeo_log "L3 마크다운 협상 확인"
# 파일명은 meta.tsv의 키(=aeo-assess.py의 슬러그)와 반드시 일치해야 한다
_md_meta="$(aeo_fetch "$_target" "${_raw}/homeMarkdown.head" "${_raw}/homeMarkdown.body" \
  "$AEO_PROBE_UA_BROWSER" 'text/markdown')"
printf 'homeMarkdown\t%s\n' "$_md_meta" >> "${_raw}/meta.tsv"

# ── 3. AI UA 접근성 실측 (L1) ───────────────────────────────────
aeo_log "L1 AI 크롤러 HTTP 접근성 실측"
for _pair in "search:${AEO_PROBE_UA_SEARCH}" \
             "perplexity:${AEO_PROBE_UA_PERPLEXITY}" \
             "train:${AEO_PROBE_UA_TRAIN}"; do
  _tag="${_pair%%:*}"
  _ua="${_pair#*:}"
  _code="$(aeo_probe_status "$_target" "$_ua" "${_raw}/ua_${_tag}.head")"
  printf 'ua_%s\t%s\t\t0\t%s\n' "$_tag" "$_code" "$_target" >> "${_raw}/meta.tsv"
done

# ── 4. well-known / 루트 발견 문서 ──────────────────────────────
for _entry in "${AEO_PROBE_PATHS[@]}"; do
  _key="${_entry%%|*}"
  _path="${_entry#*|}"
  # quick 모드는 L1~L3 핵심만
  if [[ "$_quick" == "1" ]]; then
    case "$_key" in
      robotsTxt|sitemap|llmsTxt) ;;
      *) continue ;;
    esac
  fi
  _slug="$(aeo_slug "$_key")"
  _meta="$(aeo_fetch "${_origin}${_path}" "${_raw}/${_slug}.head" "${_raw}/${_slug}.body")"
  printf '%s\t%s\n' "$_key" "$_meta" >> "${_raw}/meta.tsv"
done
aeo_log "발견 문서 ${#AEO_PROBE_PATHS[@]}종 조회 완료"

# ── 5. DNS-AID (DoH) ────────────────────────────────────────────
if [[ "$_quick" != "1" ]]; then
  aeo_log "L4 DNS-AID 조회"
  aeo_doh "_index._agents.${_host}" 64 "${_raw}/dns_index.json"
  aeo_doh "_a2a._agents.${_host}" 64 "${_raw}/dns_a2a.json"
  aeo_doh "_catalog._agents.${_host}" 16 "${_raw}/dns_catalog.json"
fi

# ── 6. 판정 위임 ────────────────────────────────────────────────
python3 "${_script_dir}/aeo-assess.py" \
  --raw "$_raw" --target "$_target" --origin "$_origin" --host "$_host" \
  --out "$_out"

if [[ "$_keep_raw" != "1" ]]; then
  aeo_log "원본 근거 보존: ${_raw} (--keep-raw 없이도 유지됨 — 증거는 지우지 않는다)"
fi

aeo_log "완료 → ${_out}"
