# worktree-manager.nvim

A Neovim plugin for switching and managing git worktrees with [fzf-lua](https://github.com/ibhagwan/fzf-lua).

Optionally integrates with [auto-session](https://github.com/rmagatti/auto-session) to save/restore sessions when switching worktrees.

## Requirements

- Neovim >= 0.10
- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- [auto-session](https://github.com/rmagatti/auto-session) (installed by default, can be opted out)

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "geronimomendez/worktree-manager.nvim",
  dependencies = {
    "ibhagwan/fzf-lua",
    "rmagatti/auto-session",
  },
  config = function()
    require("worktree-manager").setup()
  end,
}
```

## Configuration

```lua
require("worktree-manager").setup({
  -- Base directory for new worktrees (relative to cwd or absolute)
  worktree_dir = ".worktrees",
  -- Set to false to disable auto-session integration
  session = true,
  -- Set to false to disable :Wt, :Wtc and :Wtd commands
  commands = true,
  keymaps = {
    -- Set to false to disable a keymap
    switch = "<leader>gw",
    create = "<leader>gcw",
    delete = "<leader>grw",
  },
})

```

To opt out of auto-session (no session save/restore when switching worktrees):

```lua
{
  "geronimomendez/worktree-manager.nvim",
  dependencies = { "ibhagwan/fzf-lua" },
  config = function()
    require("worktree-manager").setup({ session = false })
  end,
}
```

## Usage

| Action           | Default keymap | Command |
|------------------|----------------|---------|
| Switch worktree  | `<leader>gw`   | `:Wt`   |
| Create worktree  | `<leader>gcw`  | `:Wtc`  |
| Delete worktree  | `<leader>grw`  | `:Wtd`  |

### Switch worktree

Opens an fzf picker with all non-bare worktrees. Selecting one will:

1. Save the current session (if auto-session is installed)
2. Close sidebars and wipe all buffers
3. Change directory to the selected worktree
4. Restore the session for that worktree (if auto-session is installed)

### Create worktree

Opens an fzf picker with all local and remote branches, plus a `[new branch]` option. Selecting an existing branch creates a worktree for it; selecting `[new branch]` prompts for a name and creates both the branch and the worktree.

New worktrees are placed under the configured `worktree_dir` (defaults to `.worktrees` in the current working directory). Creation runs asynchronously.

### Delete worktree

Opens an fzf picker with worktrees (excluding the current one). After selecting, prompts for confirmation with options to force-delete. Removal runs asynchronously so Neovim stays responsive.
