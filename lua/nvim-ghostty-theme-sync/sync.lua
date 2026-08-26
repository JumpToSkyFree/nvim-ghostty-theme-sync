local M = {}
local config = require("nvim-ghostty-theme-sync.config")
local colors_mod = require("nvim-ghostty-theme-sync.colors")

--- Convert RGB table to hex string
--- @param color table: {r, g, b}
--- @return string hex like "#rrggbb"
local function to_hex(color)
	return string.format("#%02x%02x%02x", color.r, color.g, color.b)
end

--- Generate a Ghostty theme file from colors table
--- @param theme_name string: Name for the theme
--- @param c table: Color table with bg, fg, palette, etc.
--- @return string path to the generated theme file
local function write_theme_file(theme_name, c)
	local lines = {}

	-- Palette (terminal colors 0-15)
	for i = 0, 15 do
		table.insert(lines, "palette = " .. i .. "=" .. to_hex(c.palette[i]))
	end

	-- Core colors
	table.insert(lines, "background = " .. to_hex(c.background))
	table.insert(lines, "foreground = " .. to_hex(c.foreground))
	table.insert(lines, "cursor-color = " .. to_hex(c.cursor_color))
	table.insert(lines, "cursor-text = " .. to_hex(c.cursor_text))
	table.insert(lines, "selection-background = " .. to_hex(c.selection_background))
	table.insert(lines, "selection-foreground = " .. to_hex(c.selection_foreground))

	-- Ensure themes directory exists
	local themes_dir = config.get_ghostty_themes_dir()
	vim.fn.mkdir(themes_dir, "p")

	-- Write theme file
	local theme_path = themes_dir .. "/" .. theme_name
	local file = io.open(theme_path, "w")
	if not file then
		error("Failed to write theme file: " .. theme_path)
	end
	for _, line in ipairs(lines) do
		file:write(line .. "\n")
	end
	file:close()

	return theme_path
end

--- Find a light/dark variant of the current colorscheme
--- @param colorscheme string: Current colorscheme name
--- @param want_light boolean: true to find light variant, false for dark
--- @return string|nil variant_name
local function find_variant(colorscheme, want_light)
	local all = vim.fn.getcompletion("", "color")
	local all_set = {}
	for _, cs in ipairs(all) do all_set[cs] = true end

	-- Common patterns for light/dark variants
	local light_suffixes = { "-light", "-day", "-dawn", "-lotus", "_light", " Light" }
	local dark_suffixes = { "-dark", "-night", "-moon", "-storm", "_dark", " Dark" }

	local target_suffixes = want_light and light_suffixes or dark_suffixes
	local current_suffixes = want_light and dark_suffixes or light_suffixes

	-- 1. Check if current name has a suffix we can strip
	for _, suffix in ipairs(current_suffixes) do
		if colorscheme:match(vim.pesc(suffix) .. "$") then
			local base = colorscheme:sub(1, #colorscheme - #suffix)
			-- Try adding opposite suffix
			for _, target in ipairs(target_suffixes) do
				local candidate = base .. target
				if all_set[candidate] then
					return candidate
				end
			end
			-- Try base name itself (might be the opposite variant)
			if all_set[base] then
				return base
			end
		end
	end

	-- 2. Check if adding a suffix to current name yields a result
	for _, suffix in ipairs(target_suffixes) do
		local candidate = colorscheme .. suffix
		if all_set[candidate] then
			return candidate
		end
	end

	return nil
end

--- Get colors for a specific colorscheme
--- @param colorscheme string: The colorscheme to load
--- @return table|nil colors
local function get_colors_for(colorscheme)
	-- Save current state
	local old_colors = vim.g.colors_name
	local old_bg = vim.o.background

	-- Try to load the target colorscheme
	local success = pcall(function()
		vim.cmd("colorscheme " .. colorscheme)
	end)

	if not success then
		-- Restore original
		if old_colors then
			pcall(function() vim.cmd("colorscheme " .. old_colors) end)
		end
		vim.o.background = old_bg
		return nil
	end

	-- Get colors
	local c = colors_mod.get_theme_colors()

	-- Restore original state
	if old_colors then
		pcall(function() vim.cmd("colorscheme " .. old_colors) end)
	end
	vim.o.background = old_bg

	return c
end

--- Update Ghostty config to use mode-aware theme
--- @param dark_name string: Dark theme name
--- @param light_name string: Light theme name
local function update_ghostty_config(dark_name, light_name)
	local config_path = config.options.ghostty_config_path
	local lines = {}
	local found = false

	for line in io.lines(config_path) do
		if line:match("^theme%s*=%s*") then
			table.insert(lines, "theme = dark:" .. dark_name .. ", light:" .. light_name)
			found = true
		else
			table.insert(lines, line)
		end
	end

	if not found then
		table.insert(lines, "theme = dark:" .. dark_name .. ", light:" .. light_name)
	end

	local file = io.open(config_path, "w")
	if not file then
		error("Failed to open ghostty config to write")
	end
	for _, line in ipairs(lines) do
		file:write(line .. "\n")
	end
	file:close()
end

--- Main function: sync current nvim theme to Ghostty (dark + light)
function M.sync()
	local base_name = config.options.theme_name
	local dark_name = base_name .. "-dark"
	local light_name = base_name .. "-light"

	-- Get current colorscheme and background
	local current_cs = vim.g.colors_name or "default"
	local current_bg = vim.o.background
	local is_dark = current_bg == "dark"

	-- Find the opposite variant (if we're dark, find light; if light, find dark)
	local opposite_cs = find_variant(current_cs, is_dark)

	local paths = {}

	if opposite_cs then
		-- Found a proper light/dark variant
		local current_c = colors_mod.get_theme_colors()
		local opposite_c = get_colors_for(opposite_cs)

		if opposite_c then
			-- Generate both variants
			if is_dark then
				table.insert(paths, write_theme_file(dark_name, current_c))
				table.insert(paths, write_theme_file(light_name, opposite_c))
			else
				table.insert(paths, write_theme_file(dark_name, opposite_c))
				table.insert(paths, write_theme_file(light_name, current_c))
			end
		else
			-- Couldn't load opposite, use same for both
			table.insert(paths, write_theme_file(dark_name, current_c))
			table.insert(paths, write_theme_file(light_name, current_c))
		end
	else
		-- No opposite variant exists, use same theme for both
		local c = colors_mod.get_theme_colors()
		table.insert(paths, write_theme_file(dark_name, c))
		table.insert(paths, write_theme_file(light_name, c))
	end

	-- Update Ghostty config with mode-aware format
	update_ghostty_config(dark_name, light_name)

	vim.notify(
		"Generated themes:\n  " .. paths[1] .. "\n  " .. paths[2] ..
		"\n\nSet Ghostty to: dark:" .. dark_name .. ", light:" .. light_name ..
		"\nRun Reload Config in Ghostty to apply",
		vim.log.levels.INFO
	)
end

return M
