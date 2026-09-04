#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_config
  load_lib config
  REPO="$BATS_TEST_TMPDIR/Example_App"
  make_repo "$REPO" 5552
  WT="$REPO/.claude/worktrees/5552"
}

@test "main worktree の project 名は repo 名のみ" {
  [ "$(wt_repo_root "$REPO")" = "$REPO" ]
  [ "$(wt_worktree_name "$REPO")" = "" ]
  [ "$(wt_project_name "$REPO")" = "example-app" ]
  [ "$(wt_app_host "$REPO")" = "example-app.localhost" ]
}

@test "worktree の project 名は repo-worktree" {
  [ "$(wt_repo_root "$WT")" = "$REPO" ]
  [ "$(wt_worktree_root "$WT")" = "$WT" ]
  [ "$(wt_worktree_name "$WT")" = "5552" ]
  [ "$(wt_project_name "$WT")" = "example-app-5552" ]
  [ "$(wt_app_host "$WT")" = "example-app-5552.localhost" ]
}

@test "サブディレクトリからでも同じ結果" {
  mkdir -p "$WT/src/deep"
  [ "$(wt_project_name "$WT/src/deep")" = "example-app-5552" ]
}

@test "repos/<repo>/ の設定を読む" {
  mkdir -p "$DEVENV_REPOS_DIR/example-app"
  cat > "$DEVENV_REPOS_DIR/example-app/devenv.yml" <<'EOF'
mode: host
ports: [PORT, PG_PORT]
env_template: .env.example
env_overrides:
  DATABASE_URL: "postgresql://u:p@localhost:${PG_PORT}/db"
setup:
  - echo one
  - echo two
EOF
  echo 'services: {}' > "$DEVENV_REPOS_DIR/example-app/compose.devenv.yml"
  [ "$(wt_repo_config_dir "$WT")" = "$DEVENV_REPOS_DIR/example-app" ]
  f=$(wt_devenv_file "$WT")
  [ "$f" = "$DEVENV_REPOS_DIR/example-app/devenv.yml" ]
  [ "$(wt_compose_override_src "$WT")" = "$DEVENV_REPOS_DIR/example-app/compose.devenv.yml" ]
  [ "$(wt_config_get "$f" .mode docker)" = "host" ]
  [ "$(wt_config_get "$f" .missing docker)" = "docker" ]
  [ "$(wt_config_list "$f" .ports | tr '\n' ' ')" = "PORT PG_PORT " ]
  [ "$(wt_config_list "$f" .setup | wc -l | tr -d ' ')" = "2" ]
  [ "$(wt_config_json "$f" .env_overrides | jq -r .DATABASE_URL)" = 'postgresql://u:p@localhost:${PG_PORT}/db' ]
  [ "$(wt_config_json "$f" .nothing)" = "{}" ]
}

@test "設定が無ければ空文字と既定値" {
  [ "$(wt_repo_config_dir "$WT")" = "" ]
  [ "$(wt_devenv_file "$WT")" = "" ]
  [ "$(wt_compose_override_src "$WT")" = "" ]
  [ "$(wt_config_get "" .mode docker)" = "docker" ]
  [ "$(wt_config_list "" .ports)" = "" ]
}

@test "COMPOSE_FILE は compose, override(あれば), devenv の順の絶対パス" {
  touch "$WT/docker-compose.yml"
  [ "$(wt_compose_files "$WT")" = "$WT/docker-compose.yml:$WT/docker-compose.devenv.yml" ]
  touch "$WT/docker-compose.override.yml"
  [ "$(wt_compose_files "$WT")" = "$WT/docker-compose.yml:$WT/docker-compose.override.yml:$WT/docker-compose.devenv.yml" ]
}

@test "COMPOSE_FILE は compose.yaml も認識し、無ければ空文字" {
  [ "$(wt_compose_files "$WT")" = "" ]
  touch "$WT/compose.yaml"
  [ "$(wt_compose_files "$WT")" = "$WT/compose.yaml:$WT/docker-compose.devenv.yml" ]
}
