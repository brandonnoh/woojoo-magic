import { asNodeId, type FlowNode } from "../types/graph";

/**
 * 자동 품질 게이트 훅 7개 — 하단 "시스템 자동" 띠 가로 배치.
 * 사용자가 직접 호출하지 않고 Claude Code 이벤트에 자동 트리거.
 */
const Y = 1060;
const XS = [240, 420, 600, 780, 960, 1140, 1320];

export const HOOK_NODES: FlowNode[] = [
  hook("bootstrap", "bootstrap", "SessionStart", ".dev/state/ 초기화 + 구버전 캐시 GC. 매 세션 시작 시 첫 실행.", XS[0]!),
  hook("session-summary", "session-summary", "SessionStart", "MCP 필수 사용 규칙 고지 + 세션 요약. 매 세션 시작 두 번째.", XS[1]!),
  hook("block-dangerous", "block-dangerous", "PreToolUse · Bash", "rm -rf, sudo, force push 등 위험 명령을 실행 전 차단.", XS[2]!),
  hook("block-sensitive-write", "block-sensitive", "PreToolUse · Edit", "인증서·키 보호 + 시크릿 패턴 차단 + Serena 리마인더.", XS[3]!),
  hook("quality-check", "quality-check", "PostToolUse", "파일 크기·시크릿 패턴 즉시 검사 (2차 안전망).", XS[4]!),
  hook("stop-loop", "stop-loop", "Stop", "L1 → L2 → L3 3단계 게이트 순차 실행.", XS[5]!),
  hook("subagent-gate", "subagent-gate", "SubagentStop", "서브에이전트 L1 + MCP 호출 흔적 정적 검출.", XS[6]!),
];

function hook(id: string, label: string, trigger: string, detail: string, x: number): FlowNode {
  return {
    id: asNodeId(`hook-${id}`),
    category: "hook",
    label,
    full: trigger,
    summary: `${trigger} 이벤트에 자동 트리거`,
    detail,
    position: { x, y: Y },
  };
}
