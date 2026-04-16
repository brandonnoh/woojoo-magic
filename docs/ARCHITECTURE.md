# woojoo-magic v3 Architecture

## 철학

1. **사람 문서 vs AI 문서 분리** — `docs/`는 사람이 관리, `.dev/`는 AI 흔적
2. **최소 침투** — 유저 프로젝트에 3개 엔트리만 생성 (docs/, .dev/, CLAUDE.md)
3. **세션 내 루프** — 외부 프로세스 없이 Stop hook으로 자동 iteration
4. **경량 게이트** — L1(grep <1초) + L2(tsc 2~10초) + L3(targeted test 5~30초)

## 레이어

```
src/woojoo-magic/
├── hooks/          ← 자동 안전장치 (SessionStart, PreToolUse, PostToolUse, Stop)
├── lib/            ← Stop hook이 호출하는 bash 유틸
├── commands/       ← 사용자 슬래시 커맨드 (/wj:init, /wj:loop, etc.)
├── skills/         ← 반복 작업 레시피 (/wj:commit, /wj:devrule, etc.)
├── agents/         ← 전문가 서브에이전트
├── rules/          ← glob 조건부 로드 규칙
├── references/     ← 고품질 코드 표준 문서
└── templates/      ← /wj:init이 복사할 스켈레톤
```

## 유저 프로젝트 구조 (after /wj:init)

```
my-project/
├── docs/           ← 사람이 관리 (prd.md, specs/, ADR)
├── .dev/           ← AI 흔적 (tasks.json, journal/, state/, learnings.md)
├── CLAUDE.md       ← 프로젝트 지도 (~100줄)
└── (기존 소스)
```

## Stop Hook 루프 흐름

```
사용자: /wj:loop start
  → loop.state active=true
  → Claude가 task 구현
  → Claude 응답 종료
  → Stop hook 발동
  → L1(grep) → L2(tsc) → L3(test)
  → 통과: 다음 task 전진 or 이어서 구현
  → 실패: "이것부터 고쳐" 재프롬프트
  → 연속 3회 실패: 자동 중단
  → 30분 타임아웃: 자동 중단
  → /wj:loop stop: 수동 중단
```

---

## wj-studybook 플러그인 아키텍처

### 레이어

```
src/wj-studybook/
├── hooks/
│   ├── hooks.json              ← Stop + SessionEnd 훅 등록
│   ├── capture-stop.sh         ← Stop hook: 응답 단위 수집
│   └── capture-session-end.sh  ← SessionEnd hook: 세션 단위 전수 복원
├── lib/
│   ├── schema.sh               ← ULID, frontmatter, validate_*
│   ├── filter.sh               ← is_educational, redact_sensitive, estimate_value
│   ├── inbox-writer.sh         ← write_inbox_note → ~/.studybook/inbox/
│   ├── index-update.sh         ← update_index_on_add/remove/move, update_tree_unsorted_*
│   ├── transcript-parser.sh    ← extract_all_assistant_texts, get_session_meta (NUL 구분)
│   ├── digest.sh               ← collect/prepare/apply/archive 파이프라인 (s10)
│   ├── topic-writer.sh         ← write_topic_note → books/<profile>/topics/.../
│   ├── config-wizard.sh        ← wizard_main (s6)
│   ├── profile-mgmt.sh         ← profile_list/use/new/delete (s7)
│   └── config-set.sh           ← config_set/edit/show (s8)
├── commands/
│   └── studybook.md            ← /wj:studybook 라우터
└── references/
    └── SCHEMAS.md              ← 6개 스키마 명세 (studybook.note/book/index/config/profile/tree)
```

### SessionEnd 훅 흐름 (s9)

```
세션 종료
  → end_reason == "resume" → 즉시 exit (세션 계속)
  → transcript JSONL 전체 파싱 (transcript-parser.sh)
  → extract_all_assistant_texts → NUL 구분 assistant 텍스트 순회
  → is_educational 필터 통과
  → SHA256(본문) → inbox/ 기존 파일과 중복 검사
  → 신규만 write_inbox_note (hook_source=session_end)
  → 세션 요약 노트 생성 (type=session_summary)
  → update_tree_unsorted_increment 호출
```

### digest 파이프라인 흐름 (s10)

```
/wj:studybook digest
  1. [collect]  digest_collect_inbox → 미분류 inbox 경로 열거
                (session_summary 타입 제외, processed/ 제외)
  2. [prepare]  digest_prepare → ACTIVE_PROFILE + CURRENT_TREE_JSON
                + INBOX_NOTES 컨텍스트 블록 stdout 출력
  3. [Claude]   컨텍스트 읽고 각 inbox 노트를 category/subcategory/topic/title/body 분류
                (INBOX_COUNT ≤ 20: 메인 세션, > 20: subagent 위임)
  4. [apply]    /wj:studybook digest apply <json>
                → write_topic_note (Generation Effect 슬롯 자동 삽입)
                → update_index_on_add
                → digest_archive_inbox → inbox/processed/<YYYY-MM-DD>/
                → update_tree_unsorted_decrement
```

### Generation Effect 슬롯

`topic-writer.sh`의 `_tw_build_body()` 가 모든 topic 노트 본문 끝에 자동 삽입:

```markdown
## 내 말로 정리
<!-- Generation Effect 슬롯 — 직접 작성 -->
```

Claude가 `body` 필드에 포함시킬 필요 없음 (라이브러리 책임).
