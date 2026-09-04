#!/usr/bin/env bats
load helpers

setup() {
  load_lib config
  PATH="${PATH#"$WT_ROOT/tests/fakes:"}"
  command -v docker >/dev/null || skip "docker なし"
  D="$BATS_TEST_TMPDIR/wt"; mkdir -p "$D"
  cp "$WT_ROOT/tests/fixtures/upstream-compose.yml" "$D/docker-compose.yml"
  cp "$WT_ROOT/repos/example/compose.devenv.yml" "$D/docker-compose.devenv.yml"
  export APP_HOST=example-app-t.localhost COMPOSE_PROJECT_NAME=example-app-t
  export COMPOSE_FILE="$D/docker-compose.yml:$D/docker-compose.devenv.yml"
}

@test "example の override は上流 compose と合成でき、ラベル・ネットワーク・環境変数が入る" {
  run docker compose --project-directory "$D" config
  [ "$status" -eq 0 ]
  [[ "$output" == *"caddy: example-app-t.localhost"* ]]
  [[ "$output" == *"devproxy"* ]]
  [[ "$output" == *"APP_HOST: example-app-t.localhost"* ]]
  [[ "$output" == *"ASSET_HOST: https://example-app-t.localhost"* ]]
}

@test "example の override は app と db のホスト publish を消す" {
  run docker compose --project-directory "$D" config
  ! grep -qE 'published: "?3000' <<<"$output"
  ! grep -qE 'published: "?3306' <<<"$output"
}

@test "example の override は tunnel を既定の profile から外す" {
  run docker compose --project-directory "$D" config --services
  [[ "$output" != *"tunnel"* ]]
  [[ "$output" == *"app"* ]]
}
