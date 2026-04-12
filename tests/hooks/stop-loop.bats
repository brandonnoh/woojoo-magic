#!/usr/bin/env bats

setup() {
  export CLAUDE_PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/woojoo-magic" && pwd)"
  export CLAUDE_PROJECT_DIR="$(mktemp -d)"
  mkdir -p "$CLAUDE_PROJECT_DIR/.dev/state"
  mkdir -p "$CLAUDE_PROJECT_DIR/.dev/journal"
  echo '{"summary":{"total":0,"done":0},"features":[]}' > "$CLAUDE_PROJECT_DIR/.dev/tasks.json"
  git -C "$CLAUDE_PROJECT_DIR" init -q
  git -C "$CLAUDE_PROJECT_DIR" commit --allow-empty -m "init" -q
}

teardown() {
  rm -rf "$CLAUDE_PROJECT_DIR"
}

@test "Stop hook: no loop.state file exits cleanly" {
  run bash "$CLAUDE_PLUGIN_ROOT/hooks/stop-loop.sh"
  [ "$status" -eq 0 ]
}

@test "Stop hook: active=false exits cleanly" {
  echo '{"active":false}' > "$CLAUDE_PROJECT_DIR/.dev/state/loop.state"
  run bash "$CLAUDE_PLUGIN_ROOT/hooks/stop-loop.sh"
  [ "$status" -eq 0 ]
}

@test "Stop hook: active=true with no changes continues loop" {
  echo '{"active":true,"started_at":"2099-01-01T00:00:00Z","current_task":"test-001","iteration":0,"consecutive_failures":0}' \
    > "$CLAUDE_PROJECT_DIR/.dev/state/loop.state"
  run bash "$CLAUDE_PLUGIN_ROOT/hooks/stop-loop.sh"
  [[ "$output" == *"이어서 구현"* ]] || [[ "$output" == *"block"* ]]
}
