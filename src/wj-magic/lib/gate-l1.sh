#!/usr/bin/env bash
# gate-l1.sh — L1 정적 감사 오케스트레이터 (언어별 서브모듈 위임)
# 인자: 파일 목록 (stdin, 한 줄에 하나) 또는 $1로 단일 파일
# 출력: 실패 시 위반 내역을 stdout에 출력하고 exit 1
# 성공 시 exit 0
set -euo pipefail

_l1_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 공통 패턴 라이브러리 로드
source "${_l1_dir}/patterns.sh"

_files=""
if [[ $# -gt 0 && -f "$1" ]]; then
  _files="$1"
else
  _files="$(cat || true)"
fi

[[ -n "$_files" ]] || exit 0

_total_fail=0
_total_messages=""

# 각 언어 서브모듈 source 및 실행
source "${_l1_dir}/gate-l1-ts.sh"
_l1_run_ts "$_files"

source "${_l1_dir}/gate-l1-py.sh"
_l1_run_py "$_files"

source "${_l1_dir}/gate-l1-go.sh"
_l1_run_go "$_files"

source "${_l1_dir}/gate-l1-rs.sh"
_l1_run_rs "$_files"

source "${_l1_dir}/gate-l1-sw.sh"
_l1_run_sw "$_files"

source "${_l1_dir}/gate-l1-kt.sh"
_l1_run_kt "$_files"

source "${_l1_dir}/gate-l1-cc.sh"
_l1_run_cc "$_files"

if (( _total_fail == 1 )); then
  echo "$_total_messages"
  exit 1
fi

echo "[L1] OK"
exit 0
