import { asNodeId, type FlowNode } from "../types/graph";
import { COL, ROW } from "./grid";

export const COMMAND_NODES: FlowNode[] = [
  {
    id: asNodeId("cmd-init"),
    category: "command",
    label: "/init",
    full: "/wj-magic:init",
    summary: "프로젝트 최초 세팅 — docs/, .dev/, CLAUDE.md 구조 생성",
    detail:
      "프로젝트당 한 번만 실행. docs/, .dev/, CLAUDE.md 표준 구조를 자동 생성하고 MCP 필수 사용 규칙을 CLAUDE.md 최상단에 박는다.",
    example: "/wj-magic:init",
    position: { x: COL.c1, y: 200 },
  },
  {
    id: asNodeId("cmd-loop"),
    category: "command",
    label: "/loop",
    full: "/wj-magic:loop",
    summary: "자율 개발 루프 — PRD 생성 → 에이전트 구현 → 검증 반복",
    detail:
      "랄프 루프. /wj-magic:loop plan 으로 PRD + 태스크 목록을 만들고 /wj-magic:loop start 로 자율 반복 진입. 규모 판정(S/M/L) → 위임 → QA → 커밋 → 다음을 멈출 때까지 반복.",
    example: "/wj-magic:loop plan\n/wj-magic:loop start",
    position: { x: COL.c8, y: ROW.upper },
  },
  {
    id: asNodeId("cmd-check"),
    category: "command",
    label: "/check",
    full: "/wj-magic:check",
    summary: "코드베이스 품질 전수 점검 리포트",
    detail:
      "L1 게이트 기준으로 코드베이스 전체를 스캔. 파일 300줄·any·!. silent catch 위반 목록을 카테고리별로 리포트.",
    example: "/wj-magic:check",
    position: { x: COL.c8, y: ROW.bottom },
  },
  {
    id: asNodeId("cmd-help"),
    category: "command",
    label: "/help",
    full: "/wj-magic:help",
    summary: "커맨드·스킬 전체 목록과 사용법",
    detail: "전체 커맨드 8개 + 스킬 16개 사용법을 한눈에. 처음 설치한 사람이 가장 먼저 호출하는 진입점.",
    example: "/wj-magic:help",
    position: { x: COL.c0, y: 200 },
  },
];
