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
