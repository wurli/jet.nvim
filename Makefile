# Run all test files
test: deps/mini.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run test from file at `$FILE` environment variable
test_file: deps/mini.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"


.PHONY: docs
docs: deps/pandoc-include-sh deps/pandoc-better-vim emmylua_doc_cli/doc.json
	@mkdir -p docs
	pandoc \
		--lua-filter=deps/pandoc-include-sh/include-sh.lua \
		--lua-filter=deps/pandoc-better-vim/better-vim.lua \
		-t vimdoc --columns 78 --standalone \
		docs/jet.md -o doc/jet.txt

emmylua_doc_cli/doc.json: export VIMRUNTIME = $(shell nvim --clean --headless +'lua io.write(vim.env.VIMRUNTIME)' +qa)
emmylua_doc_cli/doc.json: $(shell find lua -name '*.lua')
	@mkdir -p emmylua_doc_cli
	emmylua_doc_cli . -f json -o emmylua_doc_cli

deps/pandoc-include-sh:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/wurli/pandoc-include-sh $@

deps/pandoc-better-vim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/wurli/pandoc-better-vim $@

deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/nvim-mini/mini.nvim $@

deps/test-kernels:
	sh scripts/install-dev-kernels.sh
