-- nvim --headless -u NONE -l tests/run.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd("runtime plugin/rex-relay.lua")
assert(vim.fn.exists(":Relay") == 2, ":Relay not registered by plugin/")
local c = require("rex-relay.comments")

assert(c.location("/p/a/b.lua", 3, 3, "/p") == "a/b.lua:3")
assert(c.location("/p/a/b.lua", 3, 9, "/p/") == "a/b.lua:3-9")
assert(c.location("/x/b.lua", 1, 1, "/p") == "/x/b.lua:1")

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, "/p/f.lua")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b", "c", "d" })
c.add(buf, 2, 3, "why?")
vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "new" }) -- comment should follow the edit
local list = c.list()
assert(#list == 1 and list[1].start_line == 3 and list[1].end_line == 4, vim.inspect(list))
local msg = c.format(list, "/p")
assert(msg:find("1. f.lua:3-4", 1, true) and msg:find("   > b\n   > c\n", 1, true) and msg:find("Comment: why?", 1, true), msg)
-- edit keeps the anchor and text tracks; delete removes only that one
c.edit(list[1], "really?")
vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "new2" })
list = c.list()
assert(#list == 1 and list[1].text == "really?" and list[1].start_line == 4, vim.inspect(list))
c.add(buf, 1, 1, "top")
assert(#c.at(buf, 4) == 1 and #c.at(buf, 1) == 1 and #c.at(buf, 3) == 0)
c.delete(c.at(buf, 1)[1])
assert(#c.list() == 1 and c.list()[1].text == "really?")

-- :Relay edit / delete via the cursor and via the quickfix list
local r = require("rex-relay")
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_win_set_cursor(0, { 5, 0 })
vim.ui.input = function(_, cb) cb("edited") end
r.edit()
assert(c.list()[1].text == "edited")
c.add(buf, 5, 5, "overlap")
vim.ui.select = function(items, _, cb) cb(items[2]) end
r.delete() -- two comments cover line 5; picker chooses the second
assert(#c.list() == 1)
r.list()
assert(vim.bo.buftype == "quickfix" and #vim.fn.getqflist() == 1)
assert(vim.fn.getline(1):find("f.lua|", 1, true), "qf line lacks filename: " .. vim.fn.getline(1))
assert(vim.api.nvim_eval_statusline(vim.wo.winbar, { winid = 0, use_winbar = true }).str:find("e: edit", 1, true), "winbar hint")
vim.ui.input = function(_, cb) cb("via e") end
vim.api.nvim_feedkeys("e", "x", false)
assert(c.list()[1].text == "via e" and vim.fn.getqflist()[1].text == "via e", "qf e")
vim.api.nvim_feedkeys("d", "x", false)
assert(#c.list() == 0 and #vim.fn.getqflist() == 0, "qf d / not refreshed")
-- another list in the same window: keys fall back to builtins
c.add(buf, 1, 1, "keep")
vim.fn.setqflist({}, " ", { title = "grep", items = { { bufnr = buf, lnum = 1, text = "hit" } } })
vim.api.nvim_feedkeys("d", "x", false)
assert(#c.list() == 1, "d acted outside our list")
assert(require("rex-relay").qf_winbar() == "", "hint shown on another list")
vim.cmd("cclose")
c.clear()

-- list stays current when changes happen from the code window, incl. async input
local function qf_texts() return vim.tbl_map(function(i) return i.text end, vim.fn.getqflist()) end
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_win_set_cursor(0, { 2, 0 })
r.list()
vim.cmd("wincmd p") -- back to the code window, list stays open
local pending
vim.ui.input = function(_, cb) pending = cb end -- like snacks/dressing: answers later
r.comment(2, 2)
pending("added")
assert(vim.deep_equal(qf_texts(), { "added" }), vim.inspect(qf_texts()))
r.edit()
pending("changed")
assert(vim.deep_equal(qf_texts(), { "changed" }), vim.inspect(qf_texts()))
r.delete()
assert(#vim.fn.getqflist() == 0, "delete not refreshed")
r.comment(2, 2)
pending("again")
r.clear()
assert(#vim.fn.getqflist() == 0, "clear not refreshed")
vim.cmd("cclose")

c.add(buf, 1, 1, "x")
c.clear()
assert(#c.list() == 0)
print("ok")
