local M = {}

--- Default configuration
local defaults = {
	ghostty_config_path = nil,
	theme_name = "nvim-synced",
}

--- Config file names Ghostty loads, highest precedence first
--- (verified: config.ghostty overrides config when both exist in one dir)
local config_names = { "config.ghostty", "config" }

--- Always populated so the plugin also works without an explicit setup() call
--- @type table
M.options = vim.tbl_extend("force", defaults, {})

--- Read an environment variable, treating unset/empty as nil.
--- Unlike vim.fn.getenv, never returns the vim.NIL userdata.
--- @param name string
--- @return string|nil
local function env(name)
	local value = os.getenv(name)
	if type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

--- Get the home directory
--- @return string home directory path
local function get_home()
	return vim.fn.expand("~")
end

--- Get the OS type
--- @return string "macos", "linux", or "windows"
local function get_os()
	local sysname = (vim.uv or vim.loop).os_uname().sysname
	if sysname == "Darwin" then
		return "macos"
	elseif sysname == "Windows_NT" then
		return "windows"
	else
		return "linux"
	end
end

--- Path separator for the current platform
--- @return string
local function sep()
	return get_os() == "windows" and "\\" or "/"
end

--- Directories Ghostty loads user config files from, highest precedence first.
--- macOS: Application Support files are loaded after XDG files, so they win.
--- Linux: only $XDG_CONFIG_HOME/ghostty is read (defaulting to ~/.config/ghostty).
--- @return string[]
local function config_dirs()
	local os = get_os()
	local home = get_home()
	local dirs = {}

	if os == "macos" then
		dirs[#dirs + 1] = home .. "/Library/Application Support/com.mitchellh.ghostty"
	elseif os == "windows" then
		local localappdata = env("LOCALAPPDATA")
		if localappdata then
			dirs[#dirs + 1] = localappdata .. "\\ghostty"
		end
		dirs[#dirs + 1] = home .. "\\.config\\ghostty"
		return dirs
	end

	local xdg = env("XDG_CONFIG_HOME")
	if xdg then
		dirs[#dirs + 1] = xdg .. "/ghostty"
	else
		dirs[#dirs + 1] = home .. "/.config/ghostty"
	end

	return dirs
end

--- Detect the Ghostty config file path
--- @return string|nil path to config file, or nil if not found
function M.detect_ghostty_config()
	local s = sep()
	for _, dir in ipairs(config_dirs()) do
		for _, name in ipairs(config_names) do
			local path = dir .. s .. name
			if vim.fn.filereadable(path) == 1 then
				return path
			end
		end
	end

	return nil
end

--- Path used when no config file exists yet (a new one is created there)
--- @return string
function M.default_config_path()
	return config_dirs()[1] .. sep() .. "config"
end

--- Ensure the config path exists, creating an empty file if needed.
--- @return string path to Ghostty config file
function M.ensure_config_path()
	local path = M.options.ghostty_config_path
	if not path then
		path = M.detect_ghostty_config() or M.default_config_path()
		M.options.ghostty_config_path = path
	end

	if vim.fn.filereadable(path) ~= 1 then
		vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
		local file = io.open(path, "w")
		if not file then
			error("[nvim-ghostty-theme-sync] Failed to create Ghostty config file: " .. path)
		end
		file:close()
	end

	return path
end

--- Get the Ghostty themes directory Ghostty searches for named themes
--- ($XDG_CONFIG_HOME/ghostty/themes, or ~/.config/ghostty/themes)
--- @return string themes directory path
function M.get_ghostty_themes_dir()
	if get_os() == "windows" then
		local localappdata = env("LOCALAPPDATA")
		if localappdata then
			return localappdata .. "\\ghostty\\themes"
		end
		return get_home() .. "\\.config\\ghostty\\themes"
	end

	local xdg = env("XDG_CONFIG_HOME")
	if xdg then
		return xdg .. "/ghostty/themes"
	end
	return get_home() .. "/.config/ghostty/themes"
end

--- Setup function for the plugin
--- @param opts table|nil options table
function M.setup(opts)
	M.options = vim.tbl_extend("force", defaults, opts or {})

	if M.options.ghostty_config_path then
		-- Expand a leading ~ so README-style paths work
		if M.options.ghostty_config_path:match("^~") then
			M.options.ghostty_config_path = vim.fn.expand(M.options.ghostty_config_path)
		end
	else
		M.options.ghostty_config_path = M.detect_ghostty_config() or M.default_config_path()
	end

	-- Ensure themes directory exists
	vim.fn.mkdir(M.get_ghostty_themes_dir(), "p")
end

return M
