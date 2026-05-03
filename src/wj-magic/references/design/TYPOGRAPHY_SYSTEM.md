# Typography System — 타이포그래피 체계

## 타이포 스케일 (Type Scale)

일관된 크기 비율로 시각적 위계를 만든다. Major Third (1.25) 또는 Perfect Fourth (1.333) 비율 권장.

| 역할 | 비율 (1.25 기반) | 예시 (base 16px) | Tailwind |
|------|----------------|-----------------|----------|
| Display | ×2.44 | 39px | text-4xl |
| H1 | ×1.95 | 31px | text-3xl |
| H2 | ×1.56 | 25px | text-2xl |
| H3 | ×1.25 | 20px | text-xl |
| Body | ×1.00 | 16px | text-base |
| Small | ×0.80 | 13px | text-sm |
| Caption | ×0.64 | 10px | text-xs |

**규칙:**
- 한 화면에 3~4단계만 사용 (전체 스케일을 다 쓰지 않음)
- 인접 단계 간 최소 1.2배 차이 (구분이 명확해야 함)

## Font Weight 위계

| 용도 | Weight | Tailwind |
|------|--------|----------|
| 페이지 제목 | Bold (700) | font-bold |
| 섹션 제목 | Semibold (600) | font-semibold |
| 강조 텍스트 | Medium (500) | font-medium |
| 본문 | Regular (400) | font-normal |
| 보조 텍스트 | Regular (400) + muted color | font-normal text-muted |

**규칙:**
- weight 3단계 이내로 사용 (너무 많으면 위계가 흐림)
- Bold + 큰 크기 = 최상위 위계. 같은 수단을 중복하지 않음

## Line Height (행간)

| 용도 | 값 | Tailwind |
|------|---|----------|
| 제목 (Display, H1) | 1.1~1.2 | leading-tight |
| 소제목 (H2, H3) | 1.3 | leading-snug |
| 본문 | 1.5~1.6 | leading-relaxed |
| UI 라벨/버튼 | 1.0~1.2 | leading-none ~ leading-tight |

## 가독성 규칙

- 본문 줄 길이: 45~75자 (max-w-prose 또는 max-w-2xl)
- 단락 간격: 본문 line-height의 0.5~1배
- 텍스트 정렬: 본문은 left-aligned (center는 3줄 이하 짧은 텍스트만)
- 자간(letter-spacing): 제목에만 약간 tight (-0.02em), 본문은 기본값
