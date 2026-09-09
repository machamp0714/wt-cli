#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_config; use_fakes
  load_lib config ports envfile proxy compose cmd_setup cmd_updown
  REPO="$BATS_TEST_TMPDIR/app"
  make_repo "$REPO"
  CFG="$DEVENV_REPOS_DIR/app"; mkdir -p "$CFG"
  export FAKE_DOCKER_PS_NAMES="devenv-caddy"
  export FAKE_DOCKER_PORTS_PUBLISHED=1
  cd "$REPO"
}

@test "docker 型 up は compose up -d を呼び URL を出す" {
  printf 'mode: docker\n' > "$CFG/devenv.yml"
  cmd_setup "$REPO"; : > "$FAKE_LOG"
  run cmd_up
  [ "$status" -eq 0 ]
  grep -q "docker compose up -d" "$FAKE_LOG"
  [[ "$output" == *"https://app.localhost"* ]]
}

@test "host 型 up はアプリ起動の案内を出す" {
  printf 'mode: host\nports: [PORT]\n' > "$CFG/devenv.yml"
  cmd_setup "$REPO"
  run cmd_up
  [[ "$output" == *"PORT=31000"* ]]
}

@test ".envrc が無ければ die" {
  run cmd_up
  [ "$status" -eq 1 ]
  [[ "$output" == *"wt setup"* ]]
}

@test "down は compose down" {
  printf 'mode: docker\n' > "$CFG/devenv.yml"
  cmd_setup "$REPO"; : > "$FAKE_LOG"
  cmd_down
  grep -q "docker compose down" "$FAKE_LOG"
}

@test "down は追加引数を docker compose down にそのまま渡す" {
  printf 'mode: docker\n' > "$CFG/devenv.yml"
  cmd_setup "$REPO"; : > "$FAKE_LOG"
  cmd_down -v
  grep -q "docker compose down -v" "$FAKE_LOG"
}
