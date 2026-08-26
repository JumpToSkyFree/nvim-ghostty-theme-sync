local M = {}

--- Get the RGB values from a highlight color
--- @param color table|number|string: The color value
--- @return table|nil {r, g, b} in 0-255 range
local function parse_color(color)
	if type(color) == "table" then
		return color
	end
	if type(color) == "number" then
		return {
			r = math.floor(color / 65536) % 256,
			g = math.floor(color / 256) % 256,
			b = color % 256,
		}
	end
	if type(color) == "string" then
		local r, g, b = color:match("#(%x%x)(%x%x)(%x%x)")
		if r then
			return {
				r = tonumber(r, 16),
				g = tonumber(g, 16),
				b = tonumber(b, 16),
			}
		end
	end
	return nil
end

--- Convert RGB table to hex string
--- @param color table: {r, g, b}
--- @return string hex like "#rrggbb"
local function to_hex(color)
	return string.format("#%02x%02x%02x", color.r, color.g, color.b)
end

--- Get a highlight group's fg color
--- @param group string: The highlight group name
--- @return table|nil fg color
local function get_fg(group)
	local hl = vim.api.nvim_get_hl(0, { name = group })
	if not hl then return nil end
	return parse_color(hl.fg or hl.foreground)
end

--- Get a highlight group's bg color
--- @param group string: The highlight group name
--- @return table|nil bg color
local function get_bg(group)
	local hl = vim.api.nvim_get_hl(0, { name = group })
	if not hl then return nil end
	return parse_color(hl.bg or hl.background)
end

--- Brighten a color by mixing with white
--- @param color table: {r, g, b}
--- @param factor number: 0-1, how much to brighten
--- @return table brightened color
local function brighten(color, factor)
	return {
		r = math.min(255, math.floor(color.r + (255 - color.r) * factor)),
		g = math.min(255, math.floor(color.g + (255 - color.g) * factor)),
		b = math.min(255, math.floor(color.b + (255 - color.b) * factor)),
	}
end

--- Darken a color by mixing with black
--- @param color table: {r, g, b}
--- @param factor number: 0-1, how much to darken
--- @return table darkened color
local function darken(color, factor)
	return {
		r = math.floor(color.r * (1 - factor)),
		g = math.floor(color.g * (1 - factor)),
		b = math.floor(color.b * (1 - factor)),
	}
end

--- Try to get a color from multiple highlight groups, first match wins
--- @param groups table: List of highlight group names
--- @return table|nil color
local function get_fg_from(groups)
	for _, g in ipairs(groups) do
		local c = get_fg(g)
		if c then return c end
	end
	return nil
end

--- Get the current nvim theme's full color palette
--- @return table with bg, fg, and terminal colors
function M.get_theme_colors()
	local colors = {}

	-- Core colors
	local bg = get_bg("Normal") or { r = 30, g = 30, b = 30 }
	local fg = get_fg("Normal") or { r = 200, g = 200, b = 200 }
	colors.background = bg
	colors.foreground = fg

	-- Cursor
	colors.cursor_color = get_bg("Cursor") or fg
	colors.cursor_text = get_fg("Cursor") or bg

	-- Selection
	local sel_bg = get_bg("Visual") or brighten(bg, 0.3)
	colors.selection_background = sel_bg
	colors.selection_foreground = get_fg("Visual") or fg

	-- Try to get terminal colors from g:terminal_color_N
	local terminal_colors = {}
	local has_terminal = false
	for i = 0, 15 do
		local c = vim.g["terminal_color_" .. i]
		if c then
			local parsed = parse_color(c)
			if parsed then
				terminal_colors[i] = parsed
				has_terminal = true
			end
		end
	end

	-- If no terminal colors, derive from highlight groups
	if not has_terminal then
		-- Collect all unique highlight colors
		local all_colors = {}
		local seen = {}
		local hl_groups = {
			"DiagnosticError", "ErrorMsg", "Error",
			"DiagnosticWarn", "WarningMsg", "Todo",
			"DiagnosticInfo", "DiagnosticOk",
			"Function", "String", "Statement", "Constant",
			"Number", "Boolean", "Identifier", "Type",
			"Special", "Comment", "Operator",
			"@function.builtin", "@string.escape", "@variable.member",
		}

		for _, g in ipairs(hl_groups) do
			local c = get_fg(g)
			if c then
				local key = to_hex(c)
				if not seen[key] then
					seen[key] = true
					table.insert(all_colors, c)
				end
			end
		end

		-- Ensure we have at least 7 distinct colors
		while #all_colors < 7 do
			table.insert(all_colors, { r = 128, g = 128, b = 128 })
		end

		-- Sort by hue for better color distribution
		table.sort(all_colors, function(a, b)
			local ha = math.atan2(a.b - a.g, a.r - a.g)
			local hb = math.atan2(b.b - b.g, b.r - b.g)
			return ha < hb
		end)

		terminal_colors[0] = darken(bg, 0.3)
		terminal_colors[1] = all_colors[1]   -- red
		terminal_colors[2] = all_colors[2]   -- green
		terminal_colors[3] = all_colors[3]   -- yellow
		terminal_colors[4] = all_colors[4]   -- blue
		terminal_colors[5] = all_colors[5]   -- magenta
		terminal_colors[6] = all_colors[6]   -- cyan
		terminal_colors[7] = all_colors[7]   -- white

		-- Bright colors
		terminal_colors[8] = brighten(terminal_colors[0], 0.4)
		terminal_colors[9] = brighten(terminal_colors[1], 0.3)
		terminal_colors[10] = brighten(terminal_colors[2], 0.3)
		terminal_colors[11] = brighten(terminal_colors[3], 0.3)
		terminal_colors[12] = brighten(terminal_colors[4], 0.3)
		terminal_colors[13] = brighten(terminal_colors[5], 0.3)
		terminal_colors[14] = brighten(terminal_colors[6], 0.3)
		terminal_colors[15] = brighten(terminal_colors[7], 0.5)
	end

	-- Fill any missing palette colors with defaults
	local defaults = {
		{ r = 30, g = 30, b = 30 },
		{ r = 205, g = 49, b = 49 },
		{ r = 13, g = 188, b = 121 },
		{ r = 229, g = 229, b = 16 },
		{ r = 36, g = 114, b = 200 },
		{ r = 188, g = 63, b = 188 },
		{ r = 17, g = 168, b = 205 },
		{ r = 200, g = 200, b = 200 },
		{ r = 100, g = 100, b = 100 },
		{ r = 255, g = 100, b = 100 },
		{ r = 100, g = 255, b = 100 },
		{ r = 255, g = 255, b = 100 },
		{ r = 100, g = 149, b = 237 },
		{ r = 255, g = 100, b = 255 },
		{ r = 100, g = 255, b = 255 },
		{ r = 255, g = 255, b = 255 },
	}

	for i = 0, 15 do
		if not terminal_colors[i] then
			terminal_colors[i] = defaults[i + 1]
		end
	end

	colors.palette = terminal_colors
	return colors
end

return M
