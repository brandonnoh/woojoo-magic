---
description: wj-studybook 전체 커맨드 + 플래그 안내
---

# wj-studybook 커맨드 가이드

## 자동 실행 (호출 불필요)

| Hook | 트리거 | 동작 |
|------|--------|------|
| `capture-stop.sh` | Claude 응답 완료마다 (Stop) | 학습 내용 → `~/.studybook/inbox/` 자동 저장 |
| `capture-session-end.sh` | 세션 종료 (SessionEnd) | 미수집 발화 dedup 보완 + 세션 요약 노트 생성 |

---

## 설정 — `/wj-studybook:config`

| 서브커맨드 | 설명 |
|-----------|------|
| `init` | 프로필 초기 설정 마법사 (처음 한 번) |
| `profile list` | 프로필 목록 + ★ 활성 표시 |
| `profile use <name>` | 활성 프로필 전환 |
| `profile new` | 새 프로필 마법사 |
| `profile delete <name>` | 프로필 삭제 |
| `profile delete <name> --purge` | 프로필 + 관련 books 폴더 완전 삭제 |
| `profile delete <name> --keep-books` | 프로필만 삭제, books 유지 (기본값) |
| `set <key.path> <value>` | 활성 프로필 yaml 단일 값 변경 |
| `edit` | `$EDITOR`로 활성 프로필 yaml 직접 편집 |
| _(인자 없음)_ | 활성 프로필 + 전역 설정 yaml dump |

```
/wj-studybook:config init
/wj-studybook:config profile list
/wj-studybook:config profile use brandon
/wj-studybook:config set learner.level advanced
/wj-studybook:config edit
```

---

## 소급 수집 — `/wj-studybook:backfill`

| 플래그 | 설명 |
|--------|------|
| `--since <YYYY-MM-DD>` | 지정 날짜 이후 세션만 수집 **(필수 또는 --all)** |
| `--project <name>` | 특정 프로젝트 디렉토리로 필터링 |
| `--all` | 전체 Claude Code 세션 소급 (날짜 무제한) |

```
/wj-studybook:backfill --since 2026-04-01
/wj-studybook:backfill --since 2026-01-01 --project woojoo-magic
/wj-studybook:backfill --all
```

---

## 분류 — `/wj-studybook:digest`

inbox 노트를 Claude가 주제별 topics 폴더로 분류하는 2-step 커맨드.

| 서브커맨드 | 설명 |
|-----------|------|
| _(인자 없음)_ | prepare → Claude 분류 → apply 전체 흐름 실행 |
| `prepare` | Claude용 컨텍스트만 출력 (INBOX_NOTES + TREE) |
| `apply <json_file>` | Claude 결과 JSON을 파일 시스템에 적용 |

```
/wj-studybook:digest
/wj-studybook:digest prepare
/wj-studybook:digest apply /tmp/digest-result.json
```

---

## 유사 노트 검색 — `/wj-studybook:similar`

| 서브커맨드 | 설명 |
|-----------|------|
| `<쿼리>` | ripgrep 1차 매칭 + Claude 의미 유사도 Top 5 출력 |
| `keyword <쿼리>` | ripgrep 1차 매칭 경로만 출력 |
| `prepare <쿼리>` | Claude 컨텍스트 패키징만 출력 (CANDIDATES + TREE) |
| `format <json_file>` | Claude 결과 JSON → 사람 친화 포맷 출력 |

```
/wj-studybook:similar 리액트 훅
/wj-studybook:similar keyword useEffect 클린업
/wj-studybook:similar prepare 타입스크립트 제네릭
/wj-studybook:similar format /tmp/similar-result.json
```

---

## 폴더 병합 — `/wj-studybook:merge`

| 서브커맨드 | 설명 |
|-----------|------|
| _(인자 없음)_ | 동의어 폴더 Claude 자동 탐지 컨텍스트 출력 |
| `--auto-detect` | 위와 동일 |
| `<from_dir> <to_dir>` | 지정 폴더 병합 (사용자 확인 후) |
| `<from_dir> <to_dir> --yes` | 확인 없이 강제 병합 |
| `apply <from> <to> [--yes]` | 명시적 apply 호출 |

```
/wj-studybook:merge --auto-detect
/wj-studybook:merge react 리액트
/wj-studybook:merge react 리액트 --yes
```

---

## 책 발간 — `/wj-studybook:publish`

| 서브커맨드 | 설명 |
|-----------|------|
| `weekly` | 이번 주 노트로 주간 책 발간 (기본값) |
| `monthly` | 이번 달 노트로 월간 책 발간 |
| `weekly prepare` | 주간 발간용 Claude 컨텍스트만 출력 |
| `monthly prepare` | 월간 발간용 Claude 컨텍스트만 출력 |
| `apply <json_file> weekly` | Claude 결과 JSON → 주간 책 파일 생성 |
| `apply <json_file> monthly` | Claude 결과 JSON → 월간 책 파일 생성 |

```
/wj-studybook:publish weekly
/wj-studybook:publish monthly
/wj-studybook:publish apply /tmp/book.json weekly
```

---

## 트리 시각화 — `/wj-studybook:tree`

| 플래그 | 설명 |
|--------|------|
| _(인자 없음)_ | 기본 깊이 3으로 ASCII 트리 출력 |
| `--depth <N>` | 출력 깊이 지정 (예: `--depth 2`) |
| `--json` | ASCII 대신 JSON 구조 출력 |

```
/wj-studybook:tree
/wj-studybook:tree --depth 2
/wj-studybook:tree --json
```

---

## 동기화 — `/wj-studybook:sync`

외부 전송 없음. symlink 생성 또는 경로 안내만 수행 (Local-first).

| 서브커맨드 | 설명 |
|-----------|------|
| _(인자 없음)_ | 프로필 `sync_to` 설정값으로 실행 |
| `status` | 현재 symlink 상태 확인 |
| `--target icloud` | iCloud Drive 경로로 symlink 생성 |
| `--target obsidian --vault <path>` | Obsidian vault 내 Studybook/ 폴더로 symlink |
| `--target git` | `books/<profile>/`에 git init |
| `--target none` | 책 경로만 출력 |

```
/wj-studybook:sync status
/wj-studybook:sync --target icloud
/wj-studybook:sync --target obsidian --vault ~/Documents/MyVault
/wj-studybook:sync --target git
```

---

## 처음 시작하는 흐름

```
1. 프로필 초기화
   /wj-studybook:config init

2. 과거 세션 소급 수집 (선택)
   /wj-studybook:backfill --since 2026-01-01

3. inbox → topics 분류
   /wj-studybook:digest

4. 분류 트리 확인
   /wj-studybook:tree

5. 동의어 폴더 정리 (선택)
   /wj-studybook:merge --auto-detect

6. 주간 책 발간
   /wj-studybook:publish weekly

7. 동기화 설정 (선택)
   /wj-studybook:sync --target icloud
```

> **일상 루틴**: Stop/SessionEnd hook이 자동으로 inbox를 채우므로, 주기적으로 `digest` → `publish` 순서만 실행하면 됩니다.
