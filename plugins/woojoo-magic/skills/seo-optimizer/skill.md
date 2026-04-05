---
name: SEO Optimizer
description: Search Engine Optimization specialist for content strategy, technical SEO, keyword research, and ranking improvements. Use when optimizing website content, improving search rankings, conducting keyword analysis, or implementing SEO best practices. Expert in on-page SEO, meta tags, schema markup, and Core Web Vitals.
---

## 품질 기준 (woojoo-magic 표준)

**반드시 참조: `../../shared-references/HIGH_QUALITY_CODE_STANDARDS.md`**

### 핵심 규칙
- 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드 + guard clause
- Branded Types 적용 (PlayerId, ChipAmount 등) — `../../shared-references/BRANDED_TYPES_PATTERN.md`
- Result<T,E> 패턴으로 에러 처리 — `../../shared-references/RESULT_PATTERN.md`
- Discriminated Union으로 상태 모델링 — `../../shared-references/DISCRIMINATED_UNION.md`
- 같은 패턴 2곳 이상 → 공통 유틸 추출
- CSS animation > JS animation (성능)
- Silent catch 금지

### MCP 필수 사용
- **serena**: 코드 탐색/수정 (symbolic tools)
- **context7**: 라이브러리 API 문서 조회
- **sequential-thinking**: 복잡한 리팩토링 계획

### 리팩토링 방지 시그널
파일 작성 중 다음 징후가 보이면 즉시 분할:
- 파일 200줄 돌파 → 300줄 넘기 전에 SRP 기준 분리
- 함수가 3가지 이상 책임 → 분해
- 같은 패턴 2곳 반복 → 공통 유틸
- Props 5개 초과 → 객체 그룹핑

**상세: `../../shared-references/REFACTORING_PREVENTION.md`**

# SEO Optimizer

Comprehensive guidance for search engine optimization across content, technical implementation, and strategic planning to improve organic search visibility and rankings for web applications.

## When to Use This Skill

Use this skill when:
- Optimizing landing pages and marketing content for search engines
- Conducting keyword research for the project's target market
- Implementing technical SEO improvements
- Creating SEO-friendly meta tags and descriptions
- Auditing the web app for SEO issues
- Improving Core Web Vitals and page speed
- Implementing schema markup (structured data)
- Planning content strategy for organic traffic
- Ensuring legal compliance in SEO messaging

## Legal & Compliance SEO Guidelines

프로젝트의 법적 요구사항을 확인하고, SEO 콘텐츠가 관련 법규를 준수하는지 검토한다.

**일반 원칙:**
- 제품/서비스의 성격을 정확하게 표현
- 과장 광고나 오해를 유발하는 표현 금지
- 프로젝트가 속한 업종의 규제 키워드 파악 및 준수
- 필요 시 면책 조항(disclaimer) 배치
- Meta description에 오해를 유발하는 표현 금지

## SEO Fundamentals

### 1. Keyword Research & Strategy

**Primary Keyword Selection:**
- Focus on search intent (informational, navigational, transactional, commercial)
- Balance search volume with competition
- Consider keyword difficulty and ranking potential
- Target long-tail keywords for quick wins

**Keyword Research Process:**
```
1. 핵심 키워드 도출:
   - 제품/서비스의 핵심 가치를 나타내는 키워드
   - 사용자가 검색할 만한 문제/니즈 기반 키워드

2. 페이지별 키워드 매핑:
   Landing Page: 브랜드 + 핵심 서비스 키워드 (high volume)
   Feature Pages: 기능별 세부 키워드
   Long-tail: 구체적인 사용 사례, 비교, 가이드 키워드

3. 경쟁 분석:
   - 경쟁사의 타겟 키워드 분석
   - 키워드 갭(gap) 발견
   - 차별화 포인트 키워드 선정
```

**다국어 SEO 전략 (해당 시):**
```html
<!-- hreflang 태그로 언어 버전 표시 -->
<link rel="alternate" hreflang="ko" href="https://example.com/ko" />
<link rel="alternate" hreflang="en" href="https://example.com/en" />
<link rel="alternate" hreflang="x-default" href="https://example.com" />
```
- 각 언어별 네이티브 콘텐츠 작성 (자동 번역 지양)
- 언어별 키워드 리서치 별도 수행

**Content Optimization Formula:**
- Primary keyword: 1-2% density (natural placement)
- Include in: Title tag, H1, first paragraph, URL, meta description
- Use semantic variations and related terms
- Maintain natural readability (don't keyword stuff)

### 2. On-Page SEO

**Title Tag Optimization:**
```html
<!-- Good: Descriptive, includes keyword, under 60 characters -->
<title>Brand Name - Core Value Proposition</title>

<!-- Bad: Too long, keyword stuffing -->
<title>Brand Product Service Feature Keyword Keyword Another Keyword</title>
```

**Best Practices:**
- Keep under 60 characters (displayed in SERPs)
- Place primary keyword near the beginning
- Include brand name
- Make compelling and click-worthy
- Unique for every page

**Meta Description:**
```html
<!-- Good: Compelling, includes keywords, call-to-action, 150-160 chars -->
<meta name="description" content="Concise description of what the page offers. Include primary keyword and a clear call-to-action for users.">

<!-- Bad: Too short, no value proposition -->
<meta name="description" content="Welcome to our website">
```

**Header Structure:**
```html
<!-- Proper hierarchy -->
<h1>Primary Page Topic with Keyword</h1>
  <h2>Core Feature or Section</h2>
    <h3>Sub-topic Detail</h3>
    <h3>Sub-topic Detail</h3>
  <h2>Another Major Section</h2>
    <h3>Detail</h3>
```

**URL Structure:**
```
Good URLs:
- /features
- /how-it-works
- /pricing
- /ko/features (Korean version)
- /en/about (English version)

Bad URLs:
- /page?id=abc123&ref=xyz
- /page.php?action=view
- /12345/asdf
```

**Image Optimization:**
```html
<!-- Optimized image -->
<img
  src="/images/feature-preview-800w.webp"
  alt="Descriptive alt text explaining the image content"
  width="800"
  height="600"
  loading="lazy"
/>
```

**Best Practices:**
- Use descriptive, keyword-rich alt text
- Compress images (WebP format preferred)
- Specify dimensions to prevent layout shift
- Use lazy loading for below-fold images

### 3. Content Quality

**E-E-A-T Principles (Experience, Expertise, Authoritativeness, Trust):**
- Demonstrate domain expertise with detailed, accurate content
- Link to authoritative sources and documentation
- Emphasize transparency of product/service
- Show real screenshots and user experiences
- Provide educational content related to the product domain

**Content Length Guidelines:**
- Landing page: 500-1,000 words (concise but informative)
- Feature/How-it-works page: 1,000-2,000 words (detailed)
- Blog/guides: 1,500-2,500 words
- FAQ page: 500-1,000 words

### 4. Technical SEO

**Schema Markup (Structured Data) - WebApplication:**
```json
{
  "@context": "https://schema.org",
  "@type": "WebApplication",
  "name": "Application Name",
  "description": "Application description for search engines",
  "url": "https://example.com",
  "applicationCategory": "ApplicationCategory",
  "operatingSystem": "Web Browser",
  "offers": {
    "@type": "Offer",
    "price": "0",
    "priceCurrency": "USD"
  },
  "author": {
    "@type": "Organization",
    "name": "Organization Name"
  },
  "inLanguage": ["ko", "en"],
  "browserRequirements": "Requires JavaScript. Requires HTML5.",
  "softwareVersion": "1.0"
}
```

**Schema Markup - FAQ:**
```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Frequently asked question?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Clear, concise answer to the question."
      }
    }
  ]
}
```

**Robots.txt Configuration:**
```
User-agent: *
Disallow: /api/
Disallow: /admin/
Disallow: /internal/
Allow: /

Sitemap: https://example.com/sitemap.xml
```

**XML Sitemap Structure:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:xhtml="http://www.w3.org/1999/xhtml">
  <url>
    <loc>https://example.com/</loc>
    <lastmod>2026-03-01</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://example.com/features</loc>
    <lastmod>2026-03-01</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
</urlset>
```

**Canonical Tags:**
```html
<!-- Prevent duplicate content issues -->
<link rel="canonical" href="https://example.com/">

<!-- Handle language variants -->
<link rel="canonical" href="https://example.com/ko">
```

### 5. Social Sharing & OG Tags

**Open Graph Tags:**
```html
<meta property="og:title" content="Page Title - Brand Name">
<meta property="og:description" content="Compelling description for social sharing.">
<meta property="og:image" content="https://example.com/images/og-preview.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:url" content="https://example.com">
<meta property="og:type" content="website">
<meta property="og:locale" content="ko_KR">
<meta property="og:locale:alternate" content="en_US">
<meta property="og:site_name" content="Brand Name">
```

**Twitter Card Tags:**
```html
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="Page Title - Brand Name">
<meta name="twitter:description" content="Compelling description for Twitter sharing.">
<meta name="twitter:image" content="https://example.com/images/twitter-card.png">
```

**OG Image Best Practices:**
- Use 1200x630px (1.91:1 ratio) for universal compatibility
- Include brand logo and clear text
- Make images visually compelling with product screenshots
- Create separate images for different page types

### 6. Core Web Vitals

**Largest Contentful Paint (LCP) - Target: < 2.5s**
- Optimize hero images and above-fold assets
- Use CDN for static assets
- Minimize render-blocking resources
- Implement lazy loading for non-critical assets

**First Input Delay (FID) - Target: < 100ms**
- Minimize JavaScript execution time
- Break up long tasks
- Defer non-critical JavaScript (analytics, social sharing SDK)
- Load application progressively

**Cumulative Layout Shift (CLS) - Target: < 0.1**
- Set size attributes on images and media
- Reserve space for dynamic UI elements before they load
- Avoid inserting dynamic content above existing content

**Page Speed Optimization:**
```html
<!-- Preload critical assets -->
<link rel="preload" href="/fonts/main-font.woff2" as="font" crossorigin>
<link rel="preload" href="/images/hero-image.webp" as="image">

<!-- Defer non-critical scripts -->
<script src="/js/analytics.js" async></script>
<script src="/js/social-share.js" defer></script>
```

### 7. Mobile SEO

**Mobile-First Optimization:**
- Responsive design that works on all screen sizes
- Touch-friendly buttons (minimum 48x48px)
- Readable font sizes (16px minimum)
- Proper viewport configuration
- Fast mobile page speed

**Viewport Configuration:**
```html
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
```

**PWA Meta Tags (for app-like experience):**
```html
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="App Name">
<link rel="apple-touch-icon" href="/icons/apple-touch-icon.png">
<meta name="theme-color" content="#1a1a2e">
```

### 8. Internal Linking Strategy

**Best Practices:**
- Use descriptive anchor text (avoid "click here")
- Link to relevant, contextual pages
- Maintain logical hierarchy and flow

**Example:**
```markdown
Learn more about [how our technology works](/how-it-works)
or [get started for free](/get-started).
```

## SEO Content Checklist

**Before Publishing:**
- [ ] Primary keyword in title tag (under 60 chars)
- [ ] Meta description (150-160 chars, compelling)
- [ ] H1 tag with primary keyword
- [ ] URL slug optimized and readable
- [ ] Images compressed with descriptive alt text
- [ ] Internal links to relevant content
- [ ] External links to authoritative sources
- [ ] Content length appropriate for topic depth
- [ ] Schema markup implemented
- [ ] Mobile-friendly and responsive
- [ ] Page speed optimized (< 3s load time)
- [ ] No broken links
- [ ] Canonical tag set correctly
- [ ] hreflang tags for multilingual versions (if applicable)
- [ ] Open Graph tags with preview image (1200x630px)
- [ ] Twitter Card tags configured
- [ ] Legal/compliance requirements met (if applicable)

## Advanced SEO Strategies

### Topic Clusters & Pillar Pages

**Structure:**
```
Pillar Page: "Complete Guide to [Product/Service Domain]"
  |-- Cluster: "Getting Started with [Product]"
  |-- Cluster: "How [Core Feature] Works"
  |-- Cluster: "[Product] Best Practices"
  |-- Cluster: "[Product] vs Alternatives"
  |-- Cluster: "Advanced [Product] Tips"
```

**Implementation:**
- Create comprehensive pillar content (3,000+ words)
- Develop 8-12 cluster articles supporting the pillar
- Link all clusters back to pillar page
- Link pillar page to all clusters
- Use consistent keyword themes

### Featured Snippet Optimization

**Question-Based Content:**
```markdown
## What is [Core Feature]?

[Core Feature] provides [clear, concise explanation in 40-60 words
that directly answers the question with specific details].
```

**List-Based Content:**
```markdown
## How to Get Started with [Product]

1. Create a free account
2. Set up your workspace
3. Configure your preferences
4. Invite your team members
5. Start using [core feature]
```

## Monitoring & Analytics

**Key Metrics to Track:**
- Organic traffic to key pages (by language if multilingual)
- Keyword rankings for target terms
- Click-through rates (CTR) from SERPs
- Bounce rate and dwell time
- Core Web Vitals scores (especially on mobile)
- Conversion rates from organic traffic
- Social share click-through rates (OG/Twitter Card performance)

**Tools:**
- Google Search Console (performance, indexing issues)
- Google Analytics 4 (traffic, behavior, conversions)
- PageSpeed Insights (Core Web Vitals)
- Ahrefs/SEMrush (keywords, backlinks, competition)

When optimizing for SEO, prioritize user experience and value delivery. Ensure all content accurately represents the product/service and complies with relevant regulations.
