# s7-profile-mgmt: 프로필 관리 명령 (list/use/new/delete)

## 배경
초기 마법사 외에 프로필을 빈번하게 전환/관리할 수 있어야 함.

## 변경 범위
- `commands/studybook.md` (config profile 서브커맨드 라우팅)
- `lib/profile-mgmt.sh` 신규
- `tests/wj-studybook/test-profile-mgmt.bats`

## 명령어
| 명령 | 동작 |
|------|------|
| `/wj:studybook config profile list` | 목록 + ★ 활성 표시 |
| `/wj:studybook config profile use <name>` | active_profile 갱신 |
| `/wj:studybook config profile new` | wizard 호출 |
| `/wj:studybook config profile delete <name>` | yaml 삭제 (books/<name>/는 confirmation 후) |

## 핵심 함수
- `profile_list()` — table 출력
- `profile_use(name)` — config.yaml.active_profile 갱신, 없으면 에러
- `profile_delete(name, --keep-books|--purge)` — yaml + (옵션) books 폴더

## 검증
```bash
bats tests/wj-studybook/test-profile-mgmt.bats
```

## 의존
- s6 (wizard 재사용)
