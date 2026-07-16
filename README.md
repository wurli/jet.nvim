# jet.nvim

A Jupyter kernel supervisor for Neovim, built on top of
[Jet](https://github.com/wurli/jet).

## Features

*   A REPL which runs in Neovim's built-in terminal
*   Integration with Jet's LSP server which surfaces completions from the kernel
    in your Neovim session
*   A Lua API which gives fine-grained control over running kernels, down to
    the level of individual Jupyter messages
*   Ability to connect to kernel sessions running outside of Neovim
*   Work alongside your favourite AI agent using Jet
*   Plug and play - No remote plugin stuff. No python requirements. 

**Not yet implemented**
*   Notebooks!

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

## Extending jet.nvim

jet.nvim exposes an [API](./lua/jet/core/kernel.lua) for working with Jupyter
kernels using Lua. The idea is to allow other plugins to build on jet.nvim to
expose kernel-specific functionality. 

**Existing extensions**

| Repo                                        | Kernel                                  | Language | Features             |
| ----                                        | ------                                  | -------- | --------             |
| [jet.ark](https://github.com/wurli/jet.ark) | [Ark](https://github.com/posit-dev/ark) | R        | LSP server, debugger |

## FAQ

<details>
<summary>
For a 'Jupyter kernel supervisor' this plugin doesn't have much to do with
notebooks?
</summary>

> It's a common misconception that Jupyter == notebooks. Jupyter is really
> standard for how interactive languages can tell editors about execution
> results. It's somewhat analogous to LSP as a standard for how code analysis
> software can tell editors about code state.
> 
> If you want to implement the Jupyter standard for a language, you wrap the
> language in a Jupyter kernel. Ipykernel is a popular kernel for Python, Ark is
> another for R. There are many other kernels which exist for other languages.
> 
> Once you've got a kernel, your editor needs to implement a Jupyter client to
> talk to it. Most editors which implement a Jupyter client use it for some kind
> of notebook experience, but many also include some kind of REPL (notable
> examples are Positron and Jupyter's Qt Console).
> 
> Jet is a Jupyter client and kernel supervisor purpose-built for Neovim. So far
> jet.nvim only supports a REPL experience, but the infrastructure is there to
> support notebooks too, I just haven't implemented them on the Neovim side yet.
> But it's on the roadmap!
> 
> NB, one of the main benefits of a purpose-built client like Jet is that it will
> Neovim to tap into special/non-standard features that some kernels implement
> above and beyond the Jupyter spec. E.g. Ark adds a debugger, LSP server,
> variables pane, a dedicated help window, etc, all of which I'd like to expose
> in Neovim.

</details>
