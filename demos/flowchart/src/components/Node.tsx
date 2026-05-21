import type { FlowNode } from "../types/graph";
import { NODE_H, NODE_W } from "../data/grid";

/**
 * DBH 인게임 플로우차트 노드.
 * - 평행사변형 (우측으로 살짝 기울어진 사다리꼴)
 * - 활성: 다크 네이비 + 흰 텍스트
 * - 잠금: 옅은 그레이 + 네 코너 브래킷 + 빨간 자물쇠
 */
interface NodeProps {
  node: FlowNode;
  hovered: boolean;
  selected: boolean;
  locked: boolean;
  onHover: (id: string | null) => void;
  onClick: (id: string) => void;
}

const W = NODE_W;
const H = NODE_H;
const SKEW = 10;

// 평행사변형 좌표 (center 기준)
const HX = W / 2;
const HY = H / 2;
const SHAPE = `${-HX + SKEW},${-HY} ${HX},${-HY} ${HX - SKEW},${HY} ${-HX},${HY}`;

const ENTRY_W = 220;
const ENTRY_H = 64;
const EHX = ENTRY_W / 2;
const EHY = ENTRY_H / 2;
const ENTRY_SHAPE = `${-EHX + 14},${-EHY} ${EHX},${-EHY} ${EHX - 14},${EHY} ${-EHX},${EHY}`;

export function Node({ node, hovered, selected, locked, onHover, onClick }: NodeProps) {
  const isActive = !locked;
  const isEntry = node.category === "entry";
  const isHook = node.category === "hook";
  const focus = hovered || selected;

  const w = isEntry ? ENTRY_W : W;
  const h = isEntry ? ENTRY_H : H;
  const shape = isEntry ? ENTRY_SHAPE : SHAPE;

  const { x, y } = node.position;

  return (
    <g
      transform={`translate(${x}, ${y})`}
      style={{ cursor: "pointer" }}
      onMouseEnter={() => onHover(node.id as string)}
      onMouseLeave={() => onHover(null)}
      onClick={() => onClick(node.id as string)}
    >
      {/* 잠금 노드: 네 코너 브래킷 */}
      {locked && <CornerBrackets w={w} h={h} />}

      {/* 본체 */}
      <polygon
        points={shape}
        fill={fillFor(node.category, isActive, focus)}
        stroke={strokeFor(node.category, isActive, focus)}
        strokeWidth={focus ? 1.6 : 1}
      />

      {/* 좌측 액센트 사각형 (활성 노드만) */}
      {isActive && !isHook && !isEntry && (
        <rect
          x={-HX + 4}
          y={-HY + 6}
          width={6}
          height={H - 12}
          fill={accentFor(node.category)}
        />
      )}

      {/* 라벨 */}
      {locked ? (
        <LockLabel />
      ) : (
        <text
          x={isEntry ? 0 : isHook ? 0 : -HX + 22}
          y={isEntry ? 4 : 4}
          textAnchor={isEntry || isHook ? "middle" : "start"}
          fontFamily="Rajdhani, sans-serif"
          fontSize={isEntry ? 16 : isHook ? 11 : 13}
          fontWeight={isEntry ? 600 : 500}
          letterSpacing={isEntry ? "0.15em" : isHook ? "0.08em" : "0.1em"}
          fill={textFor(node.category)}
          style={{ pointerEvents: "none", textTransform: "uppercase" }}
        >
          {node.label}
        </text>
      )}
    </g>
  );
}

function CornerBrackets({ w, h }: { w: number; h: number }) {
  const hw = w / 2;
  const hh = h / 2;
  const L = 10; // 브래킷 길이
  const stroke = "#5b6379";
  const sw = 1.2;
  const off = 8;
  // 네 모서리에 ㄱ자 짧은 선
  return (
    <g opacity={0.6}>
      {/* top-left */}
      <path d={`M ${-hw - off} ${-hh - off + L} L ${-hw - off} ${-hh - off} L ${-hw - off + L} ${-hh - off}`} stroke={stroke} strokeWidth={sw} fill="none" />
      {/* top-right */}
      <path d={`M ${hw + off - L} ${-hh - off} L ${hw + off} ${-hh - off} L ${hw + off} ${-hh - off + L}`} stroke={stroke} strokeWidth={sw} fill="none" />
      {/* bottom-left */}
      <path d={`M ${-hw - off} ${hh + off - L} L ${-hw - off} ${hh + off} L ${-hw - off + L} ${hh + off}`} stroke={stroke} strokeWidth={sw} fill="none" />
      {/* bottom-right */}
      <path d={`M ${hw + off - L} ${hh + off} L ${hw + off} ${hh + off} L ${hw + off} ${hh + off - L}`} stroke={stroke} strokeWidth={sw} fill="none" />
    </g>
  );
}

function LockLabel() {
  return (
    <g>
      {/* 빨간 자물쇠 아이콘 (간단한 표현) */}
      <rect x={-HX + 8} y={-7} width={10} height={10} fill="#d22b3a" rx={1} />
      <rect x={-HX + 10} y={-11} width={6} height={6} fill="none" stroke="#d22b3a" strokeWidth={1.5} rx={2} />
      <text
        x={-HX + 30}
        y={4}
        fontFamily="Rajdhani, sans-serif"
        fontSize={14}
        fontWeight={500}
        letterSpacing="0.2em"
        fill="#98a0b3"
        style={{ pointerEvents: "none" }}
      >
        [ . . . ]
      </text>
    </g>
  );
}

function fillFor(cat: FlowNode["category"], active: boolean, focus: boolean): string {
  if (!active) return "#e6e9ee";
  if (cat === "entry") return focus ? "#0e1424" : "#1b2440";
  if (cat === "command") return focus ? "#1b2440" : "#2a3658";
  if (cat === "skill") return focus ? "#0e1424" : "#1b2440";
  if (cat === "agent") return focus ? "#2a3658" : "#3a4670";
  if (cat === "hook") return "#5b6379";
  return "#1b2440";
}

function strokeFor(cat: FlowNode["category"], active: boolean, focus: boolean): string {
  if (!active) return "#b9bfc9";
  if (focus) return "#2e5dda";
  if (cat === "agent") return "#5b6379";
  if (cat === "hook") return "#5b6379";
  return "#0e1424";
}

function accentFor(cat: FlowNode["category"]): string {
  if (cat === "skill") return "#2e5dda";
  if (cat === "agent") return "#7a8095";
  if (cat === "command") return "#2e5dda";
  return "#2e5dda";
}

function textFor(cat: FlowNode["category"]): string {
  if (cat === "hook") return "#f0f2f5";
  return "#f0f2f5";
}
