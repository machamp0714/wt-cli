#!/usr/bin/env bats
load helpers

setup() { setup_tmp_config; use_fakes; load_lib ports proxy cmd_init; }

@test "proxy compose ファイルは docker compose config で妥当" {
  PATH="${PATH#"$WT_ROOT/tests/fakes:"}"
  command -v docker >/dev/null || skip "docker なし"
  run docker compose -f "$WT_ROOT/proxy/docker-compose.yml" config
  [ "$status" -eq 0 ]
  [[ "$output" == *"CADDY_INGRESS_NETWORKS"* ]]
}

@test "ensure_network はネットワークが無い時だけ作る" {
  wt_proxy_ensure_network
  grep -q "docker network create devproxy" "$FAKE_LOG"
  : > "$FAKE_LOG"
  FAKE_DOCKER_NETWORKS=devproxy wt_proxy_ensure_network
  ! grep -q "network create" "$FAKE_LOG"
}

@test "running は devenv-caddy コンテナの有無で判定" {
  ! wt_proxy_running
  FAKE_DOCKER_PS_NAMES="devenv-caddy" wt_proxy_running
}

@test "ports_published は 443/tcp の公開有無で判定" {
  run wt_proxy_ports_published
  [ "$status" -eq 1 ]
  export FAKE_DOCKER_PORTS_PUBLISHED=1
  run wt_proxy_ports_published
  [ "$status" -eq 0 ]
  grep -qx "docker port devenv-caddy 443/tcp" "$FAKE_LOG"
}

@test "require は未稼働なら wt init を案内して die" {
  run wt_proxy_require
  [ "$status" -eq 1 ]
  [[ "$output" == *"wt init"* ]]
}

@test "require は稼働中でもポート未公開なら原因と wt init を案内して die" {
  export FAKE_DOCKER_PS_NAMES="devenv-caddy"
  run wt_proxy_require
  [ "$status" -eq 1 ]
  [[ "$output" == *"ポート公開が外れています"* ]]
  [[ "$output" == *"wt init"* ]]
}

@test "cmd_init はネットワーク作成・compose up・ports.json 初期化を行う" {
  run cmd_init
  [ "$status" -eq 0 ]
  grep -q "network create devproxy" "$FAKE_LOG"
  grep -q "compose -f $WT_ROOT/proxy/docker-compose.yml -p devenv-proxy up -d" "$FAKE_LOG"
  [ -f "$DEVENV_CONFIG_DIR/ports.json" ]
}

@test "cmd_init は稼働中でポート未公開ならプロキシを再作成する" {
  export FAKE_DOCKER_PS_NAMES="devenv-caddy"
  run cmd_init
  [ "$status" -eq 0 ]
  grep -q "compose -f $WT_ROOT/proxy/docker-compose.yml -p devenv-proxy up -d --force-recreate" "$FAKE_LOG"
}

@test "cmd_init はポート公開済みならプロキシを再作成しない" {
  export FAKE_DOCKER_PS_NAMES="devenv-caddy"
  export FAKE_DOCKER_PORTS_PUBLISHED=1
  run cmd_init
  [ "$status" -eq 0 ]
  grep -q "compose -f $WT_ROOT/proxy/docker-compose.yml -p devenv-proxy up -d" "$FAKE_LOG"
  ! grep -q -- "--force-recreate" "$FAKE_LOG"
}
