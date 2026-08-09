-- Bootstrap for headless mini.test runs. Used both as `-u` for the test
-- runner itself and as `-u` for the child neovim each test spawns (see
-- MiniTest.new_child_neovim). The `cwd` is the repo root in both cases.

vim.cmd([[let &rtp.=','.getcwd()]])

vim.env.JUPYTER_PATH = vim.fn.getcwd() .. "/test-kernels"

-- mini.test setup runs only in the headless runner (no UIs attached).
-- Child instances get a UI and skip this block — they just need the
-- plugin on rtp.
if #vim.api.nvim_list_uis() == 0 then
	vim.opt.runtimepath:prepend("deps/mini.nvim")
	require("mini.test").setup({
		collect = {
			find_files = function() return vim.fn.globpath("tests", "test_*.lua", true, true) end,
		},
		execute = {
			reporter = require("mini.test").gen_reporter.stdout({ quit_on_finish = true }),
		},
	})

	local dl = require("jet.core.utils.download")
	local has_jet = function()
		local paths = dl.get_jet_paths()
		return paths.bin and paths.lib
	end

	if has_jet() then
		return
	end

	dl.download_jet("latest")
	assert(vim.wait(30000, has_jet), "Could not download Jet CLI/lib")

	require("jet").setup({})

	vim.print(dl.get_jet_paths())
	vim.print(dl.check_bin_version())
	vim.print(dl.check_lib_version())
end
