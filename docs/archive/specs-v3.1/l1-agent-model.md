# l1-agent-model: 에이전트 모델 버전 중앙 관리

> 우선순위: LOW
> 날짜: 2026-04-13

## 현황

5개 에이전트 파일에 `model:` 필드가 frontmatter에 하드코딩되어 있다.
모델 버전을 업데이트하려면 5개 파일을 모두 수동 편집해야 한다.

### 현재 값

| 파일 | 라인 | 현재 값 | 비고 |
|------|------|---------|------|
| `src/wj-magic/agents/frontend-dev.md` | **3행** | `model: claude-opus-4-6` | |
| `src/wj-magic/agents/backend-dev.md` | **3행** | `model: claude-opus-4-6` | |
| `src/wj-magic/agents/engine-dev.md` | **3행** | `model: claude-opus-4-6` | |
| `src/wj-magic/agents/qa-reviewer.md` | **3행** | `model: claude-opus-4-6` | |
| `src/wj-magic/agents/docs-keeper.md` | **3행** | `model: claude-sonnet-4-6` | 의도적으로 sonnet 사용 (비용 절감) |

## 문제

1. 모델 버전 업데이트 시 5개 파일을 각각 수정해야 함 (누락 위험)
2. 어떤 에이전트가 어떤 모델을 쓰는지 한눈에 파악 불가
3. `docs-keeper`만 `sonnet`을 쓰는 이유가 문서화되어 있지 않음

## 변경 방안

### 방안 A: 각 에이전트 파일 상단에 주석 추가 (최소 변경)

각 에이전트 `.md` 파일의 frontmatter `---` 바로 아래(2행)에 주석을 추가한다.

**frontend-dev.md, backend-dev.md, engine-dev.md, qa-reviewer.md** (4개 파일 동일 패턴):

```diff
 ---
+# [모델 정책] opus = 개발/리뷰 에이전트 기본 모델. 변경 시 5개 파일 동기화 필요.
 name: frontend-dev
 model: claude-opus-4-6
```

**docs-keeper.md** (1개 파일):

```diff
 ---
+# [모델 정책] sonnet = 문서 전용 에이전트 (비용 효율). opus 에이전트와 의도적으로 다름.
 name: docs-keeper
 model: claude-sonnet-4-6
```

### 방안 B: 중앙 설정 파일 도입 (구조 변경)

`src/wj-magic/agents/_config.yaml` 신규 생성:

```yaml
# 에이전트 모델 정책
# - dev/review 에이전트: opus (고품질 코드 생성/리뷰 필요)
# - docs 에이전트: sonnet (문서 작업은 비용 효율 우선)
defaults:
  model: claude-opus-4-6

overrides:
  docs-keeper:
    model: claude-sonnet-4-6
    reason: "문서 동기화는 비용 효율이 우선. 코드 생성 품질 불필요."
```

단, Claude Code 플러그인 시스템이 에이전트 `.md` frontmatter의 `model:` 필드를 직접 읽으므로, `_config.yaml`은 **사람이 참조하는 문서 역할**만 한다. 실제 모델 변경은 여전히 각 `.md` 파일을 수정해야 한다.

## 권장

**방안 A 채택**. 이유:
- 플러그인 시스템이 frontmatter를 직접 파싱하므로 중앙 설정 파일은 런타임 효과 없음
- 주석으로 정책을 명시하면 다음 모델 업데이트 시 누락 방지 가능
- 최소 변경으로 목적 달성

## 수정 대상 (방안 A 기준)

### 1. `src/wj-magic/agents/frontend-dev.md` — 1행 뒤에 주석 삽입

**현재 (1~3행):**
```
---
name: frontend-dev
model: claude-opus-4-6
```

**변경 후 (1~4행):**
```
---
# [모델 정책] opus = 개발/리뷰 에이전트 기본 모델. 변경 시 5개 파일 동기화 필요.
name: frontend-dev
model: claude-opus-4-6
```

### 2. `src/wj-magic/agents/backend-dev.md` — 1행 뒤에 주석 삽입

**현재 (1~3행):**
```
---
name: backend-dev
model: claude-opus-4-6
```

**변경 후 (1~4행):**
```
---
# [모델 정책] opus = 개발/리뷰 에이전트 기본 모델. 변경 시 5개 파일 동기화 필요.
name: backend-dev
model: claude-opus-4-6
```

### 3. `src/wj-magic/agents/engine-dev.md` — 1행 뒤에 주석 삽입

**현재 (1~3행):**
```
---
name: engine-dev
model: claude-opus-4-6
```

**변경 후 (1~4행):**
```
---
# [모델 정책] opus = 개발/리뷰 에이전트 기본 모델. 변경 시 5개 파일 동기화 필요.
name: engine-dev
model: claude-opus-4-6
```

### 4. `src/wj-magic/agents/qa-reviewer.md` — 1행 뒤에 주석 삽입

**현재 (1~3행):**
```
---
name: qa-reviewer
model: claude-opus-4-6
```

**변경 후 (1~4행):**
```
---
# [모델 정책] opus = 개발/리뷰 에이전트 기본 모델. 변경 시 5개 파일 동기화 필요.
name: qa-reviewer
model: claude-opus-4-6
```

### 5. `src/wj-magic/agents/docs-keeper.md` — 1행 뒤에 주석 삽입

**현재 (1~3행):**
```
---
name: docs-keeper
model: claude-sonnet-4-6
```

**변경 후 (1~4행):**
```
---
# [모델 정책] sonnet = 문서 전용 에이전트 (비용 효율). opus 에이전트와 의도적으로 다름.
name: docs-keeper
model: claude-sonnet-4-6
```

## 검증

- 5개 파일 모두 `model:` 라인이 유지되는지 확인
- `docs-keeper`만 `claude-sonnet-4-6`인지 확인
- 나머지 4개가 동일한 `claude-opus-4-6`인지 확인
