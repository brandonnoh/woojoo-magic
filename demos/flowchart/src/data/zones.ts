/**
 * 시각적 영역 그룹 — 노드들을 의미 단위로 묶어 점선 박스 + 코너 브래킷으로 표시.
 * 사용자가 직접 호출하지 않는 "자동 차출" 또는 "이벤트 자동 트리거" 영역을 강조.
 */
export interface Zone {
  id: string;
  x: number;
  y: number;
  w: number;
  h: number;
  /** 좌상단 트랙 라벨 */
  label: string;
  /** 라벨 뒤에 디밍된 톤으로 표시되는 부제 */
  sub?: string;
  /** 좌하단 큐(메타) — 예: "9 AGENTS", "7 HOOKS" */
  tag?: string;
}

export const ZONES: Zone[] = [
  {
    id: "zone-meta",
    x: 20,
    y: 40,
    w: 700,
    h: 90,
    label: "META · DIRECT CALL",
    sub: "워크플로 외부 진입 — 어디서든 직접 호출 가능",
    tag: "3 NODES",
  },
  {
    id: "zone-agents-impl",
    x: 900,
    y: 240,
    w: 414,
    h: 520,
    label: "AGENT BENCH · IMPL / REVIEW",
    sub: "필요 시 자동 차출 — devrule · design · polish 가 호출",
    tag: "9 AGENTS",
  },
  {
    id: "zone-agents-analyze",
    x: 1410,
    y: 720,
    w: 888,
    h: 130,
    label: "AGENT BENCH · ANALYZE",
    sub: "investigate 가동 시 4명 병렬",
    tag: "4 AGENTS",
  },
  {
    id: "zone-agents-audit",
    x: 1410,
    y: 960,
    w: 1690,
    h: 120,
    label: "AGENT BENCH · AUDIT",
    sub: "audit 가동 시 OWASP 8벡터 병렬",
    tag: "8 AGENTS",
  },
  {
    id: "zone-agents-aeo",
    x: 2350,
    y: 720,
    w: 888,
    h: 130,
    label: "AGENT BENCH · AEO",
    sub: "aeo 가동 시 전략·콘텐츠·인프라·실측 4명 병렬",
    tag: "4 AGENTS",
  },
  {
    id: "zone-hooks",
    x: 140,
    y: 1180,
    w: 1380,
    h: 90,
    label: "SYSTEM AUTO · HOOKS",
    sub: "Claude Code 이벤트에 자동 트리거 — 사용자 호출 없음",
    tag: "7 HOOKS",
  },
];
