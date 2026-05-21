import { useCallback, useEffect, useRef, useState } from "react";

/**
 * SVG viewBox 기반 줌·팬 훅.
 * - 휠: 마우스 포인터를 중심으로 줌인/줌아웃 (1.15x 단계)
 * - 빈 배경 드래그: 팬 (data-pan="bg" 속성이 있는 요소에서만 시작)
 * - 빈 배경 더블 클릭: 원위치 리셋
 *
 * 노드 위에서의 클릭/호버는 영향 없음 — e.target 분기로 분리.
 */
export interface ViewBox {
  x: number;
  y: number;
  w: number;
  h: number;
}

const MIN_W = 600; // 가장 줌인 (≈ 3x)
const MAX_W = 3680; // 가장 줌아웃 (≈ 0.5x)
const WHEEL_STEP = 1.15;

const RESET_DURATION = 300;

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function easeOut(t: number): number {
  return 1 - (1 - t) * (1 - t);
}

export function useZoomPan(initial: ViewBox) {
  const svgRef = useRef<SVGSVGElement | null>(null);
  const [vb, setVb] = useState<ViewBox>(initial);
  const panState = useRef<{ startX: number; startY: number; vbx: number; vby: number } | null>(
    null,
  );
  const animating = useRef(false);

  const reset = useCallback(() => {
    animating.current = true;
    let start: number | null = null;
    let from: ViewBox | null = null;

    const tick = (ts: number) => {
      if (start === null) {
        start = ts;
        setVb((cur) => { from = cur; return cur; });
      }
      if (!from) { requestAnimationFrame(tick); return; }
      const elapsed = ts - start;
      const t = Math.min(elapsed / RESET_DURATION, 1);
      const e = easeOut(t);
      setVb({
        x: lerp(from.x, initial.x, e),
        y: lerp(from.y, initial.y, e),
        w: lerp(from.w, initial.w, e),
        h: lerp(from.h, initial.h, e),
      });
      if (t < 1) {
        requestAnimationFrame(tick);
      } else {
        animating.current = false;
      }
    };
    requestAnimationFrame(tick);
  }, [initial]);

  // 마우스 좌표 → SVG 좌표 변환
  const toSvgPoint = useCallback((clientX: number, clientY: number) => {
    const svg = svgRef.current;
    if (!svg) return null;
    const ctm = svg.getScreenCTM();
    if (!ctm) return null;
    const pt = svg.createSVGPoint();
    pt.x = clientX;
    pt.y = clientY;
    return pt.matrixTransform(ctm.inverse());
  }, []);

  // 휠 줌 — wheel 이벤트는 passive: false 가 필요해 ref + addEventListener 사용
  useEffect(() => {
    const svg = svgRef.current;
    if (!svg) return;
    const onWheel = (e: WheelEvent) => {
      e.preventDefault();
      if (animating.current) return;
      const p = toSvgPoint(e.clientX, e.clientY);
      if (!p) return;
      setVb((cur) => {
        const factor = e.deltaY > 0 ? WHEEL_STEP : 1 / WHEEL_STEP;
        const targetW = cur.w * factor;
        const nw = Math.max(MIN_W, Math.min(MAX_W, targetW));
        const realScale = nw / cur.w;
        const nh = cur.h * realScale;
        // 마우스 포인터가 화면상 같은 위치에 머물도록 x/y 보정
        const nx = p.x - (p.x - cur.x) * realScale;
        const ny = p.y - (p.y - cur.y) * realScale;
        return { x: nx, y: ny, w: nw, h: nh };
      });
    };
    svg.addEventListener("wheel", onWheel, { passive: false });
    return () => {
      svg.removeEventListener("wheel", onWheel);
    };
  }, [toSvgPoint]);

  // Pan — 빈 배경에서만 (data-pan="bg")
  const onMouseDown = useCallback(
    (e: React.MouseEvent<SVGSVGElement>) => {
      if (animating.current) return;
      const target = e.target as SVGElement;
      if (target.getAttribute("data-pan") !== "bg") return;
      panState.current = {
        startX: e.clientX,
        startY: e.clientY,
        vbx: vb.x,
        vby: vb.y,
      };
    },
    [vb.x, vb.y],
  );

  const onMouseMove = useCallback(
    (e: React.MouseEvent<SVGSVGElement>) => {
      const s = panState.current;
      if (!s) return;
      const svg = svgRef.current;
      if (!svg) return;
      const rect = svg.getBoundingClientRect();
      // 화면 픽셀 → SVG 단위 (현재 viewBox 폭 기준)
      const px = vb.w / rect.width;
      const py = vb.h / rect.height;
      const dx = (e.clientX - s.startX) * px;
      const dy = (e.clientY - s.startY) * py;
      setVb((cur) => ({ ...cur, x: s.vbx - dx, y: s.vby - dy }));
    },
    [vb.w, vb.h],
  );

  const onMouseUp = useCallback(() => {
    panState.current = null;
  }, []);

  // 빈 배경 더블 클릭 → 리셋
  const onDoubleClick = useCallback(
    (e: React.MouseEvent<SVGSVGElement>) => {
      if ((e.target as SVGElement).getAttribute("data-pan") !== "bg") return;
      reset();
    },
    [reset],
  );

  const isPanning = useCallback(() => panState.current !== null, []);

  return {
    svgRef,
    vb,
    reset,
    onMouseDown,
    onMouseMove,
    onMouseUp,
    onDoubleClick,
    isPanning,
  };
}
