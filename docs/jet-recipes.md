---
title: jet.nvim recipes
filename: jet-recipes.txt
vimdoc-prefix: jet-recipes
---

The following document shows how jet.nvim's Lua API can be used to achieve
cool stuff.

## Execution notifications

Shows a notification when execution requests complete. The notification shows
both the executed code and the result, and only fires if the repl is not
visible.

``` lua
local hooks = require("jet").hooks

local execute_inputs = {}
local execute_results = {}
hooks.on_message_received.notify = function(k, msg)
	-- We only need to handle messages which were originally triggered by an
	-- `execute_request`
	if not (msg.parent_header and msg.parent_header.msg_type == "execute_request") then
		return
	end

	-- When any frontend (not just Neovim) sends an `execute_request`, the
	-- kernel always echoes back the code to be executed in an `execute_input`
	-- message. We listen for such messages and store the parent message id,
	-- i.e. the id of the original `execute_request`.
	-- https://jupyter-client.readthedocs.io/en/latest/messaging.html#execute
	if msg.header.msg_type == "execute_input" then
		execute_inputs[msg.parent_header.msg_id] = msg.content

	-- When we get the final result we store it against the parent message id
	-- in the same way
	elseif msg.header.msg_type == "execute_result" then
		execute_results[msg.parent_header.msg_id] = msg.content

	-- When an execution finishes the kernel reports idle status, so we can
	-- finally report the information we stored in the previous steps.
	elseif msg.header.msg_type == "status" then
		local input = execute_inputs[msg.parent_header.msg_id]
		local result = execute_results[msg.parent_header.msg_id]
		execute_inputs[msg.parent_header.msg_id] = nil
		execute_results[msg.parent_header.msg_id] = nil

		local code = input and input.code
		local text = result and result.data and result.data["text/plain"]
		local term_is_open = k.term and k.term:win()

		if code and text and not term_is_open then
			vim.notify(string.format("Ran `%s`:\nResult: %s", code, text))
		end
	end
end
```

Note: this doesn't report errors or other output types than `text/plain`, but
you can read the Jupyter spec to implement these pretty easily. Or just get AI
to do it for you, I'm not your mum.

## Auto-update repl width

Kernels/languages have different ways of detecting terminal width, and not all
of them work with Jet/Neovim's built-in terminal. Thankfully if you can figure
out how to just tell the kernel when the width changes, jet.nvim makes this
very easy. Here's an example with ipython/pandas:

``` lua
vim.api.nvim_create_autocmd("WinResized", {
	callback = function()
		local wins = vim.v.event.windows --[[@as integer[] ]]
		for _, win in ipairs(wins) do
			local buf = vim.api.nvim_win_get_buf(win)
			local session_id = vim.b[buf].jet and vim.b[buf].jet.session_id
			local kernel = session_id and api.get_kernel_by_id(session_id)
			if kernel and kernel.filetype == "python" then
				local code = string.format(
					"import sys\n"
						.. 'if "pandas" in sys.modules: sys.modules.get("pandas").set_option("display.width", %d)',
					vim.api.nvim_win_get_width(win)
				)
				-- Send 'silently' so the code isn't echoed in the repl
				kernel:send_lua(code, true)
			end
		end
	end,
})
```
