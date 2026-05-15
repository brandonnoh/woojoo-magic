#!/usr/bin/env bash
# wj-magic v3: 세션 시작 부트스트랩
# - 프로젝트에 파일을 복사하지 않음
# - .gitignore, .mcp.json을 수정하지 않음
# - 자동 git commit을 하지 않음
#
# 비활성화: WOOJOO_MAGIC_SKIP_BOOTSTRAP=1
set -euo pipefail

if [[ "${WOOJOO_MAGIC_SKIP_BOOTSTRAP:-0}" == "1" ]]; then
  exit 0
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# .dev/state/ 디렉토리 보장 (Stop hook loop에 필요)
if [[ -d "${PROJECT_ROOT}/.dev" ]]; then
  mkdir -p "${PROJECT_ROOT}/.dev/state"
  mkdir -p "${PROJECT_ROOT}/.dev/journal"
fi

# 플러그인 구버전 캐시 자동 정리 (GC)
# Claude Code 플러그인 시스템에 자동 GC가 없어서 버전업마다 구버전이 누적됨
_wj_cache="${HOME}/.claude/plugins/cache/wj-tools"
if [[ -d "$_wj_cache" ]]; then
  _installed="${HOME}/.claude/plugins/installed_plugins.json"
  if [[ -f "$_installed" ]]; then
    for _plugin_dir in "$_wj_cache"/*/; do
      _plugin_name="$(basename "$_plugin_dir")"
      _cur_ver="$(python3 -c "
import json, sys
d = json.load(open('$_installed'))
for p in d.get('plugins',{}).get('${_plugin_name}@wj-tools',[]):
  print(p.get('version','')); break
" 2>/dev/null || true)"
      [[ -z "$_cur_ver" ]] && continue
      for _ver_dir in "$_plugin_dir"/*/; do
        [[ "$(basename "$_ver_dir")" == "$_cur_ver" ]] && continue
        rm -rf "$_ver_dir" 2>/dev/null || true
      done
    done
  fi
fi

exit 0
