---
description: 세션 자동 학습 노트화 — config/digest/publish/similar/merge/backfill/tree/sync
argument-hint: "config [init|profile list|profile use <n>|profile new|profile delete <n> [--purge|--keep-books]|set <k.p> <v>|edit] | digest | publish weekly | similar <쿼리> | tree"
---

`$ARGUMENTS`를 파싱해 첫 단어로 분기:

| 명령 | 동작 | 구현 task |
|------|------|----------|
| config init | 프로필 마법사 | s6 |
| config | 활성 프로필 + 전역 설정 yaml dump | s8 |
| config profile list | 프로필 목록 + ★ 활성 표시 | s7 |
| config profile use \<name\> | active_profile 갱신 | s7 |
| config profile new | 신규 프로필 마법사 | s7 |
| config profile delete \<name\> [--purge\|--keep-books] | 프로필 삭제 | s7 |
| config set \<key.path\> \<value\> | 활성 프로필 yaml 단일 값 변경 | s8 |
| config edit | $EDITOR로 활성 프로필 yaml 편집 | s8 |
| digest | inbox → topics 분류 | s10 |
| similar \<쿼리\> | 유사 노트 검색 (ripgrep + Claude 의미 유사도) | s11 |
| publish weekly | 주간 책 발간 (prepare → Claude → apply) | s13 |
| publish monthly | 월간 책 발간 | s13 |
| merge [--auto-detect] | 동의어 주제 폴더 탐지 컨텍스트 출력 | s12 |
| merge \<from\> \<to\> [--yes] | from 폴더의 모든 노트를 to로 병합 | s12 |
| backfill --since \<날짜\> | 과거 세션 소급 | s14 |
| tree | 분류 트리 시각화 | s15 |
| sync | 동기화 경로 안내 | s16 |

각 서브커맨드는 `${CLAUDE_PLUGIN_ROOT}/lib/<feature>.sh`로 위임.

## 라우팅

```bash
set -euo pipefail
_args="${ARGUMENTS:-}"
# 토큰화 (POSIX awk)
_a1="$(printf '%s\n' "$_args" | awk '{print $1}')"
_a2="$(printf '%s\n' "$_args" | awk '{print $2}')"
_a3="$(printf '%s\n' "$_args" | awk '{print $3}')"
_a4="$(printf '%s\n' "$_args" | awk '{print $4}')"
_a5="$(printf '%s\n' "$_args" | awk '{print $5}')"

case "$_a1" in
  config)
    case "$_a2" in
      init)
        # shellcheck source=/dev/null
        . "${CLAUDE_PLUGIN_ROOT}/lib/config-wizard.sh"
        wizard_main
        ;;
      profile)
        # shellcheck source=/dev/null
        . "${CLAUDE_PLUGIN_ROOT}/lib/profile-mgmt.sh"
        case "$_a3" in
          list)   profile_list ;;
          use)    profile_use "$_a4" ;;
          new)    profile_new ;;
          delete) profile_delete "$_a4" "${_a5:---keep-books}" ;;
          *)
            echo "사용법: config profile {list|use <name>|new|delete <name> [--purge|--keep-books]}" >&2
            exit 2
            ;;
        esac
        ;;
      set)
        # shellcheck source=/dev/null
        . "${CLAUDE_PLUGIN_ROOT}/lib/config-set.sh"
        config_set "$_a3" "$_a4"
        ;;
      edit)
        # shellcheck source=/dev/null
        . "${CLAUDE_PLUGIN_ROOT}/lib/config-set.sh"
        config_edit
        ;;
      ""|*)
        # 인자 없음 → show
        # shellcheck source=/dev/null
        . "${CLAUDE_PLUGIN_ROOT}/lib/config-set.sh"
        config_show
        ;;
    esac
    ;;
  digest)
    # digest는 Claude(메인 세션)가 수행하는 2-step.
    # 이 branch는 "준비 컨텍스트"를 stdout으로 출력한다.
    # Claude는 아래 instruction을 읽고 분류 → 임시 JSON 파일 작성 → `digest apply <file>` 재호출.
    case "$_a2" in
      apply)
        # shellcheck source=/dev/null
        . "${CLAUDE_PLUGIN_ROOT}/lib/digest.sh"
        digest_apply "$_a3"
        ;;
      prepare|"")
        # shellcheck source=/dev/null
        . "${CLAUDE_PLUGIN_ROOT}/lib/digest.sh"
        digest_prepare
        ;;
      *)
        echo "사용법: digest [prepare|apply <json>]" >&2
        exit 2
        ;;
    esac
    ;;
  similar)
    # similar는 Claude(메인 세션)가 수행하는 2-step.
    # 1) keyword: ripgrep 1차 매칭 (후보 경로 목록)
    # 2) prepare: 후보 + tree.json을 Claude 컨텍스트로 패키징 → Claude가 Top 5 점수/요약 JSON 산출
    # 3) format:  Claude 결과 JSON을 사람 친화 포맷으로 출력
    # 쿼리는 _a2부터 끝까지 (공백 포함)
    _simq="$(printf '%s\n' "$_args" | awk '{ $1=""; sub(/^[[:space:]]+/,""); print }')"
    case "$_a2" in
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
        # _a3 이후는 JSON 파일 경로
        _simf="$_a3"
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
    ;;
  merge)
    # merge는 Claude(메인 세션)가 수행하는 2-step.
    # - detect|prepare (또는 --auto-detect): tree + FOLDERS 목록을 Claude 컨텍스트로 패키징
    # - apply <from> <to> [--yes]: 지정된 두 폴더를 병합 (from → to)
    # shellcheck source=/dev/null
    . "${CLAUDE_PLUGIN_ROOT}/lib/merge.sh"
    case "$_a2" in
      ""|detect|prepare|--auto-detect)
        merge_detect_prepare
        ;;
      apply)
        merge_apply "$_a3" "$_a4" "${_a5:-}"
        ;;
      *)
        # 기본: _a2가 경로 형태(<from>) → apply 흐름
        merge_apply "$_a2" "$_a3" "${_a4:-}"
        ;;
    esac
    ;;
  publish)
    # publish는 Claude(메인 세션)가 수행하는 2-step.
    # - prepare <weekly|monthly> (기본): 기간 내 노트 + 프로필을 Claude 컨텍스트로 패키징
    # - apply <json_file> <weekly|monthly>: Claude 결과 JSON → 책 파일 + 노트 published_in[] 갱신
    # shellcheck source=/dev/null
    . "${CLAUDE_PLUGIN_ROOT}/lib/publish.sh"
    case "$_a2" in
      ""|weekly|monthly)
        # 인자 없으면 weekly 기본
        _pbk="${_a2:-weekly}"
        case "$_a3" in
          apply)
            publish_apply "$_a4" "$_pbk"
            ;;
          prepare|"")
            publish_prepare "$_pbk"
            ;;
          *)
            echo "사용법: publish <weekly|monthly> [prepare|apply <json>]" >&2
            exit 2
            ;;
        esac
        ;;
      apply)
        # publish apply <json> <weekly|monthly>
        publish_apply "$_a3" "$_a4"
        ;;
      prepare)
        # publish prepare <weekly|monthly>
        publish_prepare "$_a3"
        ;;
      *)
        echo "사용법: publish <weekly|monthly> [prepare|apply <json>]" >&2
        exit 2
        ;;
    esac
    ;;
  *)
    echo "지원하지 않는 명령: $_args" >&2
    echo "사용 가능: config [init|profile ...|set ...|edit] | digest | similar <쿼리> | merge [--auto-detect|<from> <to> [--yes]] (이후 task에서 추가)" >&2
    exit 2
    ;;
esac
```

## digest 분기 Claude 작업 지시

`/wj:studybook digest` 실행 시 Claude(본 세션)는 다음을 수행한다:

1. `bash ${CLAUDE_PLUGIN_ROOT}/lib/digest.sh` 소스 후 `digest_prepare` 호출 —
   또는 슬래시 커맨드 라우팅(`digest` 또는 `digest prepare`)으로 동일 결과 획득.
   → 출력에는 `ACTIVE_PROFILE`, `PROFILE_YAML`, `CURRENT_TREE_JSON`, `INBOX_NOTES`, `INBOX_COUNT` 섹션이 포함된다.
2. 컨텍스트를 읽고 각 `INBOX_BEGIN ... INBOX_END` 블록을 분류. 원칙:
   - `CURRENT_TREE_JSON`의 기존 카테고리를 우선 재사용하고 신설은 보수적으로.
   - 프로필 `level`/`language`/`tone`에 맞춰 `body`를 다듬는다.
   - 본문 끝 `## 내 말로 정리` 섹션은 `topic-writer.sh`가 자동 삽입하므로 Claude가 추가할 필요 없음.
3. 결과를 아래 JSON 배열 형식으로 작성:
   ```json
   [
     {
       "inbox_id": "<inbox 노트의 id 값>",
       "category": "<top>",
       "subcategory": "<mid>",
       "topic": "<leaf>",
       "subtopic": "<optional>",
       "title": "<한 줄 제목>",
       "slug": "<kebab-case 영문 slug>",
       "tags": ["tag1", "tag2"],
       "body": "<학습자 수준에 맞춘 본문 markdown (Generation Effect 슬롯 제외)>"
     }
   ]
   ```
4. JSON을 임시 파일에 저장한 뒤 `/wj:studybook digest apply <tmp_file>` 호출로 파일 시스템에 적용.
   → `digest_apply`가 topic 노트 생성, `sources[]` 누적, inbox/processed 이동, `update_index_on_add`, `unsorted_count` 감소를 모두 처리한다.

호출 방식 선택 (spec 기준):
- `INBOX_COUNT` ≤ 20 → 메인 세션에서 즉시 분류.
- `INBOX_COUNT` > 20 → Task(Agent) 도구로 subagent에 위임.

## similar 분기 Claude 작업 지시

`/wj:studybook similar <쿼리>` 실행 시 Claude(본 세션)는 다음을 수행한다:

1. 라우팅 기본(인자를 쿼리로 해석)은 `similar_keyword_match | similar_semantic_rank` 파이프를
   실행해 Claude에 전달할 컨텍스트를 stdout으로 출력한다.
   → 출력에는 `QUERY`, `CURRENT_TREE_JSON`, `CANDIDATES` (`CANDIDATE_BEGIN` / `CANDIDATE_END` 블록),
   `CANDIDATE_COUNT` 섹션이 포함된다.
2. Claude는 컨텍스트를 읽고 각 `CANDIDATE_BEGIN ... CANDIDATE_END` 블록을 쿼리와의 의미적 유사도로
   평가한다. 원칙:
   - `path`, `title`, 본문 스니펫(첫 200자)을 근거로 0–100 점수 산정.
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
4. JSON을 임시 파일에 저장한 뒤 `/wj:studybook similar format <tmp_file>`로 사람 친화 출력을 얻는다.
   → `similar_format_output`이 score desc 정렬, Top 5 제한, `경로 (xx%) — 요약` 포맷팅을 처리한다.

직접 호출용 서브커맨드:
- `/wj:studybook similar keyword <쿼리>` — 1차 ripgrep 매칭 경로만 출력
- `/wj:studybook similar prepare <쿼리>` — 2차 Claude 컨텍스트 (QUERY + CANDIDATES + TREE) 출력
- `/wj:studybook similar format <json_file>` — Claude 결과 JSON → 사람 친화 출력

## merge 분기 Claude 작업 지시

`/wj:studybook merge` 또는 `/wj:studybook merge --auto-detect` 실행 시 Claude(본 세션)는 다음을 수행한다:

1. 기본 라우팅은 `merge_detect_prepare`를 실행해 Claude에 전달할 컨텍스트를 stdout으로 출력한다.
   → 출력에는 `ACTIVE_PROFILE`, `TREE_DUMP`, `FOLDERS` (경로 + 노트 수), `FOLDER_COUNT`, `INSTRUCTIONS`
   섹션이 포함된다.
2. Claude는 `FOLDERS` 목록에서 동의어/유사 주제 폴더 쌍(예: `react ↔ 리액트`, `dp ↔ 다이나믹프로그래밍`)을
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
3. 각 후보에 대해 사용자에게 `'A (N개) ↔ B (M개) — 병합?`으로 확인을 받는다. y인 경우:
   - 노트가 더 많은 쪽을 `to`, 나머지를 `from`으로 결정
   - `/wj:studybook merge <from> <to> --yes` 호출로 실제 병합 실행
   → `merge_apply`가 mv, frontmatter 갱신, `update_index_on_move`, 빈 폴더 삭제를 모두 처리한다.

직접 호출용 서브커맨드:
- `/wj:studybook merge --auto-detect` — Claude용 탐지 컨텍스트 출력 (기본 동작과 동일)
- `/wj:studybook merge <from_dir> <to_dir>` — 사용자 확인 후 병합
- `/wj:studybook merge <from_dir> <to_dir> --yes` — 확인 없이 강제 병합 (테스트/자동화용)

## publish 분기 Claude 작업 지시

`/wj:studybook publish weekly` 또는 `/wj:studybook publish monthly` 실행 시 Claude(본 세션)는 다음을 수행한다:

1. 기본 라우팅은 `publish_prepare <weekly|monthly>`를 실행해 Claude에 전달할 컨텍스트를 stdout으로 출력한다.
   → 출력에는 `ACTIVE_PROFILE`, `PROFILE_YAML`, `BOOK_KIND`, `PERIOD_START`, `PERIOD_END`,
   `NOTES` (`NOTE_BEGIN` / `NOTE_END` 블록), `NOTE_COUNT`, `INSTRUCTIONS`, `OUTPUT_TEMPLATE` 섹션이 포함된다.
2. Claude는 PROFILE_YAML의 `level/tone/language/age_group/book_style`에 맞춰 `NOTES`를
   한 권의 책으로 다듬는다. 원칙:
   - 관련 주제를 챕터로 묶고 입문 → 심화 순서로 재배치
   - 각 챕터에 도입글 + 원본 노트 본문 통합
   - 원본 노트의 `## 내 말로 정리` 사용자 주석이 있으면 "#### 내 말로 정리"로 보존
   - `level=child/beginner`: 친절한 비유, 쉬운 어휘 / `level=advanced`: 간결/전문 톤
3. 결과를 아래 JSON 형식으로 작성:
   ```json
   {
     "title": "<책 제목>",
     "body":  "<OUTPUT_TEMPLATE 구조의 markdown 본문>",
     "chapters": [
       {"title": "<챕터 제목>", "note_ids": ["<ulid>", ...]}
     ],
     "note_paths": ["<NOTE_BEGIN path= 의 경로 그대로>", ...]
   }
   ```
4. JSON을 임시 파일에 저장한 뒤 `/wj:studybook publish apply <tmp_file> <weekly|monthly>` 호출로 파일 시스템에 적용.
   → `publish_apply`가 `books/<profile>/<weekly|monthly>/<slug>.md` 생성, frontmatter(stats 자동 계산 + chapters) 작성,
   각 노트의 `published_in[]` 역참조 추가를 모두 처리한다.

직접 호출용 서브커맨드:
- `/wj:studybook publish weekly` / `publish weekly prepare` — 주간 발간 컨텍스트 출력
- `/wj:studybook publish monthly` / `publish monthly prepare` — 월간 발간 컨텍스트 출력
- `/wj:studybook publish apply <json_file> <weekly|monthly>` — Claude 결과 적용
