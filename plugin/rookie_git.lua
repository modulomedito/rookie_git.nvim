if vim.g.rookie_git_loaded then
    return
end
vim.g.rookie_git_loaded = true

local ok, rk = pcall(require, "rookie_git")
if ok and type(rk.setup) == "function" then
    pcall(rk.setup)
end
