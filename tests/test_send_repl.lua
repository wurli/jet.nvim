local MiniTest = require("mini.test")

local new_set = MiniTest.new_set

local child = MiniTest.new_child_neovim()

local T = new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "scripts/minimal_init.lua" })
			child.lua([[require("jet").setup()]])
		end,
		post_once = child.stop,
	},
})

local run_send = function()
	child.lua([[
			local Kernel = require("jet.core.kernel")
			_G.kernel = Kernel.init_owned({ spec_path = "test-kernels/ark/kernel.json", session_name = "minitest" })
			_G.kernel:open_term(function()
				vim.uv.sleep(500)
				_G.kernel:send_repl({ "print('first line')", "print('second line')" })
			end)
		]])

	local TERM_TEXT = [[
		_G.kernel and _G.kernel.term
			and table.concat(vim.api.nvim_buf_get_lines(_G.kernel.term.buf, 0, -1, false), "\n")
			or ""
	]]

	local repl_text = ""
	local ok = vim.wait(4000, function()
		repl_text = child.lua_get(TERM_TEXT)
		return repl_text:find("first line", 1, true) ~= nil and repl_text:find("second line", 1, true) ~= nil
	end, 100)

	if not ok then
		error(
			"send_by_expr dropped lines.\n"
				.. "Expected:\n"
				.. "    'first line' and 'second line' in REPL buffer\n"
				.. "Got:\n"
				.. "    "
				.. vim.trim(repl_text):gsub("\n", "\n    ")
		)
	end
end

T["send_repl with send_by_expr=false delivers every line"] = function()
	child.lua([[ require("jet.core.config").options.send.send_by_expr = false ]])
	run_send()
end

T["send_repl with send_by_expr=true delivers every line"] = function()
	child.lua([[ require("jet.core.config").options.send.send_by_expr = true ]])
	run_send()
end

return T
