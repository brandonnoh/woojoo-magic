#!/usr/bin/env bats

setup() {
  GATE_L1="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/woojoo-magic/lib" && pwd)/gate-l1.sh"
  FIXTURES="$(cd "$(dirname "$BATS_TEST_FILENAME")/../fixtures/minimal-ts" && pwd)"
}

@test "L1: clean TS file passes" {
  echo "${FIXTURES}/src/clean.ts" | bash "$GATE_L1"
}

@test "L1: any usage detected" {
  run bash -c "echo '${FIXTURES}/src/dirty.ts' | bash '$GATE_L1'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"any"* ]]
}

@test "L1: 300-line limit detected" {
  run bash -c "echo '${FIXTURES}/src/long.ts' | bash '$GATE_L1'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"300"* ]]
}

@test "L1: empty input passes" {
  echo "" | bash "$GATE_L1"
}

@test "L1: .d.ts files are skipped" {
  echo "foo.d.ts" | bash "$GATE_L1"
}

@test "L1: .test.ts files are skipped" {
  echo "foo.test.ts" | bash "$GATE_L1"
}
