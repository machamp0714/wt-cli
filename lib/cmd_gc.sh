# shellcheck shell=bash
# wt gc。孤児 compose プロジェクトと解放漏れポートを回収する。

cmd_gc() {
  local dry=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      *) die "unknown option: ${1}（使い方: wt gc [--dry-run]）" ;;
    esac
  done
  need docker; need jq
  local name owner expected any=0

  # wt_compose_orphans / wt_compose_mismatched は < <(...) プロセス置換の中で
  # wt_compose_projects を呼ぶため、その中で die しても exit がサブシェルに
  # 閉じ込められ cmd_gc には伝播しない。ここで一度直接呼んで疎通確認する。
  wt_compose_projects >/dev/null

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    any=1
    if [ "$dry" -eq 1 ]; then
      log "[dry-run] 孤児 compose プロジェクト: $name"
    else
      log "孤児 compose プロジェクトを削除: $name"
      wt_compose_down "$name" || log "警告: $name の削除に失敗"
    fi
  done < <(wt_compose_orphans)

  while IFS= read -r owner; do
    [ -n "$owner" ] || continue
    [ -d "$owner" ] && continue
    any=1
    if [ "$dry" -eq 1 ]; then
      log "[dry-run] 解放漏れポート: $(wt_ports_for "$owner" | tr '\n' ' ')($owner)"
    else
      log "ポートを解放: $(wt_ports_for "$owner" | tr '\n' ' ')($owner)"
      wt_ports_release "$owner"
    fi
  done < <(wt_ports_owners)

  while IFS=$'\t' read -r name expected; do
    [ -n "$name" ] || continue
    any=1
    log "警告: compose プロジェクト ${name} は規約名 ${expected} と一致しません（手動確認。消すなら docker compose -p ${name} down -v --rmi local --remove-orphans）"
  done < <(wt_compose_mismatched)

  [ "$any" -eq 1 ] || log "回収対象はありません"
}
