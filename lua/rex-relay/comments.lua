-- Pending review comments, anchored with extmarks so they follow edits.
local M = {}
M.ns = vim.api.nvim_create_namespace("rex-relay")
local notes = {} -- bufnr -> { [extmark_id] = comment text }

-- path relative to the agent's cwd when inside it; `path:12` or `path:12-20`.
function M.location(file, s, e, cwd)
  local prefix = (cwd or ""):gsub("/$", "") .. "/"
  if cwd and cwd ~= "" and file:sub(1, #prefix) == prefix then file = file:sub(#prefix + 1) end
  return s == e and string.format("%s:%d", file, s) or string.format("%s:%d-%d", file, s, e)
end

local function mark_opts(e, text)
  return {
    end_row = e - 1,
    sign_text = "▍",
    sign_hl_group = "DiagnosticInfo",
    virt_lines = { { { "  💬 " .. text, "DiagnosticInfo" } } },
  }
end

function M.add(bufnr, s, e, text)
  local id = vim.api.nvim_buf_set_extmark(bufnr, M.ns, s - 1, 0, mark_opts(e, text))
  notes[bufnr] = notes[bufnr] or {}
  notes[bufnr][id] = text
  return id
end

-- c is an entry from M.list(); the extmark is re-set in place so it keeps tracking edits.
function M.edit(c, text)
  vim.api.nvim_buf_set_extmark(c.bufnr, M.ns, c.start_line - 1, 0, vim.tbl_extend("force", mark_opts(c.end_line, text), { id = c.id }))
  notes[c.bufnr][c.id] = text
end

function M.delete(c)
  vim.api.nvim_buf_del_extmark(c.bufnr, M.ns, c.id)
  notes[c.bufnr][c.id] = nil
end

-- Comments in bufnr whose range covers line.
function M.at(bufnr, line)
  return vim.tbl_filter(function(c)
    return c.bufnr == bufnr and c.start_line <= line and line <= c.end_line
  end, M.list())
end

-- All pending comments, sorted by file then line.
function M.list()
  local out = {}
  for bufnr, by_id in pairs(notes) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      for _, m in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, M.ns, 0, -1, { details = true })) do
        local id, row, details = m[1], m[2], m[4]
        if by_id[id] then
          table.insert(out, {
            bufnr = bufnr, id = id, text = by_id[id],
            file = vim.api.nvim_buf_get_name(bufnr),
            start_line = row + 1, end_line = math.max(row, details.end_row or row) + 1,
          })
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.file ~= b.file then return a.file < b.file end
    return a.start_line < b.start_line
  end)
  return out
end

function M.clear()
  for bufnr in pairs(notes) do
    if vim.api.nvim_buf_is_valid(bufnr) then vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1) end
  end
  notes = {}
end

function M.format(list, cwd)
  local lines = { "Code review comments from my editor:", "" }
  for i, c in ipairs(list) do
    table.insert(lines, string.format("%d. %s", i, M.location(c.file, c.start_line, c.end_line, cwd)))
    for _, l in ipairs(vim.api.nvim_buf_get_lines(c.bufnr, c.start_line - 1, math.min(c.end_line, c.start_line + 2), false)) do
      table.insert(lines, "   > " .. l)
    end
    table.insert(lines, "   Comment: " .. c.text)
    table.insert(lines, "")
  end
  table.insert(lines, "Please address each comment.")
  return table.concat(lines, "\n")
end

return M
