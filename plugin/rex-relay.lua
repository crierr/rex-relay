if vim.g.loaded_rex_relay then return end
vim.g.loaded_rex_relay = true

-- Defined at startup so :Relay works without setup(); the module loads on first use.
vim.api.nvim_create_user_command("Relay", function(o)
  local subs = require("rex-relay").subcommands
  local f = subs[o.fargs[1]]
  if not f then
    return vim.notify("Relay: expected one of " .. table.concat(vim.tbl_keys(subs), ", "), vim.log.levels.ERROR)
  end
  f(o)
end, {
  nargs = 1,
  range = true,
  desc = "rex-relay: send refs/comments to a Rex agent",
  complete = function(lead)
    return vim.tbl_filter(function(s) return vim.startswith(s, lead) end,
      vim.tbl_keys(require("rex-relay").subcommands))
  end,
})
