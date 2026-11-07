-- :checkhealth rex-relay
local M = {}

function M.check()
  vim.health.start("rex-relay")
  if vim.fn.executable("rex") == 1 then vim.health.ok("rex on PATH") else vim.health.error("rex not on PATH") end
  if not (vim.env.REX_SESSION and vim.env.REX_BLOCK) then
    return vim.health.warn("REX_SESSION/REX_BLOCK unset: nvim is not running inside a Rex terminal")
  end
  vim.health.ok("in Rex session " .. vim.env.REX_SESSION)
  local list, err = require("rex-relay.rex").agents()
  if not list then return vim.health.error(err) end
  if #list == 0 then return vim.health.warn("no agents found in this session") end
  for _, a in ipairs(list) do
    vim.health.ok(string.format("agent %s (%s) in %s%s", a.app, a.state, a.cwd, a.same_tab and ", this tab" or ""))
  end
end

return M
