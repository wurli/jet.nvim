--- TODO: swap for vim.Pos once it's stabilised
---@class jet.send.Pos
---@field buf integer
---@field row integer 0-indexed
---@field col integer 0-indexed

local Pos = {}

---@param a jet.send.Pos
---@param b jet.send.Pos
---@return boolean
Pos.pos_eq = function(a, b) return a.buf == b.buf and a.row == b.row and a.col == b.col end

---@param pos jet.send.Pos
---@param n? -1 | 1
---@return jet.send.Pos?
Pos.pos_nudge = function(pos, n)
	n = n or 1

	local new_col = pos.col + n

	if n == 1 then
		local line = vim.api.nvim_buf_get_lines(pos.buf, pos.row, pos.row + 1, false)[1]
		if new_col <= (line and #line or 1) - 1 then
			return { buf = pos.buf, row = pos.row, col = new_col }
		else
			local new_row = pos.row + 1
			if new_row <= vim.api.nvim_buf_line_count(pos.buf) then
				return { buf = pos.buf, row = new_row, col = 0 }
			else
				return
			end
		end
	end

	if n == -1 then
		if new_col >= 0 then
			return { buf = pos.buf, row = pos.row, col = new_col }
		else
			local new_row = pos.row - 1
			if new_row >= 0 then
				local line = vim.api.nvim_buf_get_lines(pos.buf, new_row, new_row + 1, false)[1]
				return { buf = pos.buf, row = new_row, col = line and math.max(0, (#line - 1)) or 0 }
			else
				return
			end
		end
	end
end

---@param a jet.send.Pos
---@param b jet.send.Pos
Pos.pos_lt = function(a, b)
	assert(a.buf == b.buf, "Cannot compare positions in different buffers")

	if a.row < b.row then
		return true
	elseif a.row > b.row then
		return false
	else
		return a.col < b.col
	end
end

---@return jet.send.Pos
Pos.curr_pos = function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	return {
		buf = vim.api.nvim_get_current_buf(),
		row = cursor[1] - 1,
		col = cursor[2],
	}
end

---@param p jet.send.Pos
Pos.pos_char = function(p)
	local line = vim.api.nvim_buf_get_lines(p.buf, p.row, p.row + 1, false)[1]
	if not line then
		return nil
	end
	return line:sub(p.col + 1, p.col + 1)
end

return Pos
