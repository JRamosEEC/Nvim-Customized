require "core"

local custom_init_path = vim.api.nvim_get_runtime_file("lua/custom/init.lua", false)[1]

if custom_init_path then
  dofile(custom_init_path)
end

require("core.utils").load_mappings()

local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

-- bootstrap lazy.nvim!
if not vim.loop.fs_stat(lazypath) then
  require("core.bootstrap").gen_chadrc_template()
  require("core.bootstrap").lazy(lazypath)
end

dofile(vim.g.base46_cache .. "defaults")
vim.opt.rtp:prepend(lazypath)
require "plugins"

-- ### Custom Config

-- Relative Line Number By Default
vim.opt.relativenumber = true

-- Setup Telescope
local telescope = require("telescope")
local telescope_actions = require("telescope.actions")
local builtin = require("telescope.builtin")
telescope.setup({
    defaults = {
        mappings = {
            n = { ["<C-q>"] = telescope_actions.send_to_qflist},-- + builtin.quickfixhistory()},
            i = { ["<C-q>"] = telescope_actions.send_to_qflist},-- + builtin.quickfixhistory},
        },
    },
})
vim.keymap.set('n', '<leader>tt', '<cmd>Telescope<CR>', { desc = "Telescope", noremap = true }) --Keybind to open Telescope picker list
vim.keymap.set('n', '<leader>fl', builtin.quickfix, { desc = "Find Last Search", noremap = true }) --Keybind to open Telescope quick fix (The last saved search)
vim.keymap.set('n', '<leader>fh', builtin.quickfixhistory, { desc = "Find Search History", noremap = true }) --Keybind to open Telescope quick fix (The last saved search)

-- ## LSP - (Two PHP LSP's for combined features e.g. completion snippets and deprecation messages)
-- LSP PHP Actor (Primary LSP)
require('lspconfig').phpactor.setup({
  filetype = { "php", "phtml" },
  init_options = {
    --["language_serer_worse_reflection.inlay_hints.enable"] = true,
    --["language_serer_worse_reflection.inlay_hints.params"] = true,
    --["language_serer_worse_reflection.inlay_hints.types"] = true,
    --["language_server_configuration.auto_config"] = false,
    --["language_server_psalm.enabled"] = false,
    ["code_transform.import_globals"] = true,
    ["language_server_phpstan.enabled"] = true,
    ["language_server_phpstan.level"] = 7,
    ["language_server_phpstan.bin"] = "phpstan",
  }
})
-- LSP Intelephense (Alternative LSP)
require('lspconfig').intelephense.setup({
  on_attach = function(client, bufnr)
    vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
  end,
  debounce_text_changes = 150,
})

-- Dap (Setup in Plugins & Loaded With PHP Debugger Adapter Here)
local dap = require('dap')
require('dap').set_log_level('trace')
require('telescope').load_extension('dap')
dap.adapters.php = {
  type = "executable",
  command = "node",
  args = { os.getenv("HOME") .. "/vscode-php-debug/out/phpDebug.js" }
}
dap.configurations.php = {
  {
    type = 'php',
    request = 'launch',
    name = 'Listen for Xdebug',
    port = 9003,
    log = true,
    pathMappings = {
      ['/home/justin/sandbox/dev/zf2'] = "${workspaceFolder}",
    },
    stopOnEntry = false,
    xdebugSettings = {
      ["max_data"] = -1,
    }
  }
}
-- Dap Virtual Text Inline Info (I don't think this is fully funcitonal yet)
require("nvim-dap-virtual-text").setup({
  enabled = true,
  enabled_commands = true,
  highlight_changed_variables = true,
  highlight_new_as_changed = true,
  show_stop_reason = true,
  commented = true,
  only_first_definition = true,
  all_references = false,
  clear_on_continue = false,

  display_callback = function (variable, buf, stackframe, node, options)
    if options.virt_text_post == 'inline' then
      return ' = ' .. variable.value
    else
      return variable.name .. ' = ' .. variable.value
    end
  end,
  virt_text_pos = vim.fn.has 'nvim-0.10' == 1 and 'inline' or 'eol',
  -- Experimental features:
  all_frames = false,
  virt_line = false,
  virt_text_win_col = nil,
})
-- Dap Keybinds
vim.keymap.set('n', '<F5>', function() require('dap').continue() end)
vim.keymap.set('n', '<F9>', function() require('dap').toggle_breakpoint() end)
vim.keymap.set('n', '<F10>', function() require('dap').step_over() end)
vim.keymap.set('n', '<F11>', function() require('dap').step_into() end)
vim.keymap.set('n', '<F12>', function() require('dap').step_out() end)

-- File Browser & Find In Directory (Removing this until I add fd file searching to it way to slow without it)
--vim.api.nvim_set_keymap('n', '<space>fd', ":Telescope file_browser<CR>", { desc = "Find Directories", noremap = true })

-- ###Experimental Changes
-- Telescope Find In Folder Function For Fuzzy Finder (Slow With Large File Trees Like Ours)
local ts_select_dir_for_grep = function(prompt_bufnr)
    local action_state = require("telescope.actions.state")
    local fb = require("telescope").extensions.file_browser
    local live_grep = require("telescope.builtin").live_grep
    local current_line = action_state.get_current_line()
    local async_oneshot_finder = require "telescope.finders.async_oneshot_finder" --For Custom browse_folders Function
    local Path = require "plenary.path" --For Custom browse_folders Function
    fb.file_browser({
        files = false, --Disable to only use custom browse_folers function without predefined browse_files
        depth = 1,
        use_fd = true, -- Kind of a necessity it's fast as hell
        attach_mappings = function(prompt_bufnr)
            require("telescope.actions").select_default:replace(function()
                local entry_path = action_state.get_selected_entry().Path
                local dir = entry_path:is_dir() and entry_path or entry_path:parent()
                local relative = dir:make_relative(vim.fn.getcwd())
                local absolute = dir:absolute()
                live_grep({ results_title = relative .. "/", cwd = absolute, default_text = current_line, })
            end)
            return true
        end,
        browse_folders = function(opts) -- Redefine the function using only fd with command/args "fd -t d --maxdepth 1 --absolute-path" which will get all directories in the current path only (This function also get parent '../' dir)
            local cwd = opts.cwd_to_path and opts.path or opts.cwd
            local entry_maker = opts.entry_maker { cwd = cwd }
            return async_oneshot_finder {
                fn_command = function()
                    return { command = "fd", args = { "--type", "directory", "--absolute-path", "--maxdepth", 1 } }
                end,
                entry_maker = entry_maker,
                results = { entry_maker(Path:new(opts.path):parent():absolute()) }, --Parent Path To Include Parent Dir
                cwd = cwd,
            }
        end,
    })
end

local fb_actions = require "telescope._extensions.file_browser.actions" --For Custom File Browswer Mappings
telescope.setup({
    extensions = {
        file_browser = {
            mappings = {
                ["i"] = { ["<C-]>"] = fb_actions.change_cwd },
                ["n"] = { ["<C-]>"] = fb_actions.change_cwd },
            },
        },
    },
    pickers = {
        live_grep = {
            mappings = {
                ["i"] = { ["<C-f>"] = ts_select_dir_for_grep, },
                ["n"] = { ["<C-f>"] = ts_select_dir_for_grep, }
            },
        },
    },
})
