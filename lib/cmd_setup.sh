# shellcheck shell=bash
# wt setup / wt teardown。Orca の setup / archive hook から cwd で呼ばれる。

cmd_setup() {
  local dir="${1:-$PWD}" wt root repo wtname project host devenv mode override
  need git; need docker; need direnv
  wt_proxy_require
  wt=$(wt_worktree_root "$dir"); root=$(wt_repo_root "$dir")
  repo=$(wt_repo_name "$dir"); wtname=$(wt_worktree_name "$dir")
  project=$(wt_project_name "$dir"); host=$(wt_app_host "$dir")
  devenv=$(wt_devenv_file "$dir"); override=$(wt_compose_override_src "$dir")
  mode=$(wt_config_get "$devenv" .mode docker)
  [ -n "$devenv" ] || log "警告: $(wt_repos_dir)/$repo/devenv.yml が無いため .envrc の生成のみ行います"

  # host 型はポート割当（再実行時は既存の割当を使う）
  local extra=() names=() ports=() i
  if [ "$mode" = host ]; then
    local names_raw
    names_raw=$(wt_config_list "$devenv" .ports) || die "devenv.yml の読み取りに失敗しました: $devenv"
    [ -n "$names_raw" ] && mapfile -t names <<<"$names_raw"
    if [ "${#names[@]}" -gt 0 ]; then
      mapfile -t ports < <(wt_ports_for "$wt")
      if [ "${#ports[@]}" -ne "${#names[@]}" ]; then
        # 新しい割当が確定するまで既存の割当は残す。一時オーナーで確保してから移し替える
        local fresh tmp_owner="$wt#pending"
        fresh=$(wt_ports_alloc "$tmp_owner" "${#names[@]}") \
          || die "ポート割当に失敗しました（wt gc で解放漏れを回収してください）"
        wt_ports_release "$wt"
        wt_ports_release "$tmp_owner"
        read -ra ports <<<"$fresh"
        wt_ports_assign "$wt" "${ports[@]}"
      fi
      for i in "${!names[@]}"; do extra+=("${names[$i]}=${ports[$i]}"); done
    fi
  fi

  # 生成物は途中で中断してもコミット対象にならないよう、書き出す前に無視設定を済ませる
  wt_ensure_ignored "$wt" .envrc .env docker-compose.devenv.yml

  # compose override をコピーし COMPOSE_FILE を組み立てる
  if [ -n "$override" ]; then
    cp "$override" "$wt/docker-compose.devenv.yml"
    local files; files=$(wt_compose_files "$wt")
    if [ -n "$files" ]; then
      extra+=("COMPOSE_FILE=$files")
    else
      log "警告: compose ファイルが見つからないため COMPOSE_FILE を設定しません"
    fi
  fi

  wt_write_envrc "$wt" "$repo" "$wtname" "$project" "$host" "${extra[@]}"
  direnv allow "$wt"
  wt_load_envrc "$wt"

  # host 型は .env を生成。main worktree の .env があればそれをテンプレートにする
  if [ "$mode" = host ]; then
    local template out
    template=$(wt_config_get "$devenv" .env_template .env.example)
    out="$wt/.env"
    if [ -f "$root/.env" ] && [ "$root" != "$wt" ]; then
      log ".env は main worktree の .env をテンプレートにします"
      wt_write_env "$root/.env" "$out" "$(wt_config_json "$devenv" .env_overrides)"
    elif [ -f "$wt/$template" ]; then
      wt_write_env "$wt/$template" "$out" "$(wt_config_json "$devenv" .env_overrides)"
    else
      log "警告: テンプレート $template が無いため .env を生成しません"
    fi
  fi

  # setup ステップ
  local steps_raw
  steps_raw=$(wt_config_list "$devenv" .setup) || die "devenv.yml の読み取りに失敗しました: $devenv"
  local step n=0
  while IFS= read -r step; do
    [ -n "$step" ] || continue
    n=$((n + 1))
    log "setup[$n]: $step"
    if ! (cd "$wt" && bash -c "$step"); then
      die "setup[$n] が失敗しました。作成済みリソースは残しています。撤収は wt rm ${wtname:-<name>}"
    fi
  done <<<"$steps_raw"

  wt_repos_add "$root"
  printf '\n  %s\n\n' "https://$host"
}

cmd_teardown() {
  local dir="${1:-$PWD}" wt project
  need git; need docker
  wt=$(wt_worktree_root "$dir"); project=$(wt_project_name "$dir")
  if ! wt_compose_down "$project" 2>/dev/null; then
    log "警告: compose プロジェクト $project の停止に失敗（既に無い可能性）"
  fi
  wt_ports_release "$wt"
  log "teardown 完了: $project"
}
