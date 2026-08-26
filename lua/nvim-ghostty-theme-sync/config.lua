local M = {}

local defaults = {
	ghostty_config_path = nil,
	theme_name = "nvim-synced",
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_extend("force", defaults, opts or {})
	if not M.options.ghostty_config_path then
		M.options.ghostty_config_path = M.detect_ghostty_config()
	end
end

function M.detect_ghostty_config()
	local home = vim.fn.expand("~")
	local sysname = vim.loop.os_uname().sysname

	if sysname == "Darwin" then
		local mac_path = home .. "/Library/Application Support/com.mitchellh.ghostty/config"
		if vim.fn.filereadable(mac_path) == 1 then
			return mac_path
		end
	end

	return home .. "/.config/ghostty/config"
end

function M.get_ghostty_themes_dir()
	return vim.fn.expand("~/.config/ghostty/themes")
end

return M
