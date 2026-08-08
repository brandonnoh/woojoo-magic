# 아키텍처 확장성 진단 카탈로그

> 바이브코딩 MVP가 사용자 증가로 아키텍처 개선이 필요할 때 쓰는 진단 레퍼런스.
> 코드 품질(review-checklist.md)이 "깨끗한가"를 본다면, 이 문서는 "구조가 확장을 견디는가"를 본다.
> 출처: ISO/IEC 25010:2023, Clean/Hexagonal Architecture, Connascence, Evolutionary Architecture,
> Fundamentals of Software Architecture, Team Topologies, Supabase/PostgreSQL 공식 문서 (10-way 리서치 종합).

## 진단 매트릭스: 6 레이어 × 4 품질축

진단은 **"어디를(레이어)" × "무엇을(품질축)"** 의 2차원으로 수행한다.
같은 코드도 레이어별로 다르게 읽힌다 — 예: 좋아요 상태 복제는 도메인축(meals)으론 "정상"이지만
상태흐름 레이어(L2)×결합도축(X1)으론 "심각한 확장성 결함"이다.

```
                     X1 결합도    X2 확장성    X3 신뢰성    X4 진화성
L1 프레젠테이션        L1-C         L1-S         L1-R         L1-E
L2 상태·데이터흐름     L2-C ★       L2-S         L2-R         L2-E
L3 도메인·비즈니스로직  L3-C         L3-S         L3-R         L3-E
L4 데이터접근(액션/API) L4-C         L4-S         L4-R ★       L4-E
L5 데이터·인프라(DB)   L5-C         L5-S ★       L5-R         L5-E
L6 모듈·경계·조직      L6-C         L6-S         L6-R         L6-E ★
```

- **레이어(수직)**: 코드가 속한 계층. UI → 상태 → 도메인 → 데이터접근 → 인프라 → 모듈경계.
- **품질축(수평)**: C=결합도/응집도, S=확장성(스케일 병목), R=신뢰성/운영, E=진화성(변경용이성/부채).
- 각 셀에 아래 진단 관점이 매핑된다. ★ = 바이브코딩 MVP에서 가장 자주 터지는 셀.

---

## L1 — 프레젠테이션 (UI 컴포넌트)

| 관점 | 병목 신호 | 이상적 구조 | 탐지 |
|------|----------|------------|------|
| God Component (L1-C) | 파일 300줄+ & useState 7개+ & useEffect 5개+ | 컨테이너/프레젠테이션 분리, 커스텀 훅 추출 | `find src -name '*.tsx' \| xargs wc -l \| sort -rn \| head` |
| Prop Drilling (L1-C) | 같은 prop 3단계+ 전달, 중간 컴포넌트가 미사용 prop 전달 | Context(저빈도)/store/합성(children) | props 인터페이스 필드 8개+ 탐지 |
| 조건부 렌더 폭발 (L1-E) | `type`/`variant` prop 5개+ & 내부 if/else 10개+ | Compound Component, cva()로 variant 분리 | 컴포넌트 내 분기 수 카운트 |
| 리렌더 폭발 (L1-S) | inline 함수/객체 props, memo 무효화 | 안정 참조, React 19 Compiler, children 패턴 | React DevTools Profiler "highlight updates" |
| 이미지 로딩 전략 (L1-S) | LCP 이미지 lazy, `sizes` 누락 | LCP에 priority, 표시크기별 thumb | Lighthouse LCP audit |
| 로딩/에러/빈 상태 누락 (L1-R) | happy-path만 구현, `loading.tsx` 없음 | 3상태 모두 처리, Suspense+ErrorBoundary | `find src/app -name loading.tsx \| wc -l` |
| CSS 아키텍처 산포 (L1-E) | 동일 Tailwind 조합 10곳+ 반복, `mt-[17px]` 매직값 | cn()+cva(), 디자인 토큰 중앙화 | arbitrary value `grep "mt-\["` |

## L2 — 상태·데이터 흐름 (클라이언트 상태, 캐시, 동기화) ★핫스팟

| 관점 | 병목 신호 | 이상적 구조 | 탐지 |
|------|----------|------------|------|
| **서버상태 복제** (L2-C) ★ | 서버 데이터를 useState로 복제, 화면마다 사본 | TanStack Query/SWR 단일 정규화 캐시 | `grep -rn "useState.*\(props\.\|fetch\|data\)"` |
| Connascence of Value (L2-C) ★ | 같은 엔티티 상태가 N개 컴포넌트에 독립 존재 + 콜백 동기화 | 단일 소스 + 캐시 mutation 전파 | `grep -rn "useState.*like\|heart\|favorite"` |
| 파생 상태 저장 (L2-C) | `setA();setB();setC()` 연쇄, useEffect로 파생값 set | 렌더 중 계산 or useMemo (저장 말고 유도) | useEffect body의 set* + deps에 state |
| Optimistic UI 부재 (L2-S) | 토글 액션이 서버 응답 대기 | onMutate 낙관 + onError 롤백 (또는 useOptimistic) | mutation에 onMutate 유무 |
| 캐시 무효화 누락 (L2-R) | mutation 후 revalidate/invalidate 없음 → "새로고침해야 반영" | onSettled invalidateQueries / revalidateTag | actions에서 revalidate 없는 함수 |
| useEffect 과용 (L2-E) | effect에서 setState(렌더 루프), props→state 리셋 | 이벤트=핸들러, 파생=렌더, 외부동기화만 effect+cleanup | 파일당 useEffect 3개+ |
| Realtime 구독 누수 (L2-R) | subscribe 후 removeChannel cleanup 없음 | useEffect cleanup에서 unsubscribe | subscribe/channel vs removeChannel diff |
| Context broadcast (L2-S) | Provider value에 5필드+ 객체, 무관 consumer 리렌더 | 도메인별 Context 분리, 빈번데이터는 store | Profiler로 Context 변경 시 리렌더 수 |

## L3 — 도메인·비즈니스 로직 (규칙, 계산, 타입)

| 관점 | 병목 신호 | 이상적 구조 | 탐지 |
|------|----------|------------|------|
| 도메인-인프라 결합 (L3-C) | 계산 함수 안에 supabase/next 직접 import | 순수 함수로 분리(lib/domain), 프레임워크 import 0 | `grep -rn "supabase\|next/" src/lib/domain/` |
| Connascence of Algorithm (L3-C) | 주수계산/혈당판정이 여러 곳 복제 | 순수 함수 단일 export | `grep -rn "280\|dueDate\|gestational"` |
| Connascence of Meaning (L3-C) | 매직 넘버/문자열(`role==='admin'`, `95`) 산재 | const/enum/Branded Type 중앙정의 | `grep` 매직값 3파일+ 반복 |
| Primitive Obsession (L3-E) | userId가 string, 혈당이 number (도메인 개념 미표현) | Branded Types, Value Objects | `grep -rn "userId: string"` |
| 테스트 용이성 (L3-E) | 로직이 프레임워크/IO와 혼재, 순수함수 비율 낮음 | 비즈니스 로직 순수 함수 추출 → unit test | `.test.*` 수 vs 소스 수, coverage |
| Aggregate 경계 위반 (L3-C) | 자식 테이블을 Root 거치지 않고 직접 CRUD | Aggregate Root 통한 접근, 불변식 보장 | `.from('child')` 단독 사용 |

## L4 — 데이터 접근 (서버액션, API Route)

| 관점 | 병목 신호 | 이상적 구조 | 탐지 |
|------|----------|------------|------|
| Fat Server Action (L4-C) | actions.ts 300줄+ & 5도메인+ & 내부에 SQL+검증+규칙 인라인 | 얇은 오케스트레이션(검증→서비스→revalidate) | actions 파일 크기 + .from() 수 |
| 서버/클라 경계 위반 (L4-C) | 'use client'에서 서버 클라이언트 호출, env 유출 | 'use client'는 leaf, server-only 패키지 | `grep "'use client'"` 위치/수 |
| 인증 일관성 (L4-R) | 일부 action만 getUser() 체크 | 미들웨어+action getUser()+RLS 삼중 방어 | `grep -rL "getUser\|getAuthUser" **/actions.ts` |
| Silent Failure (L4-R) ★ | `catch {}`, `.error` 미체크, `return null` | Result 패턴, 구조화 로깅, 명시적 전파 | `grep -rn "catch" \| grep -v "error\|throw\|log"` |
| 멱등성 부재 (L4-R) | POST에 idempotency key 없음, INSERT without ON CONFLICT | idempotency key + atomic check-set / upsert | mutation의 INSERT vs UPSERT |
| Rate Limiting 부재 (L4-S) | 공개 action/AI API 무제한 호출 | token bucket, IP+User 이중, 429+Retry-After | 미들웨어 rate limit 유무 |
| API 표면적 팽창 (L4-E) | 중복 endpoint, action과 route 이중 제공 | action 우선, route는 외부/webhook | `find api -name route.ts \| wc -l` |
| DTO 오염 (L4-C) | DB Row를 그대로 Client props/API 응답 | DTO 변환, 필요 필드만 projection | props에 `Row]` 타입 직접 사용 |

## L5 — 데이터·인프라 (Postgres/Supabase, 스토리지, 외부서비스) ★핫스팟

| 관점 | 병목 신호 | 이상적 구조 | 탐지 |
|------|----------|------------|------|
| **N+1 쿼리** (L5-S) ★ | 루프 안 `.from().eq()`, 리스트당 개별 fetch | 임베디드 조인 `.select('*,rel(*)')` 또는 `.in()` 배치 | 루프 내 `.from()` grep, 쿼리 로그 |
| 무한 데이터 페치 (L5-S) | LIMIT 없는 select, 클라 `.slice()` 후처리 | 서버 기본/최대 페이지크기 강제 | `.from(` without `.limit\|.range` |
| OFFSET 페이지네이션 (L5-S) | `.range(offset,...)` 깊은 페이지 O(n) | 커서/keyset `.lt('created_at',cursor)` | `.range(\|OFFSET` grep |
| 인덱스 부재 (L5-S) ★ | WHERE/FK/RLS 컬럼에 인덱스 없음 → Seq Scan | 필터·FK·RLS 컬럼 B-tree 인덱스 | `pg_stat_user_tables.seq_scan` 높음 |
| RLS 정책 성능 (L5-S) ★ | `auth.uid()` 미래핑, 정책 내 서브쿼리 | `(SELECT auth.uid())`, 정책컬럼 인덱스, security definer | EXPLAIN RLS on/off 비교 |
| 커넥션 풀 고갈 (L5-S) | 서버리스 매 호출 새 커넥션, idle 80%+ | Supavisor transaction mode(6543), pool≤40% | `pg_stat_activity` state 집계 |
| SELECT * 남용 (L5-S) | `.select('*')`, JSONB/TEXT 불필요 전송 | 명시적 컬럼, 목록/상세 분리 | `.select('*')\|.select()` grep |
| 이중 집계/비원자 카운트 (L5-R) | read→+1→write, count 불일치 | `count = count + 1` 원자 UPDATE/RPC, UNIQUE 제약 | `count + 1` 앱코드 패턴 |
| Realtime 확장 한계 (L5-S) | Postgres Changes 구독자당 RLS 체크 1:N | Broadcast 채널, 필터 구독, 정책 단순화 | 채널당 구독자 수 |
| 트리거 vs 앱로직 혼란 (L5-E) | 트리거에 외부호출/UI검증, 트리거 체이닝 | 트리거=무결성 불변식만, 무거운건 NOTIFY+워커 | 마이그레이션 CREATE TRIGGER 검토 |
| 스토리지/CDN 미활용 (L5-S) | 매 요청 signed URL, Cache-Control 없음, on-the-fly 리사이즈 | public 버킷 CDN, 사전 리사이즈, 긴 max-age | 응답헤더 x-cache HIT/MISS |
| 정적생성 규모 (L5-S) | generateStaticParams 전체 프리빌드 → 빌드 선형증가 | subset 프리빌드+온디맨드 ISR, sitemap 전체커버 | 빌드시간 추세, 반환배열 크기 |

## L6 — 모듈·경계·조직

| 관점 | 병목 신호 | 이상적 구조 | 탐지 |
|------|----------|------------|------|
| 순환 의존 (L6-C) ★ | A→B→C→A, barrel file 순환 | DAG, 공통부 leaf 추출, 의존성 역전 | `npx madge --circular src/` |
| 의존성 방향 위반 (L6-C) | 하위 레이어가 상위 참조, route group 교차 import | 단방향(UI→도메인→인프라), 경계는 lib 경유 | `dependency-cruiser` forbidden rule |
| Shotgun Surgery (L6-E) ★ | 한 변경이 5파일+ 수정, 상수 3곳+ 하드코딩 | 변경이유 같은 코드 co-locate, 단일소스 | `git log --name-only` co-change 클러스터 |
| God Utility (L6-C) | utils.ts 500줄+ 무관 함수 20개+ | 도메인별 분리, shared는 순수 primitive만 | `wc -l src/lib/utils*` |
| Public API 부재 (L6-E) | 내부 파일 직접 import, index.ts 없음/`export *` | index.ts로 계약 노출, 내부 은닉 | 디렉토리 index.ts 유무 |
| 안정성-추상성 불균형 (L6-E) | Ca 높은데 구체(Zone of Pain), 아무도 안쓰는 추상 | D=|A+I-1|<0.3 (Main Sequence) | dependency-cruiser metrics |
| 벤더 락인 (L6-E) | supabase/Gemini SDK가 컴포넌트 산재 | Repository/Adapter로 래핑 | `grep -rc "supabase\." src/components/` |
| Anti-Corruption Layer 부재 (L6-C) | 외부 API/DB Row가 도메인 전체 전파 | DTO→Domain 변환 경계 | `Database['public']` 컴포넌트 import |
| 과잉 분리 (L6-E) | MVP인데 10서비스, 인프라코드 > 비즈니스코드 | 1인/MVP는 모놀리스+폴더모듈, YAGNI | 팀원당 서비스 수, 인프라/비즈 LOC 비율 |
| 분산 모놀리스 (L6-C) | lock-step 배포, 양방향 의존, 공유DB 중 3+ | 합치거나 경계 재설계 | 배포 결합/API 양방향 edge |

## 횡단 품질축 요약 (모든 레이어 관통)

- **X1 결합도/응집도**: Connascence 강도(Name<Type<Meaning<Position<Algorithm), coupling 종류(content>common>control>stamp>data), LCOM. 목표: 결합은 약하게(Name쪽), 응집은 functional.
- **X2 확장성**: "사용자/데이터 10배면 터지는가". N+1, 무한페치, 인덱스, 캐싱 4계층(브라우저/CDN/앱/DB), stateless, 커넥션풀.
- **X3 신뢰성/운영**: timeout·retry(지수백오프+지터)·circuit breaker·bulkhead·graceful degradation·멱등성. Silent failure 0. 관측성 3축(로그/메트릭/트레이스), SLO/SLI, 헬스체크.
- **X4 진화성**: 변경 blast radius, 기술부채 이자, fitness function으로 재발방지, ADR로 결정 기록.

## Fitness Function (개선 후 재발 방지 — 개선안에 반드시 포함)

진단→개선으로 끝내지 말고, 각 개선에 대응하는 자동 검증(fitness function)을 CI에 심어 회귀를 막는다.

| 대상 | Fitness Function |
|------|-----------------|
| 순환 의존 | `madge --circular src/` cycle 수 === 0 (CI gate) |
| 레이어 방향 | dependency-cruiser forbidden rule (역방향 import 차단) |
| 파일/함수 크기 | ESLint max-lines(300)/max-lines-per-function(20)/complexity(15) |
| Silent failure | ESLint no-empty + 커스텀 .error 체크 rule |
| 타입 안전 | `tsc --noEmit` 0, `: any`/`as any`/`@ts-ignore` 카운트 상한 |
| 인증 누락 | `grep -L getUser **/actions.ts` === 빈 결과 |
| 서버상태 복제 | `useState.*fetch` 패턴 0 (서버상태는 캐시로) |
| 공급망 | `pnpm audit --audit-level high` exit 0 |
| 빌드 시간 | CI 빌드시간 추세, 10% 증가 시 경고 |

## 진단 도구

| 도구 | 용도 |
|------|------|
| `dependency-cruiser` | 의존성 그래프, 순환, 레이어 방향, Ca/Ce/I/A 메트릭 |
| `madge --circular` | 순환 의존 탐지·시각화 |
| `knip` / `ts-prune` | 미사용 파일·export·의존성 (dead code) |
| `jscpd` | 코드 중복률 (AI 코드는 15%+ 흔함) |
| `@next/bundle-analyzer` | 번들 크기 treemap |
| ESLint (complexity/max-lines/no-explicit-any) | 코드레벨 복잡도·크기·타입 |
| `EXPLAIN (ANALYZE,BUFFERS)` + `pg_stat_statements` | 쿼리 성능, Seq Scan, RLS 비용 |
| `git log --name-only` co-change | 논리적 결합(Shotgun Surgery) 핫스팟 |

## 바이브코딩 MVP 특화 주의 (AI 생성 코드 통계)

- 코드 복제율 8.3%→12.3%(+48%), 대형블록 복제 8배 (GitClear 2024)
- 리팩토링 비율 25%→10% 붕괴 — AI는 개선 대신 항상 추가 (진화성 최대 위협)
- 보안 취약점 포함 45%, "거의 맞는" 코드 불만 66%
- 가장 흔한 셀: **L2×X1(상태 복제)**, **L4×X3(silent failure)**, **L5×X2(N+1/인덱스)**, **L6×X4(shotgun surgery/패턴 불일치)**
- 함정: MVP에 과잉 분리(마이크로서비스/과도 추상화)도 안티패턴. 1인/소규모는 모놀리스+폴더모듈이 정답.

## 진단 워크플로우 (스킬이 수행하는 순서)

1. **레이어 매핑**: 코드베이스를 6레이어로 분류(어느 파일이 어느 층인지).
2. **셀별 진단**: 6×4 매트릭스 각 셀에 위 관점을 적용, 탐지 명령으로 증거 수집. ★핫스팟 우선.
3. **확장성 임팩트 산정**: 각 발견을 "사용자/데이터 N배 시 영향"으로 정렬(지금 안 아파도 미래 병목).
4. **최적 아키텍처 결정**: 내장 패턴(이 문서) + 리서치(Context7/WebSearch) **둘 다** 참조해 목표 구조 확정.
5. **개선 설계**: 목표 구조로의 마이그레이션 플랜(레이어 단위, 점진 이주). 각 개선에 fitness function 첨부.
6. **Wave 실행**: cto-review의 충돌 제로 Wave 전략으로 자동 개선 구현 + fitness function CI 반영.
