---
description: iCloud/Obsidian/git 동기화 경로 연결 (Local-first)
argument-hint: "[status | --target <icloud|obsidian|git|none> [--vault <path>]]"
---

아래 스크립트를 실행하고 **출력 결과를 그대로 사용자에게 보여주세요.**

`$ARGUMENTS`를 파싱해 `lib/sync.sh`에 전달:

| 명령 | 동작 |
|------|------|
| (인자 없음) | 프로필 sync_to 값대로 실행 |
| status | 현재 symlink 상태 표시 |
| --target icloud | iCloud 경로에 symlink 생성 |
| --target obsidian --vault \<path\> | Obsidian vault에 symlink 생성 |
| --target git | books 디렉토리 git init |
| --target none | 책 경로만 stdout 출력 |

## 라우팅

```bash
set -euo pipefail
_args="${ARGUMENTS:-}"
_a1="$(printf '%s\n' "$_args" | awk '{print $1}')"
_a2="$(printf '%s\n' "$_args" | awk '{print $2}')"
_a3="$(printf '%s\n' "$_args" | awk '{print $3}')"
_a4="$(printf '%s\n' "$_args" | awk '{print $4}')"

# shellcheck source=/dev/null
. "${CLAUDE_PLUGIN_ROOT}/lib/sync.sh"

_sc_argv=()
for _sc_t in "$_a1" "$_a2" "$_a3" "$_a4"; do
  [ -n "$_sc_t" ] && _sc_argv+=("$_sc_t")
done
sync_run "${_sc_argv[@]}"
```

## sync 분기 설명 (s16 -- Local-first)

`/wj-studybook:sync`는 외부 전송을 수행하지 않는다. 오직 **symlink 생성** 또는 **경로 안내**만 한다.
네트워크 호출(curl/wget/ssh/rsync remote)이나 외부 업로드는 구현되지 않는다.

동작 요약:
1. 인자가 없으면 활성 프로필 yaml의 `publish.sync_to` 값을 읽어 분기.
2. `--target <icloud|obsidian|git|none>`로 override 가능.
3. `icloud`: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Studybook/` 우선, 없으면
   `~/Library/Mobile Documents/com~apple~CloudDocs/Studybook/`로 fallback. 둘 다 없으면 수동 생성 안내 + 종료.
   감지되면 해당 경로를 `books/<profile>/`로 symlink.
4. `obsidian --vault <path>`: 필수 옵션. `<vault>/Studybook/` 심볼릭 생성.
5. `git`: `books/<profile>/`에 `git init` (이미 있으면 skip). push는 사용자 수동.
6. `none`: 책 경로만 stdout으로 출력.

안전 제약:
- symlink dst 부모는 반드시 `$HOME` 하위여야 함 (pentest 방지)
- 이미 같은 target의 symlink면 idempotent OK, 다른 target이면 충돌 에러
- 실제 파일/디렉토리가 dst에 있으면 생성 거부
