---
name: design
description: >
  새 페이지·랜딩·UI 컴포넌트를 비주얼 방향 설정부터 구현까지 디자인 전 과정을 진행하는 스킬.
  처음부터 새로 만드는 UI 작업에는 반드시 이 스킬을 사용하라.
  "디자인해줘", "UI 만들어줘", "랜딩페이지", "예쁘게 만들어줘", "감각적으로",
  "세련되게", "비주얼 방향", "디자인 기획", "컴포넌트 디자인" 요청에 트리거.
  기존 UI를 고치는 경우는 polish 스킬을 사용하라.
---

**품질 기준**: `../../references/design/DESIGN_QUALITY_STANDARDS.md` 참조 (반드시 Read로 로드)

# Design — 디자인 기획 + 구현 스킬

## 목적

"그냥 만들어줘"가 아닌 **"방향 설정 → 와이어프레임 → 구현 → 리뷰"** 4단계를 강제하여,
AI 제네릭(Slop)이 아닌 의도 있는 디자인을 만든다.

## Step 1: 디자인 레퍼런스 로드

반드시 Read 도구로 로드:
1. `references/design/DESIGN_QUALITY_STANDARDS.md` (필수)
2. `references/design/ANTI_SLOP_PATTERNS.md` (필수)
3. 프로젝트 루트 `DESIGN.md` (있으면)

## Step 2: DESIGN.md 확인

프로젝트 루트에 `DESIGN.md` 존재 여부 확인.
- **있으면**: 토큰(컬러, 타이포, 스페이싱) 로드
- **없으면**: 프로젝트 도메인을 분석하여 DESIGN.md 초안 생성 제안

## Step 3: 디자인 방향 설정

사용자에게 2~3개 미학적 방향을 제안하고 선택 받는다:

```
이 프로젝트에 어울리는 디자인 방향 3가지를 제안합니다:

1. [방향 이름] — [설명] (예: "editorial-minimalist — 여백 중심, 타이포 강조, 뉴트럴 톤")
2. [방향 이름] — [설명]
3. [방향 이름] — [설명]

어떤 방향이 좋으세요? (또는 다른 방향을 알려주세요)
```

방향 제안 시 참고:
- 프로젝트 도메인 (금융, 헬스, 이커머스, 생산성 등)
- 타겟 사용자 (B2B, B2C, 개발자, 일반 사용자)
- ANTI_SLOP_PATTERNS.md의 안티패턴을 피하는 방향

## Step 4: 와이어프레임 레이아웃 시각화

**페이지 단위 작업이면 반드시 이 단계를 거친다.** 단일 컴포넌트(카드, 모달)는 스킵 가능.

상세 가이드: `visual-companion.md` 참조 (반드시 Read로 로드)

### 4-1. 서버 시작

brainstorm 스킬의 시각화 서버를 재사용한다:

```bash
PLUGIN_ROOT="$(dirname "$(dirname "$(cd "$(dirname "$0")" && pwd)")")"
"${PLUGIN_ROOT}/skills/brainstorm/scripts/start-server.sh" --project-dir <프로젝트경로>
```

반환된 `screen_dir`, `state_dir`를 저장하고 사용자에게 URL을 안내한다.

### 4-2. 와이어프레임 A/B/C 안 제시

선택된 디자인 방향을 기반으로 2~3개 레이아웃 안을 회색 박스 와이어프레임으로 작성한다.

- `visual-companion.md`의 `wire-*` CSS 클래스 사용
- 각 안은 카드 형태(`.cards` > `.card[data-choice]`)로 클릭 선택 가능
- 영역 배치·비율·계층만 표현. 색상/이미지/실제 텍스트 금지
- 각 영역에 이름 표기 ("Hero", "Features", "CTA" 등)

HTML 파일을 `screen_dir`에 Write 도구로 저장 (예: `layout-wireframe.html`).

사용자에게: "브라우저에서 레이아웃 안을 확인하고 선택해주세요."

### 4-3. 선택 확인 + 상세화

`state_dir/events` + 터미널 피드백에서 선택 결과 확인.

필요하면 2라운드 (선택된 안의 섹션별 내부 구조 상세 와이어프레임) 진행:
- 예: 히어로 내부 구성, 피처 섹션 카드 배치, 네비게이션 구조

레이아웃 확정 후 다음 단계로 진행.

## Step 5: 규모 판정 + 에이전트 위임

| 규모 | 실행 전략 |
|------|----------|
| S (컴포넌트 1~3개) | Claude 직접 구현 (디자인 레퍼런스 기준) |
| M (페이지 1개 또는 컴포넌트 4~10개) | design-dev 에이전트 위임 |
| L (복수 페이지 또는 디자인 시스템 전체) | design-dev + frontend-dev 병렬 위임 |

에이전트 프롬프트에 반드시 포함:
- 선택된 디자인 방향
- **확정된 와이어프레임 레이아웃** (Step 4에서 선택된 구조)
- DESIGN.md 토큰 (있으면)
- 대상 파일/컴포넌트 범위
- Anti-Slop 체크리스트

## Step 6: 디자인 리뷰

구현 완료 후 design-reviewer 에이전트 투입:
- PASS → 커밋
- WARN → 사용자에게 개선 포인트 보고, 커밋은 가능
- FAIL → design-dev에 수정 재위임 (최대 2회)

## ⚡ 즉시 실행
