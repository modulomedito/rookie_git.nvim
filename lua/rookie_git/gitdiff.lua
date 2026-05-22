local M = {}

--- Jump to the next differing column between this window and the other diff window on the current line
function M.jump_to_next_change()
    local cur_win = vim.api.nvim_get_current_win()
    local cur_line_content = vim.api.nvim_get_current_line()
    local cur_pos = vim.api.nvim_win_get_cursor(0)
    local cur_row = cur_pos[1]
    local cur_col = cur_pos[2] + 1

    -- find another window that has 'diff' enabled
    local other_buf = -1
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if win ~= cur_win and vim.wo[win].diff then
            other_buf = vim.api.nvim_win_get_buf(win)
            break
        end
    end

    if other_buf == -1 then
        vim.notify("No other diff window found", vim.log.levels.WARN)
        return
    end

    -- nvim_buf_get_lines uses 0-indexed line numbers, so cur_row - 1
    local other_lines =
        vim.api.nvim_buf_get_lines(other_buf, cur_row - 1, cur_row, false)
    if #other_lines == 0 then
        vim.notify(
            "No line found in other buffer at current row",
            vim.log.levels.WARN
        )
        return
    end
    local other_line_content = other_lines[1]

    local a = cur_line_content
    local b = other_line_content
    local m = math.min(#a, #b)

    local in_diff = false
    if cur_col <= m then
        in_diff = a:sub(cur_col, cur_col) ~= b:sub(cur_col, cur_col)
    elseif cur_col > m and #a ~= #b then
        in_diff = true
    end

    local col = -1

    for i = cur_col + 1, m do
        local is_diff = a:sub(i, i) ~= b:sub(i, i)
        if in_diff then
            if not is_diff then
                in_diff = false
            end
        else
            if is_diff then
                col = i
                break
            end
        end
    end

    if col == -1 and not in_diff then
        if #a ~= #b and cur_col <= m then
            col = m + 1
        end
    end

    if col == -1 then
        vim.notify("No more differences on this line", vim.log.levels.INFO)
        return
    end

    -- nvim_win_set_cursor uses 0-indexed column, so col - 1
    pcall(vim.api.nvim_win_set_cursor, 0, { cur_row, col - 1 })
end

function M.setup()
    local function setup_diff_highlights()
        vim.api.nvim_set_hl(0, "DiffAdd", { bg = "#284A36", fg = "#A6E3A1" })
        vim.api.nvim_set_hl(0, "DiffChange", { bg = "#273A5E", fg = "#89B4FA" })
        vim.api.nvim_set_hl(0, "DiffDelete", { bg = "#5C2C35", fg = "#F38BA8" })
        vim.api.nvim_set_hl(0, "DiffText", { bg = "#394b70", fg = "#89DCEB", bold = true })
    end

    setup_diff_highlights()

    vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = setup_diff_highlights,
    })

    vim.api.nvim_create_user_command(
        "RkGitdiffJumpToNextChange",
        M.jump_to_next_change,
        {
            desc = "Jump to the next differing column in diff windows",
        }
    )

    vim.keymap.set("n", "<leader>jd", M.jump_to_next_change, {
        desc = "Jump to the next differing column in diff windows",
    })
end

return M
