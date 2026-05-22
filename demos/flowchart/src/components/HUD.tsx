import { GRAPH } from "../data";

interface HUDProps {
  visibleCount: number;
  onReset: () => void;
}

/**
 * DBH HUD 톤:
 * - 우상단: 미션 제목 + 진행률 한 줄 + RESTART
 * - 그 아래: 인라인 컨트롤 힌트 한 줄
 */
export function HUD({ visibleCount, onReset }: HUDProps) {
  const total = GRAPH.nodes.length;
  const pct = Math.floor((visibleCount / total) * 100);

  return (
    <>
      <div className="fixed right-10 top-10 z-30 flex items-start gap-5">
        <div className="pointer-events-none flex flex-col items-end gap-1.5">
          <div className="label-track text-[10px] text-ink-dim">WJ-MAGIC / WORKFLOW</div>
          <h1 className="font-display text-[24px] font-light leading-none tracking-[0.08em] text-ink">
            THE WORKFLOW
          </h1>
          <div className="mt-1 flex items-baseline gap-2 font-display tracking-[0.14em] text-ink-dim">
            <span className="text-[13px] font-semibold text-ink">{pct}%</span>
            <span className="label-track text-[10px]">DISCOVERED</span>
            <span className="text-[10px]">· {visibleCount}/{total}</span>
          </div>
        </div>
        <button
          type="button"
          onClick={onReset}
          className="label-track-tight cursor-pointer rounded-sm border border-rule bg-white/80 px-3 py-1.5 text-[10px] text-ink-soft backdrop-blur transition hover:border-ink hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-line focus-visible:ring-offset-2 focus-visible:ring-offset-bg"
        >
          ↻ RESTART
        </button>
      </div>

      <div className="pointer-events-none fixed right-10 top-[124px] z-30 flex items-center justify-end gap-5">
        <ControlHint hot="HOVER" label="HIGHLIGHT" />
        <ControlHint hot="CLICK" label="SELECT" />
        <ControlHint hot="ESC" label="CLOSE" />
      </div>
    </>
  );
}

function ControlHint({ hot, label }: { hot: string; label: string }) {
  return (
    <div className="flex items-center gap-2">
      <span className="rounded-sm border border-ink bg-white/90 px-1.5 py-0.5 font-display text-[10px] font-semibold tracking-[0.1em] text-ink backdrop-blur">
        {hot}
      </span>
      <span className="label-track text-[10px] text-ink-dim">{label}</span>
    </div>
  );
}
