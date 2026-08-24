local MiniTest = require("mini.test")
local child = MiniTest.new_child_neovim()
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
	hooks = {
		pre_case = function() child.restart({ "-u", "scripts/minimal_init.lua" }) end,
		post_once = child.stop,
	},
})

local SPEC = "test-kernels/python3/kernel.json"

local start_kernel = function(name)
	child.lua(([[
		_G.%s = require("jet.core.kernel").init_owned({ spec_path = %q })
		_G.%s:start_lua_client()
	]]):format(name, SPEC, name))

	local predicate = ([[
		_G.%s and _G.%s.client_id and _G.%s.client_id ~= "<pending>"
		and _G.%s.lsp and _G.%s.filetype == "python"
	]]):format(name, name, name, name, name)
	assert(vim.wait(20000, function() return child.lua_get(predicate) end, 100), name .. " did not start")
end

local run_code = function(name, code)
	child.lua(([[ _G.%s:send_lua(%q, true) ]]):format(name, code))
	local predicate = ([[ _G.%s.execution_state == "idle" ]]):format(name)
	assert(vim.wait(10000, function() return child.lua_get(predicate) end, 50), name .. " never returned to idle")
end

local open_python_buf = function()
	child.lua([[
		vim.cmd("enew")
		_G.buf = vim.api.nvim_get_current_buf()
		vim.bo[_G.buf].filetype = "python"
	]])

	assert(
		vim.wait(10000, function()
			return child.lua_get([[
				(function()
					for _, c in ipairs(vim.lsp.get_clients({ bufnr = _G.buf })) do
						if c.name:sub(1,4) == "jet_" then return true end
					end
					return false
				end)()
			]])
		end, 50),
		"No jet_* LSP attached to python buffer"
	)
end

local set_primary = function(name)
	child.lua(([[ require("jet.core.manager"):set_primary(_G.%s) ]]):format(name))
	vim.wait(500)
end

-- Ask every attached jet_* client for completions and return the flat list of labels.
local get_completions = function(prefix)
	child.lua(([[
		_G.labels, _G.pending = {}, 0
		vim.api.nvim_buf_set_lines(_G.buf, 0, -1, false, { %q })
		vim.api.nvim_win_set_cursor(0, { 1, %d })
		local params = vim.lsp.util.make_position_params(0, "utf-16")
		for _, c in ipairs(vim.lsp.get_clients({ bufnr = _G.buf })) do
			if c.name:sub(1,4) == "jet_" then
				_G.pending = _G.pending + 1
				c:request("textDocument/completion", params, function(_err, result)
					for _, it in ipairs((result or {}).items or result or {}) do
						table.insert(_G.labels, it.label)
					end
					_G.pending = _G.pending - 1
				end, _G.buf)
			end
		end
	]]):format(prefix, #prefix))

	vim.wait(3000, function() return child.lua_get("_G.pending == 0") end, 50)
	return child.lua_get("_G.labels")
end

T["completions follow the primary kernel"] = MiniTest.new_set({
	parametrize = {
		{ "k2", "my_second_var", "my_first_var" },
		{ "k1", "my_first_var", "my_second_var" },
	},
})

T["completions follow the primary kernel"]["primary provides completions, others do not"] = function(
	primary,
	expected,
	forbidden
)
	start_kernel("k1")
	run_code("k1", "my_first_var = 1")
	start_kernel("k2")
	run_code("k2", "my_second_var = 2")

	set_primary(primary)
	open_python_buf()

	local labels_expected = get_completions(expected:sub(1, -4)) -- strip "var"
	eq(vim.tbl_contains(labels_expected, expected), true)

	local labels_forbidden = get_completions(forbidden:sub(1, -4))
	eq(vim.tbl_contains(labels_forbidden, forbidden), false)
end

return T
