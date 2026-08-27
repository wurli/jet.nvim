--- TODO: swap for vim.Range once it's stabilised
---@class jet.send.Range
---@field buf integer
---@field start_row integer 0-indexed
---@field start_col integer 0-indexed
---@field end_row integer 0-indexed
---@field end_col integer 0-indexed

local Range = {}

---@param r jet.send.Range
---@return string[]?
Range.range_text = function(r)
	local ok, text = pcall(vim.api.nvim_buf_get_text, r.buf, r.start_row, r.start_col, r.end_row, r.end_col, {})
	if not ok then
		return nil
	end
	if #text == 0 then
		return nil
	end
	return text
end

---@param r jet.send.Range
---@return nil
---@return_overload string[], string
Range.range_code = function(r)
	local utils = require("jet.core.send.utils")

	local text = Range.range_text(r)

	if not text then
		return
	end

	local lang_info = utils.local_lang_info({ buf = r.buf, row = r.start_row, col = r.start_col })
	local ft, commentstring = lang_info.filetype, lang_info.commentstring

	if not ft or not commentstring then
		return
	end

	local code_filtered = vim.tbl_filter(
		function(line) return line:match("%S") ~= nil and not utils.is_comment(line, commentstring) end,
		text
	)

	if #code_filtered == 0 then
		return
	end

	return code_filtered, ft
end

---@param r jet.send.Range
---@return jet.send.Pos
Range.range_start = function(r)
	return {
		buf = r.buf,
		row = r.start_row,
		col = r.start_col,
	}
end

---@param r jet.send.Range
---@return jet.send.Pos
Range.range_end = function(r)
	-- Gotta nudge since range end is exclusive
	local out = require("jet.core.send.pos").pos_nudge({
		buf = r.buf,
		row = r.end_row,
		col = r.end_col,
	}, -1)
	assert(out, "Failed to nudge range end position backwards")
	return out
end

---``` lua
---vim.keymap.set({ "x", "o" }, "ie", function()
---    require("jet.core.send.range").textobject()
---end, {})
---```
---@param range jet.send.Range
Range.textobject = function(range)
	vim.api.nvim_buf_set_mark(0, "<", range.start_row + 1, range.start_col, {})
	vim.api.nvim_buf_set_mark(0, ">", range.end_row + 1, range.end_col - 1, {})
	vim.cmd("normal! gv")
end

return Range
