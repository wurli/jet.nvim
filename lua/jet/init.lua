local config = require("jet.core.config")

---@class jet.Filetype
---@field get_expr? fun(p: jet.send.Pos): jet.send.Range?

---@class jet
local M = {
	---Filetype extensions. Currently only used to set `get_expr()` for a given
	---filetype.
	---@type table<string, jet.Filetype>
	filetype = {},
}
M.ft = M.filetype

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

return M
