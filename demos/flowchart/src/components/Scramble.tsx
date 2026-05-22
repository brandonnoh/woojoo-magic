import { useEffect, useState } from "react";
import { useReducedMotion } from "framer-motion";

const GLYPHS = "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾐﾑﾒ#%&*+=<>";

interface ScrambleProps {
  text: string;
  /** ms — mount 후 시작까지 지연 */
  delay?: number;
  /** ms — 글자 간 정착 간격 */
  stagger?: number;
  /** ms — 첫 글자가 정착되기까지 글리치 지속 시간 */
  scrambleMs?: number;
  className?: string;
}

/**
 * 해커 글리치 효과 — 마운트 즉시 모든 글자가 가타카나/심볼로 스크램블되다가
 * 왼쪽부터 stagger 간격으로 원본 글자로 정착한다.
 * 공백·줄바꿈은 스크램블 대상에서 제외된다.
 * prefers-reduced-motion 사용자에겐 즉시 원본 표시.
 */
export function Scramble({
  text,
  delay = 0,
  stagger = 40,
  scrambleMs = 240,
  className,
}: ScrambleProps) {
  const reduced = useReducedMotion();
  const [out, setOut] = useState<string>(() => (reduced ? text : ""));

  useEffect(() => {
    if (reduced) {
      setOut(text);
      return;
    }
    const start = performance.now() + delay;
    let raf = 0;
    let stopped = false;

    const tick = (now: number) => {
      if (stopped) return;
      const t = now - start;
      let allDone = true;
      const next = Array.from(text).map((ch, i) => {
        if (ch === " " || ch === "\n") return ch;
        const charEnd = i * stagger + scrambleMs;
        if (t < 0) {
          allDone = false;
          return " ";
        }
        if (t < charEnd) {
          allDone = false;
          return GLYPHS[Math.floor(Math.random() * GLYPHS.length)];
        }
        return ch;
      });
      setOut(next.join(""));
      if (!allDone) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => {
      stopped = true;
      cancelAnimationFrame(raf);
    };
  }, [text, delay, stagger, scrambleMs, reduced]);

  return <span className={className}>{out}</span>;
}
