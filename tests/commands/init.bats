#!/usr/bin/env bats

setup() {
  TEMPLATES="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-magic/templates" && pwd)"
}

@test "init: CLAUDE.template.md exists" {
  [ -f "$TEMPLATES/CLAUDE.template.md" ]
}

@test "init: tasks.template.json exists" {
  [ -f "$TEMPLATES/.dev/tasks.template.json" ]
}

@test "init: prd.template.md exists" {
  [ -f "$TEMPLATES/docs/prd.template.md" ]
}

@test "init: tasks.template.json is valid JSON" {
  jq . "$TEMPLATES/.dev/tasks.template.json" > /dev/null
}
