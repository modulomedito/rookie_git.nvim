local M = {}

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

    -- Command abbreviations
    -- cabbrev Gg call timer_start(200, {-> execute('RkGitGraph')})\|G
    vim.cmd([[
        cabbrev Gc silent G checkout <C-r><C-w>\|RkGitGraph
        cabbrev Gcherry G cherry-pick <C-r><C-w>\|RkGitGraph
        cabbrev Gclr G clean -d -f
        cabbrev Gdell silent G branch -d\|RkGitGraph<Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left>
        cabbrev Gdelr RkGit push origin --delete
        cabbrev Gf RkGit fetch
        cabbrev Gm silent G merge --ff <C-r><C-w>\|RkGitGraph
        cabbrev Gnew silent G checkout -b\|RkGitGraph<Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left>
        cabbrev Gpl RkGit pull
        cabbrev Gps RkGit push
        cabbrev Gr G rebase <C-r><C-w>\|RkGitGraph<Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left>
        cabbrev Gstashpo silent G stash pop\|RkGitGraph
        cabbrev Gstashpu silent G stash push --include-untracked\|RkGitGraph
        cabbrev Gtag silent G tag\|RkGitGraph<Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left>

        cabbrev Gl RkGitlabIssue
    ]])
end

return M
