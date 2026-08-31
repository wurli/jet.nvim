# jet.nvim

jet.nvim is a Jupyter client/API for Neovim, built on top of the
[Jet](https://github.com/wurli/jet) CLI/Lua library.

## Installation

``` lua
vim.pack.add("https://github.com/wurli/jet.nvim")
require("jet").setup()
```

The full set of configuration options is as follows:

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Config.Opts
```

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Hooks
```


```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Kernel
```

