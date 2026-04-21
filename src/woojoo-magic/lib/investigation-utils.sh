#!/usr/bin/env bash
# investigation-utils.sh — /wj:investigate 스킬 헬퍼
# Usage:
#   investigation-utils.sh git-suspects <file> [<n>]
#     → git blame으로 파일의 최근 <n>개 커밋+라인 추출 (기본 5)
#     → 출력: "SHA\tauthor\tdate\tline_content" (TSV)
#
#   investigation-utils.sh git-recent-changes [<n_commits>]
#     → 최근 <n_commits>개 커밋의 변경 파일 목록 (중복 제거, 기본 10)
#     → 출력: 파일 경로 목록 (한 줄에 하나)
#
#   investigation-utils.sh bisect-test <good_ref> <bad_ref> <test_cmd>
#     → git bisect run으로 회귀 도입 커밋 자동 탐색
#     → 출력: 회귀 도입 커밋 SHA + 한 줄 요약
#
#   investigation-utils.sh report-init <output_file> <issue_summary>
#     → investigation-report.md 헤더 + 섹션 스켈레톤 생성
set -euo pipefail

_utils_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_usage() {
  grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \?//' | head -20
  exit 1
}

# git-suspects: 파일의 최근 변경 커밋+라인 추출
_git_suspects() {
  _suspects_file="${1:-}"
  _suspects_n="${2:-5}"

  [[ -n "$_suspects_file" ]] || { echo "오류: 파일 경로 필요" >&2; exit 1; }
  [[ -f "$_suspects_file" ]] || { echo "오류: 파일 없음: $_suspects_file" >&2; exit 1; }

  git blame --line-porcelain "$_suspects_file" \
    | awk '
      /^[0-9a-f]{40} / { sha = $1 }
      /^author /        { author = substr($0, 8) }
      /^author-time /   { ts = $2 }
      /^\t/             { printf "%s\t%s\t%s\t%s\n", sha, author, ts, substr($0, 2) }
    ' \
    | sort -t$'\t' -k3 -rn \
    | head -n "$_suspects_n"
}

# git-recent-changes: 최근 n커밋의 변경 파일 목록
_git_recent_changes() {
  _changes_n="${1:-10}"
  git log --oneline -n "$_changes_n" --pretty=format:"%H" \
    | xargs -I{} git diff-tree --no-commit-id -r --name-only {} \
    | sort -u
}

# bisect-test: good..bad 범위에서 git bisect run 실행
_bisect_test() {
  _bisect_good="${1:-}"
  _bisect_bad="${2:-}"
  _bisect_cmd="${3:-}"

  [[ -n "$_bisect_good" && -n "$_bisect_bad" && -n "$_bisect_cmd" ]] || {
    echo "오류: good_ref, bad_ref, test_cmd 모두 필요" >&2
    exit 1
  }

  # good == bad 이면 즉시 종료
  _good_sha=$(git rev-parse "$_bisect_good" 2>/dev/null || echo "")
  _bad_sha=$(git rev-parse "$_bisect_bad" 2>/dev/null || echo "")
  if [[ "$_good_sha" == "$_bad_sha" ]]; then
    echo "[bisect] good == bad — 동일 커밋, 회귀 없음"
    exit 0
  fi

  git bisect start
  git bisect bad "$_bisect_bad"
  git bisect good "$_bisect_good"

  _bisect_result=""
  if git bisect run bash -c "$_bisect_cmd" 2>&1; then
    _bisect_result=$(git bisect log | grep "^# first bad commit" | head -1 | awk '{print $NF}')
  fi

  git bisect reset

  if [[ -n "$_bisect_result" ]]; then
    _commit_summary=$(git log --oneline -1 "$_bisect_result" 2>/dev/null || echo "알 수 없음")
    echo "[bisect] 회귀 도입: $_bisect_result — $_commit_summary"
  else
    echo "[bisect] 회귀 커밋 특정 불가 — 테스트 명령 재확인 필요"
  fi
}

# report-init: investigation-report.md 스켈레톤 생성
_report_init() {
  _report_file="${1:-}"
  _report_issue="${2:-}"

  [[ -n "$_report_file" ]] || { echo "오류: output_file 필요" >&2; exit 1; }
  [[ -n "$_report_issue" ]] || { echo "오류: issue_summary 필요" >&2; exit 1; }

  _report_date=$(date +"%Y-%m-%d")

  cat > "$_report_file" <<REPORT
# Investigation Report

**Issue:** ${_report_issue}
**Date:** ${_report_date}
**Status:** IN PROGRESS

---

## Triage

- **Issue type:** <!-- bug | perf | security | arch | 복합 -->
- **Affected files:** <!-- 파일 목록 -->
- **Recent changes:** <!-- 관련 커밋 SHA -->

---

## Agent Findings

### web-researcher
<!-- Context7 + WebSearch + GitHub Issues 조사 결과 -->

### code-analyst
<!-- Serena 심볼 추적 + SBFL-inspired 의심 file:line 목록 -->

### security-auditor
<!-- OWASP 체크 + 취약점 스캔 결과 -->

### perf-analyst
<!-- 코드 레벨 병목 + Chrome DevTools 수집 결과 -->

### regression-hunter
<!-- git bisect 결과 + 회귀 도입 커밋 -->

---

## Root Cause Analysis

**Candidate 1 (confidence: high)**
> <!-- 근본 원인 설명 -->
Evidence: <!-- 근거 -->

**Candidate 2 (confidence: medium)**
> <!-- 근본 원인 설명 -->
Evidence: <!-- 근거 -->

**Candidate 3 (confidence: low)**
> <!-- 근본 원인 설명 -->
Evidence: <!-- 근거 -->

---

## Fix Applied

- **Approach:** <!-- S | M | L -->
- **Files changed:** <!-- 수정된 파일 목록 -->
- **Summary:** <!-- 수정 내용 한 줄 -->

---

## Verification

- Tests passed: <!-- yes | no | N/A -->
- L1 gate: <!-- pass | fail -->
- L2 gate: <!-- pass | fail | N/A -->
- L3 gate: <!-- pass | fail | N/A -->

---

## Lessons

<!-- /wj:learn으로 LESSONS.md에 기록할 핵심 인사이트 -->
-

---

## Memory Graph (자동 저장됨)

\`\`\`
Entity: "Investigation: ${_report_issue}"
Observations:
  - date: ${_report_date}
  - issue_type: <감지된 타입>
  - root_cause: <확정된 원인>
  - fix_approach: <S|M|L>
Relations:
  - investigatedIn → <프로젝트명>
  - fixedByCommit → <커밋 SHA>
\`\`\`
REPORT

  echo "[report] 생성됨: $_report_file"
}

# 메인 디스패치
case "${1:-}" in
  git-suspects)      shift; _git_suspects "$@" ;;
  git-recent-changes) shift; _git_recent_changes "$@" ;;
  bisect-test)       shift; _bisect_test "$@" ;;
  report-init)       shift; _report_init "$@" ;;
  *)                 _usage ;;
esac
