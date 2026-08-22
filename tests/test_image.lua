local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local child = MiniTest.new_child_neovim()

local T = new_set({
	hooks = {
		pre_case = function() child.restart({ "-u", "scripts/minimal_init.lua" }) end,
		post_once = child.stop,
	},
})

T["Images are produced by jet.nvim"] = function()
	child.lua([[
		_G.k = require("jet.core.kernel").init_owned({ spec_path = "test-kernels/ark/kernel.json" })

		require("jet.core.config").options.hooks.on_image_display_pre.test = function(_, src)
			_G.rendered_image = src
		end

		_G.k:start_lua_client(function(k)
			_G.bla = 123
			k:send_lua("hist(iris$Sepal.Width)")
		end)
	]])

	vim.wait(5000, function() return child.lua_get("_G.rendered_image") ~= vim.NIL end)
	local file = child.lua_get("_G.rendered_image")
	file = file ~= vim.NIL and file or nil
	assert(file, "No image was produced by the kernel")
	assert(vim.uv.fs_stat(tostring(file)), string.format("Reported file %s does not exist", file))
end

return T
