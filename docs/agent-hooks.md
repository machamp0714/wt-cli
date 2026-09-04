# Claude Code / Codex への規約注入

`wt prime` を SessionStart と PreCompact の hook に登録すると、wt 管理の worktree で起動したエージェントに
URL と規約が自動で渡る。共有リポジトリの CLAUDE.md には何も書かない。

登録先（グローバル）:
- `~/.claude/settings.json` → `hooks.SessionStart[]`, `hooks.PreCompact[]`
- `~/.codex/hooks.json` → 同上

エントリ:
    { "matcher": "", "hooks": [ { "type": "command", "command": "\"$HOME/repo/devenv/bin/wt\" prime", "timeout": 10 } ] }

wt 管理外の場所では `wt prime` は何も出さないので、全リポジトリに付けて無害。
