---
description: 고품질 코드 표준 적용 명령 (HIGH_QUALITY_CODE_STANDARDS.md 강제 참조)
---

# /wj:standards — 표준 문서 기반 개발 강제 모드

이 커맨드는 Claude에게 **woojoo-magic 고품질 코드 표준을 반드시 준수**하며 작업하도록 지시한다.
이후의 모든 코드 작성·수정·리뷰는 아래 절차를 따른다.

---

## 절차

### 1단계: 표준 문서 로드 (필수)

반드시 다음 파일을 **Read 도구로 직접 읽는다**:

1. `plugins/woojoo-magic/shared-references/HIGH_QUALITY_CODE_STANDARDS.md` (공통 원칙)
2. 프로젝트 언어 감지 후 해당 문서:
   - **TypeScript/JavaScript 감지** (`*.ts`, `*.tsx`, `package.json` 존재) → `plugins/woojoo-magic/shared-references/standards/typescript.md`
   - **Python 감지** (`*.py`, `pyproject.toml`, `requirements.txt`, `setup.py` 존재) → `plugins/woojoo-magic/shared-references/standards/python.md`
   - **둘 다 존재** → 두 문서 모두 로드 (polyglot 프로젝트)
   - **기타 언어** → 공통 원칙만 적용

> 플러그인이 `~/.claude/plugins/`에 설치되어 있을 수 있으니, 현재 프로젝트에 없으면 그 경로도 확인.

### 2단계: 요약 출력

사용자에게 다음 형식으로 로드 결과를 보고:

```
## 📐 woojoo-magic 표준 적용 모드 활성화

**감지된 언어**: TypeScript + Python (polyglot)
**로드된 문서**:
- ✅ HIGH_QUALITY_CODE_STANDARDS.md (공통 원칙)
- ✅ standards/typescript.md
- ✅ standards/python.md

**이후 모든 작업은 다음 규칙을 강제합니다**:

### 공통
- 단일 책임, 타입 안전성, 불변성, Silent failure 금지
- Cyclomatic Complexity ≤ 10
- 빌드/테스트/린트/타입체크 통과 전 "완료" 주장 금지

### TypeScript
- 파일 300줄 / 함수 20줄 / Props 5개 hard limit
- `any` / `!` / silent catch 0개
- Branded Types, Result<T,E>, Discriminated Union

### Python
- Ruff + Pyright strict 통과
- NewType, frozen dataclass + match, EAFP + 경계 catch
- 파일 400줄 / 함수 30줄 (soft), 복잡도 10 (hard)

이 세션이 끝날 때까지 이 표준을 위반하는 코드는 작성하지 않습니다.
```

### 3단계: 작업 모드 전환

이 커맨드 이후로는:

1. **코드 작성 전**: 해당 파일이 어느 표준(TS/Python)에 속하는지 확인
2. **작성 중**: 표준 문서의 규칙을 체크하며 작성
   - 파일 크기 / 복잡도 실시간 모니터링
   - 타입 안전성 규칙 준수
   - 금지 패턴(`any`, `Any`, `!`, bare except, silent catch) 회피
3. **작성 후**:
   - 해당 언어의 코드 리뷰 체크리스트 내부적으로 실행
   - 검증 명령어 실행 (TS: `pnpm turbo build/test/typecheck`, Python: `ruff check && pyright --strict && pytest`)
   - 실패 시 수정 후 재검증
4. **완료 보고**: 체크리스트 통과 여부 명시

### 4단계: 위반 감지 시 대응

작업 중 표준 위반을 발견하면:
- **즉시 중단**하지 말고, 작성 흐름을 끝까지 완료
- 완료 직후 **자가 리뷰 섹션**에서 위반 사항 목록화
- 수정안 제시 후 사용자 승인 하에 리팩토링

단, **명백히 금지된 패턴**(`any`, `!`, bare except, silent catch)은 **처음부터 작성하지 않는다**.

---

## 사용 예시

```
/wj:standards
→ 표준 문서 로드 후, 이어서
"src/auth/login.ts 리팩토링해줘"
→ Claude가 TS 표준에 맞춰 작업
```

```
/wj:standards
→ Python 프로젝트 감지
"fetch_opportunities.py를 소스별로 분리해줘"
→ Claude가 Python 표준(복잡도 10, NewType, frozen dataclass)에 맞춰 분리
```

---

## 주의

- 이 커맨드는 **명시적 활성화**다. 호출하지 않아도 에이전트(frontend-dev 등)는 표준을 참조하지만, `/wj:standards`는 **이번 세션 전체**에 강제 적용한다.
- 사용자가 "빠르게 프로토타입만" 요청 시에는 사용자의 의사를 우선하되, 금지 패턴(`any`, `!`, silent catch)은 여전히 회피한다.
- 로드 실패 시(파일 없음 등) 즉시 사용자에게 보고하고, `/wj:init --force-code`로 복구 제안.
