#!/usr/bin/env python3
"""aeo-crawler-parse.py — 액세스 로그 stdin을 읽어 AI 크롤러 히트를 집계한다.

자체 AEO 점수는 선행 지표일 뿐이고, 실제 크롤러 히트와 크롤 성공률이
훨씬 강한 증거다. 그래서 점수 파이프라인과 별도로 이 집계를 유지한다.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone

COMBINED = re.compile(
    r'^(?P<ip>\S+)\s+\S+\s+\S+\s+\[(?P<time>[^\]]*)\]\s+'
    r'"(?P<method>\S+)\s+(?P<path>\S+)[^"]*"\s+(?P<status>\d{3})\s+(?P<bytes>\S+)'
    r'\s+"(?P<referer>[^"]*)"\s+"(?P<ua>[^"]*)"'
)


def load_catalog() -> tuple:
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "aeo-bots.json")
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    return data["bots"], data.get("referrers", [])


def parse_line(line: str, fmt: str, ua_field: str) -> dict | None:
    if fmt == "json":
        try:
            row = json.loads(line)
        except ValueError:
            return None
        return {"ua": str(row.get(ua_field, "")),
                "path": str(row.get("request_uri") or row.get("path") or ""),
                "status": str(row.get("status", "")),
                "referer": str(row.get("http_referer") or row.get("referer") or "")}
    match = COMBINED.match(line)
    if not match:
        return None
    return {"ua": match.group("ua"), "path": match.group("path"),
            "status": match.group("status"), "referer": match.group("referer")}


def status_class(status: str) -> str:
    if not status[:1].isdigit():
        return "other"
    head = status[0]
    return {"2": "2xx", "3": "3xx", "4": "4xx", "5": "5xx"}.get(head, "other")


def aggregate(stream, fmt: str, ua_field: str, bots: list, referrers: list) -> dict:
    hits = defaultdict(lambda: {"total": 0, "2xx": 0, "3xx": 0, "4xx": 0,
                                "5xx": 0, "other": 0})
    paths = defaultdict(Counter)
    ai_referrals = Counter()
    parsed = matched = 0
    lowered = [(b["token"].lower(), b) for b in bots]
    for line in stream:
        row = parse_line(line.rstrip("\n"), fmt, ua_field)
        if row is None:
            continue
        parsed += 1
        referer = row["referer"].lower()
        for host in referrers:
            if host in referer:
                ai_referrals[host] += 1
        ua = row["ua"].lower()
        for token, bot in lowered:
            if token in ua:
                matched += 1
                bucket = hits[bot["token"]]
                bucket["total"] += 1
                bucket[status_class(row["status"])] += 1
                paths[bot["token"]][row["path"]] += 1
                break
    return {"hits": dict(hits), "paths": paths, "parsed": parsed, "matched": matched,
            "aiReferrals": dict(ai_referrals)}


def summarize(agg: dict, bots: list, top: int) -> dict:
    by_kind = defaultdict(lambda: {"total": 0, "2xx": 0, "blocked": 0})
    rows = []
    for bot in bots:
        stats = agg["hits"].get(bot["token"])
        if not stats:
            continue
        blocked = stats["4xx"] + stats["5xx"]
        kind = by_kind[bot["kind"]]
        kind["total"] += stats["total"]
        kind["2xx"] += stats["2xx"]
        kind["blocked"] += blocked
        rows.append({
            "token": bot["token"], "kind": bot["kind"], "name": bot["name"],
            "total": stats["total"], "ok": stats["2xx"], "blocked": blocked,
            "successRate": round(stats["2xx"] / stats["total"], 3) if stats["total"] else 0,
            "topPaths": [{"path": p, "count": c}
                         for p, c in agg["paths"][bot["token"]].most_common(5)],
        })
    rows.sort(key=lambda r: -r["total"])
    warnings = []
    citing = by_kind["search"]["total"] + by_kind["user"]["total"]
    if citing == 0:
        warnings.append("인용 경로 크롤러(search·user) 히트가 0건 — "
                        "차단 중이거나 아직 발견되지 않았다. L1을 먼저 검증하라.")
    for row in rows:
        if row["kind"] in ("search", "user") and row["successRate"] < 0.8:
            warnings.append(f"{row['token']} 크롤 성공률 {row['successRate']} — "
                            "WAF·레이트리밋 확인 필요")
    return {"bots": rows[:top], "byKind": dict(by_kind), "warnings": warnings}


def main() -> int:
    parser = argparse.ArgumentParser(description="AI 크롤러 로그 집계기")
    parser.add_argument("--format", default="combined", choices=("combined", "json"))
    parser.add_argument("--ua-field", default="http_user_agent")
    parser.add_argument("--top", type=int, default=15)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    bots, referrers = load_catalog()
    agg = aggregate(sys.stdin, args.format, args.ua_field, bots, referrers)
    payload = {"kind": "aeo-crawlers",
               "aggregatedAt": datetime.now(timezone.utc).isoformat(),
               "linesParsed": agg["parsed"], "botHits": agg["matched"],
               "aiReferrals": agg["aiReferrals"]}
    payload.update(summarize(agg, bots, args.top))
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
    print(f"[aeo] 로그 {agg['parsed']}줄 파싱, AI 크롤러 히트 {agg['matched']}건, "
          f"경고 {len(payload['warnings'])}건 → {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
