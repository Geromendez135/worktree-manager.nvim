local M = {}

local defaults = {
  worktree_dir = ".worktrees",
  session = true,
  keymaps = {
    switch = "<leader>gw",
    delete = "<leader>grw",
    create = "<leader>gcw",
  },
  commands = true,
}

local config = {}

-- Get list of worktrees from git
local function get_worktrees()
  local output = vim.fn.systemlist("git worktree list --porcelain")
  local worktrees = {}
  local current = {}

  for _, line in ipairs(output) do
    if line:match("^worktree ") then
      current = { path = line:match("^worktree (.+)") }
    elseif line:match("^HEAD ") then
      current.head = line:match("^HEAD (.+)")
    elseif line:match("^branch ") then
      current.branch = line:match("^branch refs/heads/(.+)")
    elseif line == "bare" then
      current.bare = true
    elseif line == "detached" then
      current.detached = true
    elseif line == "" and current.path then
      table.insert(worktrees, current)
      current = {}
    end
  end
  if current.path then
    table.insert(worktrees, current)
  end

  return worktrees
end

-- Format worktree entry for display in the picker
local function format_worktree(wt)
  if wt.bare then
    return wt.path .. "  (bare)"
  end
  local branch = wt.branch or (wt.detached and "detached" or "unknown")
  local short_head = wt.head and wt.head:sub(1, 7) or ""
  return string.format("%s  [%s]  %s", wt.path, branch, short_head)
end

-- Extract path from formatted display string
local function extract_path(display_str)
  return display_str:match("^(.-)  ")
end

-- Save and restore sessions if enabled and auto-session is available
local function get_auto_session()
  if not config.session then
    return nil
  end
  local ok, auto_session = pcall(require, "auto-session")
  return ok and auto_session or nil
end

-- Switch to a worktree
local function switch_to_worktree(wt_path)
  local cwd = vim.fn.getcwd()
  if wt_path == cwd then
    vim.notify("Already in this worktree", vim.log.levels.INFO)
    return
  end

  if vim.fn.isdirectory(wt_path) == 0 then
    vim.notify("Worktree path does not exist: " .. wt_path, vim.log.levels.ERROR)
    return
  end

  local auto_session = get_auto_session()


  local auto_session = get_auto_session()

  if auto_session then
    auto_session.SaveSession()
  end

  pcall(vim.cmd, "NvimTreeClose")
  vim.cmd("silent! only")
  vim.cmd("silent! %bwipeout!")

  vim.cmd("cd " .. vim.fn.fnameescape(wt_path))
  vim.cmd("tcd " .. vim.fn.fnameescape(wt_path))

  if auto_session then
    auto_session.RestoreSession()
  end

  -- Re-edit current buffer to trigger BufRead/FileType and start LSP
  vim.cmd("edit")

  vim.notify("Switched to worktree: " .. wt_path, vim.log.levels.INFO)
end

-- Remove a worktree asynchronously
local function remove_worktree(path, force)
  local cmd = { "git", "worktree", "remove" }
  if force then
    table.insert(cmd, "--force")
  end
  table.insert(cmd, path)

  vim.notify("Removing worktree: " .. path .. "...", vim.log.levels.INFO)
  vim.system(cmd, {}, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("Failed to remove worktree: " .. (result.stderr or ""), vim.log.levels.ERROR)
      else
        vim.notify("Worktree removed: " .. path, vim.log.levels.INFO)
      end
    end)
  end)
end

-- Resolve the worktree base directory (absolute path)
local function get_worktree_dir()
  local dir = config.worktree_dir
  if not vim.startswith(dir, "/") then
    dir = vim.fn.getcwd() .. "/" .. dir
  end
  return dir
end

-- Get list of branches for the picker
local function get_branches()
  local output = vim.fn.systemlist("git branch -a --format='%(refname:short)'")
  if vim.v.shell_error ~= 0 then
    return {}
  end
  return output
end

-- Create a new worktree
function M.create_worktree()
  local branches = get_branches()

  local entries = vim.list_extend({ "[new branch]" }, branches)

  require("fzf-lua").fzf_exec(entries, {
    prompt = "Create worktree from branch> ",
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local branch = selected[1]

        if branch == "[new branch]" then
          vim.ui.input({ prompt = "New branch name: " }, function(new_branch)
            if not new_branch or new_branch == "" then return end
            local base_dir = get_worktree_dir()
            local wt_path = base_dir .. "/" .. new_branch
            vim.fn.mkdir(base_dir, "p")

            vim.notify("Creating worktree: " .. wt_path .. "...", vim.log.levels.INFO)
            vim.system({ "git", "worktree", "add", "-b", new_branch, wt_path }, {}, function(result)
              vim.schedule(function()
                if result.code ~= 0 then
                  vim.notify("Failed to create worktree: " .. (result.stderr or ""), vim.log.levels.ERROR)
                else
                  vim.notify("Worktree created: " .. wt_path, vim.log.levels.INFO)
                end
              end)
            end)
          end)
        else
          local short_name = branch:gsub("^origin/", "")
          local base_dir = get_worktree_dir()
          local wt_path = base_dir .. "/" .. short_name
          vim.fn.mkdir(base_dir, "p")

          vim.notify("Creating worktree: " .. wt_path .. "...", vim.log.levels.INFO)
          vim.system({ "git", "worktree", "add", wt_path, branch }, {}, function(result)
            vim.schedule(function()
              if result.code ~= 0 then
                vim.notify("Failed to create worktree: " .. (result.stderr or ""), vim.log.levels.ERROR)
              else
                vim.notify("Worktree created: " .. wt_path, vim.log.levels.INFO)
              end
            end)
          end)
        end
      end,
    },
  })
end

-- Pick and switch worktree
function M.switch_worktree()
  local worktrees = get_worktrees()

  if #worktrees <= 1 then
    vim.notify("No other worktrees found. Create one with: git worktree add <path> <branch>", vim.log.levels.WARN)
    return
  end

  local entries = {}
  local cwd = vim.fn.getcwd()
  for _, wt in ipairs(worktrees) do
    if not wt.bare then
      local display = format_worktree(wt)
      if wt.path == cwd then
        display = display .. "  * current"
      end
      table.insert(entries, display)
    end
  end

  require("fzf-lua").fzf_exec(entries, {
    prompt = "Switch worktree> ",
    actions = {
      ["default"] = function(selected)
        if selected and #selected > 0 then
          local path = extract_path(selected[1])
          if path then
            switch_to_worktree(path)
          end
        end
      end,
    },
  })
end

-- Delete a worktree
function M.delete_worktree()
  local worktrees = get_worktrees()
  local cwd = vim.fn.getcwd()

  local entries = {}
  for _, wt in ipairs(worktrees) do
    if not wt.bare and wt.path ~= cwd then
      table.insert(entries, format_worktree(wt))
    end
  end

  if #entries == 0 then
    vim.notify("No other worktrees to delete", vim.log.levels.WARN)
    return
  end

  require("fzf-lua").fzf_exec(entries, {
    prompt = "Delete worktree> ",
    actions = {
      ["default"] = function(selected)
        if selected and #selected > 0 then
          local path = extract_path(selected[1])
          if not path then return end

          vim.ui.select({ "Yes", "Yes (force)", "No" }, {
            prompt = "Delete worktree '" .. path .. "'?",
          }, function(choice)
            if choice == "Yes" then
              remove_worktree(path, false)
            elseif choice == "Yes (force)" then
              remove_worktree(path, true)
            end
          end)
        end
      end,
    },
  })
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", defaults, opts or {})

  if config.commands then
    vim.api.nvim_create_user_command("Wt", M.switch_worktree, { desc = "Switch git worktree" })
    vim.api.nvim_create_user_command("Wtd", M.delete_worktree, { desc = "Delete git worktree" })
    vim.api.nvim_create_user_command("Wtc", M.create_worktree, { desc = "Create git worktree" })
  end

  if config.keymaps.switch then
    vim.keymap.set("n", config.keymaps.switch, M.switch_worktree, { desc = "Switch git worktree" })
  end
  if config.keymaps.delete then
    vim.keymap.set("n", config.keymaps.delete, M.delete_worktree, { desc = "Delete git worktree" })
  end
  if config.keymaps.create then
    vim.keymap.set("n", config.keymaps.create, M.create_worktree, { desc = "Create git worktree" })
  end
end

return M
