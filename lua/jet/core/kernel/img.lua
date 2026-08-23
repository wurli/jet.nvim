local utils = require("jet.core.utils")
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
			return {
				split = term_win and "above" or "right",
				win = term_win or -1,
				style = "minimal",
			}
		end,
	})

	out.kernel = opts.kernel
	vim.bo[out.buf].filetype = "jetimg" -- Note: Snacks.image overrides to "image"
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
---@param which? string | integer
---@return integer # Win number
function Img:open(focus, which)
	local win = buf.open(self, focus)
	vim.wo[win].winbar = "%{%v:lua.require'jet.core.kernel.img'.get_winbar()%}"
	self:display(which)
	return win
end

---@return string[]
---@return integer?
function Img:list_files()
	local files = {}
	local curr_file_index
	for name, type in vim.fs.dir(self.kernel:img_dir()) do
		if type == "file" then
			table.insert(files, name)
			if name == self.img_file then
				curr_file_index = #files
			end
		end
	end

	return files, curr_file_index
end

---@param which? string | integer
function Img:display(which)
	local files, curr_file_index = self:list_files()

	local jet = vim.b[self.buf].jet or {}
	jet.n_images = #files
	jet.curr_image_index = curr_file_index

	local filepath
	if not which then
		filepath = self.img_file or curr_file_index and files[curr_file_index] or files[#files]
	elseif type(which) == "string" then
		filepath = which
	elseif type(which) == "number" and curr_file_index then
		filepath = files[curr_file_index + which] or which > 0 and files[1] or which < 0 and files[#files]
	else
		filepath = files[#files]
	end

	if not filepath then
		return
	end

	local win = self:win()

	if not win then
		return
	end

	self.img_file = vim.fs.basename(filepath)
	local src = vim.fs.joinpath(self.kernel:img_dir(), filepath)
	vim.api.nvim__redraw({ win = win, winbar = true })

	self.kernel:do_image_display_pre(src)

	-- First try Snacks
	if _G.Snacks and _G.Snacks.image and _G.Snacks.image.config then
		if not _G.Snacks.image.config.enabled then
			utils.log_warn("Snacks.image is not enabled. Please enable Snacks.image to view images.")
			return
		end
		_G.Snacks.image.buf.attach(self.buf, {
			src = src,
			inline = true,
			type = "image",
			pos = { 1, 0 },
		})
		return
	end

	-- ...Then fall back to image.nvim. Unfortunately this plugin seems to
	-- struggle with some jet.nvim stuff. In particular it has issues with
	-- jet.ark, which replaces image files if the user resizes the image
	-- window in nvim. When image.nvim tries to display an image, it seems
	-- there is a delay before imagemagick picks up the file, during which
	-- time the file might get deleted, causing an error.
	local ok, image_api = pcall(require, "image")
	if ok and image_api then
		local img = image_api.from_file(src, {
			buffer = self.buf,
			window = win,
		})
		if img then
			img:render()
		else
			utils.log_warn("[image.nvim]: Failed to render image: " .. src)
		end
		return
	end

	utils.log_warn("Image support is not available. Please install Snacks.nvim or image.nvim to view images.")
end

return Img
