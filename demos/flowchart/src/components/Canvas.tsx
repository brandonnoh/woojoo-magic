import { useEffect, useMemo } from "react";
import { GRAPH, VIEWBOX } from "../data";
import { ZONES, type Zone } from "../data/zones";
import { useZoomPan } from "../hooks/useZoomPan";
import { Edge } from "./Edge";
import { Node } from "./Node";

interface CanvasProps {
  selectedId: string | null;
  hoveredId: string | null;
  visibleNodeIds: Set<string>;
  onHover: (id: string | null) => void;
  onSelect: (id: string) => void;
  onZoomChange?: (pct: number) => void;
}

const INITIAL = { x: 0, y: 0, w: VIEWBOX.width, h: VIEWBOX.height };

export function Canvas({
  selectedId,
  hoveredId,
  visibleNodeIds,
  onHover,
  onSelect,
  onZoomChange,
}: CanvasProps) {
  const nodeMap = useMemo(() => new Map(GRAPH.nodes.map((n) => [n.id as string, n])), []);
  const activeId = hoveredId ?? selectedId;

  const highlightedEdges = useMemo(() => {
    const s = new Set<string>();
    if (!activeId) return s;
    for (const e of GRAPH.edges) {
      if (e.from === activeId || e.to === activeId) {
        s.add(`${e.from}::${e.to}`);
      }
    }
    return s;
  }, [activeId]);

  const zoomPan = useZoomPan(INITIAL);
  const zoomPct = Math.round((INITIAL.w / zoomPan.vb.w) * 100);
  if (onZoomChange) onZoomChange(zoomPct);

  // 노드 선택 → 줌인, 해제 → 줌아웃
  useEffect(() => {
    if (selectedId) {
      const node = nodeMap.get(selectedId);
      if (node) zoomPan.focusOn(node.position.x, node.position.y);
    } else {
      zoomPan.reset();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedId]);

  const selectedNode = selectedId ? nodeMap.get(selectedId) : null;

  return (
    <div
      className="absolute inset-0"
      style={{
        perspective: "2200px",
        perspectiveOrigin: "15% 50%",
      }}
    >
    <div
      className="absolute inset-0"
      style={{
        transform: "rotateY(-7deg) rotateX(1.5deg)",
        transformOrigin: "left center",
        transformStyle: "preserve-3d",
        willChange: "transform",
      }}
    >
    <svg
      ref={zoomPan.svgRef}
      viewBox={`${zoomPan.vb.x} ${zoomPan.vb.y} ${zoomPan.vb.w} ${zoomPan.vb.h}`}
      preserveAspectRatio="xMidYMid meet"
      role="application"
      aria-roledescription="interactive flowchart"
      aria-label="wj-magic 워크플로우 분기 트리"
      className="absolute inset-0 h-full w-full select-none"
      style={{ cursor: zoomPan.isPanning() ? "grabbing" : "grab" }}
      onMouseDown={zoomPan.onMouseDown}
      onMouseMove={zoomPan.onMouseMove}
      onMouseUp={zoomPan.onMouseUp}
      onMouseLeave={zoomPan.onMouseUp}
      onDoubleClick={zoomPan.onDoubleClick}
    >
      <defs>
        <pattern id="watermark" width="640" height="640" patternUnits="userSpaceOnUse">
          <polygon points="320,40 600,320 320,600 40,320" fill="var(--color-watermark)" opacity="0.5" />
          <polygon points="320,180 460,320 320,460 180,320" fill="var(--color-watermark-2)" opacity="0.45" />
        </pattern>
      </defs>

      {/* 배경 — 워터마크 (data-pan="bg" — 드래그 팬 시작점) */}
      <rect
        data-pan="bg"
        x={-2000}
        y={-2000}
        width={6000}
        height={6000}
        fill="var(--color-bg)"
      />
      <rect
        data-pan="bg"
        x={-2000}
        y={-2000}
        width={6000}
        height={6000}
        fill="url(#watermark)"
      />

      {/* 영역 그룹 — 점선 박스 + 코너 브래킷 + 라벨 */}
      <g aria-hidden="true">
        {ZONES.map((z) => (
          <ZoneBox key={z.id} zone={z} />
        ))}
      </g>

      {/* 엣지 */}
      <g>
        {GRAPH.edges.map((e) => {
          const from = nodeMap.get(e.from as string);
          const to = nodeMap.get(e.to as string);
          if (!from || !to) return null;
          const key = `${e.from}::${e.to}`;
          const visible = visibleNodeIds.has(e.from as string) && visibleNodeIds.has(e.to as string);
          const flow: "incoming" | "outgoing" | null = selectedId
            ? e.from === selectedId
              ? "outgoing"
              : e.to === selectedId
                ? "incoming"
                : null
            : null;
          return (
            <Edge
              key={key}
              edge={e}
              from={from}
              to={to}
              highlighted={highlightedEdges.has(key)}
              active={visible}
              flow={flow}
            />
          );
        })}
      </g>

      {/* 선택 노드 펄스 링 — 줌인 직후 강조 */}
      {selectedNode && (
        <g
          transform={`translate(${selectedNode.position.x}, ${selectedNode.position.y})`}
          style={{ pointerEvents: "none" }}
        >
          <FocusRing key={selectedNode.id as string} />
        </g>
      )}

      {/* 노드 */}
      <g>
        {GRAPH.nodes.map((n) => {
          const visible = visibleNodeIds.has(n.id as string);
          return (
            <Node
              key={n.id as string}
              node={n}
              hovered={hoveredId === (n.id as string)}
              selected={selectedId === (n.id as string)}
              locked={!visible}
              onHover={onHover}
              onClick={onSelect}
            />
          );
        })}
      </g>
    </svg>
    </div>
    </div>
  );
}

function FocusRing() {
  // 노드 평행사변형보다 약간만 큰 ring — 정착 outline 제거, 펄스 wave만
  const SKEW = 10;
  const baseHW = 100; // NODE_HW(84) + 16
  const baseHH = 32; // NODE_HH(22) + 10
  const ring = parallelogramPoints(baseHW, baseHH, SKEW);

  return (
    <g>
      {/* 펄스 wave 1 — 1.0 → 1.6 expand + fade out */}
      <polygon
        points={ring}
        fill="none"
        stroke="var(--color-line-bright)"
        strokeWidth={1.4}
        opacity={0}
      >
        <animate
          attributeName="opacity"
          values="0;0.35;0"
          keyTimes="0;0.2;1"
          dur="1.8s"
          repeatCount="indefinite"
        />
        <animateTransform
          attributeName="transform"
          type="scale"
          values="1;1.6"
          dur="1.8s"
          repeatCount="indefinite"
          additive="sum"
        />
      </polygon>

      {/* 펄스 wave 2 — 0.9s stagger, 더 옅게 */}
      <polygon
        points={ring}
        fill="none"
        stroke="var(--color-line-bright)"
        strokeWidth={1}
        opacity={0}
      >
        <animate
          attributeName="opacity"
          begin="0.9s"
          values="0;0.22;0"
          keyTimes="0;0.2;1"
          dur="1.8s"
          repeatCount="indefinite"
        />
        <animateTransform
          attributeName="transform"
          type="scale"
          begin="0.9s"
          values="1;1.85"
          dur="1.8s"
          repeatCount="indefinite"
          additive="sum"
        />
      </polygon>
    </g>
  );
}

function parallelogramPoints(hw: number, hh: number, skew: number): string {
  return `${-hw + skew},${-hh} ${hw},${-hh} ${hw - skew},${hh} ${-hw},${hh}`;
}

function ZoneBox({ zone }: { zone: Zone }) {
  const { x, y, w, h, label, sub, tag } = zone;
  const L = 16;
  return (
    <g>
      <rect
        x={x}
        y={y}
        width={w}
        height={h}
        fill="var(--color-bg-soft)"
        fillOpacity={0.45}
        stroke="var(--color-rule)"
        strokeWidth={1.2}
        strokeDasharray="6 6"
      />
      {/* 코너 브래킷 4개 */}
      <g stroke="var(--color-ink-dim)" strokeWidth={1.6} fill="none">
        <path d={`M${x},${y + L} L${x},${y} L${x + L},${y}`} />
        <path d={`M${x + w - L},${y} L${x + w},${y} L${x + w},${y + L}`} />
        <path d={`M${x},${y + h - L} L${x},${y + h} L${x + L},${y + h}`} />
        <path d={`M${x + w - L},${y + h} L${x + w},${y + h} L${x + w},${y + h - L}`} />
      </g>
      <text
        x={x + 18}
        y={sub ? y - 30 : y - 12}
        fontFamily="Rajdhani, sans-serif"
        fontSize={11}
        letterSpacing="0.22em"
        fill="var(--color-ink-dim)"
        fontWeight={500}
      >
        {label}
      </text>
      {sub && (
        <text
          x={x + 18}
          y={y - 12}
          fontFamily="Rajdhani, sans-serif"
          fontSize={10}
          letterSpacing="0.08em"
          fill="var(--color-ink-fog)"
        >
          {sub}
        </text>
      )}
      {tag && (
        <text
          x={x + w - 12}
          y={sub ? y - 30 : y - 12}
          textAnchor="end"
          fontFamily="Rajdhani, sans-serif"
          fontSize={10}
          letterSpacing="0.16em"
          fill="var(--color-ink-fog)"
        >
          {tag}
        </text>
      )}
    </g>
  );
}
