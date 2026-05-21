import { useMemo } from "react";
import { GRAPH, VIEWBOX } from "../data";
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

  return (
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

      {/* 엣지 */}
      <g>
        {GRAPH.edges.map((e) => {
          const from = nodeMap.get(e.from as string);
          const to = nodeMap.get(e.to as string);
          if (!from || !to) return null;
          const key = `${e.from}::${e.to}`;
          const visible = visibleNodeIds.has(e.from as string) && visibleNodeIds.has(e.to as string);
          return (
            <Edge
              key={key}
              edge={e}
              from={from}
              to={to}
              highlighted={highlightedEdges.has(key)}
              active={visible}
            />
          );
        })}
      </g>

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
  );
}
