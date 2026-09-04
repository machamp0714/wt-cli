# bats 共通ヘルパー
WT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
export WT_ROOT

setup_tmp_config() {
  export DEVENV_CONFIG_DIR="$BATS_TEST_TMPDIR/config"
  export DEVENV_REPOS_DIR="$BATS_TEST_TMPDIR/repos"
  mkdir -p "$DEVENV_CONFIG_DIR" "$DEVENV_REPOS_DIR"
}

use_fakes() {
  export FAKE_LOG="$BATS_TEST_TMPDIR/fake.log"
  : > "$FAKE_LOG"
  export PATH="$WT_ROOT/tests/fakes:$PATH"
}

load_lib() {
  # shellcheck disable=SC1090
  source "$WT_ROOT/lib/common.sh"
  for f in "$@"; do source "$WT_ROOT/lib/$f.sh"; done
}

# テスト用 git リポジトリを作る: make_repo <path> [worktree-name...]
make_repo() {
  local path=$1; shift
  git init -q -b main "$path"
  git -C "$path" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  local w
  for w in "$@"; do git -C "$path" worktree add -q "$path/.claude/worktrees/$w" -b "b-$w"; done
}
