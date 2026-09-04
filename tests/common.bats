#!/usr/bin/env bats
load helpers

setup() { setup_tmp_config; }

@test "die は exit 1 で stderr にメッセージを出す" {
  load_lib
  run die "boom"
  [ "$status" -eq 1 ]
  [[ "$output" == *"boom"* ]]
}

@test "wt は未知のサブコマンドで exit 1" {
  run "$WT_ROOT/bin/wt" nosuch
  [ "$status" -eq 1 ]
  [[ "$output" == *"nosuch"* ]]
}

@test "wt help は使い方を出す" {
  run "$WT_ROOT/bin/wt" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"wt new"* ]]
}

@test "bash 3.2 から呼んでも brew の bash で再実行される" {
  [ -x /bin/bash ] || skip "/bin/bash なし"
  run /bin/bash "$WT_ROOT/bin/wt" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"wt new"* ]]
}

@test "bin/wt は呼び出し側 PATH の shim を潰さない（PATH は後置）" {
  local log="$BATS_TEST_TMPDIR/fake.log"
  : > "$log"
  run env PATH="$WT_ROOT/tests/fakes:$PATH" FAKE_LOG="$log" \
    DEVENV_CONFIG_DIR="$DEVENV_CONFIG_DIR" \
    "$WT_ROOT/bin/wt" gc --dry-run
  [ "$status" -eq 0 ]
  grep -q "docker compose ls" "$log"
}
