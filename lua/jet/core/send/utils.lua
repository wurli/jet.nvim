local pos = require("jet.core.send.pos")
local range = require("jet.core.send.range")

local M = {}

---Adapted from https://github.com/neovim/neovim/blob/master/runtime/lua/vim/_comment.lua
---NOTE: if this causes issues in the future (e.g. we don't actually want the
---range-specific filetype) we could instead return a table of candidate
---filetypes and commentstrings, then match these against kernel filetypes
---until we find a match. Don't do this until it's clear that it's a real issue.
---@param p? jet.send.Pos
---@return { filetype?: string, commentstring?: string }
M.local_lang_info = function(p)
	p = p or pos.curr_pos()
	local buf_ft = vim.bo[p.buf].filetype
	local buf_cs = vim.bo[p.buf].commentstring

	local ts_parser = vim.treesitter.get_parser(p.buf, "")
	if not ts_parser then
		return {
			filetype = buf_ft,
			commentstring = buf_cs,
		}
	end

	-- Get 'commentstring' from tree-sitter captures' metadata.
	-- Traverse backwards to prefer narrower captures.
	local captures = vim.treesitter.get_captures_at_pos(p.buf, p.row, p.col - 1)
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
		if not lang_tree:contains({ p.row, p.col, p.row, p.col }) then
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
---@field direction? 1 | -1
---@field boundary? "start" | "end" | "any"
---@field current_ok? boolean
---@field _no_recurse? boolean

---@param opts? jet.send.next_significant_line.Opts
---@param p? jet.send.Pos
---@return jet.send.Pos?
M.next_expr_boundary = function(opts, p)
	opts = opts or {}
	opts.boundary = opts.boundary or "any"
	opts.direction = opts.direction or 1
	p = p or pos.curr_pos()
	local include_boundary_start = opts.boundary == "start" or opts.boundary == "any"
	local include_boundary_end = opts.boundary == "end" or opts.boundary == "any"

	local expr = require("jet.core.send.get_range").get_expr(p)

	if not expr then
		local next_pos = M.next_significant_pos(opts, p)
		expr = next_pos and require("jet.core.send.get_range").get_expr(next_pos)
		if next_pos and not expr then
			require("jet.core.utils").log_warn(
				"Failed to get expression at position %d:%d; skipping line.",
				next_pos.row + 1,
				next_pos.col + 1
			)
			-- If a node is not a comment but is not captured by the
			-- `get_expr()` code, just skip to the next line. We could also use
			-- `pos_nudge()` to try the next character, but next row means less
			-- messages and is more likely to just skip the problematic region.
			next_pos.row = next_pos.row + opts.direction
			return M.next_expr_boundary(opts, next_pos)
		end
	end

	local out ---@type jet.send.Pos?

	local is_after = function(a, b) return opts.current_ok and pos.pos_eq(a, b) or pos.pos_lt(b, a) end

	if expr then
		local r_start = range.range_start(expr)
		local r_end = range.range_end(expr)

		if opts.direction == 1 then
			out = (include_boundary_start and is_after(r_start, p) and r_start)
				or (include_boundary_end and is_after(r_end, p) and r_end)
				or nil

			if not (out and is_after(out, p)) then
				local nudged = pos.pos_nudge(r_end, opts.direction)
				if nudged then
					opts.current_ok = true
					opts._no_recurse = true
					out = M.next_expr_boundary(opts, nudged)
				end
			end
		elseif opts.direction == -1 then
			out = (include_boundary_end and is_after(p, r_end) and r_end)
				or (include_boundary_start and is_after(p, r_start) and r_start)
				or nil

			if not (out and is_after(p, out)) then
				local nudged = pos.pos_nudge(r_start, opts.direction)
				if nudged then
					opts.current_ok = true
					opts._no_recurse = true
					out = M.next_expr_boundary(opts, nudged)
				end
			end
		end
	end

	if not out or opts.current_ok or (not pos.pos_eq(out, p)) then
		return out
	end

	opts.current_ok = true
	local next = M.next_expr_boundary(opts, p)
	if not next or not pos.pos_eq(p, next) then
		return
	end

	return pos.pos_nudge(next, opts.direction == "down" and 1 or -1)
end

---Get the next position in a buffer which is not empty or a comment
---
---@param opts? jet.send.next_significant_line.Opts
---@param p? jet.send.Pos
---@return jet.send.Pos?
M.next_significant_pos = function(opts, p)
	opts = opts or {}
	opts.direction = opts.direction or 1
	p = p or pos.curr_pos()

	local lang_info = M.local_lang_info(p)
	if not lang_info.commentstring then
		return nil
	end

	local cur_line = p.row
	local out = { buf = p.buf }

	while true do
		local line = vim.api.nvim_buf_get_lines(p.buf, cur_line, cur_line + 1, false)[1]

		if not line then
			return nil
		end

		if cur_line == p.row then
			if opts.direction == 1 then
				line = line:sub(p.col + 1)
			else
				line = line:sub(1, p.col)
			end
		end

		if line:match("%S") and not M.is_comment(line, lang_info.commentstring) then
			out.row = cur_line
			if opts.direction == 1 then
				out.col = (line:find("%S") or 1) - 1
			else
				out.col = (line:find("%S%s*$") or #line) - 1
			end
			if cur_line == p.row and opts.direction == 1 then
				out.col = out.col + p.col
			end
			break
		end

		cur_line = cur_line + opts.direction
	end

	return out
end

return M
