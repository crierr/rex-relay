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

-- Comments into the quickfix list for review/jumping.
function M.list()
  vim.fn.setqflist({}, " ", {
    title = "rex-relay comments",
    items = vim.tbl_map(function(c)
      return { bufnr = c.bufnr, lnum = c.start_line, end_lnum = c.end_line, text = c.text }
    end, comments.list()),
  })
  vim.cmd("copen")
end

M.clear = comments.clear

-- :Relay subcommands; registered by plugin/rex-relay.lua.
M.subcommands = {
  ref = function(o) M.ref(o.line1, o.line2) end,
  comment = function(o) M.comment(o.line1, o.line2) end,
  send = function() M.send(false) end,
  submit = function() M.send(true) end,
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
  vim.keymap.set("n", p .. "s", "<cmd>Relay send<cr>", { desc = "Relay: paste comments to agent" })
  vim.keymap.set("n", p .. "S", "<cmd>Relay submit<cr>", { desc = "Relay: submit comments to agent" })
  vim.keymap.set("n", p .. "l", "<cmd>Relay list<cr>", { desc = "Relay: list comments" })
end

return M
