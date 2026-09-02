#!/usr/bin/env python3
"""aeo-dashboard.py — score.json을 8-bit 로컬 대시보드 HTML로 렌더한다.

references/common/REPORT_8BIT.md 규격을 따른다: 단일 파일 · 외부 의존성은
Galmuri 폰트 CDN 하나 · JS 없이 CSS만 · 스캔라인 · STAGE 패널 구조.
"""

from __future__ import annotations

import argparse
import glob
import html
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone

LAYER_LABELS = {
    "L1": ("ACCESS", "크롤러가 들어올 수 있는가"),
    "L2": ("RENDER", "본문이 JS 없이 보이는가"),
    "L3": ("REPRESENT", "읽기 좋은 형태로 주는가"),
    "L4": ("MEANING", "의미·신뢰를 기계가 읽는가"),
    "L5": ("ACT", "에이전트가 행동할 수 있는가"),
}

STATUS_COLOR = {
    "pass": "var(--lime)", "partial": "var(--gold)", "fail": "var(--coral)",
    "neutral": "var(--sub)", "unableToCheck": "var(--sky)", "na": "var(--sub)",
}
STATUS_LABEL = {
    "pass": "PASS", "partial": "PART", "fail": "FAIL",
    "neutral": "N/D", "unableToCheck": "N/C", "na": "N/A",
}

CSS = """
:root{--bg:#1a1423;--panel:#241b2f;--panel2:#2d2240;--ink:#f3ead9;--sub:#9c8aa5;
--grid:#2a2136;--lime:#9dde6a;--gold:#ffd75e;--coral:#ff7e67;--sky:#6ecbff;--violet:#b98aff;}
*{box-sizing:border-box;margin:0;padding:0;}
html{background:var(--bg);}
body{font-family:"Galmuri11","Galmuri9",monospace;color:var(--ink);
background:linear-gradient(var(--grid) 1px,transparent 1px),
linear-gradient(90deg,var(--grid) 1px,transparent 1px);
background-size:24px 24px;background-color:var(--bg);
padding:32px 16px 80px;line-height:1.7;image-rendering:pixelated;}
.wrap{max-width:980px;margin:0 auto;}
body::after{content:"";position:fixed;inset:0;pointer-events:none;z-index:99;
background:repeating-linear-gradient(0deg,rgba(0,0,0,.12) 0 1px,transparent 1px 3px);}
.panel{background:var(--panel);border:3px solid var(--ink);box-shadow:6px 6px 0 #000;
padding:22px 20px;margin-bottom:34px;position:relative;}
.panel::before{content:attr(data-tag);position:absolute;top:-14px;left:14px;
background:var(--gold);color:#1a1423;font-size:11px;font-weight:bold;
padding:2px 10px;border:3px solid var(--ink);}
h1{font-size:26px;text-align:center;margin-bottom:6px;color:var(--gold);text-shadow:3px 3px 0 #000;}
.subtitle{text-align:center;color:var(--sub);font-size:12px;margin-bottom:30px;}
.blink{animation:blink 1.1s steps(2) infinite;}
@keyframes blink{50%{opacity:0;}}
h2{font-size:15px;color:var(--sky);margin:14px 0 10px;}
h2::before{content:"\\25B8 ";color:var(--coral);}
p,li{font-size:12.5px;}
.dim{color:var(--sub);}
code{font-family:inherit;background:#000;color:var(--lime);padding:1px 6px;
border:1px solid #444;font-size:11.5px;}
.score{display:flex;gap:18px;flex-wrap:wrap;justify-content:center;margin-bottom:26px;}
.scorebox{background:var(--panel);border:3px solid var(--ink);box-shadow:5px 5px 0 #000;
padding:14px 20px;text-align:center;min-width:172px;}
.scorebox .num{font-size:34px;color:var(--gold);text-shadow:2px 2px 0 #000;display:block;}
.scorebox .lab{font-size:10.5px;color:var(--sub);}
.scorebox .sub{font-size:11px;color:var(--ink);}
.delta-up{color:var(--lime);} .delta-down{color:var(--coral);}
.conveyor{display:flex;align-items:stretch;justify-content:space-between;gap:6px;
margin:18px 0 8px;flex-wrap:wrap;}
.station{flex:1;min-width:150px;text-align:center;background:var(--panel2);
border:3px solid var(--ink);padding:10px 6px;font-size:11px;}
.station b{display:block;font-size:12px;margin-bottom:3px;}
.station small{color:var(--sub);font-size:10px;display:block;}
.station.blocked{border-color:var(--coral);background:#3a1f28;}
.track{position:relative;height:22px;margin:4px 2px 12px;border-bottom:2px dashed #4a3c5e;}
.packet{position:absolute;top:2px;left:0;width:14px;height:14px;background:var(--lime);
border:2px solid var(--ink);animation:travel 4s steps(24) infinite;}
@keyframes travel{0%{left:0%;background:var(--violet);}50%{background:var(--sky);}
92%{left:calc(100% - 16px);background:var(--lime);opacity:1;}
100%{left:calc(100% - 16px);opacity:0;}}
.gates{display:flex;flex-direction:column;gap:8px;margin-top:12px;}
.gate{display:flex;align-items:center;gap:12px;background:var(--panel2);
border:2px solid #4a3c5e;padding:8px 12px;}
.gate .n{width:26px;height:26px;flex-shrink:0;display:grid;place-items:center;
background:var(--ink);color:#1a1423;font-weight:bold;font-size:13px;border:2px solid #000;}
.gate .desc{font-size:11.5px;flex:1;}
.gate .out{font-size:10.5px;white-space:nowrap;}
table{width:100%;border-collapse:collapse;margin-top:10px;font-size:11.5px;}
th,td{border:2px solid #4a3c5e;padding:6px 10px;text-align:left;vertical-align:top;}
th{background:#000;color:var(--gold);font-size:11px;}
td b{color:var(--lime);}
.bar{display:inline-flex;gap:2px;vertical-align:middle;}
.bar i{width:9px;height:9px;background:var(--lime);border:1px solid #000;}
.bar i.off{background:#3a3048;}
.bar i.warn{background:var(--gold);} .bar i.bad{background:var(--coral);}
.srcgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(215px,1fr));
gap:10px;margin-top:10px;}
.src{border:2px solid #4a3c5e;background:var(--panel2);padding:8px 10px;font-size:11px;}
.src.na{opacity:.42;}
.src b{color:var(--gold);font-size:11.5px;}
.src .cat{float:right;font-size:10px;padding:0 6px;border:1px solid;}
.src .msg{display:block;color:var(--sub);font-size:10px;margin-top:4px;line-height:1.45;}
ul{list-style:none;margin-top:8px;}
li::before{content:"\\25A0 ";color:var(--coral);font-size:9px;vertical-align:2px;}
li{margin-bottom:5px;}
.legend{font-size:10.5px;color:var(--sub);margin-top:10px;}
.spark{border:2px solid #4a3c5e;background:#000;margin-top:12px;}
footer{text-align:center;color:var(--sub);font-size:10.5px;margin-top:40px;}
@media (prefers-reduced-motion:reduce){*{animation:none!important;}}
"""


def esc(value) -> str:
    return html.escape(str(value), quote=True)


def bar(score: float, cells: int = 12) -> str:
    filled = int(round(max(0.0, min(1.0, score)) * cells))
    tone = "" if score >= 0.85 else (" warn" if score >= 0.5 else " bad")
    body = "".join(f'<i class="{("off" if i >= filled else tone.strip())}"></i>'
                   for i in range(cells))
    return f'<span class="bar">{body}</span>'


def layer_rows(data: dict) -> list:
    buckets = {key: [] for key in LAYER_LABELS}
    for row in data["rows"]:
        if row["axis"] == "aeo":
            buckets[row["layer"]].append(row)
        elif row["applicable"]:
            buckets["L5"].append(row)
    out = []
    for key, (name, note) in LAYER_LABELS.items():
        rows = buckets[key]
        total = sum(r["weight"] for r in rows)
        got = sum(r["score"] * r["weight"] for r in rows)
        score = round(got / total, 3) if total else None
        out.append({"key": key, "name": name, "note": note, "score": score,
                    "count": len(rows),
                    "fails": sum(1 for r in rows if r["status"] == "fail")})
    return out


def render_header(data: dict, history: list) -> str:
    delta = ""
    if history:
        diff = round(data["overall"] - history[-1]["overall"], 1)
        cls = "delta-up" if diff >= 0 else "delta-down"
        delta = f'<span class="{cls}">{"+" if diff >= 0 else ""}{diff}</span> vs 직전'
    boxes = [
        ("종합 점수", f'{data["overall"]}', delta or f'프로파일 {data["profile"]}'),
        ("AEO 축 (인용)", f'{data["aeo"]}',
         f'등급 {data["grade"]} · 가중 {data["weights"]["aeo"]}'),
        ("Agent 축 (실행)", f'{data["agent"]}',
         f'Lv{data["agentLevel"]} {data["agentLevelName"]}'),
    ]
    cards = "".join(
        f'<div class="scorebox"><span class="lab">{esc(lab)}</span>'
        f'<span class="num">{esc(num)}</span>'
        f'<span class="sub">{sub}</span></div>' for lab, num, sub in boxes)
    return f'<div class="score">{cards}</div>'


def render_layers(data: dict) -> str:
    stations = []
    for layer in layer_rows(data):
        if layer["score"] is None:
            value, cls = '<small class="dim">해당 없음</small>', ""
        else:
            cls = " blocked" if layer["score"] < 0.5 else ""
            value = bar(layer["score"]) + f'<small>{int(layer["score"] * 100)}점 · ' \
                                          f'체크 {layer["count"]}개</small>'
        stations.append(
            f'<div class="station{cls}"><b>{layer["key"]} {layer["name"]}</b>'
            f'<small>{esc(layer["note"])}</small>{value}</div>')
    gates = data["gates"]
    warn = ""
    if gates["upperCap"] < 1.0:
        warn = ('<p class="dim">L1이 무너져 상위 레이어 획득 점수에 ×0.5 캡이 걸렸다. '
                '크롤러가 못 들어오면 스키마도 마크다운도 읽히지 않는다.</p>')
    elif gates["l4Cap"] < 1.0:
        warn = ('<p class="dim">L2 렌더링 갭으로 L4 획득 점수에 ×0.6 캡이 걸렸다. '
                'AI 크롤러는 JS를 실행하지 않으므로 CSR 페이지의 JSON-LD는 도달하지 않는다.</p>')
    return (f'<div class="conveyor">{"".join(stations)}</div>'
            '<div class="track"><div class="packet"></div></div>' + warn)


def render_axes(data: dict) -> str:
    aeo_rows = [r for r in data["rows"] if r["axis"] == "aeo"]
    agent_rows = [r for r in data["rows"] if r["axis"] == "agent"]
    on = [r for r in agent_rows if r["applicable"]]
    na = len(agent_rows) - len(on)
    rows = [
        ("AEO / GEO — AI 답변에 인용되는가", data["aeo"] / 100.0, data["aeo"],
         data["weights"]["aeo"], len(aeo_rows), 0),
        ("Agent-Readiness — 에이전트가 행동하는가", data["agent"] / 100.0,
         data["agent"], data["weights"]["agent"], len(on), na),
    ]
    body = "".join(
        f"<tr><td>{esc(name)}</td><td>{bar(ratio)} <b>{value}</b></td>"
        f"<td>{weight}</td><td>{count}개</td><td>{na_count}개</td></tr>"
        for name, ratio, value, weight, count, na_count in rows)
    return (
        "<table><tr><th>축</th><th>점수</th><th>가중치</th><th>적용 체크</th>"
        f"<th>N/A</th></tr>{body}</table>"
        f'<p class="legend">N/A는 프로파일 <code>{esc(data["profile"])}</code>에 '
        "무관해 <b>분모에서 제외</b>한 체크다. 감점하지 않는다 — 콘텐츠 사이트에 "
        "OAuth 디스커버리를 붙여도 AI 인용은 오르지 않기 때문이다.</p>")


def merge_rows(rows: list) -> list:
    """markdownNegotiation·llmsTxt는 두 축에 동시 기여한다 — 카드는 하나로 합친다."""
    merged = {}
    for row in rows:
        item = merged.get(row["key"])
        tag = row.get("layer") or f'agent:{row.get("group")}'
        if item is None:
            merged[row["key"]] = {**row, "tags": [tag],
                                  "applicable": row["applicable"]}
            continue
        item["tags"].append(tag)
        item["weight"] += row["weight"]
        item["applicable"] = item["applicable"] or row["applicable"]
        if row["applicable"] and item["status"] == "na":
            item["status"] = row["status"]
    return list(merged.values())


def render_checks(data: dict) -> str:
    cards = []
    rows = merge_rows(data["rows"])
    for row in sorted(rows, key=lambda r: (not r["applicable"], -r["weight"])):
        status = row["status"] if row["applicable"] else "na"
        color = STATUS_COLOR.get(status, "var(--sub)")
        cap = " · 캡적용" if row.get("capped") else ""
        cards.append(
            f'<div class="src{" na" if not row["applicable"] else ""}">'
            f'<span class="cat" style="color:{color};border-color:{color}">'
            f'{STATUS_LABEL.get(status, status)}</span>'
            f'<b>{esc(row["key"])}</b><br>'
            f'{bar(row["score"], 8)} <span class="dim">'
            f'{esc("+".join(row["tags"]))} · w{row["weight"]}{cap}</span>'
            f'<span class="msg">{esc(row["message"])[:170]}</span></div>')
    return f'<div class="srcgrid">{"".join(cards)}</div>'


def render_bots(data: dict) -> str:
    bots = data.get("bots") or []
    if not bots:
        return '<p class="dim">크롤러 정책 데이터 없음 (robots.txt 미수집)</p>'
    order = {"search": 0, "user": 1, "train": 2}
    rows = []
    for bot in sorted(bots, key=lambda b: (order.get(b.get("kind"), 9), b["token"])):
        blocked = bot.get("policy") == "disallow"
        citing = bot.get("kind") in ("search", "user")
        color = "var(--coral)" if (blocked and citing) else (
            "var(--sub)" if blocked else "var(--lime)")
        verdict = "차단" if blocked else "허용"
        note = "인용 경로 — 차단 시 AI 답변에서 사라짐" if citing else "학습 데이터 수집"
        rows.append(
            f'<tr><td>{esc(bot["token"])}</td><td>{esc(bot.get("kind"))}</td>'
            f'<td style="color:{color}"><b style="color:{color}">{verdict}</b></td>'
            f'<td>{"명시" if bot.get("explicit") else "와일드카드/기본"}</td>'
            f'<td class="dim">{esc(note)}</td></tr>')
    return ("<table><tr><th>User-Agent</th><th>유형</th><th>정책</th>"
            f"<th>선언 방식</th><th>비고</th></tr>{''.join(rows)}</table>")


def render_prescriptions(data: dict) -> str:
    blocks = []
    tone = {"NOW": "var(--coral)", "NEXT": "var(--gold)", "LATER": "var(--sub)"}
    for bucket in ("NOW", "NEXT", "LATER"):
        items = data["prescriptions"].get(bucket) or []
        if not items:
            continue
        gates = "".join(
            f'<div class="gate"><div class="n">{i + 1}</div>'
            f'<div class="desc"><b>{esc(item["title"])}</b><br>'
            f'<span class="dim">{esc(item["action"])}</span></div>'
            f'<div class="out" style="color:{tone[bucket]}">p={item["priority"]}<br>'
            f'<span class="dim">i{item["impact"]}/e{item["effort"]}/'
            f'c{item["confidence"]}</span></div></div>'
            for i, item in enumerate(items))
        blocks.append(f'<h2>{bucket} — {len(items)}건</h2><div class="gates">{gates}</div>')
    if not blocks:
        blocks.append("<p>처방 없음 — 적용 대상 체크가 모두 기준을 넘었다.</p>")
    blocks.append('<p class="legend">priority = impact × confidence ÷ effort. '
                  'confidence가 낮은 항목(llms.txt 등)은 효과 근거가 약하다는 뜻이며, '
                  '과대평가하지 않기 위해 의도적으로 낮게 잡았다.</p>')
    return "".join(blocks)


def render_trend(data: dict, history: list) -> str:
    points = history + [{"overall": data["overall"], "aeo": data["aeo"],
                         "agent": data["agent"], "label": "now"}]
    if len(points) < 2:
        return ('<p class="dim">스냅샷이 1개뿐이다. '
                '<code>--snapshot</code>으로 적재하면 추세가 그려진다.</p>')
    width, height = 900, 150
    step = width / max(1, len(points) - 1)

    def path_for(key):
        return " ".join(
            f'{i * step:.1f},{height - (p.get(key, 0) / 100.0) * (height - 20) - 10:.1f}'
            for i, p in enumerate(points))

    lines = "".join(
        f'<polyline fill="none" stroke="{color}" stroke-width="3" '
        f'points="{path_for(key)}"/>'
        for key, color in (("overall", "#ffd75e"), ("aeo", "#9dde6a"),
                           ("agent", "#6ecbff")))
    labels = " · ".join(f'{esc(p.get("label", "?"))}:{p["overall"]}' for p in points[-6:])
    return (f'<svg class="spark" viewBox="0 0 {width} {height}" width="100%" '
            f'height="{height}">{lines}</svg>'
            f'<p class="legend">노랑=종합 · 초록=AEO · 파랑=Agent &nbsp;|&nbsp; '
            f'최근 스냅샷: {labels}</p>')


def render_findings(data: dict) -> str:
    findings = data.get("codeFindings") or []
    crawlers = data.get("crawlers") or {}
    parts = []
    if findings:
        items = "".join(
            f'<li><b>[{esc(f.get("severity"))}]</b> {esc(f.get("message"))}</li>'
            for f in findings)
        parts.append(f"<h2>코드베이스 신호</h2><ul>{items}</ul>")
    if crawlers.get("bots"):
        rows = "".join(
            f'<tr><td>{esc(b["token"])}</td><td>{esc(b["kind"])}</td>'
            f'<td><b>{b["total"]}</b></td><td>{b["ok"]}</td><td>{b["blocked"]}</td>'
            f'<td>{bar(b["successRate"], 8)} {b["successRate"]}</td></tr>'
            for b in crawlers["bots"])
        parts.append("<h2>실측 크롤러 히트</h2><table><tr><th>봇</th><th>유형</th>"
                     "<th>요청</th><th>2xx</th><th>차단</th><th>성공률</th></tr>"
                     f"{rows}</table>")
    for warning in crawlers.get("warnings", []):
        parts.append(f'<p style="color:var(--coral)">! {esc(warning)}</p>')
    if not parts:
        parts.append('<p class="dim">코드 감사·크롤러 로그 데이터가 없다. '
                     '<code>aeo-content-audit.sh</code>와 <code>aeo-crawler-log.sh</code>를 '
                     '함께 돌리면 이 패널이 채워진다.</p>')
    return "".join(parts)


def panel(tag: str, heading: str, body: str) -> str:
    return (f'<section class="panel" data-tag="{esc(tag)}">'
            f'<h2>{esc(heading)}</h2>{body}</section>')


def build_html(data: dict, history: list) -> str:
    stamp = data.get("scoredAt", "")[:16].replace("T", " ")
    target = data.get("target") or data.get("host") or "(대상 미지정)"
    stages = [
        panel("STAGE 1 · 5레이어 스택",
              "크롤러가 들어와서(L1) 본문을 보고(L2) 읽고(L3) 이해하고(L4) 행동한다(L5)",
              render_layers(data)),
        panel("STAGE 2 · 두 축 분리",
              "AEO(인용)와 Agent-Readiness(실행)는 목표가 다르다 — 따로 채점한다",
              render_axes(data)),
        panel("STAGE 3 · 체크 도감", "체크별 획득 점수와 근거", render_checks(data)),
        panel("STAGE 4 · 크롤러 접근 매트릭스",
              "학습 봇은 막아도 검색 봇을 막으면 AI 답변에서 사라진다",
              render_bots(data)),
        panel("STAGE 5 · ROI 처방 큐", "무엇을 먼저 할 것인가", render_prescriptions(data)),
        panel("STAGE 6 · 추세", "점수는 선행 지표다 — 크롤러 히트와 함께 본다",
              render_trend(data, history)),
        panel("STAGE 7 · 실측 근거", "코드 신호와 실제 크롤러 히트", render_findings(data)),
    ]
    return f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AEO 대시보드 — {esc(target)}</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/galmuri@latest/dist/galmuri.css">
<style>{CSS}</style>
</head>
<body>
<div class="wrap">
  <h1>&#9829; AEO CONTROL PANEL &#9829;</h1>
  <p class="subtitle">{esc(target)} — {esc(stamp)}<span class="blink">_</span></p>
  {render_header(data, history)}
  {''.join(stages)}
  <footer>&#9829; INSERT COIN TO CONTINUE &#9829;<br>
  프로파일 {esc(data['profile'])} · 근거: {esc(data.get('sources', {}).get('scan', ''))}<br>
  점수 모델: skills/aeo/references/scoring-model.md (wj-magic 자체 모델 — 외부 스캐너 점수와 다를 수 있음)
  </footer>
</div>
</body>
</html>
"""


def load_history(path: str, limit: int = 12) -> list:
    if not path or not os.path.isdir(path):
        return []
    out = []
    for file_path in sorted(glob.glob(os.path.join(path, "*.json")))[-limit:]:
        try:
            with open(file_path, encoding="utf-8") as handle:
                snap = json.load(handle)
        except (ValueError, OSError):
            continue
        out.append({"overall": snap.get("overall", 0), "aeo": snap.get("aeo", 0),
                    "agent": snap.get("agent", 0),
                    "label": os.path.basename(file_path)[:11].rstrip(".json")})
    return out


def save_snapshot(data: dict, history_dir: str) -> str:
    os.makedirs(history_dir, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M")
    target = os.path.join(history_dir, f"{stamp}.json")
    with open(target, "w", encoding="utf-8") as handle:
        json.dump({"overall": data["overall"], "aeo": data["aeo"],
                   "agent": data["agent"], "profile": data["profile"],
                   "scoredAt": data.get("scoredAt", "")}, handle, ensure_ascii=False)
    return target


def open_in_browser(path: str) -> None:
    opener = "open" if sys.platform == "darwin" else "xdg-open"
    if not shutil.which(opener):
        print(f"[aeo] 브라우저 실행기 없음. 수동으로 여세요: {path}", file=sys.stderr)
        return
    try:
        subprocess.run([opener, path], check=True)
    except (subprocess.CalledProcessError, OSError) as error:
        print(f"[aeo] 브라우저 열기 실패({error}) — "
              f"python3 -m http.server 8907 로 대신 확인하세요", file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser(description="AEO 8-bit 로컬 대시보드 생성기")
    parser.add_argument("--score", required=True)
    parser.add_argument("--history", default="")
    parser.add_argument("--out", default="docs/reports/aeo-dashboard.html")
    parser.add_argument("--snapshot", action="store_true")
    parser.add_argument("--open", dest="do_open", action="store_true")
    args = parser.parse_args()

    with open(args.score, encoding="utf-8") as handle:
        data = json.load(handle)
    history = load_history(args.history)
    if args.snapshot and args.history:
        save_snapshot(data, args.history)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        handle.write(build_html(data, history))
    print(f"[aeo] 대시보드 생성 → {args.out}")
    if args.do_open:
        open_in_browser(os.path.abspath(args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
