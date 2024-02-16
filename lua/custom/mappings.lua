---@type MappingsTable
local M = {}

M.general = {
  n = {
    [";"] = { ":", "enter command mode", opts = { nowait = true } },
  },
  v = {
    [">"] = { ">gv", "indent"},
  },
}

M.dadBod = {
  n = {
    ["<leader>db"] = {
      function()
        vim.cmd "DBUIToggle"
      end,
      "Open DadBod UI",
    },
    ["<leader>df"] = {
      function()
        vim.cmd "DBUIFindBuffer"
      end,
      "Find DadBod Buffer",
    },
    ["<leader>dr"] = {
      function()
        vim.cmd "DBUIRenameBuffer"
      end,
      "Rename DadBod Buffer",
    },
    ["<leader>dq"] = {
      function()
        vim.cmd "DBUILastQueryInfo"
      end,
      "DadBod Last Query Info",
    },
  },
}

-- more keybinds!

return M
