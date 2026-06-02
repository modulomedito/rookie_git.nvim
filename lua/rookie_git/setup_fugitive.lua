local M = {}

local function get_diff_windows(tabpage)
    local diff_wins = {}

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        if vim.api.nvim_win_is_valid(win) and vim.wo[win].diff then
            table.insert(diff_wins, win)
        end
    end

    return diff_wins
end

function M.close_diff_buffers()
    local tabpage = vim.api.nvim_get_current_tabpage()
    local diff_wins = get_diff_windows(tabpage)

    if #diff_wins == 0 then
        vim.notify("No diff buffers to close", vim.log.levels.INFO)
        return
    end

    local diff_bufs = {}
    for _, win in ipairs(diff_wins) do
        diff_bufs[vim.api.nvim_win_get_buf(win)] = true
    end

    local diff_buf_count = 0
    for _ in pairs(diff_bufs) do
        diff_buf_count = diff_buf_count + 1
    end

    local fallback_win = nil
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        if vim.api.nvim_win_is_valid(win) and not vim.wo[win].diff then
            fallback_win = win
            break
        end
    end

    if fallback_win then
        vim.api.nvim_set_current_win(fallback_win)
    else
        vim.cmd("enew")
        vim.wo.diff = false
        fallback_win = vim.api.nvim_get_current_win()
    end

    table.sort(diff_wins, function(a, b)
        return a > b
    end)

    for _, win in ipairs(diff_wins) do
        if vim.api.nvim_win_is_valid(win) and win ~= fallback_win then
            pcall(vim.api.nvim_win_close, win, false)
        end
    end

    for buf, _ in pairs(diff_bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end

    vim.notify("Closed " .. tostring(diff_buf_count) .. " diff buffers", vim.log.levels.INFO)
end

function M.setup()
    vim.api.nvim_create_user_command("RkFugitiveCloseDiffBuffers", function()
        M.close_diff_buffers()
    end, { desc = "Close diff buffers opened from Fugitive" })
end

return M
