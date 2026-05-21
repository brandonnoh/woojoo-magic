import { AnimatePresence } from "framer-motion";
import { useCallback, useEffect, useState } from "react";
import { Canvas } from "./components/Canvas";
import { HUD } from "./components/HUD";
import { Intro } from "./components/Intro";
import { SidePanel } from "./components/SidePanel";
import { clearRevealState, useReveal } from "./hooks/useReveal";

type IntroState = "playing" | "done";

export function App() {
  const [intro, setIntro] = useState<IntroState>("playing");
  const [startId, setStartId] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [hoveredId, setHoveredId] = useState<string | null>(null);

  const visibleIds = useReveal(startId);

  const choose = useCallback((entry: "yes" | "no") => {
    setStartId(entry === "yes" ? "entry-idea-yes" : "entry-idea-no");
    setIntro("done");
  }, []);

  const skip = useCallback(() => {
    localStorage.setItem("wjm-flowchart-seen", "1");
    setStartId("entry-idea-yes");
    setIntro("done");
  }, []);

  const restart = useCallback(() => {
    clearRevealState();
    setSelectedId(null);
    setStartId(null);
    setIntro("playing");
  }, []);

  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if (e.key === "Escape") setSelectedId(null);
    };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, []);

  return (
    <div className="relative h-full w-full overflow-hidden bg-[#f0f2f5]">
      {intro === "done" && (
        <>
          <Canvas
            selectedId={selectedId}
            hoveredId={hoveredId}
            visibleNodeIds={visibleIds}
            onHover={setHoveredId}
            onSelect={setSelectedId}
          />
          <HUD visibleCount={visibleIds.size} onReset={restart} />
          <SidePanel
            nodeId={selectedId}
            onClose={() => setSelectedId(null)}
            onSelect={setSelectedId}
          />
        </>
      )}
      <AnimatePresence>
        {intro === "playing" && <Intro onChoose={choose} onSkip={skip} />}
      </AnimatePresence>
    </div>
  );
}
