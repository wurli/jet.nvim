local M = {}

---@param args string[]
local parse_args = function(args)
	local out = {}

	for _, arg in ipairs(args) do
		local key, value = arg:match("^(%w+)=(.+)$")
		if key and value then
			out[key] = value
		end
	end

	return out
end

M.setup = function()
	local ui = require("jet.core.ui")
	local manager = require("jet.core.manager")

	vim.api.nvim_create_user_command("Jet", function(opts)
		local args = opts.fargs
		local open = require("jet.core.kernel").term_open

		if #args == 0 then
			return ui.show()
		end

		if args[1] == "open" then
			return manager.get(parse_args(args), open)
		end

		if args[1] == "send" and #args > 1 then
			return manager.get(parse_args(args), function(k) k:send_lua(args[#args], false) end)
		end

		if args[1] == "install" then
			local version = args[2] or "latest"
			return require("jet.core.utils.download").download_jet(version)
		end
	end, {
		desc = "Jet: work with Jupyter kernels",
		nargs = "*",
		complete = function(_, line, _)
			local args = vim.split(line, " +", { trimempty = true })
			if args[1] ~= "Jet" then
				return {}
			end

			if #args == 1 then
				return {
					"open",
					"send",
					"install",
				}
			end
		end,
	})
end

return M
