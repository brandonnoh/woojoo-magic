import { useEffect, useMemo, useRef, useState } from "react";
import { motion } from "framer-motion";
import { GRAPH } from "../data";
import type { FlowNode } from "../types/graph";

interface SearchBarProps {
  /** 검색 결과 선택 시 호출. 선택 노드 ID를 전달. */
  onPick: (id: string) => void;
  /** 검색 포커스 해제 (입력 비우기 + dim 모드 해제). */
  onClear: () => void;
  /** 현재 검색 포커스된 노드 ID (있으면 라벨 표시). */
  focusedId: string | null;
}

const CAT_LABEL: Record<FlowNode["category"], string> = {
  entry: "ENTRY",
  command: "CMD",
  skill: "SKILL",
  agent: "AGENT",
  hook: "HOOK",
};

const MAX_RESULTS = 8;
const CAT_ORDER: FlowNode["category"][] = ["entry", "command", "skill", "agent", "hook"];

export function SearchBar({ onPick, onClear, focusedId }: SearchBarProps) {
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const [highlight, setHighlight] = useState(0);
  const inputRef = useRef<HTMLInputElement | null>(null);

  const results = useMemo(() => matchNodes(query), [query]);

  useEffect(() => {
    setHighlight(0);
  }, [query]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "/" && document.activeElement !== inputRef.current) {
        e.preventDefault();
        inputRef.current?.focus();
        setOpen(true);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const choose = (node: FlowNode) => {
    onPick(node.id as string);
    setQuery("");
    setOpen(false);
    inputRef.current?.blur();
  };

  const clear = () => {
    setQuery("");
    setOpen(false);
    onClear();
    inputRef.current?.blur();
  };

  const onKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setHighlight((h) => Math.min(h + 1, results.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setHighlight((h) => Math.max(h - 1, 0));
    } else if (e.key === "Enter") {
      e.preventDefault();
      const pick = results[highlight];
      if (pick) choose(pick);
    } else if (e.key === "Escape") {
      e.preventDefault();
      clear();
    }
  };

  const focusedNode = focusedId ? GRAPH.nodes.find((n) => n.id === focusedId) : null;
  const showResults = open && results.length > 0;

  return (
    <motion.div
      initial={{ opacity: 0, y: -8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.25, duration: 0.4 }}
      className="pointer-events-auto fixed left-1/2 top-6 z-30 w-[min(560px,92vw)] -translate-x-1/2"
    >
      <div className="relative">
        <div className="flex items-center gap-3 rounded-sm border border-rule bg-white/95 px-4 py-2.5 shadow-[0_8px_24px_-12px_rgba(14,20,36,0.25)] backdrop-blur">
          <span className="label-track text-[10px] text-ink-dim">SEARCH</span>
          <div className="h-4 w-px bg-rule" />
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              setOpen(true);
            }}
            onFocus={() => setOpen(true)}
            onBlur={() => window.setTimeout(() => setOpen(false), 120)}
            onKeyDown={onKeyDown}
            placeholder={
              focusedNode
                ? `포커스: ${focusedNode.label} — ESC 또는 ✕ 로 해제`
                : "노드 검색 (이름·한글 라벨·트리거)  /"
            }
            aria-label="노드 검색"
            className="flex-1 bg-transparent text-[14px] text-ink outline-none placeholder:text-ink-fog"
          />
          {(query || focusedId) && (
            <button
              type="button"
              onClick={clear}
              aria-label="검색 해제"
              className="label-track-tight cursor-pointer rounded-sm border border-rule px-2 py-0.5 text-[10px] text-ink-dim transition hover:border-ink hover:text-ink"
            >
              ✕ ESC
            </button>
          )}
        </div>

        {showResults && (
          <ul
            role="listbox"
            className="absolute left-0 right-0 top-[calc(100%+6px)] max-h-[60vh] overflow-y-auto rounded-sm border border-rule bg-white shadow-[0_16px_40px_-16px_rgba(14,20,36,0.3)]"
          >
            {results.map((n, i) => (
              <li
                key={n.id as string}
                role="option"
                aria-selected={i === highlight}
                onMouseEnter={() => setHighlight(i)}
                onMouseDown={(e) => {
                  e.preventDefault();
                  choose(n);
                }}
                className={`flex cursor-pointer items-start gap-3 border-l-2 px-4 py-2.5 transition ${
                  i === highlight
                    ? "border-l-line bg-bg"
                    : "border-l-transparent hover:bg-bg-soft"
                }`}
              >
                <span className="label-track-tight mt-[3px] w-[44px] shrink-0 text-[9px] text-ink-dim">
                  {CAT_LABEL[n.category]}
                </span>
                <span className="flex-1">
                  <span className="block font-display text-[14px] font-medium text-ink">
                    {n.label}
                  </span>
                  <span className="mt-0.5 block text-[11px] leading-snug text-ink-soft">
                    {n.summary}
                  </span>
                </span>
                <span className="label-track-tight mt-[3px] shrink-0 text-[10px] text-ink-fog">
                  ↵
                </span>
              </li>
            ))}
          </ul>
        )}

        {open && query.length > 0 && results.length === 0 && (
          <div className="absolute left-0 right-0 top-[calc(100%+6px)] rounded-sm border border-rule bg-white px-4 py-3 text-[12px] text-ink-dim">
            매칭되는 노드 없음. 다른 키워드 시도 — 예: "디자인", "보안", "loop"
          </div>
        )}
      </div>
    </motion.div>
  );
}

function matchNodes(raw: string): FlowNode[] {
  const q = raw.trim().toLowerCase();
  if (!q) {
    // 빈 쿼리 — 전체 노드를 카테고리·라벨 순으로 (드롭다운 자체 스크롤로 처리)
    return [...GRAPH.nodes].sort((a, b) => {
      const ca = CAT_ORDER.indexOf(a.category);
      const cb = CAT_ORDER.indexOf(b.category);
      if (ca !== cb) return ca - cb;
      return a.label.localeCompare(b.label);
    });
  }
  const scored: { node: FlowNode; score: number }[] = [];
  for (const n of GRAPH.nodes) {
    const score = scoreNode(n, q);
    if (score > 0) scored.push({ node: n, score });
  }
  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, MAX_RESULTS).map((s) => s.node);
}

function scoreNode(n: FlowNode, q: string): number {
  const label = n.label.toLowerCase();
  const full = n.full.toLowerCase();
  const summary = n.summary.toLowerCase();
  const triggers = (n.triggers ?? []).map((t) => t.toLowerCase());
  let s = 0;
  if (label === q) s += 100;
  if (label.startsWith(q)) s += 60;
  if (label.includes(q)) s += 40;
  if (full.includes(q)) s += 25;
  if (summary.includes(q)) s += 12;
  for (const t of triggers) {
    if (t.includes(q)) s += 18;
  }
  return s;
}
