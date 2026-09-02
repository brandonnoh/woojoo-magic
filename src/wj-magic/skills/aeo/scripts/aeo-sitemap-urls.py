#!/usr/bin/env python3
"""aeo-sitemap-urls.py — 사이트맵 XML에서 URL을 최대 N개 추출한다.

bash의 `grep | head` 파이프는 대용량 사이트맵에서 SIGPIPE를 일으켜
`set -o pipefail`과 충돌한다. 그래서 추출을 이 스크립트로 분리했다.

사용: python3 aeo-sitemap-urls.py <sitemap-file> [limit]
"""

from __future__ import annotations

import re
import sys
from html import unescape

LOC = re.compile(r"<loc>\s*([^<]+?)\s*</loc>", re.IGNORECASE)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: aeo-sitemap-urls.py <sitemap-file> [limit]", file=sys.stderr)
        return 2
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    try:
        with open(sys.argv[1], encoding="utf-8", errors="replace") as handle:
            body = handle.read()
    except OSError as error:
        print(f"[aeo] 사이트맵을 읽을 수 없음: {error}", file=sys.stderr)
        return 0  # URL 0개로 진행 — 감사 전체를 중단시키지 않는다
    seen, out = set(), []
    for match in LOC.finditer(body):
        url = unescape(match.group(1))
        if url in seen:
            continue
        seen.add(url)
        out.append(url)
        if len(out) >= limit:
            break
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
