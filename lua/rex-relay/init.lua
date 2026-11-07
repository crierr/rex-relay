-- Public API: setup() and the actions behind :Relay.
local M = {}
local rex = require("rex-relay.rex")
local comments = require("rex-relay.comments")

M.config = { prefix = "<leader>a", keymaps = true }

local function write(agent, text, submit)
  local ok, err = rex.write(agent, text, submit)
  if not ok then vim.notify("rex-relay: " .. err, vim.log.levels.ERROR) end
  return ok
end

-- Drop `path:line ` at the agent's cursor; never submits.
function M.ref(s, e)
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then return vim.notify("rex-relay: buffer has no file", vim.log.levels.WARN) end
  rex.with_agent(function(a) write(a, comments.location(file, s, e, a.cwd) .. " ", false) end)
end

function M.comment(s, e)
  local bufnr = vim.api.nvim_get_current_buf()
  vim.ui.input({ prompt = "Comment: " }, function(text)
    if text and text ~= "" then comments.add(bufnr, s, e, text) end
  end)
end

function M.send(submit)
  local list = comments.list()
  if #list == 0 then return vim.notify("rex-relay: no comments to send") end
  rex.with_agent(function(a)
    if not write(a, comments.format(list, a.cwd), submit) then return end
    comments.clear()
    vim.notify(string.format("rex-relay: sent %d comment(s) to %s", #list, a.app))
  end)
end

local function qf_items()
  return vim.tbl_map(function(c)
    return { bufnr = c.bufnr, lnum = c.start_line, end_lnum = c.end_line, text = c.text }
  end, comments.list())
end

-- Comments into the quickfix list for review/jumping.
function M.list()
  vim.fn.setqflist({}, " ", { title = "rex-relay comments", items = qf_items() })
  vim.cmd("copen")
end

-- Run fn on the comment under the cursor (or under the quickfix entry), asking
-- when several overlap. Refreshes our quickfix list if that's where we are.
local function on_comment(verb, fn)
  local bufnr, line = vim.api.nvim_get_current_buf(), vim.fn.line(".")
  local in_qf = vim.bo.buftype == "quickfix"
  if in_qf then
    local item = vim.fn.getqflist()[line]
    if not item then return end
    bufnr, line = item.bufnr, item.lnum
  end
  local function run(c)
    fn(c)
    if in_qf and vim.fn.getqflist({ title = 0 }).title == "rex-relay comments" then
      vim.fn.setqflist({}, "r", { items = qf_items() })
    end
  end
  local found = comments.at(bufnr, line)
  if #found == 0 then return vim.notify("rex-relay: no comment here") end
  if #found == 1 then return run(found[1]) end
  vim.ui.select(found, { prompt = verb .. " comment", format_item = function(c) return c.text end },
    function(c) if c then run(c) end end)
end

function M.edit()
  on_comment("Edit", function(c)
    vim.ui.input({ prompt = "Comment: ", default = c.text }, function(text)
      if text and text ~= "" then comments.edit(c, text) end
    end)
  end)
end

function M.delete()
  on_comment("Delete", comments.delete)
end

M.clear = comments.clear

-- :Relay subcommands; registered by plugin/rex-relay.lua.
M.subcommands = {
  ref = function(o) M.ref(o.line1, o.line2) end,
  comment = function(o) M.comment(o.line1, o.line2) end,
  send = function() M.send(false) end,
  submit = function() M.send(true) end,
  edit = function() M.edit() end,
  delete = function() M.delete() end,
  list = function() M.list() end,
  clear = function() M.clear() end,
}

function M.setup(cfg)
  M.config = vim.tbl_deep_extend("force", M.config, cfg or {})
  if not M.config.keymaps then return end
  local p = M.config.prefix
  vim.keymap.set("n", p .. "i", "<cmd>Relay ref<cr>", { desc = "Relay: file:line to agent" })
  vim.keymap.set("x", p .. "i", ":Relay ref<cr>", { desc = "Relay: file:range to agent" })
  vim.keymap.set("n", p .. "c", "<cmd>Relay comment<cr>", { desc = "Relay: comment line" })
  vim.keymap.set("x", p .. "c", ":Relay comment<cr>", { desc = "Relay: comment selection" })
  vim.keymap.set("n", p .. "e", "<cmd>Relay edit<cr>", { desc = "Relay: edit comment here" })
  vim.keymap.set("n", p .. "d", "<cmd>Relay delete<cr>", { desc = "Relay: delete comment here" })
  vim.keymap.set("n", p .. "s", "<cmd>Relay send<cr>", { desc = "Relay: paste comments to agent" })
  vim.keymap.set("n", p .. "S", "<cmd>Relay submit<cr>", { desc = "Relay: submit comments to agent" })
  vim.keymap.set("n", p .. "l", "<cmd>Relay list<cr>", { desc = "Relay: list comments" })
end

return M
