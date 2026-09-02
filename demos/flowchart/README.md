# wj-magic / FLOWCHART

> wj-magic 워크플로우 인터랙티브 분기 트리.
> Detroit: Become Human의 플로우차트 화면에서 영감 받음.

![v4.20.0](https://img.shields.io/badge/wj--magic-v4.20.0-00E5FF) ![vite](https://img.shields.io/badge/vite-6-FFD700) ![react](https://img.shields.io/badge/react-19-FF2D7E)

## 무엇

wj-magic이 어떻게 동작하는지 한 화면에서 보여주는 비주얼 가이드.

- **2개 진입점** (아이디어 있음/없음)
- **2개 진입점** + **4개 커맨드** + **19개 스킬** + **26개 에이전트** + **7개 훅** = 58개 노드
- 모든 분기 관계와 다음 단계가 시각화
- 노드 클릭 → 우측 사이드패널에 요약 / 예시 명령어 / 자연어 트리거 / 다음 단계

## 어디에 쓰나

1. **부트캠프 강의 자료** — 강사가 시연하며 "지금 우리는 brainstorm 노드에 있고, 다음은 plan으로 갑니다" 흐름 안내
2. **마케팅 페이지** — wj-magic을 처음 보는 사람한테 "이게 뭐 하는 거" 한 눈에 보여주기
3. **수료생 레퍼런스** — 업무 중 "이거 어떤 스킬이었지?" 빠르게 찾기

## 개발

```bash
npm install
npm run dev    # http://localhost:5173
```

## 배포 (GitHub Pages)

레포 루트에서 `.github/workflows/deploy-flowchart.yml` 워크플로우가 자동 실행되어 `gh-pages`에 푸시.

```bash
# 수동 빌드 확인
npm run deploy:check
```

## 스택

| 영역 | 선택 |
|---|---|
| 빌드 | Vite 6 + TypeScript strict |
| UI | React 19 |
| 스타일 | Tailwind CSS 4 (CSS-first config) |
| 애니메이션 | Framer Motion |
| 폰트 | Inter (본문) + Space Grotesk (제목) + JetBrains Mono (코드·HUD) |
| 그래프 | 자체 SVG (Bezier 곡선 + 커스텀 노드 모양) |

## 데이터 동기화

노드 정의는 `src/data/` 안에 있고, **wj-magic 플러그인의 실제 상태 (`../../src/wj-magic/{commands,skills,agents,hooks}`) 와 수동 동기화**가 원칙. 플러그인 버전이 올라가면 여기도 같이 갱신 (현재 동기화 기준: v4.20.0).

장기적으로는 빌드 타임에 실제 디렉토리에서 추출하는 스크립트로 자동화 예정.

## 디자인 톤

- **DBH 플로우차트** + **레트로 퓨처리즘** 조합
- 칠흑 배경(`#06070a`) + 시안 광원(`#00E5FF`) + 마젠타 액센트(`#FF2D7E`) + 골드 강조(`#FFD700`)
- CRT 스캔라인 + 비네팅 + 가로 스캔 빔 (전역 오버레이)
- 노드 호버 시 글리치 + 글로우 펄스
- 잠긴 노드(아직 BFS로 도달 안 함)는 흐릿 + 노이즈

## 라이선스

MIT — wj-magic 본체와 동일.
