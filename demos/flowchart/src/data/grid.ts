/**
 * DBH 플로우차트 격자 시스템 — 직각 꺾임 라인이 깔끔하게 그려지도록
 * 모든 노드 좌표를 미리 정의된 컬럼·로우에 정렬한다.
 *
 * viewBox: 1840 x 1100
 */

export const COL = {
  c0: 120, // 진입점
  c1: 320, // brainstorm / ideation
  c2: 520, // analyze / plan
  c3: 720, // devrule / design / tdd / polish
  c4: 920, // 구현 에이전트
  c5: 1120, // 리뷰 에이전트 / team / cto-review
  c6: 1320, // verify / investigate / audit
  c7: 1520, // commit / 분석 에이전트
  c8: 1720, // loop / learn / 보안 감사 (1열)
  c9: 1920, // 보안 감사 (2열)
} as const;

export const ROW = {
  top: 160, // init
  upper: 240, // analyze, tdd
  mainA: 360, // brainstorm, frontend-dev, qa-reviewer
  main: 440, // plan, devrule, verify, commit
  mainB: 520, // engine-dev, regression-hunter
  belowA: 600, // design
  belowB: 680, // polish, design-dev
  invA: 780, // investigate
  invB: 860, // audit / team
  invC: 940, // cto-review
  bottom: 1020, // 훅 띠 + 좌하단 메타
} as const;

export const NODE_W = 168;
export const NODE_H = 44;
