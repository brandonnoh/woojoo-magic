/**
 * markdown-negotiation.worker.js
 * Accept: text/markdown 요청에 마크다운을 반환하는 Cloudflare Worker 예시.
 *
 * Cloudflare 존이라면 AI Crawl Control의 "Markdown for Agents"를 켜는 편이
 * 훨씬 낫다(엣지 변환 + 토큰 헤더 자동). 이 Worker는 그 기능을 쓸 수 없거나
 * 변환 범위를 직접 통제해야 할 때 쓴다.
 *
 * 필수 규칙
 *  - Vary: Accept 를 반드시 설정한다. 없으면 캐시가 브라우저에 마크다운을 준다.
 *  - 기본 응답은 HTML이어야 한다(브라우저 경험 불변).
 *  - 마크다운과 HTML의 "내용"이 달라지면 클로킹이다. 형식만 달라야 한다.
 */

const MARKDOWN_TYPE = "text/markdown; charset=utf-8";

export default {
  async fetch(request, env, ctx) {
    const accept = request.headers.get("accept") || "";
    const wantsMarkdown = /text\/markdown/i.test(accept);
    const response = await fetch(request);

    if (!wantsMarkdown || !isHtml(response)) return response;

    const html = await response.text();
    const markdown = htmlToMarkdown(html);
    const headers = new Headers(response.headers);
    headers.set("content-type", MARKDOWN_TYPE);
    headers.set("vary", appendVary(headers.get("vary"), "Accept"));
    headers.set("x-markdown-tokens", String(estimateTokens(markdown)));
    headers.set("x-original-tokens", String(estimateTokens(html)));
    // 본문 길이·인코딩을 기술하던 헤더는 변환 후 무효다
    for (const key of ["content-length", "content-encoding", "content-range",
                       "transfer-encoding", "etag", "last-modified"]) {
      headers.delete(key);
    }
    return new Response(markdown, { status: response.status, headers });
  },
};

function isHtml(response) {
  return /text\/html/i.test(response.headers.get("content-type") || "");
}

function appendVary(current, value) {
  const parts = (current || "").split(",").map((p) => p.trim()).filter(Boolean);
  if (!parts.some((p) => p.toLowerCase() === value.toLowerCase())) parts.push(value);
  return parts.join(", ");
}

function estimateTokens(text) {
  return Math.ceil(text.length / 4);
}

/**
 * 최소 변환기. 실제 운영에서는 <main>/<article> 경계를 정확히 잡는 것이
 * 변환 품질의 90%를 결정한다 — 네비·푸터·광고가 섞이면 이득이 반감된다.
 */
function htmlToMarkdown(html) {
  const main = extractMain(html);
  return main
    .replace(/<(script|style|noscript|svg|nav|footer|aside)[^>]*>[\s\S]*?<\/\1>/gi, "")
    .replace(/<h([1-6])[^>]*>([\s\S]*?)<\/h\1>/gi,
             (_, level, body) => `\n\n${"#".repeat(+level)} ${strip(body)}\n\n`)
    .replace(/<li[^>]*>([\s\S]*?)<\/li>/gi, (_, body) => `\n- ${strip(body)}`)
    .replace(/<a[^>]+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi,
             (_, href, body) => `[${strip(body)}](${href})`)
    .replace(/<(p|div|section|tr)[^>]*>/gi, "\n\n")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function extractMain(html) {
  const match = html.match(/<(main|article)[^>]*>([\s\S]*?)<\/\1>/i);
  return match ? match[2] : html;
}

function strip(fragment) {
  return fragment.replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim();
}
