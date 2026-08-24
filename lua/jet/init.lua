local config = require("jet.core.config")
local manager = require("jet.core.manager")

local M = {}

local jet_quit_augroup = vim.api.nvim_create_augroup("jet.quit", { clear = true })

vim.api.nvim_create_autocmd({ "VimLeave", "UILeave" }, {
	group = jet_quit_augroup,
	callback = function(e)
		for _, kernel in pairs(require("jet.core.manager").kernels) do
			kernel:close(e.event)
		end
	end,
})

-- Jet extensions might want to install custom (nvim specific) kernelspecs.
-- Prepending ~/.local/share/nvim/jet to JUPYTER_PATH means this dir will be
-- seached first when running Jet from nvim - but not in other contexts.
local modify_jupyter_path = function()
	local pathsep = vim.fn.has("win32") == 1 and ";" or ":"
	vim.env.JUPYTER_PATH = table.concat({ config.data.jet_nvim_data_dir, vim.env.JUPYTER_PATH }, pathsep)
end

---@param opts jet.DeepPartial<jet.Config.Opts>
M.setup = function(opts)
	modify_jupyter_path()
	config.set(opts)
	require("jet.core.cmd").setup()
	require("jet.core.ui.colours").setup()
end

---Get a kernel and do some stuff with it
---
---Looks for kernels which match `filters` in the following order:
---1. Connected (or connecting) kernels
---2. Inactive kernels which are marked as 'default'
---3. Other inactive kernels
---
---If any of the above steps match a single kernel it is passed to
---`callback()`. If multiple kernels match, the user is prompted to select one.
---
---@param filters jet.api.Filters
---@param callback fun(k: jet.Kernel)
M.get = function(filters, callback) return manager.get(filters, callback) end

---Get a running kernel by its session id
---
---This can be useful, e.g. if you want to get the running `Kernel` object
---powering the repl:
---
---``` lua
---local jet = require("jet")
---local kernel = jet.get_by_id(vim.b.jet.session_id)
---```
---
---@param session_id string
---@return jet.Kernel?
M.get_by_id = function(session_id) return manager.get_by_id(session_id) end

return M
