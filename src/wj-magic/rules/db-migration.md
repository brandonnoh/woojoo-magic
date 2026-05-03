---
globs:
  - "**/migrations/**"
  - "**/*.migration.ts"
  - "**/*.migration.js"
  - "**/*.migration.sql"
  - "**/*.migrate.ts"
  - "**/db/migrate/**"
  - "**/database/migrations/**"
---

## DB Migration Rules

> 마이그레이션은 되돌리기 어렵다. 프로덕션 데이터를 날리면 복구할 수 없다.
> 작성 전 이 체크리스트를 반드시 확인한다.

### 절대 금지

- **기존 마이그레이션 파일 수정 금지** — 이미 적용된 마이그레이션을 변경하면 다른 환경과 불일치 발생. 새 파일을 추가하라.
- **`down()` 없는 마이그레이션 금지** — 롤백 불가 마이그레이션은 배포 사고를 블로킹한다.
- **`CASCADE DELETE`를 `up()`에서 즉시 추가 금지** — 기존 데이터 관계 파악 후 단계적으로.

### 필수 확인 (코드 작성 전)

1. **롤백 계획**: `down()`이 `up()`을 완전히 되돌리는가?
2. **데이터 보존**: `up()`에서 기존 데이터가 소멸되지 않는가?
   - 컬럼 삭제 → `nullable` 먼저, 1~2 배포 후 삭제
   - 타입 변경 → 새 컬럼 추가 → 데이터 복사 → 기존 컬럼 삭제 (3단계)
3. **트랜잭션**: DDL을 지원하는 DB(PostgreSQL 등)에서 `knex.transaction` 또는 `BEGIN/COMMIT` 감쌌는가?
4. **인덱스 성능**: 새 인덱스 추가 시 `EXPLAIN ANALYZE` 또는 `CONCURRENTLY` 옵션 검토했는가?
5. **락 위험**: 대용량 테이블의 `ALTER TABLE`은 Lock을 건다 → `LOCK_TIMEOUT` 설정 또는 배치 전략 수립

### 파괴적 작업 체크리스트

컬럼/테이블 삭제, 타입 변경, NOT NULL 추가 시 반드시 수행:

```
[ ] 프로덕션 해당 테이블 레코드 수 확인 (대용량 = Lock 위험)
[ ] 해당 컬럼/테이블을 참조하는 코드 전수 검색 (grep)
[ ] 애플리케이션 코드를 먼저 수정 → 마이그레이션 적용 순서 확인
[ ] 스테이징 환경 데이터 복사본에서 테스트 실행
[ ] 롤백 시나리오 실제 테스트
```

### NOT NULL 컬럼 추가 패턴

기존 레코드가 있는 테이블에 NOT NULL 컬럼 추가 시:
```sql
-- 잘못된 방법 (기존 레코드 오류)
ALTER TABLE users ADD COLUMN role TEXT NOT NULL;

-- 올바른 방법
ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'user';
-- 또는: nullable로 추가 → 백필 → NOT NULL 제약 추가 (3단계 마이그레이션)
```

### MCP 필수
- **Context7**: Knex / Prisma / Drizzle / TypeORM 등 ORM 마이그레이션 API 조회 필수

### Quality Standards

→ `references/common/AGENT_QUICK_REFERENCE.md`
