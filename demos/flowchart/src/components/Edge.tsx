import type { FlowEdge, FlowNode } from "../types/graph";

/**
 * DBH 직각 꺾임 라인 — 곡선 X, L-shape 또는 ㄹ-shape.
 * - 활성: 진한 블루 `#2E5DDA`
 * - 비활성: 옅은 그레이 `#C8CDD4`
 * - 글로우/애니메이션 X (단, 호버 시 두께만 살짝)
 */
interface EdgeProps {
  edge: FlowEdge;
  from: FlowNode;
  to: FlowNode;
  highlighted: boolean;
  active: boolean;
  /** 선택 노드 기준 흐름 방향 — null이면 흐름 dot 표시 안 함 */
  flow: "incoming" | "outgoing" | null;
}

const NODE_HW = 84; // NODE_W/2
const NODE_HH = 22; // NODE_H/2

export function Edge({ from, to, highlighted, active, flow }: EdgeProps) {
  const isFlowing = flow !== null && active;
  const stroke = active
    ? isFlowing
      ? flow === "outgoing"
        ? "var(--color-line-bright)"
        : "var(--color-ink)"
      : highlighted
        ? "var(--color-navy)"
        : "var(--color-line)"
    : "var(--color-rule)";
  const sw = isFlowing ? 2.4 : highlighted ? 2.5 : active ? 1.6 : 1.2;
  const opacity = active ? 1 : 0.7;

  const geom = buildGeometry(from, to);
  const dotColor =
    flow === "outgoing" ? "var(--color-line-bright)" : "var(--color-ink)";

  return (
    <g>
      <path
        d={geom.path}
        fill="none"
        stroke={stroke}
        strokeWidth={sw}
        strokeOpacity={opacity}
        strokeLinejoin="miter"
        strokeLinecap="butt"
        style={{ transition: "stroke 200ms ease-out, stroke-width 200ms ease-out, stroke-opacity 200ms ease-out" }}
      />
      {active && (
        <polygon points={arrow(geom)} fill={stroke} opacity={opacity} />
      )}

      {/* 흐름 dot 2개 — incoming/outgoing 시각화 */}
      {isFlowing && (
        <>
          <circle r={5} fill={dotColor} opacity={0}>
            <animate attributeName="opacity" values="0;1;1;0" keyTimes="0;0.1;0.85;1" dur="1.4s" repeatCount="indefinite" />
            <animateMotion dur="1.4s" repeatCount="indefinite" path={geom.path} />
          </circle>
          <circle r={4} fill={dotColor} opacity={0}>
            <animate attributeName="opacity" begin="0.5s" values="0;0.85;0.85;0" keyTimes="0;0.1;0.85;1" dur="1.4s" repeatCount="indefinite" />
            <animateMotion begin="0.5s" dur="1.4s" repeatCount="indefinite" path={geom.path} />
          </circle>
        </>
      )}
    </g>
  );
}

interface Geometry {
  /** SVG path 문자열 */
  path: string;
  /** 마지막 꺾임 직전의 진행 방향: "right" | "down" | "up" | "left" */
  dir: "right" | "down" | "up" | "left";
  /** 화살표 꼭짓점 좌표 */
  x: number;
  y: number;
}

const TREE_THRESHOLD = 60; // |Δy| 가 이보다 크면 위/아래 트리 분기로

function buildGeometry(from: FlowNode, to: FlowNode): Geometry {
  const dx = to.position.x - from.position.x;
  const dy = to.position.y - from.position.y;
  const sameCol = Math.abs(dx) < 1;
  const sameRow = Math.abs(dy) < 1;

  // 같은 컬럼 — 위→아래 또는 아래→위 직선
  if (sameCol) {
    const x = from.position.x;
    if (dy > 0) {
      const y1 = from.position.y + NODE_HH;
      const y2 = to.position.y - NODE_HH;
      return { path: `M ${x} ${y1} L ${x} ${y2}`, dir: "down", x, y: y2 };
    }
    const y1 = from.position.y - NODE_HH;
    const y2 = to.position.y + NODE_HH;
    return { path: `M ${x} ${y1} L ${x} ${y2}`, dir: "up", x, y: y2 };
  }

  // 같은 행 — 좌→우 또는 우→좌 직선
  if (sameRow) {
    const y = from.position.y;
    if (dx > 0) {
      const x1 = from.position.x + NODE_HW;
      const x2 = to.position.x - NODE_HW;
      return { path: `M ${x1} ${y} L ${x2} ${y}`, dir: "right", x: x2, y };
    }
    const x1 = from.position.x - NODE_HW;
    const x2 = to.position.x + NODE_HW;
    return { path: `M ${x1} ${y} L ${x2} ${y}`, dir: "left", x: x2, y };
  }

  // |Δy| 가 충분히 크면 — 노드 위/아래에서 출발하는 트리 분기 (audit → 자식 8명 같은 케이스)
  if (Math.abs(dy) > TREE_THRESHOLD) {
    if (dy > 0) {
      const x1 = from.position.x;
      const y1 = from.position.y + NODE_HH;
      const x2 = to.position.x;
      const y2 = to.position.y - NODE_HH;
      const midY = y1 + (y2 - y1) * 0.5;
      const path = `M ${x1} ${y1} L ${x1} ${midY} L ${x2} ${midY} L ${x2} ${y2}`;
      return { path, dir: "down", x: x2, y: y2 };
    }
    const x1 = from.position.x;
    const y1 = from.position.y - NODE_HH;
    const x2 = to.position.x;
    const y2 = to.position.y + NODE_HH;
    const midY = y1 + (y2 - y1) * 0.5;
    const path = `M ${x1} ${y1} L ${x1} ${midY} L ${x2} ${midY} L ${x2} ${y2}`;
    return { path, dir: "up", x: x2, y: y2 };
  }

  // 가로 L-shape — 같은 행 근사 (|Δy| <= TREE_THRESHOLD)
  if (dx > 0) {
    const x1 = from.position.x + NODE_HW;
    const x2 = to.position.x - NODE_HW;
    const midX = x1 + (x2 - x1) / 2;
    const path = `M ${x1} ${from.position.y} L ${midX} ${from.position.y} L ${midX} ${to.position.y} L ${x2} ${to.position.y}`;
    return { path, dir: "right", x: x2, y: to.position.y };
  }
  const x1 = from.position.x - NODE_HW;
  const x2 = to.position.x + NODE_HW;
  const midX = x1 - (x1 - x2) / 2;
  const path = `M ${x1} ${from.position.y} L ${midX} ${from.position.y} L ${midX} ${to.position.y} L ${x2} ${to.position.y}`;
  return { path, dir: "left", x: x2, y: to.position.y };
}

function arrow({ x, y, dir }: Geometry): string {
  switch (dir) {
    case "right":
      return `${x},${y} ${x - 6},${y - 4} ${x - 6},${y + 4}`;
    case "left":
      return `${x},${y} ${x + 6},${y - 4} ${x + 6},${y + 4}`;
    case "down":
      return `${x},${y} ${x - 4},${y - 6} ${x + 4},${y - 6}`;
    case "up":
      return `${x},${y} ${x - 4},${y + 6} ${x + 4},${y + 6}`;
  }
}
