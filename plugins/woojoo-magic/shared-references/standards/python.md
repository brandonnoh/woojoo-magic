# Python Standards (Silicon Valley 2026)

> 공통 원칙은 `HIGH_QUALITY_CODE_STANDARDS.md` 참조. 이 문서는 Python 전용 규칙.
> 2026년 기준: Ruff + Pyright strict + EAFP + Structural Typing이 de facto 표준.

---

## 0. 철학

Python은 TS가 아니다. **관용구(idioms)는 그대로 존중**하되 안전성 장치는 최대로:

- 예외는 Python의 네이티브 제어 흐름 → Result 강요 X, **EAFP + 경계 규율**
- 타입 힌트는 선택이 아닌 필수 → **Pyright strict**
- 줄 수보다 **Cyclomatic Complexity**로 복잡도 판단
- Immutable by default → `@dataclass(frozen=True, slots=True)`

---

## 1. 툴체인 (사실상 단일화)

| 도구 | 역할 | 설정 |
|------|------|------|
| **Ruff** | lint + format (Black/isort/flake8/pyupgrade 통합) | `ruff check`, `ruff format` |
| **Pyright** | 타입 체크 (strict) | `pyright --strict` |
| **pytest + pytest-cov** | 테스트 + 커버리지 | `--cov-fail-under=80` |
| **pre-commit** | 커밋 전 자동 검증 | `.pre-commit-config.yaml` |

### `pyproject.toml` 권장 설정

```toml
[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = [
  "E", "F", "W",       # pycodestyle + pyflakes
  "I",                  # isort
  "N",                  # pep8-naming
  "UP",                 # pyupgrade
  "B",                  # flake8-bugbear
  "C90",                # mccabe complexity
  "SIM",                # flake8-simplify
  "TCH",                # flake8-type-checking
  "RUF",                # ruff-specific
  "ANN",                # flake8-annotations
  "S",                  # flake8-bandit (security)
  "PTH",                # flake8-use-pathlib
  "ERA",                # eradicate commented code
]
ignore = ["ANN101", "ANN102"]  # self, cls 타입 힌트 생략 허용

[tool.ruff.lint.mccabe]
max-complexity = 10

[tool.pyright]
typeCheckingMode = "strict"
reportMissingTypeStubs = true
reportUnknownMemberType = true
```

---

## 2. 타입 안전성 — **Any 전면 금지**

### `Any` 금지 (TS `any`와 동치)
```python
# ❌ def process(data: Any) -> Any: ...
# ✅ def process(data: dict[str, int]) -> Result: ...
# ✅ 진짜 모를 때는 object (런타임 체크 강제)
def process(data: object) -> Result:
    if not isinstance(data, dict):
        raise TypeError(...)
```

### NewType — Branded Types 대응
```python
from typing import NewType

UserId = NewType("UserId", str)
SessionId = NewType("SessionId", str)
Money = NewType("Money", int)

def as_money(value: int) -> Money:
    if value < 0:
        raise ValueError("Money cannot be negative")
    return Money(value)

# ❌ def transfer(from_: str, to: str, amount: int): ...
# ✅ def transfer(from_: UserId, to: UserId, amount: Money): ...
#    → Pyright가 인자 순서 오류를 컴파일 타임에 감지
```

### Protocol — 구조적 서브타이핑 (2026 표준)
```python
from typing import Protocol

class Repository(Protocol):
    def find(self, id: UserId) -> User | None: ...
    def save(self, user: User) -> None: ...

# 상속 없이 duck typing + 타입 안전
def service(repo: Repository) -> None: ...
```

### Literal + Discriminated Union
```python
from dataclasses import dataclass
from typing import Literal

@dataclass(frozen=True, slots=True)
class Draft:
    kind: Literal["draft"] = "draft"

@dataclass(frozen=True, slots=True)
class Processing:
    kind: Literal["processing"] = "processing"
    started_at: int = 0

@dataclass(frozen=True, slots=True)
class Shipped:
    kind: Literal["shipped"] = "shipped"
    tracking_id: str = ""

OrderPhase = Draft | Processing | Shipped

# Structural pattern matching (Python 3.10+)
match phase:
    case Draft():
        ...
    case Processing(started_at=t):
        ...
    case Shipped(tracking_id=tid):
        ...
```

---

## 3. 불변성 & 데이터 모델

### `@dataclass(frozen=True, slots=True)` 기본값
```python
from dataclasses import dataclass

@dataclass(frozen=True, slots=True, kw_only=True)
class User:
    id: UserId
    balance: Money
    name: str

# 불변 업데이트 (dataclasses.replace)
from dataclasses import replace
updated = replace(user, balance=as_money(user.balance - 10))
```

### Pydantic v2 — 경계 검증
외부 입력(API, DB, 파일) 경계에서만 Pydantic BaseModel 사용. 내부 도메인은 frozen dataclass.

### Mutable default argument 금지
```python
# ❌ def f(x: list = []): ...
# ✅ def f(x: list | None = None): x = x or []
```

---

## 4. 에러 처리 — EAFP + 경계 규율

**Python 주류는 예외 기반(EAFP)**. Result 라이브러리 강요 X. 대신:

### 구체 예외만 catch
```python
# ❌ try: ... except Exception: pass      # silent catch — 금지
# ❌ try: ... except: pass                # bare except — 금지
# ✅
try:
    result = api.fetch(id)
except (TimeoutError, ConnectionError) as e:
    logger.warning("fetch failed", exc_info=e)
    raise FetchError(f"Could not fetch {id}") from e
```

### 규칙
- **bare `except:` 금지** (Ruff E722)
- **`except Exception: pass` 금지** (silent catch — wj의 `!.` 금지와 동치)
- **체인 보존 필수**: `raise NewError(...) from e`
- **도메인 로직은 예외 전파**: catch는 I/O·API 경계에서만
- **커스텀 예외는 도메인별로** (`FetchError`, `ValidationError`, `InsufficientBalanceError`)

### Result 라이브러리 (선택)
팀 합의 시 `returns` 라이브러리 허용 가능. 하지만 **기본은 예외**.

---

## 5. 복잡도 — "줄 수"가 아닌 "Cyclomatic Complexity"

| 지표 | Soft Limit | Hard Limit |
|------|-----------|-----------|
| **Cyclomatic Complexity (C901)** | **10** | 15 |
| 함수 길이 | 30줄 | 50줄 |
| 파일 길이 | 400줄 | 600줄 |
| 클래스 | 400줄 | — |
| 매개변수 | 5개 | 7개 |

**핵심**: 줄 수가 아니라 **분기 경로 수**로 판단. Ruff `C901`로 자동 검출.

```bash
ruff check . --select C901
```

---

## 6. 함수 설계

- **Type hint 100%** — public API는 필수, private도 권장
- **순수 함수 우선** — I/O는 경계 레이어로 밀어내기
- **Guard clause** (early return)
- **매개변수 5개 초과 → dataclass로 묶기**
- **`*args, **kwargs` 최소화** — 타입 안전성 희생

```python
# ❌
def create(name, email, role, tenant, created_at, metadata): ...

# ✅
@dataclass(frozen=True)
class CreateUserInput:
    name: str
    email: str
    role: Role
    tenant: TenantId
    created_at: datetime
    metadata: dict[str, str]

def create(input: CreateUserInput) -> User: ...
```

---

## 7. 모듈 구조

```
src/
├── domain/           # 순수 로직 (I/O 없음, frozen dataclass, 순수 함수)
│   ├── models.py
│   └── rules.py
├── infrastructure/   # I/O 경계 (DB, HTTP, 파일)
│   ├── repository.py
│   └── http_client.py
├── application/      # 유스케이스 (domain + infra 조합)
│   └── services.py
└── interface/        # API/CLI 진입점
    └── api.py
```

**레이어 규칙**: `domain ← application ← interface/infrastructure`. domain은 외부를 모른다.

---

## 8. 테스트

- **pytest** + **pytest-cov** (커버리지 80%+)
- **AAA 패턴** (Arrange-Act-Assert)
- **Fixture > 전역 setup**
- **Mock은 경계에서만** — 도메인 함수는 순수하므로 mock 불필요
- **파라미터화 테스트** (`@pytest.mark.parametrize`) 적극 활용
- **Property-based testing** (hypothesis) — 도메인 규칙 검증

```python
import pytest
from hypothesis import given, strategies as st

@given(st.integers(min_value=0))
def test_money_never_negative(value: int):
    result = as_money(value)
    assert result >= 0
```

---

## 9. 금지 목록

- ❌ `Any` / `# type: ignore` (명시적 사유 없이)
- ❌ `from X import *`
- ❌ Bare `except:` / `except Exception: pass`
- ❌ Mutable default arguments (`def f(x=[])`)
- ❌ `print` 디버깅 잔재 (logging 사용)
- ❌ 전역 가변 상태
- ❌ God class / 복잡도 > 10 함수
- ❌ 주석 처리된 코드 (Ruff ERA로 검출)
- ❌ `os.path` — `pathlib.Path` 사용 (Ruff PTH)

---

## 10. 검증 명령어

```bash
ruff check . --fix
ruff format .
pyright --strict
pytest --cov=src --cov-fail-under=80 --cov-report=term-missing
```

→ `/wj:check`가 Python 프로젝트 감지 시 이 명령어들을 사용.

---

## 11. 코드 리뷰 체크리스트

### 타입 안전성
- [ ] `Any` 0개
- [ ] `# type: ignore` 사유 주석 있음
- [ ] 도메인 식별자는 `NewType`
- [ ] 공개 API는 100% 타입 힌트
- [ ] `Pyright strict` 통과

### 구조
- [ ] Cyclomatic Complexity ≤ 10 (Ruff C901 통과)
- [ ] 함수 30줄 이하 (복잡도 우선)
- [ ] 파일 400줄 이하
- [ ] 매개변수 5개 이하
- [ ] 도메인 레이어에 I/O 없음

### 불변성
- [ ] dataclass는 `frozen=True, slots=True`
- [ ] mutable default argument 없음
- [ ] 전역 가변 상태 없음

### 에러 처리
- [ ] Bare except / silent except 0개
- [ ] 예외 체인 보존 (`raise ... from e`)
- [ ] 도메인 커스텀 예외 사용
- [ ] 경계(I/O)에서만 catch

### 테스트/빌드
- [ ] `ruff check` 통과
- [ ] `ruff format --check` 통과
- [ ] `pyright --strict` 통과
- [ ] `pytest --cov` 80%+

---

## 참고

- [Modern Python Best Practices 2026](https://onehorizon.ai/blog/modern-python-best-practices-the-2026-definitive-guide)
- [Google Python Style Guide](https://google.github.io/styleguide/pyguide.html)
- [Ruff C901 Rule](https://docs.astral.sh/ruff/rules/complex-structure/)
- [ezyang: Algebraic Data Types in Python](https://blog.ezyang.com/2020/10/idiomatic-algebraic-data-types-in-python-with-dataclasses-and-union/)
