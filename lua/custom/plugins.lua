local overrides = require("custom.configs.overrides")

---@type NvPluginSpec[]
local plugins = {

  -- Override plugin definition options

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      -- format & linting
      {
        "jose-elias-alvarez/null-ls.nvim",
        config = function()
          require "custom.configs.null-ls"
        end,
      },
    },
    config = function()
      require "plugins.configs.lspconfig"
      require "custom.configs.lspconfig"
    end, -- Override to setup mason-lspconfig
  },

  -- override plugin configs
  {
    "williamboman/mason.nvim",
    opts = overrides.mason
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = overrides.treesitter,
    run = ":TSUpdate",
  },

  {
    "nvim-tree/nvim-tree.lua",
    opts = overrides.nvimtree,
  },

  -- Install a plugin
  {
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    config = function()
      require("better_escape").setup()
    end,
  },

  -- ### Custom Plugins --
    -- Most Plugins Should Probably Be Lazy Loaded

  -- Save/Load Sessions
  {
    "natecraddock/sessions.nvim",
    config = function()
      require("sessions").setup({}) --events = { "WinEnter" }, session_filepath = ".nvim/session", })
      vim.api.nvim_create_user_command("Save", function(args)
        if (args['args']) then
          require("sessions").save("~/.config/nvim/ws/" .. string.lower(args['args']))
        end
      end, {nargs='*'})
      vim.api.nvim_create_user_command("Load", function(args)
        if (args['args']) then
          require("sessions").load("~/.config/nvim/ws/" .. string.lower(args['args']))
        end
      end, {nargs='*'})
    end,
    lazy = false,
  },

  -- Fuzzy Finding (Live Grep, Find Files, Find Buffers, etc)
    -- Note installing fzf in /home/jramos/.local/share/nvim/lazy/telescope-fzf-native.nvim/lua/fzf_lib.lua
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = 'make',
    opts = {
      extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = "smart_case",
          },
      },
    },
    config = function(_, opts)
      require("telescope").setup(opts)
    end,
  },

  -- Dap/DapUi/DapVirtualText - Step Debugger (Added function to automatically normalize window sizes)
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        keys = {
          { "<leader>du", function() require("dapui").toggle({}) end, desc = "Dap UI Toggler" },
          { "<leader>de", function() require("dapui").eval() end, desc = "Eval", mode = {"n", "v"} },
          { "<leader>dn", function()
                vim.cmd("NvimTreeClose")
                require("dapui").open()
                vim.cmd("wincmd h")
                vim.cmd("vertical resize 60")
                vim.cmd("wincmd j")
                vim.cmd("wincmd j")
                vim.cmd("horizontal resize 10")
                vim.cmd("wincmd l")
                vim.cmd("horizontal resize 10")
            end,
            desc = "Dap UI Normalize Sizing"
          }, --A bit ghetto but works (Find cleaner/safer way like requiring nvim-tree)
        },
        opts = {
          icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
          mappings = {
            expand = { "<CR>", "<2-LeftMouse>" },
            open = "o",
            remove = "d",
            edit = "e",
            repl = "r",
            toggle = "t",
          },
          expand_lines = vim.fn.has("nvim-0.7"),
          layouts = {
            {
              elements = {
                { id = "scopes", size = 0.65 },
                { id = "breakpoints", size = 0.15 },
                { id = "stacks", size = 0.20 },
              },
              size = 60,
              position = "left",
            },
            {
              elements = {
                "watches", --Moved watches to bottom in place of console to conserver space and movement { id = "watches", size = 0.20 }
                "repl",
                --"console", --Remove the console for now I'm really not sure what it's use cases are
              },
              size = 10,
              position = "bottom",

            },
          },
          floating = {
            max_height = nil,
            max_width = nil,
            border = "single",
            mappings = {
              close = { "q", "<Esc>" }
            },
          },
          windows = { indend = 1 },
          render = {
            max_type_length = nil,
            max_value_lines = 100,
          }
        },
        config = function(_, opts)
          local dap = require("dap")
          local dapui = require("dapui")
          dapui.setup(opts)
          dap.listeners.after.event_initialized["dapui_config"] = function()
            dapui.open()
          end
          dap.listeners.before.event_terminated["dapui_config"] = function()
            dapui.close()
          end
          dap.listeners.before.event_exited["dapui_config"] = function()
            dapui.close()
          end
        end,
      },
      { "theHamsta/nvim-dap-virtual-text", "nvim-telescope/telescope-dap.nvim" },
    },
  },

  -- Popup Notifications (Currently Using - Grep Proccess(Custom))
  {
    "rcarriga/nvim-notify",
    lazy = false,
    opts = {
        render = "compact",
        minimum_width = 25,
        stages = "slide",
        timeout = 1000,
        top_down = true, -- If I could position it above the bottom bar I'd like to do the bottom
    },
  },

  -- DadBod Database Tool 
  {
    "tpope/vim-dadbod",
    lazy = false, -- This one can be fixed for sure
    dependencies = { "kristijanhusak/vim-dadbod-ui", "kristijanhusak/vim-dadbod-completion", "pbogut/vim-dadbod-ssh" },
    config = function()
      require("custom.config.dadbod").setup()
      vim.api.nvim_create_autocmd("FileType", {pattern = "dbout", command = [[setlocal nofoldenable]]}) --autocmd FileType dbout setlocal nofoldenable
    end,
  },

  -- Scroll Bar With Git Sign & Search Indicators
  {
    "petertriho/nvim-scrollbar",
    lazy = false,
    dependencies = {"kevinhwang91/nvim-hlslens"},
    config = function()
      require("scrollbar").setup({ handle = { color = "#27303b", blend = 25 }, marks = { Search = { color = "#fafa48" } } }) -- Added Custom Coloring
      require("scrollbar.handlers.gitsigns").setup()
      require("scrollbar.handlers.search").setup({
            override_lens = function() end,
      })
    end,
  },

  -- Telescope File Browser (Used For Find In Folder Added Funcation)
  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = {"nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim"}
  },

  -- To make a plugin not be loaded
  -- {
  --   "NvChad/nvim-colorizer.lua",
  --   enabled = false
  -- },
  -- All NvChad plugins are lazy-loaded by default
  -- For a plugin to be loaded, you will need to set either `ft`, `cmd`, `keys`, `event`, or set `lazy = false`
  -- If you want a plugin to load on startup, add `lazy = false` to a plugin spec, for example
  -- {
  --   "mg979/vim-visual-multi",
  --   lazy = false,
  -- }
}

return plugins
