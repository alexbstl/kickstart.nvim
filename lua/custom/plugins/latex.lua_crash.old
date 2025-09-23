return {
  -- VimTeX
  {
    'lervag/vimtex',
    lazy = false,
    init = function()
      vim.g.tex_flavor = 'latex'
      vim.g.vimtex_compiler_method = 'latexmk'
      vim.g.vimtex_syntax_conceal_disable = 1
      vim.g.vimtex_complete_enabled = 1

      if vim.fn.has 'macunix' == 1 then
        vim.g.vimtex_view_method = 'skim'
        vim.g.vimtex_view_skim_sync = 1
        vim.g.vimtex_view_skim_activate = 1
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

          -- VimTeX omni completion + sane popup behavior
          vim.bo[ev.buf].omnifunc = 'vimtex#complete#omnifunc'
          vim.opt_local.completeopt = { 'menu', 'menuone', 'noinsert' }

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

          -- nvim-cmp (per-buffer; trigger on <C-x> so it doesn't clash with Neo-tree)
          local ok, cmp = pcall(require, 'cmp')
          if ok then
            local has_snip, luasnip = pcall(require, 'luasnip')
            cmp.setup.buffer {
              preselect = cmp.PreselectMode.Item,
              mapping = cmp.mapping.preset.insert {
                ['<C-x>'] = cmp.mapping.complete(),
                ['<C-e>'] = cmp.mapping.abort(),
                ['<CR>'] = cmp.mapping.confirm { select = true }, -- confirm only
                ['<Tab>'] = cmp.mapping(function(fb)
                  if cmp.visible() then
                    cmp.select_next_item()
                  elseif has_snip and luasnip.expand_or_jumpable() then
                    luasnip.expand_or_jump()
                  else
                    fb()
                  end
                end, { 'i', 's' }),
                ['<S-Tab>'] = cmp.mapping(function(fb)
                  if cmp.visible() then
                    cmp.select_prev_item()
                  elseif has_snip and luasnip.jumpable(-1) then
                    luasnip.jump(-1)
                  else
                    fb()
                  end
                end, { 'i', 's' }),
              },
              sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'omni' }, -- \begin{…}, \alpha, \cite, \ref, etc.
                { name = 'luasnip' },
              }, {
                { name = 'path' },
                { name = 'buffer' },
              }),
            }
          end

          ------------------------------------------------------------------
          -- Insert-mode "}" mapping (scheduled, deduped):
          -- After you type '}', if line ends with \begin{env}, insert a blank
          -- line + \end{env} below. Skips if one already exists.
          ------------------------------------------------------------------
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

              -- Confirm we really just typed "}" here
              local last = line:sub(col0, col0)
              if last ~= '}' then
                return
              end

              -- Text BEFORE cursor ends with \begin{env} ?
              local before = line:sub(1, col0)
              local env = before:match '\\begin{([^}]*)}$'
              if not env or env == '' then
                return
              end

              -- Avoid duplicates: if \end{env} already in next few lines, bail
              local esc = env:gsub('([^%w])', '%%%1')
              for i = 0, 4 do
                local nxt = safe_get_line(0, row1 + i)
                if nxt:match('^%s*\\end{' .. esc .. '}') then
                  return
                end
              end

              -- Insert blank + \end{env} and place cursor on the blank line
              local indent = line:match '^(%s*)' or ''
              vim.api.nvim_buf_set_lines(0, row1, row1, false, { '', indent .. '\\end{' .. env .. '}' })
              vim.api.nvim_win_set_cursor(0, { row1 + 1, #indent })
            end)
            return '}' -- the actual typed character
          end, { expr = true, buffer = ev.buf, desc = 'TeX: mirror \\end{…} after \\begin{…}' })

          ------------------------------------------------------------------
          -- Auto-trigger completion right after "\ref{" and "\cite{…}" families
          ------------------------------------------------------------------
          do
            -- label-like commands
            local ref_like = {
              ref = true,
              eqref = true,
              pageref = true,
              nameref = true,
              cref = true,
              Cref = true,
              autoref = true,
              vref = true,
              Vref = true,
            }
            -- citation-like commands (biblatex, natbib, etc.)
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
              -- insert '{' first, then inspect context & maybe trigger completion
              vim.schedule(function()
                local ok2, cmp2 = pcall(require, 'cmp')
                if not ok2 then
                  return
                end
                local pos = vim.api.nvim_win_get_cursor(0) -- {row1, col0}
                local col0 = pos[2]
                local line = vim.api.nvim_get_current_line()
                local before = line:sub(1, col0) -- includes the just-typed '{'
                local cmd = before:match '\\([A-Za-z]+){$' -- command name before '{'
                if not cmd then
                  return
                end
                if ref_like[cmd] or cite_like[cmd] then
                  cmp2.complete() -- VimTeX omni will list labels or bib keys
                end
              end)
              return '{'
            end, { expr = true, buffer = ev.buf, desc = 'Auto-complete after \\ref{/\\cite{' })
          end

          ------------------------------------------------------------------
          -- Citations helper: run biber/bibtex (auto-detect), then recompile
          ------------------------------------------------------------------
          local function detect_bib_backend(buf)
            -- Prefer explicit biblatex backend=biber; else fall back to file hints
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            for _, ln in ipairs(lines) do
              if ln:match '\\usepackage[^}]*{biblatex}' then
                if ln:match 'backend%s*=%s*biber' then
                  return 'biber'
                end
                return 'bibtex' -- biblatex but not explicitly biber
              end
            end
            -- If a .bcf exists -> biber; else default bibtex
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

            -- Save first to ensure aux files are fresh
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
                -- Rebuild twice to resolve cross-refs
                vim.schedule(function()
                  vim.cmd 'VimtexCompile'
                  vim.defer_fn(function()
                    vim.cmd 'VimtexCompile'
                  end, 300)
                end)
              end,
            })
          end

          -- Expose a user command and keymaps
          vim.api.nvim_create_user_command('LatexCitations', run_citations_then_build, {})
          map('<leader>lb', run_citations_then_build, 'LaTeX: Run biber/bibtex, then build twice')

          -- Quick clean + rebuild (helps after backend changes)
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

  -- Bridge VimTeX omni -> nvim-cmp
  { 'hrsh7th/cmp-omni', ft = { 'tex', 'bib', 'markdown' }, dependencies = { 'hrsh7th/nvim-cmp' } },

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

  -- LSP: ltex-ls with cmp capabilities
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
}
