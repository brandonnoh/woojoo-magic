#!/usr/bin/env python3
"""
strategy-brief: 시장 규모(TAM/SAM/SOM) + 수익모델별 보텀업 매출 추정 템플릿.

사용법: 아래 ASSUMPTIONS / REVENUE_MODELS / YEARS 를 실제 전략 숫자로 수정 후 실행.
모든 수치는 '가정 기반 추정(illustrative)' — 앵커는 공개자료, 정밀치 아님을 리포트에 명시할 것.
합계는 반드시 이 스크립트로 검산하여 PDF 표와 일치시킨다.
"""

# ── 1) 앵커 가정 (공개 자료 기반, 대략치) ─────────────────────────
ASSUMPTIONS = {
    "시장 모수": "예: 국내 태양광 ~29GW / 평균 0.5MW → ~58,000개소",
    "연간 신규": "예: ~3GW / 6,000개소",
}

# ── 2) 수익모델 (단가 KRW, 연차별 물량) ───────────────────────────
YEARS = ["1년차", "2년차", "3년차"]
REVENUE_MODELS = {
    # name: (unit_price_KRW, [y1_qty, y2_qty, y3_qty], 단위라벨)
    "Report (단건 리포트)":   (3_000_000,  [50, 130, 300],      "건"),
    "API (포트폴리오 구독)":   (120_000,    [300, 900, 2000],    "자산·년"),
    "Index (기관 구독)":       (30_000_000, [1, 2, 5],           "기관·년"),
}

# ── 3) TAM/SAM/SOM 비율 가정 ──────────────────────────────────────
SAM_RATIO = 0.25                       # TAM 중 유효시장 비율
SOM_SHARES = {"1년차": 0.03, "2년차": 0.08, "3년차": 0.15}  # SAM 점유율


def won(v):  # 억 단위 표기
    return f"{v/1e8:,.1f}억"


def main():
    print("=" * 64)
    print("가정 (Anchor) — 모두 illustrative")
    for k, v in ASSUMPTIONS.items():
        print(f"  {k}: {v}")
    print("=" * 64)

    # 수익모델별 분해표
    print("\n[수익모델별 매출 분해]")
    header = f"{'모델':<22}{'단가':>14}  " + "  ".join(f"{y:>14}" for y in YEARS)
    print(header)
    totals = [0] * len(YEARS)
    for name, (price, qtys, unit) in REVENUE_MODELS.items():
        cells = []
        for i, q in enumerate(qtys):
            rev = price * q
            totals[i] += rev
            cells.append(f"{q:,}{unit[0]}·{won(rev)}")
        print(f"{name:<22}{price:>12,}  " + "  ".join(f"{c:>14}" for c in cells))
    print(f"{'합계':<22}{'':>14}  " + "  ".join(f"{won(t):>14}" for t in totals))

    # TAM/SAM/SOM — 3년차 매출 규모를 SOM 기준점으로 역산 예시
    tam_hint = totals[-1] / SOM_SHARES[YEARS[-1]] / SAM_RATIO
    print("\n[TAM / SAM / SOM] (3년차 매출로부터 역산 예시)")
    print(f"  TAM ≈ {won(tam_hint)} / 년   (전체 잠재)")
    print(f"  SAM ≈ {won(tam_hint*SAM_RATIO)} / 년   (TAM×{SAM_RATIO:.0%})")
    for y in YEARS:
        print(f"  SOM {y}: 점유 {SOM_SHARES[y]:.0%} → {won(tam_hint*SAM_RATIO*SOM_SHARES[y])}")

    print("\n※ 숫자는 가정 기반 추정 — PDF 리포트에 'illustrative' 명기, 사업화 전 실측 검증 필요")


if __name__ == "__main__":
    main()
