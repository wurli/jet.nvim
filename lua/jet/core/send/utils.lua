local pos = require("jet.core.send.pos")

local M = {}

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
	p = p or pos.get_curr()
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

	---@param a jet.send.Pos
	---@param b jet.send.Pos
	local is_after = function(a, b) return opts.current_ok and a:eq(b) or b:lt(a) end

	if expr then
		local r_start = expr:start()
		local r_end = expr:_end()

		if opts.direction == 1 then
			out = (include_boundary_start and is_after(r_start, p) and r_start)
				or (include_boundary_end and is_after(r_end, p) and r_end)
				or nil

			if not (out and is_after(out, p)) then
				local nudged = r_end:nudge(opts.direction)
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
				local nudged = r_start:nudge(opts.direction)
				if nudged then
					opts.current_ok = true
					opts._no_recurse = true
					out = M.next_expr_boundary(opts, nudged)
				end
			end
		end
	end

	if not out or opts.current_ok or (not out:eq(p)) then
		return out
	end

	opts.current_ok = true
	local next = M.next_expr_boundary(opts, p)
	if not next or not p:eq(next) then
		return
	end

	return next:nudge(opts.direction == "down" and 1 or -1)
end

---Get the next position in a buffer which is not empty or a comment
---
---@param opts? jet.send.next_significant_line.Opts
---@param p? jet.send.Pos
---@return jet.send.Pos?
M.next_significant_pos = function(opts, p)
	opts = opts or {}
	opts.direction = opts.direction or 1
	p = p or pos.get_curr()

	local lang = p:lang_info()
	if not lang.commentstring then
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

		if line:match("%S") and not require("jet.core.utils.comment").is_comment(line, lang.commentstring) then
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

	return pos.new(out)
end

return M
