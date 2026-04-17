---
description: 동의어 주제 폴더 탐지 + 병합
argument-hint: "[--auto-detect | <from_dir> <to_dir> [--yes] | apply <from> <to> [--yes]]"
---

`$ARGUMENTS`를 파싱해 서브커맨드로 분기:

| 명령 | 동작 |
|------|------|
| (인자 없음) / --auto-detect / detect / prepare | 동의어 폴더 탐지 컨텍스트 출력 |
| apply \<from\> \<to\> [--yes] | 지정된 두 폴더를 병합 (from -> to) |
| \<from_dir\> \<to_dir\> [--yes] | 사용자 확인 후 병합 |

## 라우팅

```bash
set -euo pipefail
_args="${ARGUMENTS:-}"
_a1="$(printf '%s\n' "$_args" | awk '{print $1}')"
_a2="$(printf '%s\n' "$_args" | awk '{print $2}')"
_a3="$(printf '%s\n' "$_args" | awk '{print $3}')"
_a4="$(printf '%s\n' "$_args" | awk '{print $4}')"

# shellcheck source=/dev/null
. "${CLAUDE_PLUGIN_ROOT}/lib/merge.sh"

case "$_a1" in
  ""|detect|prepare|--auto-detect)
    merge_detect_prepare
    ;;
  apply)
    merge_apply "$_a2" "$_a3" "${_a4:-}"
    ;;
  *)
    # 기본: _a1이 경로 형태(<from>) -> apply 흐름
    merge_apply "$_a1" "$_a2" "${_a3:-}"
    ;;
esac
```

## Claude 작업 지시

`/wj-studybook:merge` 또는 `/wj-studybook:merge --auto-detect` 실행 시 Claude(본 세션)는 다음을 수행한다:

1. 기본 라우팅은 `merge_detect_prepare`를 실행해 Claude에 전달할 컨텍스트를 stdout으로 출력한다.
   -> 출력에는 `ACTIVE_PROFILE`, `TREE_DUMP`, `FOLDERS` (경로 + 노트 수), `FOLDER_COUNT`, `INSTRUCTIONS`
   섹션이 포함된다.
2. Claude는 `FOLDERS` 목록에서 동의어/유사 주제 폴더 쌍(예: `react <-> 리액트`, `dp <-> 다이나믹프로그래밍`)을
   찾아 아래 JSON 배열 형식으로 후보를 제안한다:
   ```json
   [
     {
       "a": "<경로 A>",
       "b": "<경로 B>",
       "reason": "<왜 동의어/유사한지>",
       "confidence": 0-100
     }
   ]
   ```
3. 각 후보에 대해 사용자에게 `'A (N개) <-> B (M개) -- 병합?`으로 확인을 받는다. y인 경우:
   - 노트가 더 많은 쪽을 `to`, 나머지를 `from`으로 결정
   - `/wj-studybook:merge <from> <to> --yes` 호출로 실제 병합 실행
   -> `merge_apply`가 mv, frontmatter 갱신, `update_index_on_move`, 빈 폴더 삭제를 모두 처리한다.

직접 호출용 서브커맨드:
- `/wj-studybook:merge --auto-detect` -- Claude용 탐지 컨텍스트 출력 (기본 동작과 동일)
- `/wj-studybook:merge <from_dir> <to_dir>` -- 사용자 확인 후 병합
- `/wj-studybook:merge <from_dir> <to_dir> --yes` -- 확인 없이 강제 병합 (테스트/자동화용)
