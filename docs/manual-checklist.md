# 結合チェックリスト

前提: `wt init` と `wt trust` 済み、Orca と Claude Code / Codex の hook 登録済み。

- [ ] 設定済みの業務リポジトリで `wt new chk-a` と `wt new chk-b` を作り、両方で `wt up`
- [ ] 2 つの URL に同時に curl して両方応答する
      - https://<repo>-chk-a.localhost
      - https://<repo>-chk-b.localhost
      - http://<repo>-chk-a.localhost（証明書未信頼のブラウザ用）
      - http://<repo>-chk-b.localhost（証明書未信頼のブラウザ用）
- [ ] ブラウザ（Chrome）で証明書警告なしに開ける。Safari の挙動も記録する
- [ ] `wt ls` に 2 本が正しい compose 状態で並ぶ
- [ ] chk-a の中で `git status` に生成物（.envrc, docker-compose.devenv.yml）が出ない
- [ ] chk-a の中で `claude` を起動し、URL と規約が注入されている
- [ ] Orca から worktree を 1 本作り、setup hook で URL が出る。Orca から削除して compose が残らない
- [ ] 2 本を `wt rm` し、`docker compose ls -a` と `docker volume ls` に痕跡が無い
- [ ] `wt gc --dry-run` が「回収対象はありません」を出す
