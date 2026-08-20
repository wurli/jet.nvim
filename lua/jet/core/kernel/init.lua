local manager = require("jet.core.manager")
local config = require("jet.core.config")
local utils = require("jet.core.utils")
local hooks = require("jet.core.hooks")

local STARTING_KERNEL_SENTINEL = "<pending>"

---@alias jet.kernel.last_execution { start_time: integer, end_time?: integer, code: string?, is_error?: boolean, count: integer }
---@alias jet.kernel.paritalspec { display_name: string, language: string }
---@alias jet.kernel.execution_state "busy" | "idle" | "starting"

---The `Kernel` class is jet.nvim's central abstraction for working with
---Jupyter kernels using Jet. You can create a new instance using two
---methods
---
---1. To start a fresh session:
---   ``` lua
---   local owned = Kernel.init_owned({ spec_path = "path/to/spec/kernel.json" })
---   owned:start_lua_client()
---   ```
---2. To connect to a session running externally:
---   ``` lua
---   local external = Kernel.init_external({ session_id = "jet-session-id" })
---   external:start_lua_client()
---   ```
---@class jet.Kernel
---@field session_name? string
---@field spec jupyter.KernelSpec | jet.kernel.paritalspec
---@field spec_path string
---@field kernel_info? jupyter.KernelInfo
---@field session_id? string
---@field session_info? jet.SessionInfo
---@field client_id? string
---@field lsp_port? integer
---@field term? jet.Kernel.Term
---@field img? jet.Kernel.Img
---@field cmd string[]
---@field owned boolean
---@field filetype? string
---@field last_execution? jet.kernel.last_execution
---@field execution_state? jet.kernel.execution_state
---@field ui_expand boolean
---@field comms table<string, string> comm_name -> id
---@field output_stream { complete_lines: jet.utils.Queue<string>, incomplete_line: string }
---@field on_message_received table<string, fun(k: jet.Kernel, msg: jupyter.Msg)>
---@field on_started table<string, fun(k: jet.Kernel)>
---@field metadata table<string, any> Arbitrary data, e.g. for use by extensions
---@field stream jet.callback<jupyter.Msg>
---@field private augroup? integer
local Kernel = {}
Kernel.__index = Kernel ---@private

---@return Partial<jet.Kernel>
local init_defaults = function()
	local queue = require("jet.core.utils.queue")
	return {
		comms = {},
		ui_expand = false,
		output_stream = {
			complete_lines = queue.new(config.options.ui.stream_lines, {}),
			incomplete_line = "",
		},
		on_message_received = {},
		on_started = {},
		metadata = {},
	}
end

---@class jet.kernel.init_owned.Opts
---@field spec_path string
---@field session_name? string
---@field spec? jupyter.KernelSpec | jet.kernel.paritalspec

---Represents a kernel which is not active. Turn it into an 'owned'/connected
---kernel using `Kernel:start_lua_client()` or `Kernel:open_term()`.
---
---@param opts jet.kernel.init_owned.Opts
function Kernel.init_owned(opts)
	if not opts.spec then
		opts.spec = require("jet.core.engine").show_spec(opts.spec_path)
	end

	local out = setmetatable(vim.tbl_extend("force", opts, init_defaults(), { owned = true }), Kernel)
	out:try_resolve_filetype()

	hooks.kernel_init(out)

	return out
end

---@class jet.kernel.init_external.Opts
---@field session_id string

---Initialise a connection to an kernel running externally
---
---opts:
---- `session_id`: The session ID of the kernel to connect to
---
---@param opts jet.kernel.init_external.Opts
---@return jet.Kernel
function Kernel.init_external(opts)
	---@diagnostic disable-next-line: unnecessary-assert
	assert(opts.session_id, "Kernel session ID is not set")
	local view = require("jet.core.engine").show_session(opts.session_id)

	local out = setmetatable(
		vim.tbl_extend("force", init_defaults(), {
			session_id = opts.session_id,
			spec = view.spec,
			spec_path = view.session.kernelspec_path,
			session_info = view.session,
			owned = false,
		}),
		Kernel
	)

	manager:insert(out)
	Kernel.try_resolve_filetype(out)

	hooks.kernel_init(out)

	return out
end

---Toggle the terminal window for the kernel.
---If no terminal is active, one will be created and opened.
function Kernel:term_toggle()
	if self.term then
		self.term:toggle()
	else
		self:term_open()
	end
end

local jet_hl_ns = vim.api.nvim_create_namespace("jet_highlights")
vim.api.nvim_set_hl(jet_hl_ns, "Normal", { link = "JetRepl" })

---Open a terminal window for the kernel.
---If no terminal is active, one will be created and opened
---@param callback? fun(t: jet.Kernel.Term)
---@param focus? boolean
function Kernel:term_open(callback, focus)
	self:term_create(function()
		assert(self.term, "kernel.term is nil")
		self.term:open(focus)
		if callback then
			callback(self.term)
		end
	end)
end

---Connect a Jet repl using nvim's built-in terminal.
---Internally uses `jet attach` to connect to a session started using the
---Lua API.
---@private
---@param callback? fun(k: jet.Kernel)
function Kernel:term_create(callback)
	self:start_lua_client(function()
		if not self.term then
			assert(self.session_id, "Kernel has no session id")
			self.term = require("jet.core.kernel.term").init({
				session_id = self.session_id,
				display_name = self.spec.display_name,
				ns = jet_hl_ns,
			})
			self.term:create_autocmd("TermEnter", function() self:set_as_filetype_primary() end)
			if config.options.stop_on_buf_wipeout then
				self.term:create_autocmd("BufWipeout", function() self:close("BufWipeout") end)
			end
		end
		if callback then
			callback(self)
		end
	end)
end

---@alias jet.kernel.status "connecting" | "connected" | "external" | "inactive"

---@return jet.kernel.status, string
function Kernel:status()
	if self.client_id == STARTING_KERNEL_SENTINEL then
		return "connecting", "󰪤 "
	elseif self.client_id then
		return "connected", "󰪥 "
	elseif self.session_id then
		return "external", "󰺕 "
	else
		return "inactive", " "
	end
end

---Set the kernel as the 'primary' kernel for its filetype. No-op if the kernel
---has no filetype.
function Kernel:set_as_filetype_primary()
	if not self.filetype then
		return
	end

	manager.filetype_primary[self.filetype] = self.session_id
end

---@param s string
---@return string
local strip_escapes = function(s)
	local res = s:gsub("\x1b%[[0-9;]*m", "")
	return res
end

---@param s string
split = function(s, trim) return vim.split(s, "[\n\r]", { plain = false, trimempty = trim }) end

---@private
---@param msg jupyter.Msg
function Kernel:update_output_stream(msg)
	local flush = function(allow_empty)
		if allow_empty or self.output_stream.incomplete_line ~= "" then
			self.output_stream.complete_lines:append(self.output_stream.incomplete_line)
			self.output_stream.incomplete_line = ""
		end
	end

	---@param text string
	local append = function(text)
		self.output_stream.incomplete_line = self.output_stream.incomplete_line .. strip_escapes(text)
	end

	if msg.channel == "shell" and msg.header.msg_type == "kernel_info_reply" and msg.content and msg.content.banner then
		flush()
		for _, l in ipairs(split(vim.trim(msg.content.banner), false)) do
			append(l)
			flush(true)
		end
	end

	if msg.channel ~= "iopub" then
		return
	end

	if msg.header.msg_type == "stream" and msg.content.text then
		for i, line_part in ipairs(split(msg.content.text, false)) do
			-- The first item may be a continuation of a previous partial line. Subsequent parts
			-- always begin new lines (but don't necessarily finish them)
			if i > 1 then
				flush()
			end
			append(line_part)
		end
	end

	if msg.header.msg_type == "status" and msg.content.execution_state == "idle" then
		flush()
	end

	if msg.header.msg_type == "execute_result" then
		flush()
		for _, l in ipairs(split(msg.content.data["text/plain"], true)) do
			append(l)
			flush()
		end
	end

	if msg.header.msg_type == "error" then
		local ename = msg.content.ename and msg.content.ename ~= "" and split(msg.content.ename, false) or {}
		local evalue = msg.content.evalue and msg.content.evalue ~= "" and split(msg.content.evalue or "", false) or {}
		local trace = {} --[[@as string[] ]]

		for _, chunk in ipairs(msg.content.traceback or {}) do
			for _, line in ipairs(split(chunk, false)) do
				table.insert(trace, line)
			end
		end

		local has_trace = #trace > 0
		local has_ename = #ename > 0
		local has_evalue = #evalue > 0

		local lines = {}

		-- Yeah I know.
		-- Reasoning: https://github.com/wurli/jet/blob/6e0ee17e3ad75be80d0ae6224466332d8601b930/crates/core/src/events.rs#L189-L233
		if has_trace and has_ename and has_evalue then
			lines = trace
		elseif has_trace and has_evalue then
			if vim.startswith(trace[1] or "", evalue[1] or "") then
				lines = trace
			else
				lines = vim.list_extend({ evalue }, trace)
			end
		elseif has_ename and has_evalue then
			lines = ename
			for i, line in ipairs(evalue) do
				if i == 1 then
					lines[#lines] = lines[#lines] .. ": " .. line
				else
					table.insert(lines, line)
				end
			end
		elseif has_evalue then
			lines = evalue
		end

		flush()
		for _, l in ipairs(lines) do
			append(l)
			flush()
		end
	end
end

---@private
---@return boolean
function Kernel:has_lua_client() return self.client_id ~= nil end

local last_execute_id = ""

---@private
---@param msg jupyter.Msg
function Kernel:update_execution_state(msg)
	local header = msg.header
	local parent = msg.parent_header or {}

	-- Execution is only officially started once we receive "busy" status,
	-- so for now just save the executed code so we can include it when do
	-- get the "busy" status.
	if header.msg_type == "execute_input" and parent.msg_id == last_execute_id and self.last_execution then
		self.last_execution.code = msg.content.code
		self.last_execution.count = msg.content.execution_count
		return
	end

	if header.msg_type == "error" and parent.msg_id == last_execute_id and self.last_execution then
		self.last_execution.is_error = true
		return
	end

	if header.msg_type ~= "status" then
		return
	end
	local new_state = msg.content and msg.content.execution_state
	if not vim.tbl_contains({ "idle", "busy", "starting" }, new_state) then
		utils.log_warn("Kernel '%s' sent unknown execution state: %s", self.spec.display_name, new_state)
		return
	end

	self.execution_state = new_state

	if new_state == "busy" and parent.msg_type == "execute_request" then
		last_execute_id = parent.msg_id or last_execute_id
		local count = self.last_execution and self.last_execution.count or 0
		self.last_execution = { start_time = os.time(), count = count + 1 }
	elseif new_state == "idle" and parent.msg_id == last_execute_id and self.last_execution then
		self.last_execution.end_time = os.time()
	end

	if self.term and self.term.buf and vim.api.nvim_buf_is_valid(self.term.buf) then
		local jet_b = vim.b[self.term.buf].jet or {}
		jet_b.execution_state = self.execution_state
		jet_b.last_execution = self.last_execution
		vim.b[self.term.buf].jet = jet_b
		vim.api.nvim__redraw({ statusline = true, buf = self.term.buf })
	end

	hooks.execution_state_changed(self, new_state)
end

function Kernel:image_dir()
	assert(self.session_id, "Kernel has no session id")
	local dir = vim.fn.stdpath("data") .. "/images/" .. self.session_id
	utils.mkdir(dir)
	return dir
end

function Kernel:open_images()
	if not self.img then
		assert(self.session_id, "Kernel has no session id")
		self.img = require("jet.core.kernel.img").init({
			session_id = self.session_id,
			img_dir = self:image_dir(),
			display_name = self.spec.display_name,
			ns = jet_hl_ns,
		})
	end
	self.img:open(false)
end

---@private
---@param msg jupyter.Msg
function Kernel:handle_image_msg(msg)
	local img_messages = { display_data = true, execute_result = true } ---@type table<jupyter.msg_type, boolean>
	local data = msg.channel == "iopub" and img_messages[msg.header.msg_type] and msg.content and msg.content.data

	if not data then
		return
	end

	for mime_text, content in pairs(data) do
		local mime = utils.parse_mime(mime_text)
		if mime and mime.type == "image" then
			local filepath =
				string.format("%s/%s_%s.png", self:image_dir(), vim.fn.strftime("%Y%m%d_%H%M%S"), msg.header.msg_id)
			if require("jet.core.image").base64_to_file(content, mime, filepath) then
				self:open_images()
				assert(self.img):display()
			end
		end
	end
end

---@param msg jupyter.Msg
function Kernel:handle_input_request(msg)
	if msg.header.msg_type ~= "input_request" then
		return
	end

	if not msg.parent_header then
		utils.log_warn(
			"Received an input_request message without a parent_header from kernel '%s'",
			self.spec.display_name
		)
		return
	end

	assert(self.client_id, "Kernel has no client id")

	local prompt = msg.content.prompt or ""
	-- local password = msg.content.password or false

	vim.schedule(function()
		vim.ui.input(
			{ prompt = string.format("[%s] %s", self.spec.display_name, prompt) },
			function(input)
				require("jet.core.engine").provide_stdin(self.client_id, msg.parent_header.msg_id, input or "")
			end
		)
	end)
end

---@private
function Kernel:handle_stream()
	utils.poll(function()
		local res = self.stream()
		local msg = res.value

		if msg then
			self:update_execution_state(msg)
			self:update_output_stream(msg)
			self:handle_image_msg(msg)
			self:handle_input_request(msg)

			hooks.message_received(self, msg)
			for _, hook in pairs(self.on_message_received) do
				hook(self, msg)
			end
		end

		return res.status
	end, { alias = "Watch for kernel stream messages " .. self.session_id })
end

---@private
function Kernel:register_lsp_client()
	if not self.filetype then
		return
	end

	assert(self.lsp_port, "Kernel has no lsp port")
	assert(self.client_id, "Kernel has no client id")
	---@diagnostic disable-next-line: unnecessary-assert
	assert(self.spec and self.spec.display_name, "Kernel has no display name")

	local clean_name = self.spec.display_name:gsub("%W", "_"):gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", "")
	self.lsp_name = "jet_" .. clean_name .. "_" .. self.client_id

	local capabilities = vim.lsp.protocol.make_client_capabilities()

	vim.lsp.config(self.lsp_name, {
		cmd = vim.lsp.rpc.connect("127.0.0.1", self.lsp_port),
		root_markers = { ".git" },
		filetypes = { self.filetype },
		root_dir = ".",
		capabilities = {
			general = capabilities.general,
			textDocument = {
				completion = (capabilities.textDocument or {}).completion,
				-- hover = {
				-- 	dynamicRegistration = true,
				-- 	contentFormat = { constants.MarkupKind.Markdown, constants.MarkupKind.PlainText },
				-- },
			},
		},
	})

	vim.lsp.enable(self.lsp_name)
end

---Connect to a real kernel instance using the Jet Lua client.
---
---When a kernel is opened, the Lua client starts first, possibly starting a
---new kernel session. The terminal starts afterwards by attaching to the
---(possibly freshly started) kernel session.
---
---@param callback? fun(k: jet.Kernel)
function Kernel:start_lua_client(callback)
	if self:status() == "connected" then
		if callback then
			callback(self)
		end
		return
	end

	table.insert(self.on_started, callback)

	if self:status() == "connecting" then
		return
	end

	utils.log_info("Starting kernel '%s'", utils.path_shorten(self.spec_path))

	local cb
	if self.owned then
		---@diagnostic disable-next-line: unnecessary-assert
		assert(self.spec_path, "Kernel spec_path is not set")
		cb, self.session_info = require("jet.core.engine").start(self.spec_path, nil)

		assert(self.session_info, "Kernel did not return session info")
		self.session_id = self.session_info.session_id
		manager:insert(self)

		self.client_id = STARTING_KERNEL_SENTINEL

		hooks.status_changed(self)

		---@diagnostic disable-next-line: unnecessary-assert
		assert(self.session_id, "Kernel did not return a session id")
	else
		assert(self.session_id, "Kernel session_id is not set")
		cb, self.session_info = require("jet.core.engine").attach(self.session_id, nil)
	end

	self.augroup = vim.api.nvim_create_augroup("jet-" .. self.session_id, { clear = true })

	--TODO: stop poll on kernel close
	utils.poll(function()
		local ok, res = pcall(cb)

		if not ok then
			utils.log_error(
				"Failed to start kernel '%s': %s",
				self.spec.display_name,
				vim.split(tostring(res), "\n")[1]
			)
			if self.session_id then
				self:close("Failed to start kernel: " .. tostring(res))
			end
			return "done"
		end

		local val = res.value

		if val then
			utils.log_info("Started kernel '%s' (%s)", self.spec.display_name, self.session_id)

			self.lsp_port = val.lsp_port
			self.client_id = val.client_id
			self.kernel_info = val.kernel_info
			self.stream = val.stream

			-- Try resolving filetype after kernel started autocmd so the user
			-- has a chance to override it.
			self:try_resolve_filetype()

			-- Even though the kernel has not yet been shown in a REPL, if
			-- there isn't another kernel for this filetype already set as
			-- primary we should set this one for convenience.
			if self.filetype and not manager.filetype_primary[self.filetype] then
				self:set_as_filetype_primary()
			end

			self:handle_stream()
			self:register_lsp_client()

			hooks.lua_client_start(self)
			hooks.status_changed(self)

			for _, on_started_callback in pairs(self.on_started) do
				on_started_callback(self)
			end
		end

		return res.status
	end, { interval = 30, alias = "Wait for kernel startup reply " .. self.session_id })
end

---Can only be done after the kernel is connected and we have the kernel info,
---since we need the file extension to resolve the filetype (kernelspec has
---language, but this is not the same).
---
---@private
function Kernel:try_resolve_filetype()
	if self.filetype then
		return
	end
	local shorten = require("jet.core.utils").path_shorten
	for ft, default_spec in pairs(config.options.default_kernels) do
		local s = type(default_spec) == "string" and default_spec or default_spec()
		if s and shorten(s) == shorten(self.spec_path) then
			self.filetype = ft
			return
		end
	end

	if self.kernel_info then
		---@diagnostic disable-next-line: unnecessary-if
		if self.kernel_info.language_info and self.kernel_info.language_info.file_extension then
			local ft, _, is_fallback = vim.filetype.match({
				-- Idk if 'dummy-file' is ever gonna make a difference, felt right tho
				filename = "dummy-file" .. self.kernel_info.language_info.file_extension,
			})
			if ft and not is_fallback then
				self.filetype = ft
			end
		else
			--TODO: advertise autocmd help page as a way to override this!
			utils.log_warn("Could not resolve filetype for kernel '%s'.", self.spec.display_name, self.session_id)
		end
	end
end

---Shut down the kernel and clean up any associated resources.
---
---If the kernel is `owned` it will be stopped, otherwise it will just be
---disconnected.
---
---@param reason? boolean | string
function Kernel:close(reason)
	assert(self.session_id, "Kernel has no session id")

	manager.kernels[self.session_id] = nil
	for ft, session_id in pairs(manager.filetype_primary) do
		if session_id == self.session_id then
			manager.filetype_primary[ft] = nil
		end
	end

	if self.augroup then
		pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
	end
	if self.term then
		self.term:delete()
	end

	if self.owned then
		self:stop(function(success, failure_msg)
			if not success then
				utils.log_error("Failed to stop kernel '%s': %s", self.spec.display_name, failure_msg)
				return
			end
			if reason ~= false then
				reason = reason and string.format(" (%s)", reason) or ""
				utils.log_info("Stopped kernel '%s'%s", self.spec.display_name, reason)
			end
			hooks.kernel_close(self)
			hooks.status_changed(self)
		end)
		return
	end

	hooks.status_changed(self)
end

---Stop the kernel if it is owned
---
---This function is lower level than |Kernel:close()| and does not clean up any
---resources on the nvim side.
---
---@param callback fun(success: boolean, failure_msg?: string)
---@see |Kernel:close|
function Kernel:stop(callback)
	if not self.session_id then
		return
	end

	local cb = require("jet.core.engine").stop(self.session_id)
	utils.poll(function()
		local res = cb()
		if res.value then
			self.client_id = nil
			self.session_id = nil
			callback(res.value.success, res.value.failure_msg)
		end
		return res.status
	end, { alias = "Waiting for kernel stop response " .. self.session_id })
end

---@class jet.kernel.comm_open.Opts
---@field listener? fun(res: jupyter.Msg)
---@field listener_interval? integer In milliseconds, default 50ms

---Open a comm channel to the kernel
---
---Kernels may implement custom messages using comm channels. This function
---can be used to open a comm channel to the kernel.
---
---If you're using this you should probably be writing an extension for
---jet.nvim!
---
---@param name string
---@param data? table
---@param opts? jet.kernel.comm_open.Opts
---@return string # Comm id
---@return string # Message id
---@see |Kernel:comm_send()|
---@see https://jupyter-client.readthedocs.io/en/latest/messaging.html#custom-messages
function Kernel:comm_open(name, data, opts)
	assert(self.client_id, "Kernel has no client id")
	local _cb, comm_id, msg_id = require("jet.core.engine").comm_open(self.client_id, name, data or {})

	self.comms[name] = comm_id

	opts = opts or {}

	if opts.listener then
		local get_comm_msg = require("jet.core.engine").comm_listen(self.client_id, comm_id)

		utils.poll(function()
			local res = get_comm_msg()
			if res.value then
				opts.listener(res.value)
			end
			return res.status
		end, { interval = opts.listener_interval, "Waiting for comm open reply " .. self.session_id })
	end

	return comm_id, msg_id
end

---Send a message via a comm channel
---
---@param comm_id string
---@param data table
---@return string # Message id
---@see |Kernel:comm_open()|
function Kernel:comm_send(comm_id, data)
	assert(self.client_id)
	local _cb, msg_id = require("jet.core.engine").comm_send(self.client_id, comm_id, data)
	return msg_id
end

---Send code to the kernel via the terminal repl
---
---@param code string | string[] Code to be sent
---@param tabstop? integer Optional; number of spaces to use for tab characters
function Kernel:send_repl(code, tabstop)
	self:term_open(function(t)
		t:send(code, tabstop, function(lines) hooks.send_pre(self, lines) end)
	end, false)
end

---Send code to the kernel via the Lua client
---
---This is a little more efficient than |Kernel:send_repl()| since it doesn't
---have to go through the terminal, but any resulting input requests will not
---be sent to the terminal.
---
---@param code string | string[]
---@param silent boolean
---@param callback? fun(res: jupyter.Msg)
---@return string # Message id
function Kernel:send_lua(code, silent, callback)
	assert(self.client_id, "Kernel has no client id")
	if type(code) == "table" then
		code = table.concat(code, "\n")
	end
	local responder, msg_id = require("jet.core.engine").execute_code(self.client_id, code, silent, true, {})

	if callback then
		utils.poll(function()
			local res = responder()
			if res.value then
				callback(res.value)
			end
			return res.status
		end, { interval = 30, alias = "Wait for execute_code response: " .. self.session_id .. ": " .. code })
	end

	return msg_id
end

---Interrupt the current execution
---
---Can also be done using `<c-c>` in the terminal.
function Kernel:interrupt()
	assert(self.client_id, "Kernel has no client id")
	require("jet.core.engine").interrupt(self.client_id)
end

return Kernel
