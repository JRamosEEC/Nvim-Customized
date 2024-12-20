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

-- ### Custom Config ### ---

-- Experiment with dvorak for now --
--vim.opt.keymap = 'dvorak'

-- Relative Line Number By Default
vim.opt.relativenumber = true

-- Custom Yank Current File Name
vim.keymap.set('n', '<leader>yc', function() vim.fn.setreg("+", vim.fn.expand("%:p")) end, { desc = "Yank Current Filename", noremap = true })

-- Setup Global Notes & Note Taking
local global_note = require("global-note")
global_note.setup()
vim.keymap.set("n", "<leader>gn", global_note.toggle_note, { desc = "Global Notes", noremap = true })

--
-- ## Telescope
--
local telescope = require("telescope")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local make_entry = require("telescope.make_entry")
local telescope_actions = require("telescope.actions")
local builtin = require("telescope.builtin")
local action_set = require("telescope.actions.set")
local action_state = require("telescope.actions.state")
local from_entry = require("telescope.from_entry")

local parse_with_col = function(t) -- Originally from grep preview
    local _, _, filename, lnum, col = string.find(t.value, [[(..-):(%d+):(%d+):(.*)]])
    local ok
    ok, lnum = pcall(tonumber, lnum)
    if not ok then lnum = 1 end
    ok, col = pcall(tonumber, col)
    if not ok then col = 1 end
    return { filename, lnum, col }
end
local entry_to_qf_custom = function(entry)
    if not entry.text and type(entry[1]) == "string" and type(entry.value) ~= "table" then
        entry.filename, entry.lnum, entry.col = parse_with_col({ value = entry[1] })
    end
    return { filename = from_entry.path(entry, false, false), lnum = entry.lnum, col = entry.col }
end

-- I think when I get the chance I'll implement the parsing computation and the array or stack storage computation in rust and query it like an lsp would (Interfacing it like a server)
-- Vimscript qflist is expecting pre-parsed data for every entries filename,lnum,col,text - I'd rather do it one per viewed entry in the previewer (Made compatible with normal qflist functions)
local customQflist = {}
local send_all_to_qf_custom = function(prompt_bufnr, mode, experimental)
    local picker = action_state.get_current_picker(prompt_bufnr)
    local manager = picker.manager
    local prompt = picker:_get_prompt()

    if (experimental == true) then
        local qf_title = string.format([[%s (%s)]], picker.prompt_title, prompt)
        customQflist[qf_title] = {}
        for entry in manager:iter() do
            if not entry.text then
                table.insert(customQflist[qf_title], entry[1]) -- It's raw text make sure not to grab any meta
            else
                table.insert(customQflist[qf_title], entry) -- It's already parsed store it
            end
        end
        telescope_actions.close(prompt_bufnr)
    else
        local qf_entries = {}
        for entry in manager:iter() do
            table.insert(qf_entries, entry_to_qf_custom(entry)) -- The normal Qflist is expecting data like col, lnum, etc so parse it out of custom grep data
        end
        telescope_actions.close(prompt_bufnr)
        vim.api.nvim_exec_autocmds("QuickFixCmdPre", {})
        vim.fn.setqflist(qf_entries, mode)
        vim.fn.setqflist({}, "a", { title = string.format([[%s (%s)]], picker.prompt_title, prompt) })
        vim.api.nvim_exec_autocmds("QuickFixCmdPost", {})
    end
end

local open_custom_qflist = function(key)
    if customQflist[key] == nil or vim.tbl_isempty(customQflist[key]) then
        return
    end

    local entry_maker = nil
    local wrapped_previewer = nil
    if not customQflist[key][1].text then
        local qfCustom_previewer = previewers.vim_buffer_qflist.new({}) -- Exactly the same as vimgrep previewer in telescope
        wrapped_previewer = {
            orig_previewer = qfCustom_previewer,
            preview_fn = function (self, entry, status) -- preview_fn called per highlighted entry (Single grepped item)
                local parsedEntry = parse_with_col({ value = entry[1] })
                entry.filename = parsedEntry[1]
                entry.lnum = parsedEntry[2]
                entry.col = parsedEntry[3]
                qfCustom_previewer.preview_fn(self, entry, status)
            end
        }
        setmetatable(wrapped_previewer, {
            __index = function(self, key)
                local originalMethod = wrapped_previewer.orig_previewer[key]
                if type(originalMethod) == "function" then
                    return function(...)
                        return originalMethod(...)
                    end
                end
                return originalMethod
            end
        })
    else
        wrapped_previewer = previewers.vim_buffer_qflist.new({})
        entry_maker = make_entry.gen_from_quickfix({})
    end
    pickers.new({}, {
        prompt_title = "Custom Qflist",
        finder = finders.new_table({ results = customQflist[key], entry_maker = entry_maker }),
        previewer = wrapped_previewer,
        sorter = conf.generic_sorter({}),
    }):find()
end
local open_custom_qflist_history = function()
    local qf_keys = {}
    for k,v in pairs(customQflist) do
        table.insert(qf_keys, k)
    end
    pickers.new({}, {
        prompt_title = "Custom Qflist History",
        finder = finders.new_table({ results = qf_keys }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(_, map)
            action_set.select:replace(function(prompt_bufnr)
                local key = action_state.get_selected_entry()[1]
                telescope_actions.close(prompt_bufnr)
                open_custom_qflist(key)
            end)
            return true
        end,
    }):find()
end
vim.keymap.set('n', '<leader>fh', function() open_custom_qflist_history() end, { desc = "Find Search History", noremap = true }) -- Open custom qflist (Now Default usage keybind)

telescope.setup({
    defaults = {
        mappings = {
            n = {
                ["<C-q>"] = function(prompt_bufnr) send_all_to_qf_custom(prompt_bufnr, " ", true) end, -- Use custom "qflist" really just a store of raw result of searching in array and parse when previewing
                ["<C-e>"] = function(prompt_bufnr) send_all_to_qf_custom(prompt_bufnr, " ") end, -- The original qf list functionality (Moved from my default usage keybind in favor of more efficient custom save list)
                ["<C-c>"] = telescope_actions.close,
                ["<C-n>"] = function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('a<C-n>', true, false, true), "i", false) end,
                ["<C-p>"] = function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('a<C-p>', true, false, true), "i", false) end,
                ["p"] = function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('a<C-r>"<C-c>', true, false, true), "i", false) end,
                ["P"] = function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('i<C-r>"<C-c>', true, false, true), "i", false) end,
            },
            i = {
                ["<C-q>"] = function(prompt_bufnr) send_all_to_qf_custom(prompt_bufnr, " ", true) end,
                ["<C-e>"] = function(prompt_bufnr) send_all_to_qf_custom(prompt_bufnr, " ") end,
                ["<esc>"] = telescope_actions.close,
                ["<C-c>"] = function() vim.cmd("stopinsert") end,
            },
        },
    },
})
vim.keymap.set('n', '<leader>tt', '<cmd>Telescope<CR>', { desc = "Telescope", noremap = true }) --Keybind to open Telescope picker list
vim.keymap.set('n', '<leader>tr', builtin.resume, { desc = "Telescope Resume", noremap = true }) --Keybind to resume Telescope finder
vim.keymap.set('n', '<leader>fl', builtin.quickfix, { desc = "Find Last Search", noremap = true }) --Keybind to open Telescope quick fix (The last saved search)
vim.keymap.set('n', '<leader>fH', function() builtin.quickfixhistory({previewer = false}) end, { desc = "Find Search History", noremap = true }) -- Open Telescope original quick fix list (Saved searches) - Removed previewer quicker load
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
vim.keymap.set('n', '<leader>fw', function() builtin.live_grep({
    additional_args = function(opts)
        return { { "-o", "--no-binary", "--max-filesize=295K" } }
    end,
    glob_pattern = { "!*.min.{js,css,js.map,css.map}", "!public/js/jquery*", "!wordpress/wp-includes/*", "!wordpress/wp-admin/*", "!wordpress/wp-content/plugins/*", "!migrations/*/seeds/*" },
}) end, { desc = "Live Grep", noremap = true })
vim.keymap.set('n', '<leader>fW', function() builtin.live_grep({
    additional_args = function(opts)
        return { { "-uu", "-o", "--no-binary", "--max-filesize=295K" } }
    end,
    glob_pattern = { "!*.min.{js,css,js.map,css.map}", "!public/js/jquery*", "!wordpress/wp-includes/*", "!wordpress/wp-admin/*", "!wordpress/wp-content/plugins/*", "!migrations/*/seeds/*" },
}) end, { desc = "Live Grep All", noremap = true }) -- Live Grep Everything Included

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


--Updates
-- I'm probably going to have re-write my own Printer type classs
-- I'm not sure how I'm going to deal with the fact the search_worker requires a term color implemented class
-- Either I can work with it to create a mutable object
-- Otherwise I'll have to create my own search_worker function that can somehow run a builder without a term color type Printer

--Goals -
-- I created a RCP Protocol App and I cloned ripgrep.
-- Somehow I need to call a grep matcher/regex/searcher/whatever
-- I need to set the "Printer" to take the results and store them in my RCP application
-- This application will then manage parsing & fetching when needed

---- Grep In Background Process - (Fix) The escape characters are wonky need 3 \\\ to escape \ I think it's lua string? Or maybe std_in
local queryText = ""
local results = {}
local grepNotif = false
local g_notif_opts = { title = "Grep Proccess", timeout = 3000, render = "wrapped-compact", hide_from_history = true, on_close = function() grepNotif = false end }
function LiveGrep(query, flag) --I'm leaving the idea of flags here because it could be handy
    results = {} -- Reset results on a new search
    queryText = query -- Save the query text as an identifier to each search
    local job_id = vim.fn.jobstart("rg --vimgrep --glob '!*.min.{js,css,js.map,css.map}' --glob '!public/js/jquery*' --glob '!wordpress/wp-includes/*' --glob '!wordpress/wp-admin/*' --glob '!wordpress/wp-content/plugins/*' --glob '!migrations/*/seeds/*' --max-filesize 295K -o --color=never --no-heading --with-filename --line-number --column --smart-case --no-binary --no-search-zip -uu " .. query .. " ./", {
        on_exit = function(job_id, code, event)
            g_notif_opts['timeout'] = 3000 -- Reset timeout on finish
            if grepNotif ~= false then
                g_notif_opts["replace"] = grepNotif
            end
            if not vim.tbl_isempty(results) then
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
            g_notif_opts['timeout'] = 3000 -- Reset timeout on finish
            if grepNotif ~= false then
                g_notif_opts["replace"] = grepNotif
            end
            grepNotif = require('notify')("An Error Occured With Grep Process", "info", g_notif_opts)
        end,
        pty = 1,
        detach = false,
    })
end
vim.cmd('command! -nargs=* LiveGrep lua LiveGrep(<f-args>)')
vim.keymap.set('n', '<leader>fp', ":LiveGrep ", { desc = "Grep Process (Run in background)", noremap = true, silent = true })

-- Wrap vimgrep previewer to manipulate data individually rather than all at once with with entry_maker  - (wrapped preview_fn called prior to __index -> originalFN)
local open_results = function()
    local vg_previewer = previewers.vim_buffer_vimgrep.new({})
    local wrapped_previewer = {
        orig_previewer = vg_previewer,
        preview_fn = function (self, entry, status) -- preview_fn called per highlighted entry (Single grepped item)
            local parsedEntry = parse_with_col({ value = entry[1] })
            entry.filename = parsedEntry[1]
            entry.lnum = parsedEntry[2]
            entry.col = parsedEntry[3]
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
            end
            return originalMethod
        end
    })
    pickers.new({}, {
        prompt_title = "Grep Proccess Results (" .. queryText .. ") - Sorting",
        finder = finders.new_table({ results = results }),
        previewer = wrapped_previewer,
        sorter = conf.generic_sorter({}),
    }):find()
    --local entry_maker = make_entry.gen_from_string({}) local wrap_entry_maker = function(line) return entry_maker(line) end -- I don't need the entry maker wrapper right now but keep this incase I might later
end
vim.keymap.set('n', '<leader>fr', open_results, { desc = "Grep Background", noremap = true, silent = true })

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
  filetypes = { "php", "phtml" }, --Removing phtml here doesn't work (Actually none of these work when debugging lspconfig there are two after with php patterns that might be the clue)
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
    --["language_server_php_cs_fixer.enabled"] = true, --PSR standards -- Package doesn't exist need to install
    --["php_code_sniffer.enabled"] = true, --Code standards -- Package doesn't exist need to install
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
      files = {
        maxSize = 10000000,
      },
    },
  },
  debounce_text_changes = 150,
  capabilities = capabilities,
})

--Set Clang LSP
local cmp_nvim_lsp = require "cmp_nvim_lsp"
lspconfig.clangd.setup({
    on_attach = on_attach,
    capabilities = cmp_nvim_lsp.default_capabilities(),
    cmd = {
        "clangd",
        "--offset-encoding=utf-16"
    },
})

--Set Rust Analyze
lspconfig.rust_analyzer.setup({})

-- Dap (Setup in Plugins & Loaded With PHP Debugger Adapter Here)
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

-- PHP Debug Adapter & Config
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

-- Rust Debug Adapter & Config
dap.adapters.lldb = {
    type = "server",
    port = "${port}",
    executable = {
        command = "lldb-vscode",
        args = {"--port", "${port}"}
    }
}
dap.configurations.rust = {
    {
        type = 'lldb',
        request = "launch",
        name = "Rust Debug",
        program = function()
            local projName = vim.fn.input('Project Name: ')
            local projDir = vim.fn.getcwd() .. '/rust/' .. projName
            vim.fn.jobstart('cargo build --manifest-path=' .. projDir .. '/Cargo.toml')
            return projDir .. '/target/debug/' .. projName
        end,
        args = {'debug'},
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
    }
}

-- C Debug Adapter & Config (At some point)

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
-- Dap Keybinds - (looin into dap.up() & dap.down() and figure out good keybings for quick stck traversal)
vim.keymap.set('n', '<F2>', function() require('dap').step_over() end)
vim.keymap.set('n', '<F3>', function() require('dap').step_into() end)
vim.keymap.set('n', '<F4>', function() require('dap').step_out() end)
vim.keymap.set('n', '<F5>', function() require('dap').continue() end)
vim.keymap.set('n', '<F6>', function() require('dap').close() end)
vim.keymap.set('n', '<F9>', function() require('dap').run_to_cursor() end)
vim.keymap.set('n', '<F10>', function() require('dap').toggle_breakpoint() end)

-- Rust Testing
--./rust/search-history/target/debug/search-history

-- RPC Messages

local debugFn = function(job_id, data, event)
    vim.pretty_print({jobId = job_id, data = data, event = event})
end

local rgExe = './rust/search-history/target/debug/search-history'
local rgArgs = {
    "--vimgrep",
    "-o",
    "-uu",
    "--column",
    "--no-binary",
    "--no-heading",
    "--smart-case",
    "--line-number",
    "--with-filename",
    "--no-search-zip",
    "--color=never",
    "--max-filesize=295K",
    "--glob='!*.min.{js,css,js.map,css.map}'",
    "--glob='!public/js/jquery*'",
    "--glob='!wordpress/wp-includes/*'",
    "--glob='!wordpress/wp-admin/*'",
    "--glob='!wordpress/wp-content/plugins/*'",
    "--glob='!migrations/*/seeds/*'",
}
local searchHistoryJobId = vim.fn.jobstart({ rgExe, unpack(rgArgs) }, {
    rpc = true,
    on_exit = debugFn,
    on_stdout = debugFn,
    on_stderr = debugFn
})

function rustGrep(search)
    vim.rpcnotify(searchHistoryJobId, 'search', search)
end
function close()
    vim.fn.jobclose(searchHistoryJobId)
end
vim.cmd('command! -nargs=+ RustGrep lua rustGrep(<f-args>)')
vim.cmd('command! -nargs=+ Close lua close(<f-args>)')

vim.keymap.set('n', '<leader>rg', ":RustGrep ", { desc = "Grep Process (Run in background)", noremap = true, silent = true })
