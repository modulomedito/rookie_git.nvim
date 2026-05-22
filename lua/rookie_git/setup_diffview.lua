local M = {}

local first_commit = nil

function M.setup()
    local ok, diffview = pcall(require, "diffview")
    if not ok then
        return
    end

    -- Setup diffview with default options if needed
    diffview.setup({
        keymaps = {
            disable_defaults = true,
        },
    })

    -- Keymaps
    vim.keymap.set("n", "<leader>diff", function()
        local current_hash = vim.fn.expand("<cword>")
        if current_hash == "" then
            vim.notify("No hash under cursor", vim.log.levels.WARN)
            return
        end

        if not first_commit then
            first_commit = current_hash
            vim.fn.setreg("z", first_commit)
            vim.notify(
                "Saved first commit: " .. first_commit .. " (to register z)"
            )
        else
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
            -- Reset for next comparison
            first_commit = nil
        end
    end, { desc = "Diffview: Select/Compare commits" })

    vim.keymap.set("n", "<leader><leader>diff", function()
        first_commit = nil
        vim.fn.setreg("z", "")
        vim.fn.setreg("x", "")
        vim.notify("Cleared saved commits and registers z/x")
    end, { desc = "Diffview: Clear saved commits" })
end

return M
