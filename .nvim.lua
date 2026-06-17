vim.lsp.config.nil_ls = {
	name = "nil_ls",
	cmd = { "nil" },
	filetypes = { "nix" },
}

vim.lsp.enable({ "nil_ls" })
