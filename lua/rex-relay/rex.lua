-- Talking to Rex: find agent panes in this session and type into them.
local M = {}

local function rex(args, input)
  local r = vim.system(vim.list_extend({ "rex" }, args), { text = true, stdin = input }):wait()
  if r.code ~= 0 then return nil, vim.trim(r.stderr ~= "" and r.stderr or ("exit " .. r.code)) end
  local ok, out = pcall(vim.json.decode, r.stdout)
  return ok and out or nil, not ok and "bad JSON from rex" or nil
end

local function call(block, method, args)
  local argv = { "block", "call", "-s", vim.env.REX_SESSION, "-b", block, method }
  if args then table.insert(argv, "-") end
  return rex(argv, args and vim.json.encode(args) or nil)
end

-- Agents in this Rex session, same tab first. Rex itself reports the running
-- agent app via program_status, so no process-name guessing is needed.
function M.agents()
  if not vim.env.REX_SESSION then return nil, "not inside a Rex terminal (REX_SESSION unset)" end
  local ls, err = rex({ "block", "ls", "-s", vim.env.REX_SESSION, "--json" })
  if not ls then return nil, err end
  local my_win
  for _, b in ipairs(ls.blocks) do
    if b.block_id == vim.env.REX_BLOCK then my_win = b.window_id end
  end
  local out = {}
  for _, b in ipairs(ls.blocks) do
    if b.block_id ~= vim.env.REX_BLOCK then
      local st = call(b.block_id, "program_status")
      local rec = st and st.records and st.records[1]
      if rec and rec.app then
        local p = call(b.block_id, "process") or {}
        table.insert(out, {
          block = b.block_id,
          app = rec.effective_app or rec.app,
          state = rec.state or "?",
          cwd = (p.foreground or {}).cwd or "",
          same_tab = b.window_id == my_win,
        })
      end
    end
  end
  table.sort(out, function(a, b) return a.same_tab and not b.same_tab end)
  return out
end

-- Type text into the agent's input like a paste; press Enter after a beat if
-- submitting (same 300ms herdr uses, so the TUI finishes ingesting the paste).
function M.write(agent, text, submit)
  local modes = call(agent.block, "modes")
  for _, m in ipairs(modes and modes.modes or {}) do
    if m.number == 2004 and m.set then text = "\27[200~" .. text .. "\27[201~" end
  end
  local _, err = call(agent.block, "write", { data = text })
  if err then return false, err end
  if submit then
    vim.defer_fn(function() call(agent.block, "write", { data = "\r" }) end, 300)
  end
  return true
end

-- Move Rex's focus to the agent's pane.
function M.focus(agent)
  local r = vim.system({ "rex", "block", "focus", "-s", vim.env.REX_SESSION, agent.block }, { text = true }):wait()
  if r.code ~= 0 then return false, vim.trim(r.stderr ~= "" and r.stderr or ("exit " .. r.code)) end
  return true
end

-- Call fn with the target agent: the lone agent in this tab, else the lone
-- agent in the session, else ask.
function M.with_agent(fn)
  local list, err = M.agents()
  if not list then return vim.notify("rex-relay: " .. err, vim.log.levels.ERROR) end
  if #list == 0 then return vim.notify("rex-relay: no agents in this Rex session", vim.log.levels.WARN) end
  local in_tab = vim.tbl_filter(function(a) return a.same_tab end, list)
  if #in_tab == 1 then return fn(in_tab[1]) end
  if #list == 1 then return fn(list[1]) end
  vim.ui.select(list, {
    prompt = "Send to agent",
    format_item = function(a)
      return string.format("%s · %s · %s%s", a.app, a.state, vim.fn.fnamemodify(a.cwd, ":t"), a.same_tab and " (this tab)" or "")
    end,
  }, function(a) if a then fn(a) end end)
end

return M
