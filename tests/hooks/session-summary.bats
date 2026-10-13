#!/usr/bin/env bats
# session-summary: 300줄 초과·any 카운트가 .claude/worktrees(저장소 사본)·가상환경을 훑지 않는다(세션 시작이 멈추던 문제)

setup() {
  export HOOK="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-magic" && pwd)/hooks/session-summary.sh"
  export REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/src" "$REPO/.claude/worktrees/copy/src" "$REPO/.venv/lib"
  long() { for i in $(seq 1 320); do echo "const a$i = $i"; done; }
  long > "$REPO/src/big.ts"
  echo 'const x: any = 1' > "$REPO/src/small.ts"
  long > "$REPO/.claude/worktrees/copy/src/big.ts"
  echo 'const y: any = 2' > "$REPO/.claude/worktrees/copy/src/small.ts"
  long > "$REPO/.venv/lib/big.js"
  printf '.claude/worktrees/\n.venv/\n' > "$REPO/.gitignore"
  git -C "$REPO" init -q
  git -C "$REPO" -c user.email=t@t -c user.name=t add -A
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -qm init
}

@test "git repo: counts tracked files only (skips worktree copies and venv)" {
  run env CLAUDE_PROJECT_DIR="$REPO" bash "$HOOK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"300줄 초과 파일: 1개"* ]]
  [[ "$output" == *"any 사용: 1곳"* ]]
}

@test "git repo: untracked copies under .claude are not counted" {
  long() { for i in $(seq 1 320); do echo "const b$i = $i"; done; }
  long > "$REPO/.claude/worktrees/copy/src/big2.ts"
  run env CLAUDE_PROJECT_DIR="$REPO" bash "$HOOK"
  [[ "$output" == *"300줄 초과 파일: 1개"* ]]
}
