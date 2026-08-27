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

---@return integer, integer
function Pos:to_cursor() return self.row + 1, self.col + 1 end

---Adapted from https://github.com/neovim/neovim/blob/master/runtime/lua/vim/_comment.lua
---NOTE: if this causes issues in the future (e.g. we don't actually want the
---range-specific filetype) we could instead return a table of candidate
---filetypes and commentstrings, then match these against kernel filetypes
---until we find a match. Don't do this until it's clear that it's a real issue.
---@return { filetype?: string, commentstring?: string }
function Pos:lang_info()
	local buf_ft = vim.bo[self.buf].filetype
	local buf_cs = vim.bo[self.buf].commentstring

	local ts_parser = vim.treesitter.get_parser(self.buf, "")
	if not ts_parser then
		return {
			filetype = buf_ft,
			commentstring = buf_cs,
		}
	end

	-- Get 'commentstring' from tree-sitter captures' metadata.
	-- Traverse backwards to prefer narrower captures.
	local captures = vim.treesitter.get_captures_at_pos(self.buf, self.row, self.col - 1)
	for i = #captures, 1, -1 do
		local id, metadata = captures[i].id, captures[i].metadata
		local metadata_cs = metadata["bo.commentstring"] or metadata[id] and metadata[id]["bo.commentstring"]
		local metadata_ft = metadata["bo.filetype"] or metadata[id] and metadata[id]["bo.filetype"]

		if metadata_cs and metadata_ft and type(metadata_ft) == "string" then
			return {
				filetype = metadata_ft,
				commentstring = metadata_cs,
			}
		end
	end

	-- Get filetype and commentstring from the deepest LanguageTree which
	-- both contains reference range and has valid 'commentstring' and
	-- 'filetype'. In simple cases using `parser:language_for_range()` would be
	-- enough, but it might return a language without a valid 'commentstring',
	-- (like 'comment'), which is not very useful for our purposes.
	local treesitter_ft, treesitter_cs, res_level = nil, nil, 0

	---@param lang_tree vim.treesitter.LanguageTree
	local function traverse(lang_tree, level)
		if not lang_tree:contains({ self.row, self.col, self.row, self.col }) then
			return
		end

		local filetypes = vim.treesitter.language.get_filetypes(lang_tree:lang())
		for _, curr_ft in ipairs(filetypes) do
			local cur_cs = vim.filetype.get_option(curr_ft, "commentstring")
			if cur_cs ~= "" and curr_ft ~= "" and level > res_level then
				treesitter_cs = cur_cs
				treesitter_ft = curr_ft
				break
			end
		end

		for _, child_lang_tree in pairs(lang_tree:children()) do
			traverse(child_lang_tree, level + 1)
		end
	end
	traverse(ts_parser, 1)

	return {
		filetype = (treesitter_ft or buf_ft),
		commentstring = (treesitter_cs or buf_cs),
	}
end

return Pos
