---
globs:
  - "**/*.sh"
  - "**/*.bash"
---

## Shell Script Rules

### 필수 헤더

모든 스크립트 첫 줄:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `set -e`: 명령 실패 시 즉시 종료
- `set -u`: 미정의 변수 참조 시 오류
- `set -o pipefail`: 파이프라인 중간 실패도 감지

### 금지 패턴

| 패턴 | 이유 | 대안 |
|------|------|------|
| `rm -rf $VAR` | 변수 미설정 시 루트 삭제 위험 | `rm -rf "${VAR:?변수 필수}"` |
| `cd dir && rm ...` | cd 실패해도 rm 실행 위험 | `set -e`로 자동 보호 |
| `2>/dev/null` 남용 | 에러 은폐 | 필요한 경우만 명시적으로 |
| `eval "$USER_INPUT"` | 인젝션 위험 | 절대 금지 |
| `cat file \| bash` | 원격 코드 실행 위험 | 절대 금지 |

### 변수 작성 규칙

```bash
# 항상 따옴표로 감싸기
echo "$var"             # 공백 포함 변수 안전
echo "${var:-default}"  # 기본값

# 필수 변수 명시
: "${REQUIRED_VAR:?REQUIRED_VAR must be set}"

# 경로 변수는 절대경로로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

### 함수 구조

```bash
# 서브커맨드 패턴 (lib/gate-l1.sh 참고)
main() {
  local cmd="${1:-}"
  case "$cmd" in
    subcommand) _do_something "$@" ;;
    *)          _usage; exit 1 ;;
  esac
}

_do_something() { ... }  # 함수당 20줄 이하
_usage() { echo "Usage: $0 <subcommand>"; }

main "$@"
```

### 에러 처리

```bash
# 에러 메시지는 stderr로
echo "Error: 파일을 찾을 수 없습니다: $file" >&2

# 정리 작업은 trap으로
trap 'rm -f "$TMPFILE"' EXIT

# 실패 시 의미 있는 exit code
exit 1  # 일반 오류
exit 2  # 잘못된 인자
```

### 멱등성 (Idempotency)

스크립트는 여러 번 실행해도 같은 결과여야 한다:
```bash
# 나쁜 예: 두 번 실행하면 중복
mkdir "$DIR"

# 좋은 예: 이미 있으면 건너뜀
mkdir -p "$DIR"

# 파일 존재 확인 후 생성
[[ -f "$FILE" ]] || touch "$FILE"
```

### 크기 제한

- 스크립트 파일: 300줄 이하 (초과 시 lib/ 함수로 분리)
- 함수: 20줄 이하
- 복잡한 로직은 서브커맨드 패턴으로 분리

### Quality Standards

→ `references/common/AGENT_QUICK_REFERENCE.md`
