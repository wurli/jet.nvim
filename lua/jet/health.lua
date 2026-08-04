local M = {}

local check_polls_and_timers = function()
	vim.health.start("Open polls/timers")

	local any_open = false
	for poller, _ in pairs(require("jet.core.utils").open_polls) do
		any_open = true
		vim.health.info("Open poll: '" .. poller .. "'")
	end

	for timer, _ in pairs(require("jet.core.ui.line").open_timers) do
		any_open = true
		vim.health.info("Open timer: '" .. timer .. "'")
	end

	if not any_open then
		vim.health.ok("No open polls or timers")
	end
end

M.check = function()
	check_polls_and_timers()
	-- More coming soon
end

return M
