local M = {}

function M.setup()
    local ok, gitsigns = pcall(require, "gitsigns")
    if not ok then
        return
    end

    gitsigns.setup({
        on_attach = function(bufnr)
            local function map(mode, l, r, opts)
                opts = opts or {}
                opts.buffer = bufnr
                vim.keymap.set(mode, l, r, opts)
            end

            -- Navigation (GitGutter style)
            map("n", "]c", function()
                if vim.wo.diff then
                    return "]c"
                end
                vim.schedule(function()
                    gitsigns.next_hunk()
                end)
                return "<Ignore>"
            end, { expr = true, desc = "Gitsigns: Next Hunk" })

            map("n", "[c", function()
                if vim.wo.diff then
                    return "[c"
                end
                vim.schedule(function()
                    gitsigns.prev_hunk()
                end)
                return "<Ignore>"
            end, { expr = true, desc = "Gitsigns: Prev Hunk" })

            -- Actions (GitGutter style)
            map(
                "n",
                "<leader>hs",
                gitsigns.stage_hunk,
                { desc = "Gitsigns: Stage Hunk" }
            )
            map(
                "n",
                "<leader>hu",
                gitsigns.reset_hunk,
                { desc = "Gitsigns: Undo/Reset Hunk" }
            )
            map(
                "n",
                "<leader>hp",
                gitsigns.preview_hunk,
                { desc = "Gitsigns: Preview Hunk" }
            )

            -- Additional useful mappings
            map("n", "<leader>hb", function()
                gitsigns.blame_line({ full = true })
            end, { desc = "Gitsigns: Blame Line" })
            map(
                "n",
                "<leader>hd",
                gitsigns.diffthis,
                { desc = "Gitsigns: Diff This" }
            )
            map("n", "<leader>hD", function()
                gitsigns.diffthis("~")
            end, { desc = "Gitsigns: Diff This ~" })
            map(
                "n",
                "<leader>td",
                gitsigns.toggle_deleted,
                { desc = "Gitsigns: Toggle Deleted" }
            )

            map("n", "U", gitsigns.reset_hunk, { desc = "Gitsigns: Undo Hunk" })

            -- Text object
            map(
                { "o", "x" },
                "ih",
                ":<C-U>Gitsigns select_hunk<CR>",
                { desc = "Gitsigns: Select Hunk" }
            )
        end,
    })
end

return M
