# shellcheck shell=bash
# wt init / wt trust

cmd_init() {
  need docker; need jq; need yq; need direnv
  wt_proxy_up
  wt_ports_init
  log "初期化完了。HTTPS を警告なしで使うには wt trust を実行してください"
}

cmd_trust() {
  need docker
  wt_proxy_require
  local crt="$DEVENV_CONFIG_DIR/caddy-root.crt"
  mkdir -p "$DEVENV_CONFIG_DIR"
  wt_proxy_compose cp caddy:/data/caddy/pki/authorities/local/root.crt "$crt"
  log "Caddy のルート CA を macOS のシステムキーチェーンに登録します（sudo が必要）"
  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$crt"
  log "登録しました: $crt"
}
