local M = {}

M.time = function(f, name)
	local time = vim.uv.hrtime()
	f()
	print((name or "function") .. " took " .. (vim.uv.hrtime() - time) / 1e9 .. " seconds")
end

local on_key_ns = vim.api.nvim_create_namespace("jet_prompt_yn")
---@param msg string
---@param opts string[]
---@param callback fun(key: string)
M.input_key = function(msg, opts, callback)
	vim.schedule(function()
		local message = { { msg, "Conceal" } }
		table.insert(message, { " (enter " .. table.concat(opts, "/") .. "): " })
		vim.api.nvim_echo(message, false, {})
		vim.on_key(function(key)
			if vim.trim(key) == "" then
				return
			end
			vim.on_key(nil, on_key_ns)
			if vim.tbl_contains(opts, key) then
				vim.api.nvim_echo({ { key, "OkMsg" } }, false, {})
			else
				vim.api.nvim_echo({ { "" } }, false, {})
			end
			callback(key)
			return ""
		end, on_key_ns)
	end)
end

---Returns `true` if version `a` is smaller than `b`, otherwise `false`.
---
---Version numbers are expected to be in the format
---`v?<major>.<minor>.<patch>`, e.g. `v1.2.3` or `1.2.3`.
---
---@param a string
---@param b string
---@return boolean
M.version_compare = function(a, b)
	local a_major, a_minor, a_patch = a:match("^v?(%d+)%.(%d+)%.(%d+)$")
	local b_major, b_minor, b_patch = b:match("^v?(%d+)%.(%d+)%.(%d+)$")

	local va = { maj = tonumber(a_major), min = tonumber(a_minor), patch = tonumber(a_patch) }
	local vb = { maj = tonumber(b_major), min = tonumber(b_minor), patch = tonumber(b_patch) }

	assert(va.maj and va.min and va.patch, "Invalid version number format: " .. a)
	assert(vb.maj and vb.min and vb.patch, "Invalid version number format: " .. b)

	if va.maj ~= vb.maj then
		return va.maj < vb.maj
	elseif va.min ~= vb.min then
		return va.min < vb.min
	else
		return va.patch < vb.patch
	end
end

-- Purely for diagnostic purposes
M.open_polls = {}

---Repeatedly run a callback until a particular result is returned
---
---Opts:
---	- interval: number (default: 50) - polling interval in milliseconds
---	- handler: function(result) - called with the result of the callback, should return
---	    either "exit", "continue", or "wait" to control the polling behavior
---
---@generic T
---@param callback fun(): T
---@param handler fun(res: T): nil | "wait" | "continue" | "exit"
---@param opts? { interval?: integer, alias?: string }
M.poll = function(callback, handler, opts)
	opts = opts or {}
	opts.interval = opts.interval or 50

	if opts.alias then
		opts.alias = opts.alias .. " (every " .. opts.interval .. "ms)"
		M.open_polls[opts.alias] = true
	end

	local function run()
		while true do
			local result = callback()
			local action = handler(result) or "wait"

			if action == "exit" then
				if opts.alias then
					M.open_polls[opts.alias] = nil
				end
				return
			elseif action == "wait" then
				return vim.defer_fn(run, opts.interval or 50)
			---@diagnostic disable-next-line: unnecessary-if
			elseif action ~= "continue" then
				-- If we've got a valid result, process it and then and then
				-- immediately (i.e. with no delay) poll again.
				error(("Unexpected action '%s'"):format(tostring(action)))
			end
		end
	end

	run()
end

local fmt_time_hhmmss = function(hh, mm, ss) return string.format("%02.f:%02.f:%02.f", hh, mm, ss) end

-- local fmt_time_biggest = function(hh, mm, ss)
-- 	if hh > 0 then
-- 		return string.format("%.1fh", (hh * 60 * 60 + mm * 60 + ss) / (60 * 60))
-- 	elseif mm > 0 then
-- 		return string.format("%.1fm", (mm * 60 + ss) / 60)
-- 	else
-- 		return string.format("%ds", ss)
-- 	end
-- end

---Get the elapsed time since `t` as a nicely formatted string
---@param t integer | string
---@param finish? integer | string
---@return string
M.time_since = function(t, finish)
	if type(t) == "string" then
		t = M.parse_timestamp(t)
	end

	finish = finish or os.time()
	if type(finish) == "string" then
		finish = M.parse_timestamp(finish)
	end

	local seconds = math.floor(os.difftime(finish, t))
	local hh, mm, ss = math.floor(seconds / 3600), math.floor((seconds % 3600) / 60), seconds % 60

	local fmt = require("jet.core.config").options.time_formatter or fmt_time_hhmmss

	return fmt(hh, mm, ss)
end

---@param t string E.g. 2026-07-07T20:11:08Z
M.parse_timestamp = function(t)
	local yy, mm, dd, hh, mi, ss = t:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z")
	assert(yy and mm and dd and hh and mi and ss, "Invalid timestamp format: " .. t)

	local os_epoch = os.time({
		year = yy,
		month = mm,
		day = dd,
		hour = hh,
		min = mi,
		sec = ss,
		isdst = false,
	})

	-- os_epoch uses the OS timezone, so we need to adjust it to UTC.
	local utc = os.date("!*t", os_epoch)
	utc.isdst = false -- Ensure that daylight saving time is not applied
	local offset = os.difftime(os_epoch, os.time(utc)) --[[@as integer]]

	return os_epoch + offset
end

---``` lua
---for s, e in gfind("Hello, world!", "He(ll)o") do
---  vim.print({ s, e }) -- prints 5 5 and then 8 8
---end
---```
M.gfind = function(text, pattern)
	local start = 1
	---@return integer?, integer?
	return function()
		local s, e = text:find(pattern, start)
		if s then
			start = e + 1
			return s, e
		end
	end
end

---Attempts to shorten a path by either using `~` for the home directory
---or `.` for the current working directory.
---
---@param path string
---@return string
M.path_shorten = function(path) return vim.fn.simplify(vim.fn.fnamemodify(path, ":~:.")) end

M.path_normalise = function(path) return vim.fs.abspath(vim.fs.normalize(path)) end

---@param x string
---@param y string
---@return boolean
M.path_eq = function(x, y) return M.path_normalise(x) == M.path_normalise(y) end

---@return string[]
M.get_all_filetypes = function() return vim.fn.getcompletion("", "filetype") end

M.log_debug = function(msg, ...) vim.notify("[jet] " .. msg:format(...), vim.log.levels.DEBUG, {}) end
M.log_error = function(msg, ...) vim.notify("[jet] " .. msg:format(...), vim.log.levels.ERROR, {}) end
M.log_info = function(msg, ...) vim.notify("[jet] " .. msg:format(...), vim.log.levels.INFO, {}) end
M.log_off = function(msg, ...) vim.notify("[jet] " .. msg:format(...), vim.log.levels.OFF, {}) end
M.log_trace = function(msg, ...) vim.notify("[jet] " .. msg:format(...), vim.log.levels.TRACE, {}) end
M.log_warn = function(msg, ...) vim.notify("[jet] " .. msg:format(...), vim.log.levels.WARN, {}) end

return M
