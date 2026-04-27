# Design Visual Companion — 와이어프레임 레이아웃 시각화

브라우저에서 회색 박스 와이어프레임으로 A/B/C 레이아웃 안을 보여주고 사용자가 선택하면 그 구조로 구현에 들어간다.

## 인프라

brainstorm 스킬의 서버를 재사용한다. 별도 서버 없음.

```bash
# 서버 시작 (brainstorm 서버 재사용)
PLUGIN_ROOT="$(dirname "$(dirname "$(cd "$(dirname "$0")" && pwd)")")"
"${PLUGIN_ROOT}/skills/brainstorm/scripts/start-server.sh" --project-dir <프로젝트경로>
```

반환된 `screen_dir`에 HTML을 쓰면 브라우저에 표시된다. 동작 원리는 `brainstorm/visual-companion.md` 참조.

## 언제 사용하나

**반드시 사용**: 페이지 단위 작업 (랜딩, 대시보드, 폼 페이지, 멀티 섹션)
**선택 사용**: 단일 컴포넌트 (카드, 모달, 네비게이션)
**사용 안 함**: 색상/폰트 변경, 스타일 토큰 수정

## 와이어프레임 작성 규칙

1. **회색 박스만** — 색상, 이미지, 실제 텍스트 금지. 모든 영역은 `wire-*` 클래스 사용
2. **레이아웃 구조에 집중** — 영역 배치, 비율, 계층만 표현
3. **2~3개 안** — A/B/C 최대 3개. 각 안에 핵심 차이점 라벨 필수
4. **영역에 이름 표기** — "Hero", "CTA", "Features", "Footer" 등 영역명 텍스트로 표시

## CSS 클래스

frame-template.html의 기존 클래스에 더해, 와이어프레임 전용 패턴:

### 와이어프레임 컨테이너

```html
<div class="wire-page">
  <!-- 한 페이지 레이아웃 전체를 감싸는 컨테이너 -->
</div>
```

### 와이어프레임 블록 (회색 박스)

```html
<!-- 기본 블록 -->
<div class="wire-block" style="height: 60px;">Navigation</div>

<!-- 히어로 영역 -->
<div class="wire-block wire-hero">Hero Section</div>

<!-- 컨텐츠 영역 -->
<div class="wire-block wire-content">Main Content</div>

<!-- 사이드바 -->
<div class="wire-block wire-sidebar">Sidebar</div>

<!-- CTA -->
<div class="wire-block wire-cta">Call to Action</div>

<!-- 푸터 -->
<div class="wire-block wire-footer">Footer</div>
```

### 레이아웃 그리드

```html
<!-- 2컬럼 -->
<div class="wire-row">
  <div class="wire-block wire-content">Main</div>
  <div class="wire-block wire-sidebar">Side</div>
</div>

<!-- 3컬럼 균등 -->
<div class="wire-cols-3">
  <div class="wire-block">Feature 1</div>
  <div class="wire-block">Feature 2</div>
  <div class="wire-block">Feature 3</div>
</div>

<!-- 4컬럼 균등 -->
<div class="wire-cols-4">
  <div class="wire-block">Card 1</div>
  <div class="wire-block">Card 2</div>
  <div class="wire-block">Card 3</div>
  <div class="wire-block">Card 4</div>
</div>
```

### 카드 선택형 (A/B/C 안)

```html
<div class="cards">
  <div class="card" data-choice="a" onclick="toggleSelect(this)">
    <div class="card-image">
      <!-- 여기에 wire-page 와이어프레임 -->
      <div class="wire-page wire-thumb">
        <div class="wire-block" style="height:20px">Nav</div>
        <div class="wire-block wire-hero">Hero</div>
        <div class="wire-cols-3">
          <div class="wire-block">F1</div>
          <div class="wire-block">F2</div>
          <div class="wire-block">F3</div>
        </div>
        <div class="wire-block wire-cta">CTA</div>
      </div>
    </div>
    <div class="card-body">
      <h3>A. 풀 와이드 히어로</h3>
      <p>히어로가 전체 폭 차지, 아래로 피처 3컬럼</p>
    </div>
  </div>
  <!-- B, C 안 동일 구조 -->
</div>
```

## 인라인 스타일 (frame-template에 없는 것)

와이어프레임 전용 스타일은 각 HTML 파일 상단에 `<style>` 블록으로 삽입한다:

```html
<style>
  .wire-page { display: flex; flex-direction: column; gap: 4px; }
  .wire-block {
    background: #d1d5db; border-radius: 4px;
    padding: 12px; text-align: center;
    color: #6b7280; font-size: 0.8rem; font-weight: 500;
    min-height: 40px; display: flex; align-items: center; justify-content: center;
  }
  .wire-hero { min-height: 120px; background: #9ca3af; color: #fff; }
  .wire-content { min-height: 200px; flex: 1; }
  .wire-sidebar { min-height: 200px; min-width: 160px; }
  .wire-cta { min-height: 60px; background: #9ca3af; color: #fff; }
  .wire-footer { min-height: 40px; background: #e5e7eb; }
  .wire-row { display: flex; gap: 4px; }
  .wire-cols-3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 4px; }
  .wire-cols-4 { display: grid; grid-template-columns: repeat(4, 1fr); gap: 4px; }
  .wire-thumb { padding: 8px; font-size: 0.6rem; }
  .wire-thumb .wire-block { padding: 4px; min-height: 16px; }
  .wire-thumb .wire-hero { min-height: 40px; }
  .wire-thumb .wire-content { min-height: 60px; }
  .wire-thumb .wire-sidebar { min-height: 60px; min-width: 60px; }
  .wire-thumb .wire-cta { min-height: 20px; }
</style>
```

## 예시: 랜딩 페이지 A/B/C

```html
<style>/* 위의 와이어프레임 스타일 전체 */</style>

<h2>랜딩 페이지 레이아웃</h2>
<p class="subtitle">회색 박스 = 영역 배치. 클릭해서 선호하는 구조를 선택하세요.</p>

<div class="cards">
  <div class="card" data-choice="a" onclick="toggleSelect(this)">
    <div class="card-image" style="padding:12px; background:var(--bg-tertiary)">
      <div class="wire-page wire-thumb">
        <div class="wire-block" style="height:20px">Nav</div>
        <div class="wire-block wire-hero">Hero — 전체 폭 이미지</div>
        <div class="wire-cols-3">
          <div class="wire-block">Feature</div>
          <div class="wire-block">Feature</div>
          <div class="wire-block">Feature</div>
        </div>
        <div class="wire-block wire-cta">CTA</div>
        <div class="wire-block wire-footer">Footer</div>
      </div>
    </div>
    <div class="card-body">
      <h3>A. 클래식 랜딩</h3>
      <p>풀와이드 히어로 → 3컬럼 피처 → CTA</p>
    </div>
  </div>

  <div class="card" data-choice="b" onclick="toggleSelect(this)">
    <div class="card-image" style="padding:12px; background:var(--bg-tertiary)">
      <div class="wire-page wire-thumb">
        <div class="wire-block" style="height:20px">Nav</div>
        <div class="wire-row">
          <div class="wire-block wire-content">Hero Text<br>+ CTA 버튼</div>
          <div class="wire-block wire-sidebar">Hero Image</div>
        </div>
        <div class="wire-cols-4">
          <div class="wire-block">F1</div>
          <div class="wire-block">F2</div>
          <div class="wire-block">F3</div>
          <div class="wire-block">F4</div>
        </div>
        <div class="wire-block wire-footer">Footer</div>
      </div>
    </div>
    <div class="card-body">
      <h3>B. 스플릿 히어로</h3>
      <p>좌: 텍스트+CTA / 우: 이미지, 아래 4컬럼</p>
    </div>
  </div>

  <div class="card" data-choice="c" onclick="toggleSelect(this)">
    <div class="card-image" style="padding:12px; background:var(--bg-tertiary)">
      <div class="wire-page wire-thumb">
        <div class="wire-block" style="height:20px">Nav</div>
        <div class="wire-block wire-hero">풀스크린 Hero + Overlay Text</div>
        <div class="wire-block wire-content" style="min-height:80px">스크롤 피처 (세로 나열)</div>
        <div class="wire-block wire-cta">CTA</div>
        <div class="wire-block wire-footer">Footer</div>
      </div>
    </div>
    <div class="card-body">
      <h3>C. 이머시브</h3>
      <p>풀스크린 히어로 → 세로 스크롤 피처 → CTA</p>
    </div>
  </div>
</div>
```

## 예시: 대시보드 A/B/C

```html
<h2>대시보드 레이아웃</h2>
<p class="subtitle">관리자 대시보드의 영역 배치를 선택하세요.</p>

<div class="cards">
  <div class="card" data-choice="a" onclick="toggleSelect(this)">
    <div class="card-image" style="padding:12px; background:var(--bg-tertiary)">
      <div class="wire-page wire-thumb">
        <div class="wire-block" style="height:20px">Top Nav</div>
        <div class="wire-row">
          <div class="wire-block wire-sidebar">Side Nav</div>
          <div style="flex:1; display:flex; flex-direction:column; gap:4px">
            <div class="wire-cols-4">
              <div class="wire-block">KPI</div>
              <div class="wire-block">KPI</div>
              <div class="wire-block">KPI</div>
              <div class="wire-block">KPI</div>
            </div>
            <div class="wire-block wire-content">차트 / 테이블</div>
          </div>
        </div>
      </div>
    </div>
    <div class="card-body">
      <h3>A. 사이드바 + 탑바</h3>
      <p>고정 사이드바, 상단 KPI 카드, 메인 차트</p>
    </div>
  </div>

  <div class="card" data-choice="b" onclick="toggleSelect(this)">
    <div class="card-image" style="padding:12px; background:var(--bg-tertiary)">
      <div class="wire-page wire-thumb">
        <div class="wire-block" style="height:20px">Top Nav + Tabs</div>
        <div class="wire-cols-3">
          <div class="wire-block">KPI</div>
          <div class="wire-block">KPI</div>
          <div class="wire-block">KPI</div>
        </div>
        <div class="wire-row">
          <div class="wire-block wire-content">차트</div>
          <div class="wire-block wire-content">차트</div>
        </div>
        <div class="wire-block wire-content">테이블</div>
      </div>
    </div>
    <div class="card-body">
      <h3>B. 탭 네비게이션</h3>
      <p>사이드바 없이 탭으로 전환, 넓은 컨텐츠</p>
    </div>
  </div>
</div>
```

## 루프

1. 서버 시작 → 사용자에게 URL 안내
2. 와이어프레임 HTML 작성 → `screen_dir`에 저장 (예: `layout-wireframe.html`)
3. 사용자에게 "브라우저에서 레이아웃 안을 확인하고 선택해주세요" 안내
4. `state_dir/events` + 터미널 피드백 확인
5. 선택된 안 확정 → 필요하면 상세 와이어프레임 (섹션별 내부 구조) 추가 라운드
6. 확정 후 구현 단계로 전환 → 서버는 계속 유지 (구현 중간 프리뷰에도 활용 가능)
