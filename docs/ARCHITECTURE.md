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
│   ├── config-set.sh           ← config_set/edit/show (s8)
│   ├── similar.sh              ← similar_keyword_match / similar_semantic_rank / similar_format_output (s11)
│   ├── merge.sh                ← merge_detect_prepare / merge_apply (s12)
│   ├── backfill.sh             ← backfill_find_sessions / backfill_process_session / backfill_run (s14)
│   ├── tree-view.sh            ← tree_render / tree_render_json / tree_cli (s15)
│   └── sync.sh                 ← sync_run / sync_status / sync_detect_icloud_path (s16)
├── commands/
│   └── studybook.md            ← /wj:studybook 라우터
└── references/
    └── SCHEMAS.md              ← 6개 스키마 명세 (studybook.note/book/index/config/profile/tree)
```

### SessionEnd 훅 흐름 (s9 + 자동 digest 트리거)

```
세션 종료
  → end_reason == "resume" → 즉시 exit (세션 계속)
  → transcript JSONL 전체 파싱 (transcript-parser.sh)
  → extract_all_assistant_texts → NUL 구분 assistant 텍스트 순회
  → is_educational 필터 통과
  → SHA256(본문) → inbox/ 기존 파일과 중복 검사
  → 신규만 write_inbox_note (hook_source=session_end)
  → 세션 요약 노트 생성 (type=session_summary)
  → update_tree_unsorted_increment
  → [자동 digest 트리거] 미분류 inbox 1건 이상이면
      setsid nohup claude -p '/wj-studybook:digest auto' &
      (O_EXCL 락: ~/.studybook/.digest.lock, 로그: .logs/digest-*.log)
```

### digest 파이프라인 흐름 (s10 + 쪽 페이지 발간 모델)

```
/wj-studybook:digest [auto]       (SessionEnd hook이 자동 호출)
  1. [collect]  digest_collect_inbox → 미분류 inbox 경로 열거
                (session_summary 타입 제외, processed/ 제외)
  2. [route]    메인 에이전트가 inbox 전체를 훑어
                각 노트를 (category, subcategory, topic) 좌표로 분류
                (본문 재작성은 이 단계에서 하지 않음)
  3. [bucket]   <category>/<subcategory>/<topic> 키로 버킷팅
                → INBOX_COUNT ≤ 5 or 버킷 1개: 단일 실행
                → 그 외: 버킷별 서브에이전트 병렬 (max WJ_SB_DIGEST_PARALLEL, 기본 4)
                  각자 digest_prepare_bucket <routing> <topic_key> 로 독립 컨텍스트
  4. [rewrite]  서브에이전트가 버킷 노트들을 "쪽 페이지"로 재작성
                → 대화 기록 → 지식 교훈 (맥락 한정 정보 제거)
                → 독립 발간물로 읽히는 제목/요약/본문/see-also
  5. [merge]    메인 세션이 서브에이전트 결과 JSON 배열을 병합
  6. [apply]    /wj-studybook:digest apply <json>
                → write_topic_note (Generation Effect 슬롯 자동 삽입)
                → update_index_on_add (= 토픽 목차 갱신)
                → digest_archive_inbox → inbox/processed/<YYYY-MM-DD>/
                → update_tree_unsorted_decrement
```

**쪽 페이지 발간 모델**: topics/<cat>/<sub>/<topic>/<slug>-<ULID>.md 하나가
곧 "발간물"이다. 폴더별 `_index.md`가 토픽 목차 역할을 한다. 주간/월간
묶음 책은 더 이상 만들지 않는다.

### Generation Effect 슬롯

`topic-writer.sh`의 `_tw_build_body()` 가 모든 topic 노트 본문 끝에 자동 삽입:

```markdown
## 내 말로 정리
<!-- Generation Effect 슬롯 — 직접 작성 -->
```

Claude가 `body` 필드에 포함시킬 필요 없음 (라이브러리 책임).

---

### similar 파이프라인 흐름 (s11)

```
/wj:studybook similar <쿼리>
  1. [keyword]  similar_keyword_match <query>
                → rg(없으면 grep fallback) --fixed-strings --ignore-case
                → topics/ 하위 매칭 .md 경로 최대 20줄 출력
  2. [prepare]  similar_semantic_rank <query>  (stdin: 후보 경로)
                → QUERY + CURRENT_TREE_JSON + CANDIDATES 블록 패키징 → stdout
  3. [Claude]   CANDIDATES를 쿼리와 의미 유사도 평가 → Top 5 JSON [{path, score, summary}]
  4. [format]   similar_format_output <json_file>
                → score desc 정렬, "경로 (xx%) — 요약" 포맷 출력
```

2단계: 1차 키워드 매칭(속도) + 2차 Claude 의미 유사도(정확도).

### merge 파이프라인 흐름 (s12)

```
/wj:studybook merge --auto-detect
  1. [detect/prepare]  merge_detect_prepare
                       → topics/ depth-3 leaf 폴더 나열
                         (절대경로 + 노트수 + category/subcategory/topic)
                       → TREE_DUMP + FOLDERS 블록 패키징 → stdout
  2. [Claude]  FOLDERS에서 동의어/유사 주제 쌍 탐지
               → [{a, b, reason, confidence}] JSON
  3. [사용자 확인] 각 쌍에 대해 y/n
  4. [apply]   merge_apply <from_dir> <to_dir> [--yes]
               → mv 노트 파일, frontmatter category/subcategory/topic 갱신
               → update_index_on_move (from + to 양쪽)
               → 빈 폴더 삭제 + _index.md 재생성
```

prepare/apply 2단 분리: Claude 판단(detect) → 파일시스템 반영(apply) 분리.

### publish (제거됨, 1.9.0)

기존 `publish weekly|monthly`는 제거되었다. 이유와 대체 경로:

- **이유**: 주간 누적 100+ 노트를 한 권으로 묶을 때 37~40분, 토큰 160k+
  소모. "주간 서사" 기획이 범용 지식 위키 취지와 어긋남.
- **대체**: 토픽 폴더의 topic 노트가 곧 쪽 페이지 발간물. 폴더별 `_index.md`가
  목차 역할. SessionEnd hook이 자동 digest로 분류·편집·발간을 한번에 처리.
- **아카이브**: 기존 `books/<profile>/weekly/`, `books/<profile>/monthly/`
  결과물은 읽기 전용으로 보존.

### backfill 파이프라인 흐름 (s14)

```
/wj:studybook backfill --since <YYYY-MM-DD> [--project <name>] [--all]
  1. backfill_find_sessions --since <date>
     → ~/.claude/projects/<encoded-cwd>/*.jsonl 탐색
     → --project 지정 시 해당 경로만, --all 이면 전체 projects/ 탐색
     → 파일의 mtime 또는 내부 blocks[].timestamp >= since 필터
  2. backfill_process_session <jsonl_path> <since_date>
     → transcript-parser.sh: extract_all_assistant_texts (NUL 구분)
     → 각 블록 timestamp >= since_date 필터 (blocks 단위)
     → is_educational 필터 통과
     → SHA256(본문) → 기존 inbox 해시 인덱스 대조 dedup
     → 신규만 write_inbox_note (hook_source=backfill)
     → update_tree_unsorted_increment
  3. backfill_progress <cur> <total>  → stderr 진행 표시
```

SHA256 dedup: `_bf_build_inbox_hash_index`가 inbox/*.md 전체 본문 해시를 메모리에 보유.

### tree-view 렌더 흐름 (s15)

```
/wj:studybook tree [--depth N] [--json]
  1. tree_cli [--depth N] [--json]
     → --json 이면 tree_render_json (jq pretty)
     → 기본: tree_render <tree_json_path> [max_depth]
  2. tree_render
     → jq 1-pass 재귀 렌더 (bash 변수 오염 회피)
     → studybook.tree/v1의 tree 객체를 순회
     → ASCII box-drawing (├ └ │) + 노트 수 표시
     → max_depth 초과 시 "..." 생략
```

jq 재귀 렌더: bash subshell 재귀의 변수 스코프 오염 없이 UTF-8 안전 출력.

### sync 동작 흐름 (s16)

```
/wj:studybook sync [--target icloud|obsidian|git|none] [--vault <path>]
  1. 인자 없으면 활성 프로필 yaml publish.sync_to 값 읽기
  2. icloud → sync_detect_icloud_path
             → iCloud~md~obsidian 경로 우선, 없으면 com~apple~CloudDocs fallback
             → 감지 성공: books/<profile>/ → <icloud_path> symlink 생성
  3. obsidian → --vault 필수. <vault>/Studybook/ symlink 생성
  4. git → books/<profile>/ 에 git init (이미 있으면 skip). push는 사용자 수동
  5. none → 책 디렉토리 경로만 stdout 출력
  6. status → 현재 symlink 상태 확인
```

P4 Local-first 보장: `grep` 기반 소스 테스트로 `curl/wget/ssh/rsync` remote 호출 금지 회귀 방호.
symlink 안전: dst 부모가 `$HOME` 하위인지 검증 + 이미 다른 target symlink면 충돌 에러.
