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

---@param p jet.send.Pos
M.pos_char = function(p)
	local line = vim.api.nvim_buf_get_lines(p.buf, p.row, p.row + 1, false)[1]
	if not line then
		return nil
	end
	return line:sub(p.col + 1, p.col + 1)
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

---@param r jet.send.Range
---@return jet.send.Pos
M.range_end = function(r)
	-- Gotta nudge since range end is exclusive
	local out = M.pos_nudge({
		buf = r.buf,
		row = r.end_row,
		col = r.end_col,
	}, -1)
	assert(out, "Failed to nudge range end position backwards")
	return out
end

---@param r jet.send.Range
---@return jet.send.Pos
M.range_start = function(r)
	return {
		buf = r.buf,
		row = r.start_row,
		col = r.start_col,
	}
end

---@param a jet.send.Pos
---@param b jet.send.Pos
---@return boolean
M.pos_eq = function(a, b) return a.buf == b.buf and a.row == b.row and a.col == b.col end

---@param pos jet.send.Pos
---@param n? -1 | 1
---@return jet.send.Pos?
M.pos_nudge = function(pos, n)
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

-- vim.keymap.set("n", "<leader>t", function()
-- 	local pos = M.curr_pos()
-- 	vim.print({ pos = pos, next = M.pos_nudge(pos, 1), prev = M.pos_nudge(pos, -1) })
-- end)

---@param a jet.send.Pos
---@param b jet.send.Pos
M.pos_lt = function(a, b)
	assert(a.buf == b.buf, "Cannot compare positions in different buffers")

	if a.row < b.row then
		return true
	elseif a.row > b.row then
		return false
	else
		return a.col < b.col
	end
end

---@class jet.send.next_significant_line.Opts
---@field direction? 1 | -1
---@field boundary? "start" | "end" | "any"
---@field current_ok? boolean
---@field _no_recurse? boolean

---@param opts? jet.send.next_significant_line.Opts
---@param pos? jet.send.Pos
---@return jet.send.Pos?
M.next_expr_boundary = function(opts, pos)
	opts = opts or {}
	opts.boundary = opts.boundary or "any"
	opts.direction = opts.direction or 1
	pos = pos or M.curr_pos()
	local include_boundary_start = opts.boundary == "start" or opts.boundary == "any"
	local include_boundary_end = opts.boundary == "end" or opts.boundary == "any"

	local expr = require("jet.core.send.get_code").get_expr(pos)

	if not expr then
		local next_pos = M.next_significant_pos(opts, pos)
		expr = next_pos and require("jet.core.send.get_code").get_expr(next_pos)
		if next_pos and not expr then
			require("jet.core.utils").log_warn(
				"Failed to get expression at non-commented position %d:%d; returning early",
				next_pos.row + 1,
				next_pos.col + 1
			)
			return
		end
	end

	local out ---@type jet.send.Pos?

	local is_after = function(a, b) return opts.current_ok and M.pos_eq(a, b) or M.pos_lt(b, a) end

	if expr then
		local r_start = M.range_start(expr)
		local r_end = M.range_end(expr)

		if opts.direction == 1 then
			out = (include_boundary_start and is_after(r_start, pos) and r_start)
				or (include_boundary_end and is_after(r_end, pos) and r_end)
				or nil

			if not (out and is_after(out, pos)) then
				local nudged = M.pos_nudge(r_end, opts.direction)
				if nudged then
					opts.current_ok = true
					opts._no_recurse = true
					out = M.next_expr_boundary(opts, nudged)
				end
			end
		elseif opts.direction == -1 then
			out = (include_boundary_end and is_after(pos, r_end) and r_end)
				or (include_boundary_start and is_after(pos, r_start) and r_start)
				or nil

			if not (out and is_after(pos, out)) then
				local nudged = M.pos_nudge(r_start, opts.direction)
				if nudged then
					opts.current_ok = true
					opts._no_recurse = true
					out = M.next_expr_boundary(opts, nudged)
				end
			end
		end
	end

	if not out or opts.current_ok or (not M.pos_eq(out, pos)) then
		return out
	end

	opts.current_ok = true
	local next = M.next_expr_boundary(opts, pos)
	if not next or not M.pos_eq(pos, next) then
		return
	end

	return M.pos_nudge(next, opts.direction == "down" and 1 or -1)
end

---Get the next position in a buffer which is not empty or a comment
---
---@param opts? jet.send.next_significant_line.Opts
---@param pos? jet.send.Pos
---@return jet.send.Pos?
M.next_significant_pos = function(opts, pos)
	opts = opts or {}
	opts.direction = opts.direction or 1
	pos = pos or M.curr_pos()

	local lang_info = M.local_lang_info(pos)
	if not lang_info.commentstring then
		return nil
	end

	local cur_line = pos.row
	local out = { buf = pos.buf }

	while true do
		local line = vim.api.nvim_buf_get_lines(pos.buf, cur_line, cur_line + 1, false)[1]

		if not line then
			return nil
		end

		if cur_line == pos.row then
			if opts.direction == 1 then
				line = line:sub(pos.col + 1)
			else
				line = line:sub(1, pos.col)
			end
		end

		if line:match("%S") and not M.is_comment(line, lang_info.commentstring) then
			out.row = cur_line
			if opts.direction == 1 then
				out.col = (line:find("%S") or 1) - 1
			else
				out.col = (line:find("%S%s*$") or #line) - 1
			end
			if cur_line == pos.row and opts.direction == 1 then
				out.col = out.col + pos.col
			end
			break
		end

		cur_line = cur_line + opts.direction
	end

	return out
end

return M
