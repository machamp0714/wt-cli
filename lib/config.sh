# shellcheck shell=bash
# リポジトリ・worktree の名前導出と devenv 側リポジトリ設定の読み取り。関数定義のみ。

wt_repo_root() {
  local common
  common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
    || die "git リポジトリではありません: $1"
  dirname "$common"
}

wt_worktree_root() {
  git -C "$1" rev-parse --show-toplevel 2>/dev/null || die "git リポジトリではありません: $1"
}

wt_sanitize() {
  printf '%s' "$1" | tr '[:upper:]_' '[:lower:]-' | sed -E 's/[^a-z0-9-]/-/g; s/-+/-/g; s/^-|-$//g'
}

wt_repo_name() { wt_sanitize "$(basename "$(wt_repo_root "$1")")"; }

wt_worktree_name() {
  local root wt
  root=$(wt_repo_root "$1"); wt=$(wt_worktree_root "$1")
  if [ "$root" = "$wt" ]; then printf ''; else wt_sanitize "$(basename "$wt")"; fi
}

wt_project_name() {
  local r w
  r=$(wt_repo_name "$1"); w=$(wt_worktree_name "$1")
  if [ -n "$w" ]; then printf '%s-%s\n' "$r" "$w"; else printf '%s\n' "$r"; fi
}

wt_app_host() { printf '%s.localhost\n' "$(wt_project_name "$1")"; }

wt_repos_dir() { printf '%s\n' "${DEVENV_REPOS_DIR:-$DEVENV_CONFIG_DIR/repos}"; }

wt_repo_config_dir() {
  local d; d="$(wt_repos_dir)/$(wt_repo_name "$1")"
  if [ -d "$d" ]; then printf '%s\n' "$d"; else printf ''; fi
}

wt_devenv_file() {
  local d f; d=$(wt_repo_config_dir "$1")
  f="$d/devenv.yml"
  if [ -n "$d" ] && [ -f "$f" ]; then printf '%s\n' "$f"; else printf ''; fi
}

wt_compose_override_src() {
  local d f; d=$(wt_repo_config_dir "$1")
  f="$d/compose.devenv.yml"
  if [ -n "$d" ] && [ -f "$f" ]; then printf '%s\n' "$f"; else printf ''; fi
}

# COMPOSE_FILE の値。リポジトリの compose ファイルが無ければ空文字。
wt_compose_files() {
  local wt=$1 base="" override="" f
  for f in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
    [ -f "$wt/$f" ] && { base="$wt/$f"; break; }
  done
  [ -n "$base" ] || { printf ''; return 0; }
  for f in compose.override.yaml compose.override.yml docker-compose.override.yaml docker-compose.override.yml; do
    [ -f "$wt/$f" ] && { override="$wt/$f"; break; }
  done
  printf '%s%s:%s\n' "$base" "${override:+:$override}" "$wt/docker-compose.devenv.yml"
}

wt_config_get() {
  local file=$1 path=$2 default=${3-}
  if [ -n "$file" ] && [ -f "$file" ]; then
    need yq
    yq -r "$path // \"$default\"" "$file"
  else
    printf '%s\n' "$default"
  fi
}

wt_config_list() {
  local file=$1 path=$2
  [ -n "$file" ] && [ -f "$file" ] || return 0
  need yq
  # shellcheck disable=SC1087
  yq -r "$path[]?" "$file"
}

wt_config_json() {
  local file=$1 path=$2
  if [ -n "$file" ] && [ -f "$file" ]; then
    need yq
    yq -o=json "$path // {}" "$file"
  else
    printf '{}\n'
  fi
}
