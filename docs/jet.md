---
title: jet.nvim
filename: jet.txt
vimdoc-prefix: jet
---

jet.nvim is a Jupyter client/API for Neovim, built on top of the
[Jet](https://github.com/wurli/jet) CLI/Lua library.

## Configuration

Configure jet.nvim by passing options to `setup()`:

``` lua
require("jet").setup({
	-- Config options here
})
```

The full set of configuration options is as follows:

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Config.Opts
```

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Config.Ui.Opts
```

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Config.Img.Opts
```

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Hooks
```

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Kernel
```

## Jet UI

Bla bla

### Jet kernel management

`:Jet` without args brings up a UI for kernel management. This allows

* Renaming sessions (sets the `Kernel.session_name` attribute)
* Stopping or starting kernels
* Connecting to kernels managed by Jet which are not owned by the current
  Neovim session

### The repl buffer

### The image buffer

## Filetypes

## AI integration

## Primary kernels

## Default kernels

## Recipes

## API

## Extending jet.nvim

