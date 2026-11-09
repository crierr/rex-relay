# rex-relay.nvim

Send `file:line` references and review comments from Neovim to CLI coding
agents (Claude Code, Pi, OpenCode, …) running in other panes of the same
[Rex](https://www.superlogical.com/rex) session.

## Features

- **Finds your agents.** Uses the agent in the same tab, or the only one in the
  session. If there are several, it asks which one.
- **References.** Type `path:12` or `path:12-20` at the agent's cursor in the
  middle of a message you're writing.
- **Review comments.** Comment on lines or selections like a code review, then
  send them all at once with file:line and the code they refer to.

## Requirements

- Neovim ≥ 0.10
- Nvim running inside a Rex terminal (`REX_SESSION` / `REX_BLOCK` set), with
  `rex` on `PATH`

Run `:checkhealth rex-relay` to check your setup and see the agents it finds.

## Install

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "crierr/rex-relay.nvim", opts = {} }
```

Options (defaults shown):

```lua
opts = {
  prefix = "<leader>a", -- keymap prefix
  keymaps = true,       -- false: no keymaps, use :Relay or the Lua API
}
```

`:Relay` works without calling `setup()`. `setup()` only adds the keymaps.

## Usage

| Key | Command | Does |
| --- | --- | --- |
| `<leader>ai` | `:[range]Relay ref` | type `path:12` (`path:12-20` for a range) at the agent's cursor; never submits |
| `<leader>aI` | `:[range]Relay ref-focus` | same, then focus the agent's pane |
| `<leader>ac` | `:[range]Relay comment` | comment the line / selection |
| `<leader>ae` | `:Relay edit` | edit the comment under the cursor |
| `<leader>ad` | `:Relay delete` | delete the comment under the cursor |
| `<leader>al` | `:Relay list` | comments in the quickfix list |
| `<leader>as` | `:Relay send` | paste all comments into the agent's input, then clear them |
| `<leader>aS` | `:Relay submit` | same, and press Enter |
| | `:Relay clear` | drop all comments |

In `:Relay list`, `e` edits and `d` deletes the entry under the cursor.
Edit and delete ask which one when several comments cover a line. Comments are kept in
memory only and follow your edits. Paths are relative to
the agent's working directory. See `:help rex-relay`.

## How it works

- **Finding agents.** `rex block ls` lists the session's panes, and
  `rex block call program_status` reports which agent each one runs
  (`claude-code`, `pi`, `opencode`, …). No guessing from process names.
- **Sending.** `rex block call write` types the text, wrapped in bracketed
  paste when the agent has enabled it, so multi-line text arrives as one
  paste. `submit` presses Enter 300 ms later.

## Development

```sh
nvim --headless -u NONE -l tests/run.lua
```

To use a local checkout, point lazy.nvim at it with
`{ dir = "~/src/rex-relay.nvim", opts = {} }`. lazy doesn't build help tags for
`dir` plugins, so run `:helptags ~/src/rex-relay.nvim/doc` once.

Inspired by [herdr-nvim](https://github.com/ChmaraX/herdr-nvim).
