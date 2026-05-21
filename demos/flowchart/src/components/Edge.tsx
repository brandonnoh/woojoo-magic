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
}

export function Edge({ from, to, highlighted, active }: EdgeProps) {
  const stroke = active
    ? highlighted ? "var(--color-navy)" : "var(--color-line)"
    : "var(--color-rule)";
  const sw = highlighted ? 2.5 : active ? 1.6 : 1.2;
  const opacity = active ? 1 : 0.7;

  // 노드 가장자리에서 시작하도록 살짝 offset
  const x1 = from.position.x + 80;
  const y1 = from.position.y;
  const x2 = to.position.x - 88;
  const y2 = to.position.y;

  const path = buildPath(x1, y1, x2, y2);

  return (
    <g>
      <path
        d={path}
        fill="none"
        stroke={stroke}
        strokeWidth={sw}
        strokeOpacity={opacity}
        strokeLinejoin="miter"
        strokeLinecap="butt"
        style={{ transition: "stroke 150ms ease-out, stroke-width 150ms ease-out, stroke-opacity 150ms ease-out" }}
      />
      {/* 도착점 작은 화살표 (▶) — 활성일 때만 */}
      {active && (
        <polygon
          points={`${x2},${y2} ${x2 - 6},${y2 - 4} ${x2 - 6},${y2 + 4}`}
          fill={stroke}
          opacity={opacity}
        />
      )}
    </g>
  );
}

function buildPath(x1: number, y1: number, x2: number, y2: number): string {
  // 같은 Y면 직선
  if (Math.abs(y1 - y2) < 1) {
    return `M ${x1} ${y1} L ${x2} ${y2}`;
  }
  // L-shape — 중간 지점에서 꺾음
  const midX = x1 + (x2 - x1) / 2;
  return `M ${x1} ${y1} L ${midX} ${y1} L ${midX} ${y2} L ${x2} ${y2}`;
}
