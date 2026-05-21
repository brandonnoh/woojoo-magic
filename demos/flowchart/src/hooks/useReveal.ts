import { useEffect, useState } from "react";
import { GRAPH } from "../data";

/**
 * 인트로 선택 이후 트리를 BFS 순서로 천천히 펼치는 훅.
 * - 선택한 진입점부터 시작해서 분기를 따라가며 한 노드씩 활성화
 * - localStorage에 "이미 한 번 펼쳐본 사람"이면 즉시 전체 펼침
 */
export function useReveal(startId: string | null) {
  const [visible, setVisible] = useState<Set<string>>(new Set());

  useEffect(() => {
    if (!startId) {
      setVisible(new Set());
      return;
    }

    // 이미 본 사용자라면 즉시 전체 표시
    if (localStorage.getItem("wjm-flowchart-seen") === "1") {
      setVisible(new Set(GRAPH.nodes.map((n) => n.id as string)));
      return;
    }

    // BFS 펼침 — 분기마다 stagger
    const queue: string[][] = [[startId]];
    const seen = new Set<string>([startId]);
    const timers: number[] = [];
    let depth = 0;

    const step = () => {
      const layer = queue.shift();
      if (!layer) {
        localStorage.setItem("wjm-flowchart-seen", "1");
        return;
      }
      setVisible((prev) => {
        const next = new Set(prev);
        for (const id of layer) next.add(id);
        return next;
      });
      // 다음 레이어 수집
      const nextLayer: string[] = [];
      for (const id of layer) {
        for (const e of GRAPH.edges) {
          if (e.from === id && !seen.has(e.to as string)) {
            seen.add(e.to as string);
            nextLayer.push(e.to as string);
          }
        }
      }
      if (nextLayer.length > 0) queue.push(nextLayer);
      depth += 1;
      timers.push(window.setTimeout(step, depth === 1 ? 600 : 350));
    };

    step();

    // 5초 후 미연결 노드(에이전트 위성, 훅, 메타 커맨드) 일괄 펼침
    timers.push(
      window.setTimeout(() => {
        setVisible(new Set(GRAPH.nodes.map((n) => n.id as string)));
      }, 4500),
    );

    return () => {
      for (const t of timers) clearTimeout(t);
    };
  }, [startId]);

  return visible;
}

export function clearRevealState() {
  localStorage.removeItem("wjm-flowchart-seen");
}
