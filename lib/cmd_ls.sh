# shellcheck shell=bash
# wt ls。登録リポジトリの全 worktree を一覧する。

# name<TAB>status の TSV。$(...) の中で呼ぶと die の exit がサブシェルに閉じ込められ
# 呼び出し元に伝播しないため、必ず素の文（bare statement）として呼ぶこと。
wt_compose_status_map() {
  local raw
  raw=$(docker compose ls -a --format json) \
    || die "docker compose ls に失敗しました"
  printf '%s' "$raw" | jq -r '.[] | [.Name, .Status] | @tsv'
}

cmd_ls() {
  need git; need docker; need jq
  local repos; repos=$(wt_repos_list)
  if [ -z "$repos" ]; then
    log "登録リポジトリがありません。各リポジトリで wt setup または wt new を実行すると登録されます"
    return 0
  fi
  local statuses
  statuses=$(wt_compose_status_map) || exit "$?"
  {
    printf 'PROJECT\tURL\tBRANCH\tCOMPOSE\tPORTS\tPATH\n'
    local repo path branch project status ports
    while IFS= read -r repo; do
      while IFS= read -r path; do
        [ -n "$path" ] || continue
        branch=$(git -C "$path" branch --show-current 2>/dev/null || echo '?')
        project=$(wt_project_name "$path")
        status=$(awk -F'\t' -v p="$project" '$1 == p { print $2 }' <<<"$statuses")
        ports=$(wt_ports_for "$path" | paste -sd, -)
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$project" "https://$(wt_app_host "$path")" "${branch:-detached}" "${status:--}" "${ports:--}" "$path"
      done < <(git -C "$repo" worktree list --porcelain | awk '/^worktree / { sub(/^worktree /, ""); print }')
    done <<<"$repos"
  } | column -t -s $'\t'
}
