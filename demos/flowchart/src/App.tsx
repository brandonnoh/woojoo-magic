import { AnimatePresence, motion, MotionConfig } from "framer-motion";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Canvas } from "./components/Canvas";
import { HUD } from "./components/HUD";
import { Intro } from "./components/Intro";
import { SearchBar } from "./components/SearchBar";
import { SidePanel } from "./components/SidePanel";
import { GRAPH } from "./data";
import { clearRevealState, useReveal } from "./hooks/useReveal";

type IntroState = "playing" | "done";

export function App() {
  const [intro, setIntro] = useState<IntroState>("playing");
  const [startId, setStartId] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [hoveredId, setHoveredId] = useState<string | null>(null);
  const [searchFocusId, setSearchFocusId] = useState<string | null>(null);

  const revealedIds = useReveal(startId);

  /** 검색 포커스 활성 시 — 해당 노드 + 직접 연결된 인접만 visible. */
  const focusNeighborhood = useMemo(() => {
    if (!searchFocusId) return null;
    const set = new Set<string>([searchFocusId]);
    for (const e of GRAPH.edges) {
      if (e.from === searchFocusId) set.add(e.to as string);
      if (e.to === searchFocusId) set.add(e.from as string);
    }
    return set;
  }, [searchFocusId]);

  const visibleIds = focusNeighborhood ?? revealedIds;

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
    setSearchFocusId(null);
    setStartId(null);
    setIntro("playing");
  }, []);

  const onSearchPick = useCallback((id: string) => {
    setSearchFocusId(id);
    setSelectedId(id);
  }, []);

  const clearSearchFocus = useCallback(() => {
    setSearchFocusId(null);
  }, []);

  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setSelectedId(null);
        setSearchFocusId(null);
      }
    };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, []);

  return (
    <MotionConfig reducedMotion="user">
      <div className="relative h-full w-full overflow-hidden bg-bg">
        {intro === "done" && (
          <motion.div
            initial={{ opacity: 0, scale: 1.18 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.9, ease: [0.22, 0.61, 0.36, 1] }}
            className="absolute inset-0"
          >
            <Canvas
              selectedId={selectedId}
              hoveredId={hoveredId}
              visibleNodeIds={visibleIds}
              onHover={setHoveredId}
              onSelect={setSelectedId}
            />
            <HUD visibleCount={visibleIds.size} onReset={restart} />
            <SearchBar
              onPick={onSearchPick}
              onClear={clearSearchFocus}
              focusedId={searchFocusId}
            />
            <SidePanel
              nodeId={selectedId}
              onClose={() => {
                setSelectedId(null);
                setSearchFocusId(null);
              }}
              onSelect={setSelectedId}
            />
          </motion.div>
        )}
        <AnimatePresence>
          {intro === "playing" && <Intro onChoose={choose} onSkip={skip} />}
        </AnimatePresence>
      </div>
    </MotionConfig>
  );
}
