# shellcheck shell=bash
# wt new / wt rm。git worktree の作成・削除と setup / teardown のラッパー。

wt_worktree_path() { printf '%s/.claude/worktrees/%s\n' "$1" "$2"; }

cmd_new() {
  local name="${1:-}" base="" branch=""
  [ -n "$name" ] || die "usage: wt new <name> [--base <ref>] [--branch <branch>]"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --base) base="$2"; shift 2 ;;
      --branch) branch="$2"; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
  need git
  local root path
  root=$(wt_repo_root "$PWD")
  path=$(wt_worktree_path "$root" "$name")
  [ ! -e "$path" ] || die "既に存在します: $path"
  [ -n "$branch" ] || branch="$name"

  if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
    log "既存ブランチ $branch をチェックアウト"
    git -C "$root" worktree add "$path" "$branch"
  else
    git -C "$root" worktree add "$path" -b "$branch" ${base:+"$base"}
  fi
  cmd_setup "$path"
}

cmd_rm() {
  local name="${1:-}"
  [ -n "$name" ] || die "usage: wt rm <name>"
  need git
  local root path branch
  root=$(wt_repo_root "$PWD")
  path=$(wt_worktree_path "$root" "$name")
  [ -d "$path" ] || die "worktree がありません: $path"
  branch=$(git -C "$path" branch --show-current)

  cmd_teardown "$path"
  git -C "$root" worktree remove --force "$path"
  if [ -n "$branch" ]; then
    if git -C "$root" branch -d "$branch" >/dev/null 2>&1; then
      log "ブランチ $branch を削除"
    else
      log "警告: ブランチ $branch は未マージのため残しました（git branch -D $branch で強制削除）"
    fi
  fi
  log "削除完了: $path"
}
