#!/usr/bin/env python3
"""aeo-content-assess.py — 로컬 코드 신호 + 샘플 페이지를 판정해 content.json을 만든다.

원격 홈 1페이지만 보는 aeo-assess.py의 L3·L4 판정을 여러 페이지 평균으로 교정한다.
이 결과가 있으면 aeo-score.py가 해당 체크를 이 값으로 덮어쓴다.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import aeo_html  # noqa: E402

PASS, PARTIAL, FAIL, NEUTRAL = "pass", "partial", "fail", "neutral"
CORE_TYPES = {"Article", "BlogPosting", "NewsArticle", "TechArticle",
              "MedicalWebPage", "Product", "FAQPage", "HowTo"}


def result(score, status, message, **evidence):
    return {"score": round(max(0.0, min(1.0, score)), 3), "status": status,
            "message": message, "evidence": evidence}


def load_codebase(raw_dir: str) -> dict:
    signals = {}
    path = os.path.join(raw_dir, "codebase.tsv")
    if not os.path.exists(path):
        return signals
    for line in open(path, encoding="utf-8", errors="replace"):
        key, _, value = line.rstrip("\n").partition("\t")
        signals[key] = value
    return signals


def load_samples(raw_dir: str) -> list:
    pages = []
    meta_path = os.path.join(raw_dir, "meta.tsv")
    if not os.path.exists(meta_path):
        return pages
    for line in open(meta_path, encoding="utf-8", errors="replace"):
        cols = line.rstrip("\n").split("\t")
        if len(cols) < 5:
            continue
        body_path = os.path.join(raw_dir, cols[0] + ".body")
        if not os.path.exists(body_path):
            continue
        with open(body_path, encoding="utf-8", errors="replace") as handle:
            html = handle.read()
        pages.append({"key": cols[0], "status": cols[1], "url": cols[4], "html": html})
    return pages


def analyze_page(html: str) -> dict:
    nodes = aeo_html.extract_jsonld(html)
    meta = aeo_html.extract_meta(html)
    headings = aeo_html.extract_headings(html)
    stats = aeo_html.text_stats(html)
    entity, entity_ev = aeo_html.entity_score(nodes, meta)
    chunk, chunk_ev = aeo_html.chunk_score(html, headings, meta)
    types = set(aeo_html.jsonld_types(nodes))
    return {
        "chars": stats["chars"], "shellOnly": stats["shellOnly"],
        "jsonLdBlocks": len(nodes), "types": sorted(types),
        "hasCoreType": bool(types & CORE_TYPES),
        "answerBlocks": aeo_html.answer_block_ratio(html),
        "chunk": chunk, "chunkEvidence": chunk_ev,
        "entity": entity, "entityEvidence": entity_ev,
        "hasTitle": bool(meta["title"]), "hasDescription": bool(meta["description"]),
        "hasCanonical": bool(meta["canonical"]), "hasOg": bool(meta["ogTitle"]),
        "semantic": meta["articleTags"] + meta["mainTags"] > 0,
    }


def _mean(values: list) -> float:
    return round(sum(values) / len(values), 3) if values else 0.0


def build_page_checks(pages: list) -> dict:
    if not pages:
        return {}
    stats = [analyze_page(p["html"]) for p in pages]
    thin = [s for s in stats if s["chars"] < 400 or s["shellOnly"]]
    no_ld = [s for s in stats if s["jsonLdBlocks"] == 0]
    core = _mean([1.0 if s["hasCoreType"] else 0.0 for s in stats])
    answer = _mean([s["answerBlocks"] for s in stats])
    chunk = _mean([s["chunk"] for s in stats])
    entity = _mean([s["entity"] for s in stats])
    meta_score = _mean([
        sum([s["hasTitle"], s["hasDescription"], s["hasCanonical"],
             s["hasOg"], s["semantic"]]) / 5.0 for s in stats])
    render = 1.0 - (len(thin) / len(stats))
    return {
        "serverRendering": result(
            render, PASS if render >= 0.9 else (PARTIAL if render >= 0.5 else FAIL),
            f"샘플 {len(stats)}쪽 중 본문 부족·JS셸 {len(thin)}쪽"
            + (" — CSR 렌더링 갭" if thin else ""),
            sampled=len(stats), thin=len(thin),
            meanChars=int(_mean([s["chars"] for s in stats]))),
        "structuredData": result(
            core, PASS if core >= 0.8 else (PARTIAL if core > 0 else FAIL),
            f"샘플 중 핵심 스키마 보유 비율 {core} (JSON-LD 없는 쪽 {len(no_ld)}개)",
            missingJsonLd=len(no_ld),
            types=sorted({t for s in stats for t in s["types"]})[:12]),
        "answerBlocks": result(
            answer, PASS if answer >= 0.6 else (PARTIAL if answer > 0 else FAIL),
            f"H2 직후 직답 블록 비율 평균 {answer}"),
        "chunkability": result(
            chunk, PASS if chunk >= 0.7 else (PARTIAL if chunk > 0 else FAIL),
            f"청크 자기완결성 점수 평균 {chunk}"),
        "entityAuthority": result(
            entity, PASS if entity >= 0.6 else (PARTIAL if entity > 0 else FAIL),
            f"엔티티·권위 신호 평균 {entity}"),
        "metaFoundation": result(
            meta_score, PASS if meta_score >= 0.9 else (PARTIAL if meta_score > 0 else FAIL),
            f"메타 기반 충족률 평균 {meta_score}"),
    }


def build_code_findings(signals: dict) -> list:
    findings = []
    framework = signals.get("framework", "")
    client = int(signals.get("clientComponents", "0") or 0)
    json_ld = int(signals.get("jsonLdSources", "0") or 0)
    ssr_off = int(signals.get("ssrDisabled", "0") or 0)
    if ssr_off:
        findings.append({
            "severity": "high", "key": "ssrDisabled",
            "message": f"SSR을 끈 동적 임포트가 {ssr_off}개 파일에 있음 — "
                       "해당 콘텐츠는 AI 크롤러에 보이지 않는다"})
    if client and not json_ld:
        findings.append({
            "severity": "high", "key": "jsonLdMissing",
            "message": f"클라이언트 컴포넌트 {client}개 대비 JSON-LD 소스 0개 — "
                       "구조화 데이터 자체가 없음"})
    if not int(signals.get("robotsSources", "0") or 0):
        findings.append({"severity": "medium", "key": "robotsSource",
                         "message": "robots 생성 소스를 찾지 못함 — 배포본만 존재하는지 확인"})
    if not int(signals.get("sitemapSources", "0") or 0):
        findings.append({"severity": "medium", "key": "sitemapSource",
                         "message": "sitemap 생성 소스를 찾지 못함"})
    if not int(signals.get("llmsSources", "0") or 0):
        findings.append({"severity": "low", "key": "llmsSource",
                         "message": "llms.txt 생성 소스 없음 (선택 항목)"})
    if not int(signals.get("metadataExports", "0") or 0):
        findings.append({"severity": "high", "key": "metadataExports",
                         "message": "페이지 메타데이터 생성 코드를 찾지 못함 — "
                                    "title·description이 정적일 가능성"})
    findings.append({"severity": "info", "key": "framework",
                     "message": f"감지된 프레임워크/런타임: {framework or '미확인'}"})
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="AEO 콘텐츠 레이어 판정기")
    parser.add_argument("--raw", required=True)
    parser.add_argument("--repo", default=".")
    parser.add_argument("--out", required=True)
    parser.add_argument("--render-gap", action="store_true")
    args = parser.parse_args()

    signals = load_codebase(args.raw)
    pages = load_samples(args.raw)
    checks = build_page_checks(pages)
    payload = {
        "kind": "aeo-content",
        "repo": os.path.abspath(args.repo),
        "auditedAt": datetime.now(timezone.utc).isoformat(),
        "codebase": signals,
        "findings": build_code_findings(signals),
        "sampledUrls": [p["url"] for p in pages],
        "checks": checks,
    }
    if args.render_gap and pages:
        payload["renderGap"] = {
            "note": "raw HTML 기준 수치. Playwright MCP로 렌더 후 본문 길이를 재어 "
                    "raw/rendered 비율을 계산하라. 0.3 미만이면 심각한 갭.",
            "pages": [{"url": p["url"],
                       "rawChars": aeo_html.text_stats(p["html"])["chars"]}
                      for p in pages],
        }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
    print(f"[aeo] 콘텐츠 감사 완료: 샘플 {len(pages)}쪽, "
          f"코드 findings {len(payload['findings'])}건 → {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
