local M = {}

---``` lua
---vim.keymap.set({ "x", "o" }, "ie", function()
---    require("jet.core.send.textobject").textobject()
---end, {})
---```
---@param range jet.send.Range
M.textobject = function(range)
	vim.api.nvim_buf_set_mark(0, "<", range.start_row + 1, range.start_col, {})
	vim.api.nvim_buf_set_mark(0, ">", range.end_row + 1, range.end_col - 1, {})
	vim.cmd("normal! gv")
end

return M
