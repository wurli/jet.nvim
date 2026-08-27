local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local child = MiniTest.new_child_neovim()

local T = new_set({
	hooks = {
		pre_once = function()
			child.restart({ "-u", "scripts/minimal_init.lua" })
			child.lua([[
				_G.k = require("jet.core.kernel").init_owned({ spec_path = "test-kernels/ark/kernel.json" })

				require("jet.core.config").options.hooks.on_image_display_pre.test = function(k, src)
					_G.rendered_image = src
					_G.image_buf = k.img.buf
				end

				_G.k:start_lua_client(function(k)
					_G.bla = 123
					k:send_lua("hist(iris$Sepal.Width)")
				end)
			]])
		end,
		post_once = child.stop,
	},
})

T["Image files are produced"] = function()
	vim.wait(5000, function() return child.lua_get("_G.rendered_image") ~= vim.NIL end)
	local file = child.lua_get("_G.rendered_image")
	file = file ~= vim.NIL and file or nil
	assert(file, "No image was produced by the kernel")
	assert(vim.uv.fs_stat(tostring(file)), string.format("Reported file %s does not exist", file))
end

T["Image buffer is created"] = function()
	local buf_exists = vim.wait(5000, function()
		local buf_session_id = child.lua_get("vim.b[_G.image_buf].jet.session_id")
		return buf_session_id ~= vim.NIL
	end)
	assert(buf_exists, "Image buffer was not created")
end

T["Image buffer is displayed"] = function()
	local buf_visible = vim.wait(5000, function()
		for _, win in ipairs(child.api.nvim_list_wins()) do
			if child.api.nvim_win_get_buf(win) == child.lua_get("_G.image_buf") then
				return true
			end
		end
	end)
	assert(buf_visible, "Image buffer is not visible in any window")
end

return T
