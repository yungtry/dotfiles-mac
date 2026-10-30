#!/bin/sh
# Claude Code PreToolUse/PostToolUse hook (see lua/claude/init.lua).
# Forwards the event to the Neovim that hosts the Claude panel ($NVIM is set by :terminal).
# Never blocks Claude: always exits 0.

if [ -z "$NVIM" ]; then
  cat >/dev/null
  exit 0
fi

tmp=$(mktemp "${TMPDIR:-/tmp}/claude-nvim.XXXXXX") || exit 0
cat >"$tmp"
"${CLAUDE_NVIM_BIN:-nvim}" --server "$NVIM" --remote-expr "v:lua.ClaudeLiveHook('$1', '$tmp')" >/dev/null 2>&1 || rm -f "$tmp"
exit 0
