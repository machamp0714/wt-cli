#!/usr/bin/env bats
load helpers

setup() { setup_tmp_config; use_fakes; load_lib ports; }

@test "alloc は最小の空きから確保しレジストリに記録する" {
  run wt_ports_alloc /wt/a 3
  [ "$status" -eq 0 ]
  [ "$output" = "31000 31001 31002" ]
  [ "$(jq -r '."31001"' "$(wt_ports_file)")" = "/wt/a" ]
}

@test "登録済みと LISTEN 中のポートは飛ばす" {
  wt_ports_alloc /wt/a 1 >/dev/null
  FAKE_BUSY_PORTS="31001 31002" run wt_ports_alloc /wt/b 2
  [ "$output" = "31003 31004" ]
}

@test "release で owner の分だけ消える" {
  wt_ports_alloc /wt/a 2 >/dev/null
  wt_ports_alloc /wt/b 1 >/dev/null
  wt_ports_release /wt/a
  [ "$(wt_ports_for /wt/a)" = "" ]
  [ "$(wt_ports_for /wt/b)" = "31002" ]
  [ "$(wt_ports_owners)" = "/wt/b" ]
}

@test "範囲を使い切ったら die する" {
  WT_PORT_MAX=31001
  wt_ports_alloc /wt/a 2 >/dev/null
  run wt_ports_alloc /wt/b 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"wt gc"* ]]
}

@test "ports.json が無くても release は成功する" {
  run wt_ports_release /wt/none
  [ "$status" -eq 0 ]
}
