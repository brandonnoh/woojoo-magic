#!/usr/bin/env bash
# quality-gate.sh — Stage 3: 빌드/테스트/품질 델타
set -euo pipefail

if ! declare -f collect_quality_metrics >/dev/null 2>&1; then
  source "$(dirname "${BASH_SOURCE[0]}")/metrics.sh"
fi

# plan-${iter}.json의 affected_packages로부터 build/test 명령을 scope 제한
# - monorepo(pnpm --filter 지원) 환경에서만 scope 작동
# - affected_packages가 비어 있거나 모노레포가 아니면 기본 명령 그대로 반환
scope_cmd_by_plan() {
  local base_cmd="$1"
  local plan_file="$2"
  local stack_file="$3"

  [[ -f "$plan_file" && -f "$stack_file" ]] || { echo "$base_cmd"; return 0; }

  local pm monorepo
  pm=$(jq -r '.package_manager // "npm"' "$stack_file")
  monorepo=$(jq -r '.monorepo // false' "$stack_file")

  # pnpm monorepo에서만 --filter scope 적용
  [[ "$pm" == "pnpm" && "$monorepo" == "true" ]] || { echo "$base_cmd"; return 0; }

  local pkgs
  pkgs=$(jq -r '[.selected_tasks[]?.affected_packages[]?] | unique | .[]' "$plan_file" 2>/dev/null || true)
  [[ -n "$pkgs" ]] || { echo "$base_cmd"; return 0; }

  # base_cmd에서 동작(build/test)만 추출
  local action
  action=$(echo "$base_cmd" | awk '{print $NF}')
  [[ "$action" == "build" || "$action" == "test" ]] || { echo "$base_cmd"; return 0; }

  # pnpm --filter '*<pkg>*' 패턴 (패키지명 부분매치)
  local filter_args=""
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    filter_args+=" --filter='*${p}*'"
  done <<< "$pkgs"

  echo "pnpm${filter_args} ${action}"
}

quality_gate_run() {
  local iter="$1"
  local state="${STATE_DIR:-.ralph-state}"
  mkdir -p "$state"

  echo "[quality-gate] iter=$iter 시작"

  # 1. stack 로드
  local build_cmd test_cmd
  if [[ -f "$state/stack.json" ]]; then
    build_cmd=$(jq -r '.build_cmd' "$state/stack.json")
    test_cmd=$(jq -r '.test_cmd' "$state/stack.json")
  else
    build_cmd="pnpm turbo build"
    test_cmd="pnpm turbo test"
  fi

  # 1b. affected_packages scope 제한 (P0 이슈 2)
  local plan_file="$state/plan-${iter}.json"
  local scoped_build scoped_test
  scoped_build=$(scope_cmd_by_plan "$build_cmd" "$plan_file" "$state/stack.json")
  scoped_test=$(scope_cmd_by_plan "$test_cmd" "$plan_file" "$state/stack.json")

  if [[ "$scoped_build" != "$build_cmd" ]]; then
    echo "[quality-gate] scope 제한 적용: $scoped_build"
    build_cmd="$scoped_build"
    test_cmd="$scoped_test"
  fi

  echo "[quality-gate] build: $build_cmd"
  if ! eval "$build_cmd"; then
    echo "[quality-gate] BUILD FAILED"
    return 1
  fi

  echo "[quality-gate] test: $test_cmd"
  if ! eval "$test_cmd"; then
    echo "[quality-gate] TESTS FAILED"
    return 1
  fi

  # 1c. Smoke Test — 프로젝트 루트에 smoke-test.sh가 있으면 실행 (timeout 120s)
  if [[ -f "smoke-test.sh" ]]; then
    local smoke_timeout="${SMOKE_TIMEOUT:-300}"
    echo "[quality-gate] smoke-test.sh 감지 → E2E smoke 검증 (timeout=${smoke_timeout}s)"
    if command -v timeout >/dev/null 2>&1; then
      if ! timeout "$smoke_timeout" bash smoke-test.sh 2>&1; then
        local exit_code=$?
        if (( exit_code == 124 )); then
          echo "[quality-gate] SMOKE TEST TIMEOUT (${smoke_timeout}s 초과)"
        else
          echo "[quality-gate] SMOKE TEST FAILED (exit=$exit_code)"
        fi
        # smoke-test가 남긴 서버 프로세스 정리
        local smoke_port="${SMOKE_PORT:-3000}"
        lsof -ti:"$smoke_port" 2>/dev/null | xargs kill -9 2>/dev/null || true
        return 1
      fi
    else
      # macOS coreutils 없는 경우: 백그라운드 + wait 방식
      bash smoke-test.sh 2>&1 &
      local smoke_pid=$!
      local elapsed=0
      while kill -0 "$smoke_pid" 2>/dev/null; do
        if (( elapsed >= smoke_timeout )); then
          kill -9 "$smoke_pid" 2>/dev/null || true
          wait "$smoke_pid" 2>/dev/null || true
          echo "[quality-gate] SMOKE TEST TIMEOUT (${smoke_timeout}s 초과)"
          local smoke_port="${SMOKE_PORT:-3000}"
          lsof -ti:"$smoke_port" 2>/dev/null | xargs kill -9 2>/dev/null || true
          return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
      done
      wait "$smoke_pid" || {
        echo "[quality-gate] SMOKE TEST FAILED"
        local smoke_port="${SMOKE_PORT:-3000}"
        lsof -ti:"$smoke_port" 2>/dev/null | xargs kill -9 2>/dev/null || true
        return 1
      }
    fi
    echo "[quality-gate] smoke test OK"
  fi

  # 1d. tests.json 구조 무결성 검증
  if [[ -f "tests.json" ]]; then
    local feat_count summary_total
    feat_count=$(jq '.features | length' tests.json 2>/dev/null || echo 0)
    summary_total=$(jq '(.summary.passing // 0) + (.summary.pending // 0) + (.summary.failing // 0)' tests.json 2>/dev/null || echo 0)
    if (( feat_count < 2 )); then
      echo "[quality-gate] ❌ tests.json 파괴 감지: features 배열이 ${feat_count}개 (Worker가 단일 객체로 덮어쓴 것으로 추정)"
      return 1
    fi
    if (( feat_count != summary_total )); then
      echo "[quality-gate] ⚠️  tests.json summary 불일치 (features=${feat_count}, summary=${summary_total}) → 자동 보정"
      local passing failing
      passing=$(jq '[.features[] | select(.status == "passing")] | length' tests.json)
      failing=$(( feat_count - passing ))
      jq --argjson t "$feat_count" --argjson p "$passing" --argjson f "$failing" \
        '.summary = {total: $t, passing: $p, failing: $f}' tests.json > tests.json.tmp \
        && mv tests.json.tmp tests.json
      git add tests.json 2>/dev/null || true
      git commit --no-verify -m "fix(ralph): iter-${iter} tests.json summary 자동 보정" >/dev/null 2>&1 || true
      echo "[quality-gate] summary 보정 완료: passing=${passing}, failing=${failing}, total=${feat_count}"
    fi
    echo "[quality-gate] tests.json 무결성 OK (features=${feat_count}, summary=${summary_total})"
  fi

  # 1e. High-Risk 변경 감지 — auth/middleware/route 변경 시 전체 빌드+테스트 강제
  local base_sha
  base_sha=$(cat "$state/checkpoint-${iter}.sha" 2>/dev/null || echo "")
  if [[ -n "$base_sha" ]]; then
    local high_risk_files
    high_risk_files=$(git diff --name-only "$base_sha"...HEAD 2>/dev/null \
      | grep -iE '(auth|middleware|guard|route|session)' || true)
    if [[ -n "$high_risk_files" ]]; then
      echo "[quality-gate] ⚠️ HIGH-RISK 변경 감지:"
      echo "$high_risk_files" | sed 's/^/  🔴 /'
      # scope 제한 무시하고 전체 빌드+테스트 강제
      if [[ "$scoped_build" != "$build_cmd" ]]; then
        echo "[quality-gate] → 전체 빌드+테스트 강제 실행"
        if ! eval "$build_cmd"; then
          echo "[quality-gate] FULL BUILD FAILED (high-risk)"
          return 1
        fi
        if ! eval "$test_cmd"; then
          echo "[quality-gate] FULL TEST FAILED (high-risk)"
          return 1
        fi
        echo "[quality-gate] 전체 빌드+테스트 OK"
      fi
    fi
  fi

  # 2. 감사 5종 (P2 이슈 5) — 이번 iteration diff 범위 내에서만
  if ! audit_diff_files "$iter"; then
    echo "[quality-gate] AUDIT FAILED"
    return 1
  fi

  # 3. 품질 스냅샷
  local curr="$state/quality-${iter}.json"
  collect_quality_metrics > "$curr"
  echo "[quality-gate] 스냅샷: $(cat "$curr")"

  # 4. 델타 비교
  local prev="$state/prev-metrics.json"
  if [[ -f "$prev" ]]; then
    local delta; delta=$(get_delta "$prev" "$curr")
    echo "[quality-gate] 델타: $delta"
    local d_over d_any d_nn
    d_over=$(echo "$delta" | jq '.files_over_300_delta')
    d_any=$(echo "$delta" | jq '.any_count_delta')
    d_nn=$(echo "$delta" | jq '.nonnull_count_delta')
    if (( d_over > 0 || d_any > 0 || d_nn > 0 )); then
      echo "[quality-gate] WARNING: 품질 회귀 감지"
      echo "  files_over_300 델타: $d_over"
      echo "  any_count 델타: $d_any"
      echo "  nonnull_count 델타: $d_nn"
      if [[ "${STRICT:-0}" == "1" ]]; then
        echo "[quality-gate] STRICT 모드 → FAIL"
        return 1
      fi
    fi
  fi

  # 5. 다음 iteration 안전장치
  cp "$curr" "$state/prev-metrics.json"

  echo "[quality-gate] OK"
  return 0
}

# 이번 iteration에서 변경된 파일만 대상으로 5종 감사
# - 300줄 초과 (신규/수정 파일)
# - : any / <any> / as any
# - non-null ! 접근자
# - silent catch {}
# - eslint-disable no-explicit-any
audit_diff_files() {
  local iter="$1"
  local state="${STATE_DIR:-.ralph-state}"
  local base_sha
  base_sha=$(cat "$state/checkpoint-${iter}.sha" 2>/dev/null || echo "")
  [[ -n "$base_sha" ]] || { echo "[audit] skip (baseline SHA 없음)"; return 0; }

  local files
  files=$(git diff --name-only --diff-filter=AM "$base_sha"...HEAD 2>/dev/null \
          | grep -E '\.(ts|tsx|mts|cts)$' \
          | grep -vE '(\.d\.ts|__tests__|\.test\.|\.spec\.|node_modules/|dist/)' || true)

  # worker가 아직 commit하지 않은 unstaged 변경도 포함
  local unstaged
  unstaged=$(git diff --name-only --diff-filter=AM 2>/dev/null \
             | grep -E '\.(ts|tsx|mts|cts)$' \
             | grep -vE '(\.d\.ts|__tests__|\.test\.|\.spec\.|node_modules/|dist/)' || true)
  files=$(printf "%s\n%s\n" "$files" "$unstaged" | sort -u | sed '/^$/d')

  [[ -n "$files" ]] || { echo "[audit] 변경된 TS 파일 없음 → skip"; return 0; }

  echo "[audit] 대상 파일:"
  echo "$files" | sed 's/^/  - /'

  local fail=0

  # 1) 300줄 초과
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    local lines; lines=$(wc -l < "$f" | tr -d ' ')
    if (( lines > 300 )); then
      echo "[audit] ❌ 300줄 초과: $f ($lines줄)"
      fail=1
    fi
  done <<< "$files"

  # 2) any 금지
  # shellcheck disable=SC2016
  if echo "$files" | xargs -I {} grep -HnE ':\s*any\b|<any>|\bas\s+any\b' {} 2>/dev/null | grep -v '// @ts-' | grep .; then
    echo "[audit] ❌ any 타입 도입 감지"
    fail=1
  fi

  # 3) non-null assertion
  if echo "$files" | xargs -I {} grep -HnE '[A-Za-z0-9_\)\]]!\.' {} 2>/dev/null | grep .; then
    echo "[audit] ❌ non-null 단언(!.) 감지"
    fail=1
  fi

  # 4) silent catch
  if echo "$files" | xargs -I {} grep -HnE 'catch\s*\(\s*\w*\s*\)\s*\{\s*\}' {} 2>/dev/null | grep .; then
    echo "[audit] ❌ silent catch {} 감지"
    fail=1
  fi

  # 5) eslint-disable no-explicit-any
  if echo "$files" | xargs -I {} grep -Hn 'eslint-disable.*no-explicit-any' {} 2>/dev/null | grep .; then
    echo "[audit] ❌ eslint-disable no-explicit-any 감지"
    fail=1
  fi

  if (( fail == 1 )); then
    return 1
  fi
  echo "[audit] OK (5종 감사 통과)"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  quality_gate_run "${1:-manual}"
fi
