# s5-index-update: 인덱스 점진 갱신 — _index.md + tree.json 동기화

## 배경 (★ 핵심 task)
**사용자가 명시한 핵심 원칙(P1)**: 매번 전체 폴더 재스캔하면 컨텍스트 폭발 + 성능 저하. 노트가 추가/수정/삭제될 때마다 영향받는 인덱스 파일들만 부분 업데이트한다. Claude에게 분류 컨텍스트 줄 때는 캐시된 `tree.json`만 주입.

이 라이브러리가 잘못 만들어지면 분류 정확도와 검색 성능이 모두 무너진다.

## 변경 범위

| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| `src/wj-studybook/lib/index-update.sh` | 신규 | 점진 갱신 함수 라이브러리 |
| `src/wj-studybook/hooks/capture-stop.sh` | 수정 | inbox 추가 후 tree.json unsorted_count +1 |
| `tests/wj-studybook/test-index-update.bats` | 신규 | 단위 테스트 |

## 데이터 정합성 원칙

1. **단일 진실의 원천**: `_index.md`의 note_count와 `tree.json`의 note_count는 항상 일치해야 함
2. **재귀 갱신**: 자식 폴더 변경 시 부모 폴더 _index.md도 자동 갱신
3. **원자성**: 갱신 도중 실패해도 일관된 상태 (lockfile 또는 임시 파일 + mv)
4. **rebuild 명령 제공**: 정합성 깨졌을 때 전체 재구성 가능 (`update_tree_full_rebuild`)
5. **idempotency**: 같은 입력으로 여러 번 호출해도 결과 동일

## 구현 방향

### 핵심 함수 시그니처

```bash
# 노트 추가 시
update_index_on_add <note_path>
  → 인자: 노트의 절대 경로 (예: ~/.studybook/books/woojoo/topics/개발/프론트엔드/react/use-effect.md)
  → 동작:
    1. 노트 frontmatter에서 category/subcategory/topic/subtopic 추출
    2. 해당 폴더 _index.md 갱신 (note_count +1, last_updated)
       - 없으면 신규 생성
    3. 부모 폴더들의 _index.md도 재귀 갱신 (note_count는 누적이므로 +1)
    4. tree.json의 해당 경로 노드 갱신 (note_count +1)
       - subtopics에 새 항목이면 추가
    5. tree.json.generated_at 갱신

# 노트 삭제 시
update_index_on_remove <note_path>
  → add의 반대 (note_count -1, count=0이면 _index.md/폴더 삭제 옵션)

# 노트 이동 시
update_index_on_move <from_path> <to_path>
  → remove(from) + add(to) 단순 조합
  → 단, 트랜잭션처럼 둘 다 성공해야 함

# 전체 재구성 (정합성 회복용)
update_tree_full_rebuild [profile]
  → books/<profile>/topics/ 전체 walk → tree.json + 모든 _index.md 재생성
  → 점진 갱신 결과 검증용으로도 사용

# inbox 카운트 (분류 안 된 것)
update_tree_unsorted_increment   # +1
update_tree_unsorted_decrement   # -1 (digest 처리 시)
update_tree_unsorted_set <N>     # 절대값 설정 (rebuild 시)
```

### _index.md 형식

```markdown
---
schema: studybook.index/v1
type: index
category: 개발
subcategory: 프론트엔드
topic: react
note_count: 24
last_updated: 2026-04-16T15:01:42+09:00
subtopics:
  - hooks
  - lifecycle
  - patterns
---

# React 노트 모음

총 24개 노트, 3개 소주제.

<!-- @AUTO-GENERATED — 이 섹션은 인덱스 갱신 시 자동 재생성됨 -->
## 소주제별
- hooks/ (12)
- lifecycle/ (5)
- patterns/ (7)
<!-- @END-AUTO -->
```

→ `<!-- @AUTO-GENERATED -->` ... `<!-- @END-AUTO -->` 사이만 자동 갱신, 그 외 사용자 작성 영역은 보존.

### tree.json 점진 갱신 (jq 기반)

```bash
# tree.json의 특정 경로 노드 note_count +1
update_tree_node_count() {
  local _category="$1"
  local _subcategory="${2:-}"
  local _topic="${3:-}"
  local _delta="$4"  # +1 or -1
  local _tree_file="${HOME}/.studybook/cache/tree.json"

  # jq로 부분 업데이트 (전체 재스캔 X)
  local _path=".tree[\"$_category\"]"
  [[ -n "$_subcategory" ]] && _path="$_path.subtopics[\"$_subcategory\"]"
  [[ -n "$_topic" ]] && _path="$_path.subtopics[\"$_topic\"]"

  # 노드 없으면 생성, 있으면 +delta
  jq "
    if (${_path}.note_count // null) == null then
      ${_path} = {note_count: 1, subtopics: {}}
    else
      ${_path}.note_count += $_delta
    end
    | .generated_at = \"$(date -Iseconds)\"
  " "$_tree_file" > "${_tree_file}.tmp" && mv "${_tree_file}.tmp" "$_tree_file"
}
```

### 동시성 처리

여러 hook이 동시에 tree.json을 만지는 경우 race condition 방지 — flock 사용:

```bash
update_tree_node_count() {
  local _tree_file="${HOME}/.studybook/cache/tree.json"
  local _lock="${_tree_file}.lock"

  (
    flock -x 200
    # 위 jq 갱신 로직
  ) 200>"$_lock"
}
```

### tree.json 초기 생성

```bash
init_tree_cache() {
  local _tree_file="${HOME}/.studybook/cache/tree.json"
  mkdir -p "$(dirname "$_tree_file")"
  if [[ ! -f "$_tree_file" ]]; then
    cat > "$_tree_file" <<EOF
{
  "schema": "studybook.tree/v1",
  "generated_at": "$(date -Iseconds)",
  "active_profile": "$(get_active_profile)",
  "unsorted_count": 0,
  "tree": {}
}
EOF
  fi
}
```

### capture-stop.sh 통합 (s3에 추가)

```bash
# inbox 저장 직후
source "${_plugin_root}/lib/index-update.sh"
init_tree_cache
update_tree_unsorted_increment
```

## 의존 관계

- 사용 라이브러리: `lib/schema.sh` (s2)
- 호출 위치:
  - `hooks/capture-stop.sh` (s3) — inbox 저장 시 unsorted +1
  - `lib/digest.sh` (s10) — topic 노트 생성 시 update_index_on_add
  - `lib/digest.sh` — inbox processed 이동 시 unsorted -1
  - `lib/merge.sh` (s12) — 폴더 병합 시 update_index_on_move
  - `commands/tree` (s15) — tree.json 읽기

## 검증 명령

```bash
# 단위 테스트
bats tests/wj-studybook/test-index-update.bats

# 통합 시나리오 (수동)
source src/wj-studybook/lib/index-update.sh
init_tree_cache

# 가짜 노트 10개 추가
for i in {1..10}; do
  mkdir -p ~/.studybook/books/test/topics/개발/프론트엔드/react
  echo "---
schema: studybook.note/v1
type: topic
category: 개발
subcategory: 프론트엔드
topic: react
---
" > ~/.studybook/books/test/topics/개발/프론트엔드/react/note-$i.md
  update_index_on_add ~/.studybook/books/test/topics/개발/프론트엔드/react/note-$i.md
done

# 검증
jq '.tree.개발.subtopics.프론트엔드.subtopics.react.note_count' ~/.studybook/cache/tree.json
# → 10

yq '.note_count' ~/.studybook/books/test/topics/개발/프론트엔드/react/_index.md
# → 10

yq '.note_count' ~/.studybook/books/test/topics/개발/프론트엔드/_index.md
# → 10 (부모 누적)

# rebuild로 정합성 검증
update_tree_full_rebuild test
diff <(jq '.tree' ~/.studybook/cache/tree.json) <(jq '.tree' ~/.studybook/cache/tree.json.before-rebuild)
# → 동일

# 5개 삭제
for i in {1..5}; do
  rm ~/.studybook/books/test/topics/개발/프론트엔드/react/note-$i.md
  update_index_on_remove ~/.studybook/books/test/topics/개발/프론트엔드/react/note-$i.md
done
jq '.tree.개발.subtopics.프론트엔드.subtopics.react.note_count' ~/.studybook/cache/tree.json
# → 5
```
