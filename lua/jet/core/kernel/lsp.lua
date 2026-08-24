-- local utils = require("jet.core.utils")

---@class jet.Lsp
---@field port integer
---@field name string
---@field filetype string
local Lsp = {}
Lsp.__index = Lsp ---@private

---@class jet.Lsp.init.Opts
---@field port integer
---@field filetype string?
---@field client_id string
---@field display_name string

---@param opts jet.Lsp.init.Opts
function Lsp.init(opts)
	local out = setmetatable({
		sesssion = opts.session_id,
		name = string.format(
			"jet_%s_%s",
			opts.display_name:gsub("%W", "_"):gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", ""),
			opts.client_id
		),
		port = opts.port,
		filetype = opts.filetype,
	}, Lsp)

	return out
end

local make_capabilities = function()
	local capabilities = vim.lsp.protocol.make_client_capabilities()
	return {
		general = capabilities.general,
		textDocument = {
			completion = (capabilities.textDocument or {}).completion,
			-- hover = {
			-- 	dynamicRegistration = true,
			-- 	contentFormat = { constants.MarkupKind.Markdown, constants.MarkupKind.PlainText },
			-- },
		},
	}
end

function Lsp:configure()
	vim.lsp.config(self.name, {
		cmd = vim.lsp.rpc.connect("127.0.0.1", self.port),
		root_markers = { ".git" },
		filetypes = { self.filetype },
		root_dir = ".",
		capabilities = make_capabilities(),
	})
end

function Lsp:enable()
	if not vim.lsp.is_enabled(self.name) then
		print("enabling " .. vim.inspect(self))
		self:configure()
		vim.lsp.enable(self.name)
	end
end

function Lsp:disable()
	print("disabling " .. vim.inspect(self))
	vim.lsp.enable(self.name, false)
end

return Lsp
