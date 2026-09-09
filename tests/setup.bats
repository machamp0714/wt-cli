#!/usr/bin/env bats
load helpers

setup() {
  setup_tmp_config; use_fakes
  load_lib config ports envfile proxy compose cmd_setup
  REPO="$BATS_TEST_TMPDIR/example-app"
  make_repo "$REPO" 5552
  WT="$REPO/.claude/worktrees/5552"
  touch "$WT/docker-compose.yml"
  CFG="$DEVENV_REPOS_DIR/example-app"; mkdir -p "$CFG"
  export FAKE_DOCKER_PS_NAMES="devenv-caddy"
  export FAKE_DOCKER_PORTS_PUBLISHED=1
}

@test "docker 型: .envrc、override コピー、direnv allow、setup 実行、repos.txt 登録" {
  cat > "$CFG/devenv.yml" <<'EOF'
mode: docker
setup:
  - echo "step1 $COMPOSE_PROJECT_NAME" > setup.out
  - echo "step2 $APP_HOST $COMPOSE_FILE" >> setup.out
EOF
  printf 'services:\n  app:\n    labels:\n      caddy: ${APP_HOST}\n' > "$CFG/compose.devenv.yml"
  run cmd_setup "$WT"
  [ "$status" -eq 0 ]
  grep -q 'COMPOSE_PROJECT_NAME="example-app-5552"' "$WT/.envrc"
  grep -q "COMPOSE_FILE=\"$WT/docker-compose.yml:$WT/docker-compose.devenv.yml\"" "$WT/.envrc"
  cmp -s "$CFG/compose.devenv.yml" "$WT/docker-compose.devenv.yml"
  grep -q "direnv allow $WT" "$FAKE_LOG"
  [ "$(sed -n 1p "$WT/setup.out")" = "step1 example-app-5552" ]
  [ "$(sed -n 2p "$WT/setup.out")" = "step2 example-app-5552.localhost $WT/docker-compose.yml:$WT/docker-compose.devenv.yml" ]
  grep -qx "$REPO" "$DEVENV_CONFIG_DIR/repos.txt"
  [[ "$output" == *"https://example-app-5552.localhost"* ]]
  [ -z "$(wt_ports_for "$WT")" ]
}

@test "override が無ければ COMPOSE_FILE を書かない" {
  printf 'mode: docker\n' > "$CFG/devenv.yml"
  cmd_setup "$WT"
  ! grep -q COMPOSE_FILE "$WT/.envrc"
  [ ! -f "$WT/docker-compose.devenv.yml" ]
}

@test "host 型: ポート割当と .env 生成" {
  cat > "$CFG/devenv.yml" <<'EOF'
mode: host
ports: [PORT, PG_PORT]
env_template: .env.example
env_overrides:
  DATABASE_URL: "postgresql://u:p@localhost:${PG_PORT}/db"
  NEXT_PUBLIC_APP_URL: "https://${APP_HOST}"
EOF
  printf 'DATABASE_URL="x"\nJWT_SECRET="dev"\n' > "$WT/.env.example"
  run cmd_setup "$WT"
  [ "$status" -eq 0 ]
  grep -q 'export PORT="31000"' "$WT/.envrc"
  grep -q 'export PG_PORT="31001"' "$WT/.envrc"
  grep -q 'DATABASE_URL="postgresql://u:p@localhost:31001/db"' "$WT/.env"
  grep -q 'NEXT_PUBLIC_APP_URL="https://example-app-5552.localhost"' "$WT/.env"
  [ "$(wt_ports_for "$WT" | tr '\n' ' ')" = "31000 31001 " ]
}

@test "host 型: main worktree に .env があればそれをテンプレートに使う" {
  printf 'mode: host\nports: [PORT]\nenv_template: .env.example\n' > "$CFG/devenv.yml"
  printf 'JWT_SECRET="example"\n' > "$WT/.env.example"
  printf 'JWT_SECRET="real-local"\n' > "$REPO/.env"
  cmd_setup "$WT"
  grep -q 'JWT_SECRET="real-local"' "$WT/.env"
}

@test "setup の再実行はポートを再割当せず同じ値を保つ" {
  printf 'mode: host\nports: [PORT, PG_PORT]\n' > "$CFG/devenv.yml"
  cmd_setup "$WT"
  local first envrc_first
  first=$(wt_ports_for "$WT" | paste -sd, -)
  envrc_first=$(grep -E '^export (PORT|PG_PORT)=' "$WT/.envrc")
  cmd_setup "$WT"
  [ "$(wt_ports_for "$WT" | paste -sd, -)" = "$first" ]
  [ "$(grep -E '^export (PORT|PG_PORT)=' "$WT/.envrc")" = "$envrc_first" ]
}

@test "ポート名→番号の対応は登録順が非連番でも再実行後も安定する" {
  printf 'mode: host\nports: [PORT, PG_PORT]\n' > "$CFG/devenv.yml"
  mkdir -p "$DEVENV_CONFIG_DIR"
  printf '{"31005":"%s","31002":"%s"}\n' "$WT" "$WT" > "$(wt_ports_file)"
  cmd_setup "$WT"
  grep -q 'export PORT="31002"' "$WT/.envrc"
  grep -q 'export PG_PORT="31005"' "$WT/.envrc"
  cmd_setup "$WT"
  grep -q 'export PORT="31002"' "$WT/.envrc"
  grep -q 'export PG_PORT="31005"' "$WT/.envrc"
}

@test "ポート再割当に失敗したら既存の割当を保持したまま die する" {
  cat > "$CFG/devenv.yml" <<'EOF'
mode: host
ports: [PORT, PG_PORT]
EOF
  # 事前に 1 ポートだけ割り当てられている状態（config 変更前の名残）を再現
  wt_ports_alloc "$WT" 1 >/dev/null
  export WT_PORT_MIN=31001 WT_PORT_MAX=31001
  # 唯一の空きポートを別オーナーが確保し、範囲を使い切る
  wt_ports_alloc /other/wt 1 >/dev/null
  run cmd_setup "$WT"
  [ "$status" -eq 1 ]
  [ "$(wt_ports_for "$WT")" = "31000" ]
}

@test "生成物は git に無視される（.gitignore に無くても）" {
  printf 'mode: host\nports: [PORT]\nenv_template: .env.example\n' > "$CFG/devenv.yml"
  printf 'A=1\n' > "$WT/.env.example"
  echo 'services: {}' > "$CFG/compose.devenv.yml"
  cmd_setup "$WT"
  git -C "$WT" check-ignore -q .envrc
  git -C "$WT" check-ignore -q .env
  git -C "$WT" check-ignore -q docker-compose.devenv.yml
  [ -z "$(git -C "$WT" status --porcelain -- .envrc .env docker-compose.devenv.yml)" ]
  grep -qx '/.envrc' "$REPO/.git/info/exclude"
  mkdir -p "$WT/sub"
  ! git -C "$WT" check-ignore -q sub/.env
}

@test "既に .gitignore で無視されていれば info/exclude には書かない" {
  printf '.envrc\n.env\ndocker-compose.devenv.yml\n' > "$WT/.gitignore"
  printf 'mode: docker\n' > "$CFG/devenv.yml"
  cmd_setup "$WT"
  [ ! -f "$REPO/.git/info/exclude" ] || ! grep -qx '.envrc' "$REPO/.git/info/exclude"
}

@test "setup ステップが失敗したら以降を止めて wt rm を案内" {
  cat > "$CFG/devenv.yml" <<'EOF'
mode: docker
setup:
  - "false"
  - touch never.out
EOF
  run cmd_setup "$WT"
  [ "$status" -eq 1 ]
  [ ! -f "$WT/never.out" ]
  [[ "$output" == *"wt rm"* ]]
}

@test "setup ステップが標準入力を読んでも後続ステップは消費されず実行される" {
  cat > "$CFG/devenv.yml" <<'EOF'
mode: docker
setup:
  - cat >/dev/null; echo one >> steps.out
  - echo two >> steps.out
  - echo three >> steps.out
EOF
  run cmd_setup "$WT"
  [ "$status" -eq 0 ]
  [ "$(cat "$WT/steps.out")" = "$(printf 'one\ntwo\nthree')" ]
}

@test "設定が無ければ .envrc だけ作って警告" {
  rmdir "$CFG"
  run cmd_setup "$WT"
  [ "$status" -eq 0 ]
  [ -f "$WT/.envrc" ]
  [[ "$output" == *"repos/"* ]]
}

@test "devenv.yml が壊れていれば setup を実行せず die する" {
  cat > "$CFG/devenv.yml" <<'EOF'
mode: [unclosed
setup:
  - touch should-not-run.out
EOF
  run cmd_setup "$WT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"devenv.yml"* ]]
  [ ! -f "$WT/should-not-run.out" ]
}

@test "プロキシ未稼働なら die" {
  FAKE_DOCKER_PS_NAMES="" run cmd_setup "$WT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"wt init"* ]]
}

@test "teardown は compose down とポート解放を行う" {
  printf 'mode: host\nports: [PORT]\n' > "$CFG/devenv.yml"
  cmd_setup "$WT"
  : > "$FAKE_LOG"
  run cmd_teardown "$WT"
  [ "$status" -eq 0 ]
  grep -q "docker compose -p example-app-5552 down -v --rmi local --remove-orphans" "$FAKE_LOG"
  [ -z "$(wt_ports_for "$WT")" ]
}

@test "wt 以外が作った .envrc は上書きせず die し info/exclude も増やさない" {
  printf 'mode: docker\n' > "$CFG/devenv.yml"
  printf 'export MINE=1\n' > "$WT/.envrc"
  git -C "$WT" add -f .envrc
  git -C "$WT" -c user.email=t@t -c user.name=t commit -qm envrc
  run cmd_setup "$WT"
  [ "$status" -eq 1 ]
  [[ "$output" == *".envrc"* ]]
  [ "$(cat "$WT/.envrc")" = "export MINE=1" ]
  [ ! -f "$REPO/.git/info/exclude" ] || ! grep -qx '/.envrc' "$REPO/.git/info/exclude"
}

@test "host 型: wt 以外が作った .env は上書きせず die する" {
  printf 'mode: host\nports: [PORT]\nenv_template: .env.example\n' > "$CFG/devenv.yml"
  printf 'A="1"\n' > "$WT/.env.example"
  printf 'SECRET="real"\n' > "$WT/.env"
  run cmd_setup "$WT"
  [ "$status" -eq 1 ]
  [[ "$output" == *".env"* ]]
  [ "$(cat "$WT/.env")" = 'SECRET="real"' ]
}

@test "host 型: wt が生成した .env は再実行で上書きされる" {
  printf 'mode: host\nports: [PORT]\nenv_template: .env.example\n' > "$CFG/devenv.yml"
  printf 'A="1"\n' > "$WT/.env.example"
  cmd_setup "$WT"
  [ "$(head -1 "$WT/.env")" = "$WT_ENVRC_MARKER" ]
  printf 'A="2"\n' > "$WT/.env.example"
  cmd_setup "$WT"
  grep -q 'A="2"' "$WT/.env"
}

@test "teardown は compose down 失敗時に stderr の末尾を添えて警告する" {
  printf 'mode: docker\n' > "$CFG/devenv.yml"
  cmd_setup "$WT"
  : > "$FAKE_LOG"
  export FAKE_DOCKER_FAIL_COMPOSE_DOWN=1
  run cmd_teardown "$WT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"停止に失敗しました"* ]]
  [[ "$output" == *"fake docker: compose down failed"* ]]
}
