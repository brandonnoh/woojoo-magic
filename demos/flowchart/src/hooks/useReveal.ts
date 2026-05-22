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

    // 카드 선택 직후 — 전체 노드 즉시 visible (BFS reveal 제거)
    setVisible(new Set(GRAPH.nodes.map((n) => n.id as string)));
  }, [startId]);

  return visible;
}

export function clearRevealState() {
  localStorage.removeItem("wjm-flowchart-seen");
}
