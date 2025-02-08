---@type MappingsTable
local M = {}

M.general = {
  n = {
    --[";"] = { ":", "enter command mode", opts = { nowait = true } }, --Custom edit, couldn't rebind ';' so remove this definition
    ["<leader>tn"] = { "<cmd> set nu! <CR>", "Toggle line number" }, -- Rebinding So I Can Make "<leader>n" A Chain Command
    ["y<CR>"] = { "<ESC>", "Escape Action" }, -- When saving I y<CR> By Habit Beause Of The Fucking Overwrite Message And It Fucks Up My Yanks Everytime
    -- DVORAK Mappings --
    ["d"] = { "h", "Move Left" },
    ["h"] = { "j", "Move Down" },
    ["t"] = { "k", "Move Up" },
    ["n"] = { "l", "Move Right" },
    [","] = { "w", "Move Forward A Word" },
    ["k"] = { "b", "Move Back A Word" },
    ["D"] = { "d", "Delete" },
    ["D,"] = { "dw", "Delete Word" },
    ["DD"] = { "dd", "Delete Line" },
    ["Dd"] = { "dd", "Delete Line" },
    ["Di"] = { "di", "Delete In" },
    ["DI"] = { "di", "Delete In" },
    ["Da"] = { "da", "Delete Around" },
    ["DA"] = { "da", "Delete Around" },
  },
  x = {
    -- DVORAK Mappings --
    ["d"] = { "h", "Move Left" },
    ["h"] = { "j", "Move Down" },
    ["t"] = { "k", "Move Up" },
    ["n"] = { "l", "Move Right" },
    [","] = { "w", "Move Forward A Word" },
    ["k"] = { "b", "Move Back A Word" },
    ["D"] = { "d", "Delete" },
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
