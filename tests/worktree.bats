#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_config; use_fakes
  load_lib config ports envfile proxy compose cmd_setup cmd_worktree
  REPO="$BATS_TEST_TMPDIR/example-app"
  make_repo "$REPO"
  git -C "$REPO" tag base-tag
  export FAKE_DOCKER_PS_NAMES="devenv-caddy"
  cd "$REPO"
}

@test "new は .claude/worktrees/<name> に branch <name> で作り setup する" {
  run cmd_new 5552
  [ "$status" -eq 0 ]
  [ -d "$REPO/.claude/worktrees/5552" ]
  [ "$(git -C "$REPO/.claude/worktrees/5552" branch --show-current)" = "5552" ]
  [ -f "$REPO/.claude/worktrees/5552/.envrc" ]
  [[ "$output" == *"https://example-app-5552.localhost"* ]]
}

@test "new は --branch と --base を受ける" {
  cmd_new 5552 --branch feature/5552-x --base base-tag
  [ "$(git -C "$REPO/.claude/worktrees/5552" branch --show-current)" = "feature/5552-x" ]
}

@test "new は既存ブランチ名なら -b なしでチェックアウトする" {
  git -C "$REPO" branch existing
  cmd_new 5552 --branch existing
  [ "$(git -C "$REPO/.claude/worktrees/5552" branch --show-current)" = "existing" ]
}

@test "new は同名 worktree があれば die" {
  cmd_new 5552
  run cmd_new 5552
  [ "$status" -eq 1 ]
}

@test "new は --base に値が無ければ die し worktree を作らない" {
  run cmd_new 5552 --base
  [ "$status" -eq 1 ]
  [[ "$output" == *"--base"* ]]
  [ ! -d "$REPO/.claude/worktrees/5552" ]
}

@test "new は setup 失敗時に worktree を残し wt rm を案内する" {
  export FAKE_DOCKER_PS_NAMES=""
  run cmd_new 5552
  [ "$status" -eq 1 ]
  [[ "$output" == *"wt rm 5552"* ]]
  [ -d "$REPO/.claude/worktrees/5552" ]
}

@test "rm は teardown して worktree を消す。マージ済みブランチは削除" {
  cmd_new 5552
  : > "$FAKE_LOG"
  run cmd_rm 5552
  [ "$status" -eq 0 ]
  [ ! -d "$REPO/.claude/worktrees/5552" ]
  grep -q "compose -p example-app-5552 down" "$FAKE_LOG"
  ! git -C "$REPO" show-ref --verify --quiet refs/heads/5552
}

@test "rm は未マージブランチを残して警告" {
  cmd_new 5552
  (cd "$REPO/.claude/worktrees/5552" && touch f && git add f && git -c user.email=t@t -c user.name=t commit -qm wip)
  run cmd_rm 5552
  [ "$status" -eq 0 ]
  git -C "$REPO" show-ref --verify --quiet refs/heads/5552
  [[ "$output" == *"未マージ"* ]]
}
