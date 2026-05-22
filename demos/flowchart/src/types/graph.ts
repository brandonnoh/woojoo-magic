/**
 * wj-magic 워크플로우 그래프 타입 정의.
 * 노드는 4가지 카테고리: entry / command / skill / agent / hook
 */

export type NodeCategory =
  | "entry" // 진입점 (아이디어 있음/없음)
  | "command" // 슬래시 커맨드 (8개)
  | "skill" // 워크플로우 스킬 (16개)
  | "agent" // 전문가 에이전트 (21개)
  | "hook"; // 자동 품질 게이트 훅 (7개)

export type AgentRole = "implement" | "review" | "analyze" | "audit";

export type NodeId = string & { readonly __brand: "NodeId" };
export const asNodeId = (s: string): NodeId => s as NodeId;

export interface NodeScenario {
  /** 사용자가 자연어로 말한 문장 (또는 슬래시 호출) */
  user: string;
  /** 어떤 일이 벌어지는지 한 문장 결과 묘사 */
  outcome: string;
}

export interface FlowNode {
  id: NodeId;
  category: NodeCategory;
  label: string; // 짧은 표시명 (예: "brainstorm")
  full: string; // 정식명 (예: "/wj-magic:brainstorm")
  summary: string; // 한 줄 요약 (사이드패널 상단)
  detail: string; // 상세 설명 (2~4문장)
  example?: string; // 예시 명령어 / 호출 패턴
  triggers?: string[]; // 트리거 키워드 (스킬에 한해서)
  agentRole?: AgentRole; // 에이전트에 한해서
  /** 실 사용 시나리오 — 사용자 발화 + 그에 따른 결과 */
  scenarios?: NodeScenario[];
  /** 산출물 (생성되는 파일·아티팩트 경로 등) */
  outputs?: string[];
  position: { x: number; y: number }; // SVG 좌표 (viewBox 기준)
  /** 트리에서 진입점부터 이 노드까지 도달하는 데 필요한 선행 노드 */
  requires?: NodeId[];
}

export interface FlowEdge {
  from: NodeId;
  to: NodeId;
  /** 분기 라벨 (예: "S", "M", "L", "디자인 작업") — 선택 사항 */
  label?: string;
  /** 분기 유형 — 시각적으로 다르게 표시 */
  kind?: "primary" | "secondary" | "size-S" | "size-M" | "size-L" | "loop";
}

export interface FlowGraph {
  nodes: FlowNode[];
  edges: FlowEdge[];
}
