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

-- Setup LSP Colors
--require("lsp-colors").setup({
--    Error = "#999999",
--    Warning = "#999999",
--    Information = "#999999",
--    Hint = "#999999",
--    Hint = "#999999",
--})

-- Setup Telescope
local telescope = require("telescope")
local telescope_actions = require("telescope.actions")
local builtin = require("telescope.builtin")
telescope.setup({
    defaults = {
        mappings = { --If this keybind ever doesn't work or similarly <C-s> good terminal flow control and remove it on the terminal
            n = { ["<C-q>"] = telescope_actions.send_to_qflist},-- + builtin.quickfixhistory()},
            i = { ["<C-q>"] = telescope_actions.send_to_qflist},-- + builtin.quickfixhistory},
        },
    },
})
vim.keymap.set('n', '<leader>tt', '<cmd>Telescope<CR>', { desc = "Telescope", noremap = true }) --Keybind to open Telescope picker list
vim.keymap.set('n', '<leader>fl', builtin.quickfix, { desc = "Find Last Search", noremap = true }) --Keybind to open Telescope quick fix (The last saved search)
vim.keymap.set('n', '<leader>fh', builtin.quickfixhistory, { desc = "Find Search History", noremap = true }) --Keybind to open Telescope quick fix (The last saved search)

vim.keymap.set('n', '<leader>fb', function() -- Set default find buffer funcitonality to sort by last used and to ignore current
    builtin.buffers({ sort_mru = true, ignore_current_buffer = true}) --, sorter = require'telescope.sorters'.get_substr_matcher() })
end, {desc = "Find buffers (Sort Last-Used)", noremap = true})

-- Background Searching Proccess (WIP) I'd prefer to get the first method working
--vim.keymap.set('n', '<leader>fx', function()
--    builtin.resume()
--    local prompt_bufnr = vim.api.nvim_get_current_buf()
--    vim.api.nvim_create_autocmd('User TelescopeResumePost', {
--        buffer = prompt_bufnr,
--        once = true,
--        callback = function ()
--            print("It works")
--        end,
--    })
--end, {desc = "Find Execute (As a background process)", noremap = true})

--vim.keymap.set('n', '<leader>fx', function()
--    builtin.live_grep({
--        on_complete = function(prompt_bufnr)
--            telescope_actions.select_default(prompt_bufnr)
--            require('telescope.actions.state').get_selected_entry(prompt_bufnr)
--            telescope_actions.close(prompt_bufnr)
--        end
--    })
--end, {desc = "Find Execute (As a background process)", noremap = true})


-- ## LSP - (Two PHP LSP's for combined features e.g. completion snippets and deprecation messages)
local lspconfig = require('lspconfig')
local cmp_lsp = require('cmp_nvim_lsp')
local capabilities = cmp_lsp.default_capabilities(vim.lsp.protocol.make_client_capabilities())
local window = require('lspconfig.ui.windows')

vim.keymap.set('n', '<leader>lo', vim.diagnostic.open_float, { desc = "Open Diagnostic Floating Window", noremap = true })
vim.keymap.set('n', '<leader>lp', vim.diagnostic.goto_prev, { desc = "Go To Previous Diagnostic", noremap = true })
vim.keymap.set('n', '<leader>ln', vim.diagnostic.goto_next, { desc = "Go To Next Diagnostic", noremap = true })
vim.keymap.set('n', '<leader>ll', '<cmd>Telescope diagnositcs<cr>', { desc = "Open Diagnostic List", noremap = true })
vim.keymap.set('n', '<leader>ld', vim.lsp.buf.definition, { desc = "Go To Definition", noremap = true })
vim.keymap.set('n', '<leader>lD', vim.lsp.buf.definition, { desc = "Go To Declaration (The interface)", noremap = true })
vim.keymap.set('n', '<leader>lr', vim.lsp.buf.references, { desc = "Display References", noremap = true })
vim.keymap.set('n', '<leader>lh', vim.lsp.buf.hover, { desc = "Show Var Information", noremap = true })

-- Removes the virtual text in-favor for opening the diagnostic floating window (Applies to all lsp's that attach unless overridden) -Note:I'm feeling out if I enjoy this
window.default_options.border = 'single'
vim.diagnostic.config {float = {border = 'single'}}
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
    vim.lsp.handlers.hover, {
        border = "single",
        focusable = false,
        title = "Details",
    }
)
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics, {
        virtual_text = false,
        underline = true,
        float = {border = 'single'},
    }
)
--Wondering if maybe I can make a corner window or something that's out of the way but will open seperately
--vim.o.updatetime = 250
--vim.api.nvim_command('autocmd CursorHold * lua vim.diagnostic.open_float()') --It messes up the vim.lsp.buf.hover (Also Idk it might get in the way auto popping up)

-- LSP PHP Actor (Primary LSP)
lspconfig.phpactor.setup({
  filetype = { "php", "phtml" },
  init_options = {
    --["language_server_completion.trim_leading_dollar"] = true,
    ["completion_worse.completor.constant.enabled"] = true, --Default is false I don't see why
    ["completion_worse.experimantal"] = true, --Default is false
    ["language_server_configuration.auto_config"] = false,
    ["language_server_worse_reflection.diagnostics.enable"] = true, --This stop all the error logging only when the language servers are also disabled
    ["language_server_worse_reflection.inlay_hints.enable"] = true, --Default false
    ["language_server_worse_reflection.inlay_hints.types"] = true, --Default false
    --Right now I'm utilizing diagnostics without a specified Language Server - Try determining if phpactor or psalm is worth it
    --Extra Extensions Added Below
    ["language_server_php_cs_fixer.enabled"] = true, --PSR standards
    ["php_code_sniffer.enabled"] = true, --Code standards
    ["prophecy.enabled"] = true, --Propechy is a mocking extension
    ["symfony.enabled"] = true,
    ["phpunit.enabled"] = true,
    --Errors --["blackfire.enabled"] = true, --Blackfire is performance monitoring
    --["behat.enabled"] = false, --Goto definition and completion support in fiels
  },
  handlers = {
    ["textDocument/hover"] = function() end, -- Override the vim.lsp.handler to remove the hover information from phpActor
  },
  capabilities = capabilities,
})
--LSP Intelephense (Alternative LSP)
lspconfig.intelephense.setup({
  settings = {
    intelephense = {
      diagnostics = {
        deprecated = false,
        undefinedVariables = false,
        undefinedMethods = false,
        duplicateSymbols = false,
      },
    },
  },
  debounce_text_changes = 150,
  capabilities = capabilities,
})

-- Dap (Setup in Plugins & Loaded With PHP Debugger Adapter Here)
local dap = require('dap')
require('dap').set_log_level('trace')
telescope.load_extension('dap')
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
    local fb = telescope.extensions.file_browser
    local live_grep = require("telescope.builtin").live_grep
    local current_line = action_state.get_current_line()
    local async_oneshot_finder = require "telescope.finders.async_oneshot_finder" --For Custom browse_folders Function
    local Path = require "plenary.path" --For Custom browse_folders Function
    fb.file_browser({
        files = false, --Disable to only use custom browse_folers function without predefined browse_files
        depth = 1,
        hidden = false,
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
                    return { command = "fd", args = { "--type", "directory", "--absolute-path", "--unrestricted", "--maxdepth", 1 } }
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
