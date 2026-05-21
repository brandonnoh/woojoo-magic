import { useMemo } from "react";
import { GRAPH, VIEWBOX } from "../data";
import { Edge } from "./Edge";
import { Node } from "./Node";

interface CanvasProps {
  selectedId: string | null;
  hoveredId: string | null;
  visibleNodeIds: Set<string>;
  onHover: (id: string | null) => void;
  onSelect: (id: string) => void;
}

export function Canvas({ selectedId, hoveredId, visibleNodeIds, onHover, onSelect }: CanvasProps) {
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

  return (
    <svg
      viewBox={`0 0 ${VIEWBOX.width} ${VIEWBOX.height}`}
      preserveAspectRatio="xMidYMid meet"
      className="absolute inset-0 h-full w-full"
    >
      <defs>
        {/* DBH 배경 워터마크 패턴 — 큰 옅은 마름모/삼각형 */}
        <pattern id="watermark" width="640" height="640" patternUnits="userSpaceOnUse">
          <polygon points="320,40 600,320 320,600 40,320" fill="#e2e5ea" opacity="0.5" />
          <polygon points="320,180 460,320 320,460 180,320" fill="#d8dde4" opacity="0.45" />
        </pattern>
      </defs>

      {/* 배경 — 워터마크 */}
      <rect width={VIEWBOX.width} height={VIEWBOX.height} fill="#f0f2f5" />
      <rect width={VIEWBOX.width} height={VIEWBOX.height} fill="url(#watermark)" />

      {/* 엣지 (노드 뒤) */}
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
