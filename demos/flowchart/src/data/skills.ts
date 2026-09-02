import { asNodeId, type FlowNode } from "../types/graph";
import { COL, ROW } from "./grid";

export const SKILL_NODES: FlowNode[] = [
  // ── 기획·발산 ──
  {
    id: asNodeId("skill-venture"),
    category: "skill",
    label: "venture",
    full: "/wj-magic:venture",
    summary: "아이템을 만들고 즉시 실측으로 부수는 0→1 루프",
    detail:
      "발굴(DISCOVER)·설계(DESIGN)·심문(INTERROGATE)·종합(SYNTHESIZE) 4모드를 입력에서 자동 판별한다. 6필드 형식(정의·첫 고객과 채널·첫 매출까지 시간·가격·실격 필터·3년 시나리오)으로 실행 가능한 아이템을 만들고, 근거 등급([실측]/[문서]/[추정])과 판정 강제로 허약한 것을 걸러낸다. 심문이 전제를 깨면 자동으로 발굴로 되돌아가는 루프.",
    example: "/wj-magic:venture",
    triggers: ["아이데이션", "이거 될까", "뭐 만들지", "시장 검증", "전제 확인"],
    scenarios: [
      {
        user: "1인 개발자로 뭘 만들지 모르겠어",
        outcome: "→ DISCOVER: 워커 4명이 6필드 아이템 12개 발굴 → 실격 필터로 3개만 생존",
      },
      {
        user: "기획서에 '플랫폼이 이미 흡수했다'고 썼는데 맞아?",
        outcome: "→ INTERROGATE: curl 실측으로 판정 → 거짓이면 그 전제 위 후보 전부 재발굴",
      },
    ],
    outputs: [
      "docs/reports/<모드코드><번호>-<주제>.md  (§0 판정 먼저)",
      "docs/<번호>-strategy.md  (원본 대비 변경 표) + docs/_archive/ (폐기 근거)",
    ],
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
    scenarios: [
      {
        user: "팀 회고록 자동 요약 기능 만들고 싶어. 같이 정리해줘",
        outcome: "→ 한 번에 하나씩 질문 → 답변 누적 → spec 문서로 저장",
      },
      {
        user: "기능 범위가 헷갈려. 뭘 빼고 뭘 넣을지 정리하고 싶어",
        outcome: "→ MoSCoW 우선순위 도출 + must/should/could 분리",
      },
    ],
    outputs: ["docs/specs/YYYY-MM-DD-<topic>-design.md  (설계 문서)"],
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
    scenarios: [
      {
        user: "로그인 API 응답 포맷을 바꾸려는데 어디까지 영향이 가?",
        outcome: "→ Serena로 호출 그래프 추적 → 클라/서버/테스트 영향 파일 리스트",
      },
      {
        user: "이 유틸 함수 누가 쓰는지 다 찾아줘",
        outcome: "→ 참조 위치 + 직간접 의존 + 변경 시 위험도 라벨",
      },
    ],
    outputs: ["콘솔 리포트  (영향 파일 트리 · 위험도 · 권장 수정 순서)"],
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
    scenarios: [
      {
        user: "brainstorm으로 만든 설계 문서를 구현 태스크로 잘게 쪼개줘",
        outcome: "→ 파일 단위 태스크 12~20개 + 의존 그래프 + 추정 사이즈(S/M/L)",
      },
    ],
    outputs: [".dev/tasks.json  (의존관계 포함 태스크 큐)"],
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
    scenarios: [
      {
        user: "이 결제 로직은 회귀가 무서워. 테스트부터 만들고 가자",
        outcome: "→ 실패하는 테스트 작성 → 실행 → 통과시키는 최소 코드",
      },
      {
        user: "버그 재현 케이스를 테스트로 박아두고 고쳐줘",
        outcome: "→ Red 테스트 추가 → 수정 → Green 확인 → 리팩토링",
      },
    ],
    outputs: ["__tests__/  하위 신규 spec  (실패→통과 커밋 분리)"],
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
    scenarios: [
      {
        user: "헤더에 다크모드 토글 추가해줘",
        outcome: "→ S 판정 → Claude 직접 구현 + qa-reviewer 자동 리뷰",
      },
      {
        user: "결제 모듈 전체를 결제대행사 기준으로 재설계해줘",
        outcome: "→ L 판정 → backend-dev + engine-dev + test-engineer 병렬",
      },
    ],
    outputs: ["변경 파일들 + qa-reviewer 리뷰 코멘트"],
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
    scenarios: [
      {
        user: "Stripe 같은 톤으로 랜딩 페이지 만들어줘",
        outcome: "→ 무드보드 3안 제시 → 선택 → 토큰·컴포넌트·페이지 구현",
      },
      {
        user: "신규 어드민 대시보드 첫 화면 디자인해줘",
        outcome: "→ 정보 위계 도출 → 컴포넌트 트리 → 시안 + 코드 동시 산출",
      },
    ],
    outputs: ["DESIGN.md (토큰·원칙) + 신규 컴포넌트 + 페이지"],
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
    scenarios: [
      {
        user: "이 페이지 너무 AI 같아. 사람 손맛 좀 넣어줘",
        outcome: "→ 진단 카드(밋밋한 그리드·기본 컬러 등) → 처방 → 재구현",
      },
      {
        user: "여백이랑 위계만 정리해줘",
        outcome: "→ design-reviewer 진단 → 토큰 단위 수정 → qa-frontend 실측",
      },
    ],
    outputs: ["변경된 컴포넌트 + design-reviewer 리포트 + qa-frontend 점수"],
    position: { x: COL.c3, y: ROW.belowB },
  },
  {
    id: asNodeId("skill-qa-frontend"),
    category: "skill",
    label: "qa-frontend",
    full: "/wj-magic:qa-frontend",
    summary: "Playwright 4 viewport + Lighthouse 실측 QA 게이트",
    detail:
      "Playwright 4 viewport(375/768/1024/1440) 풀페이지 캡처 + Chrome DevTools MCP Mobile Lighthouse 4종 + LCP/CLS/TTFB/INP 측정. 토큰 darken·메타·aria 한정 자동 수정 최대 3회 루프.",
    example: "/wj-magic:qa-frontend",
    triggers: ["실측 QA", "Lighthouse", "color-contrast 측정"],
    scenarios: [
      {
        user: "방금 다듬은 페이지 모바일에서도 깨끗한지 봐줘",
        outcome: "→ 4 viewport 캡처 + Lighthouse 4종 측정 + 결함 CRIT/HIGH/MED/LOW 정렬",
      },
      {
        user: "color-contrast 위반이랑 LCP 같이 잡아줘",
        outcome: "→ 토큰 darken + 이미지 사이즈 attr + aria 보정 → 재측정 PASS까지",
      },
    ],
    outputs: [
      "QA 리포트  (점수·결함·자동 수정 diff)",
      "captures/qa-frontend/<viewport>.png",
    ],
    position: { x: COL.c3, y: ROW.belowB + 80 },
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
    scenarios: [
      {
        user: "어제부터 결제 페이지가 1초씩 느려졌어. 원인 찾아줘",
        outcome: "→ perf-analyst·regression-hunter 병렬 → 도입 커밋 + 핵심 병목 보고",
      },
      {
        user: "이 에러 스택만 보면 뭔지 모르겠어. 다 같이 봐줘",
        outcome: "→ code-analyst SBFL 의심도 + web-researcher 유사 이슈 매핑",
      },
    ],
    outputs: ["조사 리포트  (원인 5순위 + 수정 PR diff)"],
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
    example: "/wj-magic:team frontend-dev,backend-dev,test-engineer",
    triggers: ["팀 구성", "에이전트 소환"],
    scenarios: [
      {
        user: "이 기능은 풀스택이라 프엔/백엔/테스트 셋 다 같이 가줘",
        outcome: "→ 3 에이전트 worktree 격리 병렬 → 통합 PR 생성",
      },
    ],
    outputs: ["에이전트별 worktree + 통합 diff"],
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
    scenarios: [
      {
        user: "기술 부채 한 번 크게 털고 가고 싶어",
        outcome: "→ 도메인별 분석 4명 → Wave 1: 토큰화 → Wave 2: 분할 → Wave 3: 테스트",
      },
    ],
    outputs: ["Wave별 커밋 시리즈 + 리팩토링 리포트"],
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
    scenarios: [
      {
        user: "출시 전에 OWASP 기준으로 한 번 싹 훑어봐",
        outcome: "→ 1차 8명 병렬 → 2차 검증 3명 크로스 → CRIT/HIGH 자동 수정 PR",
      },
      {
        user: "결제 API만 집중 점검해줘",
        outcome: "→ injection-hunter·api-security-auditor·auth-auditor 집중 투입",
      },
    ],
    outputs: ["docs/audit/<date>-report.md", ".dev/tasks.json (loop 호환)"],
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
    scenarios: [
      {
        user: "다 됐다고 했는데 진짜인지 한 번만 더 확인하고 커밋해줘",
        outcome: "→ build + test 실제 실행 → 통과 로그 첨부 → 커밋 진행",
      },
    ],
    outputs: ["콘솔: 빌드/테스트 실행 결과 (통과 시 ✓ + 시간)"],
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
    scenarios: [
      {
        user: "지금 변경분 커밋해줘",
        outcome: "→ diff 분석 → 타입 자동 분류 → 본문 2~3문장 → git commit",
      },
      {
        user: "두 묶음으로 나눠서 커밋해줘",
        outcome: "→ 변경을 논리 그룹 분리 → 각 그룹별 메시지 생성 → 순차 커밋",
      },
    ],
    outputs: ["git: 분류된 한글 커밋"],
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
    scenarios: [
      {
        user: "이번에 발견한 안티패턴 다음에도 안 틀리게 규칙으로 박아둬",
        outcome: "→ LESSONS.md에 정형화된 항목 추가 → devrule 자동 적용",
      },
    ],
    outputs: ["docs/LESSONS.md  (불변 교훈 누적)"],
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
    scenarios: [
      {
        user: "이 useEffect 뭐 하는 거야?",
        outcome: "→ 한 줄 요약 → 식당 비유 → 왜 필요한지 → 다음 단계",
      },
      {
        user: "왜 여기서 비동기로 처리한 거야?",
        outcome: "→ 동기/비동기 차이 비유 → 이 코드에서의 트레이드오프",
      },
    ],
    position: { x: COL.c2, y: 80 },
  },
  // ── 데이터 계층 ──
  {
    id: asNodeId("skill-db-design"),
    category: "skill",
    label: "db-design",
    full: "/wj-magic:db-design",
    summary: "워크로드별 최적 DB 매칭 → 스키마·인덱스·샤딩 설계",
    detail:
      "특정 스택에 락인하지 않고 워크로드를 분석해 10종 DB 유형(관계형·문서·키값·와이드컬럼·그래프·시계열·검색·벡터·인메모리·DW)을 트레이드오프로 매칭한다. NEW(신규 설계) / DIAGNOSE(기존 진단) 2-mode. Wave 전략으로 DDL·ORM 스키마·migration 코드까지 생성.",
    example: "/wj-magic:db-design",
    triggers: ["DB 설계", "어떤 DB 써야", "인덱스 최적화", "샤딩", "ERD"],
    scenarios: [
      {
        user: "실시간 채팅 + 검색 + 통계가 다 필요한데 DB 뭘 써야 해?",
        outcome: "→ 워크로드 3분할 → 폴리글랏 조합 제안 + 각각 트레이드오프 명시",
      },
      {
        user: "쿼리가 갈수록 느려지는데 스키마 문제일까?",
        outcome: "→ DIAGNOSE 모드: 인덱스·정규화·N+1 진단 → 무중단 마이그레이션 계획",
      },
    ],
    outputs: ["ERD + DDL + 인덱스 전략 + 무중단 마이그레이션 계획"],
    position: { x: COL.c2, y: ROW.belowA },
  },
  // ── 배포 후 최적화 ──
  {
    id: asNodeId("skill-aeo"),
    category: "skill",
    label: "aeo",
    full: "/wj-magic:aeo",
    summary: "AI 답변 인용 + 에이전트 실행 가능성 2축 최적화",
    detail:
      "AEO(우리 콘텐츠가 AI 답변에 인용되는가)와 Agent-Readiness(자율 에이전트가 우리 사이트에서 행동하는가)를 분리해 다룬다. 서비스 프로파일 5종별 가중 점수로 무관한 표준은 N/A 처리. 5레이어(ACCESS·RENDER·REPRESENT·MEANING·ACT) 34체크 실측 후 ROI 처방(NOW/NEXT/LATER)과 로컬 8-bit 대시보드를 낸다.",
    example: "/wj-magic:aeo",
    triggers: ["AEO", "AI 검색 최적화", "ChatGPT에 인용", "llms.txt", "agent ready"],
    scenarios: [
      {
        user: "우리 서비스가 AI 검색에 하나도 안 걸려",
        outcome: "→ 실측 스캔: robots.txt AI 규칙·SSR 렌더링 갭 진단 → NOW 처방부터 구현",
      },
      {
        user: "llms.txt 붙이면 인용이 늘어?",
        outcome: "→ 효과 근거가 약한 항목은 confidence 낮게 표기 → 우선순위 뒤로 정렬",
      },
    ],
    outputs: ["docs/reports/aeo-dashboard.html  (2축 점수 + 34체크 도감 + 추세)"],
    position: { x: COL.c7, y: ROW.belowA },
  },
];
