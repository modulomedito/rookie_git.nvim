local M = {}

local function is_fugitive_buffer(buf)
    local ft = vim.bo[buf].filetype
    local name = vim.api.nvim_buf_get_name(buf)
    return ft == "fugitive" or name:match("^fugitive://") or name:match("Fugitive$")
end

local function is_gitgraph_buffer(buf)
    local ft = vim.bo[buf].filetype
    local name = vim.api.nvim_buf_get_name(buf)
    return ft == "gitgraph" or name:match("GitGraph$")
end

local function refresh_fugitive_status(win)
    if win == -1 or not vim.api.nvim_win_is_valid(win) then
        return
    end

    vim.api.nvim_win_call(win, function()
        if vim.bo.filetype ~= "fugitive" then
            return
        end

        local ok = false
        if vim.fn.exists("*fugitive#ReloadStatus") == 1 then
            ok = pcall(vim.fn["fugitive#ReloadStatus"])
        end

        if not ok then
            pcall(vim.cmd, "silent edit")
        end
    end)
end

function M.find_git_tab()
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        local wins = vim.api.nvim_tabpage_list_wins(tab)
        for _, win in ipairs(wins) do
            local buf = vim.api.nvim_win_get_buf(win)
            local ft = vim.bo[buf].filetype
            if ft == "gitgraph" or ft == "fugitive" then
                return tab
            end
        end
    end
    return -1
end

function M.open_gitgraph()
    -- 1. Cleanup redundant buffers first
    local fugitive_buf = -1
    local gitgraph_buf = -1
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            if is_fugitive_buffer(buf) then
                if fugitive_buf == -1 then
                    fugitive_buf = buf
                else
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
            elseif is_gitgraph_buffer(buf) then
                if gitgraph_buf == -1 then
                    gitgraph_buf = buf
                else
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
            end
        end
    end

    -- 2. Check if a tab with gitgraph/fugitive already exists
    local target_tab = M.find_git_tab()

    -- 3. Switch to existing tab or create a new one
    if target_tab ~= -1 then
        vim.api.nvim_set_current_tabpage(target_tab)
    else
        vim.cmd("tabnew")
    end

    -- 4. Proceed with drawing
    local timed_out = false
    vim.notify("Git fetching...", vim.log.levels.INFO)
    local job_id = vim.fn.jobstart({ "git", "fetch" }, {
        on_exit = function(_, exit_code)
            vim.schedule(function()
                if exit_code == 0 then
                    vim.notify("Git fetch completed", vim.log.levels.INFO)
                elseif not timed_out then
                    vim.notify("Git fetch failed", vim.log.levels.WARN)
                end
                M.draw_gitgraph()
            end)
        end,
    })

    -- 3s timeout
    vim.defer_fn(function()
        if vim.fn.jobwait({ job_id }, 0)[1] == -1 then
            timed_out = true
            vim.fn.jobstop(job_id)
            vim.notify("Git fetch timed out, showing graph", vim.log.levels.INFO)
        end
    end, 3000)
end

function M.async_git(args, success_msg)
    local cmd_str = table.concat(args, " ")
    vim.notify("Git " .. cmd_str .. "...", vim.log.levels.INFO)
    vim.fn.jobstart(vim.list_extend({ "git" }, args), {
        on_exit = function(_, exit_code)
            vim.schedule(function()
                if exit_code == 0 then
                    if success_msg then
                        vim.notify(success_msg, vim.log.levels.INFO)
                    else
                        vim.notify("Git " .. cmd_str .. " completed", vim.log.levels.INFO)
                    end
                    M.draw_gitgraph()
                else
                    vim.notify("Git " .. cmd_str .. " failed", vim.log.levels.WARN)
                end
            end)
        end,
    })
end

function M.draw_gitgraph()
    -- 0. Ensure we are in the Git tab
    local target_tab = M.find_git_tab()
    if target_tab ~= -1 then
        vim.api.nvim_set_current_tabpage(target_tab)
    end

    -- Save the window that is CURRENTLY focused in this tab and its cursor position
    local original_win = vim.api.nvim_get_current_win()
    local original_cursor = vim.api.nvim_win_get_cursor(original_win)
    local original_buf = vim.api.nvim_win_get_buf(original_win)
    local is_fresh_tab = vim.bo[original_buf].buftype == ""
        and vim.api.nvim_buf_get_name(original_buf) == ""
        and #vim.api.nvim_tabpage_list_wins(0) == 1

    -- 1. Find existing windows and buffers in the CURRENT tab
    local current_tab = vim.api.nvim_get_current_tabpage()
    local wins = vim.api.nvim_tabpage_list_wins(current_tab)

    local fugitive_win = -1
    local gitgraph_win = -1
    local extra_fugitive_wins = {}
    local extra_gitgraph_wins = {}
    for _, win in ipairs(wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        if is_fugitive_buffer(buf) then
            if fugitive_win == -1 then
                fugitive_win = win
            else
                table.insert(extra_fugitive_wins, win)
            end
        elseif is_gitgraph_buffer(buf) then
            if gitgraph_win == -1 then
                gitgraph_win = win
            else
                table.insert(extra_gitgraph_wins, win)
            end
        end
    end

    if vim.tbl_contains(extra_fugitive_wins, original_win) then
        original_win = fugitive_win
    elseif vim.tbl_contains(extra_gitgraph_wins, original_win) then
        original_win = gitgraph_win
    end

    for _, win in ipairs(extra_fugitive_wins) do
        if vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, false)
        end
    end
    for _, win in ipairs(extra_gitgraph_wins) do
        if vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, false)
        end
    end

    -- Find buffers globally to reuse them if they exist
    local fugitive_buf = -1
    local gitgraph_buf = -1
    local bufs = vim.api.nvim_list_bufs()
    for _, buf in ipairs(bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
            if is_fugitive_buffer(buf) then
                if fugitive_buf == -1 then
                    fugitive_buf = buf
                else
                    -- Close extra fugitive buffers
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
            elseif is_gitgraph_buffer(buf) then
                if gitgraph_buf == -1 then
                    gitgraph_buf = buf
                else
                    -- Close extra gitgraph buffers
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
            end
        end
    end

    -- 2. Open/Focus Fugitive
    if fugitive_win ~= -1 then
        vim.api.nvim_set_current_win(fugitive_win)
        -- Ensure fugitive is on the left
        vim.cmd("wincmd H")
    else
        if fugitive_buf ~= -1 then
            -- Buffer exists but no window in this tab
            if is_fresh_tab then
                fugitive_win = original_win
            else
                vim.cmd("leftabove vsplit")
                fugitive_win = vim.api.nvim_get_current_win()
            end
            vim.api.nvim_win_set_buf(fugitive_win, fugitive_buf)
        else
            -- Use G to open fugitive
            local ok, err = pcall(vim.cmd, "G")
            if not ok then
                vim.notify("Fugitive failed: " .. tostring(err), vim.log.levels.ERROR)
                return
            end

            -- Find the newly opened fugitive window
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                local buf = vim.api.nvim_win_get_buf(win)
                if vim.bo[buf].filetype == "fugitive" then
                    fugitive_win = win
                    break
                end
            end

            -- If G opened in a split and we had a fresh tab, close the empty buffer
            if is_fresh_tab and fugitive_win ~= -1 and fugitive_win ~= original_win then
                pcall(vim.api.nvim_win_close, original_win, false)
                -- Update original_win to fugitive_win so focus restoration works
                original_win = fugitive_win
                original_cursor = { 1, 0 }
            end
        end
        -- Ensure fugitive is on the left
        vim.api.nvim_set_current_win(fugitive_win)
        vim.cmd("wincmd H")
    end

    refresh_fugitive_status(fugitive_win)

    -- 3. Recreate GitGraph as a direct right split of fugitive so no window sits between them.
    if gitgraph_win ~= -1 and vim.api.nvim_win_is_valid(gitgraph_win) then
        if original_win == gitgraph_win then
            original_win = -1
        end
        pcall(vim.api.nvim_win_close, gitgraph_win, false)
        gitgraph_win = -1
    end

    vim.api.nvim_set_current_win(fugitive_win)
    vim.cmd("rightbelow vsplit")
    gitgraph_win = vim.api.nvim_get_current_win()
    if gitgraph_buf ~= -1 then
        vim.api.nvim_win_set_buf(gitgraph_win, gitgraph_buf)
    end
    if is_gitgraph_buffer(original_buf) then
        original_win = gitgraph_win
    end

    -- 4. Draw
    vim.api.nvim_set_current_win(gitgraph_win)
    require("gitgraph").draw({}, { all = true, max_count = 5000 })

    -- Remove leftover placeholder windows so the Git tab stays |fugitive|gitgraph|.
    local final_wins = vim.api.nvim_tabpage_list_wins(current_tab)
    for _, win in ipairs(final_wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        if not is_fugitive_buffer(buf) and not is_gitgraph_buffer(buf) then
            if win == original_win then
                original_win = fugitive_win
                original_cursor = { 1, 0 }
            end
            pcall(vim.api.nvim_win_close, win, false)
        end
    end

    if vim.api.nvim_win_is_valid(fugitive_win) then
        vim.api.nvim_set_current_win(fugitive_win)
        vim.cmd("wincmd H")
    end
    if vim.api.nvim_win_is_valid(gitgraph_win) then
        vim.api.nvim_set_current_win(gitgraph_win)
        vim.cmd("wincmd L")
    end

    -- 5. Restore original window focus and cursor position
    if original_win and vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
        -- Only restore cursor if it's still within bounds (just in case the graph shrank)
        pcall(vim.api.nvim_win_set_cursor, original_win, original_cursor)
    end
end

function M.setup()
    local ok, gitgraph = pcall(require, "gitgraph")
    if not ok then
        return
    end

    -- Apply Tokyonight colors if available
    local has_tokyonight, tokyonight_colors =
        pcall(require, "tokyonight.colors")
    if has_tokyonight then
        local colors = tokyonight_colors.setup()
        local highlights = {
            GitGraphHash = { fg = colors.purple },
            GitGraphTimestamp = { fg = colors.blue2 },
            GitGraphAuthor = { fg = colors.green },
            GitGraphBranchName = { fg = colors.magenta },
            GitGraphBranchTag = { fg = colors.orange },
            GitGraphBranchMsg = { fg = colors.fg },
            GitGraphBranch1 = { fg = colors.blue },
            GitGraphBranch2 = { fg = colors.magenta },
            GitGraphBranch3 = { fg = colors.green },
            GitGraphBranch4 = { fg = colors.yellow },
            GitGraphBranch5 = { fg = colors.orange },
        }
        for group, hl in pairs(highlights) do
            vim.api.nvim_set_hl(0, group, hl)
        end
    end

    require("gitgraph").setup({
        symbols = {
            merge_commit = "M",
            commit = "*",
        },
        format = {
            timestamp = "%Y-%m-%d %H:%M:%S",
            fields = { "hash", "timestamp", "author", "branch_name", "tag" },
        },
        hooks = {
            -- Check diff of a commit
            on_select_commit = function(commit)
                vim.notify("DiffviewOpen " .. commit.hash .. "^!")
                vim.cmd(":DiffviewOpen " .. commit.hash .. "^!")
            end,
            -- Check diff from commit a -> commit b
            on_select_range_commit = function(from, to)
                vim.notify("DiffviewOpen " .. from.hash .. "~1.." .. to.hash)
                vim.cmd(":DiffviewOpen " .. from.hash .. "~1.." .. to.hash)
            end,
        },
    })

    vim.api.nvim_create_user_command("RkGitGraph", function()
        M.open_gitgraph()
    end, { desc = "Rookie GitGraph - Draw" })

    vim.api.nvim_create_user_command("Gg", function()
        M.open_gitgraph()
    end, { desc = "Rookie GitGraph - Draw" })

    vim.api.nvim_create_user_command("RkGit", function(opts)
        if #opts.fargs == 0 then
            vim.notify("Usage: RkGit <git command>", vim.log.levels.ERROR)
            return
        end
        M.async_git(opts.fargs)
    end, { nargs = "*", complete = "shellcmd" })

end

return M
