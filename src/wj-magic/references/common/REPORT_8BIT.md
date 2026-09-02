# 8-bit 시각 리포트 (REPORT_8BIT)

보고형 스킬의 **필수 마무리 단계**. 분석·설계·감사·조사 결과를 종합해 사용자에게
보고할 때, 텍스트 리포트와 별도로 **8-bit 레트로 게임 스타일의 단일 HTML 도감**을
생성하고 로컬 브라우저로 즉시 띄워 보여준다.

> 원칙: 채팅 요약을 대체하지 않는다. 채팅에는 핵심 요약을 그대로 쓰고,
> HTML은 "한눈에 구조가 보이는 시각 브리핑"으로 병행 제공한다.

## 적용 대상 스킬

`cto-review`, `db-design`, `aeo`(필수) + `audit`, `investigate`, `analyze`,
`venture`, `explain`(시스템/구조 단위 설명일 때), `/wj-magic:check`.
즉 **결과를 종합해 사용자에게 보고하는 모든 스킬**의 마지막 단계.

## 생성 규칙

1. **경로**: `docs/reports/{skill}-{주제}-8bit.html` (예: `docs/reports/cto-review-arch-8bit.html`).
   `docs/reports/`가 없으면 생성한다.
2. **단일 파일**: 외부 의존성은 Galmuri 폰트 CDN 하나만. JS 없이 CSS 애니메이션만 사용.
3. **로컬 오픈 (필수)**: 생성 직후 반드시 브라우저로 띄운다.
   ```bash
   open "docs/reports/{파일명}.html"          # macOS
   # Linux: xdg-open, 안 열리면: python3 -m http.server 8901 --directory docs/reports &
   ```
4. **채팅 보고**: 파일 경로와 함께 "브라우저에 리포트를 띄웠다"고 알린다.
5. **내용 우선**: 스타일은 수단이다. 실제 분석 결과(파일:라인, 수치, 심각도, 트레이드오프)가
   전부 담겨야 하며, 장식을 위해 정보를 누락하지 않는다.

## 콘텐츠 구성 원칙

- **STAGE 패널 구조**: 리포트를 5~8개의 `STAGE N · 제목` 패널로 나눈다.
  각 패널 = 하나의 명쾌한 메시지 (전체 구조 → 상세 → 수치 → 상태 → 액션 순).
- **비유와 명쾌함**: 각 패널 첫 문단은 비개발자도 이해하는 한 문장으로 시작.
  "예전엔 X였다 — 이제 Y다" 식의 before/after 서술이 잘 맞는다.
- **심각도 색 매핑**: CRITICAL=`--coral`, HIGH=`--gold`, MEDIUM=`--sky`,
  LOW/INFO=`--sub`, 통과/해결=`--lime`.
- **마지막 패널은 항상 "코드 맵" 또는 "다음 액션"**: 어디를 보면 되는지 / Wave·태스크 목록.
- **footer**: `♥ INSERT COIN TO CONTINUE ♥` + 프로젝트명·근거 문서 경로.

## 컴포넌트 카탈로그 (상황별 선택)

| 컴포넌트 | 용도 | 예 |
|----------|------|-----|
| 컨베이어(`conveyor`+`packet`) | 파이프라인·데이터 흐름 | 요청 경로, 빌드 흐름, CDC 전파 |
| 게이트 시퀀스(`gates`) | 순차 판정·검증 단계 | 품질 게이트, 정책 판정, 마이그레이션 4단계 |
| HUD 테이블(`bar` 게이지) | 수치·상한·커버리지 | 이슈 수, 캡, 인덱스 커버리지, 점수 |
| 상태머신(`fsm`) | 상태 전이 | 이슈 라이프사이클, outbox, 배포 상태 |
| 카드 그리드(`srcgrid`) | 항목 도감 | 도메인별 이슈, DB 후보, 에이전트 팀, 취약점 |
| 씬(`scene`) | 시간·시나리오 연출 | 10배 성장 시나리오, 심야/피크 트래픽 |

## HTML 스켈레톤 (이 CSS를 그대로 복사해 시작)

```html
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{프로젝트} {리포트명} — 8bit 도감</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/galmuri@latest/dist/galmuri.css">
<style>
  :root {
    --bg: #1a1423; --panel: #241b2f; --panel2: #2d2240;
    --ink: #f3ead9; --sub: #9c8aa5; --grid: #2a2136;
    --lime: #9dde6a; --gold: #ffd75e; --coral: #ff7e67;
    --sky: #6ecbff; --violet: #b98aff;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html { background: var(--bg); }
  body {
    font-family: "Galmuri11", "Galmuri9", monospace;
    color: var(--ink);
    background:
      linear-gradient(var(--grid) 1px, transparent 1px),
      linear-gradient(90deg, var(--grid) 1px, transparent 1px);
    background-size: 24px 24px; background-color: var(--bg);
    padding: 32px 16px 80px; line-height: 1.7; image-rendering: pixelated;
  }
  .wrap { max-width: 880px; margin: 0 auto; }
  body::after { /* 스캔라인 */
    content: ""; position: fixed; inset: 0; pointer-events: none; z-index: 99;
    background: repeating-linear-gradient(0deg, rgba(0,0,0,.12) 0 1px, transparent 1px 3px);
  }
  .panel {
    background: var(--panel); border: 3px solid var(--ink);
    box-shadow: 6px 6px 0 #000; padding: 22px 20px;
    margin-bottom: 34px; position: relative;
  }
  .panel::before {
    content: attr(data-tag);
    position: absolute; top: -14px; left: 14px;
    background: var(--gold); color: #1a1423;
    font-size: 11px; font-weight: bold;
    padding: 2px 10px; border: 3px solid var(--ink);
  }
  h1 { font-size: 26px; text-align: center; margin-bottom: 6px;
       color: var(--gold); text-shadow: 3px 3px 0 #000; }
  .subtitle { text-align: center; color: var(--sub); font-size: 12px; margin-bottom: 30px; }
  .blink { animation: blink 1.1s steps(2) infinite; }
  @keyframes blink { 50% { opacity: 0; } }
  h2 { font-size: 15px; color: var(--sky); margin: 14px 0 10px; }
  h2::before { content: "▸ "; color: var(--coral); }
  p, li { font-size: 12.5px; }
  .dim { color: var(--sub); }
  code { font-family: inherit; background: #000; color: var(--lime);
         padding: 1px 6px; border: 1px solid #444; font-size: 11.5px; }
  /* 컨베이어 */
  .conveyor { display: flex; align-items: center; justify-content: space-between;
              gap: 6px; margin: 18px 0 8px; flex-wrap: wrap; }
  .station { flex: 1; min-width: 118px; text-align: center;
             background: var(--panel2); border: 3px solid var(--ink);
             padding: 10px 6px; font-size: 11px; }
  .station b { display: block; font-size: 12px; margin-bottom: 3px; }
  .station small { color: var(--sub); font-size: 10px; }
  .arrow { color: var(--coral); font-size: 16px; animation: nudge 1s steps(2) infinite; }
  @keyframes nudge { 50% { transform: translateX(3px); } }
  .track { position: relative; height: 22px; margin: 4px 2px 12px;
           border-bottom: 2px dashed #4a3c5e; }
  .packet { position: absolute; top: 2px; left: 0; width: 14px; height: 14px;
            background: var(--lime); border: 2px solid var(--ink);
            animation: travel 4s steps(24) infinite; }
  @keyframes travel {
    0% { left: 0%; background: var(--violet); } 50% { background: var(--sky); }
    92% { left: calc(100% - 16px); background: var(--lime); opacity: 1; }
    100% { left: calc(100% - 16px); opacity: 0; } }
  /* 게이트 시퀀스 */
  .gates { display: flex; flex-direction: column; gap: 8px; margin-top: 12px; }
  .gate { display: flex; align-items: center; gap: 12px;
          background: var(--panel2); border: 2px solid #4a3c5e; padding: 8px 12px; }
  .gate .n { width: 26px; height: 26px; flex-shrink: 0; display: grid; place-items: center;
             background: var(--ink); color: #1a1423; font-weight: bold; font-size: 13px;
             border: 2px solid #000; }
  .gate .desc { font-size: 11.5px; flex: 1; }
  .gate .out { font-size: 10.5px; white-space: nowrap; }
  .skip { color: var(--coral); } .queue { color: var(--sky); } .send { color: var(--lime); }
  /* HUD 테이블 + 게이지 */
  table { width: 100%; border-collapse: collapse; margin-top: 10px; font-size: 11.5px; }
  th, td { border: 2px solid #4a3c5e; padding: 6px 10px; text-align: left; }
  th { background: #000; color: var(--gold); font-size: 11px; }
  td b { color: var(--lime); }
  .bar { display: inline-flex; gap: 2px; vertical-align: middle; }
  .bar i { width: 9px; height: 9px; background: var(--lime); border: 1px solid #000; }
  .bar i.off { background: #3a3048; }
  /* 상태머신 */
  .fsm { display: flex; align-items: center; justify-content: center;
         gap: 14px; flex-wrap: wrap; margin: 16px 0 6px; }
  .state { border: 3px solid var(--ink); padding: 8px 16px; font-size: 12px;
           background: var(--panel2); box-shadow: 3px 3px 0 #000; }
  /* 카드 그리드 */
  .srcgrid { display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr));
             gap: 10px; margin-top: 10px; }
  .src { border: 2px solid #4a3c5e; background: var(--panel2);
         padding: 8px 10px; font-size: 11px; }
  .src b { color: var(--gold); font-size: 11.5px; }
  .src .cat { float: right; font-size: 10px; padding: 0 6px; border: 1px solid; }
  ul { list-style: none; margin-top: 8px; }
  li::before { content: "■ "; color: var(--coral); font-size: 9px; vertical-align: 2px; }
  li { margin-bottom: 5px; }
  footer { text-align: center; color: var(--sub); font-size: 10.5px; margin-top: 40px; }
  @media (prefers-reduced-motion: reduce) { * { animation: none !important; } }
</style>
</head>
<body>
<div class="wrap">
  <h1>♥ {프로젝트} {리포트명} ♥</h1>
  <p class="subtitle">{한 줄 부제} — {YYYY.MM.DD}<span class="blink">_</span></p>

  <section class="panel" data-tag="STAGE 1 · 전체 구조">
    <h2>{핵심 메시지 한 문장}</h2>
    <!-- 컨베이어 / 카드 그리드 / 게이트 등 상황에 맞게 -->
  </section>
  <!-- STAGE 2..N -->

  <footer>♥ INSERT COIN TO CONTINUE ♥<br>{프로젝트} · {근거 문서 경로} 기반</footer>
</div>
</body>
</html>
```

## 위험 신호

| 위험 신호 | 현실 |
|---------|------|
| "간단한 결과니 HTML은 생략" | 보고형 스킬의 필수 산출물이다. 규모가 작으면 패널 수를 줄여라 |
| "채팅 요약 대신 HTML만" | 채팅 요약은 유지. HTML은 병행 브리핑이다 |
| "스타일을 새로 창작" | 이 스켈레톤이 기준. 컬러 토큰·패널·스캔라인을 유지하라 |
| "open 실패했지만 넘어가자" | xdg-open → http.server 순으로 폴백해 반드시 띄워라 |
