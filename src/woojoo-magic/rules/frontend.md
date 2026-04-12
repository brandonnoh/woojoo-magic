---
globs:
  - "**/client/**/*.ts"
  - "**/client/**/*.tsx"
  - "**/web/**/*.ts"
  - "**/web/**/*.tsx"
  - "**/frontend/**/*.ts"
  - "**/frontend/**/*.tsx"
---

## Frontend Rules

### MCP 필수
- 코드 탐색/수정: **Serena** symbolic tools 우선
- React/Vite/Zustand/Framer Motion/TailwindCSS 등 라이브러리 API: **Context7** 조회 필수

### 스킬 필수
- UI/UX/디자인/컴포넌트 작업: **`ui-ux-pro-max`** 또는 **`senior-frontend`** 스킬 필수 사용
- 개발 완료 후: **`review-code`** 스킬로 QA 필수 (useEffect 의존성, 미사용 import, 선언 순서 등)

### Design System
- 프로젝트에서 정의한 테마 토큰(컬러, 타이포, 스페이싱)만 사용
- 커스텀 인라인 스타일·매직 넘버 지양

### 레이아웃 변경 필수 체크리스트
컴포넌트 위치를 옮기거나 레이아웃 구조를 변경할 때 **코드 작성 전에** 반드시 수행:
1. **뷰포트 높이 예산**: 헤더+패딩 빼고 남는 px 계산 → 자식 합산이 초과하면 설계가 틀림
2. **자식 고정 높이**: 옮길 컴포넌트의 `h-*`, `min-h-*`, `max-h-*` 전부 확인
3. **absolute/fixed 자식**: 부모 `overflow-hidden`이면 `absolute` 요소 잘림
4. **flex shrink**: `flex-col` 안의 `flex-1`은 `min-h-0` 없으면 안 줄어듦
5. **한 번에 설계**: 컴포넌트 하나씩 옮기면서 패치 금지. 전체 설계 후 한 번에 적용

### Architecture
- Store = 오케스트레이션만 → 계산은 별도 순수 모듈로 추출
- 비즈니스 로직을 컴포넌트/Store 인라인 금지
- 프리뷰/스토리북 화면은 실제 프로덕션 컴포넌트 재사용

### Quality Standards (woojoo-magic)
- 파일 300줄, 함수 20줄 이하
- `any`, `!.` 금지 (타입 가드/Result 사용)
- Branded Types로 도메인 식별자 구분
- DU + 전수 검사(exhaustive switch)로 상태 모델링
