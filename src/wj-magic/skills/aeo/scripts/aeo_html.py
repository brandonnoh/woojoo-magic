"""aeo_html.py — HTML에서 AEO 신호를 추출하는 공용 모듈.

원격 스캔(aeo-assess.py)과 로컬 콘텐츠 감사(aeo-content-assess.py)가 함께 쓴다.
외부 의존성 없음(표준 라이브러리만) — 설치 없이 어디서나 돌아가야 한다.
"""

from __future__ import annotations

import json
import re
from html import unescape

_DROP = re.compile(r"(?is)<(script|style|noscript|template|svg)[^>]*>.*?</\1>")
_TAG = re.compile(r"(?s)<[^>]+>")
_JSONLD = re.compile(
    r'(?is)<script[^>]+type\s*=\s*["\']application/ld\+json["\'][^>]*>(.*?)</script>'
)
_HEADING = re.compile(r"(?is)<h([1-6])\b[^>]*>(.*?)</h\1>")
_PARA = re.compile(r"(?is)<p\b[^>]*>(.*?)</p>")
_QUESTION_HINT = re.compile(
    r"(?:\?|까요|나요|인가|무엇|어떻게|왜|언제|어디|얼마|방법|기준|차이|하는 법"
    r"|what|how|why|when|where|which|who|can |does |is |are )",
    re.IGNORECASE,
)

# 본문으로 볼 수 없는 껍데기 텍스트 (렌더링 갭 오탐 방지)
_SHELL_HINT = re.compile(
    r"(?i)(enable javascript|자바스크립트를 활성|loading\.\.\.|잠시만 기다려)"
)


def strip_tags(html: str) -> str:
    """스크립트·스타일을 제거하고 태그를 벗겨 본문 텍스트만 남긴다."""
    body = _DROP.sub(" ", html or "")
    body = _TAG.sub(" ", body)
    return " ".join(unescape(body).split())


def inner_text(fragment: str) -> str:
    return " ".join(unescape(_TAG.sub(" ", fragment or "")).split())


def text_stats(html: str) -> dict:
    text = strip_tags(html)
    return {
        "chars": len(text),
        "words": len(text.split()),
        "shellOnly": bool(_SHELL_HINT.search(text)) and len(text) < 800,
    }


def extract_jsonld(html: str) -> list:
    """JSON-LD 블록을 파싱해 평탄화된 노드 리스트로 반환한다."""
    nodes = []
    for block in _JSONLD.findall(html or ""):
        try:
            data = json.loads(unescape(block.strip()))
        except (ValueError, TypeError):
            nodes.append({"@type": "__INVALID__"})
            continue
        nodes.extend(_flatten_jsonld(data))
    return nodes


def _flatten_jsonld(data) -> list:
    if isinstance(data, list):
        out = []
        for item in data:
            out.extend(_flatten_jsonld(item))
        return out
    if not isinstance(data, dict):
        return []
    out = [data]
    for key in ("@graph", "mainEntity", "itemListElement"):
        if key in data:
            out.extend(_flatten_jsonld(data[key]))
    return out


def jsonld_types(nodes: list) -> list:
    types = []
    for node in nodes:
        raw = node.get("@type")
        if isinstance(raw, str):
            types.append(raw)
        elif isinstance(raw, list):
            types.extend(t for t in raw if isinstance(t, str))
    return sorted(set(types))


def extract_headings(html: str) -> list:
    return [
        {"level": int(level), "text": inner_text(body)}
        for level, body in _HEADING.findall(html or "")
    ]


def question_ratio(headings: list) -> float:
    """H2/H3 중 질문형(대화형 질의와 매칭되는) 헤딩의 비율."""
    targets = [h for h in headings if h["level"] in (2, 3) and h["text"]]
    if not targets:
        return 0.0
    hit = sum(1 for h in targets if _QUESTION_HINT.search(h["text"]))
    return round(hit / len(targets), 3)


def answer_block_ratio(html: str, low: int = 18, high: int = 95) -> float:
    """각 H2 직후 첫 문단이 '직답 블록' 길이 범위에 드는 비율.

    한국어는 어절 단위라 영어 40~60단어보다 넓은 범위를 쓴다.
    """
    sections = re.split(r"(?is)<h2\b", html or "")[1:]
    if not sections:
        return 0.0
    hit = 0
    for section in sections:
        para = _PARA.search(section)
        if not para:
            continue
        words = len(inner_text(para.group(1)).split())
        if low <= words <= high:
            hit += 1
    return round(hit / len(sections), 3)


def extract_meta(html: str) -> dict:
    """title·description·canonical·OG·hreflang·robots 메타를 추출한다."""
    page = html or ""
    title = re.search(r"(?is)<title[^>]*>(.*?)</title>", page)
    return {
        "title": inner_text(title.group(1)) if title else "",
        "description": _meta_content(page, r'name=["\']description["\']'),
        "robots": _meta_content(page, r'name=["\']robots["\']'),
        "canonical": _link_href(page, r'rel=["\']canonical["\']'),
        "ogTitle": _meta_content(page, r'property=["\']og:title["\']'),
        "ogDescription": _meta_content(page, r'property=["\']og:description["\']'),
        "hreflang": len(re.findall(r'(?i)rel=["\']alternate["\'][^>]*hreflang=', page)),
        "articleTags": len(re.findall(r"(?i)<article\b", page)),
        "mainTags": len(re.findall(r"(?i)<main\b", page)),
        "tables": len(re.findall(r"(?i)<table\b", page)),
        "lists": len(re.findall(r"(?i)<(ul|ol)\b", page)),
        "headingAnchors": len(re.findall(r"(?is)<h[23]\b[^>]*\bid=", page)),
        "outboundCitations": len(re.findall(r'(?i)<(cite|blockquote)\b', page)),
        "webMcp": bool(re.search(r"navigator\.modelContext", page)),
        "aiCatalogLink": bool(re.search(r'(?i)rel=["\']ai-catalog["\']', page)),
    }


def _meta_content(html: str, attr_pattern: str) -> str:
    match = re.search(
        r"(?is)<meta[^>]*" + attr_pattern + r"[^>]*content=[\"']([^\"']*)[\"']", html
    )
    if not match:
        match = re.search(
            r"(?is)<meta[^>]*content=[\"']([^\"']*)[\"'][^>]*" + attr_pattern, html
        )
    return unescape(match.group(1)).strip() if match else ""


def _link_href(html: str, attr_pattern: str) -> str:
    match = re.search(
        r"(?is)<link[^>]*" + attr_pattern + r"[^>]*href=[\"']([^\"']*)[\"']", html
    )
    if not match:
        match = re.search(
            r"(?is)<link[^>]*href=[\"']([^\"']*)[\"'][^>]*" + attr_pattern, html
        )
    return unescape(match.group(1)).strip() if match else ""


def entity_score(nodes: list, meta: dict) -> tuple:
    """Organization/Person/sameAs/저자/출처 등 권위 신호를 0~1로 점수화."""
    types = set(jsonld_types(nodes))
    has_org = bool(types & {"Organization", "NewsMediaOrganization", "LocalBusiness",
                            "Corporation", "MedicalOrganization"})
    has_person = "Person" in types
    same_as = any(node.get("sameAs") for node in nodes)
    author = any(node.get("author") for node in nodes)
    citation = any(node.get("citation") for node in nodes) or meta["outboundCitations"] > 0
    signals = [has_org, has_person, same_as, author, citation]
    return round(sum(1 for s in signals if s) / len(signals), 3), {
        "organization": has_org, "person": has_person, "sameAs": same_as,
        "author": author, "citation": citation,
    }


def chunk_score(html: str, headings: list, meta: dict) -> tuple:
    """청크 자기완결성 — 질문형 헤딩·표/리스트·앵커·섹션 밀도를 종합."""
    q_ratio = question_ratio(headings)
    h2_count = sum(1 for h in headings if h["level"] == 2)
    structure = min(1.0, (meta["tables"] + meta["lists"]) / 4.0)
    anchors = min(1.0, meta["headingAnchors"] / max(1, h2_count)) if h2_count else 0.0
    density = min(1.0, h2_count / 4.0)
    score = 0.4 * q_ratio + 0.25 * density + 0.2 * structure + 0.15 * anchors
    return round(score, 3), {
        "questionHeadingRatio": q_ratio, "h2Count": h2_count,
        "tables": meta["tables"], "lists": meta["lists"],
        "headingAnchors": meta["headingAnchors"],
    }
