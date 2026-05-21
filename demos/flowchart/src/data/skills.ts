import { asNodeId, type FlowNode } from "../types/graph";
import { COL, ROW } from "./grid";

export const SKILL_NODES: FlowNode[] = [
  // ── 기획·발산 ──
  {
    id: asNodeId("skill-ideation"),
    category: "skill",
    label: "ideation",
    full: "/wj-magic:ideation",
    summary: "PM·UX·사업·마케팅·데이터 5명이 병렬 리서치",
    detail:
      "5개 전문가 에이전트가 동시에 시장 분석·경쟁사 벤치마크·수익화 모델·마케팅 전략·기술 아키텍처를 리서치. 통합 리포트(스쿼드 컨센서스, MVP 로드맵) 산출.",
    example: "/wj-magic:ideation",
    triggers: ["아이데이션", "시장 분석", "경쟁사 비교"],
    position: { x: COL.c1, y: ROW.mainB + 40 },
  },
  {
    id: asNodeId("skill-brainstorm"),
    category: "skill",
    label: "brainstorm",
    full: "/wj-magic:brainstorm",
    summary: "1:1 대화로 막연한 아이디어를 설계 문서로 정제",
    detail:
      "Claude와 1:1로 한 번에 하나씩 질문·답을 주고받으며 아이디어를 좁힌다. docs/specs/YYYY-MM-DD-<topic>-design.md 에 설계 문서를 저장.",
    example: "/wj-magic:brainstorm",
    triggers: ["기획해줘", "어떻게 만들까", "스펙 잡아줘"],
    position: { x: COL.c1, y: ROW.mainA },
  },
  // ── 계획·분석 ──
  {
    id: asNodeId("skill-analyze"),
    category: "skill",
    label: "analyze",
    full: "/wj-magic:analyze",
    summary: "수정 전 임팩트 분석 — 관련 파일·함수·의존 관계 특정",
    detail:
      "Serena 심볼 추적 + Context7 문서 조회 + Explore 에이전트 3종을 병렬 투입해 \"어디를 고쳐야 하는지\" 구조화된 리포트.",
    example: "/wj-magic:analyze",
    triggers: ["관련 코드 찾아줘", "영향 범위"],
    position: { x: COL.c2, y: ROW.upper },
  },
  {
    id: asNodeId("skill-plan"),
    category: "skill",
    label: "plan",
    full: "/wj-magic:plan",
    summary: "설계를 파일 단위 구현 태스크로 분해",
    detail:
      "완성된 스펙을 파일 단위·단계별 태스크 목록으로 분해. .dev/tasks.json 에 의존 관계와 함께 저장.",
    example: "/wj-magic:plan",
    triggers: ["태스크 분해", "구현 계획 세워줘"],
    position: { x: COL.c2, y: ROW.main },
  },
  // ── 구현 ──
  {
    id: asNodeId("skill-tdd"),
    category: "skill",
    label: "tdd",
    full: "/wj-magic:tdd",
    summary: "테스트 먼저 작성 → 실패 확인 → 구현",
    detail:
      "Red-Green-Refactor 사이클을 강제. 새 기능·버그 수정·리팩토링에서 회귀 방지가 중요할 때 devrule 대신 사용.",
    example: "/wj-magic:tdd",
    triggers: ["테스트 주도", "tdd", "테스트 먼저"],
    position: { x: COL.c3, y: ROW.upper },
  },
  {
    id: asNodeId("skill-devrule"),
    category: "skill",
    label: "devrule",
    full: "/wj-magic:devrule",
    summary: "코드 구현 — 규모(S/M/L)에 따라 직접 또는 에이전트 위임",
    detail:
      "S(1~3 파일): Claude 직접. M(4~10): 전문 에이전트 1명. L(10+): 에이전트 팀 worktree 병렬. 코드 작업의 기본 진입점.",
    example: "/wj-magic:devrule",
    triggers: ["구현해줘", "만들어줘", "수정해줘"],
    position: { x: COL.c3, y: ROW.main },
  },
  {
    id: asNodeId("skill-design"),
    category: "skill",
    label: "design",
    full: "/wj-magic:design",
    summary: "새 UI를 비주얼 방향부터 구현까지",
    detail:
      "처음부터 새로 만드는 UI 작업의 진입점. 비주얼 디렉션 → 디자인 시스템 선택 → 컴포넌트 구현. design-dev/design-reviewer 에이전트 자동 투입.",
    example: "/wj-magic:design",
    triggers: ["디자인해줘", "UI 만들어줘", "랜딩페이지"],
    position: { x: COL.c3, y: ROW.belowA },
  },
  {
    id: asNodeId("skill-polish"),
    category: "skill",
    label: "polish",
    full: "/wj-magic:polish",
    summary: "기존 UI 진단 → 처방 → 재구현",
    detail:
      "이미 있는 화면을 더 다듬는 작업. \"AI스러워\" 같은 피드백에 트리거. 디자인 품질 진단 후 처방·재구현.",
    example: "/wj-magic:polish",
    triggers: ["더 예쁘게", "다듬어줘", "polish"],
    position: { x: COL.c3, y: ROW.belowB },
  },
  // ── 검수·조사 ──
  {
    id: asNodeId("skill-investigate"),
    category: "skill",
    label: "investigate",
    full: "/wj-magic:investigate",
    summary: "버그·성능을 5개 에이전트가 병렬 조사",
    detail:
      "code-analyst / perf-analyst / regression-hunter / web-researcher / security-auditor 5명이 동시 조사. 근본 원인 규명 + 자동 수정.",
    example: "/wj-magic:investigate",
    triggers: ["버그", "에러", "느려"],
    position: { x: COL.c6, y: ROW.invA },
  },
  {
    id: asNodeId("skill-team"),
    category: "skill",
    label: "team",
    full: "/wj-magic:team",
    summary: "전문가 에이전트 팀을 직접 선별·병렬 투입",
    detail:
      "사용자가 직접 \"이 작업엔 이 에이전트들\"이라고 명시적으로 팀을 짜는 방식. 여러 전문 영역 걸친 작업, 대규모 병렬 처리에.",
    example: "/wj-magic:team",
    triggers: ["팀 구성", "에이전트 소환"],
    position: { x: COL.c5, y: ROW.invB },
  },
  {
    id: asNodeId("skill-cto-review"),
    category: "skill",
    label: "cto-review",
    full: "/wj-magic:cto-review",
    summary: "도메인별 CTO 팀이 전수 점검 + 자동 리팩토링",
    detail:
      "Wave 전략으로 분석 에이전트들이 전수 점검 → 수정 에이전트들이 리팩토링. 대규모 정리 필요할 때.",
    example: "/wj-magic:cto-review",
    triggers: ["전수 점검", "리팩토링"],
    position: { x: COL.c5, y: ROW.invC },
  },
  {
    id: asNodeId("skill-audit"),
    category: "skill",
    label: "audit",
    full: "/wj-magic:audit",
    summary: "8+3 보안 감사 에이전트 2-pass + 자동 수정",
    detail:
      "1차: 8개 보안 감사 에이전트 OWASP Top 10:2025 기반 병렬 감사. 2차: 3개 검증 에이전트 크로스 리뷰. 결과를 /wj-magic:loop plan 호환 태스크로 변환.",
    example: "/wj-magic:audit",
    triggers: ["보안 감사", "취약점 찾아줘", "OWASP"],
    position: { x: COL.c6, y: ROW.invB },
  },
  // ── 종결 ──
  {
    id: asNodeId("skill-verify"),
    category: "skill",
    label: "verify",
    full: "/wj-magic:verify",
    summary: "완료 주장 전 실행·통과 증거 확보 강제",
    detail:
      "\"됐어\", \"고쳤어\", \"완료\"라고 말하기 전에 반드시 호출. 전체 빌드 + 테스트를 실제로 돌려 통과 증거 확보.",
    example: "/wj-magic:verify",
    triggers: ["완료", "다 됐어", "통과"],
    position: { x: COL.c6, y: ROW.main },
  },
  {
    id: asNodeId("skill-commit"),
    category: "skill",
    label: "commit",
    full: "/wj-magic:commit",
    summary: "한글 커밋 메시지 자동 작성 (feat/fix/ui/...)",
    detail:
      "변경사항을 분석해 feat/fix/ui/ux/docs/refactor/chore/test/perf 중 적절한 타입으로 분류 후 한글 커밋 메시지 작성.",
    example: "/wj-magic:commit",
    triggers: ["커밋", "commit"],
    position: { x: COL.c7, y: ROW.main },
  },
  {
    id: asNodeId("skill-learn"),
    category: "skill",
    label: "learn",
    full: "/wj-magic:learn",
    summary: "발견된 실수·교훈을 규칙에 영구 반영",
    detail:
      "버그 수정 후 \"다음에도 안 틀리고 싶다\" 패턴이 발견되면 호출. LESSONS.md에 영구 기록.",
    example: "/wj-magic:learn",
    triggers: ["기억해", "remember"],
    position: { x: COL.c8, y: ROW.mainB },
  },
  {
    id: asNodeId("skill-explain"),
    category: "skill",
    label: "explain",
    full: "/wj-magic:explain",
    summary: "비개발자 눈높이로 코드·개념 해설",
    detail:
      "소프트웨어 공학 모르는 바이브코더를 위한 4단계 응답(한 줄 요약 → 음식점 비유 → 왜 + 대안 → 다음 단계).",
    example: "/wj-magic:explain",
    triggers: ["설명해줘", "이게뭐야", "쉽게 알려줘"],
    position: { x: COL.c2, y: 200 },
  },
];
