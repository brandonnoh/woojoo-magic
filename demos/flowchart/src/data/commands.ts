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
    scenarios: [
      {
        user: "방금 git init 한 빈 프로젝트야. 표준 구조부터 잡아줘",
        outcome: "→ docs/·.dev/·CLAUDE.md 생성, MCP 규칙·품질 기준 자동 주입",
      },
    ],
    outputs: [
      "CLAUDE.md  (MCP 필수 사용 + 품질 게이트 규칙)",
      "docs/ARCHITECTURE.md  (구조 설명 템플릿)",
      ".dev/state/, .dev/tasks.json  (루프용 상태 폴더)",
    ],
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
    scenarios: [
      {
        user: "이 PRD 따라서 끝까지 알아서 진행해줘",
        outcome: "→ 태스크 분해 → 에이전트 위임 → L1~L3 게이트 → 커밋 반복",
      },
      {
        user: "방금 만든 audit 리포트 그대로 fix까지 자동으로 돌려",
        outcome: "→ audit 태스크를 loop plan에 주입, start 시 순차 자동 수정",
      },
    ],
    outputs: [
      ".dev/prd.md  (자동 생성된 요구 문서)",
      ".dev/tasks.json  (의존관계 포함 태스크 큐)",
      "git: 각 태스크마다 별도 커밋",
    ],
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
    scenarios: [
      {
        user: "전체적으로 코드 품질 어떤 상태인지 봐줘",
        outcome: "→ 300줄 초과 파일·any 사용·silent catch 위반 표로 정리",
      },
      {
        user: "리팩토링 우선순위 좀 잡아줘",
        outcome: "→ 위반 점수 높은 파일 Top 10 + 권장 cto-review/loop 트리거",
      },
    ],
    outputs: ["콘솔 리포트  (위반 카테고리 · 파일별 점수 · 권장 액션)"],
    position: { x: COL.c1, y: 80 },
  },
  {
    id: asNodeId("cmd-help"),
    category: "command",
    label: "/help",
    full: "/wj-magic:help",
    summary: "커맨드·스킬 전체 목록과 사용법",
    detail: "전체 커맨드 8개 + 스킬 17개 사용법을 한눈에. 처음 설치한 사람이 가장 먼저 호출하는 진입점.",
    example: "/wj-magic:help",
    scenarios: [
      {
        user: "어떤 스킬이 있는지 한 번 훑고 싶어",
        outcome: "→ 카테고리별 스킬 표 + 자연어 트리거 키워드 + 추천 진입점 안내",
      },
    ],
    outputs: ["콘솔 출력  (커맨드/스킬 표)"],
    position: { x: COL.c0, y: 80 },
  },
];
