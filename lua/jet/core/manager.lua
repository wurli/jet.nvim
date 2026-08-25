local utils = require("jet.core.utils")

---@class jet.Manager
---@field kernels table<string, jet.Kernel>
---@field filetype_primary table<string, string> key=filetype, value=session_id
local Manager = {
	kernels = {},
	filetype_primary = {},
}

---@param k jet.Kernel
function Manager:insert(k)
	assert(not self.kernels[k.session_id], "Kernel with session_id " .. k.session_id .. " already exists")
	self.kernels[k.session_id] = k
end

---Also activates the kernel LSP and disables any other active Jet LSP for the
---same filetype.
---
---@param k jet.Kernel
function Manager:set_primary(k)
	print("setting primary kernel")
	assert(k.session_id, "Kernel must have a session_id")
	assert(k.filetype, "Kernel must have a filetype")

	local prev_primary = self.filetype_primary[k.filetype]

	self.kernels[k.session_id] = k
	self.filetype_primary[k.filetype] = k.session_id

	if prev_primary ~= k.session_id then
		local h = require("jet.core.hooks")
		if prev_primary and self.kernels[prev_primary] then
			h.do_primary_status_changed(self.kernels[prev_primary], false)
		end
		h.do_primary_status_changed(k, true)
	end

	-- We only want one active Jet LSP per filetype
	for _, ki in pairs(self.kernels) do
		if ki ~= k and ki.filetype == k.filetype and ki.lsp then
			ki.lsp:disable()
		end
	end

	if k.lsp then
		k.lsp:enable()
	end
end

---@class jet.api.Filters
---@field session_id? string Implies `status` = "connected" or "external"
---@field spec_path? string
---@field filetype? string | boolean `true` gets the filetype at the cursor position
---@field ft? string | boolean alias for `filetype`
---@field display_name? string
---@field primary? boolean Implies `status` = "connected"
---@field default? boolean Only gets the default kernel for `filetype` (see `config.default_kernels`)
---@field status? jet.kernel.status | jet.kernel.status[]

---@param kernels jet.Kernel[]
---@param opts? jet.api.Filters
---@return jet.Kernel[]
Manager.filter_kernels = function(kernels, opts)
	opts = opts or {}
	opts.filetype = opts.filetype or opts.ft
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
			and not (k.session_id and vim.tbl_contains(vim.tbl_values(Manager.filetype_primary), k.session_id))
		then
			return false
		end

		return true
	end, kernels)
end

---@param filters? jet.api.Filters
---@param callback? fun(kernels: jet.Kernel[])
Manager.list = function(filters, callback)
	filters = filters or {}
	filters.status = filters.status or { "connecting", "connected", "external", "inactive" }
	filters.status = type(filters.status) == "string" and { filters.status } or filters.status

	---@type jet.Kernel[]
	local kernels = {}

	if vim.tbl_contains(filters.status, "connected") or vim.tbl_contains(filters.status, "connecting") then
		for _, k in pairs(Manager.kernels) do
			table.insert(kernels, k)
		end
	end

	if vim.tbl_contains(filters.status, "inactive") then
		for _, k in ipairs(require("jet.core.engine").list_kernels()) do
			table.insert(kernels, require("jet.core.kernel").init_owned({ spec_path = k.path, spec = k.spec }))
		end
	end

	if vim.tbl_contains(filters.status, "external") then
		---@param sessions jet.SessionInfo[]
		local collect = function(sessions)
			for _, session in ipairs(sessions) do
				-- Don't include sessions that are already connected to Neovim
				if not Manager.kernels[session.session_id] then
					table.insert(kernels, require("jet.core.kernel").init_external({ session_id = session.session_id }))
				end
			end
		end

		local cb = require("jet.core.engine").list_sessions()

		if callback then
			utils.poll(function()
				local res = cb()
				if res.value then
					collect(res.value)
					callback(Manager.filter_kernels(kernels, filters))
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

	local out = Manager.filter_kernels(kernels, filters)

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

---See `jet/init.lua` for docs.
---@param session_id string
---@return jet.Kernel?
Manager.get_by_id = function(session_id)
	assert(type(session_id) == "string", "'session_id' must be a string")
	return Manager.kernels[session_id]
end

---See `jet/init.lua` for docs.
---@param filters jet.api.Filters
---@param callback fun(k: jet.Kernel)
Manager.get = function(filters, callback)
	local choose = function(kernels)
		if #kernels == 1 then
			callback(kernels[1])
		elseif #kernels > 1 then
			select_kernel(kernels, "Select a kernel", callback)
		end
	end

	local get_filters = function(f) return vim.tbl_extend("keep", f, filters) end

	Manager.list(get_filters({ status = { "connected", "connecting" } }), function(matches1)
		if #matches1 > 0 then
			choose(matches1)
			return
		end

		Manager.list(get_filters({ status = { "inactive" } }), function(inactive_kernels)
			local matches2 =
				Manager.filter_kernels(inactive_kernels, get_filters({ status = { "inactive" }, default = true }))
			if #matches2 > 0 then
				choose(matches2)
				return
			end

			local matches3 = Manager.filter_kernels(inactive_kernels, get_filters({ status = { "inactive" } }))
			if #matches3 > 0 then
				choose(matches3)
				return
			end

			if #inactive_kernels > 0 then
				choose(inactive_kernels)
				return
			end
		end)
	end)
end

return Manager
