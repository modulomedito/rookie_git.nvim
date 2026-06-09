local M = {}
local setup_gitgraph = require("rookie_git.setup_gitgraph")

local function async_git(args, success_msg)
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
                    -- Update gitgraph and fugitive buffers
                    setup_gitgraph.try_update_gitgraph()
                    setup_gitgraph.try_update_fugitive()
                else
                    vim.notify("Git " .. cmd_str .. " failed", vim.log.levels.WARN)
                end
            end)
        end,
    })
end

function M.setup()
    -- Insert abbreviations
    vim.cmd([[
        iabbrev xbar <C-R>=repeat('-',80)<CR><Esc>0
        iabbrev xbui 🔧 build():[#]<Left><Left><Left><Left>
        iabbrev xcho 🐳 chore():[#]<Left><Left><Left><Left>
        iabbrev xdoc 📃 docs():[#]<Left><Left><Left><Left>
        iabbrev xfea ✨ feat():[#]<Left><Left><Left><Left>
        iabbrev xfix 🐞 fix():[#]<Left><Left><Left><Left>
        iabbrev xini 🎉 init():[#]<Left><Left><Left><Left>
        iabbrev xper 🎈 perf():[#]<Left><Left><Left><Left>
        iabbrev xref 🦄 refactor():[#]<Left><Left><Left><Left>
        iabbrev xrev ↩ revert():[#]<Left><Left><Left><Left>
        iabbrev xsty 🌈 style():[#]<Left><Left><Left><Left>
        iabbrev xtes 🧪 test():[#]<Left><Left><Left><Left>
    ]])

    -- Async git command
    vim.api.nvim_create_user_command("RkGitAsync", function(opts)
        if #opts.fargs == 0 then
            vim.notify("Usage: RkGitAsync <git command>", vim.log.levels.ERROR)
            return
        end
        async_git(opts.fargs)
    end, { nargs = "*", complete = "shellcmd" })

    -- Command abbreviations (async)
    vim.cmd([[
        cabbrev Gc RkGitAsync checkout <C-r><C-w>
        cabbrev Gcherry RkGitAsync cherry-pick <C-r><C-w>
        cabbrev Gclr RkGitAsync clean -d -f
        cabbrev Gdell RkGitAsync branch -d
        cabbrev Gdelr RkGitAsync push origin --delete
        cabbrev Gf RkGitAsync fetch
        cabbrev Gm RkGitAsync merge --ff <C-r><C-w>
        cabbrev Gnew RkGitAsync checkout -b
        cabbrev Gpl RkGitAsync pull
        cabbrev Gps RkGitAsync push
        cabbrev Gr RkGitAsync rebase <C-r><C-w>
        cabbrev Gstashpo RkGitAsync stash pop
        cabbrev Gstashpu RkGitAsync stash push --include-untracked
        cabbrev Gtag RkGitAsync tag
    ]])
end

return M
