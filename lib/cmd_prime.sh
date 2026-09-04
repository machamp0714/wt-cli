# shellcheck shell=bash
# wt prime。Claude Code / Codex の SessionStart / PreCompact hook から呼ばれ、
# cwd が wt 管理の worktree のときだけ URL と規約を stdout に出す（bd prime と同じ要領）。

cmd_prime() {
  local wt envrc
  wt=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
  envrc="$wt/.envrc"
  [ -f "$envrc" ] || return 0
  [ "$(head -1 "$envrc")" = "$WT_ENVRC_MARKER" ] || return 0

  local APP_URL="" COMPOSE_PROJECT_NAME="" DEVENV_WORKTREE="" COMPOSE_FILE="" PORT=""
  # shellcheck disable=SC1090
  source "$envrc"

  echo "## devenv (wt) — この worktree の開発環境"
  echo "- アプリ URL: ${APP_URL}（\`localhost:3000\` は使わない。ブラウザも curl もこの URL）"
  if [ -n "$COMPOSE_FILE" ]; then
    echo "- compose プロジェクト: ${COMPOSE_PROJECT_NAME}。\`docker compose\` は .envrc の COMPOSE_FILE により devenv の override 込みで動く"
  else
    echo "- compose プロジェクト: ${COMPOSE_PROJECT_NAME}"
  fi
  echo "- 起動 / 停止: \`wt up\` / \`wt down\`。ポートを手で変えない。compose の override ファイルを自作しない"
  if [ -n "$PORT" ]; then
    echo "- アプリはホストで起動する: \`PORT=${PORT}\` で listen させる（direnv が export 済み）"
  fi
  if [ -n "$DEVENV_WORKTREE" ]; then
    echo "- 一覧: \`wt ls\`。この worktree の削除は Orca の archive か \`wt rm ${DEVENV_WORKTREE}\`"
  else
    echo "- 一覧: \`wt ls\`。ここは main worktree なので削除しない"
  fi
}
