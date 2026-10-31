# Neovim as a regular editor + Claude Code

Run `nvim` in a project directory (or `nvim path/to/project`). The window is split into three parts:

```
 File  Edit  View  Go  Git  Claude  Help                     project
 EXPLORER       │ a.txt ✕ │ b.py ● │          │ CLAUDE CODE
 ▾ src          │ (editor)                     │ (terminal)
   main.py      │                              │
 INSERT  main.py                    utf-8 │ python  Top  1:1 │ 14:05
```

The top row is a menu bar: click a name to open its menu (F10 opens File). Each editor has its
own row of tabs: click a tab to switch, click ✕ (● when unsaved) or middle-click to close.
The clock is at the bottom right. Left of it is what's playing on the Mac (when there's room);
`vim.g.now_playing` in `lua/config/options.lua` turns it off. For every player (browsers, Podcasts...)
install `brew install media-control`; without it only Music and Spotify are shown.

It starts on a **welcome screen**: quick actions (new file, open file/folder, find in project, ask Claude,
git panel), your recent files in this project and your recent projects. Click an entry or press the key
shown next to it. Opening a recent project switches the file tree and Claude to that folder. The welcome
screen also comes back when you close the last tab, and from Help > Welcome Screen.

`nvim file.txt` opens just that file, without the panels (e.g. as the git commit editor).

**Markdown** files are shown rendered: headings, bold, lists, checkboxes, tables and code blocks.
The line with the cursor shows the raw text so you can edit it.

The colors follow macOS: Xcode light in Light mode, Xcode dark in Dark mode. Switching the system
appearance changes them within a few seconds. Claude Code's own colors are set with `/theme` inside the panel.

## Shortcuts

| Shortcut | Action |
|---|---|
| Ctrl+S | save |
| Ctrl+Z / Ctrl+Y | undo / redo |
| Ctrl+C / Ctrl+X / Ctrl+V | copy / cut / paste (with no selection: the whole line) |
| Ctrl+A | select all |
| Shift+arrows, mouse | select (typing replaces the selection) |
| Tab / Shift+Tab | indent / outdent the selection |
| Ctrl+/ | toggle comment |
| Ctrl+F, F3 / Shift+F3 | find in file, next / previous match |
| Ctrl+R | find and replace |
| Ctrl+P | quick open file |
| Ctrl+G | search in project |
| F1 | command palette |
| Ctrl+N | new file |
| Ctrl+W | close tab |
| Ctrl+PageDown / PageUp | next / previous tab (or click) |
| Ctrl+B | show / hide the file tree |
| Ctrl+` | terminal panel below the editor: show, focus, hide (Ctrl+Space where Ctrl+` doesn't get through) |
| Ctrl+Q | quit |
| F9 | git panel (lazygit; quit it with q) |
| F10 | open the File menu |
| Option+click, Shift+F10 | context menu: copy/paste and Claude actions |

Terminal.app keeps right click for its own macOS menu and never passes it to Neovim, so the context
menu is on Option+click and Shift+F10. Everything in it is also in the menu bar.
In terminals that pass right click through (iTerm2, Ghostty, WezTerm, kitty) right click works too.

Esc switches to Vim's Normal mode. All Vim keys still work; clicking a file or switching tabs puts you
back into typing mode.

## Claude

| Shortcut | Action |
|---|---|
| Ctrl+\ | switch focus: editor ⇄ Claude (opens the panel if it is closed) |
| Ctrl+\ on a selection | insert an `@file#10-20` reference into the chat |
| `@` in the file tree | insert a reference to that file into the chat |
| F12 | show / hide the panel (Claude keeps running in the background) |
| F7 / Shift+F7 | next / previous Claude change |

**Panel width:** drag the border between the editor and the panel with the mouse. The width is
remembered (also after hiding the panel and across restarts). `:ClaudeWidth 90` or `:ClaudeWidth 50%`
sets it exactly, `:ClaudeWidth` alone goes back to the default.

When Claude edits a file:

1. the file opens in the editor and scrolls to the fragment Claude is changing (before you approve the edit in the panel),
2. as soon as it is written, the change shows up in the buffer: new lines in green, removed lines in red below them,
3. the highlight stays until you accept it, so consecutive edits add up and you see the whole diff since Claude started.

Every change has **`✓ Accept`** and **`↺ Revert`** buttons at the end of its first line: click them.
Accept keeps the change and removes the highlight; Revert puts the old lines back and saves the file.

The same from the Claude menu, the context menu or commands:

- `:ClaudeAcceptHunk` / `:ClaudeRevertHunk`: accept / revert the change under the cursor
- `:ClaudeAccept` / `:ClaudeAcceptAll`: accept everything in this file / in all files
- `:ClaudeRevert`: revert all Claude changes in the file
- `:ClaudeChanges`: list all changes (quickfix)
- Ctrl+Z right after a change undoes Claude's whole edit in the buffer, Ctrl+S writes that to disk

Switching to the Claude panel saves unsaved files, so Claude sees your version. If Claude changes a file
in which you have unsaved changes, nothing gets overwritten: you get a warning, and `:ClaudeReload`
takes the version on disk.

Changes Claude makes in other ways (Bash, formatters, git) are detected and highlighted in open files too.

## Git

F9 (or Git > Open Git Panel) opens lazygit in a window over the editor: stage, commit, push, switch
branches, all clickable. Quit it with q; files it changes reload in the editor. It needs lazygit
(`brew install lazygit`). The Git menu also has the per-line actions: next/previous change, preview,
stage or discard a change, blame and a diff of the current file. Changed lines are marked in the
left margin.

## Terminal

Ctrl+` (or View > Terminal) opens a shell in a panel below the editor, in the project folder.
Pressed again it hides the panel (the shell keeps running); from the editor it jumps back into it.
Drag the border to resize it, the height is kept while Neovim runs. `exit` closes it.

## Settings

- `lua/config/options.lua`: `vim.g.have_nerd_font = true` after installing a Nerd Font
  (`brew install --cask font-jetbrains-mono-nerd-font` and selecting it in the terminal) gives file icons;
  `vim.g.modeless = false` turns off automatic typing mode.
- View > Theme: follow the system, or always light / dark (remembered).
- `lua/config/menubar.lua`: the menus; add your own with another `item(...)` line.
- `lua/config/theme.lua`: the light/dark color schemes (dark: `i3`, the i3 window manager's default colors,
  in `colors/i3.lua`; light: `xcodelight`; also `xcodedark`, `xcodelighthc`, `xcodedarkhc`, `xcodewwdc`).
- `require("claude").setup({...})` in `init.lua`: `width`, `follow` (jump to files Claude edits),
  `autosave`, `auto_open`, `cmd` (e.g. `{ "claude", "--continue" }`).
