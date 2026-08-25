local utils = require("jet.core.send.utils")

local M = {}

---``` lua
---vim.keymap.set({ "x", "o" }, "ie", function()
---    require("jet.core.send.textobject").textobject()
---end, {})
---```
M.textobject = function()
	local range = require("jet.core.send.get_code").get_expr(utils.curr_pos())
	if not range then
		return
	end

	vim.api.nvim_buf_set_mark(0, "<", range.start_row + 1, range.start_col, {})
	vim.api.nvim_buf_set_mark(0, ">", range.end_row + 1, range.end_col - 1, {})
	vim.cmd("normal! gv")
end

return M
