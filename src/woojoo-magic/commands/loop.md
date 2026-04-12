---
description: 세션 내 자율 개발 루프 — start/stop/status
argument-hint: "start [task-id] | stop | status"
---

세션 내 Ralph 루프를 제어한다. Stop hook이 매 턴 종료 시 L1/L2/L3 게이트를 거쳐 자동 재프롬프트한다.

## 사용법

| 명령 | 동작 |
|------|------|
| `/wj:loop start` | 다음 eligible task로 루프 시작 |
| `/wj:loop start <task-id>` | 특정 task로 루프 시작 |
| `/wj:loop stop` | 루프 즉시 중단 |
| `/wj:loop status` | 현재 루프 상태 표시 |

## 실행 절차

`$ARGUMENTS`를 파싱해 첫 단어로 분기:

### start

1. `.dev/tasks.json` 존재 확인. 없으면:
   ```
   ⚠️ .dev/tasks.json이 없습니다. /wj:init --with-prd 후 tasks를 정의하세요.
   ```

2. task-id 인자가 있으면 해당 task, 없으면 다음 eligible task 자동 선택:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/loop-state.sh" start "<task-id>"
   ```

3. 선택된 task 정보 출력:
   ```
   🚀 루프 시작: task=<task-id>

   Stop hook이 매 턴 종료 시 L1/L2/L3 게이트를 실행합니다.
   게이트 통과 + task 완료 시 자동으로 다음 task로 전진합니다.

   중단: /wj:loop stop
   ```

4. `docs/specs/<task-id>.md`가 있으면 **반드시 먼저 읽고** 구현 시작. 없으면 `.dev/tasks.json`의 acceptance criteria를 참조해 TDD로 구현 시작.

### stop

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/loop-state.sh" stop "manual"
```

출력:
```
⏹ 루프 중단됨. 일반 대화 모드로 복귀.
```

### status

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/loop-state.sh" status
```

출력 예시:
```
📊 루프 상태:
  active: true
  task: engine-auth-005
  iteration: 3
  연속 실패: 0
  시작: 2026-04-12T14:32:00Z
```

## ⚡ 즉시 실행
