# shellcheck shell=bash
# docker compose 操作、repos.txt、info/exclude。関数定義のみ。

wt_compose_down() {
  docker compose -p "$1" down -v --rmi local --remove-orphans
}

wt_repos_file() { printf '%s/repos.txt\n' "$DEVENV_CONFIG_DIR"; }

wt_repos_add() {
  mkdir -p "$DEVENV_CONFIG_DIR"
  touch "$(wt_repos_file)"
  grep -qxF "$1" "$(wt_repos_file)" || printf '%s\n' "$1" >> "$(wt_repos_file)"
}

wt_repos_list() {
  [ -f "$(wt_repos_file)" ] || return 0
  while IFS= read -r r; do [ -d "$r" ] && printf '%s\n' "$r"; done < "$(wt_repos_file)"
  return 0
}

wt_load_envrc() {
  local f="$1/.envrc"
  [ -f "$f" ] || die ".envrc がありません。wt setup を実行してください: $1"
  set -a
  # shellcheck disable=SC1090
  source "$f"
  set +a
}

# 生成物が誤ってコミットされないよう、無視されていなければ .git/info/exclude に足す。
# info/exclude は git common dir 配下なので main と全 worktree に共通して効く。
# 個人用ツールなので各リポジトリの .gitignore は変更しない。
wt_ensure_ignored() {
  local wt=$1; shift
  local common exclude path
  common=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir)
  exclude="$common/info/exclude"
  for path in "$@"; do
    if ! git -C "$wt" check-ignore -q "$path"; then
      mkdir -p "$common/info"
      printf '/%s\n' "$path" >> "$exclude"
      log "$path を $exclude に追加（コミット対象外にする）"
    fi
  done
}

# name<TAB>first_config_file
wt_compose_projects() {
  need jq
  docker compose ls -a --format json \
    | jq -r '.[] | select(.ConfigFiles != null and .ConfigFiles != "") | [.Name, (.ConfigFiles | split(",")[0])] | @tsv'
}

wt_compose_orphans() {
  local name file
  while IFS=$'\t' read -r name file; do
    [ -e "$file" ] || printf '%s\n' "$name"
  done < <(wt_compose_projects)
}

wt_compose_mismatched() {
  local name file dir expected
  while IFS=$'\t' read -r name file; do
    [ -e "$file" ] || continue
    dir=$(dirname "$file")
    git -C "$dir" rev-parse --show-toplevel >/dev/null 2>&1 || continue
    expected=$(wt_project_name "$dir")
    [ "$name" = "$expected" ] || printf '%s\t%s\n' "$name" "$expected"
  done < <(wt_compose_projects)
}
