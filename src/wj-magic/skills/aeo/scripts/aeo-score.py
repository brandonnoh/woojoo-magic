#!/usr/bin/env python3
"""aeo-score.py — 스캔·콘텐츠 감사 결과를 병합해 프로파일 가중 점수를 산출한다.

`references/scoring-model.md`의 구현체다. 문서와 어긋나면 문서가 기준이며
이 파일을 고친다.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone

# ── 모델 정의 (scoring-model.md와 1:1) ────────────────────────────
AEO_CHECKS = {
    "aiCrawlerAccess": ("L1", 18), "crawlerHttpAccess": ("L1", 8),
    "serverRendering": ("L2", 18), "httpHygiene": ("L2", 6),
    "markdownNegotiation": ("L3", 8), "llmsTxt": ("L3", 5),
    "chunkability": ("L3", 9),
    "structuredData": ("L4", 15), "answerBlocks": ("L4", 12),
    "entityAuthority": ("L4", 10), "freshness": ("L4", 8),
    "metaFoundation": ("L4", 10),
}

AGENT_CHECKS = {
    "robotsTxt": ("discoverability", 6), "sitemap": ("discoverability", 6),
    "linkHeaders": ("discoverability", 6), "dnsAid": ("discoverability", 3),
    "markdownNegotiation": ("contentAccessibility", 10),
    "llmsTxt": ("contentAccessibility", 4),
    "llmsFullTxt": ("contentAccessibility", 2),
    "robotsTxtAiRules": ("botAccessControl", 8),
    "contentSignals": ("botAccessControl", 6),
    "webBotAuth": ("botAccessControl", 4),
    "mcpServerCard": ("discovery", 10), "apiCatalog": ("discovery", 8),
    "a2aAgentCard": ("discovery", 6), "agentSkills": ("discovery", 6),
    "oauthDiscovery": ("discovery", 5), "oauthProtectedResource": ("discovery", 5),
    "ard": ("discovery", 4), "webMcp": ("discovery", 4), "authMd": ("discovery", 3),
    "x402": ("commerce", 5), "ucp": ("commerce", 4), "acp": ("commerce", 4),
    "mpp": ("commerce", 3), "ap2": ("commerce", 2),
}

PROFILE_WEIGHTS = {
    "content": (0.85, 0.15), "docs": (0.70, 0.30), "saas-api": (0.45, 0.55),
    "commerce": (0.50, 0.50), "hybrid": (0.60, 0.40),
}

_CONTENT_AGENT_SET = {
    "robotsTxt", "sitemap", "linkHeaders", "markdownNegotiation", "llmsTxt",
    "llmsFullTxt", "robotsTxtAiRules", "contentSignals",
}
AGENT_APPLICABLE = {
    "content": _CONTENT_AGENT_SET,
    "docs": _CONTENT_AGENT_SET | {"agentSkills", "mcpServerCard", "apiCatalog"},
    "hybrid": _CONTENT_AGENT_SET | {"mcpServerCard", "apiCatalog", "agentSkills"},
    "saas-api": {k for k, (g, _) in AGENT_CHECKS.items() if g != "commerce"},
    "commerce": set(AGENT_CHECKS),
}

# 처방 카탈로그 — impact(1~5) · effort(1~5) · confidence(0.3~1.0)
# confidence는 "효과에 대한 근거 강도". 논쟁적 항목을 낮게 잡아 과대평가를 막는다.
PRESCRIPTIONS = {
    "aiCrawlerAccess": (5, 1, 1.0, "검색계 AI 크롤러 차단 해제",
                        "robots.txt에서 OAI-SearchBot·PerplexityBot·Claude-SearchBot을 허용한다. 학습 봇과 분리해 정책을 세운다."),
    "crawlerHttpAccess": (5, 2, 1.0, "WAF·봇 규칙에서 AI 크롤러 예외 처리",
                          "AI UA 요청이 403/429/챌린지를 받고 있다. 봇 매니지먼트·레이트리밋에 예외를 추가한다."),
    "serverRendering": (5, 4, 1.0, "본문·JSON-LD 서버 렌더 전환",
                        "AI 크롤러는 JS를 실행하지 않는다. 본문과 구조화 데이터를 SSR/SSG로 옮긴다."),
    "httpHygiene": (3, 1, 0.9, "상태코드·canonical·noindex 정리",
                    "200 응답, 자기참조 canonical, noindex 제거를 확인한다."),
    "structuredData": (4, 2, 0.9, "JSON-LD 스키마 도입·보강",
                       "Article/Organization/Person/WebSite를 @graph로 묶어 서버 렌더한다."),
    "answerBlocks": (4, 2, 0.85, "질문형 H2 + 40~60단어 직답 블록",
                     "각 섹션 첫 문단을 그 질문의 완결된 답으로 다시 쓴다."),
    "entityAuthority": (4, 2, 0.85, "출처·통계·저자 귀속 보강",
                        "1차 출처 링크, 구체 수치, 실명 저자와 sameAs를 추가한다."),
    "chunkability": (4, 3, 0.8, "청크 자기완결성 리라이트",
                     "대명사 시작 제거, 섹션당 한 주제, 표·리스트·헤딩 앵커를 추가한다."),
    "freshness": (3, 2, 0.7, "신선도 관리 체계",
                  "dateModified·sitemap lastmod를 실제 수정 시각과 동기화한다."),
    "metaFoundation": (3, 1, 0.85, "메타 기반 정리",
                       "title·description·canonical·OG·시맨틱 태그를 페이지별로 채운다."),
    "markdownNegotiation": (3, 2, 0.7, "Markdown for Agents 활성화",
                            "Accept: text/markdown 협상을 켜고 Vary: Accept를 반드시 함께 설정한다."),
    "llmsTxt": (2, 1, 0.4, "llms.txt 게시",
                "설명이 붙은 핵심 링크 큐레이션으로 만든다. 효과 근거는 아직 약하다."),
    "llmsFullTxt": (2, 2, 0.35, "llms-full.txt 게시",
                    "토큰 예산을 먼저 정한다. 과대 파일은 역효과다."),
    "robotsTxt": (4, 1, 0.95, "robots.txt 게시", "RFC 9309 형식 + Sitemap 참조."),
    "sitemap": (4, 2, 0.9, "sitemap.xml 게시", "canonical URL과 정확한 lastmod."),
    "linkHeaders": (1, 1, 0.5, "Link 응답 헤더 추가",
                    "api-catalog·service-desc·service-doc 관계를 홈 응답에 추가한다."),
    "robotsTxtAiRules": (3, 1, 0.7, "AI 봇 명시 규칙 작성",
                         "와일드카드가 아닌 봇별 User-agent 블록으로 정책을 명시한다."),
    "contentSignals": (2, 1, 0.5, "Content-Signal 선언",
                       "선언이지 강제가 아니다. 강제는 WAF·AI Crawl Control이 한다."),
    "webBotAuth": (2, 3, 0.6, "Web Bot Auth JWKS 게시",
                   "우리가 에이전트를 내보낼 때만 의미가 있다."),
    "mcpServerCard": (4, 3, 0.8, "MCP Server Card 게시",
                      "실제 동작하는 MCP 서버를 먼저 만들고 카드를 붙인다."),
    "a2aAgentCard": (3, 3, 0.7, "A2A Agent Card 게시", "skills 배열을 실제 역량으로 채운다."),
    "agentSkills": (3, 2, 0.7, "Agent Skills Index 게시",
                    "각 스킬의 sha256 digest를 정확히 계산해 넣는다."),
    "apiCatalog": (3, 2, 0.75, "API Catalog 게시",
                   "RFC 9727 linkset+json으로 OpenAPI·문서·헬스를 연결한다."),
    "oauthDiscovery": (3, 3, 0.7, "OAuth/OIDC 디스커버리 게시", "RFC 8414 메타데이터."),
    "oauthProtectedResource": (3, 2, 0.7, "OAuth PRM 게시", "RFC 9728 메타데이터."),
    "authMd": (2, 2, 0.6, "auth.md 게시", "에이전트 등록 절차를 사람이 읽을 수 있게 문서화한다."),
    "ard": (2, 2, 0.55, "ARD ai-catalog 게시", "v0.9 초안. entries는 url/data 중 하나만."),
    "webMcp": (3, 3, 0.6, "WebMCP 툴 등록", "브라우저 에이전트에 사이트 액션을 노출한다."),
    "dnsAid": (1, 3, 0.4, "DNS-AID 레코드 게시", "실험 단계 표준. 우선순위 낮음."),
    "x402": (3, 3, 0.6, "x402 결제 미들웨어", "에이전트 결제가 실제 시나리오일 때만."),
    "ucp": (2, 3, 0.5, "UCP 프로필 게시", "커머스 전용."),
    "acp": (2, 3, 0.5, "ACP 문서 게시", "커머스 전용."),
    "mpp": (2, 2, 0.5, "OpenAPI에 x-payment-info", "커머스 전용."),
    "ap2": (1, 3, 0.4, "AP2 지원", "A2A Agent Card가 전제."),
}

GRADES = ((95, "S"), (85, "A"), (70, "B"), (55, "C"), (40, "D"), (0, "F"))


def load(path: str):
    if not path or not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def merge_checks(scan: dict, content: dict | None) -> dict:
    """콘텐츠 감사 결과가 있으면 해당 체크를 덮어쓴다(여러 쪽 평균이 더 정확)."""
    merged = dict(scan.get("checks") or {})
    for key, value in ((content or {}).get("checks") or {}).items():
        value = dict(value)
        value["source"] = "content-audit"
        merged[key] = value
    for key, value in merged.items():
        value.setdefault("source", "remote-scan")
    return merged


def layer_gates(checks: dict) -> dict:
    """L1·L2 실패 시 상위 레이어 획득 점수에 캡을 건다."""
    l1_keys = ("aiCrawlerAccess", "crawlerHttpAccess")
    l1 = sum(checks.get(k, {}).get("score", 0) * AEO_CHECKS[k][1] for k in l1_keys)
    l1 /= sum(AEO_CHECKS[k][1] for k in l1_keys)
    l2 = checks.get("serverRendering", {}).get("score", 0)
    return {"l1": round(l1, 3), "l2": round(l2, 3),
            "upperCap": 0.5 if l1 < 0.5 else 1.0,
            "l4Cap": 0.6 if l2 < 0.3 else 1.0}


def _cap_for(layer: str, gates: dict) -> float:
    if layer in ("L1", "L2"):
        return 1.0
    cap = gates["upperCap"]
    return min(cap, gates["l4Cap"]) if layer == "L4" else cap


def score_aeo(checks: dict, gates: dict) -> tuple:
    rows, earned, total = [], 0.0, 0.0
    for key, (layer, weight) in AEO_CHECKS.items():
        check = checks.get(key, {"score": 0, "status": "fail", "message": "미측정"})
        cap = _cap_for(layer, gates)
        got = check["score"] * cap * weight
        earned += got
        total += weight
        rows.append({"key": key, "axis": "aeo", "layer": layer, "weight": weight,
                     "score": check["score"], "capped": cap < 1.0,
                     "status": check["status"], "message": check["message"],
                     "applicable": True, "source": check.get("source", "")})
    return (round(100 * earned / total, 1) if total else 0.0), rows


def score_agent(checks: dict, profile: str, gates: dict) -> tuple:
    applicable = AGENT_APPLICABLE[profile]
    rows, earned, total = [], 0.0, 0.0
    for key, (group, weight) in AGENT_CHECKS.items():
        check = checks.get(key, {"score": 0, "status": "fail", "message": "미측정"})
        is_on = key in applicable
        cap = _cap_for("L5", gates)
        if is_on:
            earned += check["score"] * cap * weight
            total += weight
        rows.append({"key": key, "axis": "agent", "group": group, "weight": weight,
                     "score": check["score"], "capped": is_on and cap < 1.0,
                     "status": check["status"] if is_on else "na",
                     "message": check["message"], "applicable": is_on,
                     "source": check.get("source", "")})
    return (round(100 * earned / total, 1) if total else 0.0), rows


def agent_level(checks: dict) -> tuple:
    def ok(key):
        return checks.get(key, {}).get("status") == "pass"

    base = sum(1 for k in ("robotsTxt", "sitemap", "linkHeaders") if ok(k))
    if base < 2:
        return 0, "Not Ready"
    if not (ok("robotsTxtAiRules") and ok("contentSignals")):
        return 1, "Basic Web Presence"
    if not ok("markdownNegotiation"):
        return 2, "Bot-Aware"
    integrations = ["mcpServerCard", "a2aAgentCard", "agentSkills", "apiCatalog"]
    if not any(ok(k) for k in integrations):
        return 3, "Agent-Readable"
    native = [ok("webBotAuth"), all(ok(k) for k in integrations),
              any(ok(k) for k in ("oauthDiscovery", "oauthProtectedResource", "authMd"))]
    return (5, "Agent-Native") if sum(native) >= 2 else (4, "Agent-Integrated")


def prescribe(rows: list) -> dict:
    buckets = {"NOW": [], "NEXT": [], "LATER": []}
    seen = set()
    for row in rows:
        if not row["applicable"] or row["score"] >= 0.85:
            continue
        spec = PRESCRIPTIONS.get(row["key"])
        # markdownNegotiation·llmsTxt는 두 축에 동시 기여한다 — 처방은 한 번만 낸다
        if not spec or row["key"] in seen:
            continue
        seen.add(row["key"])
        impact, effort, confidence, title, action = spec
        priority = round(impact * confidence / effort, 2)
        item = {"key": row["key"], "title": title, "action": action,
                "impact": impact, "effort": effort, "confidence": confidence,
                "priority": priority, "score": row["score"],
                "layer": row.get("layer") or row.get("group"),
                "message": row["message"]}
        if row.get("layer") in ("L1", "L2") or priority >= 4.0:
            buckets["NOW"].append(item)
        elif priority >= 1.5 and confidence >= 0.5:
            buckets["NEXT"].append(item)
        else:
            buckets["LATER"].append(item)
    for items in buckets.values():
        items.sort(key=lambda i: (-i["priority"], i["effort"]))
    return buckets


def grade_of(score: float) -> str:
    return next(name for limit, name in GRADES if score >= limit)


def main() -> int:
    parser = argparse.ArgumentParser(description="AEO 프로파일 가중 점수 산출기")
    parser.add_argument("--scan", required=True)
    parser.add_argument("--content", default="")
    parser.add_argument("--crawlers", default="")
    parser.add_argument("--profile", default="content", choices=sorted(PROFILE_WEIGHTS))
    parser.add_argument("--out", required=True)
    parser.add_argument("--fail-under", type=float, default=None)
    args = parser.parse_args()

    scan = load(args.scan)
    if scan is None:
        print(f"[aeo] 스캔 결과를 찾을 수 없음: {args.scan}", file=sys.stderr)
        return 2
    content = load(args.content)
    checks = merge_checks(scan, content)
    gates = layer_gates(checks)
    aeo, aeo_rows = score_aeo(checks, gates)
    agent, agent_rows = score_agent(checks, args.profile, gates)
    weight_a, weight_b = PROFILE_WEIGHTS[args.profile]
    overall = round(aeo * weight_a + agent * weight_b, 1)
    level, level_name = agent_level(checks)
    rows = aeo_rows + agent_rows

    payload = {
        "kind": "aeo-score", "profile": args.profile,
        "weights": {"aeo": weight_a, "agent": weight_b},
        "scoredAt": datetime.now(timezone.utc).isoformat(),
        "target": scan.get("target", ""), "host": scan.get("host", ""),
        "overall": overall, "aeo": aeo, "agent": agent,
        "grade": grade_of(aeo), "agentLevel": level, "agentLevelName": level_name,
        "gates": gates, "rows": rows, "bots": scan.get("bots", []),
        "prescriptions": prescribe(rows),
        "codeFindings": (content or {}).get("findings", []),
        "crawlers": load(args.crawlers) or {},
        "sources": {"scan": os.path.abspath(args.scan),
                    "content": os.path.abspath(args.content) if args.content else "",
                    "crawlers": os.path.abspath(args.crawlers) if args.crawlers else ""},
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
    na_count = sum(1 for r in agent_rows if not r["applicable"])
    print(f"[aeo] 종합 {overall} (AEO {aeo}/{grade_of(aeo)} · "
          f"Agent {agent}/Lv{level} {level_name}) · N/A {na_count}개 → {args.out}")
    if args.fail_under is not None and overall < args.fail_under:
        print(f"[aeo] 임계 미달: {overall} < {args.fail_under}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
