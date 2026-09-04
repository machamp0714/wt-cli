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
