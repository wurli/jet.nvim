local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local child = MiniTest.new_child_neovim()

local cf_name = "jet-nvim-test-connection-file.json"
local kernel_systemobj = nil --[[@as vim.SystemObj?]]

local T = new_set({
	hooks = {
		pre_once = function()
			child.restart({ "-u", "scripts/minimal_init.lua" })

			local cwd = vim.fn.getcwd()
			local jupyter_runtime_dir = vim.fs.joinpath(cwd, "connection-files")
			require("jet.core.utils").mkdir(jupyter_runtime_dir)

			child.env.JUPYTER_RUNTIME_DIR = jupyter_runtime_dir
			vim.env.JUPYTER_RUNTIME_DIR = jupyter_runtime_dir

			-- Now JUPYTER_RUNTIME_DIR is set, python -m ipykernel_launcher
			-- will write a connection file to the dir
			local python = vim.fs.joinpath(cwd, ".jet-dev", "venv", "bin", "python")
			kernel_systemobj = vim.system({ python, "-m", "ipykernel_launcher", "-f", cf_name }, function() end)
		end,
		post_once = function()
			if kernel_systemobj then
				kernel_systemobj:kill("sigkill")
			end
			child.stop()
		end,
	},
})

T["Kernels started by non-Jet apps are discoverable via $JUPYTER_RUNTIME_DIR"] = function()
	-- wait as the kernel process might take a sec to start up
	local ok, _connection_files = vim.wait(10000, function()
		local files = child.lua([[
			local kernels = require("jet.api").list_kernels()
			return vim.tbl_map(function(k) return vim.fs.basename(k.connection_file_path or "") end, kernels)
		]])
		return vim.tbl_contains(files, cf_name), files
	end)

	assert(
		ok,
		string.format("Connection file %s not found in $JUPYTER_RUNTIME_DIR %s", cf_name, vim.env.JUPYTER_RUNTIME_DIR)
	)
end

T["Kernels started by non-Jet apps can be interacted with"] = function()
	child.lua(string.format(
		[[
			_G.k = require("jet.api").list_kernels({ id = "%s" })[1]
		]],
		vim.fs.joinpath(vim.env.JUPYTER_RUNTIME_DIR, cf_name)
	))

	local kernel_id = child.lua_get([[_G.k:id()]])
	assert(kernel_id ~= vim.NIL, "Could not get external kernel")

	child.lua([[
		_G.result = nil
		_G.k:start_lua_client(function()
			_G.k:send_lua("99 + 99", false, function(res)
				if res.header.msg_type == "execute_result" then
					result = res
				end
			end)
		end)
	]])

	assert(
		vim.wait(5000, function() return child.lua_get("_G.result") ~= vim.NIL end),
		"Never received execute_result after sending code to external kernel"
	)

	local res = child.lua_get("_G.result") --[[@as jupyter.Msg]]
	local text = res.content and res.content.data and res.content.data["text/plain"]
	assert(
		text and text:match("198"),
		"Kernel did not return the expected response. Actual return value: %s",
		vim.inspect(res)
	)
end

T["jet.nvim UI works with external kernels"] = function()
	child.cmd("Jet")

	local ok, lines = vim.wait(5000, function()
		local ui_lines = child.api.nvim_buf_get_lines(0, 0, -1, false) --[[@as string[] ]]
		for _, l in ipairs(ui_lines) do
			if l:find(cf_name, 0, true) then
				return true, ui_lines
			end
		end
		return false, ui_lines
	end)

	assert(
		ok,
		string.format(
			"Connection file path %s not found in UI lines.\n\nUi lines:\n%s",
			cf_name,
			table.concat(lines --[[@as string[] ]], "\n")
		)
	)
end

return T
