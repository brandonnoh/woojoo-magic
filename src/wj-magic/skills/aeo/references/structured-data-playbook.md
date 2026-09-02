# L4 — 구조화 데이터 플레이북 (JSON-LD / schema.org)

스키마는 **성장 해킹이 아니라 인프라**다. 스키마 자체가 순위를 올리는 게 아니라,
기계가 "이 페이지가 무엇에 관한 것이고 누가 썼는가"를 **모호함 없이** 파악하게 한다.
답변 엔진이 인용할 출처를 고를 때 이 명확성이 신뢰 신호로 작동한다.

## 0. 절대 규칙 4가지

1. **JSON-LD 형식**, `<script type="application/ld+json">` — Microdata/RDFa 대신
2. **서버 렌더 필수** — 클라이언트에서 주입하면 AI 크롤러는 못 읽는다 (L2 참조)
3. **본문에 보이는 내용만 기술** — 화면에 없는 FAQ를 스키마에만 넣으면 신뢰 손상
4. **`@id`로 엔티티를 연결** — 페이지 간 같은 조직/저자는 같은 `@id`를 재사용

## 1. GEO 임팩트 순위 (실제 인용에 기여하는 순)

| 순위 | 타입 | 왜 효과적인가 |
|---|---|---|
| 1 | `FAQPage` | Q&A 쌍 자체가 **자기완결 청크**. 대화형 질의와 1:1 매칭 |
| 2 | `Article` / `BlogPosting` / `NewsArticle` | 저자·발행일·수정일·발행처 — 신뢰 판단의 핵심 필드 |
| 3 | `Organization` | 브랜드 엔티티 확립. `sameAs`가 지식 그래프 연결점 |
| 4 | `Person` | 저자 권위(E-E-A-T)의 기계 판독 형태 |
| 5 | `HowTo` | 절차형 질의의 정답 포맷 |
| 6 | `Product` / `Offer` / `AggregateRating` | 커머스 질의·에이전트 쇼핑의 진입점 |
| 7 | `BreadcrumbList` | 사이트 구조·주제 계층 전달 |
| 8 | `WebSite` + `SearchAction` | 사이트 검색 노출 |
| 9 | `Dataset` / `SoftwareApplication` / `MedicalWebPage` 등 버티컬 타입 | 도메인 특이 신뢰 신호 |

`SpeakableSpecification`은 음성 답변 후보 지정에 쓰이지만 지원 범위가 좁다 — 선택.

## 2. 최소 완성형 세트 (콘텐츠형 서비스)

모든 아티클 페이지에 아래 4개를 `@graph`로 묶어 한 블록에 넣는다.

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Article",
      "@id": "https://example.com/guide/x#article",
      "headline": "임신성 당뇨 공복혈당 기준",
      "description": "공복 92mg/dL 기준과 판정 절차를 정리했습니다.",
      "datePublished": "2026-03-01T09:00:00+09:00",
      "dateModified": "2026-09-01T10:00:00+09:00",
      "author": { "@id": "https://example.com/authors/hong#person" },
      "publisher": { "@id": "https://example.com/#org" },
      "isPartOf": { "@id": "https://example.com/#website" },
      "mainEntityOfPage": "https://example.com/guide/x",
      "citation": [
        { "@type": "CreativeWork", "name": "대한당뇨병학회 2023 진료지침",
          "url": "https://example.org/guideline" }
      ],
      "inLanguage": "ko"
    },
    {
      "@type": "Person",
      "@id": "https://example.com/authors/hong#person",
      "name": "홍길동",
      "jobTitle": "산부인과 전문의",
      "url": "https://example.com/authors/hong",
      "sameAs": ["https://www.linkedin.com/in/..."]
    },
    {
      "@type": "Organization",
      "@id": "https://example.com/#org",
      "name": "서비스명",
      "url": "https://example.com",
      "logo": "https://example.com/logo.png",
      "sameAs": [
        "https://www.wikidata.org/wiki/Q...",
        "https://www.linkedin.com/company/...",
        "https://www.instagram.com/..."
      ]
    },
    {
      "@type": "WebSite",
      "@id": "https://example.com/#website",
      "name": "서비스명",
      "url": "https://example.com",
      "inLanguage": "ko"
    }
  ]
}
</script>
```

`FAQPage`는 실제 FAQ 섹션이 화면에 있을 때만 추가한다:

```json
{
  "@type": "FAQPage",
  "mainEntity": [{
    "@type": "Question",
    "name": "임신성 당뇨 공복혈당 기준은 얼마인가요?",
    "acceptedAnswer": {
      "@type": "Answer",
      "text": "공복혈당 92mg/dL 이상이면 임신성 당뇨로 진단합니다. 75g 경구당부하검사에서 1시간 180mg/dL, 2시간 153mg/dL 중 하나라도 넘으면 진단됩니다."
    }
  }]
}
```

> `acceptedAnswer.text`는 **본문의 직답 블록과 같은 문장**을 쓴다.
> 스키마와 본문이 서로를 보강하는 구조가 가장 강하다.

## 3. 프로파일별 추가 타입

| 프로파일 | 추가 |
|---|---|
| `docs` | `TechArticle`, `APIReference`, `SoftwareApplication`, `HowTo` |
| `commerce` | `Product`, `Offer`, `AggregateRating`, `Review`, `Brand`, `ItemList` |
| `saas-api` | `SoftwareApplication`, `WebAPI`, `Organization`, `Offer`(플랜) |
| 의료 | `MedicalWebPage`, `MedicalCondition`, `Physician`, `MedicalDisclaimer` |
| 지역 | `LocalBusiness`, `PostalAddress`, `OpeningHoursSpecification` |
| 커뮤니티 | `DiscussionForumPosting`, `Comment`, `InteractionCounter` |

## 4. 검증

```bash
# 1) raw HTML에서 JSON-LD 추출 (서버 렌더 여부 동시 확인)
curl -sS https://example.com/page | grep -o 'application/ld+json' | wc -l

# 2) 파싱 유효성 + @type 수집 — scripts/aeo-content-audit.sh가 자동 수행
```

- Google Rich Results Test / Schema.org Validator로 문법 검증
- **@id 연결이 끊긴 스키마**(author를 문자열로만 표기)는 엔티티 그래프에 기여하지 않는다
- 페이지마다 스키마 블록을 여러 개 흩뿌리지 말고 `@graph` 하나로 모은다

## 5. 안티패턴

| 안티패턴 | 결과 |
|---|---|
| 화면에 없는 FAQ를 스키마에만 | 정책 위반 + 신뢰 손상 |
| `author`를 문자열로만 | 엔티티 연결 실패. `Person` 객체 + `@id` 사용 |
| `dateModified`를 매일 자동 갱신 | 허위 신선도. 신뢰 손상 |
| 클라이언트 JS로 주입 | AI 크롤러가 못 읽음 (효과 0) |
| 모든 페이지에 동일 `Organization`만 | 페이지 주제 정보가 없음. `Article` 필수 |
| `sameAs` 없음 | 브랜드 엔티티가 지식 그래프에 연결되지 않음 |
