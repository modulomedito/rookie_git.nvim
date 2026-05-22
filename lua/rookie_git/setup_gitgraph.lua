local M = {}

function M.open_gitgraph()
    local timed_out = false
    vim.notify("Git fetching...", vim.log.levels.INFO)
    local job_id = vim.fn.jobstart({ "git", "fetch" }, {
        on_exit = function(_, exit_code)
            if exit_code == 0 then
                vim.notify("Git fetch completed", vim.log.levels.INFO)
            elseif not timed_out then
                vim.notify("Git fetch failed", vim.log.levels.WARN)
            end
            M.draw_gitgraph()
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
        end,
    })
end

function M.draw_gitgraph()
    -- 1. Ensure we are not in NvimTree
    if vim.bo.filetype == "NvimTree" then
        vim.cmd("wincmd l") -- Try to move right
        if vim.bo.filetype == "NvimTree" then
            -- Still in NvimTree? Try to find any other window
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                local buf = vim.api.nvim_win_get_buf(win)
                if vim.bo[buf].filetype ~= "NvimTree" then
                    vim.api.nvim_set_current_win(win)
                    break
                end
            end
        end
    end

    local main_win = vim.api.nvim_get_current_win()

    -- Find existing windows and buffers
    local fugitive_buf = -1
    local gitgraph_buf = -1
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local ft = vim.bo[buf].filetype
        if ft == "fugitive" then
            fugitive_buf = buf
        elseif ft == "gitgraph" then
            gitgraph_buf = buf
        end
    end

    local fugitive_win = -1
    local gitgraph_win = -1
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local ft = vim.bo[buf].filetype
        if ft == "fugitive" then
            fugitive_win = win
        elseif ft == "gitgraph" then
            gitgraph_win = win
        end
    end

    -- 2. Open/Focus Fugitive
    if fugitive_win ~= -1 then
        vim.api.nvim_set_current_win(fugitive_win)
    else
        vim.api.nvim_set_current_win(main_win)
        if fugitive_buf ~= -1 then
            vim.cmd("rightbelow split")
            vim.api.nvim_set_current_buf(fugitive_buf)
        else
            -- Use rightbelow G to try and force the split location
            local ok, err = pcall(vim.cmd, "rightbelow G")
            if not ok then
                vim.notify(
                    "Fugitive failed: " .. tostring(err),
                    vim.log.levels.ERROR
                )
                return
            end
        end

        -- Re-locate fugitive window
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "fugitive" then
                fugitive_win = win
                break
            end
        end
    end

    if fugitive_win == -1 then
        return
    end

    -- Refresh fugitive
    vim.api.nvim_win_call(fugitive_win, function()
        pcall(vim.cmd, "G")
    end)

    -- 3. Open/Focus GitGraph
    if gitgraph_win ~= -1 then
        vim.api.nvim_set_current_win(gitgraph_win)
    else
        vim.api.nvim_set_current_win(fugitive_win)
        vim.cmd("rightbelow vsplit")
        gitgraph_win = vim.api.nvim_get_current_win()
        if gitgraph_buf ~= -1 then
            vim.api.nvim_set_current_buf(gitgraph_buf)
        end
    end

    -- 4. Draw
    vim.api.nvim_set_current_win(gitgraph_win)
    require("gitgraph").draw({}, { all = true, max_count = 5000 })
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
