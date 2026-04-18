---
description: 학습 분류 트리 ASCII 시각화
argument-hint: "[--depth <N> | --json]"
---

아래 스크립트를 실행하고 **출력 결과를 그대로 사용자에게 보여주세요.**

`$ARGUMENTS`를 파싱해 `lib/tree-view.sh`에 전달:

| 명령 | 동작 |
|------|------|
| (인자 없음) | 기본 depth(3)로 ASCII 트리 출력 |
| --depth \<N\> | 깊이 N까지 트리 출력 |
| --json | JSON 형식으로 출력 |

## 라우팅

```bash
set -euo pipefail
_args="${ARGUMENTS:-}"
_a1="$(printf '%s\n' "$_args" | awk '{print $1}')"
_a2="$(printf '%s\n' "$_args" | awk '{print $2}')"
_a3="$(printf '%s\n' "$_args" | awk '{print $3}')"

# shellcheck source=/dev/null
. "${CLAUDE_PLUGIN_ROOT}/lib/tree-view.sh"

_tv_argv=()
for _tv_t in "$_a1" "$_a2" "$_a3"; do
  [ -n "$_tv_t" ] && _tv_argv+=("$_tv_t")
done
tree_cli "${_tv_argv[@]}"
```
