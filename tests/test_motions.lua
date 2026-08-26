-- local MiniTest = require("mini.test")
-- local child = MiniTest.new_child_neovim()
--
-- local open_lua_buf = function(lines)
-- 	child.cmd("enew")
-- 	child.bo.filetype = "lua"
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

---Set the 'expr' function for Lua to something which is basically
---gets the same range as `vip`, but without visual-line mode
---
---@param pos jet.send.Pos
---@return jet.send.Range?
local get_expr = function(pos)
	local lines = vim.api.nvim_buf_get_lines(pos.buf, 0, -1, false)
	local curr_row = pos.row + 1
	local curr_text = lines[curr_row]
	if not (curr_text and curr_text:match("%S")) then
		return
	end

	local first_non_blank = function(s) return s:find("%S") end ---@param s string
	local last_non_blank = function(s) return s:find("%S%s*$") end ---@param s string

	local start_row = curr_row
	local start_col = first_non_blank(curr_text)
	while true do
		local text = lines[start_row - 1]
		local first_char = text and first_non_blank(text)
		if first_char then
			start_col = first_char
			start_row = start_row - 1
		else
			break
		end
	end

	local end_row = curr_row
	local end_col = last_non_blank(curr_text)
	while true do
		local text = lines[end_row + 1]
		local last_char = text and last_non_blank(text)
		if last_char then
			end_col = last_char
			end_row = end_row + 1
		else
			break
		end
	end

	if not (start_col and end_col) then
		return
	end

	local out = {
		buf = pos.buf,
		start_row = start_row - 1,
		start_col = start_col - 1,
		end_row = end_row - 1,
		end_col = end_col,
	}

	vim.print({
		pos = pos,
		out = out,
	})

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
-- 	open_lua_buf({
-- 		"",
-- 		"local foo = 123",
-- 		"print(foo)",
-- 		"",
-- 		"   local bar = 123 - 234",
-- 		"",
-- 		"",
-- 		"local foo = 123",
-- 		"print(foo)",
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
