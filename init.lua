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

-- Setup Global Notes & Note Taking
local global_note = require("global-note")
global_note.setup()
vim.keymap.set("n", "<leader>gn", global_note.toggle_note, { desc = "Global Notes", noremap = true })

--
-- ## Telescope
--
local telescope = require("telescope")
local telescope_actions = require("telescope.actions")
local builtin = require("telescope.builtin")
local action_state = require("telescope.actions.state")
local from_entry = require("telescope.from_entry")

-- Originally from grep preview
local parse_with_col = function(t)
    local _, _, filename, lnum, col, text = string.find(t.value, [[(..-):(%d+):(%d+):(.*)]])

    local ok
    ok, lnum = pcall(tonumber, lnum)
    if not ok then lnum = nil end
    ok, col = pcall(tonumber, col)
    if not ok then col = nil end

    t.filename = filename
    t.lnum = lnum
    t.col = col
    t.text = text
    return { filename, lnum, col, text }
end

local entry_to_qf_custom = function(entry)
    --vim.pretty_print(entry)
    local text = entry.text

    if not text then
        if type(entry.value) == "table" then
            --text = entry.value.text
        else
            -- text = entry.value -- This is the original, I don't think this will break anything but I'm going to assumed it is the combined values such as with grep proccess
            local parsedEntry = parse_with_col({ value = entry[1] })
            entry.filename = parsedEntry[1]
            entry.lnum = parsedEntry[2]
            entry.col = parsedEntry[3]
            --entry.text = parsedEntry[4]
        end
    end

    -- (Grep process parses after entry maker so it comes through as the original item)
    -- Plan of attack going to follow grep proccess
    return {
        bufnr = entry.bufnr,
        filename = from_entry.path(entry, false, false),
        lnum = vim.F.if_nil(entry.lnum, 1),
        col = vim.F.if_nil(entry.col, 1),
        --text = text,
        --type = entry.qf_type,
    }
end

local send_all_to_qf_custom = function(prompt_bufnr, mode, target)
    local picker = action_state.get_current_picker(prompt_bufnr)
    local manager = picker.manager

    local qf_entries = {}
    for entry in manager:iter() do
        table.insert(qf_entries, entry_to_qf_custom(entry))
    end
    --vim.pretty_print(qf_entries)

    local prompt = picker:_get_prompt()
    telescope_actions.close(prompt_bufnr)

    vim.api.nvim_exec_autocmds("QuickFixCmdPre", {})
    local qf_title = string.format([[%s (%s)]], picker.prompt_title, prompt)
    vim.fn.setqflist(qf_entries, mode)
    vim.fn.setqflist({}, "a", { title = qf_title })
    vim.api.nvim_exec_autocmds("QuickFixCmdPost", {})
end

telescope.setup({
    defaults = {
        mappings = {
            n = {
                ["<C-q>"] = function(prompt_bufnr) send_all_to_qf_custom(prompt_bufnr, " ") end, -- + builtin.quickfixhistory()},
                ["<C-c>"] = telescope_actions.close,
                ["<C-n>"] = function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('a<C-n>', true, false, true), "i", false) end,
                ["<C-p>"] = function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('a<C-p>', true, false, true), "i", false) end,
                ["p"] = function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('a<C-r>"<C-c>', true, false, true), "i", false) end,
                ["P"] = function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('i<C-r>"<C-c>', true, false, true), "i", false) end,
            },
            i = {
                --["<C-q>"] = telescope_actions.send_to_qflist, -- + builtin.quickfixhistory()},
                ["<C-q>"] = function(prompt_bufnr) send_all_to_qf_custom(prompt_bufnr, " ") end, -- + builtin.quickfixhistory()},
                ["<esc>"] = telescope_actions.close,
                ["<C-c>"] = function() vim.cmd("stopinsert") end,
            },
        },
    },
})
-- I'd like to add the previewer back to qflist this might be a similar solution to openning grep process results (Also need to optimize send_to_qflist)
vim.keymap.set('n', '<leader>tt', '<cmd>Telescope<CR>', { desc = "Telescope", noremap = true }) --Keybind to open Telescope picker list
vim.keymap.set('n', '<leader>tr', builtin.resume, { desc = "Telescope Resume", noremap = true }) --Keybind to resume Telescope finder
vim.keymap.set('n', '<leader>fl', builtin.quickfix, { desc = "Find Last Search", noremap = true }) --Keybind to open Telescope quick fix (The last saved search)
vim.keymap.set('n', '<leader>fh', function() builtin.quickfixhistory({previewer = false}) end, { desc = "Find Search History", noremap = true }) --Open Telescope quick fix (Saved searches) - Remove previewer quicker load
vim.keymap.set('n', '<leader>fb', function() -- Set default find buffer funcitonality to sort by last used and to ignore current
    builtin.buffers({ sort_mru = true, ignore_current_buffer = true}) --, sorter = require'telescope.sorters'.get_substr_matcher() })
end, {desc = "Find buffers (Sort Last-Used)", noremap = true})

-- File Browser & Find In Directory - For Fuzzy Finder (Slow With Large File Trees Like Ours)
local ts_select_dir_for_grep = function(prompt_bufnr)
    local fb = telescope.extensions.file_browser
    local live_grep = require("telescope.builtin").live_grep
    local current_line = action_state.get_current_line()
    local async_oneshot_finder = require "telescope.finders.async_oneshot_finder"
    local Path = require "plenary.path"
    fb.file_browser({
        files = false, --Disable to only use custom browse_folers function without predefined browse_files
        depth = 1,
        hidden = true,
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
vim.keymap.set('n', '<leader>fd', ts_select_dir_for_grep, { desc = "Find Directories", noremap = true })
vim.keymap.set('n', '<leader>fW', function() builtin.live_grep({ additional_args = function(opts) return {"-uu"} end }) end, { desc = "Live Grep All", noremap = true }) -- Live Grep Everything Included

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

---- Grep In Background Process - (Fix) The escape characters are wonky need 3 \\\ to escape \ I think it's lua string? Or maybe std_in
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")

local results = {}
local grepNotif = false
local g_notif_opts = { title = "Grep Proccess", timeout = 3000, render = "wrapped-compact", hide_from_history = true, on_close = function() grepNotif = false end }
function LiveGrep(query)
    results = {} -- Reset results on a new search
    local job_id = vim.fn.jobstart('rg --color=never --no-heading --with-filename --line-number --column --smart-case -uu ' .. query .. ' ./', {
        on_exit = function(job_id, code, event)
            g_notif_opts['timeout'] = 3000 -- Reset timeout on finish
            if grepNotif ~= false then
                g_notif_opts["replace"] = grepNotif
            end
            if (results[1] ~= nil and results[1] ~= '') then
                grepNotif = require('notify')("Grep Results Ready", "info", g_notif_opts)
            else
                grepNotif = require('notify')("Grep Results Empty", "info", g_notif_opts)
            end
        end,
        on_stdout = function(job_id, data, event)
            for k,v in pairs(data) do
                if (v ~= nil and v ~= '') then
                    table.insert(results, v)
                end
            end
            g_notif_opts["replace"] = nil -- Reset from previous Greps
            g_notif_opts['timeout'] = 30000 -- Set an extremely long timeout to not lose notif
            if grepNotif ~= false then
                g_notif_opts["replace"] = grepNotif
            end
            grepNotif = require('notify')("Grep Process Searching", "info", g_notif_opts)
        end,
        on_stderr = function(job_id, data, event)
            if grepNotif ~= false then
                g_notif_opts["replace"] = grepNotif
            end
            grepNotif = require('notify')("An Error Occured With Grep Process", "info", g_notif_opts)
        end, -- Do nothing just a reminder how it works
        pty = 1,
        detach = false,
    })
end
vim.cmd('command! -nargs=1 LiveGrep lua LiveGrep(<q-args>)') -- I want to find a cleaner way to do this
vim.keymap.set('n', '<leader>fp', ":LiveGrep ", { desc = "Grep Process (Run in background)", noremap = true, silent = true }) -- I'd like to find a way to do a pop up text box that takes the string

-- Wrapping vimgrep previewer to manipulate data individually rather than all at once with with vimgrep entry_maker (Freezes opening picker) - Calls to preview_fn are called prior to __index forwarding to original
local open_results = function()
    local vg_previewer = previewers.vim_buffer_vimgrep.new({})
    local wrapped_previewer = {
        orig_previewer = vg_previewer,
        --I could maybe intercept the construction and parse all. The entry maker made this slow I'm not sure if it was the parsing part. Though qflist will still be slow. I might just want to remove text from qflist
        preview_fn = function (self, entry, status) -- preview_fn called per highlited entry (Single grepped item) - instead of parsing all grep items only do current preview
            --vim.pretty_print(entry)
            local parsedEntry = parse_with_col({ value = entry[1] })
            entry.filename = parsedEntry[1]
            entry.lnum = parsedEntry[2]
            entry.col = parsedEntry[3]
            entry.text = parsedEntry[4]
            --vim.pretty_print(entry)
            vg_previewer.preview_fn(self, entry, status)
        end
    }
    setmetatable(wrapped_previewer, {
        __index = function(self, key)
            local originalMethod = wrapped_previewer.orig_previewer[key]
            if type(originalMethod) == "function" then
                return function(...)
                    return originalMethod(...)
                end
            else
                return originalMethod
            end
        end
    })
    pickers.new({}, {
        prompt_title = "Grep Results",
        finder = finders.new_table({ results = results }),
        previewer = wrapped_previewer,
    }):find()
end
vim.keymap.set('n', '<leader>fr', open_results, { desc = "Grep Background", noremap = true, silent = true }) -- I need to do a dedicated notification saying it's done (Thinking like a pop box pluging)

--
-- ## LSP - (Two PHP LSP's for combined features e.g. completion snippets and deprecation messages)
--
local lspconfig = require('lspconfig')
local cmp_lsp = require('cmp_nvim_lsp')
local capabilities = cmp_lsp.default_capabilities(vim.lsp.protocol.make_client_capabilities())
local window = require('lspconfig.ui.windows')

vim.keymap.set('n', '<leader>lo', vim.diagnostic.open_float, { desc = "Open Diagnostic Floating Window", noremap = true })
vim.keymap.set('n', ';', vim.diagnostic.open_float, { desc = "Open Diagnostic Floating Window", noremap = true }) --Giving this one an easy access keybind but keep both
vim.keymap.set('n', '<leader>lp', vim.diagnostic.goto_prev, { desc = "Go To Previous Diagnostic", noremap = true })
vim.keymap.set('n', '<leader>ln', vim.diagnostic.goto_next, { desc = "Go To Next Diagnostic", noremap = true })
vim.keymap.set('n', '<leader>ll', '<cmd>Telescope diagnositcs<cr>', { desc = "Open Diagnostic List", noremap = true })
vim.keymap.set('n', '<leader>ld', vim.lsp.buf.definition, { desc = "Go To Definition", noremap = true })
vim.keymap.set('n', '<leader>lD', vim.lsp.buf.declaration, { desc = "Go To Declaration (The interface)", noremap = true })
vim.keymap.set('n', '<leader>lr', vim.lsp.buf.references, { desc = "Display References", noremap = true })
vim.keymap.set('n', '<leader>lh', vim.lsp.buf.hover, { desc = "Show Var Information", noremap = true })

-- Removes the virtual text in-favor for opening the diagnostic floating window (Applies to all lsp's that attach unless overridden) -Note:I'm feeling out if I enjoy this
window.default_options.border = 'single'
vim.diagnostic.config {float = {border = 'single'}}
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
    vim.lsp.handlers.hover, { border = "single", focusable = false, title = "Details" }
)
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics, { virtual_text = false, underline = true, float = {border = 'single'} }
)

local lspNotif = false
function NotifyDiagnostic() -- Need to be able to adjust width with replace or prematurely close then open another notif but neither is a feature yet
    local lineDiagnostic = vim.lsp.diagnostic.get_line_diagnostics()
    if (lineDiagnostic[1] ~= nil and lineDiagnostic[1] ~= '') then
        local dMsg = lineDiagnostic[1].message
        local notif_opts = { title = "Diagnostics", timeout = 2500, render = "wrapped-compact", hide_from_history = true, on_close = function() lspNotif = false end }
        if lspNotif ~= false then
            notif_opts["replace"] = lspNotif
        end
        lspNotif = require('notify')(dMsg, "info", notif_opts)
    end
end
--vim.o.updatetime = 250 --Wondering if maybe I can make a corner window or something that's out of the way but will open seperately
--vim.api.nvim_command('autocmd CursorHold * :lua NotifyDiagnostic()')--lua vim.diagnostic.open_float()') --It messes up the vim.lsp.buf.hover (Also Idk it might get in the way auto popping up)

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
-- LSP Intelephense (Alternative LSP)
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

--
-- ## Dap (Setup in Plugins & Loaded With PHP Debugger Adapter Here)
--
local getPathMap = function() -- Get current path & convert to PathMap (Current path without first 3 /home/jramos/devSys)
    local skipped = 0
    local pathMap = ''
    for part in string.gmatch(vim.fn.getcwd(), "[^/]+") do
        if skipped >= 3 then
            pathMap = pathMap .. '/' .. part
        else
            skipped = skipped + 1
        end
    end
    return pathMap
end
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
      ["/home/justin" .. getPathMap()] = "${workspaceFolder}", --['/home/justin/sandbox/dev/zf2'] = "${workspaceFolder}",
    },
    stopOnEntry = false,
    xdebugSettings = {
      ["max_data"] = -1,
    }
  }
}
-- Change PathMap on the fly & auto restart dap (Leave PathMap command example/override, autocmd should be automatically run on DirChanged)
local restartDap = function()
  require('dap').disconnect()
  require('dap').close()
  require('dap').continue()
end
vim.api.nvim_create_user_command("PathMap", function(args)
    if (args['args']) then
      dap.configurations.php[1].pathMappings = { ["/home/justin/sandbox/dev" .. string.lower(args['args'])] = "${workspaceFolder}" }
      restartDap()
    end
end, {nargs='*'})
vim.api.nvim_create_autocmd('DirChanged', {
    callback = function()
      dap.configurations.php[1].pathMappings = { ["/home/justin" .. getPathMap()] = "${workspaceFolder}" }
      require('dap').disconnect()
      require('dap').close()
      --restartDap() --Quirky bug right now if changing with another buffer like telescope it tries to run a dap for that buffer
    end,
})
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
