/**
 * wellknown.worker.js
 * 오리진 라우팅을 건드리지 않고 발견 문서(well-known)를 서빙하는 Worker.
 * templates/*.tmpl 을 실제 값으로 채운 뒤 아래 상수에 붙여넣는다.
 *
 * 원칙: 빈 껍데기를 배포하지 않는다. 카드 뒤에 실제 서버가 있어야 한다.
 */

import MCP_CARD from "./mcp-server-card.json";
import A2A_CARD from "./a2a-agent-card.json";
import API_CATALOG from "./api-catalog.json";
import AI_CATALOG from "./ai-catalog.json";
import SKILLS_INDEX from "./agent-skills-index.json";
import PRM from "./oauth-protected-resource.json";

const JSON_TYPE = "application/json; charset=utf-8";

const ROUTES = new Map([
  ["/.well-known/mcp/server-card.json", [MCP_CARD, JSON_TYPE]],
  ["/.well-known/agent-card.json", [A2A_CARD, JSON_TYPE]],
  ["/.well-known/agent-skills/index.json", [SKILLS_INDEX, JSON_TYPE]],
  ["/.well-known/api-catalog", [API_CATALOG, "application/linkset+json"]],
  ["/.well-known/ai-catalog.json", [AI_CATALOG, JSON_TYPE]],
  ["/.well-known/oauth-protected-resource", [PRM, JSON_TYPE]],
]);

export default {
  async fetch(request) {
    const { pathname } = new URL(request.url);
    const route = ROUTES.get(pathname);
    if (!route) return fetch(request);
    const [document, contentType] = route;
    return new Response(JSON.stringify(document, null, 2), {
      headers: {
        "content-type": contentType,
        // ARD는 CORS 허용이 요건이다. 나머지도 허용해두면 브라우저 에이전트가 읽는다.
        "access-control-allow-origin": "*",
        "cache-control": "public, max-age=300",
      },
    });
  },
};
