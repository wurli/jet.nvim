local pos = require("jet.core.send.pos")

--- TODO: swap for vim.Range once it's stabilised
---@class jet.send.Range
---@field buf integer
---@field start_row integer 0-indexed
---@field start_col integer 0-indexed
---@field end_row integer 0-indexed
---@field end_col integer 0-indexed
local Range = {}
Range.__index = Range

---@param opts Partial<jet.send.Range>
---@return jet.send.Range
Range.new = function(opts) return setmetatable(opts, Range) end

---@return string[]?
function Range:text()
	local ok, text =
		pcall(vim.api.nvim_buf_get_text, self.buf, self.start_row, self.start_col, self.end_row, self.end_col, {})
	if not ok then
		return nil
	end
	if #text == 0 then
		return nil
	end
	return text
end

---@class jet.send.range_code.Opts
---@field comments boolean? Set to `true` to include comments in the returned code.

---@param opts jet.send.range_code.Opts?
---@return nil
---@return_overload string[], string
function Range:range_code(opts)
	opts = opts or {}
	local utils = require("jet.core.send.utils")

	local text = Range.text(self)

	if not text then
		return
	end

	local lang_info = utils.local_lang_info(pos.new({ buf = self.buf, row = self.start_row, col = self.start_col }))
	local ft, commentstring = lang_info.filetype, lang_info.commentstring

	if not ft or not commentstring then
		return
	end

	if not opts.comments then
		text = vim.tbl_filter(
			function(line) return line:match("%S") ~= nil and not utils.is_comment(line, commentstring) end,
			text
		)
	end

	if #text == 0 then
		return
	end

	return text, ft
end

---@return jet.send.Pos
function Range:start()
	return pos.new({
		buf = self.buf,
		row = self.start_row,
		col = self.start_col,
	})
end

---@return jet.send.Pos
function Range:_end()
	-- Gotta nudge since range end is exclusive
	local out = pos.new({ buf = self.buf, row = self.end_row, col = self.end_col }):nudge(-1)
	assert(out, "Failed to nudge range end position backwards")
	return out
end

function Range:textobject()
	vim.api.nvim_buf_set_mark(0, "<", self.start_row + 1, self.start_col, {})
	vim.api.nvim_buf_set_mark(0, ">", self.end_row + 1, self.end_col - 1, {})
	vim.cmd("normal! gv")
end

return Range
