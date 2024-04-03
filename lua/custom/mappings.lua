---@type MappingsTable
local M = {}

M.general = {
  n = {
    --[";"] = { ":", "enter command mode", opts = { nowait = true } }, --Custom edit, couldn't rebind ';' so remove this definition
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
    ["<leader>dq"] = {
      function()
        vim.cmd "DBUILastQueryInfo"
      end,
      "DadBod Last Query Info",
    },
    --["<leader>dr"] = { --I'm using the <leader>dr mapping for restarting the dap ui plugin now save for later if needed
    --  function()
    --    vim.cmd "DBUIRenameBuffer"
    --  end,
    --  "Rename DadBod Buffer",
    --},
  },
}

-- more keybinds!

return M
