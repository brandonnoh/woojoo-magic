---
description: 유사 노트 검색 (ripgrep 1차 + Claude 의미 유사도)
argument-hint: "<쿼리> | keyword <쿼리> | prepare <쿼리> | format <json_file>"
---

`$ARGUMENTS`를 파싱해 서브커맨드로 분기:

| 명령 | 동작 |
|------|------|
| \<쿼리\> | ripgrep 매칭 + Claude 의미 유사도 (기본 흐름) |
| keyword \<쿼리\> | 1차 ripgrep 매칭 경로만 출력 |
| prepare \<쿼리\> | 2차 Claude 컨텍스트 (QUERY + CANDIDATES + TREE) 출력 |
| format \<json_file\> | Claude 결과 JSON -> 사람 친화 출력 |

## 라우팅

```bash
set -euo pipefail
_args="${ARGUMENTS:-}"
_a1="$(printf '%s\n' "$_args" | awk '{print $1}')"
_a2="$(printf '%s\n' "$_args" | awk '{print $2}')"

# 쿼리는 전체 인자 (공백 포함)
_simq="$_args"

case "$_a1" in
  "")
    echo "사용법: similar <쿼리>" >&2
    exit 2
    ;;
  keyword)
    # shellcheck source=/dev/null
    . "${CLAUDE_PLUGIN_ROOT}/lib/similar.sh"
    _simq2="$(printf '%s\n' "$_simq" | awk '{ $1=""; sub(/^[[:space:]]+/,""); print }')"
    similar_keyword_match "$_simq2"
    ;;
  prepare)
    # shellcheck source=/dev/null
    . "${CLAUDE_PLUGIN_ROOT}/lib/similar.sh"
    _simq2="$(printf '%s\n' "$_simq" | awk '{ $1=""; sub(/^[[:space:]]+/,""); print }')"
    similar_keyword_match "$_simq2" | similar_semantic_rank "$_simq2"
    ;;
  format)
    # shellcheck source=/dev/null
    . "${CLAUDE_PLUGIN_ROOT}/lib/similar.sh"
    _simf="$_a2"
    if [ -z "$_simf" ] || [ ! -f "$_simf" ]; then
      echo "사용법: similar format <json_file>" >&2
      exit 2
    fi
    similar_format_output "$(cat "$_simf")"
    ;;
  *)
    # 기본: 쿼리 그대로 prepare 흐름 실행
    # shellcheck source=/dev/null
    . "${CLAUDE_PLUGIN_ROOT}/lib/similar.sh"
    similar_keyword_match "$_simq" | similar_semantic_rank "$_simq"
    ;;
esac
```

## Claude 작업 지시

`/wj-studybook:similar <쿼리>` 실행 시 Claude(본 세션)는 다음을 수행한다:

1. 라우팅 기본(인자를 쿼리로 해석)은 `similar_keyword_match | similar_semantic_rank` 파이프를
   실행해 Claude에 전달할 컨텍스트를 stdout으로 출력한다.
   -> 출력에는 `QUERY`, `CURRENT_TREE_JSON`, `CANDIDATES` (`CANDIDATE_BEGIN` / `CANDIDATE_END` 블록),
   `CANDIDATE_COUNT` 섹션이 포함된다.
2. Claude는 컨텍스트를 읽고 각 `CANDIDATE_BEGIN ... CANDIDATE_END` 블록을 쿼리와의 의미적 유사도로
   평가한다. 원칙:
   - `path`, `title`, 본문 스니펫(첫 200자)을 근거로 0-100 점수 산정.
   - 중복/거의 동일 주제는 묶어 상위로.
   - 후보가 5개 이하이면 전부 반환, 초과면 Top 5만 반환.
3. 결과를 아래 JSON 배열 형식으로 작성:
   ```json
   [
     {
       "path": "<CANDIDATE path 그대로>",
       "score": 0-100,
       "summary": "<한 줄 요약 (왜 유사한지 포함)>"
     }
   ]
   ```
4. JSON을 임시 파일에 저장한 뒤 `/wj-studybook:similar format <tmp_file>`로 사람 친화 출력을 얻는다.
   -> `similar_format_output`이 score desc 정렬, Top 5 제한, `경로 (xx%) -- 요약` 포맷팅을 처리한다.

직접 호출용 서브커맨드:
- `/wj-studybook:similar keyword <쿼리>` -- 1차 ripgrep 매칭 경로만 출력
- `/wj-studybook:similar prepare <쿼리>` -- 2차 Claude 컨텍스트 (QUERY + CANDIDATES + TREE) 출력
- `/wj-studybook:similar format <json_file>` -- Claude 결과 JSON -> 사람 친화 출력
