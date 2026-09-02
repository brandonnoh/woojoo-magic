#!/usr/bin/env bash
# aeo-serve.sh — AEO 대시보드 로컬 서버 (상시 확인용)
#
# 사용법:
#   bash aeo-serve.sh                                  # 기존 대시보드만 서빙
#   bash aeo-serve.sh --url https://example.com \
#        --profile content --interval 600              # 주기 재스캔 + 자동 갱신
#
# 옵션:
#   --port N        기본 8907
#   --dir PATH      서빙 디렉터리 (기본 docs/reports)
#   --state PATH    작업 산출물 경로 (기본 .dev/aeo)
#   --interval N    재스캔 주기(초). 0이면 1회만 (기본 0)
#   --url URL       재스캔 대상. 없으면 재스캔하지 않고 서빙만 한다
set -euo pipefail

_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=aeo-lib.sh
source "${_script_dir}/aeo-lib.sh"

aeo_require python3

_port=8907
_dir="docs/reports"
_state=".dev/aeo"
_interval=0
_url=""
_profile="content"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) _port="$2"; shift 2 ;;
    --dir) _dir="$2"; shift 2 ;;
    --state) _state="$2"; shift 2 ;;
    --interval) _interval="$2"; shift 2 ;;
    --url) _url="$2"; shift 2 ;;
    --profile) _profile="$2"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) aeo_die "알 수 없는 옵션: $1" ;;
  esac
done

mkdir -p "$_dir" "$_state/history"
_page="${_dir}/aeo-dashboard.html"

# 재스캔 → 점수 → 대시보드 갱신 (1 사이클)
refresh_once() {
  [[ -n "$_url" ]] || return 0
  aeo_log "재스캔: $_url"
  bash "${_script_dir}/aeo-scan.sh" "$_url" --out "${_state}/scan.json" || return 0
  python3 "${_script_dir}/aeo-score.py" \
    --scan "${_state}/scan.json" \
    --content "${_state}/content.json" \
    --crawlers "${_state}/crawlers.json" \
    --profile "$_profile" --out "${_state}/score.json" || return 0
  python3 "${_script_dir}/aeo-dashboard.py" \
    --score "${_state}/score.json" --history "${_state}/history" \
    --out "$_page" --snapshot || return 0
}

refresh_once

if [[ ! -f "$_page" ]]; then
  aeo_die "대시보드가 없습니다. 먼저 aeo-dashboard.py로 생성하거나 --url을 주세요."
fi

aeo_log "서버 기동: http://localhost:${_port}/aeo-dashboard.html  (Ctrl-C 종료)"
python3 -m http.server "$_port" --directory "$_dir" >/dev/null 2>&1 &
_server_pid=$!
# shellcheck disable=SC2064
trap "kill ${_server_pid} 2>/dev/null || true" EXIT INT TERM

if [[ "$_interval" -le 0 ]]; then
  wait "$_server_pid"
else
  aeo_log "${_interval}초 주기로 자동 갱신합니다"
  while kill -0 "$_server_pid" 2>/dev/null; do
    sleep "$_interval"
    refresh_once
  done
fi
