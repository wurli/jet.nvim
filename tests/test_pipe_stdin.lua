local MiniTest = require("mini.test")

local new_set = MiniTest.new_set
local expect = MiniTest.expect

local child = MiniTest.new_child_neovim()

local T = new_set({
	hooks = {
		pre_case = function() child.restart({ "-u", "scripts/minimal_init.lua" }) end,
		post_once = child.stop,
	},
})

T["chansend over plain pipe stdin delivers every line"] = function()
	child.lua([[
			_G.output = {}
			local function collect(_, data, _)
				for _, l in ipairs(data) do table.insert(_G.output, l) end
			end
			_G.job_id = vim.fn.jobstart({ _G.JET_BIN_PATH, "start", "test-kernels/python3/kernel.json" }, {
				on_stdout = collect,
				on_stderr = collect,
			})
		]])

	local job_id = child.lua_get("_G.job_id")
	expect.no_equality(job_id, 0)
	expect.no_equality(job_id, -1)

	vim.wait(3000)

	local marker = "<<<this is the expected output>>>"
	child.fn.chansend(job_id, { "x = 1", "" })
	child.fn.chansend(job_id, { "x = x + 1", "" })
	child.fn.chansend(job_id, { 'print("' .. marker .. ':" + str(x))', "" })

	local needle = marker .. ":2"
	local ok = vim.wait(15000, function()
		for _, line in ipairs(child.lua_get("_G.output")) do
			if line:find(needle, 1, true) then
				return true
			end
		end
		return false
	end, 100)

	if not ok then
		error(
			'jet swallowed chansend lines over pipe stdin.\nexpected "'
				.. needle
				.. '" in stdout.\ngot:\n  '
				.. table.concat(child.lua_get("_G.output"), "\n  ")
		)
	end
end

return T
