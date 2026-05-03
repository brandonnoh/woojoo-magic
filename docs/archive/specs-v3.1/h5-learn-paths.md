# h5-learn-paths: learn 스킬 파일 경로 v3 업데이트

## 배경

`skills/learn/skill.md`에 v2 시절 경로가 다수 남아있다.
v3에서 references 디렉토리 구조가 `references/` 플랫 → `references/{common,typescript,...}` 계층으로 변경되었고,
일부 파일명도 달라졌다. 실제 존재하는 파일 경로와 일치시켜야 한다.

## 대상 파일

- `src/wj-magic/skills/learn/skill.md` (현재 127줄)

## 현재 references 디렉토리 구조 (v3)

```
references/
├── INDEX.md
├── common/
│   ├── HIGH_QUALITY_CODE_STANDARDS.md
│   └── REFACTORING_PREVENTION.md
├── typescript/
│   ├── standards.md
│   ├── BRANDED_TYPES_PATTERN.md
│   ├── DISCRIMINATED_UNION.md
│   ├── LIBRARY_TYPE_HARDENING.md
│   ├── NON_NULL_ELIMINATION.md
│   ├── RESULT_PATTERN.md
│   └── ZUSTAND_SLICE_PATTERN.md
├── python/
│   └── standards.md
├── go/
│   └── standards.md
├── rust/
│   └── standards.md
├── swift/
│   └── standards.md
└── kotlin/
    └── standards.md
```

## 변경 내용: 총 7곳 경로 수정

### 수정 1: 줄 12

**현재:**
```
**반드시 참조: `../../references/common/HIGH_QUALITY_CODE_STANDARDS.md`**
```

**변경:** 경로 정상 (v3 구조와 일치). **변경 불필요.**

### 수정 2: 줄 17

**현재:**
```
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/BRANDED_TYPES_PATTERN.md`
```

**변경 후:**
```
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../references/typescript/BRANDED_TYPES_PATTERN.md`
```

**사유:** v3에서 `BRANDED_TYPES_PATTERN.md`는 `references/typescript/` 하위로 이동.

### 수정 3: 줄 18

**현재:**
```
- Result<T,E> 패턴으로 에러 처리 — `../../references/RESULT_PATTERN.md`
```

**변경 후:**
```
- Result<T,E> 패턴으로 에러 처리 — `../../references/typescript/RESULT_PATTERN.md`
```

**사유:** `RESULT_PATTERN.md`는 `references/typescript/` 하위.

### 수정 4: 줄 19

**현재:**
```
- Discriminated Union으로 상태 모델링 — `../../references/DISCRIMINATED_UNION.md`
```

**변경 후:**
```
- Discriminated Union으로 상태 모델링 — `../../references/typescript/DISCRIMINATED_UNION.md`
```

**사유:** `DISCRIMINATED_UNION.md`는 `references/typescript/` 하위.

### 수정 5: 줄 36

**현재:**
```
**상세: `../../references/REFACTORING_PREVENTION.md`**
```

**변경 후:**
```
**상세: `../../references/common/REFACTORING_PREVENTION.md`**
```

**사유:** `REFACTORING_PREVENTION.md`는 `references/common/` 하위.

### 수정 6: 줄 62-63 (교훈 분류 테이블)

**현재:**
```
| **기술 상세** | `devrule/references/WEB_DEV_REFERENCE.md` | API 사용법, 주의사항 |
| **트러블슈팅 상세** | `devrule/references/TROUBLESHOOTING.md` | 디버깅 과정, 재현 조건, 스택트레이스 |
```

**변경 후:**
```
| **기술 상세** | `devrule/references/MACOS_DEV_REFERENCE.md` | API 사용법, 주의사항 |
| **트러블슈팅 상세** | `devrule/references/TROUBLESHOOTING.md` | 디버깅 과정, 재현 조건, 스택트레이스 |
```

**사유:** 실제 파일은 `MACOS_DEV_REFERENCE.md`이며, `WEB_DEV_REFERENCE.md`는 존재하지 않는다.
`devrule/references/` 경로 자체는 정확 (devrule 스킬 자체의 references 디렉토리).
TROUBLESHOOTING.md는 경로 정상.

### 수정 7: 줄 116-118 (대상 파일 경로 섹션)

**현재:**
```
- `/.claude/skills/devrule/skill.md` — 메인 개발 규칙
- `/.claude/skills/devrule/references/WEB_DEV_REFERENCE.md` — 기술 개발 레퍼런스
- `/.claude/skills/devrule/references/TROUBLESHOOTING.md` — 트러블슈팅 상세
```

**변경 후:**
```
- `/.claude/skills/devrule/skill.md` — 메인 개발 규칙
- `/.claude/skills/devrule/references/MACOS_DEV_REFERENCE.md` — 기술 개발 레퍼런스
- `/.claude/skills/devrule/references/TROUBLESHOOTING.md` — 트러블슈팅 상세
```

**사유:** `WEB_DEV_REFERENCE.md` → `MACOS_DEV_REFERENCE.md` (실제 파일명 반영).

## 변경 요약 테이블

| 줄 | 현재 경로 | 변경 후 | 사유 |
|----|----------|---------|------|
| 12 | `../../references/common/HIGH_QUALITY_CODE_STANDARDS.md` | (변경 없음) | 이미 v3 경로 |
| 17 | `../../references/BRANDED_TYPES_PATTERN.md` | `../../references/typescript/BRANDED_TYPES_PATTERN.md` | typescript/ 하위로 이동 |
| 18 | `../../references/RESULT_PATTERN.md` | `../../references/typescript/RESULT_PATTERN.md` | typescript/ 하위로 이동 |
| 19 | `../../references/DISCRIMINATED_UNION.md` | `../../references/typescript/DISCRIMINATED_UNION.md` | typescript/ 하위로 이동 |
| 36 | `../../references/REFACTORING_PREVENTION.md` | `../../references/common/REFACTORING_PREVENTION.md` | common/ 하위로 이동 |
| 62 | `devrule/references/WEB_DEV_REFERENCE.md` | `devrule/references/MACOS_DEV_REFERENCE.md` | 파일명 변경 |
| 117 | `/.claude/skills/devrule/references/WEB_DEV_REFERENCE.md` | `/.claude/skills/devrule/references/MACOS_DEV_REFERENCE.md` | 파일명 변경 |

## 의존성

- 없음. 마크다운 텍스트 수정만.

## 수락 조건

1. 줄 17의 `references/BRANDED_TYPES_PATTERN.md` → `references/typescript/BRANDED_TYPES_PATTERN.md`
2. 줄 18의 `references/RESULT_PATTERN.md` → `references/typescript/RESULT_PATTERN.md`
3. 줄 19의 `references/DISCRIMINATED_UNION.md` → `references/typescript/DISCRIMINATED_UNION.md`
4. 줄 36의 `references/REFACTORING_PREVENTION.md` → `references/common/REFACTORING_PREVENTION.md`
5. 줄 62의 `WEB_DEV_REFERENCE.md` → `MACOS_DEV_REFERENCE.md`
6. 줄 117의 `WEB_DEV_REFERENCE.md` → `MACOS_DEV_REFERENCE.md`
7. 줄 12 (`common/HIGH_QUALITY_CODE_STANDARDS.md`) 변경 없음 확인
8. 줄 63, 118 (`TROUBLESHOOTING.md`) 변경 없음 확인
9. 모든 변경된 경로가 실제 파일 시스템에 존재하는 파일을 가리킴
