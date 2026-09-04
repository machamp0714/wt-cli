#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_config; use_fakes
  load_lib config ports compose cmd_gc
  REPO="$BATS_TEST_TMPDIR/example-app"
  make_repo "$REPO" 3597
  touch "$REPO/docker-compose.yml" "$REPO/.claude/worktrees/3597/docker-compose.yml"
  export FAKE_COMPOSE_LS_JSON="$(cat <<EOF
[
 {"Name":"example-app","Status":"running(2)","ConfigFiles":"$REPO/docker-compose.yml"},
 {"Name":"w3597","Status":"exited(6)","ConfigFiles":"$REPO/.claude/worktrees/3597/docker-compose.yml,/nonexistent/override.yml"},
 {"Name":"gone","Status":"exited(1)","ConfigFiles":"$BATS_TEST_TMPDIR/deleted/docker-compose.yml"},
 {"Name":"langfuse","Status":"running(6)","ConfigFiles":"$REPO/docker-compose.yml"}
]
EOF
)"
}

@test "orphans は最初の設定ファイルが無いものだけ" {
  [ "$(wt_compose_orphans)" = "gone" ]
}

@test "mismatched は名前が規約と違うものを expected 付きで出す" {
  run wt_compose_mismatched
  [[ "$output" == *"w3597	example-app-3597"* ]]
  [[ "$output" == *"langfuse	example-app"* ]]
  [[ "$output" != *"gone"* ]]
}

@test "gc --dry-run は何も消さない" {
  wt_ports_alloc "$BATS_TEST_TMPDIR/deleted-wt" 1 >/dev/null
  run cmd_gc --dry-run
  [ "$status" -eq 0 ]
  ! grep -q "down -v" "$FAKE_LOG"
  [ -n "$(wt_ports_for "$BATS_TEST_TMPDIR/deleted-wt")" ]
  [[ "$output" == *"gone"* ]]
  [[ "$output" == *"31000"* ]]
}

@test "gc は孤児を down し、消えた owner のポートを解放し、mismatched を警告" {
  wt_ports_alloc "$BATS_TEST_TMPDIR/deleted-wt" 1 >/dev/null
  wt_ports_alloc "$REPO/.claude/worktrees/3597" 1 >/dev/null
  run cmd_gc
  [ "$status" -eq 0 ]
  grep -q "docker compose -p gone down -v --rmi local --remove-orphans" "$FAKE_LOG"
  ! grep -q "compose -p w3597 down" "$FAKE_LOG"
  [ -z "$(wt_ports_for "$BATS_TEST_TMPDIR/deleted-wt")" ]
  [ -n "$(wt_ports_for "$REPO/.claude/worktrees/3597")" ]
  [[ "$output" == *"w3597"* ]]
}

@test "パスにカンマを含む設定ファイルは orphan と誤判定しない" {
  mkdir -p "$BATS_TEST_TMPDIR/dir,with,comma"
  touch "$BATS_TEST_TMPDIR/dir,with,comma/docker-compose.yml"
  export FAKE_COMPOSE_LS_JSON="$(cat <<EOF
[
 {"Name":"comma-project","Status":"running(1)","ConfigFiles":"$BATS_TEST_TMPDIR/dir,with,comma/docker-compose.yml"}
]
EOF
)"
  run wt_compose_orphans
  [[ "$output" != *"comma-project"* ]]
}

@test "wt_compose_first_config は候補が全て無ければ何も出さず成功する" {
  run wt_compose_first_config "/nonexistent/a.yml,/also/missing.yml"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "docker compose ls 失敗時は die して exit 1" {
  export FAKE_DOCKER_FAIL_COMPOSE_LS=1
  run cmd_gc --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"docker compose ls"* ]]
}

@test "gc は未知の引数で die し何も消さない" {
  run cmd_gc --dryrun
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown option"* ]]
  [[ "$output" == *"wt gc [--dry-run]"* ]]
  ! grep -q " down " "$FAKE_LOG"
}

@test "mismatched だけのときは「回収対象はありません」を出さない" {
  export FAKE_COMPOSE_LS_JSON="[{\"Name\":\"wrong-name\",\"Status\":\"running(1)\",\"ConfigFiles\":\"$REPO/docker-compose.yml\"}]"
  run cmd_gc --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"wrong-name"* ]]
  [[ "$output" != *"回収対象はありません"* ]]
}
