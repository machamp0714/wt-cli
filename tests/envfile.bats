#!/usr/bin/env bats
load helpers

setup() { load_lib envfile; D="$BATS_TEST_TMPDIR"; }

@test ".envrc はマーカーで始まり基本変数が入る" {
  wt_write_envrc "$D" example-app 5552 example-app-5552 example-app-5552.localhost
  [ "$(head -1 "$D/.envrc")" = "$WT_ENVRC_MARKER" ]
  run cat "$D/.envrc"
  [[ "$output" == *'export DEVENV_REPO="example-app"'* ]]
  [[ "$output" == *'export DEVENV_WORKTREE="5552"'* ]]
  [[ "$output" == *'export COMPOSE_PROJECT_NAME="example-app-5552"'* ]]
  [[ "$output" == *'export APP_HOST="example-app-5552.localhost"'* ]]
  [[ "$output" == *'export APP_URL="https://example-app-5552.localhost"'* ]]
  [[ "$output" != *"export PORT="* ]]
}

@test ".envrc に追加の NAME=VALUE が入る" {
  wt_write_envrc "$D" r w r-w r-w.localhost PORT=31000 "COMPOSE_FILE=/a/x.yml:/a/y.yml"
  run cat "$D/.envrc"
  [[ "$output" == *'export PORT="31000"'* ]]
  [[ "$output" == *'export COMPOSE_FILE="/a/x.yml:/a/y.yml"'* ]]
}

@test "wt_expand は環境変数を展開する" {
  PG_PORT=31001 run wt_expand 'postgresql://u:p@localhost:${PG_PORT}/db'
  [ "$output" = "postgresql://u:p@localhost:31001/db" ]
}

@test ".env はコメント行・既存行を置換し無いキーを追記する" {
  cat > "$D/.env.example" <<'EOF'
DATABASE_URL="postgresql://user:pass@localhost:5433/example?schema=public"
JWT_SECRET="dev"
# REDIS_URL="redis://localhost:6379"
EOF
  overrides='{"DATABASE_URL":"postgresql://u:p@localhost:${PG_PORT}/db","REDIS_URL":"redis://localhost:${REDIS_PORT}","NEXT_PUBLIC_APP_URL":"https://${APP_HOST}"}'
  PG_PORT=31001 REDIS_PORT=31002 APP_HOST=t.localhost wt_write_env "$D/.env.example" "$D/.env" "$overrides"
  run cat "$D/.env"
  [[ "$output" == *'DATABASE_URL="postgresql://u:p@localhost:31001/db"'* ]]
  [[ "$output" == *'REDIS_URL="redis://localhost:31002"'* ]]
  [[ "$output" != *'# REDIS_URL'* ]]
  [[ "$output" == *'JWT_SECRET="dev"'* ]]
  [[ "$output" == *'NEXT_PUBLIC_APP_URL="https://t.localhost"'* ]]
  [ "$(grep -c '^DATABASE_URL=' "$D/.env")" = "1" ]
}

@test ".envrc の値に \" と \\ が含まれてもシェルとして正しく読める" {
  wt_write_envrc "$D" r w r-w r-w.localhost 'X=a"b\c'
  run bash -c "source '$D/.envrc' && printf '%s' \"\$X\""
  [ "$output" = 'a"b\c' ]
}

@test ".env の値にバックスラッシュが含まれても壊れない" {
  cat > "$D/.env.example" <<'EOF'
KEY="x"
EOF
  overrides='{"KEY":"C:\\new\\path"}'
  wt_write_env "$D/.env.example" "$D/.env" "$overrides"
  run grep '^KEY=' "$D/.env"
  [ "$output" = 'KEY="C:\\new\\path"' ]
  run bash -c "source '$D/.env' && printf '%s' \"\$KEY\""
  [ "$output" = 'C:\new\path' ]
}

@test "未定義変数はそのまま残る" {
  unset NOPE_VAR
  run wt_expand 'a=${NOPE_VAR}/b'
  [ "$output" = 'a=${NOPE_VAR}/b' ]
}

@test ".env はマーカー行で始まりテンプレート内容が続く" {
  printf 'A="1"\n' > "$D/.env.example"
  wt_write_env "$D/.env.example" "$D/.env" '{}'
  [ "$(head -1 "$D/.env")" = "$WT_ENVRC_MARKER" ]
  [ "$(sed -n 2p "$D/.env")" = 'A="1"' ]
}

@test ".env のテンプレートと出力先が同じなら die する" {
  printf 'A="1"\n' > "$D/.env"
  run wt_write_env "$D/.env" "$D/.env" '{}'
  [ "$status" -eq 1 ]
  [ "$(cat "$D/.env")" = 'A="1"' ]
}
