return {
  -- VimTeX
  {
    'lervag/vimtex',
    lazy = false,
    init = function()
      vim.g.tex_flavor = 'latex'
      vim.g.vimtex_compiler_method = 'latexmk'
      vim.g.vimtex_compiler_latexmk = {
        executable = 'latexmk',
        continuous = 1,
        callback = 1,
        options = { '-pdf', '-interaction=nonstopmode', '-synctex=1' },
      }
      vim.g.vimtex_syntax_conceal_disable = 1
      vim.g.vimtex_complete_enabled = 1

      if vim.fn.has 'macunix' == 1 then
        vim.g.vimtex_view_method = 'skim'
        vim.g.vimtex_view_skim_sync = 1
        vim.g.vimtex_view_skim_activate = 1
        vim.g.vimtex_view_automatic = 1
      else
        vim.g.vimtex_view_method = 'okular'
      end

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'tex',
        callback = function(ev)
          local map = function(lhs, rhs, desc)
            vim.keymap.set('n', lhs, rhs, { buffer = ev.buf, silent = true, desc = desc })
          end

          map('<leader>lc', '<cmd>VimtexCompile<CR>', 'LaTeX: Compile')
          map('<leader>lv', '<cmd>VimtexView<CR>', 'LaTeX: Forward search')
          map('<leader>lf', '<cmd>VimtexView<CR>', 'LaTeX: Forward search')
          map('<leader>lF', function()
            vim.cmd 'VimtexCompile'
            vim.defer_fn(function()
              vim.cmd 'VimtexView'
            end, 200)
          end, 'LaTeX: Compile then forward search')

          -- VimTeX omni completion. cmp-omni reads this buffer omnifunc and blink.compat
          -- bridges the resulting 'omni' source into blink.cmp (see the blink spec below),
          -- so \begin{…}, \alpha, \cite, \ref, etc. complete through blink.
          vim.bo[ev.buf].omnifunc = 'vimtex#complete#omnifunc'

          -- Stop auto-reindent on "}" (esp. in display math)
          do
            local ik = vim.opt_local.indentkeys:get()
            local filtered = {}
            for _, k in ipairs(ik) do
              if k ~= '}' and k ~= '0}' then
                table.insert(filtered, k)
              end
            end
            vim.opt_local.indentkeys = filtered
          end

          -- Insert-mode "}" mapping → auto-add \end{env}
          local function safe_get_line(buf, idx0)
            local lc = vim.api.nvim_buf_line_count(buf)
            if idx0 < 0 or idx0 >= lc then
              return ''
            end
            return vim.api.nvim_buf_get_lines(buf, idx0, idx0 + 1, false)[1] or ''
          end

          vim.keymap.set('i', '}', function()
            vim.schedule(function()
              local pos = vim.api.nvim_win_get_cursor(0) -- {row1, col0}
              local row1, col0 = pos[1], pos[2]
              local line = vim.api.nvim_get_current_line()
              local last = line:sub(col0, col0)
              if last ~= '}' then
                return
              end
              local before = line:sub(1, col0)
              local env = before:match '\\begin{([^}]*)}$'
              if not env or env == '' then
                return
              end

              local esc = env:gsub('([^%w])', '%%%1')
              for i = 0, 4 do
                local nxt = safe_get_line(0, row1 + i)
                if nxt:match('^%s*\\end{' .. esc .. '}') then
                  return
                end
              end

              local indent = line:match '^(%s*)' or ''
              vim.api.nvim_buf_set_lines(0, row1, row1, false, { '', indent .. '\\end{' .. env .. '}' })
              vim.api.nvim_win_set_cursor(0, { row1 + 1, #indent })
            end)
            return '}'
          end, { expr = true, buffer = ev.buf, desc = 'TeX: mirror \\end{…} after \\begin{…}' })

          -- Auto-trigger completion after \ref{ / \cite{
          do
            local ref_like = { ref = true, eqref = true, pageref = true, nameref = true, cref = true, Cref = true, autoref = true, vref = true, Vref = true }
            local cite_like = {
              cite = true,
              Cite = true,
              nocite = true,
              parencite = true,
              Parencite = true,
              textcite = true,
              Textcite = true,
              footcite = true,
              Footcite = true,
              supercite = true,
              autocite = true,
              Autocite = true,
              smartcite = true,
              Smartcite = true,
              citet = true,
              citep = true,
              Citep = true,
              Citet = true,
              citeauthor = true,
              Citeauthor = true,
              citeyear = true,
              Citeyear = true,
              citeyearpar = true,
              Citeyearpar = true,
            }
            vim.keymap.set('i', '{', function()
              vim.schedule(function()
                local ok2, blink = pcall(require, 'blink.cmp')
                if not ok2 then
                  return
                end
                local col0 = vim.api.nvim_win_get_cursor(0)[2]
                local before = vim.api.nvim_get_current_line():sub(1, col0)
                local cmd = before:match '\\([A-Za-z]+){$'
                if cmd and (ref_like[cmd] or cite_like[cmd]) then
                  blink.show()
                end
              end)
              return '{'
            end, { expr = true, buffer = ev.buf, desc = 'Auto-complete after \\ref{/\\cite{' })
          end

          -- Citations helper: run biber/bibtex, then rebuild twice
          local function detect_bib_backend(buf)
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            for _, ln in ipairs(lines) do
              if ln:match '\\usepackage[^}]*{biblatex}' then
                if ln:match 'backend%s*=%s*biber' then
                  return 'biber'
                end
                return 'bibtex'
              end
            end
            if not vim.b.vimtex or not vim.b.vimtex.tex or not vim.b.vimtex.root then
              return 'bibtex'
            end
            local jobname = vim.fn.fnamemodify(vim.b.vimtex.tex, ':t:r')
            if vim.uv.fs_stat(vim.fs.joinpath(vim.b.vimtex.root, jobname .. '.bcf')) then
              return 'biber'
            end
            return 'bibtex'
          end

          local function run_citations_then_build()
            if not vim.b.vimtex or not vim.b.vimtex.root or not vim.b.vimtex.tex then
              vim.notify('VimTeX not initialized for this buffer', vim.log.levels.WARN)
              return
            end
            local backend = detect_bib_backend(0)
            local root = vim.b.vimtex.root
            local jobname = vim.fn.fnamemodify(vim.b.vimtex.tex, ':t:r')
            vim.cmd 'silent write'
            local cmd = (backend == 'biber') and { 'biber', jobname } or { 'bibtex', jobname }
            vim.notify(('Running %s…'):format(table.concat(cmd, ' ')))
            vim.fn.jobstart(cmd, {
              cwd = root,
              stdout_buffered = true,
              stderr_buffered = true,
              on_stderr = function(_, data)
                if data and #data > 0 then
                  vim.notify(table.concat(data, '\n'), vim.log.levels.WARN)
                end
              end,
              on_exit = function(_, code)
                if code ~= 0 then
                  vim.notify(('(%s) exited with code %d'):format(cmd[1], code), vim.log.levels.ERROR)
                  return
                end
                vim.schedule(function()
                  vim.cmd 'VimtexCompile'
                  vim.defer_fn(function()
                    vim.cmd 'VimtexCompile'
                  end, 300)
                end)
              end,
            })
          end

          vim.api.nvim_create_user_command('LatexCitations', run_citations_then_build, {})
          map('<leader>lb', run_citations_then_build, 'LaTeX: Run biber/bibtex, then build twice')

          map('<leader>lC', function()
            vim.cmd 'VimtexClean'
            vim.defer_fn(function()
              vim.cmd 'VimtexCompile'
            end, 150)
          end, 'LaTeX: Clean aux and recompile')
        end,
      })
    end,
  },

  -- Bridge VimTeX's omnifunc (\ref, \cite, \begin{…}, \alpha, …) into blink.cmp.
  -- cmp-omni registers an 'omni' source into nvim-cmp's registry (nvim-cmp is kept
  -- installed purely as that registry/library — it is NOT set up as an active engine).
  -- blink.compat then exposes that registered source to blink, our single completion UI.
  { 'hrsh7th/cmp-omni', ft = { 'tex', 'bib', 'markdown' }, dependencies = { 'hrsh7th/nvim-cmp' } },
  { 'saghen/blink.compat', version = '*', lazy = true, opts = {} },
  {
    'saghen/blink.cmp',
    dependencies = { 'saghen/blink.compat', 'hrsh7th/cmp-omni' },
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      opts.sources.providers = opts.sources.providers or {}
      opts.sources.providers.omni = {
        name = 'omni',
        module = 'blink.compat.source',
        score_offset = 100, -- prefer vimtex's \cite/\ref/\begin items in TeX
      }
      opts.sources.per_filetype = opts.sources.per_filetype or {}
      for _, ft in ipairs { 'tex', 'bib', 'markdown' } do
        opts.sources.per_filetype[ft] = { 'omni', 'lsp', 'path', 'snippets', 'buffer' }
      end
      return opts
    end,
  },

  -- Disable autopairs in TeX to avoid brace/regex conflicts
  {
    'windwp/nvim-autopairs',
    opts = function(_, opts)
      opts = opts or {}
      opts.map_cr = false
      local disabled = opts.disable_filetype or {}
      if type(disabled) ~= 'table' then
        disabled = {}
      end
      local seen = {}
      for _, ft in ipairs(disabled) do
        seen[ft] = true
      end
      if not seen['tex'] then
        table.insert(disabled, 'tex')
      end
      opts.disable_filetype = disabled
      return opts
    end,
  },

  -- LSP: ltex-ls with cmp capabilities (you can comment this block out if Java/ltex is heavy)
  {
    'neovim/nvim-lspconfig',
    dependencies = { 'hrsh7th/cmp-nvim-lsp' },
    opts = function(_, opts)
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local ok, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
      if ok then
        capabilities = cmp_lsp.default_capabilities(capabilities)
      end
      opts.servers = opts.servers or {}
      opts.servers.ltex = vim.tbl_deep_extend('force', opts.servers.ltex or {}, {
        capabilities = capabilities,
        filetypes = { 'tex', 'bib', 'markdown' },
        settings = {
          ltex = {
            language = 'en-US',
            additionalRules = { enablePickyRules = true },
            completion = { enabled = true },
          },
        },
      })
    end,
  },

  -- Ensure "\" never toggles Neo-tree; keep <C-Space> as the toggle
  {
    'nvim-neo-tree/neo-tree.nvim',
    init = function()
      vim.api.nvim_create_autocmd('User', {
        pattern = 'VeryLazy',
        callback = function()
          pcall(vim.keymap.del, 'n', '\\')
          vim.keymap.set('n', '\\', '<Nop>', { noremap = true, silent = true })
          pcall(vim.keymap.del, 'n', '<Leader>\\')
          vim.keymap.set('n', '<C-Space>', '<Cmd>Neotree toggle<CR>', { silent = true })
          vim.keymap.set('n', '<C-@>', '<Cmd>Neotree toggle<CR>', { silent = true })
        end,
      })
    end,
  },

  ---------------------------------------------------------------------------
  -- Treesitter: keep TS globally, but *disable for LaTeX/BibTeX* and enable
  -- classic Vim regex highlighting for those filetypes via VimTeX.
  ---------------------------------------------------------------------------
  {
    'nvim-treesitter/nvim-treesitter',
    opts = function(_, opts)
      opts = opts or {}
      opts.highlight = opts.highlight or {}
      opts.indent = opts.indent or {}

      -- Never auto-install the latex/bibtex parsers: we use vim regex highlighting for
      -- those filetypes, and the latex parser additionally requires the tree-sitter CLI
      -- to build (which would error on `auto_install` when opening a .tex file).
      local ignore = opts.ignore_install or {}
      for _, ft in ipairs { 'latex', 'bibtex' } do
        if not vim.tbl_contains(ignore, ft) then
          ignore[#ignore + 1] = ft
        end
      end
      opts.ignore_install = ignore

      -- disable TS highlighting/indent for latex & bibtex
      local disable_list = {}
      for _, v in ipairs(opts.highlight.disable or {}) do
        disable_list[#disable_list + 1] = v
      end
      if not vim.tbl_contains(disable_list, 'latex') then
        disable_list[#disable_list + 1] = 'latex'
      end
      if not vim.tbl_contains(disable_list, 'bibtex') then
        disable_list[#disable_list + 1] = 'bibtex'
      end
      opts.highlight.disable = disable_list

      local indent_disable = {}
      for _, v in ipairs(opts.indent.disable or {}) do
        indent_disable[#indent_disable + 1] = v
      end
      if not vim.tbl_contains(indent_disable, 'latex') then
        indent_disable[#indent_disable + 1] = 'latex'
      end
      opts.indent.disable = indent_disable

      -- keep regex highlighting for LaTeX/BibTeX so you still get syntax
      local add_regex = opts.highlight.additional_vim_regex_highlighting
      if add_regex == nil then
        add_regex = {}
      end
      if add_regex == true then
        add_regex = {}
      end
      if type(add_regex) ~= 'table' then
        add_regex = {}
      end
      if not vim.tbl_contains(add_regex, 'latex') then
        add_regex[#add_regex + 1] = 'latex'
      end
      if not vim.tbl_contains(add_regex, 'bibtex') then
        add_regex[#add_regex + 1] = 'bibtex'
      end
      opts.highlight.additional_vim_regex_highlighting = add_regex

      return opts
    end,
  },
}
