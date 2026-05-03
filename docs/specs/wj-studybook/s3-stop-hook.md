# s3-stop-hook: Stop hook으로 어시스턴트 발화 추출 → inbox 저장

## 배경
플러그인의 핵심 데이터 수집 시작점. Claude의 매 응답 종료 시 자동으로 트리거되어, 어시스턴트가 방금 한 설명을 inbox에 markdown으로 저장한다. 사용자는 아무것도 하지 않음 (invisible by default).

## 현재 상태
- wj 플러그인이 이미 Stop hook 등록 (`src/wj-magic/hooks/stop-loop.sh`)
- 우리 hook은 별도 명령으로 등록되어 순차 실행됨 (충돌 X)

## Stop hook 입력 JSON 구조 (Claude Code 공식)

```json
{
  "session_id": "7f3a5e12-...",
  "transcript_path": "/Users/woojoo/.claude/projects/-Users-.../<sid>.jsonl",
  "cwd": "/Users/woojoo/Documents/GitHub/woojoo-magic",
  "last_assistant_message": "...전체 텍스트..."
}
```

→ **`last_assistant_message` 필드만 사용하면 transcript JSONL 파싱 불필요**.
- fallback: 필드가 없으면 transcript_path에서 마지막 assistant text 블록 추출

## 변경 범위

| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| `src/wj-studybook/hooks/capture-stop.sh` | 신규 | 메인 스크립트 |
| `src/wj-studybook/hooks/hooks.json` | 수정 | Stop hook 등록 |
| `src/wj-studybook/lib/inbox-writer.sh` | 신규 | inbox 파일 쓰기 헬퍼 |
| `tests/wj-studybook/test-capture-stop.bats` | 신규 | 단위 테스트 |

## 구현 방향

### capture-stop.sh (의사 코드)

```bash
#!/usr/bin/env bash
# capture-stop.sh — Stop hook: 어시스턴트 발화 → inbox 저장
set -euo pipefail

_plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${_plugin_root}/lib/schema.sh"
source "${_plugin_root}/lib/inbox-writer.sh"

# Stop hook 입력은 stdin JSON
_input=$(cat)
_session_id=$(jq -r '.session_id // empty' <<< "$_input")
_transcript_path=$(jq -r '.transcript_path // empty' <<< "$_input")
_cwd=$(jq -r '.cwd // empty' <<< "$_input")
_last_msg=$(jq -r '.last_assistant_message // empty' <<< "$_input")

# fallback: last_assistant_message 없으면 transcript에서 추출
if [[ -z "$_last_msg" && -f "$_transcript_path" ]]; then
  _last_msg=$(jq -rs '
    map(select(.type == "assistant"))
    | last
    | .message.content[]
    | select(.type == "text")
    | .text
  ' "$_transcript_path" 2>/dev/null || true)
fi

# 빈 메시지면 종료 (도구 호출만 있던 응답)
[[ -z "$_last_msg" ]] && exit 0

# 사용자 prompt 추출 (직전 user 메시지)
_user_prompt=""
if [[ -f "$_transcript_path" ]]; then
  _user_prompt=$(jq -rs '
    map(select(.type == "user"))
    | last
    | .message.content
  ' "$_transcript_path" 2>/dev/null || true)
fi

# git 정보
_branch=""
[[ -d "$_cwd/.git" ]] && _branch=$(git -C "$_cwd" branch --show-current 2>/dev/null || echo "")
_project_name=$(basename "$_cwd")

# 모델 추출
_model=$(jq -rs '
  map(select(.type == "assistant"))
  | last
  | .message.model
' "$_transcript_path" 2>/dev/null || echo "unknown")

# inbox 저장 (s4의 filter는 이 task에서는 미적용 — 일단 모두 저장)
write_inbox_note \
  --session-id "$_session_id" \
  --project "$_project_name" \
  --project-path "$_cwd" \
  --branch "$_branch" \
  --model "$_model" \
  --user-prompt "$_user_prompt" \
  --content "$_last_msg"

# tree.json의 unsorted_count +1 (s5에서 update_tree_unsorted 함수 호출)
# 이 task에서는 placeholder. s5 완료 후 통합.

exit 0
```

### inbox-writer.sh

```bash
write_inbox_note() {
  local _ulid _filename _now
  _ulid=$(ulid_generate)
  _now=$(date -Iseconds)
  _date=$(date +%Y-%m-%d)
  _inbox_dir="${HOME}/.studybook/inbox"
  mkdir -p "$_inbox_dir"
  _filename="${_inbox_dir}/${_date}-${_ulid}.md"

  # 인자 파싱 (--key value 형식)
  # ... (구현 시 getopts 또는 case 문)

  cat > "$_filename" <<EOF
---
id: $_ulid
schema: studybook.note/v1
type: inbox
status: raw
captured_at: $_now
session_id: $_session_id
project: $_project
project_path: $_project_path
git_branch: $_branch
model: $_model
hook_source: stop
user_prompt: |
  $(echo "$_user_prompt" | sed 's/^/  /')
related_files: []
detected_keywords: []
language_hints: []
estimated_value: null
---

$_content
EOF

  echo "$_filename"
}
```

### hooks.json (수정 후)

```json
{
  "Stop": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/hooks/capture-stop.sh"
        }
      ]
    }
  ],
  "SessionEnd": []
}
```

## 의존 관계

- 이 hook을 source 하는 곳: 없음 (Claude Code 런타임이 직접 실행)
- 사용하는 라이브러리: `lib/schema.sh` (s2), `lib/inbox-writer.sh` (이 task)
- 영향 받는 후속 task: s4(filter 통합), s5(tree.json 갱신 통합), s9(SessionEnd가 보완)
- wj 플러그인의 stop-loop.sh와 충돌 검증: hooks.json 형식상 두 플러그인의 Stop hook이 모두 등록되면 Claude Code가 순차 실행 → 양쪽 다 정상 동작

## 검증 명령

```bash
# 샘플 입력 JSON으로 실행
cat <<'EOF' | bash src/wj-studybook/hooks/capture-stop.sh
{
  "session_id": "test-session",
  "transcript_path": "/dev/null",
  "cwd": "/tmp",
  "last_assistant_message": "useEffect의 클린업 함수는 컴포넌트 언마운트 시..."
}
EOF

# 결과 검증
ls ~/.studybook/inbox/ | head -1
# → 2026-04-16-<ULID>.md 형태

# frontmatter 검증
latest=$(ls -t ~/.studybook/inbox/*.md | head -1)
yq '.schema' "$latest"   # studybook.note/v1
yq '.type' "$latest"     # inbox
yq '.session_id' "$latest"  # test-session

# wj와 공존 검증 (수동: 두 plugin 모두 활성 후 Claude 응답 1회 → 양쪽 hook 모두 실행 확인)

# bats
bats tests/wj-studybook/test-capture-stop.bats
```
