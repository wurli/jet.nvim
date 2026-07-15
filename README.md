# jet.nvim

A Jupyter kernel supervisor for Neovim, built on top of
[Jet](https://github.com/wurli/jet).

## Features

*   A REPL which runs in Neovim's built-in terminal
*   A Lua API which gives fine-grained control over running kernels, down to
    the level of individual jupyter messages
*   Connect to kernel sessions running outside of Neovim
*   Work alongside your favourite AI agent using Jet
*   Plug and play - No remote plugin stuff. No python requirements. 

## Installation

Using `vim.pack`:

``` lua
vim.pack.add({ "https://github.com/wurli/jet.nvim" })

-- You'll need to call setup() for things to work correctly
require("jet").setup({})
```

Recommended keymaps:

``` lua
local open_ft = function(ft)
	return function()
		---@param k jet.kernel
		require("jet.core.api").get_any({ filetype = ft }, {}, function(k)
			k:toggle_term()
		end)
	end
end

vim.keymap.set("n", "<leader>jp", open_ft("python"), { desc = "Open Python (Jet)" })
vim.keymap.set("n", "<leader>jr", open_ft("r"), { desc = "Open R (Jet)" })
```
