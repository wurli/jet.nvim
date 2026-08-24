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

function Lsp:configure()
	local capabilities = vim.lsp.protocol.make_client_capabilities()
	vim.lsp.config(self.name, {
		cmd = vim.lsp.rpc.connect("127.0.0.1", self.port),
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
end

function Lsp:enable()
	if not vim.lsp.is_enabled(self.name) then
		self:configure()
		vim.lsp.enable(self.name)
	end
end

function Lsp:disable() vim.lsp.enable(self.name, false) end

return Lsp
