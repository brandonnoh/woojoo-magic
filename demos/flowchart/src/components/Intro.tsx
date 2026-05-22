import { motion } from "framer-motion";

interface IntroProps {
  onChoose: (entry: "yes" | "no") => void;
  onSkip: () => void;
}

/**
 * DBH 미션 브리핑 톤 인트로.
 * - 흰 배경 + 워터마크
 * - 좌상단 작은 라벨 + 큰 미션 제목
 * - 가운데 진입점 2개 평행사변형 카드 (HOVER 시 살짝 색만 진해짐)
 */
export function Intro({ onChoose, onSkip }: IntroProps) {
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.4 }}
      className="fixed inset-0 z-30 flex flex-col bg-bg"
    >
      {/* 배경 워터마크 */}
      <svg className="absolute inset-0 h-full w-full" preserveAspectRatio="xMidYMid slice">
        <defs>
          <pattern id="introWm" width="640" height="640" patternUnits="userSpaceOnUse">
            <polygon points="320,40 600,320 320,600 40,320" fill="var(--color-watermark)" opacity="0.45" />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#introWm)" />
      </svg>

      <div className="relative z-10 flex flex-1 flex-col p-12">
        {/* 좌상단 헤더 */}
        <div>
          <div className="label-track text-[11px] text-ink-dim">WJ-MAGIC / WORKFLOW</div>
          <div className="mt-1 font-display text-[12px] tracking-[0.2em] text-ink-dim">
            v4.11.1 · 50 NODES
          </div>
          <h1 className="mt-8 font-display text-6xl font-light tracking-[0.06em] text-ink">
            BRIEFING
          </h1>
          <div className="mt-3 max-w-[480px] text-[15px] leading-relaxed text-ink-soft">
            wj-magic 의 50개 분기를 한 화면에 펼쳐 본다. <br />
            시작 지점을 선택하면 트리가 차례로 펼쳐진다.
          </div>
        </div>

        {/* 진입점 2개 */}
        <div className="mt-16 flex flex-1 items-center">
          <div className="grid w-full max-w-[820px] grid-cols-1 gap-6 md:grid-cols-2">
            <ChoiceCard
              tag="01 / START"
              label="아이디어 정해진 경우"
              hint="구체적인 만들 것이 정해져 있다"
              onClick={() => onChoose("yes")}
            />
            <ChoiceCard
              tag="02 / RESEARCH"
              label="아이디어 없는 경우"
              hint="방향부터 분석이 필요하다"
              onClick={() => onChoose("no")}
            />
          </div>
        </div>

        {/* 하단 컨트롤 */}
        <div className="flex items-center justify-between border-t border-rule pt-5">
          <button
            type="button"
            onClick={onSkip}
            className="label-track-tight cursor-pointer text-[11px] text-ink-dim transition hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-line focus-visible:ring-offset-2 focus-visible:ring-offset-bg"
          >
            ↳ SKIP / 전체 트리 펼치기
          </button>
          <div className="label-track text-[10px] text-ink-dim">
            INSPIRED BY DETROIT : BECOME HUMAN
          </div>
        </div>
      </div>
    </motion.div>
  );
}

function ChoiceCard({
  tag,
  label,
  hint,
  onClick,
}: {
  tag: string;
  label: string;
  hint: string;
  onClick: () => void;
}) {
  return (
    <motion.button
      type="button"
      whileHover={{ x: 4 }}
      transition={{ type: "spring", stiffness: 300, damping: 24 }}
      onClick={onClick}
      className="group relative cursor-pointer text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-line focus-visible:ring-offset-2 focus-visible:ring-offset-bg"
    >
      {/* 평행사변형 SVG 카드 */}
      <svg viewBox="0 0 380 96" className="w-full" preserveAspectRatio="none">
        <polygon
          points="14,0 380,0 366,96 0,96"
          fill="var(--color-navy)"
          className="transition-all group-hover:fill-ink"
        />
        <rect x="14" y="18" width="6" height="60" fill="var(--color-line)" />
      </svg>
      <div className="absolute inset-0 flex flex-col justify-center pl-10 pr-6">
        <div className="label-track text-[10px] text-ink-fog">{tag}</div>
        <div className="mt-1 font-display text-2xl font-semibold tracking-[0.02em] text-white">
          {label}
        </div>
        <div className="mt-1 font-display text-[13px] tracking-[0.02em] text-ink-fog">
          {hint}
        </div>
      </div>
    </motion.button>
  );
}
