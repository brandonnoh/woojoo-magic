import { asNodeId, type FlowNode } from "../types/graph";
import { COL, ROW } from "./grid";

export const ENTRY_NODES: FlowNode[] = [
  {
    id: asNodeId("entry-idea-yes"),
    category: "entry",
    label: "아이디어 정해진 경우",
    full: "아이디어 있음",
    summary: "구체적인 만들 것이 정해져 있는 상태",
    detail:
      "이미 \"무엇을 만들지\"가 정해져 있다면 곧장 brainstorm으로 진입해 설계를 정제한다. 시장 분석·전략 검증이 필요 없는 상태.",
    example: "예: \"할 일 관리 앱 만들고 싶어\" / \"이 화면에 다크모드 토글 추가\"",
    scenarios: [
      {
        user: "팀 회고록을 자동으로 요약해주는 노트 앱을 만들고 싶어",
        outcome: "→ /wj-magic:brainstorm 으로 설계 대화 시작 → spec 문서 저장",
      },
      {
        user: "이 화면 헤더에 알림 아이콘 하나만 추가해줘",
        outcome: "→ S 사이즈로 판정해 /wj-magic:devrule 로 즉시 구현",
      },
    ],
    position: { x: COL.c0, y: ROW.mainA },
  },
  {
    id: asNodeId("entry-idea-no"),
    category: "entry",
    label: "아이디어 없는 경우",
    full: "아이디어 없음",
    summary: "방향 자체가 안 잡힘 — 전략 분석부터 필요",
    detail:
      "\"뭔가는 만들어야 하는데 방향이 안 잡힌다\" 단계. ideation 스쿼드 5명(PM/UX/사업/마케팅/데이터)이 병렬로 리서치해서 전략을 도출한 뒤 brainstorm으로 합류한다.",
    example: "예: \"AI 기능 어떻게 붙여야 시장에서 먹힐까?\"",
    scenarios: [
      {
        user: "AI를 활용한 사이드 프로젝트로 뭘 만들어볼 만할까?",
        outcome: "→ /wj-magic:ideation 스쿼드 5명 병렬 리서치 → MVP 후보 3안 리포트",
      },
      {
        user: "B2B SaaS 시장에서 우리 제품이 들어갈 만한 빈틈이 있을까?",
        outcome: "→ PM·사업·마케팅 관점에서 경쟁사 매핑 + 차별화 포인트 도출",
      },
    ],
    position: { x: COL.c0, y: ROW.mainB + 40 },
  },
];
