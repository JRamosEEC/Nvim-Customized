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

M.gitsigns = {
    n = {
        ["<leader>gB"] = {
          function()
            require("gitsigns").blame_line {full=true}
          end,
          "Blame line (Verbose)",
        },
        ["<leader>gu"] = {
          function()
            require("gitsigns").undo_stage_hunk()
          end,
          "Undo stage hunk",
        },
        ["<leader>gd"] = {
          function()
            require("gitsigns").diffthis()
          end,
          "Git diff",
        },
        ["<leader>gD"] = {
          function()
            require("gitsigns").diffthis('~')
          end,
          "Git diff (Verbose)",
        },
        ["<leader>sh"] = {
          function()
            require("gitsigns").stage_hunk()
          end,
          "Stage hunk",
        },
        ["<leader>sb"] = {
          function()
            require("gitsigns").stage_buffer()
          end,
          "Stage buffer",
        },
        ["<leader>rb"] = {
          function()
            require("gitsigns").reset_buffer()
          end,
          "Reset buffer",
        },
    },
    v = {
        ["<leader>sh"] = {
          function()
            require("gitsigns").stage_hunk {vim.fn.line('.'), vim.fn.line('v')}
          end,
          "Stage hunk",
        },
        ["<leader>rh"] = {
          function()
            require("gitsigns").reset_hunk {vim.fn.line('.'), vim.fn.line('v')}
          end,
          "Reset hunk",
        },
    }
}

-- more keybinds!

return M
