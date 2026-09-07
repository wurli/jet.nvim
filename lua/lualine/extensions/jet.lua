local icons = {
	jet = "",
	busy = "󰪥",
	idle = "",
	chart = "",
}

local M = {}

local jet_filename = function()
	local file = vim.api.nvim_buf_get_name(0)
	return icons.jet .. " " .. vim.fs.basename(file)
end

---@param k jet.Kernel
local jet_execution = function(k)
	local last_execution = k and k.last_execution

	local cfg = require("jet.core.config").options

	if (not last_execution) or last_execution.end_time then
		return "%$JetIdle$" .. (cfg.ui.lualine_idle_icon or icons.idle)
	end

	-- Don't show the timer before 30 seconds have elapsed
	local timer_delay = cfg.ui.lualine_timer_delay or 30

	local elapsed = os.time() - last_execution.start_time
	local jet_runtime_text = ""
	if elapsed >= timer_delay then
		local hrs, mins, secs = math.floor(elapsed / 3600), math.floor((elapsed % 3600) / 60), elapsed % 60
		if hrs > 0 then
			jet_runtime_text = string.format("(%02.f:%02.f:%02.f) ", hrs, mins, secs)
		else
			jet_runtime_text = string.format("(%02.f:%02.f) ", mins, secs)
		end
	end

	return jet_runtime_text .. "%$JetBusy$" .. (cfg.ui.lualine_busy_icon or icons.busy)
end

---@param k jet.Kernel
local jet_img = function(k)
	if not k.img then
		return ""
	end

	local files, curr_file_index = k.img:list_files()

	if not curr_file_index then
		return ""
	end

	local cfg = require("jet.core.config").options
	return string.format("%s %d/%d", cfg.ui.lualine_icon_chart or icons.chart, curr_file_index, #files)
end

local jet_details = function()
	local session_id = vim.b.jet and vim.b.jet.session_id
	local k = session_id and require("jet.api").get_kernel_by_id(session_id)

	if not k then
		return ""
	end

	if vim.bo.filetype == "jetrepl" then
		return jet_execution(k)
	elseif vim.bo.filetype == "jetimg" then
		return jet_img(k)
	else
		return "" --Shouldn't happen
	end
end

M.filetypes = { "jetrepl", "jetimg" }

M.sections = {
	lualine_a = { jet_filename },
	lualine_z = { jet_details },
}

return M
