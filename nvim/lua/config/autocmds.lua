local group = vim.api.nvim_create_augroup("user_config", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)

    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  group = group,
  callback = function(event)
    local dir = vim.fn.fnamemodify(event.match, ":p:h")

    if dir ~= "" and vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  command = "wincmd =",
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(event)
    local map = function(keys, rhs, desc, mode)
      vim.keymap.set(mode or "n", keys, rhs, { buffer = event.buf, desc = desc })
    end

    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("gr", vim.lsp.buf.references, "References")
    map("gI", vim.lsp.buf.implementation, "Go to implementation")
    map("<leader>D", vim.lsp.buf.type_definition, "Type definition")
    map("<leader>rn", vim.lsp.buf.rename, "Rename")
    map("<leader>ca", vim.lsp.buf.code_action, "Code action", { "n", "x" })
    map("K", vim.lsp.buf.hover, "Hover")

    local client = vim.lsp.get_client_by_id(event.data.client_id)

    if client and client:supports_method("textDocument/documentHighlight", event.buf) then
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = event.buf,
        group = group,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = event.buf,
        group = group,
        callback = vim.lsp.buf.clear_references,
      })
    end

    if client and client:supports_method("textDocument/inlayHint", event.buf) and vim.lsp.inlay_hint then
      map("<leader>th", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }), { bufnr = event.buf })
      end, "Toggle inlay hints")
    end
  end,
})
