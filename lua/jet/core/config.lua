local M = {}

---@class jet.Config.Ui
local ui_defaults = {
	--- Number of lines from iopub stream to show in `:Jet` ui
	stream_lines = 3,
	--- Control how Jet displays how long stuff is taking:
	--- ``` lua
	--- -- E.g. to display as hours, minutes, or seconds depending on the duration:
	--- require("jet").setup({
	---     time_formatter = function(hh, mm, ss)
	---         if hh > 0 then
	---             return string.format("%.1fh", hh + mm/60 + ss/(60 * 60))
	---         elseif mm > 0 then
	---             return string.format("%.1fm", mm + ss/60)
	---         else
	---             return string.format("%ds", ss)
	---         end
	---     end
	--- })
	--- ```
	time_formatter = nil, ---@type nil | fun(hh: integer, mm: integer, ss: integer): string
	---Seconds to wait before showing a lualine timer for long-running
	---executions; defaults to `30`
	lualine_timer_delay = 30,
	lualine_busy_icon = "󰪥",
	lualine_idle_icon = "",
	lualine_icon_chart = "",
}

---@class jet.Config.Img
local img_defaults = {
	---Some kernels might return media types which require special handling.
	---
	---Handlers should take image data, process it, and write the resulting
	---image to `filepath`. Handlers should return `filepath` on a successful
	---write, or `false` otherwise.
	---
	---E.g. to handle SVG data using `resvg` you could use the following:
	---
	---``` lua
	---handlers = {
	---    svg = function(data, _mime, filepath)
	---        local res = vim.system(
	---            { "resvg", "-", filepath, "--dpi", "500", "-z", "4" },
	---            { stdin = data }
	---        )
	---            :wait()
	---        return res.code == 0 and filepath or false
	---    end,
	---},
	---```
	handlers = {}, ---@type table<string, fun(data: string, mime: jet.Mime, filepath: string): string|false>
}

---@class jet.Config
M.defaults = {
	binary_path = nil, ---@type string? Path to a custom Jet binary.
	library_path = nil, ---@type string? Path to a custom Jet Lua library.
	---Set to `false` to keep the kernel running when the terminal buffer is
	---deleted - see |BufWipeout|.
	stop_on_buf_wipeout = true,
	---Ui config
	---* `send_by_expr`: If `true` (the default) then each expression will
	---  be sent and results shown one at a time. If `false`, then when sending
	---  several complete expressions to the repl in one go, all will be
	---  executed together and results will be emitted after the input code.
	---  * If `true` then the Jet repl is run with `--no-indent`, otherwise
	---    when code is sent it might get double-indented. Not all kernels
	---    provide an indent, and ones that don't are not affected by the
	---    `--no-indent` option, but ipython notably *does* indent. So if you
	---    use `true` you might notice that you no longer get auto-indentation
	---    when writing multiline statements directly in the REPL.
	---  * If `false` then expressions are sent surrounded by 'bracketed paste'
	---    escapes. This currently has a couple of downsides:
	---    * If the kernel is busy when code is sent, the escapes will be
	---      echoed in the REPL, resulting in some visual noise.
	---    * If too much code is sent at once (more than the height of the
	---      screen), it causes the REPL history to be truncated. This is due
	---      to an upstream issue in reedline, which powers the Jet REPL
	---      experience.
	send = {
		send_by_expr = true, ---@type boolean
	},
	--- UI config
	ui = ui_defaults,
	---Image config
	image = img_defaults,
	---Hooks for custom integrations
	hooks = require("jet.core.hooks").init_hooks(),
}

M.jet_nvim_version = "0.0.1"

---@class jet.Config.Data
M.data = {
	jet_min_version = "0.0.8",
	binary_path = nil, ---@type string?
	library_path = nil, ---@type string?
	jet_nvim_data_dir = vim.fn.stdpath("data") .. "/jet",
}

---@type jet.Config
M.options = nil

---Sorry
---@alias jet.DeepPartial<T> { [P in keyof T]?: T[P] extends any[] and T[P] or (T[P] extends table and jet.DeepPartial<T[P]> or T[P]) }

---@param options? jet.DeepPartial<jet.Config>
function M.set(options)
	if options and options.binary_path then
		local bin = vim.fs.abspath(options.binary_path)
		assert(type(bin) == "string" and vim.fn.executable(bin) == 1, "jet_binary must be an executable")
		options.binary_path = bin
	end

	M.options = vim.tbl_deep_extend("force", M.defaults, options or {})

	require("jet.core.utils.download").maybe_download_jet(function(res)
		M.data.binary_path = res.bin_path
		M.data.library_path = res.lib_path
	end)
end

return M
