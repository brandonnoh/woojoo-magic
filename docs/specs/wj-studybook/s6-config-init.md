# s6-config-init: /wj:studybook config init 마법사

## 배경
사용자 첫 실행 시 학습자 프로필 설정. 이미 있으면 "이어서/신규/삭제" 선택지 제공.

## 변경 범위
- `src/wj-studybook/commands/studybook.md` 수정 (config init 라우팅)
- `src/wj-studybook/lib/config-wizard.sh` 신규
- `tests/wj-studybook/test-config-wizard.bats` 신규

## 마법사 흐름

```
1. ~/.studybook/profiles/*.yaml 스캔
2. 프로필 N개 발견 시:
   [1..N] 기존 이어서 / [N+1] 신규 / [N+2] 삭제·수정 / [0] 취소
3. 신규 선택 시:
   - 이름 (필수, /^[a-z0-9_-]+$/)
   - 연령대 (child|teen|adult)
   - 수준 (none|beginner|intermediate|advanced)
   - 언어 (ko|en|ko-en)
   - 관심 주제 (콤마 구분, 비워도 OK)
   - 톤 (친절|정중|캐주얼)
   - 이모지 사용 (y/n)
4. yaml 생성 → ~/.studybook/profiles/<name>.yaml (schema=studybook.profile/v1)
5. config.yaml의 active_profile 업데이트
6. books/<name>/topics/, weekly/, monthly/ 디렉토리 생성
```

## 핵심 함수
- `wizard_list_profiles()` — 목록 + 활성 프로필 표시
- `wizard_create_profile(name, ...)` — yaml 생성
- `wizard_set_active(name)` — config.yaml 갱신

## 검증
```bash
bats tests/wj-studybook/test-config-wizard.bats
# 시나리오: 0개 상태 init / 1개 상태 init / 신규 생성 / 활성 전환
```

## 의존
- s2 (스키마)
