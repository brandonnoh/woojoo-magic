import { asNodeId, type FlowNode, type NodeScenario } from "../types/graph";
import { COL, ROW } from "./grid";

/**
 * 21명 에이전트 — 구현(5) 리뷰(4) 분석(4) 보안 감사(8).
 *
 * 좌표 정책 (격자 정렬, 노드 간 ≥80px 간격으로 겹침 방지):
 * - 구현 5: col c4 세로 배치 (devrule 우측)
 * - 리뷰 4: col c5 세로 배치
 * - 분석 4: col c7 세로 배치, 간격 80 (investigate 우측)
 * - 보안 감사 8: c8 4명 + c9 4명 2열 배치, 간격 80 (audit 우측)
 */

interface AgentSpec {
  id: string;
  label: string;
  summary: string;
  detail?: string;
  role: "implement" | "review" | "analyze" | "audit";
  x: number;
  y: number;
  scenario: NodeScenario;
}

const SPECS: AgentSpec[] = [
  // 구현 (5) — col c4
  {
    id: "frontend-dev",
    label: "프론트엔드",
    summary: "UI 컴포넌트·스토어·애니메이션·레이아웃",
    detail:
      "React/Vue/Svelte 컴포넌트, 전역 상태, 인터랙션·애니메이션, 반응형 레이아웃을 담당한다. design-dev와 협업해 시각 → 동작 변환을 책임진다.",
    role: "implement",
    x: COL.c4,
    y: ROW.upper + 40,
    scenario: {
      user: "이 컴포넌트 props 정리해서 리팩토링해줘",
      outcome: "→ 타입 추출 + 분할 + Storybook 시나리오 보강",
    },
  },
  {
    id: "backend-dev",
    label: "백엔드",
    summary: "REST API·WebSocket·DB·세션·서버 로직",
    detail:
      "라우터/컨트롤러, ORM·쿼리, 트랜잭션 경계, 인증·세션, 큐/배치 처리를 담당한다. injection-hunter·auth-auditor와 자동 연계된다.",
    role: "implement",
    x: COL.c4,
    y: ROW.mainA,
    scenario: {
      user: "이 엔드포인트에 페이지네이션 붙여줘",
      outcome: "→ cursor/offset 선택 → 쿼리·DTO·테스트 동시 추가",
    },
  },
  {
    id: "engine-dev",
    label: "엔진",
    summary: "도메인 규칙·타입·순수 함수·엔진 단위 테스트",
    detail:
      "프레임워크 비의존 핵심 로직. 결제 계산, 게임 룰, 상태기계 등 \"바뀌면 안 되는 진짜 로직\"을 순수 함수로 깎고 단위 테스트로 잠근다.",
    role: "implement",
    x: COL.c4,
    y: ROW.main,
    scenario: {
      user: "할인 정책 룰을 명세대로 다시 짜줘",
      outcome: "→ 표 → 결정 트리 → 순수 함수 + table-driven test",
    },
  },
  {
    id: "test-engineer",
    label: "테스트 설계",
    summary: "M/L 규모 후 독립적 테스트 보강",
    detail:
      "구현 에이전트가 누락하기 쉬운 경계 케이스를 독립 시각으로 보강. 시나리오 매트릭스, mutation testing, contract test를 우선 적용한다.",
    role: "implement",
    x: COL.c4,
    y: ROW.mainB,
    scenario: {
      user: "방금 구현한 모듈에 테스트 커버리지 보강해줘",
      outcome: "→ happy path + 경계 + 실패 경로 + 회귀 fixture 추가",
    },
  },
  {
    id: "design-dev",
    label: "디자인 구현",
    summary: "DESIGN.md + 레퍼런스 기반 시각 + CSS",
    detail:
      "디자인 토큰·컴포넌트 시스템·CSS-in-JS 구현 담당. design-reviewer와 한 쌍으로 \"구현 ↔ 검수\" 루프를 돈다.",
    role: "implement",
    x: COL.c4,
    y: ROW.belowB - 20,
    scenario: {
      user: "이 시안대로 토큰 시스템부터 잡고 구현해줘",
      outcome: "→ tokens.css 정의 → primitive 컴포넌트 → 화면 조립",
    },
  },

  // 리뷰 (4) — col c5
  {
    id: "qa-reviewer",
    label: "QA 리뷰어",
    summary: "Creator-Reviewer 패턴 코드 리뷰 + 회귀 체크",
    detail:
      "구현 에이전트의 산출물을 독립 시각으로 리뷰. 회귀 위험·테스트 누락·관습 위반을 코멘트한다. devrule M/L 산출 직후 자동 투입.",
    role: "review",
    x: COL.c5,
    y: ROW.mainA,
    scenario: {
      user: "방금 PR 한 번 검토해줘",
      outcome: "→ blocker / nit 분리 + 회귀 후보 케이스 코멘트",
    },
  },
  {
    id: "docs-keeper",
    label: "문서 동기화",
    summary: "코드 구조 변경 시 docs/LESSONS 최신화",
    detail:
      "구조 변경·신규 모듈·삭제된 컴포넌트를 감지해 docs/ARCHITECTURE·README·LESSONS를 자동 갱신한다.",
    role: "review",
    x: COL.c5,
    y: ROW.main,
    scenario: {
      user: "방금 큰 리팩토링 했는데 문서도 맞춰줘",
      outcome: "→ ARCHITECTURE 다이어그램 + 모듈 표 + 마이그레이션 노트",
    },
  },
  {
    id: "regression-hunter",
    label: "회귀 헌터",
    summary: "git bisect + blame 으로 버그 도입 커밋 특정",
    detail:
      "재현 가능한 버그가 있을 때 git bisect 자동 진행 + blame 교차 분석으로 \"이 커밋이 범인\" 까지 좁힌다.",
    role: "review",
    x: COL.c5,
    y: ROW.mainB,
    scenario: {
      user: "이 버그 언제부터 생긴 거야?",
      outcome: "→ bisect 6단계 → 범인 커밋 + diff 하이라이트",
    },
  },
  {
    id: "design-reviewer",
    label: "디자인 리뷰어",
    summary: "DESIGN_QUALITY_STANDARDS 기준 시각 검증",
    detail:
      "정성 리뷰 — 토큰 사용률·위계·여백 리듬·Anti-Slop 위반을 grep + 시각 검토로 진단. PASS/WARN 시 qa-frontend 실측 자동 연계.",
    role: "review",
    x: COL.c5,
    y: ROW.belowB - 20,
    scenario: {
      user: "이 페이지 디자인 검수해줘",
      outcome: "→ 토큰 사용률·위계·리듬 점수 + Anti-Slop 진단 카드",
    },
  },

  // 분석 (4) — 가로 4개 배치, y=780 (investigate와 같은 라인, 우측으로 직선 연결)
  {
    id: "code-analyst",
    label: "코드 분석",
    summary: "Serena 심볼 + SBFL 의심도 분석",
    detail:
      "심볼 추적 + Spectrum-Based Fault Localization 의심도 계산으로 \"이 줄이 범인일 확률\"을 점수화. investigate 첫 번째 단계로 자동 투입.",
    role: "analyze",
    x: 1500,
    y: 780,
    scenario: {
      user: "이 에러의 진짜 원인 라인 좁혀줘",
      outcome: "→ SBFL Top 5 라인 + 직접 호출 그래프",
    },
  },
  {
    id: "perf-analyst",
    label: "성능 분석",
    summary: "안티패턴 탐지 + Chrome DevTools 측정",
    detail:
      "코드 정적 분석 + 실측(LCP·CLS·INP·메모리)을 함께. 병목을 우선순위와 함께 보고하고 자동 수정 후보를 제시.",
    role: "analyze",
    x: 1700,
    y: 780,
    scenario: {
      user: "왜 이 페이지 LCP가 4초나 나와?",
      outcome: "→ Lighthouse trace 분석 + 차단 리소스 Top 3",
    },
  },
  {
    id: "web-researcher",
    label: "웹 리서치",
    summary: "Context7 + WebSearch로 CVE·이슈 수집",
    detail:
      "최신 라이브러리 문서, GitHub 유사 이슈, StackOverflow, NVD CVE를 병렬 수집해 \"남들도 같은 문제 겪었는지\"를 구조화 리포트로.",
    role: "analyze",
    x: 1900,
    y: 780,
    scenario: {
      user: "이 패키지 비슷한 버그 보고된 적 있어?",
      outcome: "→ GitHub Issue + CVE + 핵심 해결책 인용 리포트",
    },
  },
  {
    id: "security-auditor",
    label: "일반 보안",
    summary: "구현 직후 OWASP 1차 보안 검토",
    detail:
      "audit 스킬 1차 패스 진입 전 가벼운 자동 점검. 인증·인가·입력 검증·시크릿 위주 빠른 스캔.",
    role: "analyze",
    x: 2100,
    y: 780,
    scenario: {
      user: "방금 구현한 부분만 보안 봐줘",
      outcome: "→ OWASP A01~A05 기준 빠른 진단 + HIGH 항목 표시",
    },
  },

  // 보안 감사 (8) — 가로 1줄, y=1020 간격 200 (audit → 자식 동선 깔끔)
  {
    id: "auth-auditor",
    label: "인증·인가",
    summary: "JWT·OAuth·세션·RBAC 도메인 심층 감사",
    detail:
      "토큰 발급/검증 흐름, 만료/재발급, 권한 매트릭스(RBAC/ABAC), 세션 고정/탈취 벡터를 점검.",
    role: "audit",
    x: 1500,
    y: 1020,
    scenario: {
      user: "JWT 검증 로직 한 번 봐줘",
      outcome: "→ alg 혼동·만료 누락·iss/aud 검증 결손 등 표시",
    },
  },
  {
    id: "injection-hunter",
    label: "Injection",
    summary: "SQL/NoSQL/Command/Template/XSS",
    detail:
      "Source → Sink 추적으로 모든 Injection 벡터를 검출. 파라미터 바인딩, 이스케이프, 안전한 직렬화 권장.",
    role: "audit",
    x: 1700,
    y: 1020,
    scenario: {
      user: "이 검색 쿼리 안전해?",
      outcome: "→ 사용자 입력 → 쿼리 경로 추적 → 바인딩 누락 라인 표시",
    },
  },
  {
    id: "crypto-auditor",
    label: "암호·시크릿",
    summary: "암호 라이브러리·시크릿·TLS·키 관리",
    detail:
      "암호 알고리즘 약점, IV/Nonce 재사용, TLS 옵션, 시크릿 하드코딩, 키 회전 부재 등을 검출.",
    role: "audit",
    x: 1900,
    y: 1020,
    scenario: {
      user: "환경변수에 시크릿 어떻게 다루는지 봐줘",
      outcome: "→ 하드코딩·로그 노출·약한 알고리즘 사용 표시",
    },
  },
  {
    id: "api-security-auditor",
    label: "API 보안",
    summary: "SSRF·BOLA·Mass Assignment·CORS",
    detail:
      "외부 요청 URL 검증, 객체 권한 분리, 자동 바인딩 위험, CORS preflight 설정, WebSocket 오리진 검증.",
    role: "audit",
    x: 2100,
    y: 1020,
    scenario: {
      user: "이 webhook URL 입력 받는 부분 SSRF 위험 있어?",
      outcome: "→ 로컬·메타데이터 IP 차단 미적용 라인 표시",
    },
  },
  {
    id: "config-auditor",
    label: "설정·인프라",
    summary: "debug·보안 헤더·디폴트 크레덴셜",
    detail:
      "프로덕션 debug 활성화, CSP·HSTS·X-Frame-Options 누락, 기본 비밀번호, 노출된 관리자 경로 점검.",
    role: "audit",
    x: 2300,
    y: 1020,
    scenario: {
      user: "배포 설정 보안 점검",
      outcome: "→ debug=True 잔존·CSP 누락·기본 시크릿 표시",
    },
  },
  {
    id: "data-integrity-auditor",
    label: "데이터·로깅",
    summary: "결제 검증·역직렬화·감사 추적·로깅",
    detail:
      "결제 금액 서버 재검증, 역직렬화 RCE 위험, 민감정보 로깅, 감사 로그 누락을 점검.",
    role: "audit",
    x: 2500,
    y: 1020,
    scenario: {
      user: "결제 금액을 클라이언트가 보내는 구조인데 안전한가?",
      outcome: "→ 서버 재검증 누락 + 무결성 토큰 부재 표시",
    },
  },
  {
    id: "supply-chain-auditor",
    label: "공급망",
    summary: "CVE·악성 패키지·lock·CI 빌드 체인",
    detail:
      "package-lock 무결성, 알려진 CVE, 타이포스쿼팅·hijacked 패키지, CI 시크릿 노출 점검.",
    role: "audit",
    x: 2700,
    y: 1020,
    scenario: {
      user: "의존성에 알려진 취약점 있나?",
      outcome: "→ NVD 매칭 + lock drift + suspicious 패키지 리스트",
    },
  },
  {
    id: "client-security-auditor",
    label: "클라이언트",
    summary: "DOM XSS·Prototype Pollution·postMessage",
    detail:
      "프론트엔드 코드의 sink 추적, Object.assign 오용, window.postMessage origin 검증 누락 등 클라이언트 측 취약점.",
    role: "audit",
    x: 2900,
    y: 1020,
    scenario: {
      user: "이 페이지 URL 파라미터 안전하게 처리되고 있어?",
      outcome: "→ innerHTML/dangerouslySetInnerHTML 경로 추적 결과",
    },
  },
];

export const AGENT_NODES: FlowNode[] = SPECS.map(toNode);

function toNode(s: AgentSpec): FlowNode {
  return {
    id: asNodeId(`agent-${s.id}`),
    category: "agent",
    label: s.label,
    full: s.id,
    summary: s.summary,
    detail: s.detail ?? s.summary,
    agentRole: s.role,
    scenarios: [s.scenario],
    position: { x: s.x, y: s.y },
  };
}
