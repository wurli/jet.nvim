<h1 align="center">jet.nvim ✈️</h1>

<p align="center">A Jupyter kernel supervisor for Neovim, built on top of <a href=https://github.com/wurli/jet>Jet</a></p>

![motions](https://github.com/user-attachments/assets/f9c58f37-f084-43c4-9f33-413f26f016d3)

## More screenshots

<details>
<summary><strong>AI integration</strong></summary>

The [Jet](https://github.com/wurli/jet) CLI can be used by multiple users to
connect to the same kernel session. Jet provides a simple
[skill](https://github.com/wurli/jet/blob/main/crates/cli/src/skill.md)
enabling AI agents to run code and view outputs using your kernel session. AI
code is clearly marked as such in the repl:

![claude](https://github.com/user-attachments/assets/0d34eefe-db6f-43f8-b58f-34abea99ada7)

> [!TIP]
>
> **Why is this kind of AI integration useful?** Say you have some Python code
> which produces a single DataFrame and takes 10 minutes to run. Once you have
> the resulting DataFrame loaded in your Python session, to perform any
> analysis using AI in a traditional workflow, you will either need to first
> tell the AI how to reproduce the DataFrame, or serialise it to a file which
> the AI can quickly read. Both of these options take time and introduce plenty
> of room for things to go wrong. Using Jet however, the AI acts as 'player 2'
> in your session and can work with the data directly. This can save a tonne of
> time and greatly reduce context/token usage for certain types of problem.

</details>

<details>
<summary><strong>LSP Server</strong></summary>

jet.nvim provides kernel completions via an LSP middle-layer. These can include
runtime information not available to other LSP servers, e.g. the column names in
a Pandas DataFrame:

![completions](https://github.com/user-attachments/assets/37322d81-1972-42fd-9b79-eaaf5692bb2b)

</details>


<details>
<summary><strong>Jet UI</strong></summary>

jet.nvim provides a UI for kernel management, allowing you to easily
start, stop or rename kernel sessions from Neovim:

![ui](https://github.com/user-attachments/assets/dae00ec1-59cf-490a-9536-7be2973e64bd)

</details>

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
		require("jet.core.api").get_any({ filetype = ft }, {}, function(k) k:toggle_term() end)
	end
end

vim.keymap.set("n", "<leader>jp", open_ft("python"), { desc = "Open Python (Jet)" })
vim.keymap.set("n", "<leader>jr", open_ft("r"), { desc = "Open R (Jet)" })

vim.keymap.set(
	{ "n", "v" },
	"<enter>",
	function() require("jet.core.send").send_auto() end,
	{ desc = "Execute code (Jet)" }
)
```

## Extending jet.nvim

jet.nvim exposes an [API](./lua/jet/core/kernel.lua) for working with Jupyter
kernels using Lua. The idea is to allow other plugins to build on jet.nvim to
expose kernel-specific functionality. 

**Existing extensions**

| Repo                                        | Kernel                                  | Language | Features             |
| ----                                        | ------                                  | -------- | --------             |
| [jet.ark](https://github.com/wurli/jet.ark) | [Ark](https://github.com/posit-dev/ark) | R        | LSP server, debugger |

## jet.nvim vs similar plugins

Many other plugins provide some level of Jupyter integration, mostly by
implementing a Python backend. jet.nvim takes a different approach, offloading
implementation details such as ZMQ and Jupyter's wire protocol to Jet's Rust
backend. This happens in two ways:

* **Jet's Lua API**: jet.nvim bundles the Jet Lua library, allowing a fully
  featured kernel supervisor to be built in Neovim's Lua runtime. This makes
  jet.nvim more extensible than any other Jupyter plugin in Neovim's ecosystem,
  and allows jet.nvim itself to stay fairly lean, delegating kernel-specific
  problems to extension plugins such as
  [jet.ark](https://github.com/wurli/jet.ark).

* **Jet's CLI**: Jet provides a command-line tool implementing a full,
  completion-enabled repl which runs in any terminal emulator. jet.nvim runs
  the Jet CLI in Neovim's built-in terminal to provide a repl experience which
  _feels_ like native Neovim. A bonus of this architecture is that, since any
  number of Jet processes can connect to a single kernel instance, any AI agent
  can also connect to your kernel session and run code, evaluate results, etc
  alongside you.

Architecture differences aside, a high-level feature comparison is as follows:

<table>
  <thead>
    <tr>
      <th>Plugin</th>
      <th>Backend</th>
      <th>Rich Lua API</th>
      <th>Image support</th>
      <th>Native terminal repl</th>
      <th>Custom UI</th>
      <th>LSP</th>
      <th>Notebook support</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align = "center">
          <strong>jet.nvim</strong>
          <br/>
          <img src="https://img.shields.io/github/stars/wurli/jet.nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">Backed by <a href="https://github.com/wurli/jet">Jet</a>, a Rust-powered CLI and Lua library</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">🟠</td>
    </tr>
    <tr>
      <td align = "center">
          <a href="https://github.com/benlubas/molten-nvim">molten-nvim</a>
          <br/>
          <img src="https://img.shields.io/github/stars/benlubas/molten-nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">🐍 remote plugin</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/dccsillag/magma-nvim">magma-nvim</a>
        <br/>
        <img src="https://img.shields.io/github/stars/dccsillag/magma-nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">🐍 remote plugin</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/kiyoon/jupynium.nvim">jupynium.nvim</a>
        <br/>
        <img src="https://img.shields.io/github/stars/kiyoon/jupynium.nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">JupyterLab via 🐍 (Selenium)</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/luk400/vim-jukit">vim-jukit</a>
        <br/>
        <img src="https://img.shields.io/github/stars/luk400/vim-jukit?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">🐍 autoload via vimscript</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/SUSTech-data/neopyter">neopyter</a>
        <br/>
        <img src="https://img.shields.io/github/stars/SUSTech-data/neopyter?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">JupyterLab via RPC</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/sheng-tse/jupynvim">jupynvim</a>
        <br/>
        <img src="https://img.shields.io/github/stars/sheng-tse/jupynvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">Custom Rust backend</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/lkhphuc/jupyter-kernel.nvim">jupyter-kernel.nvim</a>
        <br/>
        <img src="https://img.shields.io/github/stars/lkhphuc/jupyter-kernel.nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">🐍 remote plugin</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/matarina/pyrola.nvim">pyrola.nvim</a>
        <br/>
        <img src="https://img.shields.io/github/stars/matarina/pyrola.nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">🐍 remote plugin</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/sei40kr/jupyter.nvim">jupyter.nvim</a>
        <br/>
        <img src="https://img.shields.io/github/stars/sei40kr/jupyter.nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">🐍 remote plugin</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
    </tr>
  </tbody>
</table>

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
> language in a Jupyter kernel. Ipykernel is a popular kernel for 🐍, Ark is
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
