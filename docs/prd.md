# PRD — Wave 2+3: CTO 리뷰 후속 버그 수정 + 리팩토링

## Wave 2+3 작업 계획 (2026-04-17~)

### Phase 1 — 독립 버그 수정 (병렬 실행)
- [ ] fix-iso-inbox: get_iso_now 통합 + inbox-writer hook_source/path 수정
- [ ] fix-hooks-test-jq: hooks.json jq 쿼리 수정 (테스트 실패 해소)
- [ ] fix-publish-catch: publish.sh silent catch 제거
- [ ] fix-studybook-hint: studybook.md argument-hint 갱신
- [ ] fix-schema-session: schema.sh session_summary 필드 검증 추가

### Phase 2 — 연쇄 버그 수정 (Phase 1 후)
- [ ] fix-capture-bugs: dedup hash 통일 + tmp trap + sed 패치 제거
- [ ] fix-backfill-bugs: inbox 경로 + silent catch + hash 정규화

### Phase 3 — 리팩토링
- [ ] split-gate-l1: gate-l1.sh 363줄 → 7개 서브모듈 분리
- [ ] fix-git-detect: git worktree branch 미검출 수정

---

# PRD — wj-studybook 플러그인

> Claude Code 세션의 어시스턴트 설명을 자동 수집·분류하여 학습자 맞춤 마크다운 책으로 발간하는 플러그인. **수익화 ❌, 가족/개인 학습 도구**.

> **업데이트 (1.9.0, 2026-04-20)**: 주간/월간 `publish` 개념을 제거하고
> **토픽 쪽 페이지 자동 발간 모델**로 전환. SessionEnd hook이 백그라운드에서
> `/wj-studybook:digest auto`를 호출해 토픽별 병렬 서브에이전트로 편집/발간.
> 아래 s13-publish 관련 기술은 1.8.0 이전 아키텍처 기록으로 보존되나 실행되지 않음.
> 실제 흐름은 `docs/ARCHITECTURE.md` 참고.

---

## 목표 (한 문장)

**"코딩하면 자라는 1인칭 교과서"** — 사용자가 평소처럼 Claude Code로 작업만 하면, AI가 설명한 내용이 자동으로 모이고, 정기적으로 책처럼 발간되어 모바일에서 책처럼 읽을 수 있다.

## 범위

- 신규 플러그인 `wj-studybook` 생성 (`src/wj-studybook/`)
- 기존 wj 플러그인과 같은 마켓플레이스(`woojoo-magic`)에 추가
- wj의 Stop hook과 충돌 없이 공존
- 100% 로컬 처리 (외부 API 호출 0, GDPR 자동 안전)

## 비목표 (이번 plan에서 제외)

- ❌ 클라우드 동기화 (수동 git/icloud 경로 지정만)
- ❌ 결제/유료 티어
- ❌ 자체 UI/뷰어 (Obsidian/마크다운 뷰어 호환만)
- ❌ Spaced Repetition 알림 (스키마는 준비, 기능은 v2+)
- ❌ MCP 서버 (v3+)

---

## 핵심 설계 원칙 (불변)

### P1. 인덱스 점진 갱신 (Incremental Index Update)
**노트 생성/수정/삭제 시점에 `_index.md` + `tree.json`을 동시 업데이트.** 매번 전체 재스캔 ❌. Claude에게 컨텍스트 줄 때는 캐시된 `tree.json`만 주입.

### P2. 영구 ID (ULID)
모든 노트/책/인덱스에 ULID 부여. 파일명/위치 바뀌어도 참조 유지.

### P3. 6개 스키마 + 버전 관리
`studybook.{note|book|index|config|profile|tree}/v1` — 모든 파일 frontmatter에 명시. 향후 마이그레이션 안전.

### P4. Local-first / Invisible by Default
- 모든 데이터 로컬, 외부 전송 0
- 코딩 중 push 알림 ❌, pull only (`/wj:studybook` 명령으로만 회수)
- Stop hook은 무음 백그라운드 처리 (flow 보호)

### P5. Generation Effect 슬롯
모든 topic 노트에 "내 말로 정리:" 빈칸 자동 삽입 (학습 효과 보장).

### P6. 출처 메타 필수
모든 노트에 `sources[]` (inbox_id, session_id, model, captured_at) 기록 → hallucination 추적 가능.

### P7. wj 플러그인과 공존
같은 transcript에 두 Stop hook이 read-only로 접근 → 충돌 없음.

---

## Phase 1 — MVP 수집 + 인덱스 (5 tasks)
**목표**: Claude가 응답할 때마다 자동으로 inbox에 저장 + 인덱스 동기화

- [ ] s1-scaffold — 플러그인 스캐폴딩 + 마켓 등록
- [ ] s2-schema — 6개 스키마 정의 + frontmatter helper
- [ ] s3-stop-hook — Stop hook으로 어시스턴트 발화 추출 → inbox 저장
- [ ] s4-filter — 휴리스틱 필터 (학습 가치 판정 + 민감정보 마스킹)
- [ ] s5-index-update — **인덱스 점진 갱신** (생성 시 _index.md + tree.json 동시 업데이트)

## Phase 2 — 설정 + 프로필 (3 tasks)
**목표**: 다중 학습자 프로필 관리

- [ ] s6-config-init — `/wj:studybook config init` 마법사
- [ ] s7-profile-mgmt — 프로필 list/use/new/delete
- [ ] s8-config-set — 설정 변경 (set/edit/show)

## Phase 3 — 분류 + 발간 (5 tasks)
**목표**: inbox → topics 분류, 주간 책 발간

- [x] s9-session-end-hook — SessionEnd hook으로 세션 단위 통합
- [x] s10-digest — `/wj:studybook digest` (Claude 호출 분류)
- [x] s11-similar — `/wj:studybook similar` 유사 노트 검색
- [x] s12-merge — `/wj:studybook merge` 병합 자동 탐지
- [x] s13-publish — `/wj:studybook publish weekly` 책 발간

✅ Phase 3 완주 — 2026-04-16

## Phase 4 — 보강 (3 tasks)
**목표**: 소급 적용 + 시각화 + 동기화

- [x] s14-backfill — `/wj:studybook backfill --since` 과거 세션 소급
- [x] s15-tree-view — `/wj:studybook tree` 트리 시각화
- [x] s16-sync — `/wj:studybook sync` (icloud/obsidian/git 경로 출력)

✅ Phase 4 완주 — 2026-04-16

---

## 의존성 그래프

```
Phase 1 (MVP):
  s1-scaffold
    └─ s2-schema
        ├─ s3-stop-hook
        │    ├─ s4-filter
        │    └─ s5-index-update
        │
Phase 2 (s2 완료 후):
        └─ s6-config-init → s7-profile-mgmt → s8-config-set

Phase 3 (Phase 1+2 완료 후):
    s9-session-end-hook (s3 의존)
    s10-digest (s5 의존)
      ├─ s11-similar
      ├─ s12-merge
      └─ s13-publish

Phase 4 (Phase 3 완료 후):
    s14-backfill (s10 의존)
    s15-tree-view (s5 의존)
    s16-sync (s13 의존)
```

---

## 데이터 구조 표준 (요약)

### 6개 스키마

| 스키마 | 파일 | 핵심 필드 |
|--------|------|----------|
| `studybook.note/v1` | `inbox/*.md`, `topics/**/*.md` | id, type, status, sources[], category, tags, verification |
| `studybook.book/v1` | `books/<profile>/{weekly,monthly}/*.md` | id, period, chapters[], stats, profile, level |
| `studybook.index/v1` | `topics/**/_index.md` | category, note_count, last_updated, subtopics[] |
| `studybook.config/v1` | `~/.studybook/config.yaml` | active_profile, storage, sync |
| `studybook.profile/v1` | `~/.studybook/profiles/*.yaml` | learner.{age, level, language}, book_style, capture, publish |
| `studybook.tree/v1` | `~/.studybook/cache/tree.json` | tree (계층 + note_count + subtopics) |

### 디렉토리 구조

```
~/.studybook/
├── config.yaml                      # 활성 프로필 포인터
├── profiles/<name>.yaml             # 학습자 프로필들
├── cache/tree.json                  # 분류 트리 캐시 (LLM 컨텍스트용)
├── inbox/                           # 공용 raw 수집
│   └── 2026-04-16-01HXKZ8R.md
└── books/<profile>/
    ├── topics/                      # 분류된 atomic 노트
    │   └── 개발/프론트엔드/react/
    │       ├── _index.md            # 자동 생성/갱신
    │       └── use-effect-cleanup.md
    ├── weekly/                      # 주간 책
    └── monthly/                     # 월간 책
```

---

## 인덱스 점진 갱신 메커니즘 (P1 상세)

**원칙**: 매 생성/수정/삭제마다 영향받는 인덱스 파일들만 부분 업데이트.

### 트리거 시점
| 이벤트 | 갱신 대상 |
|--------|----------|
| inbox 노트 생성 (s3) | `tree.json.unsorted_count` +1 |
| topic 노트 생성 (s10) | 해당 폴더 `_index.md` + 부모 `_index.md`들 + `tree.json` 경로 노드 |
| topic 노트 삭제 | 동일 |
| 노트 재분류 (s11/s12) | 이동 전/후 폴더 모두 갱신 |
| 책 발간 (s13) | 책 메타에 `note_ids[]` 기록, 노트 frontmatter에 `published_in[]` 추가 |

### 인덱스 갱신 함수 (lib/index-update.sh)

```bash
# 노트 추가 시
update_index_on_add <note_path>
  → 해당 폴더 _index.md의 note_count +1, last_updated 갱신
  → 부모 폴더 _index.md들 재귀 갱신
  → tree.json 해당 경로 노드 갱신

# 노트 삭제 시
update_index_on_remove <note_path>
  → 위와 반대 방향

# 노트 이동 시
update_index_on_move <from> <to>
  → remove(from) + add(to)
```

### Claude 컨텍스트 주입
`/wj:studybook digest` 또는 `similar` 실행 시:
1. `tree.json` 로드 (현재 분류 트리 전체)
2. 새 노트 본문 + tree.json을 Claude에 전달
3. "이 노트가 어디에 들어가야 하나?" 질의
→ **전체 노트 본문 재스캔 없음, tree.json만 참조**

---

## 검증 명령

```bash
# 통합 검증
bash tests/wj-studybook/integration.bats

# 또는 수동
/wj:studybook config init   # 마법사 동작 확인
/wj:studybook digest        # inbox → topics 분류 확인
/wj:studybook tree          # 분류 트리 시각화
```
