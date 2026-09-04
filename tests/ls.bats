#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_config; use_fakes
  load_lib config ports compose cmd_ls
  REPO="$BATS_TEST_TMPDIR/example-app"
  make_repo "$REPO" 5552
  wt_repos_add "$REPO"
  wt_ports_alloc "$REPO/.claude/worktrees/5552" 2 >/dev/null
  export FAKE_COMPOSE_LS_JSON="[{\"Name\":\"example-app-5552\",\"Status\":\"running(4)\",\"ConfigFiles\":\"$REPO/.claude/worktrees/5552/docker-compose.yml\"}]"
}

@test "ls は main と worktree を URL・ブランチ・compose 状態・ポート付きで出す" {
  run cmd_ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"example-app "*"https://example-app.localhost"*"main"*"-"* ]]
  [[ "$output" == *"example-app-5552"*"https://example-app-5552.localhost"*"b-5552"*"running(4)"*"31000,31001"* ]]
}

@test "repos.txt が空なら案内" {
  : > "$(wt_repos_file)"
  run cmd_ls
  [[ "$output" == *"wt setup"* ]]
}

@test "docker compose ls 失敗時は die して exit 1" {
  export FAKE_DOCKER_FAIL_COMPOSE_LS=1
  run cmd_ls
  [ "$status" -eq 1 ]
  [[ "$output" == *"docker compose ls"* ]]
}

@test "ls は消えた worktree を (prunable) 行にしエラーを撒かない" {
  rm -rf "$REPO/.claude/worktrees/5552"
  run cmd_ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"(prunable)"* ]]
  [[ "$output" != *"git リポジトリではありません"* ]]
  [[ "$output" == *"$REPO/.claude/worktrees/5552"* ]]
}
