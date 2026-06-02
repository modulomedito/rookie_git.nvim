local M = {}

local first_commit = nil

function M.compare_commits_under_cursor()
    local current_hash = vim.fn.expand("<cword>")
    if current_hash == "" then
        vim.notify("No hash under cursor", vim.log.levels.WARN)
        return
    end

    if not first_commit then
        first_commit = current_hash
        vim.fn.setreg("z", first_commit)
        vim.notify("Saved first commit: " .. first_commit .. " (to register z)")
        return
    end

    local second_commit = current_hash
    vim.fn.setreg("x", second_commit)
    vim.notify(
        "Comparing "
            .. first_commit
            .. " and "
            .. second_commit
            .. " (saved to register x)"
    )
    vim.cmd("DiffviewOpen " .. first_commit .. ".." .. second_commit)
    first_commit = nil
end

function M.clear_saved_commits()
    first_commit = nil
    vim.fn.setreg("z", "")
    vim.fn.setreg("x", "")
    vim.notify("Cleared saved commits and registers z/x")
end

function M.setup()
    local ok, diffview = pcall(require, "diffview")
    if not ok then
        return
    end

    local actions = require("diffview.actions")

    -- Setup diffview with default options if needed
    diffview.setup({
        keymaps = {
            disable_defaults = true,
            view = {
                { "n", "q", actions.close, { desc = "Close Diffview" } },
                { "n", "<tab>", actions.select_next_entry, { desc = "Next entry" } },
                { "n", "<s-tab>", actions.select_prev_entry, { desc = "Previous entry" } },
            },
            file_panel = {
                { "n", "<CR>", actions.select_entry, { desc = "Open the diff for the selected entry" } },
                { "n", "o", actions.select_entry, { desc = "Open the diff for the selected entry" } },
                { "n", "s", actions.toggle_stage_entry, { desc = "Stage / unstage the selected entry" } },
                { "n", "q", actions.close, { desc = "Close Diffview" } },
            },
            file_history_panel = {
                { "n", "<CR>", actions.select_entry, { desc = "Open the diff for the selected entry" } },
                { "n", "o", actions.select_entry, { desc = "Open the diff for the selected entry" } },
                { "n", "q", actions.close, { desc = "Close Diffview" } },
            },
        },
    })
end

return M
