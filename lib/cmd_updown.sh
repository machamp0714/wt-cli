# shellcheck shell=bash
# wt up / wt down。cwd の worktree の compose を .envrc 付きで操作する。
# COMPOSE_FILE と COMPOSE_PROJECT_NAME は .envrc から入るので docker compose に引数は不要。

cmd_up() {
  local wt devenv mode
  need docker
  wt=$(wt_worktree_root "$PWD")
  wt_load_envrc "$wt"
  wt_proxy_require
  devenv=$(wt_devenv_file "$wt")
  mode=$(wt_config_get "$devenv" .mode docker)
  (cd "$wt" && docker compose up -d "$@")
  if [ "$mode" = host ]; then
    log "インフラを起動しました。アプリはこの worktree で起動してください（PORT=${PORT:-?} で listen）"
    log "例: PORT=${PORT:-3000} pnpm dev"
  fi
  printf '\n  %s\n\n' "$APP_URL"
}

cmd_down() {
  local wt
  need docker
  wt=$(wt_worktree_root "$PWD")
  wt_load_envrc "$wt"
  (cd "$wt" && docker compose down)
}
