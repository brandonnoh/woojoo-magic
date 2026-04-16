# s8-config-set: 설정 변경 명령 (set/edit/show)

## 배경
프로필/전역 설정을 빠르게 수정.

## 변경 범위
- `commands/studybook.md` (config 서브커맨드 추가)
- `lib/config-set.sh` 신규
- `tests/wj-studybook/test-config-set.bats`

## 명령어
| 명령 | 동작 |
|------|------|
| `/wj:studybook config` | 활성 프로필 + 전역 설정 yaml dump |
| `/wj:studybook config set <key.path> <value>` | yq로 yaml 단일 값 변경 |
| `/wj:studybook config edit` | $EDITOR (없으면 vi)로 active 프로필 yaml 열기 |

## 예시
```
/wj:studybook config set learner.level intermediate
/wj:studybook config set book_style.use_emoji true
/wj:studybook config set publish.schedule weekly
```

## 핵심 함수
- `config_show()` — 두 yaml dump (전역 + 활성 프로필)
- `config_set(key_path, value)` — yq로 in-place 갱신, 잘못된 path는 에러
- `config_edit()` — exec $EDITOR

## 검증
```bash
bats tests/wj-studybook/test-config-set.bats
# 케이스: set 성공 / 잘못된 key / show 출력 / edit 호출 검증
```

## 의존
- s7
