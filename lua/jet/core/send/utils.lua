local M = {}

---@return jet.send.Pos
M.curr_pos = function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	return {
		buf = vim.api.nvim_get_current_buf(),
		row = cursor[1] - 1,
		col = cursor[2],
	}
end

---@param r jet.send.Range
---@return string[]?
M.range_text = function(r)
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
M.range_code = function(r)
	local text = M.range_text(r)

	if not text then
		return
	end

	local lang_info = M.local_lang_info({ buf = r.buf, row = r.start_row, col = r.start_col })
	local ft, commentstring = lang_info.filetype, lang_info.commentstring

	if not ft or not commentstring then
		return
	end

	local code_filtered = vim.tbl_filter(
		function(line) return line:match("%S") ~= nil and not M.is_comment(line, commentstring) end,
		text
	)

	if #code_filtered == 0 then
		return
	end

	return code_filtered, ft
end

---Adapted from https://github.com/neovim/neovim/blob/master/runtime/lua/vim/_comment.lua
---NOTE: if this causes issues in the future (e.g. we don't actually want the
---range-specific filetype) we could instead return a table of candidate
---filetypes and commentstrings, then match these against kernel filetypes
---until we find a match. Don't do this until it's clear that it's a real issue.
---@param pos? jet.send.Pos
---@return { filetype?: string, commentstring?: string }
M.local_lang_info = function(pos)
	pos = pos or M.curr_pos()
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
---@return boolean
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

---@class jet.send.next_significant_line.Opts
---@field accept_current? boolean
---@field direction? "down" | "up"

---@param opts? jet.send.next_significant_line.Opts
---@param pos? jet.send.Pos
---@return jet.send.Pos?
M.next_expr_boundary = function(opts, pos)
	opts = opts or {}
	opts.direction = opts.direction or "down"
	pos = pos or M.curr_pos()

	local lang_info = M.local_lang_info(pos)
	if not lang_info.commentstring then
		return nil
	end

	local cur_line = pos.row

	local increment = opts.direction == "down" and 1 or -1

	if opts and opts.accept_current then
		cur_line = cur_line - increment
	end

	local prev_is_significant
	local prev_pos

	while true do
		cur_line = cur_line + increment
		local line = vim.api.nvim_buf_get_lines(pos.buf, cur_line, cur_line + 1, false)[1]
		if not line then
			return nil
		end

		local curr_is_significant = line:match("%S") ~= nil and not M.is_comment(line, lang_info.commentstring)

		local curr_pos = {
			buf = pos.buf,
			row = cur_line,
			col = (line:find("%S") or 1) - 1,
		}

		if prev_is_significant ~= nil and (prev_is_significant ~= curr_is_significant) then
			return curr_is_significant and curr_pos or prev_pos
		else
			prev_is_significant = curr_is_significant
			prev_pos = curr_pos
		end
	end
end

---Get the next position in a buffer which is not empty or a comment
---
---@param opts? jet.send.next_significant_line.Opts
---@param pos? jet.send.Pos
---@return jet.send.Pos?
M.next_significant_pos = function(opts, pos)
	opts = opts or {}
	opts.direction = opts.direction or "down"
	pos = pos or M.curr_pos()

	local lang_info = M.local_lang_info(pos)
	if not lang_info.commentstring then
		return nil
	end

	local cur_line = pos.row

	local increment = opts.direction == "down" and 1 or -1

	if opts and opts.accept_current then
		cur_line = cur_line - increment
	end

	local out = { buf = pos.buf }

	while true do
		cur_line = cur_line + increment
		local line = vim.api.nvim_buf_get_lines(pos.buf, cur_line, cur_line + 1, false)[1]
		if not line then
			return nil
		end
		if line:match("%S") and not M.is_comment(line, lang_info.commentstring) then
			out.row = cur_line
			out.col = (line:find("%S") or 1) - 1
			break
		end
	end

	return out
end

return M
