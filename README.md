# worktree-manager.nvim

A Neovim plugin for switching and managing git worktrees with [fzf-lua](https://github.com/ibhagwan/fzf-lua).

Optionally integrates with [auto-session](https://github.com/rmagatti/auto-session) to save/restore sessions when switching worktrees.

## Requirements

- Neovim >= 0.10
- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- [auto-session](https://github.com/rmagatti/auto-session) (optional, for session persistence)

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "geronimomendez/worktree-manager.nvim",
  dependencies = { "ibhagwan/fzf-lua" },
  config = function()
    require("worktree-manager").setup()
  end,
}
```

## Configuration

```lua
require("worktree-manager").setup({
  -- Set to false to disable :Wt and :Wtd commands
  commands = true,
  keymaps = {
    -- Set to false to disable a keymap
    switch = "<leader>gw",
    delete = "<leader>grw",
  },
})
```

## Usage

| Action           | Default keymap | Command |
|------------------|----------------|---------|
| Switch worktree  | `<leader>gw`   | `:Wt`   |
| Delete worktree  | `<leader>grw`  | `:Wtd`  |

### Switch worktree

Opens an fzf picker with all non-bare worktrees. Selecting one will:

1. Save the current session (if auto-session is installed)
2. Close sidebars and wipe all buffers
3. Change directory to the selected worktree
4. Restore the session for that worktree (if auto-session is installed)

### Delete worktree

Opens an fzf picker with worktrees (excluding the current one). After selecting, prompts for confirmation with options to force-delete. Removal runs asynchronously so Neovim stays responsive.
