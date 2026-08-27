--- TODO: swap for vim.Pos once it's stabilised
---@class jet.send.Pos
---@field buf integer
---@field row integer 0-indexed
---@field col integer 0-indexed
local Pos = {}
Pos.__index = Pos

---@param opts Partial<jet.send.Pos>
---@return jet.send.Pos
Pos.new = function(opts) return setmetatable(opts, Pos) end

---@param p jet.send.Pos
---@return boolean
function Pos:eq(p) return self.buf == p.buf and self.row == p.row and self.col == p.col end

---@param n? -1 | 1
---@return jet.send.Pos?
function Pos:nudge(n)
	n = n or 1

	local new_col = self.col + n

	if n == 1 then
		local line = vim.api.nvim_buf_get_lines(self.buf, self.row, self.row + 1, false)[1]
		if new_col <= (line and #line or 1) - 1 then
			return Pos.new({ buf = self.buf, row = self.row, col = new_col })
		else
			local new_row = self.row + 1
			if new_row <= vim.api.nvim_buf_line_count(self.buf) then
				return Pos.new({ buf = self.buf, row = new_row, col = 0 })
			else
				return
			end
		end
	end

	if n == -1 then
		if new_col >= 0 then
			return Pos.new({ buf = self.buf, row = self.row, col = new_col })
		else
			local new_row = self.row - 1
			if new_row >= 0 then
				local line = vim.api.nvim_buf_get_lines(self.buf, new_row, new_row + 1, false)[1]
				return Pos.new({ buf = self.buf, row = new_row, col = line and math.max(0, (#line - 1)) or 0 })
			else
				return
			end
		end
	end
end

---@param p jet.send.Pos
function Pos:lt(p)
	assert(self.buf == p.buf, "Cannot compare positions in different buffers")

	if self.row < p.row then
		return true
	elseif self.row > p.row then
		return false
	else
		return self.col < p.col
	end
end

---@return jet.send.Pos
Pos.get_curr = function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	return Pos.new({
		buf = vim.api.nvim_get_current_buf(),
		row = cursor[1] - 1,
		col = cursor[2],
	})
end

---@return string?
function Pos:to_char()
	local line = vim.api.nvim_buf_get_lines(self.buf, self.row, self.row + 1, false)[1]
	if not line then
		return nil
	end
	return line:sub(self.col + 1, self.col + 1)
end

return Pos
