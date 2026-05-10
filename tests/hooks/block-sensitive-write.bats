#!/usr/bin/env bats

setup() {
  export HOOK="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../src/wj-magic" && pwd)/hooks/block-sensitive-write.sh"
}

# --- 기존: 민감 파일 차단 ---

@test "block: .pem file" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/tmp/server.pem\"}}" | bash "$HOOK"'
  [ "$status" -eq 2 ]
}

@test "block: .key file" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/tmp/private.key\"}}" | bash "$HOOK"'
  [ "$status" -eq 2 ]
}

@test "block: credentials.json" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/tmp/credentials.json\"}}" | bash "$HOOK"'
  [ "$status" -eq 2 ]
}

@test "allow: normal ts file" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/tmp/app.ts\"}}" | bash "$HOOK"'
  [ "$status" -eq 0 ]
}

# --- 시크릿 마스킹: audit 파일 내 실제 시크릿 값 차단 ---

@test "block: audit report with AWS key" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/project/.dev/audit/agent-crypto.md\",\"content\":\"found key AKIAIOSFODNN7EXAMPLE1 in config\"}}" | bash "$HOOK"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"시크릿"* ]]
}

@test "block: audit report with GCP API key" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/project/.dev/audit/agent-config.md\",\"content\":\"Google API Key: AIzaSyFAKE_EXAMPLE_DO_NOT_USE_xxxxxxxxx\"}}" | bash "$HOOK"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"시크릿"* ]]
}

@test "block: audit report with GitHub PAT" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/project/.dev/audit/round-1-report.md\",\"content\":\"token: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij\"}}" | bash "$HOOK"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"시크릿"* ]]
}

@test "block: audit report with Stripe live key pattern" {
  # 실제 sk_live_ 값은 GitHub Push Protection에 차단되므로 동적 생성
  _stripe_val="sk_""live_""abcdefghijklmnopqrstuvwx"
  run bash -c "echo '{\"tool_input\":{\"file_path\":\"/project/.dev/audit/final-report.md\",\"content\":\"'\"${_stripe_val}\"'\"}}' | bash \"\$HOOK\""
  [ "$status" -eq 2 ]
  [[ "$output" == *"시크릿"* ]]
}

@test "block: audit report with private key header" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/project/.dev/audit/agent-crypto.md\",\"content\":\"-----BEGIN RSA PRIVATE KEY-----\"}}" | bash "$HOOK"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"시크릿"* ]]
}

@test "block: audit report with Slack token" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/project/.dev/audit/agent-config.md\",\"content\":\"slack token xoxb-abc123-def456\"}}" | bash "$HOOK"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"시크릿"* ]]
}

@test "block: Edit new_string with secret in audit" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/project/.dev/audit/agent-auth.md\",\"new_string\":\"found AKIAIOSFODNN7EXAMPLE1\"}}" | bash "$HOOK"'
  [ "$status" -eq 2 ]
  [[ "$output" == *"시크릿"* ]]
}

# --- 시크릿 마스킹: ALLOW cases (마스킹된 값은 통과) ---

@test "allow: audit report with masked key" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/project/.dev/audit/agent-crypto.md\",\"content\":\"found key AIzaSy...*** in config.ts:8\"}}" | bash "$HOOK"'
  [ "$status" -eq 0 ]
}

@test "allow: audit report with no secrets" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/project/.dev/audit/agent-auth.md\",\"content\":\"SEC-C-001: src/auth.ts:15 — JWT 서명 검증 누락\"}}" | bash "$HOOK"'
  [ "$status" -eq 0 ]
}

@test "allow: audit report with test/fake key pattern" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/project/.dev/audit/agent-crypto.md\",\"content\":\"sk_test_FAKE_abcdef is safe\"}}" | bash "$HOOK"'
  [ "$status" -eq 0 ]
}

@test "allow: non-audit md file with secret (not our scope)" {
  run bash -c 'echo "{\"tool_input\":{\"file_path\":\"/project/docs/readme.md\",\"content\":\"AKIAIOSFODNN7EXAMPLE1\"}}" | bash "$HOOK"'
  [ "$status" -eq 0 ]
}

@test "allow: empty input" {
  run bash -c 'echo "" | bash "$HOOK"'
  [ "$status" -eq 0 ]
}
