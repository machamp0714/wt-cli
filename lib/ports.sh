# shellcheck shell=bash
# host 型 worktree 向けのポートレジストリ。関数定義のみ。
WT_PORT_MIN="${WT_PORT_MIN:-31000}"
WT_PORT_MAX="${WT_PORT_MAX:-39999}"

wt_ports_file() { printf '%s/ports.json\n' "$DEVENV_CONFIG_DIR"; }

wt_ports_init() {
  mkdir -p "$DEVENV_CONFIG_DIR"
  [ -f "$(wt_ports_file)" ] || printf '{}\n' > "$(wt_ports_file)"
}

wt_port_in_use() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

wt_ports_alloc() {
  local owner=$1 count=$2 file p found=()
  need jq
  wt_ports_init; file=$(wt_ports_file)
  local registered; registered=$(jq -r 'keys[]' "$file")
  p=$WT_PORT_MIN
  while [ "${#found[@]}" -lt "$count" ] && [ "$p" -le "$WT_PORT_MAX" ]; do
    if ! grep -qx "$p" <<<"$registered" && ! wt_port_in_use "$p"; then
      found+=("$p")
    fi
    p=$((p + 1))
  done
  [ "${#found[@]}" -eq "$count" ] || die "空きポートがありません（${WT_PORT_MIN}-${WT_PORT_MAX}）。wt gc を実行してください"
  wt_ports_assign "$owner" "${found[@]}"
  printf '%s\n' "${found[*]}"
}

# 空きポートの検索はせず、指定されたポートをそのまま owner に紐付ける（再登録・移し替え用）
wt_ports_assign() {
  local owner=$1; shift
  local file tmp
  need jq
  wt_ports_init; file=$(wt_ports_file)
  tmp=$(mktemp)
  jq --arg o "$owner" --argjson ps "$(printf '%s\n' "$@" | jq -R . | jq -s .)" \
    'reduce $ps[] as $p (.; .[$p] = $o)' "$file" > "$tmp" && mv "$tmp" "$file"
}

wt_ports_release() {
  local owner=$1 file tmp
  file=$(wt_ports_file)
  [ -f "$file" ] || return 0
  need jq
  tmp=$(mktemp)
  jq --arg o "$owner" 'with_entries(select(.value != $o))' "$file" > "$tmp" && mv "$tmp" "$file"
}

wt_ports_for() {
  local file; file=$(wt_ports_file)
  [ -f "$file" ] || return 0
  jq -r --arg o "$1" 'to_entries | map(select(.value == $o)) | .[].key' "$file" | sort -n
}

wt_ports_owners() {
  local file; file=$(wt_ports_file)
  [ -f "$file" ] || return 0
  jq -r '[.[]] | unique | .[]' "$file"
}
