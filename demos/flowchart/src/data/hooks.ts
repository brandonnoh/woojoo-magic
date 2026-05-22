import { asNodeId, type FlowNode } from "../types/graph";

/**
 * 자동 품질 게이트 훅 7개 — 하단 "시스템 자동" 띠 가로 배치.
 * 사용자가 직접 호출하지 않고 Claude Code 이벤트에 자동 트리거.
 */
const Y = 1220;
const XS = [240, 420, 600, 780, 960, 1140, 1320];

interface HookSpec {
  id: string;
  label: string;
  trigger: string;
  detail: string;
  output?: string;
  x: number;
}

const SPECS: HookSpec[] = [
  {
    id: "bootstrap",
    label: "bootstrap",
    trigger: "SessionStart",
    detail:
      ".dev/state/ 폴더 초기화, 구버전 캐시 GC, 진행 중 태스크 복원. 매 세션 시작 첫 번째로 실행되어 깨끗한 작업 환경을 보장한다.",
    output: ".dev/state/  (다음 훅들이 참조)",
    x: XS[0]!,
  },
  {
    id: "session-summary",
    label: "session-summary",
    trigger: "SessionStart",
    detail:
      "MCP 필수 사용 규칙을 매 세션 첫 응답에 강제 출력, 직전 작업 요약, 품질 위반 잔존 카운트를 보여준다. \"내가 어디까지 했지?\"를 즉시 복원.",
    output: "콘솔 헤더 (브랜치·최근 커밋·위반 카운트·미완료 태스크)",
    x: XS[1]!,
  },
  {
    id: "block-dangerous",
    label: "block-dangerous",
    trigger: "PreToolUse · Bash",
    detail:
      "rm -rf, sudo, git push --force, --no-verify, DROP TABLE 등 회복 불가 명령을 실행 직전에 차단. 사용자 명시 승인 없이는 통과 불가.",
    output: "차단 메시지 (대안 명령 제안 포함)",
    x: XS[2]!,
  },
  {
    id: "block-sensitive-write",
    label: "block-sensitive",
    trigger: "PreToolUse · Edit",
    detail:
      ".env, *.pem, id_rsa 등 민감 파일 보호 + 코드 본문에 시크릿 패턴(sk_live_*, AKIA*) 출현 차단 + Serena 미사용 시 리마인더.",
    output: "차단 메시지 + Serena 호출 가이드",
    x: XS[3]!,
  },
  {
    id: "quality-check",
    label: "quality-check",
    trigger: "PostToolUse · Edit",
    detail:
      "Edit/Write 직후 해당 파일에 즉시 L1 패턴 검사 — 파일 크기, any, !., silent catch, 시크릿. 2차 안전망으로 작동.",
    output: "위반 시 즉시 경고 + Stop 훅으로 escalate",
    x: XS[4]!,
  },
  {
    id: "stop-loop",
    label: "stop-loop",
    trigger: "Stop",
    detail:
      "응답 종료 시점에 L1 (grep, <1s) → L2 (타입체커, 2~10s) → L3 (테스트, 5~30s) 순차 실행. 위반 발견 시 사용자 응답을 막고 자동 보정 시도.",
    output: "L1/L2/L3 결과 콘솔 + 차단 시 재시도 명령",
    x: XS[5]!,
  },
  {
    id: "subagent-gate",
    label: "subagent-gate",
    trigger: "SubagentStop",
    detail:
      "서브에이전트가 종료될 때 L1 검사 + MCP 호출 흔적 검증. \"Serena 안 쓰고 추측으로 수정\" 같은 패턴을 정적으로 검출해 차단.",
    output: "에이전트 산출물 재작업 요청 또는 통과",
    x: XS[6]!,
  },
];

export const HOOK_NODES: FlowNode[] = SPECS.map((s) => ({
  id: asNodeId(`hook-${s.id}`),
  category: "hook",
  label: s.label,
  full: s.trigger,
  summary: `${s.trigger} 이벤트에 자동 트리거`,
  detail: s.detail,
  outputs: s.output ? [s.output] : undefined,
  position: { x: s.x, y: Y },
}));
