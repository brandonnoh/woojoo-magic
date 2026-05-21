import { GRAPH } from "../data";

interface HUDProps {
  visibleCount: number;
  onReset: () => void;
}

/**
 * DBH HUD 톤:
 * - 좌상단: 작은 라벨 + 큰 미션 제목 + 진행률
 * - 우상단: RESTART 버튼
 * - 하단 컨트롤 바: 키 라벨들 (DBH의 게임패드 가이드 자리)
 */
export function HUD({ visibleCount, onReset }: HUDProps) {
  const total = GRAPH.nodes.length;
  const pct = Math.floor((visibleCount / total) * 100);

  return (
    <>
      {/* 우상단 — 컴팩트 HUD */}
      <div className="fixed right-10 top-10 z-30 flex items-start gap-4">
        <div className="pointer-events-none text-right">
          <div className="label-track text-[10px] text-[#5b6379]">WJ-MAGIC / WORKFLOW</div>
          <h1 className="mt-1 font-display text-[24px] font-light leading-none tracking-[0.08em] text-[#0e1424]">
            THE WORKFLOW
          </h1>
          <div className="mt-2 flex items-center justify-end gap-2">
            <div className="font-display text-[20px] font-semibold leading-none text-[#0e1424]">
              {pct}%
            </div>
            <div className="label-track text-[10px] text-[#5b6379]">DISCOVERED</div>
            <div className="font-display text-[10px] tracking-[0.14em] text-[#98a0b3]">
              · {visibleCount}/{total}
            </div>
          </div>
        </div>
        <button
          type="button"
          onClick={onReset}
          className="label-track-tight cursor-pointer rounded-sm border border-[#c8cdd4] bg-white/80 px-3 py-1.5 text-[10px] text-[#2a3146] backdrop-blur transition hover:border-[#0e1424] hover:bg-white"
        >
          ↻ RESTART
        </button>
      </div>

      {/* 우상단 HUD 아래: 인라인 컨트롤 힌트 (한 줄) */}
      <div className="pointer-events-none fixed right-10 top-[100px] z-30 flex items-center justify-end gap-4">
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
      <span className="rounded-sm border border-[#0e1424] bg-white px-1.5 py-0.5 font-display text-[10px] font-semibold tracking-[0.1em] text-[#0e1424]">
        {hot}
      </span>
      <span className="label-track text-[10px] text-[#5b6379]">{label}</span>
    </div>
  );
}

