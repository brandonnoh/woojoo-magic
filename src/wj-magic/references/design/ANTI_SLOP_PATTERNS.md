# Anti-Slop Patterns — AI 제네릭 디자인 안티패턴

LLM이 반복적으로 생성하는 "AI스러운" 디자인 패턴과 그 대안.

---

## AI Slop 패턴 목록

### 1. AI Purple Problem
- **증상**: `indigo-500`, `violet-500`, `purple-500` 그라디언트가 모든 곳에
- **원인**: Tailwind 기본 팔레트 + 훈련 데이터 편향
- **대안**: 프로젝트 도메인에 맞는 브랜드 컬러 정의. 금융=네이비/그린, 헬스=티얼/화이트, 푸드=웜오렌지/크림

### 2. Inter/Roboto Monotony
- **증상**: 모든 프로젝트에 `font-family: Inter` 또는 `Roboto`
- **대안**: 도메인에 맞는 폰트 페어링. 서체 선택에 이유가 있어야 함

### 3. Card Grid Syndrome
- **증상**: 3열 동일 크기 카드 그리드가 모든 섹션의 기본 레이아웃
- **대안**: Bento Grid, 비대칭 레이아웃, 매거진 레이아웃, 리스트 뷰 등 맥락에 맞는 선택

### 4. Gradient Text Abuse
- **증상**: 헤딩마다 `bg-clip-text text-transparent bg-gradient-to-r`
- **대안**: 그라디언트 텍스트는 Hero 영역 1곳만. 나머지는 솔리드 컬러

### 5. Rounded Everything
- **증상**: `rounded-xl`, `rounded-2xl`이 모든 요소에 적용
- **대안**: 의도적 border-radius 체계. 카드=md, 버튼=sm, 인풋=sm, 아바타=full

### 6. Shadow Uniformity
- **증상**: 모든 카드에 동일한 `shadow-lg`
- **대안**: 그림자로 높이(elevation) 표현. 떠있는 요소=강한 그림자, 바닥 요소=없음/약함

### 7. Empty Hero Section
- **증상**: "Welcome to [앱이름]" + 부제 + CTA 버튼. 내용 없는 거대한 여백
- **대안**: 히어로에 실제 가치 제안, 데모, 핵심 기능을 즉시 보여줌

### 8. Emoji as Icon
- **증상**: 기능 설명에 🚀📊💡 이모지를 아이콘 대용으로 사용
- **대안**: Lucide, Heroicons 등 일관된 아이콘 세트. 이모지는 콘텐츠에서만

### 9. Hover-Only Feedback
- **증상**: 모든 인터랙션이 `hover:opacity-80`뿐
- **대안**: hover + focus + active + disabled 상태 모두 디자인. 키보드 포커스 링 필수

### 10. Symmetry Obsession
- **증상**: 모든 것이 center-aligned, 완벽한 좌우 대칭
- **대안**: 의도적 비대칭, left-aligned 텍스트 (가독성 우수), 시각적 무게 균형

---

## 탐지 규칙 (grep 가능)

```
# AI Purple — 보라/인디고 과다 사용
/(indigo|violet|purple)-(400|500|600)/

# 기본 폰트만 사용
/font-(sans|mono)(?!.*font-)/  (커스텀 폰트 미정의)

# 하드코딩 색상
/#[0-9a-fA-F]{3,8}|rgb\(|rgba\(/

# 모든 곳에 같은 radius
/rounded-(xl|2xl|3xl)/  (과다 사용 시)

# 그라디언트 텍스트 남용
/bg-gradient.*text-transparent/  (2회 이상)

# hover만 있는 인터랙션
/hover:.*(?!.*focus:)/
```
