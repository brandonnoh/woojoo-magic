#!/usr/bin/env bash
# aeo-content-audit.sh — 로컬 코드베이스 + 샘플 URL 콘텐츠 레이어 감사 (L2·L3·L4)
#
# 사용법:
#   bash aeo-content-audit.sh <repo-dir> [--out .dev/aeo/content.json]
#                             [--urls urls.txt | --sitemap .dev/aeo/raw/sitemap.body]
#                             [--sample 10] [--render-gap]
#
# 코드에는 있는데 배포에는 없는 결함을 잡기 위해 로컬·원격을 함께 본다.
set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aeo-lib.sh
source "${_script_dir}/aeo-lib.sh"

aeo_require python3 grep

_repo="."
_out=".dev/aeo/content.json"
_urls_file=""
_sitemap_file=""
_sample=8
_render_gap=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) _out="$2"; shift 2 ;;
    --urls) _urls_file="$2"; shift 2 ;;
    --sitemap) _sitemap_file="$2"; shift 2 ;;
    --sample) _sample="$2"; shift 2 ;;
    --render-gap) _render_gap=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) _repo="$1"; shift ;;
  esac
done

[[ -d "$_repo" ]] || aeo_die "저장소 경로 없음: $_repo"
_raw="$(dirname "$_out")/raw-content"
mkdir -p "$_raw" "$(dirname "$_out")"
# 재실행 시 이전 결과가 누적되지 않도록 비운다 (누적되면 옛 샘플이 평균을 오염시킨다)
: > "${_raw}/codebase.tsv"
: > "${_raw}/meta.tsv"

# ── 1. 프레임워크·렌더링 방식 탐지 ──────────────────────────────
aeo_log "로컬 코드베이스 정적 감사: ${_repo}"

# grep 카운트를 안전하게 기록한다 (매치 0건이 스크립트를 죽이지 않도록)
count_pattern() {
  _cnt_key="$1"; _cnt_pattern="$2"
  # grep은 무매치 시 1을 반환한다. pipefail 환경에서 스크립트를 죽이지 않도록 흡수한다.
  _cnt_val="$( { grep -rIl --exclude-dir=node_modules --exclude-dir=.git \
    --exclude-dir=dist --exclude-dir=build --exclude-dir=.next \
    -E "$_cnt_pattern" "$_repo" 2>/dev/null || true; } | wc -l | tr -d ' ')"
  printf '%s\t%s\n' "$_cnt_key" "${_cnt_val:-0}" >> "${_raw}/codebase.tsv"
}

_pkg="${_repo}/package.json"
if [[ -f "$_pkg" ]]; then
  python3 - "$_pkg" "${_raw}/codebase.tsv" <<'PY'
import json, sys
pkg_path, out_path = sys.argv[1], sys.argv[2]
try:
    pkg = json.load(open(pkg_path, encoding="utf-8"))
except Exception:
    pkg = {}
deps = {}
deps.update(pkg.get("dependencies") or {})
deps.update(pkg.get("devDependencies") or {})
known = ["next", "nuxt", "astro", "@sveltejs/kit", "remix", "@remix-run/react",
         "gatsby", "react", "vue", "svelte", "vite", "express", "fastify", "hono"]
found = [name for name in known if name in deps]
with open(out_path, "a", encoding="utf-8") as handle:
    handle.write("framework\t" + ",".join(found) + "\n")
PY
else
  printf 'framework\t\n' >> "${_raw}/codebase.tsv"
fi

count_pattern clientComponents "^['\"]use client['\"]"
count_pattern jsonLdSources "application/ld\+json"
count_pattern metadataExports "generateMetadata|export const metadata|useHead\(|<svelte:head"
count_pattern robotsSources "robots\.(ts|js|txt)"
count_pattern sitemapSources "sitemap\.(ts|js|xml)"
count_pattern llmsSources "llms(-full)?\.txt"
count_pattern ssrDisabled "ssr:\s*false|dynamic\(.*ssr:\s*false"
count_pattern canonicalSources "rel=[\"']canonical[\"']|canonical:"
count_pattern faqSchema "FAQPage"
count_pattern orgSchema "\"@type\"\s*:\s*\"(Organization|Person)\""
count_pattern mcpSources "modelContext|server-card|mcp"

# ── 2. 샘플 URL 수집 ────────────────────────────────────────────
: > "${_raw}/urls.txt"
if [[ -n "$_urls_file" && -f "$_urls_file" ]]; then
  head -n "$_sample" "$_urls_file" > "${_raw}/urls.txt"
elif [[ -n "$_sitemap_file" && -f "$_sitemap_file" ]]; then
  # 사이트맵 인덱스면 하위 사이트맵을 한 단계 따라가야 실제 페이지 URL이 나온다.
  # grep|head 파이프는 SIGPIPE로 pipefail에 걸리므로 python으로 추출한다.
  if grep -q '<sitemapindex' "$_sitemap_file" 2>/dev/null; then
    _child="$(python3 "${_script_dir}/aeo-sitemap-urls.py" "$_sitemap_file" 1)"
    if [[ -n "$_child" ]]; then
      aeo_log "사이트맵 인덱스 감지 — 하위 사이트맵 추적: $_child"
      aeo_fetch "$_child" "${_raw}/child.head" "${_raw}/child.body" >/dev/null
      _sitemap_file="${_raw}/child.body"
    fi
  fi
  python3 "${_script_dir}/aeo-sitemap-urls.py" "$_sitemap_file" "$_sample" > "${_raw}/urls.txt"
fi

_idx=0
while IFS= read -r _url; do
  [[ -n "$_url" ]] || continue
  _idx=$((_idx + 1))
  _meta="$(aeo_fetch "$_url" "${_raw}/s${_idx}.head" "${_raw}/s${_idx}.body")"
  printf 's%s\t%s\n' "$_idx" "$_meta" >> "${_raw}/meta.tsv"
done < "${_raw}/urls.txt"
[[ "$_idx" -gt 0 ]] && aeo_log "샘플 페이지 ${_idx}개 수집" || aeo_log "샘플 URL 없음 (로컬 감사만 수행)"

# ── 3. 판정 위임 ────────────────────────────────────────────────
python3 "${_script_dir}/aeo-content-assess.py" \
  --raw "$_raw" --repo "$_repo" --out "$_out" \
  $([[ "$_render_gap" == "1" ]] && printf '%s' --render-gap)

aeo_log "완료 → ${_out}"
