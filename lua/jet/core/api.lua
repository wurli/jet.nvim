local kernel = require("jet.core.kernel")
local utils = require("jet.core.utils")
local manager = require("jet.core.manager")

local M = {}

---@class jet.api.Filters
---@field session_id? string Implies `status` = "connected" or "external"
---@field spec_path? string
---@field filetype? string | boolean `true` gets the filetype at the current position
---@field display_name? string
---@field primary? boolean Implies `status` = "connected"
---@field default? boolean Only gets the default kernel for `filetype` (see `config.default_kernels`)
---@field status? jet.kernel.status | jet.kernel.status[]

---@param kernels jet.Kernel[]
---@param opts? jet.api.Filters
---@return jet.Kernel[]
M.filter_kernels = function(kernels, opts)
	opts = opts or {}
	opts.status = opts.status or { "connecting", "connected", "external", "inactive" }
	opts.status = type(opts.status) == "string" and { opts.status } or opts.status
	if opts.filetype == true then
		opts.filetype = require("jet.core.send.utils").local_lang_info().filetype
	end

	---@param k jet.Kernel
	return vim.tbl_filter(function(k)
		local status, _ = k:status()
		if not vim.tbl_contains(opts.status, status) then
			return false
		end

		if opts.spec_path and k.spec_path ~= opts.spec_path then
			return false
		end

		if opts.display_name and not k.spec.display_name:lower():match(opts.display_name:lower()) then
			return false
		end

		-- implies `status` = "connected" or "external"
		if opts.session_id and k.session_id ~= opts.session_id then
			return false
		end

		if opts.filetype then
			-- filetype is present for connected kernels if added through hooks,
			-- and for other kernels if explicitly configured
			if opts.filetype ~= k.filetype then
				return false
			end

			if opts.default then
				local spec_path = require("jet.core.config").options.default_kernels[opts.filetype]
				if type(spec_path) == "function" then
					spec_path = spec_path()
				end
				if not spec_path or not utils.path_eq((k.spec_path or ""), spec_path) then
					return false
				end
			end
		end

		if
			opts.primary
			and not (k.session_id and vim.tbl_contains(vim.tbl_values(manager.filetype_primary), k.session_id))
		then
			return false
		end

		return true
	end, kernels)
end

---@param filters? jet.api.Filters
---@param callback? fun(kernels: jet.Kernel[])
M.list_kernels = function(filters, callback)
	filters = filters or {}
	filters.status = filters.status or { "connecting", "connected", "external", "inactive" }
	filters.status = type(filters.status) == "string" and { filters.status } or filters.status

	---@type jet.Kernel[]
	local kernels = {}

	if vim.tbl_contains(filters.status, "connected") or vim.tbl_contains(filters.status, "connecting") then
		for _, k in pairs(manager.kernels) do
			table.insert(kernels, k)
		end
	end

	if vim.tbl_contains(filters.status, "inactive") then
		for _, k in ipairs(require("jet.core.engine").list_kernels()) do
			table.insert(kernels, kernel.init_owned({ spec_path = k.path, spec = k.spec }))
		end
	end

	if vim.tbl_contains(filters.status, "external") then
		---@param sessions jet.SessionInfo[]
		local collect = function(sessions)
			for _, session in ipairs(sessions) do
				-- Don't include sessions that are already connected to Neovim
				if not manager.kernels[session.session_id] then
					table.insert(kernels, kernel.init_external({ session_id = session.session_id }))
				end
			end
		end

		local cb = require("jet.core.engine").list_sessions()

		if callback then
			utils.poll(function()
				local res = cb()
				if res.value then
					collect(res.value)
					callback(M.filter_kernels(kernels, filters))
				end
				return res.status
			end, { interval = 20, alias = "Waiting for list_sessions output" })
			return
		else
			while true do
				local res = cb()
				if res.value then
					collect(res.value)
					break
				end
			end
		end
	end

	local out = M.filter_kernels(kernels, filters)

	if callback then
		callback(out)
	else
		return out
	end
end

---@param kernels jet.Kernel[]
---@param msg string
---@param callback fun(k: jet.Kernel)
local select_kernel = function(kernels, msg, callback)
	vim.ui.select(kernels, {
		prompt = msg,
		---@param k jet.Kernel
		format_item = function(k)
			local _, status_icon = k:status()
			return string.format("%s  %s  %s", status_icon, k.spec.display_name, utils.path_shorten(k.spec_path))
		end,
	}, function(choice)
		if choice then
			callback(choice)
		end
	end)
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
M.get = function(filters, callback)
	local choose = function(kernels)
		if #kernels == 1 then
			callback(kernels[1])
		elseif #kernels > 1 then
			select_kernel(kernels, "Select a kernel", callback)
		end
	end

	local get_filters = function(f) return vim.tbl_extend("keep", f, filters) end

	M.list_kernels(get_filters({ status = { "connected", "connecting" } }), function(matches1)
		if #matches1 > 0 then
			choose(matches1)
			return
		end

		M.list_kernels({ status = { "inactive" } }, function(inactive_kernels)
			local matches2 =
				M.filter_kernels(inactive_kernels, get_filters({ status = { "inactive" }, default = true }))
			if #matches2 > 0 then
				choose(matches2)
				return
			end

			local matches3 = M.filter_kernels(inactive_kernels, get_filters({ status = { "inactive" } }))
			if #matches3 > 0 then
				choose(matches3)
				return
			end

			if #inactive_kernels > 0 then
				choose(inactive_kernels)
				return
			end

			-- If we reach this point, there are multiple kernels to choose from.
			M.list_kernels({}, function(kernels) select_kernel(kernels, "Select a kernel", callback) end)
		end)
	end)
end

return M
