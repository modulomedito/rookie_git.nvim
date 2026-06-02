local M = {}

local modules = {
    "rookie_git.gitdiff",
    "rookie_git.setup_diffview",
    "rookie_git.setup_fugitive",
    "rookie_git.setup_gitgraph",
    "rookie_git.setup_gitsigns",
    "rookie_git.abbr",
    "rookie_git.keymaps",
}

local function try_setup(modname)
    local ok, mod = pcall(require, modname)
    if not ok or not mod then
        return
    end
    if type(mod.setup) == "function" then
        pcall(mod.setup)
    end
end

function M.setup()
    for _, modname in ipairs(modules) do
        try_setup(modname)
    end
end

return M
