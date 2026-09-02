# 프레임워크별 배선 가이드

L1~L4를 프레임워크 안에서 어디에 붙이는지. **Context7 MCP로 현재 버전 API를
반드시 재확인**하고 쓴다 — 아래는 배선 위치를 보여주는 뼈대다.

## Next.js (App Router)

### robots · sitemap · llms.txt

```
app/robots.ts          → MetadataRoute.Robots (Content-Signal은 미지원 → 아래 참고)
app/sitemap.ts         → MetadataRoute.Sitemap (lastModified 정확히)
app/llms.txt/route.ts  → Route Handler로 text/plain 반환
```

`Content-Signal`은 `MetadataRoute.Robots` 타입에 없다. 두 가지 선택지:

1. `public/robots.txt`로 정적 파일 관리 (`app/robots.ts` 제거 — 둘 다 있으면 충돌)
2. `app/robots.txt/route.ts`에서 문자열을 직접 반환

```ts
// app/robots.txt/route.ts — Content-Signal까지 담아야 할 때
export function GET(): Response {
  return new Response(BODY, {
    headers: { "content-type": "text/plain; charset=utf-8" },
  });
}
```

### JSON-LD (반드시 서버 컴포넌트에서)

```tsx
// app/guide/[slug]/page.tsx — 'use client' 를 붙이지 않는다
export default async function Page({ params }: PageProps) {
  const doc = await getDoc(params.slug);
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(buildGraph(doc)) }}
      />
      <article>{/* 본문 */}</article>
    </>
  );
}
```

> 클라이언트 컴포넌트에서 주입하면 AI 크롤러가 읽지 못한다. `next/dynamic`의
> `ssr: false`로 감싼 본문도 마찬가지다.

### 메타데이터

```ts
export async function generateMetadata({ params }): Promise<Metadata> {
  const doc = await getDoc(params.slug);
  return {
    title: doc.title,
    description: doc.summary,
    alternates: { canonical: `https://example.com/guide/${params.slug}` },
    openGraph: { title: doc.title, description: doc.summary, type: "article" },
  };
}
```

### Link 헤더 · 마크다운 협상

`next.config.js`의 `headers()`로 Link 헤더를 추가하거나, Cloudflare 앞단에서
Transform Rule로 붙인다(오리진 배포 없이 되돌릴 수 있어 실험에 유리).

## Nuxt 3

```
server/routes/robots.txt.ts       → defineEventHandler로 text/plain
server/routes/llms.txt.ts         → 동일
server/routes/[...].ts            → well-known 라우트
```

JSON-LD는 `useHead({ script: [{ type: 'application/ld+json', innerHTML: ... }] })`를
**서버 렌더 경로에서** 호출한다. `ssr: false` 페이지에서는 효과가 없다.

## Astro

정적 생성이 기본이라 L2가 자연히 해결된다.

```
src/pages/robots.txt.ts     → APIRoute
src/pages/llms.txt.ts       → APIRoute
public/.well-known/*        → 정적 발견 문서
```

JSON-LD는 `.astro` 컴포넌트에 `<script type="application/ld+json" set:html={...}>`.

## SvelteKit

```
src/routes/robots.txt/+server.ts
src/routes/llms.txt/+server.ts
src/routes/.well-known/[...path]/+server.ts
```

JSON-LD는 `+page.svelte`의 `<svelte:head>`에 넣되, 해당 라우트가 SSR로
프리렌더되는지(`export const prerender = true`) 확인한다.

## Express / Hono / FastAPI (오리진 직접 서빙)

```ts
app.get("/.well-known/mcp/server-card.json", (req, res) =>
  res.type("application/json").send(MCP_CARD));
app.get("/.well-known/api-catalog", (req, res) =>
  res.type("application/linkset+json").send(API_CATALOG));
```

마크다운 협상은 미들웨어에서 `Accept` 헤더를 보고 분기하되
**`Vary: Accept`를 반드시 설정**한다.

## 공통 검증 (배포 후 스모크)

```bash
bash scripts/aeo-scan.sh https://example.com --out .dev/aeo/scan.json --quick
python3 scripts/aeo-score.py --scan .dev/aeo/scan.json --profile content \
  --out .dev/aeo/score.json --fail-under 60
```
