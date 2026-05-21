import { asNodeId, type FlowNode } from "../types/graph";
import { COL, ROW } from "./grid";

/**
 * 21명 에이전트 — 구현(5) 리뷰(4) 분석(4) 보안 감사(8).
 *
 * 좌표 정책 (격자 정렬):
 * - 구현 5: col c4 세로 배치 (devrule 우측)
 * - 리뷰 4: col c5 세로 배치
 * - 분석 4: col c7 세로 배치 (investigate 우측)
 * - 보안 감사 8: col c8 세로 배치 (audit 우측)
 */
export const AGENT_NODES: FlowNode[] = [
  // 구현 (5) — col c4
  agent("frontend-dev", "프론트엔드", "UI 컴포넌트·스토어·애니메이션·레이아웃", "implement", COL.c4, ROW.upper + 40, "agent-fe"),
  agent("backend-dev", "백엔드", "REST API·WebSocket·DB·세션·서버 로직", "implement", COL.c4, ROW.mainA, "agent-be"),
  agent("engine-dev", "엔진", "도메인 규칙·타입·순수 함수·엔진 단위 테스트", "implement", COL.c4, ROW.main, "agent-en"),
  agent("test-engineer", "테스트 설계", "M/L 규모 후 독립적 테스트 보강", "implement", COL.c4, ROW.mainB, "agent-te"),
  agent("design-dev", "디자인 구현", "DESIGN.md + 레퍼런스 기반 시각 + CSS", "implement", COL.c4, ROW.belowB - 20, "agent-dd"),

  // 리뷰 (4) — col c5
  agent("qa-reviewer", "QA 리뷰어", "Creator-Reviewer 패턴 코드 리뷰 + 회귀 체크", "review", COL.c5, ROW.mainA, "agent-qa"),
  agent("docs-keeper", "문서 동기화", "코드 구조 변경 시 docs/LESSONS 최신화", "review", COL.c5, ROW.main, "agent-doc"),
  agent("regression-hunter", "회귀 헌터", "git bisect + blame 으로 버그 도입 커밋 특정", "review", COL.c5, ROW.mainB, "agent-rg"),
  agent("design-reviewer", "디자인 리뷰어", "DESIGN_QUALITY_STANDARDS 기준 시각 검증", "review", COL.c5, ROW.belowB - 20, "agent-dr"),

  // 분석 (4) — col c7
  agent("code-analyst", "코드 분석", "Serena 심볼 + SBFL 의심도 분석", "analyze", COL.c7, ROW.invA - 40, "agent-ca"),
  agent("perf-analyst", "성능 분석", "안티패턴 탐지 + Chrome DevTools 측정", "analyze", COL.c7, ROW.invA + 20, "agent-pa"),
  agent("web-researcher", "웹 리서치", "Context7 + WebSearch로 CVE·이슈 수집", "analyze", COL.c7, ROW.invA + 80, "agent-wr"),
  agent("security-auditor", "일반 보안", "구현 직후 OWASP 1차 보안 검토", "analyze", COL.c7, ROW.invA + 140, "agent-sa"),

  // 보안 감사 (8) — col c8 세로 배치 (audit 우측), 간격 35 / 시작 ROW.invA(780)
  agent("auth-auditor", "인증·인가", "JWT·OAuth·세션·RBAC 도메인 심층 감사", "audit", COL.c8, ROW.invA, "agent-au"),
  agent("injection-hunter", "Injection", "SQL/NoSQL/Command/Template/XSS", "audit", COL.c8, ROW.invA + 35, "agent-in"),
  agent("crypto-auditor", "암호·시크릿", "암호 라이브러리·시크릿·TLS·키 관리", "audit", COL.c8, ROW.invA + 70, "agent-cr"),
  agent("api-security-auditor", "API 보안", "SSRF·BOLA·Mass Assignment·CORS", "audit", COL.c8, ROW.invA + 105, "agent-api"),
  agent("config-auditor", "설정·인프라", "debug·보안 헤더·디폴트 크레덴셜", "audit", COL.c8, ROW.invA + 140, "agent-cf"),
  agent("data-integrity-auditor", "데이터·로깅", "결제 검증·역직렬화·감사 추적·로깅", "audit", COL.c8, ROW.invA + 175, "agent-di"),
  agent("supply-chain-auditor", "공급망", "CVE·악성 패키지·lock·CI 빌드 체인", "audit", COL.c8, ROW.invA + 210, "agent-sc"),
  agent("client-security-auditor", "클라이언트", "DOM XSS·Prototype Pollution·postMessage", "audit", COL.c8, ROW.invA + 245, "agent-cs"),
];

function agent(
  id: string,
  label: string,
  summary: string,
  role: "implement" | "review" | "analyze" | "audit",
  x: number,
  y: number,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  _short: string,
): FlowNode {
  return {
    id: asNodeId(`agent-${id}`),
    category: "agent",
    label,
    full: id,
    summary,
    detail: summary,
    agentRole: role,
    position: { x, y },
  };
}
