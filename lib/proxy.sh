# shellcheck shell=bash
# 常駐プロキシ（caddy-docker-proxy）の管理。関数定義のみ。
WT_PROXY_NETWORK=devproxy
WT_PROXY_CONTAINER=devenv-caddy

wt_proxy_compose() {
  docker compose -f "$WT_ROOT/proxy/docker-compose.yml" -p devenv-proxy "$@"
}

wt_proxy_ensure_network() {
  if ! docker network inspect "$WT_PROXY_NETWORK" >/dev/null 2>&1; then
    log "docker network $WT_PROXY_NETWORK を作成"
    docker network create "$WT_PROXY_NETWORK" >/dev/null
  fi
}

wt_proxy_running() {
  docker ps --format '{{.Names}}' | grep -qx "$WT_PROXY_CONTAINER"
}

wt_proxy_ports_published() {
  docker port "$WT_PROXY_CONTAINER" 443/tcp >/dev/null 2>&1
}

wt_proxy_up() {
  wt_proxy_ensure_network
  if wt_proxy_running && ! wt_proxy_ports_published; then
    wt_proxy_compose up -d --force-recreate
  else
    wt_proxy_compose up -d
  fi
}

wt_proxy_require() {
  wt_proxy_running || die "プロキシが起動していません。先に wt init を実行してください"
  wt_proxy_ports_published || die "プロキシのポート公開が外れています（Docker Desktop 再起動時の bind 競合）。wt init を実行してください"
}
