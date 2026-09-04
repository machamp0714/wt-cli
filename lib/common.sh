# shellcheck shell=bash
# 共通ユーティリティ。関数定義のみ。
DEVENV_CONFIG_DIR="${DEVENV_CONFIG_DIR:-$HOME/.config/devenv}"

log() { printf '[wt] %s\n' "$*" >&2; }
die() { printf '[wt] error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 が必要です（brew install $1）"; }
