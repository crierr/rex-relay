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
c.clear()
assert(#c.list() == 0)
print("ok")
