return {
  {
    'hrsh7th/nvim-cmp',
    opts = function(_, opts)
      local cmp = require 'cmp'
      local has_luasnip, luasnip = pcall(require, 'luasnip')

      opts = opts or {}

      -- Ensure the popup shows and preselects an item
      vim.opt.completeopt = { 'menu', 'menuone', 'noinsert' }
      opts.preselect = cmp.PreselectMode.Item

      -- Make confirm + navigation sane
      opts.mapping = cmp.mapping.preset.insert {
        ['<C-n>'] = cmp.mapping.select_next_item(),
        ['<C-p>'] = cmp.mapping.select_prev_item(),
        ['<Down>'] = cmp.mapping.select_next_item(),
        ['<Up>'] = cmp.mapping.select_prev_item(),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-e>'] = cmp.mapping.abort(),
        ['<CR>'] = cmp.mapping.confirm { select = true }, -- Enter accepts current item
        ['<C-y>'] = cmp.mapping.confirm { select = true }, -- optional second confirm
        ['<Tab>'] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif has_luasnip and luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          else
            fallback()
          end
        end, { 'i', 's' }),
        ['<S-Tab>'] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif has_luasnip and luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { 'i', 's' }),
      }

      -- Keep any existing sources; nothing else to change here
      return opts
    end,
  },
}
