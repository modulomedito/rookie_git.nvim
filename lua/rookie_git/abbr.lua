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
    vim.cmd([[
        cabbrev Gc silent G checkout <C-r><C-w>
        cabbrev Gcherry G cherry-pick <C-r><C-w>
        cabbrev Gclr G clean -d -f
        cabbrev Gdell silent G branch -d
        cabbrev Gdelr RkGit push origin --delete
        cabbrev Gf RkGit fetch
        cabbrev Gm silent G merge --ff <C-r><C-w>
        cabbrev Gnew silent G checkout -b
        cabbrev Gpl RkGit pull
        cabbrev Gps RkGit push
        cabbrev Gr G rebase <C-r><C-w>
        cabbrev Gstashpo silent G stash pop
        cabbrev Gstashpu silent G stash push --include-untracked
        cabbrev Gtag silent G tag
    ]])
end

return M
