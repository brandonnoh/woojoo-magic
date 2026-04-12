# woojoo-magic (wj) v3

> Claude Code 플러그인 — 클린 스캐폴딩 + 세션 내 자율 개발 루프

리팩토링이 필요 없는 실리콘밸리 수준 개발 환경. 세션 내 Stop hook 기반 자율 루프로 task를 자동 진행하고, L1/L2/L3 경량 품질 게이트로 코드 품질을 유지한다.

## 설치

Claude Code 마켓플레이스에서 `wj-tools` 검색 후 설치.

## 빠른 시작

```bash
/wj:init --with-prd     # 스캐폴딩 (docs/ + .dev/ + CLAUDE.md + PRD 템플릿)
# docs/prd.md 편집 → task 정의
# .dev/tasks.json 작성 → acceptance criteria
/wj:loop start           # 세션 내 자율 루프 시작
/wj:loop stop            # 중단
/wj:verify               # 전체 빌드+테스트 최종 검증
```

## 커맨드

| 커맨드 | 인자 | 역할 |
|--------|------|------|
| `/wj:help` | — | 커맨드 가이드 |
| `/wj:init` | `[--with-prd]` | 클린 스캐폴딩 |
| `/wj:loop` | `start [id] \| stop \| status` | 세션 내 자율 루프 |
| `/wj:verify` | `[--smoke]` | 전체 빌드+테스트 |
| `/wj:check` | — | 품질 전수 점검 |

## 스킬

| 스킬 | 역할 |
|------|------|
| `/wj:commit` | 한글 커밋 메시지 |
| `/wj:devrule` | 프로젝트 구조 적용 개발 |
| `/wj:learn` | 교훈 → 규칙 반영 |
| `/wj:standards` | 코드 표준 강제 |
| `/wj:cto-review` | 전수 점검 |
| `/wj:ideation` | 전문가 스쿼드 기획 |
| `/wj:team` | 에이전트 팀 병렬 작업 |

## 아키텍처

- **사람 문서 (`docs/`)** — PRD, specs, ADR. 사람이 관리하는 비즈니스 진실
- **AI 흔적 (`.dev/`)** — tasks.json, journal/, state/. AI가 자동 생성
- **CLAUDE.md** — ~100줄 프로젝트 지도
- **Stop hook 루프** — 매 턴 종료 시 L1(grep <1초) → L2(tsc ~10초) → L3(test ~30초) 게이트 자동 실행

## 품질 게이트

| 계층 | 내용 | 속도 |
|---|---|---|
| L1 | 300줄/any/!./silent catch/eslint-disable grep | <1초 |
| L2 | tsc --noEmit 증분 타입체크 | 2~10초 |
| L3 | 편집 파일 매칭 테스트만 실행 | 5~30초 |

전체 빌드/smoke test는 `/wj:verify`로 수동 실행만.

## v2에서 마이그레이션

`docs/MIGRATION.md` 참조.

## 라이선스

MIT
