local range = require("jet.core.send.range")
local pos = require("jet.core.send.pos")

---@class jet.GetCode
local M = {
	---@type table<string, Partial<jet.GetCode>>
	filetype = {
		markdown = require("jet.core.send.markdown"),
	},
}

---@param p jet.send.Pos?
---@return jet.send.Range?
M.get_auto = function(p)
	p = p or pos.get_curr()
	if vim.tbl_contains({ "v", "V", "" }, vim.fn.mode()) then
		return M.get_visual()
	end
	return M.get_expr(p)
end

---@param p jet.send.Pos
---@return jet.send.Range?
M.get_expr = function(p)
	-- Note: we want the filetype at the _cursor_, not the buffer filetype
	local ft = p:lang_info().filetype
	local ft_module = require("jet").filetype[ft] or {}
	if ft_module.get_expr then
		local out = ft_module.get_expr(p)
		if out and not out.code then
			out = range.new(out)
		end
		return out
	end

	return M.get_line(p)
end

---@param p jet.send.Pos
---@return jet.send.Range?
M.get_line = function(p)
	local line = vim.api.nvim_buf_get_lines(p.buf, p.row, p.row + 1, false)[1]
	if not line then
		return
	end
	return range.new({
		buf = p.buf,
		start_row = p.row,
		start_col = 0,
		end_row = p.row + 1,
		end_col = #line,
	})
end

---@return jet.send.Range?
M.get_visual = function()
	local mode = vim.fn.mode()
	if vim.tbl_contains({ "v", "V", "" }, mode) then
		local region = vim.fn.getregionpos(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
		assert(region and region[1] and region[#region], "Failed to get visual region")

		local pos1 = region[1][1]
		local pos2 = region[#region][2]

		return range.new({
			buf = vim.api.nvim_get_current_buf(),
			start_row = pos1[2] - 1,
			start_col = pos1[3] - 1,
			end_row = pos2[2] - 1,
			end_col = pos2[3],
		})
	end
	return M.get_line(pos.new({
		buf = vim.api.nvim_get_current_buf(),
		row = vim.fn.line(".") - 1,
		col = vim.fn.col(".") - 1,
	}))
end

---Holds the callback executed by `handle_motion()` after a motion is completed
_G.JET_OP_PENDING_CALLBACK = nil

---Can be used in mappings to handle the code moved over by a motion:
---
---```lua
---vim.keymap.set(
--    { "n", "v" },
--    "gj",
--    require("jet.core.execute").get_motion(vim.print),
--    { expr = true }
--)
---```
---
---@param callback fun(code: jet.send.Range, filetype: string?)
---@return fun(): "g@" # A function that can be used in an operator-pending mapping
M.handle_motion = function(callback)
	return function()
		-- Unfortunately doesn't seem to work if the callback is a member of this module
		_G.JET_OP_PENDING_CALLBACK = callback
		vim.o.operatorfunc = "v:lua.require'jet.core.send.get_range'._handle_curr_motion"
		return "g@"
	end
end

---@private
---@param mode "line" | "block" | "char"
M._handle_curr_motion = function(mode)
	if not _G.JET_OP_PENDING_CALLBACK then
		return
	end

	local region = vim.fn.getregionpos(vim.fn.getpos("'["), vim.fn.getpos("']"), {
		type = mode == "line" and "V"
			or mode == "block" and ""
			or mode == "char" and "v"
			-- Keeps lsp happy
			or error("Invalid mode: " .. vim.inspect(mode)),
	})
	assert(region and region[1] and region[#region], "Failed to get motion region")
	local pos1 = region[1][1]
	local pos2 = region[#region][2]

	local code = range.new({
		buf = vim.api.nvim_get_current_buf(),
		start_row = pos1[2] - 1,
		start_col = pos1[3] - 1,
		end_row = pos2[2] - 1,
		end_col = pos2[3],
	})

	---`if` to avoid LSP warnings
	if _G.JET_OP_PENDING_CALLBACK then
		_G.JET_OP_PENDING_CALLBACK(code, code:start():lang_info().filetype)
	end
	_G.JET_OP_PENDING_CALLBACK = nil
end

return M
