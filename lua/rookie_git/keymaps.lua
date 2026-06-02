local M = {}

local function set(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

function M.setup()
    set("n", "<leader>jd", function()
        require("rookie_git.gitdiff").jump_to_next_change()
    end, "Jump to the next differing column in diff windows")

    set("n", "<leader><C-k>", function()
        require("rookie_git.setup_fugitive").close_diff_buffers()
    end, "Fugitive: Close diff buffers")

    set("n", "<leader>diff", function()
        require("rookie_git.setup_diffview").compare_commits_under_cursor()
    end, "Diffview: Select/Compare commits")

    set("n", "<leader><leader>diff", function()
        require("rookie_git.setup_diffview").clear_saved_commits()
    end, "Diffview: Clear saved commits")
end

return M
