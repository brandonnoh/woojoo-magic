import { AnimatePresence, motion } from "framer-motion";
import { useMemo, useState } from "react";
import { GRAPH } from "../data";
import type { FlowNode } from "../types/graph";

interface SidePanelProps {
  nodeId: string | null;
  onClose: () => void;
  onSelect: (id: string) => void;
}

const CAT_LABEL: Record<FlowNode["category"], string> = {
  entry: "MISSION ENTRY",
  command: "COMMAND",
  skill: "SKILL",
  agent: "AGENT",
  hook: "HOOK · AUTO",
};

export function SidePanel({ nodeId, onClose, onSelect }: SidePanelProps) {
  const node = useMemo(() => {
    if (!nodeId) return null;
    return GRAPH.nodes.find((n) => (n.id as string) === nodeId) ?? null;
  }, [nodeId]);

  return (
    <AnimatePresence>
      {node && (
        <motion.aside
          key={node.id as string}
          initial={{ x: 460, opacity: 0 }}
          animate={{ x: 0, opacity: 1 }}
          exit={{ x: 460, opacity: 0 }}
          transition={{ type: "spring", stiffness: 280, damping: 30 }}
          aria-label={`${CAT_LABEL[node.category]} ${node.label} 상세`}
          className="fixed right-0 top-0 z-40 flex h-full w-[440px] max-w-[88vw] flex-col bg-white shadow-[-16px_0_40px_-12px_rgba(14,20,36,0.18)]"
        >
          <Header node={node} onClose={onClose} />
          <Body node={node} onSelect={onSelect} />
        </motion.aside>
      )}
    </AnimatePresence>
  );
}

function Header({ node, onClose }: { node: FlowNode; onClose: () => void }) {
  return (
    <header className="relative bg-navy p-6 text-white">
      {/* 좌측 액센트 바 */}
      <div className="absolute left-0 top-6 h-[calc(100%-3rem)] w-1.5 bg-line" />
      <div className="ml-3">
        <div className="label-track text-[10px] text-ink-fog">{CAT_LABEL[node.category]}</div>
        <h2 className="mt-3 font-display text-3xl font-semibold tracking-[0.08em] uppercase">
          {node.label}
        </h2>
        <p className="mt-1 font-display text-[12px] tracking-[0.12em] text-ink-fog">
          {node.full}
        </p>
      </div>
      <button
        type="button"
        onClick={onClose}
        aria-label="패널 닫기"
        className="label-track-tight absolute right-5 top-5 cursor-pointer rounded-sm border border-navy-dim px-2 py-1 text-[10px] text-ink-fog transition hover:border-white hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-line focus-visible:ring-offset-2 focus-visible:ring-offset-navy"
      >
        ESC
      </button>
    </header>
  );
}

function Body({ node, onSelect }: { node: FlowNode; onSelect: (id: string) => void }) {
  const [copied, setCopied] = useState(false);
  const connected = useMemo(() => {
    const outgoing = GRAPH.edges.filter((e) => e.from === node.id).map((e) => e.to as string);
    return outgoing
      .map((id) => GRAPH.nodes.find((n) => (n.id as string) === id))
      .filter((n): n is FlowNode => Boolean(n));
  }, [node.id]);

  const copy = () => {
    if (!node.example) return;
    void navigator.clipboard.writeText(node.example);
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  };

  return (
    <div className="flex-1 overflow-y-auto p-6 text-sm text-ink">
      <p className="text-[15px] leading-relaxed">{node.summary}</p>
      <p className="mt-4 leading-relaxed text-ink-dim">{node.detail}</p>

      {node.example && (
        <div className="mt-6">
          <div className="mb-2 flex items-center justify-between">
            <span className="label-track text-[10px] text-ink-dim">예시</span>
            <button
              type="button"
              onClick={copy}
              aria-live="polite"
              className="label-track-tight cursor-pointer text-[10px] text-line transition hover:text-navy focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-line focus-visible:ring-offset-2 focus-visible:ring-offset-bg"
            >
              {copied ? "COPIED ✓" : "COPY"}
            </button>
          </div>
          <pre className="overflow-x-auto rounded-sm border border-rule bg-bg p-3 font-mono text-[12px] text-navy">
            {node.example}
          </pre>
        </div>
      )}

      {node.triggers && node.triggers.length > 0 && (
        <div className="mt-6">
          <div className="mb-2 label-track text-[10px] text-ink-dim">자연어 트리거</div>
          <div className="flex flex-wrap gap-1.5">
            {node.triggers.map((t) => (
              <span
                key={t}
                className="rounded-sm border border-rule bg-bg px-2 py-1 font-display text-[11px] tracking-[0.06em] text-ink-soft"
              >
                {t}
              </span>
            ))}
          </div>
        </div>
      )}

      {connected.length > 0 && (
        <div className="mt-6">
          <div className="mb-2 label-track text-[10px] text-ink-dim">다음 단계</div>
          <ul className="space-y-1">
            {connected.map((n) => (
              <li key={n.id as string}>
                <button
                  type="button"
                  onClick={() => onSelect(n.id as string)}
                  className="group flex w-full cursor-pointer items-center justify-between rounded-sm border border-rule bg-white px-3 py-2 text-left transition hover:border-navy hover:bg-bg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-line focus-visible:ring-offset-2 focus-visible:ring-offset-bg"
                >
                  <span className="label-track text-[12px] text-ink">{n.label}</span>
                  <span className="label-track-tight text-[10px] text-ink-dim group-hover:text-navy">
                    →
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
