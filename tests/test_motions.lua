local MiniTest = require("mini.test")
local child = MiniTest.new_child_neovim()

local open_test_buf = function(lines)
	child.cmd("enew")
	child.bo.filetype = "my_test_filetype"
	child.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	child.fn.cursor(1, 1)
end

---@param actual? table | vim.NIL
---@param expected? { row: integer, col: integer }
local expect_pos = function(actual, expected)
	actual = actual ~= vim.NIL and actual or nil
	assert(
		actual == nil and expected == nil
			or actual and expected and actual.row == expected.row and actual.col == expected.col,
		string.format(
			"\nExpected: %s\nGot: %s",
			expected and vim.inspect(expected) or "nil",
			actual and vim.inspect({ row = actual.row, col = actual.col }) or "nil"
		)
	)
end

local T = MiniTest.new_set({
	hooks = {
		pre_once = function()
			child.restart({ "-u", "scripts/minimal_init.lua" })
			child.lua([[
				---Region of contiguous non-whitespace around `pos`, including
				---overflow to surrounding lines. Returns nil when the cursor
				---sits on whitespace.
				---
				---@param pos jet.send.Pos
				---@return jet.send.Range?
				local get_expr = function(pos)
					local nudge = require("jet.core.send.utils").pos_nudge
					local lines = vim.api.nvim_buf_get_lines(pos.buf, 0, -1, false)

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

					return out
				end

				require("jet.core.send.get_code").filetype.my_test_filetype = { get_expr = get_expr }

				_G.cursor_to_next_expr = function(opts)
					local pos = require("jet.core.send.utils").next_expr_boundary(opts)
					if pos then
						vim.fn.cursor(pos.row + 1, pos.col + 1)
						return pos
					end
				end
			]])
		end,
		post_once = child.stop,
	},
})

require("jet.core.send.utils").next_expr_boundary()

---@param opts jet.send.next_significant_line.Opts
local next_expr_boundary = function(opts)
	local out = child.lua_get(
		string.format(
			'_G.cursor_to_next_expr({ direction = %d, boundary = "%s", current_ok = %s })',
			opts.direction or 1,
			opts.boundary or "any",
			opts.current_ok and "true" or "false"
		)
	)
	return out ~= vim.NIL and out or nil
end

T["next_expr_boundary() works with boundary 'any' going forwards"] = function()
	open_test_buf({
		"",
		"abc",
		"def",
		"",
		"ghi",
	})

	expect_pos(next_expr_boundary({}), { row = 1, col = 0 })
	expect_pos(next_expr_boundary({}), { row = 2, col = 2 })
	expect_pos(next_expr_boundary({}), { row = 4, col = 0 })
	expect_pos(next_expr_boundary({}), { row = 4, col = 2 })
	expect_pos(next_expr_boundary({}), nil)
end

T["next_expr_boundary() works with boundary 'any' going backwards"] = function()
	open_test_buf({
		"",
		"abc",
		"def",
		"",
		"ghi",
		"",
	})

	child.fn.cursor(6, 0)

	expect_pos(next_expr_boundary({ direction = -1 }), { row = 4, col = 2 })
	expect_pos(next_expr_boundary({ direction = -1 }), { row = 4, col = 0 })
	expect_pos(next_expr_boundary({ direction = -1 }), { row = 2, col = 2 })
	expect_pos(next_expr_boundary({ direction = -1 }), { row = 1, col = 0 })
	expect_pos(next_expr_boundary({ direction = -1 }), nil)
end

T["next_expr_boundary() with boundary 'start' going forwards visits only starts"] = function()
	open_test_buf({
		"abc",
		"",
		"def",
		"",
		"ghi",
	})

	expect_pos(next_expr_boundary({ boundary = "start" }), { row = 2, col = 0 })
	expect_pos(next_expr_boundary({ boundary = "start" }), { row = 4, col = 0 })
	expect_pos(next_expr_boundary({ boundary = "start" }), nil)
end

T["next_expr_boundary() with boundary 'end' going forwards visits only ends"] = function()
	open_test_buf({
		"abc",
		"",
		"def",
		"",
		"ghi",
	})

	expect_pos(next_expr_boundary({ boundary = "end" }), { row = 0, col = 2 })
	expect_pos(next_expr_boundary({ boundary = "end" }), { row = 2, col = 2 })
	expect_pos(next_expr_boundary({ boundary = "end" }), { row = 4, col = 2 })
	expect_pos(next_expr_boundary({ boundary = "end" }), nil)
end

T["next_expr_boundary() with boundary 'start' going backwards visits only starts"] = function()
	open_test_buf({
		"abc",
		"",
		"def",
		"",
		"ghi",
	})

	child.fn.cursor(5, 3)

	expect_pos(next_expr_boundary({ direction = -1, boundary = "start" }), { row = 4, col = 0 })
	expect_pos(next_expr_boundary({ direction = -1, boundary = "start" }), { row = 2, col = 0 })
	expect_pos(next_expr_boundary({ direction = -1, boundary = "start" }), { row = 0, col = 0 })
	expect_pos(next_expr_boundary({ direction = -1, boundary = "start" }), nil)
end

T["next_expr_boundary() with current_ok=true returns cursor position when on a boundary"] = function()
	open_test_buf({
		"abc",
		"",
		"def",
	})

	child.fn.cursor(1, 1) -- row=0 col=0, sits on start of "abc"

	-- current_ok=true means the boundary AT the cursor counts as a hit
	expect_pos(next_expr_boundary({ current_ok = true, boundary = "start" }), { row = 0, col = 0 })
end

T["next_expr_boundary() with current_ok=false skips cursor position when on a boundary"] = function()
	open_test_buf({
		"abc",
		"",
		"def",
	})

	child.fn.cursor(1, 1) -- row=0 col=0, sits on start of "abc"

	expect_pos(next_expr_boundary({ boundary = "start" }), { row = 2, col = 0 })
end

T["next_expr_boundary() jumps out of the current expression going forwards"] = function()
	open_test_buf({
		"abcdef",
		"",
		"ghi",
	})

	child.fn.cursor(1, 3) -- middle of "abcdef" (row=0 col=2)

	expect_pos(next_expr_boundary({ boundary = "end" }), { row = 0, col = 5 })
	expect_pos(next_expr_boundary({ boundary = "end" }), { row = 2, col = 2 })
end

T["next_expr_boundary() jumps to start of current expression going backwards"] = function()
	open_test_buf({
		"abcdef",
		"",
		"ghi",
	})

	child.fn.cursor(1, 4) -- middle of "abcdef" (row=0 col=3)

	expect_pos(next_expr_boundary({ direction = -1, boundary = "start" }), { row = 0, col = 0 })
end

T["next_expr_boundary() handles multi-line expressions"] = function()
	-- get_expr overflows through whitespace-adjacent lines, so these
	-- three non-blank lines form one expression.
	open_test_buf({
		"abc",
		"def",
		"ghi",
		"",
		"jkl",
	})

	expect_pos(next_expr_boundary({ boundary = "start" }), { row = 4, col = 0 })

	child.fn.cursor(1, 1)
	expect_pos(next_expr_boundary({ boundary = "end" }), { row = 2, col = 2 })
	expect_pos(next_expr_boundary({ boundary = "end" }), { row = 4, col = 2 })
end

T["next_expr_boundary() returns nil on an empty buffer"] = function()
	open_test_buf({ "" })

	expect_pos(next_expr_boundary({}), nil)
	expect_pos(next_expr_boundary({ direction = -1 }), nil)
	expect_pos(next_expr_boundary({ boundary = "start" }), nil)
	expect_pos(next_expr_boundary({ boundary = "end" }), nil)
end

T["next_expr_boundary() returns nil on a whitespace-only buffer"] = function()
	open_test_buf({ "", "   ", "\t", "" })

	assert(next_expr_boundary({}) == nil, "Expected nil in whitespace-only buffer")
	child.fn.cursor(4, 1)
	assert(next_expr_boundary({ direction = -1 }) == nil, "Expected nil going backwards in whitespace-only buffer")
end

T["next_expr_boundary() returns nil when cursor is past the last expression"] = function()
	open_test_buf({
		"abc",
		"",
		"",
	})

	child.fn.cursor(3, 1)

	expect_pos(next_expr_boundary({}), nil)
	expect_pos(next_expr_boundary({ boundary = "start" }), nil)
	expect_pos(next_expr_boundary({ boundary = "end" }), nil)
end

T["next_expr_boundary() skips over the current expression when cursor is inside it going forwards"] = function()
	open_test_buf({
		"abc",
		"",
		"def",
	})

	child.fn.cursor(1, 2) -- row=0 col=1, inside "abc"

	-- Skipping past the current expr's end lands on the next expr's start
	expect_pos(next_expr_boundary({ boundary = "start" }), { row = 2, col = 0 })
end

return T
