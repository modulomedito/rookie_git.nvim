local M = {}

local function redraw_gitgraph_buffers()
    local gitgraph_bufs = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "gitgraph" then
            gitgraph_bufs[buf] = true
        end
    end
    if vim.tbl_isempty(gitgraph_bufs) then
        return
    end

    local current_win = vim.api.nvim_get_current_win()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if gitgraph_bufs[buf] and vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_set_current_win(win)
            pcall(require("gitgraph").draw, {}, { all = true, max_count = 5000 })
        end
    end
    if vim.api.nvim_win_is_valid(current_win) then
        vim.api.nvim_set_current_win(current_win)
    end
end

function M.setup()
    vim.api.nvim_create_autocmd("User", {
        pattern = "FugitiveChanged",
        callback = redraw_gitgraph_buffers,
    })
end

return M
