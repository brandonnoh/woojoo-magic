# fix-iso-inbox: get_iso_now 통합 + inbox-writer hook_source/path 수정

## 배경
`_iw_now_iso`, `_bw_now_iso`, `_tw_now_iso`, `_idx_now_iso` 4개 함수가 동일한 로직으로 중복 구현되어 있다. macOS fallback 방식도 `index-update.sh`에서 date를 2회 호출하는 불일치가 있다.

또한 `inbox-writer.sh`의 두 가지 문제:
1. `hook_source: stop` 하드코딩 → `capture-session-end.sh`가 sed로 사후 패치하는 2-step 구조
2. inbox 경로 `${HOME}/.studybook/inbox` 하드코딩 → `STUDYBOOK_HOME` 테스트 격리 불가

## 현재 코드 구조

### config-helpers.sh (88줄)
- 줄 20-27: `get_studybook_dir()` — STUDYBOOK_HOME 우선, 없으면 ~/.studybook
- get_iso_now() 없음

### inbox-writer.sh (136줄)
- 줄 38-46: `_iw_ensure_dir()` — `_dir="${HOME}/.studybook/inbox"` 하드코딩 (줄 40)
- 줄 49-55: `_iw_now_iso()` — date -Iseconds fallback
- 줄 76: `printf 'hook_source: %s\n' "stop"` 하드코딩

### book-writer.sh
- 줄 15: `_bw_now_iso()` — date -Iseconds fallback

### topic-writer.sh
- 줄 68: `_tw_now_iso()` — date -Iseconds fallback

### index-update.sh
- 줄 9: `_idx_now_iso()` — date -Iseconds를 2회 호출하는 불일치 패턴

## 변경 범위
| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| `lib/config-helpers.sh` | 추가 | 줄 88 뒤에 `get_iso_now()` 함수 추가 |
| `lib/inbox-writer.sh` | 수정 | 줄 40: HOME 하드코딩 → get_studybook_dir() 사용 |
| `lib/inbox-writer.sh` | 수정 | 줄 49-55: _iw_now_iso() 제거 → get_iso_now 호출 |
| `lib/inbox-writer.sh` | 수정 | 줄 76: "stop" 하드코딩 → "${WJ_SB_HOOK_SOURCE:-stop}" |
| `lib/book-writer.sh` | 수정 | _bw_now_iso() 제거 → get_iso_now 호출 |
| `lib/topic-writer.sh` | 수정 | _tw_now_iso() 제거 → get_iso_now 호출 |
| `lib/index-update.sh` | 수정 | _idx_now_iso() 제거 → get_iso_now 호출 |

## 구현 방향

### config-helpers.sh에 추가 (줄 88 뒤)
```bash
# get_iso_now — ISO8601 현재 시각 (macOS/Linux 공통)
get_iso_now() {
  if date -Iseconds >/dev/null 2>&1; then
    date -Iseconds
  else
    date +"%Y-%m-%dT%H:%M:%S%z"
  fi
}
```

### inbox-writer.sh 변경

줄 38-46 (`_iw_ensure_dir`):
```bash
# Before
_dir="${HOME}/.studybook/inbox"

# After
_dir="$(get_studybook_dir)/inbox"
```

줄 49-55 (`_iw_now_iso` → 제거):
```bash
# Before
_iw_now_iso() {
  if date -Iseconds >/dev/null 2>&1; then
    date -Iseconds
  else
    date +"%Y-%m-%dT%H:%M:%S%z"
  fi
}

# After: 함수 완전 제거
```

줄 126 (`_now=$(_iw_now_iso)` → 교체):
```bash
# After
_now=$(get_iso_now)
```

줄 76 (hook_source):
```bash
# Before
printf 'hook_source: %s\n'    "stop"

# After
printf 'hook_source: %s\n'    "${WJ_SB_HOOK_SOURCE:-stop}"
```

### book-writer.sh, topic-writer.sh, index-update.sh
각 파일에서:
1. `_XXX_now_iso()` 함수 블록 전체 제거
2. `_XXX_now_iso` 호출 → `get_iso_now` 로 교체
3. config-helpers.sh가 source되어 있는지 확인 (없으면 source 추가)

## 의존 관계
- `inbox-writer.sh`를 source하는 곳: `hooks/capture-stop.sh`, `hooks/capture-session-end.sh`, `lib/backfill.sh`
- `config-helpers.sh`를 source하는 곳: 다수 lib 파일
- 이 변경에 영향받는 task: `fix-capture-bugs` (sed 패치 제거 가능해짐)

## 검증 명령
```bash
bash -n src/wj-studybook/lib/config-helpers.sh
bash -n src/wj-studybook/lib/inbox-writer.sh
bash -n src/wj-studybook/lib/book-writer.sh
bash -n src/wj-studybook/lib/topic-writer.sh
bash -n src/wj-studybook/lib/index-update.sh
grep -c "get_iso_now" src/wj-studybook/lib/config-helpers.sh  # 1
grep "_iw_now_iso\|_bw_now_iso\|_tw_now_iso\|_idx_now_iso" src/wj-studybook/lib/*.sh  # 0 results
grep "WJ_SB_HOOK_SOURCE" src/wj-studybook/lib/inbox-writer.sh  # 1 result
grep 'HOME.*studybook.*inbox' src/wj-studybook/lib/inbox-writer.sh  # 0 results
```
