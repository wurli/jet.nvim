-- local MiniTest = require("mini.test")
-- local child = MiniTest.new_child_neovim()
--
-- local open_test_buf = function(lines)
-- 	child.cmd("enew")
-- 	child.bo.filetype = "my_test_filetype"
-- 	child.api.nvim_buf_set_lines(0, 0, -1, false, lines)
-- 	child.fn.cursor(1, 1)
-- end
--
-- ---@param actual jet.send.Pos
-- ---@param expected { row: integer, col: integer }
-- local expect_pos = function(actual, expected)
-- 	assert(
-- 		actual.row == expected.row and actual.col == expected.col,
-- 		string.format(
-- 			"\nExpected: %s\nGot: %s",
-- 			vim.inspect(expected),
-- 			vim.inspect({ row = actual.row, col = actual.col })
-- 		)
-- 	)
-- end
--
-- local T = MiniTest.new_set({
-- 	hooks = {
-- 		pre_once = function()
-- 			child.restart({ "-u", "scripts/minimal_init.lua" })

---Region of contiguous non-whitespace on the current line around `pos`.
---Returns nil when the cursor sits on whitespace or past end-of-line.
---
---@param pos jet.send.Pos
---@return jet.send.Range?
local get_expr = function(pos)
	print("-----------------------------------")
	vim.print("pos: " .. pos.row .. ", " .. pos.col)
	local nudge = require("jet.core.send.utils").pos_nudge
	local lines = vim.api.nvim_buf_get_lines(pos.buf, 0, -1, false)

	local pos_to_char = function(p)
		local line = lines[p.row + 1]
		return line and line:sub(p.col + 1, p.col + 1) or nil
	end

	---@param p jet.send.Pos
	local pos_is_nonblank = function(p)
		local line = lines[p.row + 1]
		local char = line and line:sub(p.col + 1, p.col + 1)
		return char and char ~= "" and char:match("%s") == nil or false
	end

	if not pos_is_nonblank(pos) then
		return nil
	end

	local start_pos = vim.deepcopy(pos)
	local end_pos = vim.deepcopy(pos)

	local prev_pos = nudge(start_pos, -1)
	while prev_pos and pos_is_nonblank(prev_pos) do
		start_pos = prev_pos
		prev_pos = nudge(prev_pos, -1)
	end

	local next_pos = nudge(end_pos, 1)
	while next_pos and pos_is_nonblank(next_pos) do
		vim.print({ pos_to_char(next_pos) })
		end_pos = next_pos
		next_pos = nudge(end_pos, 1)
	end

	local out = {
		buf = pos.buf,
		start_row = start_pos.row,
		start_col = start_pos.col,
		end_row = end_pos.row,
		end_col = end_pos.col + 1,
	}

	vim.print(out)

	return out
end

require("jet.core.send.get_code").filetype.lua = { get_expr = get_expr }

vim.keymap.set("n", "]e", function()
	local pos = require("jet.core.send.utils").next_expr_boundary({
		direction = 1,
		boundary = "any",
	})
	if pos then
		vim.fn.cursor(pos.row + 1, pos.col + 1)
	end
end)
vim.keymap.set("n", "[e", function()
	local pos = require("jet.core.send.utils").next_expr_boundary({
		direction = -1,
		boundary = "any",
	})
	if pos then
		vim.fn.cursor(pos.row + 1, pos.col + 1)
	end
end)

-- 		end,
-- 		post_once = child.stop,
-- 	},
-- })
--
-- T["next_expr_boundary() works"] = function()
-- 	open_test_buf({
-- 		"",
-- 		"foo",
-- 		"barbar",
-- 		"",
-- 	})
--
-- 	child.lua([[
-- 		_G.cursor_to_next_expr = function(opts)
-- 			local pos = require("jet.core.send.utils").next_expr_boundary(opts)
-- 			vim.fn.cursor(pos.row + 1, pos.col + 1)
-- 			return pos
-- 		end
-- 	]])
--
-- 	local pos1 = child.lua_get([[
-- 		_G.cursor_to_next_expr({
-- 		    direction = 1,
-- 		    boundary = "start",
-- 		})
-- 	]])
--
-- 	expect_pos(pos1, { row = 1, col = 0 })
--
-- 	local pos2 = child.lua_get([[
-- 		_G.cursor_to_next_expr({
-- 		    direction = 1,
-- 		    boundary = "start",
-- 		})
-- 	]])
--
-- 	expect_pos(pos2, { row = 1, col = 0 })
-- end
--
-- return T
