# Go Standards (Silicon Valley 2026)

> 공통 원칙은 ../common/HIGH_QUALITY_CODE_STANDARDS.md 참조. 이 문서는 Go 전용 규칙.

## 1. 툴체인

| 도구 | 역할 | 명령 |
|------|------|------|
| **golangci-lint** | 메타 린터 (errcheck, gocritic, gocyclo, revive 등) | `golangci-lint run` |
| **go vet** | 컴파일러 수준 정적 분석 | `go vet ./...` |
| **staticcheck** | 고급 정적 분석 (SA/ST/QF) | `staticcheck ./...` |
| **govulncheck** | 의존성 취약점 스캔 | `govulncheck ./...` |

`.golangci.yml`에서 `gocyclo.min-complexity: 10` 설정 필수.

## 2. 에러 처리

Go의 에러는 값이다. **모든 에러를 명시적으로 처리**.

```go
// bad: _ = file.Close()
// good:
if err := file.Close(); err != nil {
    return fmt.Errorf("close config: %w", err)  // %w 필수 (wrapping)
}
// bad: return fmt.Errorf("db failed: %v", err)  // %v는 체인 끊김
// good: return fmt.Errorf("fetch user %s: %w", id, err)
```

### Sentinel Errors & Custom Types
```go
var ErrNotFound = errors.New("not found")

type ValidationError struct{ Field, Message string }
func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation: %s — %s", e.Field, e.Message)
}
// 호출부: errors.Is / errors.As 사용 (== 비교 금지)
```

## 3. 타입 설계

### `interface{}` / `any` 금지 — 제네릭 사용 (Go 1.18+)
```go
// bad: func Filter(items []any, fn func(any) bool) []any
// good:
func Filter[T any](items []T, fn func(T) bool) []T {
    var result []T
    for _, item := range items {
        if fn(item) { result = append(result, item) }
    }
    return result
}
```

### 작은 인터페이스 (1-3 메서드), 소비자 쪽에서 정의
```go
type UserFinder interface {
    FindUser(ctx context.Context, id UserID) (*User, error)
}
```

### NewType 패턴 — 도메인 식별자 필수
```go
type UserID string
type Money  int64
```

## 4. 함수 설계

| 제한 | Soft | Hard |
|------|------|------|
| 함수 길이 | 30줄 | **40줄** |
| 매개변수 | 3개 | **5개** |
| 파일 길이 | 400줄 | **500줄** |
| CC | 8 | **10** |

- **`context.Context`는 반드시 첫 번째 인자**
- Named return parameters 지양 (defer 에러 처리 등 명확한 사유 있을 때만)
- Guard clause (early return) 적극 활용
- 매개변수 초과 시 Options struct로 묶기

```go
type CreateUserInput struct { Name, Email string; Role Role; Tenant TenantID }
func CreateUser(ctx context.Context, input CreateUserInput) (*User, error) { ... }
```

## 5. 동시성

### Goroutine Leak 방지 — context cancellation + errgroup
```go
func process(ctx context.Context) error {
    g, ctx := errgroup.WithContext(ctx)
    g.Go(func() error { return fetchData(ctx) })
    g.Go(func() error { return computeResult(ctx) })
    return g.Wait()
}
```

### Channel 방향 명시
```go
func consume(ch <-chan string) { ... }
func produce(ch chan<- string) { ... }
```

**우선순위**: Channel > errgroup > sync.Mutex (최소화) > sync/atomic

## 6. 프로젝트 구조

```
cmd/           # main 패키지 (진입점)
internal/      # 외부 import 차단 — domain, service, repository
pkg/           # 외부 공개 가능한 라이브러리
api/           # OpenAPI / protobuf 스키마
```

- **작은 패키지** = 한 책임. **순환 의존 금지**.
- **`internal/` 적극 활용**: 외부 노출 불필요한 코드는 반드시 internal
- **패키지명 = 단수 소문자**: `user` (not `users`, `userPkg`)

## 7. 테스트

### Table-Driven Tests (Go 표준)
```go
func TestNewMoney(t *testing.T) {
    tests := []struct{ name string; input int64; wantErr bool }{
        {"valid", 100, false}, {"zero", 0, false}, {"negative", -1, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            _, err := NewMoney(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("NewMoney(%d) err=%v, wantErr=%v", tt.input, err, tt.wantErr)
            }
        })
    }
}
```

- **표준 `testing`** 우선, 필요 시 `testify/assert`
- **`httptest`** — HTTP 핸들러 / **`go-cmp`** — 구조체 비교
- **커버리지 80%+**: `go test -coverprofile=cover.out -coverpkg=./...`

## 8. 금지 목록

- `interface{}` / 타입 파라미터 없는 `any` (제네릭 constraint 내 `any`는 허용)
- `_ = err` (에러 무시)
- `panic()` in library code (main/init에서만 허용)
- `init()` 남용 (테스트 불가능 — 명시적 초기화 함수 사용)
- 전역 가변 상태 (`var db *sql.DB` — 의존성 주입 사용)
- `//nolint` without reason (`//nolint:errcheck // reason` 형식 필수)
- 주석 처리된 코드

## 9. 검증 명령어

```bash
go build ./...
go test ./... -race -coverprofile=cover.out
golangci-lint run
go vet ./...
govulncheck ./...
```

## 10. 코드 리뷰 체크리스트

### 타입 안전성
- [ ] `interface{}` / untyped `any` 0개
- [ ] 도메인 식별자는 NewType (`type UserID string`)
- [ ] 제네릭으로 타입 안전한 컬렉션 연산

### 에러 처리
- [ ] `_ = err` 0개
- [ ] 모든 에러 `%w`로 wrapping
- [ ] `errors.Is` / `errors.As` 사용

### 구조
- [ ] 함수 40줄 이하, CC <= 10
- [ ] 파일 500줄 이하
- [ ] 매개변수 5개 이하
- [ ] `context.Context` 첫 번째 인자
- [ ] 순환 의존 없음

### 동시성
- [ ] goroutine에 context cancellation 적용
- [ ] channel 방향 명시
- [ ] goroutine leak 없음

### 테스트/빌드
- [ ] `go build ./...` 통과
- [ ] `go test -race ./...` 통과
- [ ] `golangci-lint run` 통과
- [ ] 커버리지 80%+
