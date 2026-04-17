# fix-capture-bugs: capture-session-end.sh dedup hash 통일 + tmp trap + sed 패치 제거

## 배경
3개 독립 버그가 capture-session-end.sh에 집중되어 있다.

1. **dedup hash 불일치**: Stop hook이 저장한 파일을 SessionEnd가 중복 인식 못하고 재저장. hash 계산 방식의 trailing whitespace 처리 불일치가 원인.
2. **tmp 파일 누출**: sed 패치 실패 시 `.tmp.$$` 고아 파일 남음.
3. **sed 2-step 패치 제거**: fix-iso-inbox 완료 후 inbox-writer가 WJ_SB_HOOK_SOURCE를 직접 지원하므로 sed 패치가 불필요.

추가: `.git` 디렉토리 체크가 git worktree에서 실패.

## 현재 코드 구조 (capture-session-end.sh, 212줄)

- 줄 59-62: `_cse_hash_text()` — `printf '%s' "$1" | shasum -a 256`
- 줄 65-83: `_cse_build_inbox_hash_index()` — awk로 frontmatter 제거 후 hash
  - 줄 72-78: awk 추출 (awk는 각 줄에 \n 추가)
  - 줄 79: `sed '1{/^$/d;}'` 로 첫 빈 줄 제거
  - 줄 81: `_cse_hash_text "$_body"` 호출
- 줄 90: `if [ -n "$_cwd" ] && [ -d "$_cwd/.git" ]` — worktree 미지원
- 줄 141-145: sed hook_source 패치 블록
  ```bash
  _tmp="${_out}.tmp.$$"
  sed 's/^hook_source: stop$/hook_source: session_end/' "$_out" > "$_tmp" \
    && mv "$_tmp" "$_out"
  ```
- 줄 129: `WJ_SB_HOOK_SOURCE="session_end"` 환경변수 설정 후 write_inbox_note 호출

## hash 불일치 원인 분석
- `write_inbox_note`가 파일에 저장: `printf '\n%s\n' "$_content"` (trailing \n 포함)
- awk 추출 + 명령치환: trailing newline 제거됨 → `_body = "\ncontent"` → sed → `"content"`
- `_cse_hash_text "$_redacted"`: `printf '%s' "$_redacted"` 로 계산
- 두 경로가 동일 문자열이면 hash가 일치해야 하지만, `_redacted` 자체가 trailing \n을 포함할 경우 불일치:
  - 파일 저장: `content\n` → 파일 body: `\ncontent\n\n` → 추출: `content` → hash(`content`)
  - 직접 계산: hash(`content\n`) ≠ hash(`content`)

## 변경 범위
| 파일 | 변경 유형 | 줄 범위 | 내용 |
|------|----------|---------|------|
| `hooks/capture-session-end.sh` | 수정 | 59-62 | `_cse_hash_text`: trailing whitespace strip 추가 |
| `hooks/capture-session-end.sh` | 수정 | 79 | `_cse_build_inbox_hash_index` body 추출에도 동일 strip |
| `hooks/capture-session-end.sh` | 수정 | 90 | `[ -d "$_cwd/.git" ]` → `git -C "$_cwd" rev-parse --git-dir >/dev/null 2>&1` |
| `hooks/capture-session-end.sh` | 삭제 | 141-145 | sed hook_source 패치 블록 제거 (WJ_SB_HOOK_SOURCE 직접 지원으로 불필요) |
| `hooks/capture-session-end.sh` | 수정 | 143 | tmp 있던 자리에 trap 추가 (다른 tmp 사용처 있으면) |

## 구현 방향

### _cse_hash_text 수정 (줄 59-62)
```bash
# Before
_cse_hash_text() {
  set -u
  printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
}

# After: trailing whitespace/newline 정규화
_cse_hash_text() {
  set -u
  printf '%s' "$1" | sed 's/[[:space:]]*$//' | shasum -a 256 | awk '{print $1}'
}
```

### _cse_build_inbox_hash_index body 추출 (줄 79)
```bash
# Before
_body=$(printf '%s' "$_body" | sed '1{/^$/d;}')

# After: 첫 빈줄 제거 + trailing whitespace 정규화 (두 sed 병합 가능)
_body=$(printf '%s' "$_body" | sed '1{/^$/d;}' | sed 's/[[:space:]]*$//')
```

### worktree branch 검출 (줄 90)
```bash
# Before
if [ -n "$_cwd" ] && [ -d "$_cwd/.git" ]; then

# After
if [ -n "$_cwd" ] && git -C "$_cwd" rev-parse --git-dir >/dev/null 2>&1; then
```

### sed 패치 블록 제거 (줄 141-145)
```bash
# Before (제거 대상)
if [ -f "$_out" ]; then
  _tmp="${_out}.tmp.$$"
  sed 's/^hook_source: stop$/hook_source: session_end/' "$_out" > "$_tmp" \
    && mv "$_tmp" "$_out"
  update_tree_unsorted_increment 2>/dev/null || true
  ...
fi

# After: sed 패치 없이 직접 처리 (write_inbox_note이 WJ_SB_HOOK_SOURCE=session_end로 올바르게 기록)
if [ -f "$_out" ]; then
  update_tree_unsorted_increment 2>/dev/null || true
  ...
fi
```

## 의존 관계
- **depends_on**: fix-iso-inbox (inbox-writer.sh가 WJ_SB_HOOK_SOURCE를 지원해야 sed 패치 제거 가능)
- `_bf_hash_text` (backfill.sh)도 동일한 정규화 적용 필요 → fix-backfill-bugs가 이 방식을 따름

## 검증 명령
```bash
bash -n src/wj-studybook/hooks/capture-session-end.sh
grep "sed.*hook_source" src/wj-studybook/hooks/capture-session-end.sh  # 0 결과 (패치 제거됨)
grep "rev-parse" src/wj-studybook/hooks/capture-session-end.sh  # 1 결과 (worktree 수정됨)
grep "space.*\$\|\\\\s\*\$" src/wj-studybook/hooks/capture-session-end.sh  # trailing strip 존재
```
