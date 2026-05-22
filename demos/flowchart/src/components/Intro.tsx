import { AnimatePresence, motion } from "framer-motion";
import { useState } from "react";
import { Scramble } from "./Scramble";

interface IntroProps {
  onChoose: (entry: "yes" | "no") => void;
  onSkip: () => void;
}

type Selecting = "yes" | "no" | null;

const SELECT_DELAY_MS = 520;

/**
 * DBH 미션 브리핑 톤 인트로.
 * - 헤더(좌상단) + 가운데 큰 안내 타이틀 + 진입 카드 2개 + 하단 컨트롤
 * - 카드 선택 시 해당 카드만 확대 + 다른 카드 페이드아웃 → onChoose 지연 호출
 */
export function Intro({ onChoose, onSkip }: IntroProps) {
  const [selecting, setSelecting] = useState<Selecting>(null);

  const handleChoose = (entry: "yes" | "no") => {
    if (selecting) return;
    setSelecting(entry);
    window.setTimeout(() => onChoose(entry), SELECT_DELAY_MS);
  };

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.4 }}
      className="fixed inset-0 z-30 flex flex-col bg-bg"
    >
      <svg className="absolute inset-0 h-full w-full" preserveAspectRatio="xMidYMid slice">
        <defs>
          <pattern id="introWm" width="640" height="640" patternUnits="userSpaceOnUse">
            <polygon points="320,40 600,320 320,600 40,320" fill="var(--color-watermark)" opacity="0.45" />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#introWm)" />
      </svg>

      <div className="relative z-10 flex flex-1 flex-col px-12 py-10">
        <motion.div
          animate={{ opacity: selecting ? 0 : 1, y: selecting ? -8 : 0 }}
          transition={{ duration: 0.32 }}
        >
          <div className="label-track text-[11px] text-ink-dim">
            <Scramble text="WJ-MAGIC / WORKFLOW" delay={0} stagger={20} scrambleMs={160} />
          </div>
          <div className="mt-1 font-display text-[12px] tracking-[0.2em] text-ink-dim">
            <Scramble text="v4.13.0 · 51 NODES" delay={100} stagger={20} scrambleMs={160} />
          </div>
        </motion.div>

        <div className="flex flex-1 flex-col items-center justify-center">
          <motion.div
            animate={{ opacity: selecting ? 0 : 1, y: selecting ? -16 : 0 }}
            transition={{ duration: 0.32 }}
            className="mb-14 flex w-full max-w-[1080px] flex-col items-center text-center"
          >
            <div className="label-track text-[12px] text-ink-dim">
              <Scramble text="BRIEFING · MISSION SELECT" delay={220} stagger={18} scrambleMs={160} />
            </div>
            <h1 className="mt-4 font-display text-[64px] font-light leading-[1.05] tracking-[0.02em] text-ink md:text-[88px]">
              <Scramble text="시작 지점을 고르세요" delay={360} stagger={45} scrambleMs={220} />
            </h1>
            <div className="mt-3 font-display text-[14px] tracking-[0.32em] text-ink-dim md:text-[15px]">
              <Scramble text="CHOOSE YOUR ENTRY POINT" delay={720} stagger={18} scrambleMs={150} />
            </div>
            <p className="mt-6 max-w-[640px] text-[15px] leading-relaxed text-ink-soft md:text-[16px]">
              <Scramble
                text="wj-magic 의 51개 분기를 한 화면에 펼쳐 봅니다."
                delay={1000}
                stagger={12}
                scrambleMs={140}
              />
              <br />
              <Scramble
                text="아래에서 진입 지점을 선택하면 트리가 차례로 펼쳐집니다."
                delay={1200}
                stagger={12}
                scrambleMs={140}
              />
            </p>
          </motion.div>

          <div className="grid w-full max-w-[1080px] grid-cols-1 gap-8 md:grid-cols-2">
            <ChoiceCard
              tag="01 / START"
              label="아이디어 정해진 경우"
              hint="구체적인 만들 것이 정해져 있다"
              direction="left"
              selecting={selecting}
              mine="yes"
              scrambleDelay={1500}
              onClick={() => handleChoose("yes")}
            />
            <ChoiceCard
              tag="02 / RESEARCH"
              label="아이디어 없는 경우"
              hint="방향부터 분석이 필요하다"
              direction="right"
              selecting={selecting}
              mine="no"
              scrambleDelay={1650}
              onClick={() => handleChoose("no")}
            />
          </div>
        </div>

        <motion.div
          animate={{ opacity: selecting ? 0 : 1 }}
          transition={{ duration: 0.32 }}
          className="flex items-center justify-between border-t border-rule pt-5"
        >
          <button
            type="button"
            onClick={onSkip}
            disabled={!!selecting}
            className="label-track-tight cursor-pointer text-[11px] text-ink-dim transition hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-line focus-visible:ring-offset-2 focus-visible:ring-offset-bg disabled:cursor-default"
          >
            ↳ <Scramble text="SKIP / 전체 트리 펼치기" delay={1850} stagger={14} scrambleMs={140} />
          </button>
          <div className="label-track text-[10px] text-ink-dim">
            <Scramble text="INSPIRED BY DETROIT : BECOME HUMAN" delay={2000} stagger={14} scrambleMs={140} />
          </div>
        </motion.div>
      </div>

      <AnimatePresence>
        {selecting && (
          <motion.div
            key="flash"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.4, delay: 0.18 }}
            className="pointer-events-none absolute inset-0 z-20 bg-bg"
          />
        )}
      </AnimatePresence>
    </motion.div>
  );
}

function ChoiceCard({
  tag,
  label,
  hint,
  direction,
  selecting,
  mine,
  scrambleDelay,
  onClick,
}: {
  tag: string;
  label: string;
  hint: string;
  direction: "left" | "right";
  selecting: Selecting;
  mine: "yes" | "no";
  scrambleDelay: number;
  onClick: () => void;
}) {
  const isChosen = selecting === mine;
  const isDimmed = selecting !== null && !isChosen;

  return (
    <motion.button
      type="button"
      whileHover={selecting ? undefined : { x: direction === "left" ? 6 : -6 }}
      animate={{
        opacity: isDimmed ? 0 : 1,
        scale: isChosen ? 1.12 : 1,
        x: isChosen ? (direction === "left" ? 24 : -24) : 0,
      }}
      transition={{ type: "spring", stiffness: 220, damping: 22 }}
      onClick={onClick}
      disabled={!!selecting}
      className="group relative h-[148px] cursor-pointer text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-line focus-visible:ring-offset-2 focus-visible:ring-offset-bg disabled:cursor-default"
    >
      <svg viewBox="0 0 520 148" className="h-full w-full" preserveAspectRatio="none">
        <polygon
          points="22,0 520,0 498,148 0,148"
          fill="var(--color-navy)"
          className="transition-all group-hover:fill-ink"
        />
        <rect x="22" y="26" width="7" height="96" fill="var(--color-line)" />
      </svg>
      <div className="absolute inset-0 flex flex-col justify-center pl-14 pr-8">
        <div className="label-track text-[11px] text-ink-fog">
          <Scramble text={tag} delay={scrambleDelay} stagger={18} scrambleMs={150} />
        </div>
        <div className="mt-2 font-display text-[30px] font-semibold leading-tight tracking-[0.02em] text-white md:text-[34px]">
          <Scramble text={label} delay={scrambleDelay + 120} stagger={32} scrambleMs={180} />
        </div>
        <div className="mt-2 font-display text-[14px] tracking-[0.04em] text-ink-fog md:text-[15px]">
          <Scramble text={hint} delay={scrambleDelay + 320} stagger={14} scrambleMs={140} />
        </div>
      </div>
    </motion.button>
  );
}
