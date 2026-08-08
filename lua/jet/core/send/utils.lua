local M = {}

---@generic T
---@class jet.utils.queue<T> : T[]
---@field _items T[]
---@field first integer
---@field last integer
---@field len integer
local Queue = {}
Queue.__index = function(q, k)
	if type(k) == "number" then
		return q.items[q.first + k - 1]
	end
	return Queue[k]
end

---@param v T
Queue.__newindex = function(q, k, v)
	assert(type(k) == "number")
	if k < 1 or k > q.len then
		error(string.format("Can't assign to index %s (outside of [1, %s])", k, q.len))
	end
	q.items[q.first + k - 1] = v
end

---Add an item to the end of the queue, maybe pushing one out from the front
---@param x T
function Queue:append(x)
	if self.last - self.first + 1 >= self.len then
		self._items[self.first] = nil
		self.first = self.first + 1
	end
	self.last = self.last + 1
	self._items[self.last] = x
end

---Add an item to the front of the queue, maybe pushing one out from the end
---@param x T
function Queue:prepend(x)
	if self.last - self.first + 1 >= self.len then
		self._items[self.last] = nil
		self.last = self.last - 1
	end
	self.first = self.first - 1
	self._items[self.first] = x
end

function Queue:items()
	local out = {}
	for i = self.first, self.last do
		table.insert(out, self._items[i])
	end
	return out
end

--- ``` lua
--- local q = M.queue(3, {} --[[@as string[] ]])
--- q:append("hi")
--- q:append("there")
--- q:append("esteemed")
--- q:append("user")
--- vim.print(q:items())
--- -- { "there", "esteemed", "user" }
--- ```
---@generic U
---@param len integer
---@param items U[]
---@return jet.utils.queue<U>
M.queue = function(len, items)
	return setmetatable({
		_items = items or {},
		first = 1,
		last = 0,
		len = len,
	}, Queue)
end

---Adapted from https://github.com/neovim/neovim/blob/master/runtime/lua/vim/_comment.lua
---NOTE: if this causes issues in the future (e.g. we don't actually want the
---range-specific filetype) we could instead return a table of candidate
---filetypes and commentstrings, then match these against kernel filetypes
---until we find a match. Don't do this until it's clear that it's a real issue.
---@param pos? jet.send.Pos
---@return { filetype?: string, commentstring?: string }
M.local_lang_info = function(pos)
	pos = pos or require("jet.core.send.get_code").curr_pos()
	local buf_ft = vim.bo[pos.buf].filetype
	local buf_cs = vim.bo[pos.buf].commentstring

	local ts_parser = vim.treesitter.get_parser(pos.buf, "")
	if not ts_parser then
		return {
			filetype = buf_ft,
			commentstring = buf_cs,
		}
	end

	-- Get 'commentstring' from tree-sitter captures' metadata.
	-- Traverse backwards to prefer narrower captures.
	local captures = vim.treesitter.get_captures_at_pos(pos.buf, pos.row, pos.col - 1)
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
		if not lang_tree:contains({ pos.row, pos.col, pos.row, pos.col }) then
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

---@param text string
---@param commentstring? string
M.is_comment = function(text, commentstring)
	-- Happens reasonably often, so worth checking here for convenience
	if not commentstring or commentstring == "" then
		return false
	end

	local cs_left, cs_right = commentstring:match("^(.-)%s*%%s%s*(.-)$")

	if not (cs_left and cs_right) then
		return false
	end

	local startswith = function(s, prefix)
		if #prefix == 0 then
			return true
		end
		return s:sub(1, #prefix) == prefix
	end
	local endswith = function(s, suffix)
		if #suffix == 0 then
			return true
		end
		return s:sub(-#suffix) == suffix
	end

	text = vim.trim(text)
	return startswith(text, cs_left) and endswith(text, cs_right)
end

---@param pos jet.send.Pos
---@return integer? 1-indexed line number
M.next_significant_line = function(pos)
	local lang_info = M.local_lang_info(pos)
	if not lang_info.commentstring then
		return nil
	end

	local cur_line = pos.row

	while true do
		cur_line = cur_line + 1
		local line = vim.api.nvim_buf_get_lines(pos.buf, cur_line, cur_line + 1, false)[1]
		if not line then
			return nil
		end
		if line:match("%S") and not M.is_comment(line, lang_info.commentstring) then
			return cur_line
		end
	end
end

return M
