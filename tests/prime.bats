#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_config; use_fakes
  load_lib config ports envfile proxy compose cmd_setup cmd_prime
  REPO="$BATS_TEST_TMPDIR/example-app"
  make_repo "$REPO" 5552
  WT="$REPO/.claude/worktrees/5552"
  mkdir -p "$DEVENV_REPOS_DIR/example-app"
  printf 'mode: docker\n' > "$DEVENV_REPOS_DIR/example-app/devenv.yml"
  export FAKE_DOCKER_PS_NAMES="devenv-caddy"
}

@test "wt 管理の worktree では URL と規約を出す" {
  cmd_setup "$WT" >/dev/null
  cd "$WT"
  run cmd_prime
  [ "$status" -eq 0 ]
  [[ "$output" == *"## devenv (wt)"* ]]
  [[ "$output" == *"https://example-app-5552.localhost"* ]]
  [[ "$output" == *"localhost:3000"* ]]
  [[ "$output" == *"wt up"* ]]
  [[ "$output" == *"wt rm 5552"* ]]
  [[ "$output" == *"example-app-5552"* ]]
}

@test "サブディレクトリからでも出す" {
  cmd_setup "$WT" >/dev/null
  mkdir -p "$WT/app/models"; cd "$WT/app/models"
  run cmd_prime
  [[ "$output" == *"https://example-app-5552.localhost"* ]]
}

@test "wt の .envrc が無ければ何も出さない" {
  cd "$WT"
  run cmd_prime
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "wt 以外が書いた .envrc は無視する" {
  echo 'export FOO=1' > "$WT/.envrc"
  cd "$WT"
  run cmd_prime
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "host 型では PORT の行が出る" {
  printf 'mode: host\nports: [PORT]\n' > "$DEVENV_REPOS_DIR/example-app/devenv.yml"
  cmd_setup "$WT" >/dev/null
  cd "$WT"
  run cmd_prime
  [[ "$output" == *"PORT=31000"* ]]
}

@test "main worktree では削除しない旨を出す" {
  cmd_setup "$REPO" >/dev/null
  cd "$REPO"
  run cmd_prime
  [[ "$output" == *"main worktree"* ]]
  [[ "$output" != *"wt rm"* ]]
}

@test "git リポジトリ外でも exit 0 で無出力" {
  cd "$BATS_TEST_TMPDIR"
  run cmd_prime
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
