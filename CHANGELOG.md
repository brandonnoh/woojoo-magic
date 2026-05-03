# Changelog

## wj-magic 4.7.0 — 2026-05-04

### Added
- **`/wj:audit` 대규모 보안 감사 스킬**: OWASP Top 10:2025 기반 8개 전문가 에이전트 1차 감사 + 3개 검증 에이전트 2차 크로스 리뷰 + Wave 전략 자동 수정. auth-auditor, injection-hunter, crypto-auditor, api-security-auditor, supply-chain-auditor, config-auditor, data-integrity-auditor, client-security-auditor 8개 신규 에이전트 추가
- **OWASP 2025 체크리스트**: A01~A10 + CWE/SANS Top 25 통합 감사 체크리스트 레퍼런스
- **에이전트 로스터**: 11개 보안 감사 에이전트 역할·투입 조건·산출물 형식 정의 레퍼런스
- **`/wj:loop plan` 호환 출력**: 감사 결과를 tasks.json 형식으로 변환하여 자율 루프와 연계

## wj-magic 4.6.1 — 2026-05-03

### Added
- **`/wj:explain` 슬래시 커맨드 등록**: commands/explain.md 추가로 슬래시 자동완성에서 접근 가능

## wj-magic 4.6.0 — 2026-05-03

### Added
- **`/wj:explain` 스킬 신규**: 소프트웨어 공학을 모르는 바이브코더를 위한 코드·개념 해설. 4단계 응답 구조(한 줄 요약+비유 → 음식점 비유로 시스템 위치 → 왜 이렇게+대안 비교 → 다음 단계). 전문 용어 일상 언어 번역 강제, 문단당 전문 용어 2개 제한

### Changed
- **플러그인 경로 통일**: `src/woojoo-magic/` → `src/wj-magic/`로 리네임하여 플러그인명(`wj-magic`)과 디렉토리명 일치. 45개 파일 참조 일괄 업데이트

## srt-magic 1.0.2 — 2026-04-27

### Fixed
- **NetFunnel 혼잡 에러(`SRTNetFunnelError`)로 매크로가 조기 종료되던 버그**: SRT 대기열 시스템의 일시적 "Wrong Server ID" 에러가 영구 에러로 분류되어 연속 3회 한도에 걸려 종료됨. `SRTNetFunnelError`를 별도 `"congested"` 상태로 분리하여 fails 카운터에 누적하지 않고 30~60초 짧은 대기 후 재시도
- **세션 만료 시 자동 재로그인**: `SRTNotLoggedInError` 감지 시 1회 재로그인 시도. 재로그인 실패 시에만 종료 (기존에는 세션 만료도 일반 에러로 처리되어 즉시 종료)
- **연속 실패 한도 3→5회 완화**: NetFunnel 에러 분리 후에도 진짜 API 에러에 대한 내성 강화

### Changed
- **플랫폼 표기 정정**: README·SKILL.md·plugin.json의 "macOS 전용" 표기를 실제 코드와 일치하는 "macOS/Windows/Linux 크로스플랫폼"으로 수정. 코드는 `notify_desktop()`에서 `sys.platform` 분기로 3개 OS 모두 지원

## srt-magic 1.0.1 — 2026-04-27

### Fixed
- **nohup 백그라운드 실행 시 로그 버퍼링 버그**: Python의 fully buffered stdout 때문에 `~/srt-macro.log`가 사이클 1 이후 갱신되지 않던 문제. `_bootstrap.py`의 `ensure_venv()`에서 `sys.stdout.reconfigure(line_buffering=True)`로 자동 line buffering 강제. 사용자가 `PYTHONUNBUFFERED=1`을 따로 지정할 필요 없음
- 텔레그램 `/status` 명령 응답이 로그에 즉시 안 보이던 부수 증상도 동시 해결

## srt-magic 1.0.0 — 2026-04-27 (신규 플러그인)

### Added
- **신규 플러그인 출시**: 한국 SRT 매진 좌석 자동 감시·예약 매크로 (macOS 전용)
- **다중 노선(왕복) 동시 감시**: `--route 'dep:arr:date:time:[range:[seat]]'` 인자 반복 — 한 프로세스/1회 로그인으로 가는 표·오는 표 동시 추적
- **계정 잠김 방지 8중 안전 가드**: 세션 재사용·시간대별 지터 폴링(골든타임 30~60s/평시 60~120s/야간 5~10m)·시도 캡(200회 또는 4시간)·로그인 실패 즉시 종료·에러 백오프(2→5→15분)·lockfile·예약 후 즉시 종료·결제 자동화 X
- **텔레그램 통합**: 시작·예약·헬스체크(30분 간격) 푸시 + 원격 명령 `/stop`·`/status`·`/help` (본인 chat_id에서만 인식)
- **자동 venv 셋업**: `_bootstrap.py`가 첫 실행 시 `~/.config/srt-macro/.venv` 생성 + 의존성(SRTrain·python-dotenv·requests) 자동 설치 + `os.execv`로 venv 인터프리터 재실행
- **대화형 자격증명 셋업**: `scripts/setup.py` — `getpass`로 비밀번호 화면 비노출, 재입력 확인, `chmod 0600` 자동, 기존 `.env` 백업
- **다층 자격증명 로드**: 환경변수 → `.env` → macOS Keychain (3단계 fallback)
- **트리거 정확도 evals.json**: 20 케이스 (should_trigger 10 + should_not 10, 코레일·강릉 도메인 함정 포함)
- **역명 함정 가드**: SRTrain의 정확한 33개 역명만 허용 (`울산` ❌ → `울산(통도사)` ✅), 잘못된 역명은 영구 제외 후 다른 노선 계속 폴링
- **SKILL.md (266줄)** + **README.md (293줄)** + **LICENSE (MIT)** + **requirements.txt**

## wj-studybook 2.0.0 — 2026-04-20

### BREAKING CHANGE
- **주간/월간 `publish` 제거** — `/wj-studybook:publish` 커맨드,
  `lib/publish.sh`, `lib/book-writer.sh`, `lib/schedule.sh` 삭제.
  `config schedule install/uninstall/status` 서브커맨드 제거.
  frontmatter의 `published_in`, `book_kind` 필드, `studybook.book/v1` 스키마 폐기.
  기존 `books/<profile>/weekly/`, `books/<profile>/monthly/` 결과물은 읽기 전용
  아카이브로 보존.

### Added
- **`/wj-studybook:digest auto`**: 라우팅 → 토픽별 버킷팅 → 병렬 서브에이전트
  쪽 페이지 재작성 → apply 를 한 세션에서 자동 수행. `WJ_SB_DIGEST_PARALLEL`
  로 병렬도 조정 (기본 4).
- **`digest_prepare_bucket`** (lib/digest.sh): 라우팅 JSON + 토픽 키 입력으로
  해당 토픽 버킷만 필터링된 prepare 블록 출력. 서브에이전트 독립 컨텍스트 지원.
- **SessionEnd 자동 digest 트리거**: 미분류 inbox 1건 이상이면
  `setsid nohup claude -p '/wj-studybook:digest auto'` 백그라운드 실행.
  O_EXCL 락 (`~/.studybook/.digest.lock`)으로 중복 실행 방지.
  `WJ_SB_DIGEST_DISABLE=1` 로 skip 가능 (테스트 안전).
- **`digest bucket <cat>/<sub>/<topic>`**: 특정 토픽 버킷 prepare 진입점.

### Changed
- **발간 모델 전환**: 토픽 폴더의 topic 노트 하나하나가 곧 "쪽 페이지 발간물".
  폴더별 `_index.md`가 목차 역할.
- **help.md / session-start.sh / studybook.md** 문구를 새 모델에 맞게 갱신.
  세션 시작 알림이 "마지막 publish 경과일" 대신 "세션 종료 시 자동 발간" 안내.
- **config-wizard.sh**: 신규 프로필 생성 시 `weekly/`, `monthly/` 디렉토리와
  `publish: schedule: weekly` yaml 블록, `_cw_offer_schedule` 프롬프트 제거.

## wj-studybook 1.8.0 — 2026-04-19

### Added
- **`※ study:` 애노테이션**: Stop hook이 매 응답 끝에 수집 여부를 표시 (`배울만한 내용이 있음 — 대화 내용 수집됨` / `배울만한 내용이 아님 — 저장 건너뜀`). recap과 동일한 방식으로 노출

### Fixed
- **세션 시작 알림 릴레이 버그 수정**: `session-start.sh` 출력이 system-reminder에만 머물고 사용자에게 전달되지 않던 문제 수정 — `IMPORTANT:` 지시 추가로 Claude가 첫 응답에서 inbox 현황을 반드시 표시

## wj-magic 4.5.7 — 2026-04-30

### Fixed
- **`design`·`polish` 스킬 에이전트 호출 오류 수정**: `design-reviewer`, `design-dev` 이름만 적혀 있어 Skill 도구로 오호출되던 버그. `design/skill.md`의 Step 5·6과 `polish/skill.md`의 Step 3·4·5를 `Agent(subagent_type: "wj-magic:X")` 형식으로 명시.

## wj-magic 4.5.6 — 2026-04-30

### Fixed
- **`devrule` 에이전트 subagent_type 표기 오류 수정**: `wj:X` 형식이 Skill 도구로 오호출되던 버그. 에이전트 테이블 전체를 `wj-magic:X` 형식으로 교정 (frontend-dev/backend-dev/engine-dev/design-dev/design-reviewer/security-auditor/test-engineer/docs-keeper). Step 4와 코드 블록 내 Agent 호출도 `Agent(subagent_type: "wj-magic:X")` 형식으로 통일.

## wj-magic 4.5.5 — 2026-04-30

### Changed
- **`devrule` 스킬에 `wj:design` 선행 트리거 추가**: 새 UI/페이지/컴포넌트 생성 작업 시 구현 전 반드시 `wj:design` 스킬을 호출하도록 Step 4 작업 순서와 에이전트 유형 테이블에 명시. 기존 UI 수정은 `wj:polish` 사용 구분도 명확화.

## wj-magic 4.5.4 — 2026-04-29

### Changed
- **`cto-review` 스킬 Context7 + Serena 강제 실행**: Critical Rules를 HARD GATE로 격상. PM Phase 1에 Serena `get_symbols_overview` + Context7 `query-docs` 선행 호출 순서 명시. 분석 에이전트 프롬프트에 4단계 MCP 호출 시퀀스 + "MCP 호출 증거" 섹션 산출물 필수 요구 추가. Phase 6 수정 에이전트에도 파일 수정 전 Serena `find_referencing_symbols` + Context7 문서 조회 강제.

## wj-magic 4.5.3 — 2026-04-29

### Fixed
- **`team` 스킬 CTO 리뷰 호출 오류 수정**: Phase 4와 Execution Rules에서 "CTO 리뷰 에이전트 투입"이라고 잘못 명시돼 `subagent_type: "wj-magic:cto-review"`로 호출 → Agent type not found 에러 발생. `cto-review`는 에이전트가 아닌 스킬이므로 `Skill` 도구 사용으로 수정. Agent Mapping 테이블에 CTO 리뷰 행 추가.

## wj-magic 4.5.2 — 2026-04-24

### Changed
- **brainstorm 브랜딩 정리**: superpowers 출처 흔적 제거 — 타이틀, 헤더 링크, 세션 디렉토리 경로(`.superpowers/` → `.wj-magic/`)를 woojoo-magic으로 통일

## wj-magic 4.5.1 — 2026-04-22

### Fixed
- **`/wj:debug` 완전 삭제**: deprecated 안내만 남겨뒀던 파일이 슬래시 목록에 계속 노출되던 문제 해결. `/wj:investigate`가 완전 대체.
- **description 이중 prefix 제거**: Claude Code가 플러그인명을 자동으로 붙이는데 수동으로도 추가해 `(wj-magic) (wj-magic)`으로 표시되던 버그 수정.
- **스킬 수 14 → 13 반영**: debug 삭제로 실제 스킬 수와 description 숫자 일치.

### Changed
- **스킬 description 트리거 재설계**: skill-creator 공식 가이드 준수 — description이 자동 트리거의 핵심 메커니즘이므로 트리거 키워드·컨텍스트를 description에 포함하고 "pushy" 스타일로 작성. 13개 스킬 전체 적용.
- **help.md v4.5 동기화**: 커맨드·스킬 설명을 새 description과 일치, 워크플로 번호 오기 수정.

## wj-magic 4.5.0 — 2026-04-22

### Added
- **`rules/db-migration.md`**: DB 마이그레이션 파일 자동 주입 규칙 추가. `**/migrations/**` 등 glob 매칭 시 컬럼 삭제 3단계 패턴·NOT NULL 추가·트랜잭션·롤백·lock 위험 체크리스트 자동 제공.
- **`rules/scripts.md`**: 쉘 스크립트 자동 주입 규칙 추가. `**/*.sh` glob 매칭 시 `set -euo pipefail` 강제·forbidden patterns(rm -rf $VAR, eval, cat|bash)·변수 인용·에러 처리 패턴 자동 제공.

### Changed
- **모든 커맨드·스킬 description에 `(wj-magic)` prefix 추가**: `/` 목록에서 타 플러그인 항목과 명확히 구분. 5개 커맨드 + 14개 스킬 전체 적용.
- **README 최신화**: v4.4 기준으로 14 스킬·13 에이전트·7 규칙 반영. 규칙 자동 주입 메커니즘 설명 및 예시 추가.

## wj-magic 4.4.0 — 2026-04-21

### Added
- **`AGENT_QUICK_REFERENCE.md`**: 포인터 아키텍처의 단일 진실 공급원. 파일/함수 크기 제한, forbidden patterns (any/!./silent catch), Required Patterns (Branded Types/Result/DU), MCP 사용 원칙, 리팩토링 방지 신호를 1페이지에 통합.

### Changed
- **에이전트 포인터 아키텍처**: 9개 에이전트(frontend-dev, backend-dev, engine-dev, qa-reviewer, docs-keeper, test-engineer, security-auditor, design-dev, design-reviewer)에서 인라인 품질 규칙 임베딩 제거 → `references/common/AGENT_QUICK_REFERENCE.md` Read 포인터로 교체. 규칙 업데이트 시 모든 에이전트가 자동 최신화됨.
- **규칙 파일 포인터화**: frontend/server/shared-engine/tests 규칙의 "Quality Standards" 섹션을 인라인 나열 대신 `references/common/AGENT_QUICK_REFERENCE.md` 포인터로 교체.
- **`/wj:learn` 범위 명확화**: 프로젝트 전용 규칙(`devrule/skill.md`)과 플러그인 레벨 공통 기준(`AGENT_QUICK_REFERENCE.md`) 구분 안내 추가.

## wj-magic 4.3.0 — 2026-04-22

### Added
- **`/wj:investigate`**: 국정조사급 심층 이슈 분석 스킬. 버그·성능·보안·아키텍처 이슈를 5개 전문 에이전트 팀이 병렬 조사 후 자동 수정까지 수행. `/wj:debug` 대체.
  - **web-researcher** 에이전트: Context7 + WebSearch + GitHub Issues/CVE 조사
  - **code-analyst** 에이전트: Serena MCP 심볼 추적 + SBFL-inspired 의심도 분석 + taint analysis
  - **perf-analyst** 에이전트: Chrome DevTools Core Web Vitals 실측 + 코드 레벨 N+1/재렌더링 안티패턴 탐지
  - **regression-hunter** 에이전트: `git bisect` 자동화 + blame 분석으로 회귀 도입 커밋 특정
  - **Sequential Thinking MCP**: Phase 2 수렴 단계에서 7단계 Tree-of-Thought RCA 강제
  - **Memory MCP**: Phase 5 조사 결과 knowledge graph 저장 → 유사 과거 이슈 자동 매칭
  - **`lib/investigation-utils.sh`**: git-suspects / git-recent-changes / bisect-test / report-init bash 헬퍼 + BATS 테스트 14개

### Changed
- **`/wj:debug`** deprecated → `/wj:investigate` thin redirect로 교체

## wj-magic 4.2.1 — 2026-04-19

### Fixed
- **세션 시작 요약 릴레이 버그 수정**: `session-summary.sh` 출력이 system-reminder에만 머물고 사용자에게 표시되지 않던 문제 수정 — `IMPORTANT:` 지시 추가로 Claude가 첫 응답에서 세션 요약을 반드시 표시

## wj-magic 4.2.0 — 2026-04-17

### Added
- **`/wj:debug`**: 체계적 디버깅 스킬. 증상→근본 원인 역추적, 4단계 조사 프로세스. Iron Law: 근본 원인 파악 없이 수정 금지.
- **`/wj:plan`**: 구현 계획 작성 스킬. 설계 문서 → 단계별 실행 계획. 저장 경로: `docs/specs/plans/YYYY-MM-DD-<feature>.md`
- **`/wj:verify`**: 완료 전 검증 스킬. 요구사항 체크리스트 자동 생성, 실제 증거 기반 완료 판정. Iron Law: 검증 없이 완료 선언 금지.
- **`/wj:tdd`**: 테스트 주도 개발 스킬. Red-Green-Refactor 사이클 강제. Iron Law: 실패 테스트 없이 프로덕션 코드 작성 금지.

## wj-magic 4.1.0 — 2026-04-17

### Added
- **`/wj:brainstorm`**: 기획·설계·스펙 작성 스킬. 1:1 대화로 요구사항 정제 → 2-3가지 접근법 제시 → 설계 문서 작성 → 구현 계획 연결. HARD-GATE로 설계 승인 전 코드 작성 차단.

## wj-studybook 1.7.0 — 2026-04-17

### Added
- **`/wj-studybook:config schedule`**: macOS launchd 자동 publish 스케줄 관리 (`install` / `uninstall` / `status`)
- 매주 월요일 오전 9시(KST) 자동 `/wj-studybook:publish weekly` 실행
- `config init` 마법사 마지막 단계에 macOS 자동 스케줄 설정 제안 추가

## wj-studybook 1.6.1 — 2026-04-17

### Fixed
- **커맨드 출력 누락 수정**: `config`, `backfill`, `tree`, `sync`, `pause`, `resume` 6개 커맨드에 출력 지시 추가 — Claude가 bash 결과를 무시하고 다른 답변을 하던 문제 수정

## wj-studybook 1.6.0 — 2026-04-17

### Added
- **세션 시작 현황 알림**: inbox 10개+ 쌓이면 자동 알림 (30개+ 강조), quarantine 수·마지막 publish 경과일 표시
- **`publish` → digest 통합**: `/wj-studybook:publish` 실행 시 digest 먼저 자동 수행 (inbox 분류 + quarantine 검토 포함)

## wj-studybook 1.5.0 — 2026-04-17

### Changed
- **휴리스틱 필터 강화**: 최소 길이 50 → 200자, 키워드 임계값 1 → 2개, 테이블 덤프 감지 추가 (50%+ 라인이 `|` 포함 시 차단)
- **슬래시 커맨드 차단**: `user_prompt`가 `/`로 시작하는 경우(플러그인 커맨드 실행) inbox 저장 건너뜀
- **`/wj-studybook:help` 흐름도 추가**: 캡처 → digest → publish 전체 흐름 + 휴리스틱 기준표

## wj-studybook 1.4.0 — 2026-04-17

### Added
- **`/wj-studybook:init`**: 처음 설정 마법사 단축 커맨드 (`/wj-studybook:config init` 동일)
- **`/wj-studybook:help` 출력 수정**: 내용 전체가 출력되지 않던 문제 수정 (출력 지시 명시)

## wj-studybook 1.3.0 — 2026-04-17

### Added
- **`/wj-studybook:pause`**: 자동 수집 일시정지 (`~/.studybook/.paused` 파일 생성)
- **`/wj-studybook:resume`**: 자동 수집 재개 (`.paused` 파일 삭제)
- Stop/SessionEnd hook이 `.paused` 파일 존재 시 자동 skip
- SessionStart 시 일시정지 상태 알림 표시
- `help.md` 일시정지/재개 섹션 추가

## wj-studybook 1.2.0 — 2026-04-17

### Added
- **커맨드 파일 분리**: `studybook.md` 단일 파일 → `config/digest/similar/merge/publish/backfill/tree/sync` 8개 독립 커맨드. `/wj-studybook:digest`, `/wj-studybook:publish` 등 직접 호출 가능
- **`/wj-studybook:help`**: 전체 커맨드 + 플래그 + 예시 + 3단계 시작 가이드 (초보자 친화)
- **SessionStart 훅**: 프로필 미존재 시 온보딩 배너 자동 출력 → `/wj-studybook:config init` 안내

## wj-magic 4.0.0 — 2026-04-17

### Breaking
- **플러그인명 변경**: `wj` → `wj-magic`. 기존 `wj` 이름으로 설치된 경우 재설치 필요.

### Changed (3.3.0 내용 포함)
- **`gate-l1.sh` 분리**: 363줄 단일 파일 → 오케스트레이터(53줄) + 7개 언어 서브모듈(`gate-l1-ts/py/go/rs/sw/kt/cc.sh`) 분리. 각 파일 100줄 이하.
- **보안 패치**: `stop-loop.sh` `local` 금지 규칙 준수, `quality-check.sh` / `session-summary.sh` 변수명 `_prefix` 규칙 통일.
- **루프 스킬 강화**: `security-auditor` 트리거 조건 9항목 상세화 (관리자 인증, RLS, 결제 검증, 환경변수 노출, 에러 메시지 등).
- **CTO 리뷰 체크리스트**: 웹앱 보안 5개 항목 추가.

## wj 3.3.0 — 2026-04-17

### Changed
- **`gate-l1.sh` 분리**: 363줄 단일 파일 → 오케스트레이터(53줄) + 7개 언어 서브모듈(`gate-l1-ts/py/go/rs/sw/kt/cc.sh`) 분리. 각 파일 100줄 이하.
- **보안 패치**: `stop-loop.sh` `local` 금지 규칙 준수, `quality-check.sh` / `session-summary.sh` 변수명 `_prefix` 규칙 통일.
- **루프 스킬 강화**: `security-auditor` 트리거 조건 9항목 상세화 (관리자 인증, RLS, 결제 검증, 환경변수 노출, 에러 메시지 등).
- **CTO 리뷰 체크리스트**: 웹앱 보안 5개 항목 추가.

## wj-studybook 1.1.0 — 2026-04-17

### Fixed
- **dedup hash 정규화**: `capture-session-end.sh` + `backfill.sh` trailing whitespace strip 추가 → Stop/SessionEnd 간 SHA256 불일치 해소
- **git worktree 감지**: `capture-stop.sh` + `capture-session-end.sh` `[ -d .git ]` → `git rev-parse --git-dir` 변경, worktree 환경 branch 미검출 수정
- **inbox 경로 하드코딩 제거**: `inbox-writer.sh` + `backfill.sh` `${HOME}/.studybook/inbox` → `$(get_studybook_dir)/inbox`, `STUDYBOOK_HOME` 환경변수 테스트 격리 지원
- **`hook_source` sed 패치 제거**: `capture-session-end.sh` sed 패치 블록 제거 → `inbox-writer.sh`가 `${WJ_SB_HOOK_SOURCE:-stop}` 직접 처리
- **silent catch 제거**: `publish.sh` + `backfill.sh` `2>/dev/null || true` 패턴 → 명시적 에러 출력 + 조기 종료
- **`schema.sh` session_summary 검증**: `validate_note_schema`에 `type=session_summary` 분기 추가, 6개 필수 필드 검증
- **`studybook.md` argument-hint**: `merge`, `backfill --since`, `sync [status|--target]` 서브커맨드 추가
- **tmp 파일 안전**: `capture-session-end.sh` tmp 생성 직후 `trap 'rm -f "$_tmp"' EXIT INT TERM` 추가
- **`get_iso_now()` 통합**: `config-helpers.sh` 공통 함수 추가, 각 라이브러리 중복 `_XXX_now_iso()` 제거
- **hooks.json 테스트 쿼리 수정**: `.Stop[0]` → `.hooks.Stop[0]` (래퍼 구조 반영)

## wj-studybook 1.0.0 — 2026-04-17

### Added
- **wj-studybook 첫 안정 릴리즈** (s1~s16 완주, 309개 테스트 통과)
- **자동 수집**: Stop hook(응답 단위) + SessionEnd hook(세션 전수 복원) 이중 캡처
- **수동 소급**: `backfill` — 과거 Claude Code 세션 JSONL 소급 수집
- **분류**: `digest` — inbox → topics Claude 자동 분류 + Generation Effect 슬롯
- **탐색**: `similar` — 2단 유사 노트 검색 (키워드 + Claude 의미 유사도)
- **정리**: `merge` — 동의어 주제 폴더 자동 탐지 + 병합
- **시각화**: `tree` — 분류 트리 ASCII 시각화
- **발간**: `publish` — 주간/월간 책 파일 생성 (studybook.book/v1 스키마)
- **동기화**: `sync` — iCloud/Obsidian/git/none Local-first 경로 연결
- **프로필**: 다중 학습자 프로필 관리 (나이/레벨/언어/관심사)
- **스키마**: 6종 검증 스키마 (note/book/index/config/profile/tree)

## [wj-studybook s11~s16] — 2026-04-16 Phase 3+4 완주

### Added (wj-studybook Phase 3+4 완주)

- **`similar.sh`** (s11): 2단 유사 노트 검색 — `similar_keyword_match`(rg/grep 1차) + `similar_semantic_rank`(Claude 컨텍스트 패키징) + `similar_format_output`(Top 5 포맷). rg 없으면 grep fallback.
- **`merge.sh`** (s12): 동의어 주제 폴더 병합 — `merge_detect_prepare`(topics/ leaf 폴더 나열 → Claude 탐지 컨텍스트) + `merge_apply`(mv + frontmatter 갱신 + `update_index_on_move` + 빈 폴더 정리). prepare/apply 2단.
- **`publish.sh`** + **`book-writer.sh`** (s13): 주간/월간 책 발간 — `publish_collect_notes`/`publish_prepare`/`publish_apply` 3단. `book_compute_period`(BSD/GNU date 분기), `book_build_frontmatter`(stats 5필드 + chapters + estimated_reading_minutes), 노트 `published_in[]` 역참조 자동 갱신. 스키마 `studybook.book/v1` 준수.
- **`backfill.sh`** (s14): 과거 Claude Code 세션 소급 — `backfill_find_sessions`(`--since`/`--project`/`--all`), blocks 단위 timestamp 필터, SHA256 dedup(`_bf_build_inbox_hash_index`), `hook_source=backfill` inbox 저장.
- **`tree-view.sh`** (s15): ASCII 분류 트리 시각화 — `tree_render`(jq 1-pass 재귀, bash 변수 오염 회피) + `tree_render_json` + `tree_cli --depth N --json`. UTF-8/한글 안전.
- **`sync.sh`** (s16): 동기화 경로 출력 — `sync_run`/`sync_status`/`sync_detect_icloud_path`/`sync_create_symlink`. iCloud/Obsidian/git/none 분기, `$HOME` 경계 검증, P4 Local-first(외부 전송 0).

### Changed (wj-studybook)

- **`studybook.md`**: similar/merge/publish/backfill/tree/sync 라우팅 + 각 분기 Claude 작업 지시 섹션 추가. argument-hint 전체 갱신.
- **테스트**: 250 → **309개** (s11: +16, s12: +14, s13: +26, s14: +16, s15: +24, s16: +35).

## [wj-studybook s9+s10] — 2026-04-16

### Added (wj-studybook Phase 3 진행)

- **`capture-session-end.sh`** (s9): SessionEnd hook — 세션 종료 시 transcript JSONL 전수 파싱, SHA256 기반 dedup으로 Stop hook 미처리 발화 보완 저장. `end_reason=resume`이면 즉시 skip. 세션 요약 노트(`type=session_summary`) 자동 생성.
- **`transcript-parser.sh`** (s9): transcript JSONL 공통 파서 라이브러리 — `extract_all_assistant_texts` (NUL 구분), `extract_user_prompts`, `get_session_meta` (4-line 출력). s9/s14 공용 인터페이스.
- **`digest.sh`** (s10): inbox → topics 분류 파이프라인. `digest_collect_inbox` / `digest_prepare` / `digest_apply` / `digest_archive_inbox` 4단계. Claude가 분류 JSON 생성 → `apply`가 파일 시스템 반영.
- **`topic-writer.sh`** (s10): `write_topic_note` — books/\<profile\>/topics/.../\<slug\>-\<ulid\>.md 생성, Generation Effect 슬롯(`## 내 말로 정리`) 자동 삽입, `update_index_on_add` 호출.

### Changed (wj-studybook)

- **`hooks.json`**: `SessionEnd` 배열 추가 — `capture-session-end.sh` 등록.
- **`studybook.md`**: `digest` / `digest apply` / `digest prepare` 라우팅 추가 및 Claude 작업 지시 섹션 추가.

## [3.2.2] — 2026-04-15

### Fixed
- **루프 중간 확인 질문 금지**: "계속할까요?", "진행할까요?" 등 루프 중단 유발 질문 차단. task 남아있으면 묻지 않고 즉시 다음 task로 전진

## [3.2.1] — 2026-04-15

### Changed
- **루프 타임아웃 기본값 제거**: 30분 하드코딩 → 기본 무제한(0). 연속 3회 게이트 실패 안전장치는 유지
- **커스텀 타임아웃 지원**: `/wj:loop start <task-id> <분>` 형식으로 원하는 타임아웃 설정 가능

## [3.2.0] — 2026-04-15

### Added
- **디자인 레퍼런스 체계 (`references/design/`)**: 7개 문서 — DESIGN_QUALITY_STANDARDS, ANTI_SLOP_PATTERNS, TYPOGRAPHY_SYSTEM, COLOR_SYSTEM, SPACING_RHYTHM, LAYOUT_PATTERNS, MOTION_PRINCIPLES
- **`design-dev` 에이전트**: 시각적 설계 + CSS/스타일 구현 전문가. Anti-Slop 원칙 기반, DESIGN.md 토큰 준수
- **`design-reviewer` 에이전트**: 디자인 품질 리뷰 게이트. PASS/WARN/FAIL 3단 판정, 접근성(WCAG AA) 검증
- **`security-auditor` 에이전트**: OWASP Top 10 보안 감사. CRITICAL/HIGH/MEDIUM/LOW 심각도 분류
- **`test-engineer` 에이전트**: 테스트 설계 전문가. 커버리지 갭 분석, 엣지케이스 도출, AAA 패턴
- **`/wj:design` 스킬**: 디자인 기획 워크플로우 (방향 설정 → 구현 → 리뷰 3단계)
- **`/wj:polish` 스킬**: 기존 UI 개선 워크플로우 (진단 → 처방 → 검증 사이클)
- **`rules/design.md`**: CSS/스타일 파일 자동 적용 규칙 (Anti-Slop, 디자인 토큰, 접근성)
- **INDEX.md 디자인 섹션**: UI 작업 시 디자인 레퍼런스 자동 로드 + Hard limits

### Changed
- **에이전트 5개 → 9개**: frontend-dev, backend-dev, engine-dev, design-dev, design-reviewer, security-auditor, test-engineer, qa-reviewer, docs-keeper
- **스킬 6개 → 8개**: design, polish 추가
- **규칙 4개 → 5개**: design.md 추가
- **devrule 워크플로우 강화**: 테스트 보강 → 디자인 리뷰 + 보안 감사 + QA 리뷰 병렬 검수 체계
- **loop 워크플로우 강화**: plan 시 디자인 task 자동 태깅, Step D에 design-reviewer 병렬 투입
- **help.md 업데이트**: 9개 에이전트 + 8개 스킬 반영
- **README.md 전면 재작성**: 설치 구조, 에이전트 도식, 워크플로우, 디자인 체계 전체 반영

## [3.1.0] — 2026-04-13

### Added
- **6개 언어 품질 게이트**: Go, Rust, Swift, Kotlin standards 추가. gate-l1(정적감사), gate-l2(타입체크/컴파일), gate-l3(테스트), quality-check 모두 6개 언어 지원
- **`/wj:loop plan` 명령**: 요구사항 분석 → PRD + tasks.json + specs 자동 생성. spec에 줄 번호/before-after/의존성 포함 필수
- **`references/INDEX.md` 라우터**: 언어 감지 → 해당 언어 레퍼런스만 로드 (컨텍스트 절약)
- **SubagentStop 훅 (`subagent-gate.sh`)**: 서브에이전트 응답 종료 시 L1 게이트 자동 실행
- **민감 파일 차단 (`block-sensitive-write.sh`)**: .env, .pem, credentials 등 Write/Edit 차단
- **함수 길이 체크**: quality-check.sh에서 6개 언어 함수 길이 경고 (awk 기반)
- **Cyclomatic Complexity 체크**: gate-l1.sh에서 Python(ruff C901), Go(gocyclo) 자동 검증
- **`lib/patterns.sh` 공통 패턴 라이브러리**: gate-l1과 quality-check가 동일 정규식 공유

### Fixed
- **gate-l1.sh 조기 종료 버그**: TS 실패 시 다른 언어 검사가 skip되던 문제 → 누적 보고로 전환
- **block-dangerous.sh 우회 가능**: `rm --recursive --force /`, `rm -r -f /` 차단 + dd/mkfs/forkbomb 추가
- **session-summary.sh v2 잔재**: `tests.json` 참조 제거
- **!. 카운트 부정확**: `!==`, `!important` false positive 제거
- **learn 스킬 v2 경로**: WEB_DEV_REFERENCE → MACOS_DEV_REFERENCE
- **help.md 팬텀 스킬**: 없는 `/wj:standards` 참조 제거
- **참조 경로 22곳 수정**: 레퍼런스 디렉토리 재구조화에 따른 깨진 경로 전수 수정

### Changed
- **references/ 디렉토리 재구조화**: 평탄 구조 → `common/`, `typescript/`, `python/`, `go/`, `rust/`, `swift/`, `kotlin/` 언어별 분류
- **비루프 모드 게이트 강화**: Stop 훅에서 L1+L2 자동 실행 (이전: L1만)
- **devrule 스킬 강화**: INDEX.md 기반 언어 감지 + 규모별 에이전트 위임 (S/M/L)
- **스킬 DRY**: 5개 스킬의 품질 기준 블록 → `SKILL_PREAMBLE.md` 추출
- **stop-loop.sh 리팩토링**: `_run_l1()`, `_run_l2()` 공통 함수 추출
- **세션 시작 리마인더**: 핵심 규칙 + tasks 진행률 출력
- **에이전트 모델 정책 주석**: 5개 에이전트에 모델 선택 사유 명시
- **journal 제한 상향**: 10 → 30개 변경 파일 기록

## [3.0.0] — 2026-04-12

### Breaking
- 외부 Ralph v2 루프 전체 삭제 (ralph.sh, lib/, prompts/, schemas/)
- 커맨드 7개 삭제 (brand, harness, plan, result, smoke-init, spec-init, standards)
- 스킬 7개 삭제 (init-prd, implement-next, feedback-to-prd, seo-optimizer, ui-ux-pro-max, senior-frontend, backend-dev-rules)
- 플러그인 소스 plugins/ → src/ 이동
- shared-references/ → references/ 이름 변경
- /wj:init 완전 재설계 — docs/ + .dev/ + CLAUDE.md 3개 엔트리만 생성
- bootstrap.sh 자동 복사/패치/commit 전부 제거

### Added
- `/wj:loop` — 세션 내 자율 개발 루프 (Stop hook 기반)
- `/wj:verify` — 전체 빌드+테스트 수동 실행
- L1/L2/L3 경량 품질 게이트 (gate-l1.sh, gate-l2.sh, gate-l3.sh)
- .dev/journal/ 일지 자동 기록
- .dev/state/loop.state 루프 상태 머신
- bats 테스트 스위트 (13 tests)

### Changed
- help.md v3 커맨드 반영
- bootstrap.sh 경량화 (176줄 → 23줄)

## 2.3.9 — 2026-04-07

### Fixed
- **quality-gate.sh 한글 변수명 크래시**: `$lines줄` → `${lines}줄`. audit에서 300줄 초과 파일 감지 시 `unbound variable`로 스크립트 종료되던 문제

## 2.3.8 — 2026-04-07

### Fixed
- **Worker/Reviewer 품질 표준 문서 미참조**: 체크리스트에 "Branded Types 적용", "Result 패턴" 등 언급하면서 정작 상세 문서를 안 읽고 있던 문제. BRANDED_TYPES, RESULT, DU, NON_NULL, REFACTORING_PREVENTION, ZUSTAND_SLICE, LIBRARY_TYPE_HARDENING 전부 필수 로드에 추가
- **Reviewer 언어별 standards 누락**: `standards/{언어}.md` 참조 추가

## 2.3.7 — 2026-04-07

### Fixed
- **Planner가 spec 파일을 안 읽는 문제**: 필수 문서 로드에 `specs/{task-id}.md` 추가. eligible task 선별 후 spec을 Read로 로드하여 구현 범위/복잡도를 파악하도록 개선

## 2.3.6 — 2026-04-07

### Fixed
- **Quality Gate 테스트 출력 터미널 노출**: build/test의 stdout을 quality-gate.sh 내부에서 로그 파일로 리다이렉트. 실패 시 마지막 20~30줄만 표시
- **Smoke test 매 iteration 타임아웃**: 서버 기동이 필요한 smoke test를 매 iteration마다 실행하는 구조적 문제. `RALPH_SMOKE=1` 환경변수가 있을 때만 실행하도록 변경 (기본 skip)
- **Smoke test timeout 300s → 120s**: macOS timeout 호환 방식 통일 (백그라운드 + wait)

## 2.3.5 — 2026-04-07

### Fixed
- **Worker 모니터링 무한 "0줄 출력" 스팸**: `claude -p`가 파이프에서 출력을 버퍼링하여 로그 파일이 완료까지 빈 상태 유지. 로그 기반 모니터링을 제거하고 경과 시간 스피너로 교체

## 2.3.4 — 2026-04-07

### Fixed
- **ralph.sh `local` 키워드 크래시**: Worker 모니터링 코드가 메인 for 루프(함수 밖)에서 `local` 사용하여 `can only be used in a function` 에러. 일반 변수(`_wlog`, `_wnum` 등)로 교체

## 2.3.3 — 2026-04-07

### Fixed
- **Quality Gate 로그 폭주**: `tee`로 빌드/테스트 전체 stdout이 터미널에 출력되던 문제. 로그는 파일로만 저장하고 터미널에는 `[quality-gate]`/`[audit]` 요약만 출력

### Added
- **Worker 실시간 진행 모니터링**: Stage 2에서 5초 간격으로 각 Worker의 마지막 의미 있는 로그 라인을 터미널에 표시. Worker 완료 시 ✅/❌ 카운트 요약 출력

## 2.3.1 — 2026-04-07

### Fixed
- **ralph.sh 연속 실패 카운터 크래시**: `$MAX_CONSECUTIVE_FAILS회`에서 한글 `회`가 bash 변수명 일부로 해석되어 `unbound variable` 에러 발생. `${MAX_CONSECUTIVE_FAILS}회`로 중괄호 감싸기 (3곳)

## 2.3.0 — 2026-04-07

### Changed
- **범용 하네스 전환**: 플러그인 전체 문서에서 프로젝트 귀속 예시(crypto-holdem/포커 도메인) 제거. 모든 shared-references, skills, commands, agents, templates를 도메인 무관한 패턴 설명 문서로 리라이트
- **shared-references 7개 리라이트**: BRANDED_TYPES, RESULT, DU, NON_NULL, REFACTORING_PREVENTION, ZUSTAND_SLICE, LIBRARY_TYPE_HARDENING — 이커머스/SaaS 범용 예시로 교체
- **standards 2개 리라이트**: typescript.md, python.md — 포커 타입/페이즈를 범용 도메인(Order, User, Money)으로 교체
- **skills 13개 일괄 수정**: 핵심 규칙 섹션의 도메인 귀속 예시 제거. init-prd, feedback-to-prd 대폭 리라이트
- **agents 5개 수정**: 하드코딩된 플러그인명 → 상대경로 참조로 전환
- **commands 3개 수정**: brand, help, standards의 포커 예시 → 범용 예시
- **참조 경로 정합성 수정**: 3개 스킬의 dead link(`references/HIGH_QUALITY_CODE_STANDARDS.md`) → 올바른 shared-references 경로로 수정
- **Ralph reviewer 프롬프트**: "게임" → "주요 기능"으로 범용화

## 2.2.2 — 2026-04-07

### Fixed
- **Ralph Quality Gate 실시간 로그**: Stage 0/3/5 출력이 로그 파일로만 리다이렉트되어 터미널에 안 보이던 문제 수정 (`> file` → `| tee file`)
- **smoke-test timeout 추가**: smoke-test.sh hang 시 Ralph 전체가 무한 대기하던 문제. 기본 5분(300s) timeout + 포트 프로세스 자동 정리 (`SMOKE_TIMEOUT` 환경변수로 조정 가능)
- **smoke-test 템플릿 trap cleanup 기본 활성화**: 서버 프로세스가 정리 안 되는 근본 원인 해소

## 2.2.1 — 2026-04-07

### Fixed
- **spec-init 품질 강화**: tests.json 복붙 금지를 명시. Serena 코드 분석 → 현재 코드 분석/구현 방향/Before-After/테스트 케이스를 구체적으로 작성하도록 절차 전면 개정. 템플릿에 "현재 코드 분석", "테스트 계획" 섹션 추가.

## 2.2.0 — 2026-04-07

### Added
- **`/wj:spec-init` 커맨드**: 기존 tests.json 기반으로 누락 spec 일괄 생성 + 기존 spec 정합성 검증. 템플릿(배경, AC, 설계, 구현 가이드, Edge Cases, 회귀 체크, 의존성) 포함.
- **`⚡ 즉시 실행` 블록 일괄 추가**: standards, check, harness, brand, result, plan 커맨드 6개에 즉시 실행 지시 추가. Claude가 지시를 수행하지 않는 문제 방지.
- **install.sh CLAUDE.md/LESSONS.md 자동 생성**: 없으면 빈 파일로 touch. Ralph 프롬프트가 필수로 참조하는 파일 누락 방지.

### Fixed
- **reviewer.md 번호 오류**: 4번이 중복이던 것 → 4, 5로 수정.
- **release 스킬 플러그인 외부로 이동**: 개발용 릴리스 스킬이 배포되는 플러그인에 포함되지 않도록 `.claude/commands/`로 분리.

### Changed
- **릴리스 스킬 전면 개정**: description/숫자 동기화 검증을 필수 단계로 추가.
- **커맨드 9→10개**: `/wj:spec-init` 추가.

## 2.1.1 — 2026-04-07

### Changed
- **release 스킬을 플러그인 밖으로 이동**: `plugins/woojoo-magic/skills/release/` → `.claude/commands/release.md` (프로젝트 로컬 커맨드). 배포되는 플러그인에 개발용 릴리스 스킬이 포함되지 않도록 분리.
- **Skills 14개 → 13개**: release 제거에 따른 description/help.md 숫자 동기화.

## 2.1.0 — 2026-04-07

### Fixed
- **`/wj:init` Step 2 미실행 수정**: `⚡ 즉시 실행` 블록 추가 — Claude가 install.sh(Step 1)만 실행하고 멈추던 문제 해결. Step 1~3 전부 수행을 명시적으로 강제.

### Changed
- **릴리스 스킬 전면 개정**: description/숫자 동기화 검증을 필수 단계로 추가. 커맨드 수, 스킬 수, 에이전트 수를 실제 파일과 대조하고 help.md/marketplace.json/plugin.json 전부 일치시킨 후에만 커밋 허용.

## 2.0.1 — 2026-04-07

### Fixed
- **`/wj:init` Step 2 미실행 수정**: `⚡ 즉시 실행` 블록 추가 — Claude가 install.sh(Step 1)만 실행하고 멈추던 문제 해결. Step 1~3 전부 수행을 명시적으로 강제.

## 2.0.0 — 2026-04-07

### Changed
- **Worker 모델 opus 승격**: Worker sonnet→opus, Planner haiku→sonnet으로 모델 업그레이드.
- **`/wj:init` 완전 재설계**: 한 번 실행으로 Ralph 전체 준비 완료.
  - CODE(ralph.sh, lib/, prompts/, schemas/) 항상 최신 덮어쓰기가 기본. `--force-code` 폐기.
  - prd.md ↔ tests.json ↔ specs/ 정합성 검증 + 누락 필드/내용 자동 보충.
  - smoke-test.sh 없으면 스택 감지 후 자동 생성.
- **Planner에 failure/feedback 참조 추가**: `last-failure.log`, `review-feedback.log`를 읽고 실패 task 재선별/피드백 task 우선 배치.
- **Reviewer에 HIGH_QUALITY_CODE_STANDARDS.md 명시적 로드 지시 추가**.
- **6-stage pipeline 명칭 정정**: "5-stage" → "6-stage" (Stage 0~5).
- **`--force-code` 참조 전체 제거**: help.md, standards.md, README.md에서 폐기된 플래그 참조 정리.

## 1.8.2 — 2026-04-07

### Changed
- **Ralph README.md 전면 업데이트**: v1.7.3~1.8.1 신규 기능(smoke test, review-feedback, last-failure, high-risk 감지) 전부 반영. 상태 파일 목록, 필수 파일 목록, pipeline 표 갱신.
- **plugin.json/marketplace.json description 동기화**: 9 commands + 14 skills + Ralph v2 신규 기능 반영.
- **help.md 스킬 수 보정**: 13개 → 14개 (`/release` 누락 수정).

## 1.8.1 — 2026-04-07

### Added
- **`/wj:smoke-init` 커맨드**: 프로젝트 스택(프레임워크, DB, 인증)을 감지하고 핵심 플로우를 검증하는 `smoke-test.sh`를 자동 생성.
- **`wj:init`에 smoke-test.sh 템플릿 포함**: Ralph 설치 시 smoke-test.sh 골격이 함께 생성됨. 주석 해제 후 프로젝트에 맞게 수정하여 사용.

## 1.8.0 — 2026-04-07

### Added
- **Smoke Test 지원**: 프로젝트 루트에 `smoke-test.sh`가 있으면 Quality Gate에서 빌드/테스트 후 자동 실행. E2E 핵심 플로우 검증 가능.
- **High-Risk 변경 감지**: auth/middleware/guard/route/session 파일 변경 시 scope 제한 무시하고 전체 빌드+테스트 강제 실행.
- **Reviewer 회귀 위험 평가**: 체크리스트 섹션 G 추가 — 인증/라우트/환경변수/shared 타입 변경의 회귀 영향 필수 평가.
- **Worker 크로스 패키지 검증 강화**: 인증/미들웨어 변경 시 전체 엔드포인트 접근성, 환경변수 분기 양쪽 테스트 필수화.

## 1.7.5 — 2026-04-06

### Added
- **Reviewer 피드백 자동 전달**: `CHANGES_REQUESTED` 감지 시 `review-feedback.log`에 저장하고, 다음 iteration Worker가 피드백을 우선 수정하도록 자동화. Worker 성공 시 피드백 파일 자동 삭제.

## 1.7.4 — 2026-04-06

### Added
- **시작 배너에 플러그인 버전 표시**: Ralph 실행 시 `Ralph v2 Autonomous Loop (woojoo-magic vX.Y.Z)` 형태로 현재 플러그인 버전 출력.

## 1.7.3 — 2026-04-06

### Fixed
- **Pre-Gate 임시 파일 오탐 수정**: `.bak/.tmp/.orig` 파일이 dirty tree로 감지되어 루프가 중단되던 문제 해결. pathspec 제외 + 자동 삭제 정리 추가.
- **Rollback 후 동일 실패 반복 방지**: 롤백 시 실패 원인을 `last-failure.log`에 기록하고, Worker가 다음 iteration에서 참조하여 같은 실수를 반복하지 않도록 개선.
- **Housekeeping 커밋 실패 연쇄 차단 수정**: post-gate 하우스키핑 커밋 실패 시 `git checkout`으로 복원하여 다음 pre-gate 차단 방지.

## 1.7.2 — 2026-04-06

### Added
- **Stage별 소요 시간 로그**: 각 Stage 완료 시 `Stage N 완료 Xs` 출력으로 병목 즉시 파악 가능.
- **spec 로드 확인 로그**: Worker/Reviewer가 spec 읽었는지 `✅ spec 로드` / `⚠️ spec 없음` 명시 출력. Planner도 eligible task의 spec 유무 표시.

## 1.7.1 — 2026-04-06

### Fixed
- **Planner 16분 지연 수정**: 전 Stage 공통 `--max-turns 200`을 역할별로 분리 (Planner 30, Worker 200, Reviewer 50). Haiku가 MCP 도구를 과도 호출하며 빙빙 돌던 문제 해결.

## 1.7.0 — 2026-04-06

### Added
- **init-prd 추가 모드**: 기존 prd.md/tests.json이 있으면 자동으로 추가 모드 전환. 새 task만 append, 기존 항목 수정 금지. "태스크 추가", "기능 추가", "task 추가해줘" 등 트리거 키워드 추가.

## 1.6.0 — 2026-04-06

### Added
- **specs/ 상세 기획 시스템**: 각 task에 `specs/{task-id}.md` 상세 설계 문서를 연결. tests.json에 `spec` 필드 추가. Worker가 구현 전 반드시 spec을 읽고, Reviewer가 spec 대비 구현 일치를 검증. init-prd/feedback-to-prd 스킬에서 spec 파일 동시 생성. 5개 에이전트 모두 spec 참조 가이드 추가.

## 1.5.2 — 2026-04-06

### Fixed
- **Quality Gate tests.json summary 자동 보정**: Worker가 summary 카운트를 잘못 계산해도 rollback하지 않고 features 배열 기준으로 자동 보정 후 진행. 배열 파괴(features < 2)는 여전히 FAIL.

## 1.5.1 — 2026-04-06

### Fixed
- **인프라 자동 업그레이드 후 커밋 누락**: bootstrap.sh가 ralph.sh/lib/prompts/schemas를 덮어쓴 뒤 커밋하지 않아 다음 pre-gate에서 dirty tree로 루프가 중단되던 문제. 업그레이드 직후 `--no-verify` 자동 커밋 추가.

## 1.5.0 — 2026-04-06

### Fixed
- **Worker 대기 모드 진입 버그**: 프롬프트 내 `$PLAN_FILE`, `$RALPH_ITER` 등 환경변수가 리터럴 텍스트로 전달되어 Worker가 plan 파일을 찾지 못하고 "작업 지시를 기다리고 있습니다" 상태에 빠지던 문제. `envsubst`로 실제 값 치환 추가.
- **전 Stage 즉시 실행 지시 추가**: Planner/Worker/Reviewer 프롬프트 끝에 명시적 실행 명령 섹션 추가. Claude가 대기 모드 없이 바로 작업 시작.

## 1.4.0 — 2026-04-06

### Added
- **iteration 배너에 남은 task 카운트 표시**: Ralph 루프 iteration 시작 시 tests.json에서 passing/total을 읽어 `남은 task: N/M` 출력. 진행 상황을 한눈에 파악 가능.

## 1.3.0 — 2026-04-06

### Added
- **플러그인 업데이트 시 프로젝트 인프라 자동 업그레이드**: 매 세션마다 plugin.json 버전과 `.ralph-state/.plugin-version`을 비교하여 `ralph.sh`, `lib/`, `prompts/`, `schemas/`를 자동 덮어씀. 사용자 데이터(prd.md, tests.json, progress.md)는 건드리지 않음. 이전에는 플러그인을 업데이트해도 이미 설치된 프로젝트의 Ralph 인프라가 구버전으로 남아 버그 수정이 전파되지 않았음.

## 1.2.3 — 2026-04-06

### Fixed
- **하우스키핑 커밋 hook 실패 시 루프 중단 방지**: post-gate·pre-gate의 하우스키핑 커밋에 `--no-verify` 추가. pre-commit hook 실패 시 양쪽 커밋이 모두 실패하여 dirty tree로 루프가 중단되던 edge case 수정.

## 1.2.2 — 2026-04-06

### Fixed (Ralph v2 P0)
- **Worker의 tests.json 배열 파괴 방지**: Worker(sonnet)가 task 완료 시 features 배열 전체를 유지하지 않고 단일 task 객체만 Write하여 35개 배열이 1개로 파괴되던 문제. worker.md/implement-next에 Read-Modify-Write 5단계 명시 + ⛔ 경고 추가.
- **Quality Gate tests.json 무결성 검증 추가**: features 배열 2개 미만 시 즉시 FAIL + features 개수와 summary 합계 불일치 시 FAIL. Worker가 배열을 파괴해도 Quality Gate에서 잡혀 rollback 수행.

## 1.2.1 — 2026-04-06

### Fixed (Ralph v2 P0)
- **post-gate 하우스키핑 미커밋으로 iter 2+ 차단**: `post-gate.sh`가 worker commit 이후에 `tests.json` summary를 재계산하고 `progress.md`에 iteration 로그를 append하면서도 이 변경을 커밋하지 않아, 다음 iteration의 pre-gate가 `M tests.json` / `M progress.md` dirty tree로 즉시 중단되던 문제. post-gate 끝에 `chore(ralph): iter-XX housekeeping` 자동 커밋 추가. 추가 안전망으로 pre-gate에도 회수 로직을 넣어 **tests.json/progress.md 단독 dirty**인 경우 자동으로 복구 커밋 후 진행.

## 1.2.0 — 2026-04-06

### Fixed (Ralph v2 P0)
- **pre-gate `.ralph-state/` self-block**: Ralph 런타임 산출물(`checkpoint-*.sha`, `plan-*.json`, `metrics.jsonl`, `quality-pre-*.json`)이 dirty 체크를 막아 iteration 2+가 거부되던 문제. `git status --porcelain`에 `:!:.ralph-state` pathspec 적용 + `install.sh`가 `.gitignore`에 `.ralph-state/` 블록 자동 패치 (`stack.json`만 유지).
- **Quality Gate task scope 미인지**: 단일 task 구현 후 전체 모노레포 테스트를 돌려 타 pending task의 선작성 Red 테스트로 롤백되던 문제. `plan-${iter}.json`의 `affected_packages`를 읽어 `pnpm --filter='*<pkg>*'` 패턴으로 build/test scope 제한 (pnpm monorepo 한정).

### Added
- **감사 5종 스크립트** (`lib/quality-gate.sh` → `audit_diff_files()`): 이번 iteration diff 파일만 대상으로 300줄 초과, `any`, non-null `!.`, silent `catch {}`, `eslint-disable no-explicit-any` 차단.
- **`prompts/worker.md` 필수 문서 Read 강제**: `HIGH_QUALITY_CODE_STANDARDS.md` + 언어별 standards 직접 로드 의무화. "문서 미로드 상태로 구현 시작 금지".
- **`prompts/planner.md` TDD Red 선 작성 격리 정책**: `affected_packages` 엄격 격리로 타 패키지 pending Red가 현재 iteration을 막지 않음.

## 1.1.0 — 2026-04-05

### Added
- **`/wj:standards` 신규 커맨드**: `HIGH_QUALITY_CODE_STANDARDS.md` + 언어별 standards 문서를 세션에 로드하여 이후 모든 코드 작성·수정·리뷰에 표준을 강제 적용. 새 기능 구현·리팩토링·PR 준비 전 호출.
- **Python Standards (`shared-references/standards/python.md`)**: 2026 실리콘밸리 표준 반영.
  - 툴체인: Ruff + Pyright strict + pytest-cov (80%+)
  - 타입 안전성: `Any` 금지, `NewType` (Branded Types 대응), `Protocol` (구조적 서브타이핑), `Literal` + frozen dataclass + `match` (DU 대응)
  - 에러 처리: EAFP + 경계 규율, bare/silent except 금지, `raise ... from e` 필수
  - 복잡도: Cyclomatic Complexity ≤ 10 (Ruff C901), 파일 400줄 / 함수 30줄 soft limit
  - 레이어 분리: `domain ← application ← infrastructure/interface`
- **TypeScript Standards (`shared-references/standards/typescript.md`)**: 기존 TS 전용 규칙 분리 (파일 300줄/함수 20줄 hard limit, Branded Types, Result<T,E>, DU, `any`/`!` 금지).

### Changed
- **`HIGH_QUALITY_CODE_STANDARDS.md` v2 → v3**: 공통 원칙(언어 불문)과 언어별 디스패처 구조로 리라이트. 9개 불변 원칙(SRP, 타입 안전성, 불변성, 레이어 분리, Silent failure 금지, 복잡도 ≤10, DRY, 테스트 우선, 검증 전 완료 주장 금지) + 언어별 문서 링크.
- **`/wj:check` 언어 자동 감지**: TS(`package.json`, `*.ts`) / Python(`pyproject.toml`, `*.py`) 감지 후 해당 규칙 적용. Python 점검 추가: 400줄 초과, `Any`, bare/silent except, mutable default argument, Ruff C901 복잡도.
- **`/wj:help`**: 콤팩트 재구성, `/wj:standards` 반영, shared-references 목록 갱신.

## 1.0.2 — 2026-04-05

### Fixed
- **block-dangerous.sh 오탐 수정**: `> /dev/` 패턴이 `2>/dev/null` 같은 일반적인 stderr 리다이렉트까지 차단하던 버그. `/dev/null`, `/dev/stderr`, `/dev/stdout`, `/dev/tty`, `/dev/fd/*` 화이트리스트 방식으로 전환하여 실제 장치(`/dev/sda` 등) 쓰기만 차단.

## 1.0.0 — 2026-04-05

### 초기 릴리스

crypto-holdem 프로젝트의 Phase 1-7 리팩토링 여정에서 축적된 실전 패턴을 플러그인화.

#### Added
- **Skills (13개)**: devrule, senior-frontend, backend-dev-rules, commit, learn, team, ui-ux-pro-max, cto-review, init-prd, ideation, feedback-to-prd, implement-next, seo-optimizer
- **Agents (5개)**: frontend-dev, backend-dev, engine-dev, qa-reviewer, docs-keeper (Creator-Reviewer 패턴)
- **Shared References (8개)**:
  - HIGH_QUALITY_CODE_STANDARDS.md (파일/함수/Props 한계, 타입 안전, 성능, DRY)
  - BRANDED_TYPES_PATTERN.md
  - RESULT_PATTERN.md
  - DISCRIMINATED_UNION.md (wrapSetWithPhase 무침습 도입)
  - NON_NULL_ELIMINATION.md
  - LIBRARY_TYPE_HARDENING.md (viem 실전 예시)
  - ZUSTAND_SLICE_PATTERN.md
  - REFACTORING_PREVENTION.md
- **Ralph v2**: 5-Stage Pipeline (Pre-Gate → Planner → Workers → Quality-Gate → Reviewer → Post-Gate)
  - 모델 라우팅 (haiku/sonnet/opus)
  - 병렬 워커 (`--parallel N`)
  - 품질 회귀 자동 차단 (`--strict`)
  - 자동 git rollback
  - append-only metrics.jsonl
- **MCP (10개)**: serena, context7, sequential-thinking, playwright, chrome-devtools, shadcn, magic, tavily-remote, memory, smithery-ai-github
- **Hooks (4개)**: install-mcp (dedup 자동 설치), session-summary, block-dangerous, quality-check
- **Commands (6개)**: /woojoo:init-ralph, check-quality, apply-branded, apply-result, refactor-plan, check-harness
- **Rules (4개)**: frontend, server, shared-engine, tests (레이어별 규칙 템플릿)

#### 주요 설계 결정
- **SessionStart 훅으로 MCP 자동 dedup 설치**: 기존 `~/.claude.json`과 비교 후 누락된 것만 프로젝트 `.mcp.json`에 병합. 재실행 방지 마커 사용.
- **모든 스킬이 shared-references 중앙 참조**: 중복 제거 + 단일 진실 공급원.
- **Ralph v2는 Creator-Reviewer 분리**: 같은 인스턴스가 짜고 리뷰하는 bias 제거.
- **품질 델타 추적**: iteration마다 300줄/any/!./tests 메트릭 기록 → 회귀 시 즉시 중단.
