---
description: 전체 빌드 + 테스트 수동 실행 (커밋 전 최종 검증)
argument-hint: "[--smoke]"
---

세션 내 루프는 L1/L2/L3 경량 게이트만 실행한다. 커밋 전 전체 빌드+테스트 최종 검증은 이 커맨드로 수동 실행.

## 실행 절차

### Step 1: 스택 감지

`package.json`에서 빌드/테스트 명령 추출:

```bash
BUILD_CMD=$(jq -r '.scripts.build // empty' package.json)
TEST_CMD=$(jq -r '.scripts.test // empty' package.json)
```

turbo monorepo면 `pnpm turbo build`, `pnpm turbo test` 사용.

### Step 2: 빌드 실행

```bash
${PM:-npm} run build
```

실패 시 에러 출력 후 중단.

### Step 3: 테스트 실행

```bash
${PM:-npm} test
```

실패 시 에러 출력 후 중단.

### Step 4: Smoke (--smoke 플래그 시)

`$ARGUMENTS`에 `--smoke`가 포함되고 `scripts/smoke.sh`가 존재하면:

```bash
bash scripts/smoke.sh
```

### Step 5: 결과 출력

```
✅ /wj:verify 완료
  빌드: OK
  테스트: OK (N개 통과)
  Smoke: {OK / skip}
```

## ⚡ 즉시 실행
