# fix-backfill-bugs: backfill.sh inbox 경로 하드코딩 + silent catch + hash 정규화

## 배경
3개 독립 버그:
1. inbox 경로 `${HOME}/.studybook/inbox` 하드코딩 → STUDYBOOK_HOME 테스트 격리 불가
2. 줄 251: `2>/dev/null || echo 0` — 세션 처리 실패를 조용히 무시
3. `_bf_hash_text`가 fix-capture-bugs의 `_cse_hash_text`와 다른 정규화 → dedup 불일치 가능성

## 현재 코드 (backfill.sh)

### 줄 54-70: `_bf_build_inbox_hash_index()`
```bash
_bf_dir="${HOME}/.studybook/inbox"   # 줄 56: 하드코딩
```

### 줄 48-51: `_bf_hash_text()`
```bash
_bf_hash_text() {
  printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
}
```

### 줄 251: `_bf_run_loop()`
```bash
_bf_l_n=$(backfill_process_session "$_bf_l_jf" "$_bf_effective_since" 2>/dev/null || echo 0)
```

## 변경 범위
| 파일 | 줄 | 변경 내용 |
|------|---|---------|
| `lib/backfill.sh` | 상단 | config-helpers.sh source 확인/추가 |
| `lib/backfill.sh` | 56 | `${HOME}/.studybook/inbox` → `$(get_studybook_dir)/inbox` |
| `lib/backfill.sh` | 48-51 | `_bf_hash_text`: trailing whitespace strip 추가 (fix-capture-bugs와 동일) |
| `lib/backfill.sh` | 251 | `2>/dev/null || echo 0` 제거 → 실패 시 경고 + continue |

## 구현 방향

### config-helpers.sh source 확인
backfill.sh 상단 source 목록에 config-helpers.sh 없으면 추가:
```bash
source "${_plugin_root}/lib/config-helpers.sh"
```

### 경로 하드코딩 (줄 56)
```bash
# Before
_bf_dir="${HOME}/.studybook/inbox"

# After
_bf_dir="$(get_studybook_dir)/inbox"
```

### hash 정규화 (줄 48-51)
```bash
# Before
_bf_hash_text() {
  printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
}

# After (fix-capture-bugs의 _cse_hash_text와 동일 정규화)
_bf_hash_text() {
  printf '%s' "$1" | sed 's/[[:space:]]*$//' | shasum -a 256 | awk '{print $1}'
}
```

### silent catch 제거 (줄 251)
```bash
# Before
_bf_l_n=$(backfill_process_session "$_bf_l_jf" "$_bf_effective_since" 2>/dev/null || echo 0)

# After
if ! _bf_l_n=$(backfill_process_session "$_bf_l_jf" "$_bf_effective_since"); then
  _bf_err "세션 처리 실패: $_bf_l_jf (skip)"
  continue
fi
_bf_l_n="${_bf_l_n:-0}"
```

## 검증 명령
```bash
bash -n src/wj-studybook/lib/backfill.sh
grep 'HOME.*studybook.*inbox' src/wj-studybook/lib/backfill.sh  # 0 결과
grep 'get_studybook_dir' src/wj-studybook/lib/backfill.sh  # 1+ 결과
grep '2>/dev/null || echo 0' src/wj-studybook/lib/backfill.sh  # 0 결과
```
