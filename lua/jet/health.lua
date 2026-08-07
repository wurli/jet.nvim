local M = {}

local check_jet_version = function()
	vim.health.start("Jet version")

	local dl = require("jet.core.utils.download")

	local paths = dl.get_jet_paths()

	if paths.bin then
		local check = dl.check_bin_outdated(paths.bin)
		if check.is_outdated then
			vim.health.warn("Jet binary v" .. check.current .. " is less than required v" .. check.required)
		else
			vim.health.ok("Jet binary v" .. check.current .. " is up to date with required v" .. check.required)
		end
	else
		if paths.bin_user then
			vim.health.error("Jet binary not found at user-supplied path: " .. paths.bin_user)
		elseif paths.bin_default then
			vim.health.error("Jet binary not found at path: " .. paths.bin_default)
		else
			vim.health.error("Jet binary not found")
		end
	end

	if paths.lib then
		local check = dl.check_lib_outdated(paths.lib)
		if check.is_outdated then
			vim.health.warn("Jet library v" .. check.current .. " is less than required v" .. check.required)
		else
			vim.health.ok("Jet library v" .. check.current .. " is up to date with required v" .. check.required)
		end
	else
		if paths.lib_user then
			vim.health.error("Jet library not found at user-supplied path: " .. paths.lib_user)
		elseif paths.lib_default then
			vim.health.error("Jet library not found at path: " .. paths.lib_default)
		else
			vim.health.error("Jet library not found")
		end
	end
end

local check_timers = function()
	vim.health.start("Open timers")

	local any_open = false
	for timer, _ in pairs(require("jet.core.utils").open_polls) do
		any_open = true
		vim.health.info(timer)
	end

	if require("jet.core.ui.page").timer:is_active() then
		any_open = true
		vim.health.info(
			string.format("Jet UI page refresh timer (%sms)", require("jet.core.ui.page").timer:get_repeat())
		)
	end

	if not any_open then
		vim.health.ok("No open polls or timers")
	end
end

M.check = function()
	check_jet_version()
	check_timers()
end

return M
