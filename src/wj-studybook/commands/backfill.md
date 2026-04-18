---
description: 과거 Claude Code 세션 소급 수집
argument-hint: "--since <YYYY-MM-DD> [--project <name> | --all]"
---

아래 스크립트를 실행하고 **출력 결과를 그대로 사용자에게 보여주세요.**

`$ARGUMENTS`를 파싱해 `lib/backfill.sh`에 전달:

| 명령 | 동작 |
|------|------|
| --since \<YYYY-MM-DD\> | 지정 날짜 이후 세션을 inbox에 소급 수집 |
| --project \<name\> | 특정 프로젝트만 대상 |
| --all | 전체 프로젝트 대상 |

## 라우팅

```bash
set -euo pipefail
_args="${ARGUMENTS:-}"
_a1="$(printf '%s\n' "$_args" | awk '{print $1}')"
_a2="$(printf '%s\n' "$_args" | awk '{print $2}')"
_a3="$(printf '%s\n' "$_args" | awk '{print $3}')"
_a4="$(printf '%s\n' "$_args" | awk '{print $4}')"

# shellcheck source=/dev/null
. "${CLAUDE_PLUGIN_ROOT}/lib/backfill.sh"

_bf_argv=()
for _bf_t in "$_a1" "$_a2" "$_a3" "$_a4"; do
  [ -n "$_bf_t" ] && _bf_argv+=("$_bf_t")
done
backfill_run "${_bf_argv[@]}"
```
