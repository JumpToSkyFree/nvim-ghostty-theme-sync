local M = {}

M.config = require("nvim-ghostty-theme-sync.config")
M.setup = M.config.setup
M.sync = require("nvim-ghostty-theme-sync.sync").sync
M.colors = require("nvim-ghostty-theme-sync.colors")

return M
