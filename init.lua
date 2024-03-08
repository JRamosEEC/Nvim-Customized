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
        mappings = { --If this keybind ever doesn't work or similarly <C-s> good terminal flow control and remove it on the terminal
            n = {
                ["<C-q>"] = telescope_actions.send_to_qflist, -- + builtin.quickfixhistory()},
                ["<C-c>"] = telescope_actions.close,
                ["<C-n>"] = function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('a<C-n>', true, false, true), "i", false) end,
                ["<C-p>"] = function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('a<C-p>', true, false, true), "i", false) end,
                ["p"] = function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('a<C-r>"<C-c>', true, false, true), "i", false) end,
                ["P"] = function() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('i<C-r>"<C-c>', true, false, true), "i", false) end,
            },
            i = {
                ["<C-q>"] = telescope_actions.send_to_qflist, -- + builtin.quickfixhistory},
                ["<esc>"] = telescope_actions.close,
                ["<C-c>"] = function() vim.cmd("stopinsert") end,
            },
        },
    },
})
vim.keymap.set('n', '<leader>tt', '<cmd>Telescope<CR>', { desc = "Telescope", noremap = true }) --Keybind to open Telescope picker list
vim.keymap.set('n', '<leader>fl', builtin.quickfix, { desc = "Find Last Search", noremap = true }) --Keybind to open Telescope quick fix (The last saved search)
vim.keymap.set('n', '<leader>fh', builtin.quickfixhistory, { desc = "Find Search History", noremap = true }) --Keybind to open Telescope quick fix (The last saved search)

vim.keymap.set('n', '<leader>fb', function() -- Set default find buffer funcitonality to sort by last used and to ignore current
    builtin.buffers({ sort_mru = true, ignore_current_buffer = true}) --, sorter = require'telescope.sorters'.get_substr_matcher() })
end, {desc = "Find buffers (Sort Last-Used)", noremap = true})

-- ## LSP - (Two PHP LSP's for combined features e.g. completion snippets and deprecation messages)
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

-- File Browser & Find In Directory - For Fuzzy Finder (Slow With Large File Trees Like Ours)
local ts_select_dir_for_grep = function(prompt_bufnr)
    local action_state = require("telescope.actions.state")
    local fb = telescope.extensions.file_browser
    local live_grep = require("telescope.builtin").live_grep
    local current_line = action_state.get_current_line()
    local async_oneshot_finder = require "telescope.finders.async_oneshot_finder"
    local Path = require "plenary.path"
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
vim.keymap.set('n', '<leader>fd', ts_select_dir_for_grep, { desc = "Find Directories", noremap = true })

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

-- This Will Be Alot
local finders = require("telescope.finders") --Going to need these if I rewrite live_grep function
local make_entry = require("telescope.make_entry") --Going to need these if I rewrite live_grep function
local pickers = require("telescope.pickers") --Going to need these if I rewrite live_grep function
local sorters = require("telescope.sorters") --Going to need these if I rewrite live_grep function
local actions = require("telescope.actions") --Going to need these if I rewrite live_grep function
local conf = require("telescope.config").values
local Path = require "plenary.path"
local flatten = vim.tbl_flatten
local filter = vim.tbl_filter

local get_open_filelist = function(grep_open_files, cwd)
  if not grep_open_files then
    return nil
  end

  local bufnrs = filter(function(b)
    if 1 ~= vim.fn.buflisted(b) then
      return false
    end
    return true
  end, vim.api.nvim_list_bufs())
  if not next(bufnrs) then
    return
  end

  local filelist = {}
  for _, bufnr in ipairs(bufnrs) do
    local file = vim.api.nvim_buf_get_name(bufnr)
    table.insert(filelist, Path:new(file):make_relative(cwd))
  end
  return filelist
end

local opts_contain_invert = function(args)
  local invert = false
  local files_with_matches = false

  for _, v in ipairs(args) do
    if v == "--invert-match" then
      invert = true
    elseif v == "--files-with-matches" or v == "--files-without-match" then
      files_with_matches = true
    end

    if #v >= 2 and v:sub(1, 1) == "-" and v:sub(2, 2) ~= "-" then
      local non_option = false
      for i = 2, #v do
        local vi = v:sub(i, i)
        if vi == "=" then -- ignore option -g=xxx
          break
        elseif vi == "g" or vi == "f" or vi == "m" or vi == "e" or vi == "r" or vi == "t" or vi == "T" then
          non_option = true
        elseif non_option == false and vi == "v" then
          invert = true
        elseif non_option == false and vi == "l" then
          files_with_matches = true
        end
      end
    end
  end
  return invert, files_with_matches
end

-- Special keys:
--  opts.search_dirs -- list of directory to search in
--  opts.grep_open_files -- boolean to restrict search to open files
local live_grep_custom = function(opts)
  local vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
  local search_dirs = opts.search_dirs
  local grep_open_files = opts.grep_open_files
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()

  local filelist = get_open_filelist(grep_open_files, opts.cwd)
  if search_dirs then
    for i, path in ipairs(search_dirs) do
      search_dirs[i] = vim.fn.expand(path)
    end
  end

  local additional_args = {}
  if opts.additional_args ~= nil then
    if type(opts.additional_args) == "function" then
      additional_args = opts.additional_args(opts)
    elseif type(opts.additional_args) == "table" then
      additional_args = opts.additional_args
    end
  end

  if opts.type_filter then
    additional_args[#additional_args + 1] = "--type=" .. opts.type_filter
  end

  if type(opts.glob_pattern) == "string" then
    additional_args[#additional_args + 1] = "--glob=" .. opts.glob_pattern
  elseif type(opts.glob_pattern) == "table" then
    for i = 1, #opts.glob_pattern do
      additional_args[#additional_args + 1] = "--glob=" .. opts.glob_pattern[i]
    end
  end

  if opts.file_encoding then
    additional_args[#additional_args + 1] = "--encoding=" .. opts.file_encoding
  end

  local args = flatten { vimgrep_arguments, additional_args }
  opts.__inverted, opts.__matches = opts_contain_invert(args)

  local live_grepper = finders.new_job(function(prompt)
    if not prompt or prompt == "" then
      return nil
    end

    local search_list = {}

    if grep_open_files then
      search_list = filelist
    elseif search_dirs then
      search_list = search_dirs
    end

    return flatten { args, "--", prompt, search_list }
  end, opts.entry_maker or make_entry.gen_from_vimgrep(opts), opts.max_results, opts.cwd)

  local ok, msg = pcall(function()
    live_grepper('test123', 1, 1)
  end)
    print(ok)
    print(msg)

  --pickers
  --  .new(opts, {
  --    prompt_title = "Live Grep",
  --    finder = live_grepper,
  --    previewer = conf.grep_previewer(opts),
  --    sorter = sorters.highlighter_only(opts),
  --    attach_mappings = function(_, map)
  --      map("i", "<c-space>", actions.to_fuzzy_refine)
  --      return true
  --    end,
  --  })
  --  :find()
end

local test_background_grep = function(prompt_bufnr)
    local action_state = require("telescope.actions.state")
    local live_grep = require("telescope.builtin").live_grep
    local current_line = 'test'--action_state.get_current_line()
    --local entry_path = action_state.get_selected_entry().Path
    --local dir = entry_path:is_dir() and entry_path or entry_path:parent()
    --local relative = dir:make_relative(vim.fn.getcwd())
    --local absolute = dir:absolute()
    live_grep_custom({ default_text = current_line }) --results_title = relative .. "/", cwd = absolute,
end
vim.keymap.set('n', '<leader>ft', test_background_grep, { desc = "Grep Background", noremap = true })
