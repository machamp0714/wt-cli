# devenv — worktree 並列開発環境（個人用）

worktree ごとに `https://<repo>-<worktree>.localhost` でアプリを起動し、削除で全部回収する `wt` CLI。
共有リポジトリには一切変更を加えない。リポジトリごとの差分は `~/.config/devenv/repos/<repo>/` に持つ（このリポジトリには一般例 `repos/example/` だけを置く）。

## 導入

    brew install jq yq direnv bash bats-core shellcheck
    ln -s ~/repo/devenv/bin/wt /opt/homebrew/bin/wt
    wt init      # devproxy ネットワークと Caddy を起動
    wt trust     # Caddy のルート CA を信頼（sudo）

`wt trust` は sudo を要する。実行していなくても `http://<repo>-<worktree>.localhost` ではブラウザから開ける
（Caddy に HTTP サイトを併設しているため）。証明書警告なしで開くには `wt trust` が必要。

Orca の hook は docs/orca-hooks.md、Claude Code / Codex の hook は docs/agent-hooks.md を参照。

## 使い方

    wt new 5552                 # worktree 作成 + setup、URL を表示（Orca から作る場合は不要）
    cd .claude/worktrees/5552
    wt up                       # compose 起動（host 型はアプリを別途起動）
    wt ls                       # 全 worktree の URL と状態
    wt rm 5552                  # teardown + worktree 削除（未コミットの変更があれば --force）
    wt gc --dry-run             # 孤児の確認

## エージェントへの規約注入

`wt prime` を Claude Code / Codex の SessionStart / PreCompact hook に登録すると、worktree 内で起動した
エージェントに URL と規約が自動で渡る。詳細は docs/agent-hooks.md を参照。

## リポジトリの追加

`~/.config/devenv/repos/<repo名>/devenv.yml`（mode / setup / host 型なら ports と env_overrides）と、
必要なら同じ場所に `compose.devenv.yml`（上流 compose に重ねる override）を置く。
`<repo名>` は main リポジトリのディレクトリ名を小文字化し、英数字とハイフン以外を `-` に置き換えたもの（例: `Example_App` → `example-app`）。雛形は `repos/example/` をコピーする。

## 開発

    make test
    make lint
