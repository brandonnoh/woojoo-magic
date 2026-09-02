#!/usr/bin/env python3
"""aeo-assess.py — aeo-scan.sh가 수집한 원본 근거를 판정해 scan.json을 만든다.

수집(bash)과 판정(python)을 분리한 이유: 재판정 시 네트워크를 다시 때리지 않고
raw/ 디렉터리만으로 결과를 재생산할 수 있어야 하기 때문이다(증거 보존).
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

PASS, PARTIAL, FAIL, NEUTRAL, UNKNOWN = (
    "pass", "partial", "fail", "neutral", "unableToCheck")

CORE_SCHEMA_TYPES = {
    "Article": 0.30, "BlogPosting": 0.30, "NewsArticle": 0.30, "TechArticle": 0.30,
    "MedicalWebPage": 0.30, "Product": 0.30,
    "Organization": 0.20, "NewsMediaOrganization": 0.20, "LocalBusiness": 0.20,
    "FAQPage": 0.20, "HowTo": 0.20,
    "Person": 0.10, "WebSite": 0.10, "BreadcrumbList": 0.10,
}


def result(score: float, status: str, message: str, **evidence) -> dict:
    return {"score": round(max(0.0, min(1.0, score)), 3), "status": status,
            "message": message, "evidence": evidence}


class Raw:
    """수집 디렉터리 접근자."""

    def __init__(self, path: str):
        self.path = path
        self.meta = {}
        meta_file = os.path.join(path, "meta.tsv")
        if os.path.exists(meta_file):
            for line in open(meta_file, encoding="utf-8", errors="replace"):
                cols = line.rstrip("\n").split("\t")
                if len(cols) >= 5:
                    self.meta[cols[0]] = {
                        "status": _int(cols[1]), "contentType": cols[2],
                        "bytes": _int(cols[3]), "finalUrl": cols[4]}

    def status(self, key: str) -> int:
        return self.meta.get(key, {}).get("status", 0)

    def ctype(self, key: str) -> str:
        return self.meta.get(key, {}).get("contentType", "") or ""

    def _read(self, name: str) -> str:
        target = os.path.join(self.path, name)
        if not os.path.exists(target):
            return ""
        with open(target, encoding="utf-8", errors="replace") as handle:
            return handle.read()

    def body(self, key: str) -> str:
        return self._read(_slug(key) + ".body")

    def head(self, key: str) -> str:
        return self._read(_slug(key) + ".head")

    def as_json(self, key: str):
        try:
            return json.loads(self.body(key))
        except (ValueError, TypeError):
            return None


def _int(value: str) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def _slug(key: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "_", key)


# ── robots.txt ────────────────────────────────────────────────────
def parse_robots(text: str) -> dict:
    groups, sitemaps, agentmaps = [], [], []
    current, expecting_agent = None, False
    for raw_line in (text or "").splitlines():
        line = raw_line.split("#")[0].strip()
        if not line or ":" not in line:
            continue
        field, _, value = line.partition(":")
        field, value = field.strip().lower(), value.strip()
        if field == "user-agent":
            if current is None or not expecting_agent:
                current = {"agents": [], "rules": [], "signals": []}
                groups.append(current)
            expecting_agent = True
            current["agents"].append(value.lower())
        elif field in ("allow", "disallow") and current is not None:
            expecting_agent = False
            current["rules"].append((field, value))
        elif field == "content-signal" and current is not None:
            expecting_agent = False
            current["signals"].append(value)
        elif field == "sitemap":
            sitemaps.append(value)
        elif field == "agentmap":
            agentmaps.append(value)
    return {"groups": groups, "sitemaps": sitemaps, "agentmaps": agentmaps}


def bot_policy(robots: dict, token: str) -> dict:
    """RFC 9309 기준으로 해당 봇의 루트 접근 정책을 해석한다."""
    lowered = token.lower()
    explicit = next((g for g in robots["groups"] if lowered in g["agents"]), None)
    group = explicit or next((g for g in robots["groups"] if "*" in g["agents"]), None)
    if group is None:
        return {"policy": "allow", "explicit": False, "source": "default"}
    blocked = any(f == "disallow" and p in ("/", "/*")
                  for f, p in group["rules"])
    allowed_root = any(f == "allow" and p in ("/", "/*") for f, p in group["rules"])
    policy = "disallow" if (blocked and not allowed_root) else "allow"
    return {"policy": policy, "explicit": explicit is not None,
            "source": "explicit" if explicit else "wildcard",
            "signals": group["signals"]}


def load_bots(script_dir: str) -> list:
    with open(os.path.join(script_dir, "aeo-bots.json"), encoding="utf-8") as handle:
        return json.load(handle)["bots"]


# ── L1 체크 ───────────────────────────────────────────────────────
def check_robots_txt(raw: Raw, robots: dict) -> dict:
    if raw.status("robotsTxt") != 200:
        return result(0, FAIL, f"robots.txt 없음 (HTTP {raw.status('robotsTxt')})")
    if not robots["groups"]:
        return result(0.3, PARTIAL, "robots.txt는 있으나 User-agent 그룹이 없음")
    has_sitemap = bool(robots["sitemaps"])
    score = 1.0 if has_sitemap else 0.7
    return result(score, PASS if has_sitemap else PARTIAL,
                  f"robots.txt 유효 (그룹 {len(robots['groups'])}개, "
                  f"Sitemap 참조 {'있음' if has_sitemap else '없음'})",
                  groups=len(robots["groups"]), sitemaps=robots["sitemaps"])


def check_ai_crawler_access(bots: list, robots: dict) -> tuple:
    """AEO 축: 검색·사용자개시 봇이 차단되지 않았는가 (가장 중요한 체크)."""
    table, blocked = [], []
    for bot in bots:
        policy = bot_policy(robots, bot["token"])
        row = dict(bot, **policy)
        table.append(row)
        if bot["kind"] in ("search", "user") and policy["policy"] == "disallow":
            blocked.append(bot["token"])
    citing = [b for b in bots if b["kind"] in ("search", "user")]
    score = 1.0 - (len(blocked) / max(1, len(citing)))
    if blocked:
        message = f"인용 경로 크롤러 {len(blocked)}종이 robots.txt에서 차단됨: " \
                  + ", ".join(blocked)
        status = FAIL if score < 0.7 else PARTIAL
    else:
        message = "검색·사용자개시 AI 크롤러가 모두 허용됨"
        status = PASS
    return result(score, status, message, blocked=blocked), table


def check_ai_rules(bots: list, robots: dict) -> dict:
    """Agent 축: AI 봇에 대한 '명시적' User-agent 블록이 있는가."""
    explicit = [b["token"] for b in bots
                if bot_policy(robots, b["token"])["explicit"]]
    if len(explicit) >= 3:
        return result(1.0, PASS, f"명시적 AI 봇 규칙 {len(explicit)}종",
                      bots=explicit)
    if explicit:
        return result(0.5, PARTIAL, f"명시적 AI 봇 규칙이 {len(explicit)}종뿐",
                      bots=explicit)
    return result(0, FAIL, "AI 봇에 대한 명시적 User-agent 블록 없음 "
                           "(와일드카드만으로는 불충분)")


def check_content_signals(robots: dict) -> dict:
    signals = [s for g in robots["groups"] for s in g["signals"]]
    if not signals:
        return result(0, FAIL, "Content-Signal 디렉티브 없음")
    keys = set(re.findall(r"(ai-train|search|ai-input)\s*=", " ".join(signals)))
    score = len(keys) / 3.0
    return result(score, PASS if score == 1.0 else PARTIAL,
                  f"Content-Signal {len(signals)}건 (선언된 축: {', '.join(sorted(keys)) or '없음'})",
                  signals=signals)


def check_http_access(raw: Raw) -> dict:
    codes = {tag: raw.status(f"ua_{tag}") for tag in ("search", "perplexity", "train")}
    citing = [codes["search"], codes["perplexity"]]
    ok = sum(1 for c in citing if 200 <= c < 300)
    score = ok / len(citing)
    if score == 1.0:
        return result(1.0, PASS, "AI 크롤러 UA 요청이 정상 응답(2xx)", codes=codes)
    return result(score, FAIL if score == 0 else PARTIAL,
                  f"AI 크롤러 UA 요청이 차단됨 (search={codes['search']}, "
                  f"perplexity={codes['perplexity']}) — WAF·레이트리밋·챌린지 확인 필요",
                  codes=codes)


# ── L2 체크 ───────────────────────────────────────────────────────
def check_rendering(raw: Raw, stats: dict, jsonld_count: int) -> dict:
    chars = stats["chars"]
    if stats["shellOnly"]:
        return result(0, FAIL, "raw HTML이 JS 셸뿐 — AI 크롤러에는 빈 페이지",
                      chars=chars)
    if chars >= 1200:
        score = 1.0
    elif chars >= 400:
        score = 0.3 + 0.7 * (chars - 400) / 800.0
    else:
        score = 0.1
    status = PASS if score >= 0.9 else (PARTIAL if score >= 0.4 else FAIL)
    return result(score, status,
                  f"JS 없는 raw HTML 본문 {chars}자, JSON-LD {jsonld_count}블록"
                  + ("" if score >= 0.9 else " — CSR 렌더링 갭 의심"),
                  chars=chars, jsonLdBlocks=jsonld_count)


def check_hygiene(raw: Raw, meta: dict) -> dict:
    head = raw.head("home").lower()
    problems = []
    if raw.status("home") != 200:
        problems.append(f"홈 응답 {raw.status('home')}")
    if "noindex" in meta.get("robots", "").lower():
        problems.append("meta robots noindex")
    if re.search(r"x-robots-tag:.*noindex", head):
        problems.append("X-Robots-Tag noindex")
    if not meta.get("canonical"):
        problems.append("canonical 없음")
    score = max(0.0, 1.0 - 0.34 * len(problems))
    if not problems:
        return result(1.0, PASS, "HTTP 위생 양호 (200 · canonical · noindex 없음)")
    return result(score, FAIL if score < 0.4 else PARTIAL,
                  "HTTP 위생 문제: " + ", ".join(problems), problems=problems)


# ── L3 체크 ───────────────────────────────────────────────────────
def check_markdown(raw: Raw) -> dict:
    ctype = raw.ctype("homeMarkdown").lower()
    if "text/markdown" not in ctype:
        return result(0, FAIL,
                      f"Accept: text/markdown 요청에 마크다운 미반환 (Content-Type: {ctype or '없음'})")
    head = raw.head("homeMarkdown").lower()
    has_vary = bool(re.search(r"^vary:.*accept", head, re.M))
    tokens = re.search(r"x-markdown-tokens:\s*(\d+)", head)
    score = 1.0 if has_vary else 0.7
    return result(score, PASS if has_vary else PARTIAL,
                  "마크다운 콘텐츠 협상 동작"
                  + ("" if has_vary else " — 단 Vary: Accept 누락(캐시 오염 위험)"),
                  vary=has_vary,
                  markdownTokens=_int(tokens.group(1)) if tokens else None)


def check_llms_txt(raw: Raw) -> dict:
    if raw.status("llmsTxt") != 200:
        return result(0, FAIL, "/llms.txt 없음")
    body = raw.body("llmsTxt")
    has_h1 = body.lstrip().startswith("#")
    links = len(re.findall(r"\[[^\]]+\]\([^)]+\)", body))
    described = len(re.findall(r"\[[^\]]+\]\([^)]+\)\s*:\s*\S", body))
    if not has_h1 or links == 0:
        return result(0.4, PARTIAL, "llms.txt는 있으나 H1 또는 링크 목록이 없음")
    score = 1.0 if described >= max(1, links // 3) else 0.75
    return result(score, PASS if score == 1.0 else PARTIAL,
                  f"llms.txt 유효 (링크 {links}개, 설명 붙은 링크 {described}개)"
                  + ("" if score == 1.0 else " — 설명 없는 링크는 사이트맵 복제에 불과"),
                  links=links, described=described)


def check_llms_full(raw: Raw) -> dict:
    if raw.status("llmsFullTxt") != 200:
        return result(0, NEUTRAL, "/llms-full.txt 없음 (선택 항목)")
    size = len(raw.body("llmsFullTxt"))
    if size > 900_000:
        return result(0.5, PARTIAL,
                      f"llms-full.txt가 과대({size}자) — 컨텍스트 윈도를 넘겨 역효과",
                      chars=size)
    return result(1.0, PASS, f"llms-full.txt 제공 ({size}자)", chars=size)


# ── L4 체크 ───────────────────────────────────────────────────────
def check_sitemap(raw: Raw) -> tuple:
    if raw.status("sitemap") != 200:
        return result(0, FAIL, "sitemap.xml 없음"), []
    body = raw.body("sitemap")
    if "<urlset" not in body and "<sitemapindex" not in body:
        return result(0.3, PARTIAL, "sitemap.xml 응답이 유효한 XML 구조가 아님"), []
    urls = len(re.findall(r"<loc>", body))
    lastmods = re.findall(r"<lastmod>([^<]+)</lastmod>", body)
    return result(1.0, PASS, f"sitemap.xml 유효 (항목 {urls}개, lastmod {len(lastmods)}개)",
                  urls=urls, lastmods=len(lastmods)), lastmods


def check_freshness(lastmods: list, meta_nodes: list) -> dict:
    dates = [_parse_date(v) for v in lastmods]
    for node in meta_nodes:
        if isinstance(node.get("dateModified"), str):
            dates.append(_parse_date(node["dateModified"]))
    dates = [d for d in dates if d]
    if not dates:
        return result(0.3, PARTIAL, "lastmod·dateModified 신선도 신호 없음")
    age = (datetime.now(timezone.utc) - max(dates)).days
    table = ((30, 1.0), (90, 0.8), (180, 0.55), (365, 0.3))
    score = next((s for limit, s in table if age <= limit), 0.1)
    return result(score, PASS if score >= 0.8 else PARTIAL,
                  f"최신 갱신 {age}일 전", ageDays=age)


def _parse_date(value: str):
    text = (value or "").strip()
    for pattern in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%d"):
        try:
            parsed = datetime.strptime(text.replace("Z", "+0000")
                                       if pattern.endswith("%z") else text, pattern)
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


def check_link_headers(raw: Raw) -> dict:
    head = raw.head("home")
    rels = set(re.findall(r'rel\s*=\s*"?([a-z-]+)"?', head, re.I))
    wanted = {"api-catalog", "service-desc", "service-doc", "describedby"}
    found = sorted(rels & wanted)
    if not found:
        return result(0, FAIL, "홈 응답에 에이전트용 Link 헤더 없음")
    score = min(1.0, len(found) / 2.0)
    return result(score, PASS if score >= 1.0 else PARTIAL,
                  f"Link 관계 발견: {', '.join(found)}", relations=found)


def check_structured_data(nodes: list) -> dict:
    types = set(aeo_html.jsonld_types(nodes))
    if "__INVALID__" in types:
        return result(0.2, PARTIAL, "JSON-LD 블록이 있으나 파싱 실패(문법 오류)")
    if not types:
        return result(0, FAIL, "raw HTML에 JSON-LD 없음 "
                               "(클라이언트 주입이면 AI 크롤러는 못 읽는다)")
    score = min(1.0, sum(CORE_SCHEMA_TYPES.get(t, 0.03) for t in types))
    return result(score, PASS if score >= 0.8 else PARTIAL,
                  f"JSON-LD @type: {', '.join(sorted(types)[:8])}",
                  types=sorted(types))


def check_meta_foundation(meta: dict) -> dict:
    checks = {
        "title": bool(meta["title"]), "description": bool(meta["description"]),
        "canonical": bool(meta["canonical"]), "og": bool(meta["ogTitle"]),
        "semantic": meta["articleTags"] + meta["mainTags"] > 0,
    }
    score = sum(1 for v in checks.values() if v) / len(checks)
    missing = [k for k, v in checks.items() if not v]
    return result(score, PASS if score >= 0.9 else PARTIAL,
                  "메타 기반 양호" if not missing else f"누락: {', '.join(missing)}",
                  **checks)


def check_dns_aid(raw: Raw) -> dict:
    found = []
    for name in ("dns_index", "dns_a2a", "dns_catalog"):
        target = os.path.join(raw.path, name + ".json")
        if not os.path.exists(target):
            continue
        try:
            data = json.load(open(target, encoding="utf-8"))
        except (ValueError, OSError):
            continue
        if data.get("Answer"):
            found.append(name)
    if not found:
        return result(0, FAIL, "DNS-AID(_agents) 레코드 없음")
    return result(1.0, PASS, f"DNS-AID 레코드 발견: {', '.join(found)}", records=found)


# ── L5 체크 (well-known 발견 문서) ────────────────────────────────
def check_json_doc(raw: Raw, key: str, label: str, validate) -> dict:
    if raw.status(key) != 200:
        return result(0, FAIL, f"{label} 없음 (HTTP {raw.status(key)})")
    data = raw.as_json(key)
    if data is None:
        return result(0.2, PARTIAL, f"{label} 응답이 유효한 JSON이 아님")
    ok, note = validate(data)
    if ok:
        return result(1.0, PASS, f"{label} 유효 — {note}")
    return result(0.4, PARTIAL, f"{label} 필수 필드 누락 — {note}")


def _v_mcp(d):
    name = (d.get("serverInfo") or {}).get("name") or d.get("name")
    return bool(name), f"name={name or '없음'}"


def _v_a2a(d):
    return bool(d.get("name") and d.get("version")), f"name={d.get('name')}"


def _v_skills(d):
    skills = d.get("skills") or []
    valid = [s for s in skills if s.get("name") and s.get("url") and s.get("digest")]
    return bool(valid), f"스킬 {len(valid)}/{len(skills)}개 완전"


def _v_catalog(d):
    entries = d.get("linkset") or []
    return bool(entries), f"linkset {len(entries)}건"


def _v_oauth_as(d):
    return bool(d.get("issuer") and d.get("token_endpoint")), f"issuer={d.get('issuer')}"


def _v_prm(d):
    return (bool(d.get("resource") and d.get("authorization_servers")),
            f"resource={d.get('resource')}")


def _v_ard(d):
    entries = d.get("entries") or []
    good = [e for e in entries if bool(e.get("url")) != bool(e.get("data"))]
    return bool(d.get("specVersion") and good), f"entries {len(good)}/{len(entries)}건 적합"


def _v_jwks(d):
    return bool(d.get("keys")), f"공개키 {len(d.get('keys') or [])}개"


def _v_ucp(d):
    return bool(d.get("protocol_version") and d.get("services")), "protocol_version 존재"


def _v_acp(d):
    proto = d.get("protocol") or {}
    return (proto.get("name") == "acp" and bool(d.get("api_base_url")),
            f"protocol.name={proto.get('name')}")


def check_oauth_discovery(raw: Raw) -> dict:
    for key, label in (("oidcConfig", "OIDC Discovery"),
                       ("oauthAuthServer", "OAuth AS Metadata")):
        if raw.status(key) == 200:
            return check_json_doc(raw, key, label, _v_oauth_as)
    return result(0, FAIL, "OAuth/OIDC 디스커버리 메타데이터 없음")


def check_mcp_card(raw: Raw) -> dict:
    key = "mcpServerCard" if raw.status("mcpServerCard") == 200 else "mcpServerCardAlt"
    return check_json_doc(raw, key, "MCP Server Card", _v_mcp)


def check_auth_md(raw: Raw) -> dict:
    if raw.status("authMd") != 200:
        return result(0, FAIL, "/auth.md 없음")
    body = raw.body("authMd")
    has_h1 = bool(re.search(r"^#\s+.*auth\.md", body, re.I | re.M))
    return result(1.0 if has_h1 else 0.4, PASS if has_h1 else PARTIAL,
                  "auth.md 제공" if has_h1 else "auth.md의 H1에 'auth.md' 표기 없음")


def check_mpp(raw: Raw) -> dict:
    if raw.status("openapi") != 200:
        return result(0, FAIL, "/openapi.json 없음")
    hits = len(re.findall(r'"x-payment-info"', raw.body("openapi")))
    if not hits:
        return result(0.3, PARTIAL, "openapi.json은 있으나 x-payment-info 없음")
    return result(1.0, PASS, f"x-payment-info {hits}건", operations=hits)


def check_web_mcp(meta: dict) -> dict:
    if meta.get("webMcp"):
        return result(1.0, PASS, "navigator.modelContext 등록 코드 발견")
    return result(0, UNKNOWN, "WebMCP 미검출 — 정확한 판정은 브라우저 실행 필요 "
                              "(Playwright MCP로 재확인 권장)")


# ── 조립 ──────────────────────────────────────────────────────────
def _content_checks(home: str, nodes: list, meta: dict, lastmods: list) -> dict:
    """홈 HTML에서 파생되는 L3·L4 체크. 콘텐츠 감사가 있으면 나중에 덮어쓰인다."""
    headings = aeo_html.extract_headings(home)
    entity, entity_ev = aeo_html.entity_score(nodes, meta)
    chunk, chunk_ev = aeo_html.chunk_score(home, headings, meta)
    answer = aeo_html.answer_block_ratio(home)
    return {
        "chunkability": result(chunk, PASS if chunk >= 0.7 else PARTIAL,
                               f"청크 구조 점수 {chunk}", **chunk_ev),
        "structuredData": check_structured_data(nodes),
        "answerBlocks": result(answer, PASS if answer >= 0.6 else PARTIAL,
                               f"H2 직후 직답 블록 비율 {answer}"),
        "entityAuthority": result(entity, PASS if entity >= 0.6 else PARTIAL,
                                  f"엔티티·권위 신호 {entity}", **entity_ev),
        "freshness": check_freshness(lastmods, nodes),
        "metaFoundation": check_meta_foundation(meta),
    }


def _discovery_checks(raw: Raw, meta: dict) -> dict:
    """L5 발견 문서 체크 전체."""
    return {
        "webBotAuth": check_json_doc(raw, "webBotAuth", "Web Bot Auth JWKS", _v_jwks),
        "mcpServerCard": check_mcp_card(raw),
        "a2aAgentCard": check_json_doc(raw, "a2aAgentCard", "A2A Agent Card", _v_a2a),
        "agentSkills": check_json_doc(raw, "agentSkills", "Agent Skills Index", _v_skills),
        "apiCatalog": check_json_doc(raw, "apiCatalog", "API Catalog", _v_catalog),
        "oauthDiscovery": check_oauth_discovery(raw),
        "oauthProtectedResource": check_json_doc(
            raw, "oauthProtectedResource", "OAuth PRM", _v_prm),
        "authMd": check_auth_md(raw),
        "ard": check_json_doc(raw, "ard", "ARD ai-catalog", _v_ard),
        "webMcp": check_web_mcp(meta),
        "ucp": check_json_doc(raw, "ucp", "UCP 프로필", _v_ucp),
        "acp": check_json_doc(raw, "acp", "ACP 문서", _v_acp),
        "mpp": check_mpp(raw),
        "x402": result(0, UNKNOWN, "x402는 보호 라우트 호출이 필요 — 수동 확인"),
        "ap2": result(0, NEUTRAL, "AP2는 A2A Agent Card 전제"),
    }


def build_checks(raw: Raw, bots: list) -> tuple:
    robots = parse_robots(raw.body("robotsTxt") if raw.status("robotsTxt") == 200 else "")
    home = raw.body("home")
    nodes = aeo_html.extract_jsonld(home)
    meta = aeo_html.extract_meta(home)
    stats = aeo_html.text_stats(home)
    sitemap_check, lastmods = check_sitemap(raw)
    access_check, bot_table = check_ai_crawler_access(bots, robots)
    checks = {
        "aiCrawlerAccess": access_check,
        "crawlerHttpAccess": check_http_access(raw),
        "serverRendering": check_rendering(raw, stats, len(nodes)),
        "httpHygiene": check_hygiene(raw, meta),
        "markdownNegotiation": check_markdown(raw),
        "llmsTxt": check_llms_txt(raw),
        "llmsFullTxt": check_llms_full(raw),
        "robotsTxt": check_robots_txt(raw, robots),
        "sitemap": sitemap_check,
        "linkHeaders": check_link_headers(raw),
        "dnsAid": check_dns_aid(raw),
        "robotsTxtAiRules": check_ai_rules(bots, robots),
        "contentSignals": check_content_signals(robots),
    }
    checks.update(_content_checks(home, nodes, meta, lastmods))
    checks.update(_discovery_checks(raw, meta))
    return checks, bot_table, {"meta": meta, "stats": stats,
                               "jsonLdTypes": aeo_html.jsonld_types(nodes),
                               "robotsSitemaps": robots["sitemaps"],
                               "agentmaps": robots["agentmaps"]}


def main() -> int:
    parser = argparse.ArgumentParser(description="AEO 원격 스캔 판정기")
    parser.add_argument("--raw", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--origin", default="")
    parser.add_argument("--host", default="")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    raw = Raw(args.raw)
    checks, bot_table, extras = build_checks(raw, load_bots(script_dir))
    payload = {
        "kind": "aeo-scan",
        "target": args.target, "origin": args.origin, "host": args.host,
        "scannedAt": datetime.now(timezone.utc).isoformat(),
        "checks": checks, "bots": bot_table, "details": extras,
        "rawDir": os.path.abspath(args.raw),
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
    failed = [k for k, v in checks.items() if v["status"] == FAIL]
    print(f"[aeo] 판정 완료: {len(checks)}개 체크, fail {len(failed)}개 → {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
