# Orca hook の設定

Orca アプリ → 対象リポジトリの設定 → Hooks に、次の 2 欄がある。CLI から設定する方法は今のところ無く、
Orca アプリの UI に直接貼り付ける。

| 欄 | 値 |
|---|---|
| Setup script | `"$HOME/repo/wt-cli/bin/wt" setup` |
| Archive script | `"$HOME/repo/wt-cli/bin/wt" teardown` |

現在の設定値は次で確認できる:

    orca repo show --repo name:<repo> --json | jq .result.repo.hookSettings

## hook の実行 cwd について

hook が新しい worktree を cwd として実行されるかどうかは未確認（2026-09 時点）。初回設定時は Setup script に
一時的に次を入れて確認する:

    pwd > /tmp/orca-setup-cwd.txt; env > /tmp/orca-setup-env.txt

worktree を作成した後 `/tmp/orca-setup-cwd.txt` の内容が新しい worktree のパスであれば、上表の
`"$HOME/repo/wt-cli/bin/wt" setup` のまま使ってよい。違うパスであれば、`env` の出力から worktree のパスを
示す変数を探し、`"$HOME/repo/wt-cli/bin/wt" setup <path>` の形で明示的にパスを渡すよう Setup script を書き換える。
確認が終わったら probe 用の 2 行は削除する。

## その他の注意

- `wt` は自身で `/opt/homebrew/bin` を PATH に足し bash 5 で再実行するので、hook 側で PATH や SHELL を
  調整する必要はない。
- `--setup skip` で作った worktree は `wt setup` を手動で実行する。
