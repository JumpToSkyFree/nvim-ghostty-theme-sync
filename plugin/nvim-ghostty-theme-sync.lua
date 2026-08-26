vim.api.nvim_create_user_command("GhosttySyncTheme", function()
	require("nvim-ghostty-theme-sync.sync").sync()
end, { desc = "Sync current nvim colorscheme to Ghostty as a custom theme" })
