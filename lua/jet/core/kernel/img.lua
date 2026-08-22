local buf = require("jet.core.kernel.buf")

---@class jet.Kernel.Img : jet.Buf
---@field kernel jet.Kernel
---@field img_file? string
local Img = setmetatable({}, { __index = buf })
Img.__index = Img ---@private

---@class jet.Kernel.Img.init.Opts
---@field kernel jet.Kernel
---@field ns integer

---@param opts jet.Kernel.Img.init.Opts
---@return jet.Kernel.Img
function Img.init(opts)
	assert(opts.kernel.session_id, "Kernel session_id is required")

	local out = buf.init(Img, {
		name = opts.kernel:friendly_name() .. " - Images",
		ns = opts.ns,
		open_opts = function()
			local term_win = opts.kernel.term and opts.kernel.term:win()
			return term_win and {
				split = "above",
				win = term_win,
				style = "minimal",
			} or {
				split = "right",
				win = -1,
				style = "minimal",
			}
		end,
	})

	out.kernel = opts.kernel
	vim.bo[out.buf].filetype = "jetimg"
	vim.b[out.buf].jet = { session_id = out.kernel.session_id }

	out:create_autocmd("BufWinEnter", function() out:display() end)

	vim.keymap.set("n", "<c-n>", function() out:display(1) end, { buffer = out.buf })
	vim.keymap.set("n", "<c-p>", function() out:display(-1) end, { buffer = out.buf })

	return out
end

function Img.get_winbar()
	local session_id = vim.b.jet and vim.b.jet.session_id
	local kernel = session_id and require("jet.core.manager").kernels[session_id]

	if not kernel then
		return "Jet - Images"
	end

	if not kernel.img then
		return kernel:friendly_name() .. " - Images"
	end

	local files, curr_file_index = kernel.img:list_files()

	if #files == 0 or not curr_file_index then
		return kernel:friendly_name() .. " - Images"
	end

	return string.format("%s - Image %d/%d", kernel:friendly_name(), curr_file_index, #files, files[curr_file_index])
end

---@param focus? boolean
---@param latest? boolean
---@return integer # Win number
function Img:open(focus, latest)
	if latest == nil then
		latest = true
	end

	local win = buf.open(self, focus)
	vim.wo[win].winbar = "%{%v:lua.require'jet.core.kernel.img'.get_winbar()%}"
	self:display(latest ~= true and self.img_file or nil)
	return win
end

---@return string[]
---@return integer?
function Img:list_files()
	local files = {}
	local curr_file_index
	for name, type in vim.fs.dir(self.kernel:image_dir()) do
		if type == "file" then
			table.insert(files, name)
			if name == self.img_file then
				curr_file_index = #files
			end
		end
	end

	return files, curr_file_index
end

---@param file? string | 1 | -1
function Img:display(file)
	if not _G.Snacks then
		return
	end

	local filepath
	if type(file) == "string" then
		filepath = file
	else
		local files, curr_file_index = self:list_files()
		if not curr_file_index or not file then
			filepath = files[#files]
		elseif file == 1 then
			filepath = files[curr_file_index + 1] or files[1]
		elseif file == -1 then
			filepath = files[curr_file_index - 1] or files[#files]
		end
	end

	if not filepath then
		return
	end

	self.img_file = vim.fs.basename(filepath)

	local win = self:win()

	if not win then
		return
	end

	_G.Snacks.image.buf.attach(self.buf, {
		src = vim.fs.joinpath(self.kernel:image_dir(), filepath),
		inline = true,
		type = "image",
		pos = { 1, 0 },
	})

	vim.api.nvim__redraw({ win = win, winbar = true })
end

return Img
