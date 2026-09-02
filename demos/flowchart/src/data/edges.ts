import { asNodeId, type FlowEdge } from "../types/graph";

const id = asNodeId;

/**
 * wj-magic 워크플로우 분기 라인.
 * - primary: 메인 라인 (밝은 시안)
 * - secondary: 보조 라인 (흐릿한 시안)
 * - size-S/M/L: devrule 규모 분기 (각 다른 컬러)
 * - loop: 반복 화살표 (마젠타 점선)
 */
export const EDGES: FlowEdge[] = [
  // ── 진입점 → 기획 ──
  { from: id("entry-idea-yes"), to: id("skill-brainstorm"), kind: "primary" },
  { from: id("entry-idea-no"), to: id("skill-venture"), kind: "primary" },
  { from: id("skill-venture"), to: id("skill-brainstorm"), kind: "secondary", label: "생존 아이템 확정 후" },

  // ── 기획 → 분석/계획 ──
  { from: id("skill-brainstorm"), to: id("skill-plan"), kind: "primary" },
  { from: id("skill-brainstorm"), to: id("skill-analyze"), kind: "secondary", label: "기존 코드 영향" },
  { from: id("skill-analyze"), to: id("skill-plan"), kind: "secondary" },

  // ── 계획 → 구현 ──
  { from: id("skill-plan"), to: id("skill-devrule"), kind: "primary" },
  { from: id("skill-plan"), to: id("skill-db-design"), kind: "secondary", label: "데이터 계층 필요" },
  { from: id("skill-db-design"), to: id("agent-db-architect"), kind: "secondary" },
  { from: id("skill-db-design"), to: id("skill-devrule"), kind: "secondary", label: "DDL 확정 후" },
  { from: id("skill-plan"), to: id("skill-tdd"), kind: "secondary", label: "회귀 방지 필요" },
  { from: id("skill-plan"), to: id("skill-design"), kind: "secondary", label: "신규 UI" },
  { from: id("skill-tdd"), to: id("skill-devrule"), kind: "secondary" },

  // ── devrule 규모 분기 → 에이전트 ──
  { from: id("skill-devrule"), to: id("agent-frontend-dev"), kind: "size-S" },
  { from: id("skill-devrule"), to: id("agent-backend-dev"), kind: "size-M" },
  { from: id("skill-devrule"), to: id("agent-engine-dev"), kind: "size-M" },
  { from: id("skill-devrule"), to: id("agent-test-engineer"), kind: "size-L", label: "M/L 규모" },

  // ── design → design-dev ──
  { from: id("skill-design"), to: id("agent-design-dev"), kind: "primary" },
  { from: id("skill-polish"), to: id("agent-design-dev"), kind: "secondary" },
  { from: id("skill-design"), to: id("skill-polish"), kind: "secondary", label: "기존 UI 개선" },

  // ── design/polish → qa-frontend (실측 검수 자동 연계) ──
  { from: id("skill-design"), to: id("skill-qa-frontend"), kind: "secondary", label: "실측 검수" },
  { from: id("skill-polish"), to: id("skill-qa-frontend"), kind: "secondary", label: "실측 검수" },

  // ── devrule L → team (사용자 직접 차출) ──
  { from: id("skill-devrule"), to: id("skill-team"), kind: "size-L", label: "L 규모 직접 차출" },

  // ── 구현 → 리뷰 (Creator-Reviewer 패턴) ──
  { from: id("agent-frontend-dev"), to: id("agent-qa-reviewer"), kind: "secondary" },
  { from: id("agent-backend-dev"), to: id("agent-qa-reviewer"), kind: "secondary" },
  { from: id("agent-engine-dev"), to: id("agent-qa-reviewer"), kind: "secondary" },
  { from: id("agent-design-dev"), to: id("agent-design-reviewer"), kind: "secondary" },
  { from: id("agent-test-engineer"), to: id("agent-qa-reviewer"), kind: "secondary" },

  // ── 리뷰 통과 → verify → commit ──
  { from: id("agent-qa-reviewer"), to: id("skill-verify"), kind: "primary" },
  { from: id("agent-design-reviewer"), to: id("skill-verify"), kind: "secondary" },
  { from: id("agent-docs-keeper"), to: id("skill-verify"), kind: "secondary" },
  { from: id("skill-verify"), to: id("skill-commit"), kind: "primary" },

  // ── 부가 분기: investigate · audit · cto-review ──
  { from: id("skill-investigate"), to: id("agent-code-analyst"), kind: "secondary" },
  { from: id("skill-investigate"), to: id("agent-perf-analyst"), kind: "secondary" },
  { from: id("skill-investigate"), to: id("agent-regression-hunter"), kind: "secondary" },
  { from: id("skill-investigate"), to: id("agent-web-researcher"), kind: "secondary" },
  { from: id("skill-investigate"), to: id("agent-security-auditor"), kind: "secondary" },

  // audit → 보안 8개
  { from: id("skill-audit"), to: id("agent-auth-auditor"), kind: "secondary" },
  { from: id("skill-audit"), to: id("agent-injection-hunter"), kind: "secondary" },
  { from: id("skill-audit"), to: id("agent-crypto-auditor"), kind: "secondary" },
  { from: id("skill-audit"), to: id("agent-api-security-auditor"), kind: "secondary" },
  { from: id("skill-audit"), to: id("agent-config-auditor"), kind: "secondary" },
  { from: id("skill-audit"), to: id("agent-data-integrity-auditor"), kind: "secondary" },
  { from: id("skill-audit"), to: id("agent-supply-chain-auditor"), kind: "secondary" },
  { from: id("skill-audit"), to: id("agent-client-security-auditor"), kind: "secondary" },

  // ── cto-review → verify (정리 후 검증) ──
  { from: id("skill-cto-review"), to: id("skill-verify"), kind: "secondary", label: "정리 후 검증" },

  // ── 종결 → 다음 사이클 ──
  { from: id("skill-commit"), to: id("skill-learn"), kind: "secondary", label: "교훈 발견 시" },
  { from: id("skill-commit"), to: id("skill-aeo"), kind: "secondary", label: "배포 후 AI 가시성" },
  { from: id("skill-commit"), to: id("cmd-loop"), kind: "loop", label: "다음 태스크" },
  { from: id("cmd-loop"), to: id("skill-brainstorm"), kind: "loop", label: "랄프 루프" },

  // ── aeo → 전문 에이전트 4개 ──
  { from: id("skill-aeo"), to: id("agent-aeo-strategist"), kind: "secondary" },
  { from: id("skill-aeo"), to: id("agent-aeo-content-optimizer"), kind: "secondary" },
  { from: id("skill-aeo"), to: id("agent-aeo-infra-engineer"), kind: "secondary" },
  { from: id("skill-aeo"), to: id("agent-aeo-auditor"), kind: "secondary" },

  // ── 초기화 분기 (프로젝트 시작 1회) ──
  { from: id("cmd-init"), to: id("entry-idea-yes"), kind: "secondary" },
  { from: id("cmd-init"), to: id("entry-idea-no"), kind: "secondary" },
];
