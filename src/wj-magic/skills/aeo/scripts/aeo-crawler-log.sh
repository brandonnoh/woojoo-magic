#!/usr/bin/env bash
# aeo-crawler-log.sh — 액세스 로그에서 AI 크롤러 히트를 집계한다 (측정 루프의 1차 데이터원)
#
# 사용법:
#   bash aeo-crawler-log.sh /var/log/nginx/access.log --out .dev/aeo/crawlers.json
#   zcat logs/*.gz | bash aeo-crawler-log.sh - --out .dev/aeo/crawlers.json
#   bash aeo-crawler-log.sh access.log --format json --ua-field http_user_agent
#
# 지원 형식: combined(기본), json(한 줄당 JSON 오브젝트)
set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aeo-lib.sh
source "${_script_dir}/aeo-lib.sh"

aeo_require python3

_source="-"
_out=".dev/aeo/crawlers.json"
_format="combined"
_ua_field="http_user_agent"
_top=15

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) _out="$2"; shift 2 ;;
    --format) _format="$2"; shift 2 ;;
    --ua-field) _ua_field="$2"; shift 2 ;;
    --top) _top="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) _source="$1"; shift ;;
  esac
done

mkdir -p "$(dirname "$_out")"

if [[ "$_source" == "-" ]]; then
  python3 "${_script_dir}/aeo-crawler-parse.py" \
    --format "$_format" --ua-field "$_ua_field" --top "$_top" --out "$_out"
else
  [[ -f "$_source" ]] || aeo_die "로그 파일 없음: $_source"
  python3 "${_script_dir}/aeo-crawler-parse.py" \
    --format "$_format" --ua-field "$_ua_field" --top "$_top" --out "$_out" < "$_source"
fi

aeo_log "완료 → ${_out}"
