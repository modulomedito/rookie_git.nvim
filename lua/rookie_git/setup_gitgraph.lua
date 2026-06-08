local M = {}
local gitgraph_layout = "v"
local FETCH_TIMEOUT_MS = 300
local commit_message_float = {
    buf = nil,
    win = nil,
}
local command_queue_state = {
    active_request_id = 0,
    items = {},
}

local function normalize_gitgraph_layout(layout)
    if layout == "s" then
        return "s"
    end
    return "v"
end

local function get_git_cmd_parts()
    local git_cmd = require("gitgraph").config.git_cmd or "git"
    return vim.split(git_cmd, "%s+", { trimempty = true })
end

local function clone_queue_items(items)
    local cloned = {}
    for index, item in ipairs(items) do
        cloned[index] = {
            label = item.label,
            command = item.command,
            status = item.status,
        }
    end
    return cloned
end

local function render_command_queue(items)
    local parts = {}
    for _, item in ipairs(items) do
        local label = item.label
        if item.status == "running" then
            label = "[" .. label .. "]"
        end
        table.insert(parts, label)
    end
    return table.concat(parts, " -> ")
end

local function sync_command_queue_state()
    vim.g.rookie_git_command_queue = clone_queue_items(command_queue_state.items)
    vim.g.rookie_git_command_queue_status = render_command_queue(command_queue_state.items)

    local message = vim.g.rookie_git_command_queue_status
    if message == "" then
        message = " "
    end

    pcall(vim.api.nvim_echo, { { message, "ModeMsg" } }, false, {})
end

local function is_active_command_request(request_id)
    return command_queue_state.active_request_id == request_id
end

local function set_command_queue(request_id, items)
    if not is_active_command_request(request_id) then
        return
    end
    command_queue_state.items = items
    sync_command_queue_state()
end

local function update_command_queue_item(request_id, label, status)
    if not is_active_command_request(request_id) then
        return
    end

    for _, item in ipairs(command_queue_state.items) do
        if item.label == label then
            item.status = status
            break
        end
    end

    sync_command_queue_state()
end

local function clear_command_queue(request_id)
    set_command_queue(request_id, {})
end

local function close_commit_message_float()
    if commit_message_float.win and vim.api.nvim_win_is_valid(commit_message_float.win) then
        pcall(vim.api.nvim_win_close, commit_message_float.win, true)
    end
    commit_message_float.win = nil
    commit_message_float.buf = nil
end

local function get_commit_message_lines(commit)
    local git_cmd = require("gitgraph").config.git_cmd or "git"
    local cmd = git_cmd .. " show -s --format=%B " .. vim.fn.shellescape(commit.hash)
    local lines = vim.fn.systemlist(cmd)

    if vim.v.shell_error ~= 0 then
        vim.notify("Failed to load commit message for " .. commit.hash, vim.log.levels.WARN)
        return nil
    end

    if #lines == 0 then
        return { "(empty commit message)" }
    end

    return lines
end

local function open_commit_message_float(commit)
    local lines = get_commit_message_lines(commit)
    if not lines then
        return
    end

    close_commit_message_float()

    local max_line_width = 0
    for _, line in ipairs(lines) do
        max_line_width = math.max(max_line_width, vim.fn.strdisplaywidth(line))
    end

    local width = math.min(math.max(max_line_width + 2, 40), math.max(math.floor(vim.o.columns * 0.8), 40))
    local height = math.min(math.max(#lines, 1), math.max(math.floor(vim.o.lines * 0.7), 8))
    local row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 1)
    local col = math.max(math.floor((vim.o.columns - width) / 2), 0)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "gitcommit"
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        title = " Commit " .. commit.hash .. " ",
        title_pos = "center",
        width = width,
        height = height,
        row = row,
        col = col,
    })

    vim.wo[win].wrap = true
    vim.wo[win].linebreak = true
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].cursorline = false

    local close_keys = { "q", "<Esc>", "<Tab>" }
    for _, lhs in ipairs(close_keys) do
        vim.keymap.set("n", lhs, close_commit_message_float, {
            buffer = buf,
            silent = true,
            nowait = true,
        })
    end

    commit_message_float.buf = buf
    commit_message_float.win = win
end

local function map_gitgraph_commit_message(buf)
    vim.keymap.set("n", "<Tab>", function()
        local draw = require("gitgraph.draw")
        local utils = require("gitgraph.utils")
        local row = vim.api.nvim_win_get_cursor(0)[1]
        local commit = utils.get_commit_from_row(draw.graph, row)

        if not commit then
            vim.notify("No commit under cursor", vim.log.levels.INFO)
            return
        end

        open_commit_message_float(commit)
    end, {
        buffer = buf,
        silent = true,
        desc = "Show full commit message",
    })
end

local function is_fugitive_buffer(buf)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return false end
    local ft = vim.bo[buf].filetype
    local name = vim.api.nvim_buf_get_name(buf)
    return ft == "fugitive" or name:match("^fugitive://")
end

local function is_gitgraph_buffer(buf)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return false end
    local ft = vim.bo[buf].filetype
    return ft == "gitgraph"
end

local function refresh_fugitive_status(win)
    if win == -1 or not vim.api.nvim_win_is_valid(win) then
        return
    end

    vim.api.nvim_win_call(win, function()
        if vim.bo.filetype ~= "fugitive" then
            return
        end

        local ok = false
        if vim.fn.exists("*fugitive#ReloadStatus") == 1 then
            ok = pcall(vim.fn["fugitive#ReloadStatus"])
        end

        if not ok then
            pcall(vim.cmd, "silent edit")
        end
    end)
end

local function cleanup_redundant_git_buffers()
    local fugitive_buf = -1
    local gitgraph_buf = -1

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            if is_fugitive_buffer(buf) then
                if fugitive_buf == -1 then
                    fugitive_buf = buf
                else
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
            elseif is_gitgraph_buffer(buf) then
                if gitgraph_buf == -1 then
                    gitgraph_buf = buf
                else
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
            end
        end
    end
end

local function ensure_git_tab()
    local target_tab = M.find_git_tab()
    if target_tab ~= -1 then
        vim.api.nvim_set_current_tabpage(target_tab)
    else
        vim.cmd("tabnew")
    end
end

local function prepare_gitgraph_workspace()
    cleanup_redundant_git_buffers()
    ensure_git_tab()
end

local function run_gitgraph_draw(layout)
    prepare_gitgraph_workspace()
    M.draw_gitgraph(layout)
end

function M.find_git_tab()
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        local wins = vim.api.nvim_tabpage_list_wins(tab)
        for _, win in ipairs(wins) do
            local buf = vim.api.nvim_win_get_buf(win)
            local ft = vim.bo[buf].filetype
            if ft == "gitgraph" or ft == "fugitive" then
                return tab
            end
        end
    end
    return -1
end

function M.open_gitgraph(layout)
    if layout ~= nil then
        gitgraph_layout = normalize_gitgraph_layout(layout)
    end

    command_queue_state.active_request_id = command_queue_state.active_request_id + 1
    local request_id = command_queue_state.active_request_id
    local draw_update_started = false
    local timeout_draw_started = false
    local fetch_command = vim.list_extend(get_git_cmd_parts(), { "fetch" })

    set_command_queue(request_id, {
        {
            label = "Fetch",
            command = table.concat(fetch_command, " "),
            status = "running",
        },
        {
            label = "Draw",
            command = "RkGitGraph",
            status = "pending",
        },
    })

    local function run_timeout_draw()
        if not is_active_command_request(request_id) or timeout_draw_started then
            return
        end

        timeout_draw_started = true
        local ok, err = pcall(run_gitgraph_draw, gitgraph_layout)
        if not ok then
            vim.notify("Gitgraph draw failed: " .. tostring(err), vim.log.levels.ERROR)
        end
    end

    local function start_draw_update()
        if not is_active_command_request(request_id) or draw_update_started then
            return
        end

        draw_update_started = true
        update_command_queue_item(request_id, "Fetch", "done")
        update_command_queue_item(request_id, "Draw", "running")

        local ok, err = pcall(run_gitgraph_draw, gitgraph_layout)
        if not ok then
            vim.notify("Gitgraph draw failed: " .. tostring(err), vim.log.levels.ERROR)
        end

        clear_command_queue(request_id)
    end

    local function handle_fetch_exit(exit_code)
        if not is_active_command_request(request_id) then
            return
        end

        if exit_code == 0 then
            start_draw_update()
        else
            vim.notify("Git fetch failed", vim.log.levels.WARN)
            start_draw_update()
        end
    end

    local job_id = vim.fn.jobstart(fetch_command, {
        on_exit = function(_, exit_code)
            vim.schedule(function()
                handle_fetch_exit(exit_code)
            end)
        end,
    })

    if job_id <= 0 then
        clear_command_queue(request_id)
        vim.notify("Failed to start git fetch", vim.log.levels.ERROR)
        local ok, err = pcall(run_gitgraph_draw, gitgraph_layout)
        if not ok then
            vim.notify("Gitgraph draw failed: " .. tostring(err), vim.log.levels.ERROR)
        end
        return
    end

    vim.defer_fn(function()
        if not is_active_command_request(request_id) or draw_update_started then
            return
        end

        if vim.fn.jobwait({ job_id }, 0)[1] == -1 then
            vim.notify(
                "Git fetch exceeded " .. FETCH_TIMEOUT_MS .. "ms and continues in background",
                vim.log.levels.INFO
            )
            run_timeout_draw()
        end
    end, FETCH_TIMEOUT_MS)
end

function M.draw_gitgraph(layout)
    layout = normalize_gitgraph_layout(layout or gitgraph_layout)
    gitgraph_layout = layout

    -- 0. Ensure we are in the Git tab
    local target_tab = M.find_git_tab()
    if target_tab ~= -1 then
        vim.api.nvim_set_current_tabpage(target_tab)
    end

    -- Save the window that is CURRENTLY focused in this tab and its cursor position
    local original_win = vim.api.nvim_get_current_win()
    local original_cursor = vim.api.nvim_win_get_cursor(original_win)
    local original_buf = vim.api.nvim_win_get_buf(original_win)
    local is_fresh_tab = vim.bo[original_buf].buftype == ""
        and vim.api.nvim_buf_get_name(original_buf) == ""
        and #vim.api.nvim_tabpage_list_wins(0) == 1

    -- 1. Find existing windows and buffers in the CURRENT tab
    local current_tab = vim.api.nvim_get_current_tabpage()
    local wins = vim.api.nvim_tabpage_list_wins(current_tab)

    local fugitive_win = -1
    local gitgraph_win = -1
    local extra_fugitive_wins = {}
    local extra_gitgraph_wins = {}
    for _, win in ipairs(wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        if is_fugitive_buffer(buf) then
            if fugitive_win == -1 then
                fugitive_win = win
            else
                table.insert(extra_fugitive_wins, win)
            end
        elseif is_gitgraph_buffer(buf) then
            if gitgraph_win == -1 then
                gitgraph_win = win
            else
                table.insert(extra_gitgraph_wins, win)
            end
        end
    end

    if vim.tbl_contains(extra_fugitive_wins, original_win) then
        original_win = fugitive_win
    elseif vim.tbl_contains(extra_gitgraph_wins, original_win) then
        original_win = gitgraph_win
    end

    for _, win in ipairs(extra_fugitive_wins) do
        if vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, false)
        end
    end
    for _, win in ipairs(extra_gitgraph_wins) do
        if vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, false)
        end
    end

    -- Find buffers globally to reuse them if they exist
    local fugitive_buf = -1
    local gitgraph_buf = -1
    local bufs = vim.api.nvim_list_bufs()
    for _, buf in ipairs(bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
            if is_fugitive_buffer(buf) then
                if fugitive_buf == -1 then
                    fugitive_buf = buf
                else
                    -- Close extra fugitive buffers
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
            elseif is_gitgraph_buffer(buf) then
                if gitgraph_buf == -1 then
                    gitgraph_buf = buf
                else
                    -- Close extra gitgraph buffers
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                end
            end
        end
    end

    -- 2. Open/Focus Fugitive
    if fugitive_win ~= -1 then
        vim.api.nvim_set_current_win(fugitive_win)
        if layout == "v" then
            vim.cmd("wincmd H")
        else
            vim.cmd("wincmd J")
        end
    else
        if fugitive_buf ~= -1 then
            -- Buffer exists but no window in this tab
            if is_fresh_tab then
                fugitive_win = original_win
            else
                if layout == "v" then
                    vim.cmd("leftabove vsplit")
                else
                    vim.cmd("rightbelow split")
                end
                fugitive_win = vim.api.nvim_get_current_win()
            end
            vim.api.nvim_win_set_buf(fugitive_win, fugitive_buf)
        else
            -- Use G to open fugitive
            local ok, err = pcall(vim.cmd, "G")
            if not ok then
                vim.notify("Fugitive failed: " .. tostring(err), vim.log.levels.ERROR)
                return
            end

            -- Find the newly opened fugitive window
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                local buf = vim.api.nvim_win_get_buf(win)
                if vim.bo[buf].filetype == "fugitive" then
                    fugitive_win = win
                    break
                end
            end

            -- If G opened in a split and we had a fresh tab, close the empty buffer
            if is_fresh_tab and fugitive_win ~= -1 and fugitive_win ~= original_win then
                pcall(vim.api.nvim_win_close, original_win, false)
                -- Update original_win to fugitive_win so focus restoration works
                original_win = fugitive_win
                original_cursor = { 1, 0 }
            end
        end
        vim.api.nvim_set_current_win(fugitive_win)
        if layout == "v" then
            vim.cmd("wincmd H")
        else
            vim.cmd("wincmd J")
        end
    end

    refresh_fugitive_status(fugitive_win)

    -- 3. Recreate GitGraph as a direct split of fugitive so no window sits between them.
    if gitgraph_win ~= -1 and vim.api.nvim_win_is_valid(gitgraph_win) then
        if original_win == gitgraph_win then
            original_win = -1
        end
        pcall(vim.api.nvim_win_close, gitgraph_win, false)
        gitgraph_win = -1
    end

    vim.api.nvim_set_current_win(fugitive_win)
    if layout == "v" then
        vim.cmd("rightbelow vsplit")
    else
        vim.cmd("leftabove split")
    end
    gitgraph_win = vim.api.nvim_get_current_win()
    if gitgraph_buf ~= -1 then
        vim.api.nvim_win_set_buf(gitgraph_win, gitgraph_buf)
    end
    if is_gitgraph_buffer(original_buf) then
        original_win = gitgraph_win
    end

    -- 4. Draw
    vim.api.nvim_set_current_win(gitgraph_win)
    require("gitgraph").draw({}, { all = true, max_count = 5000 })
    map_gitgraph_commit_message(vim.api.nvim_win_get_buf(gitgraph_win))

    -- Remove leftover windows so the Git tab stays |fugitive|gitgraph|.
    local final_wins = vim.api.nvim_tabpage_list_wins(current_tab)
    for _, win in ipairs(final_wins) do
        if win ~= fugitive_win and win ~= gitgraph_win then
            if win == original_win then
                original_win = fugitive_win
                original_cursor = { 1, 0 }
            end
            pcall(vim.api.nvim_win_close, win, true)
        end
    end

    if vim.api.nvim_win_is_valid(fugitive_win) then
        vim.api.nvim_set_current_win(fugitive_win)
        if layout == "v" then
            vim.cmd("wincmd H")
        else
            vim.cmd("wincmd J")
        end
    end
    if vim.api.nvim_win_is_valid(gitgraph_win) then
        vim.api.nvim_set_current_win(gitgraph_win)
        if layout == "v" then
            vim.cmd("wincmd L")
        else
            vim.cmd("wincmd K")
        end
    end

    -- 5. Restore original window focus and cursor position
    if original_win and vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
        -- Only restore cursor if it's still within bounds (just in case the graph shrank)
        pcall(vim.api.nvim_win_set_cursor, original_win, original_cursor)
    end
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
        M.open_gitgraph("s")
    end, { desc = "Rookie GitGraph - Draw (vertical)" })

    vim.api.nvim_create_user_command("Ggv", function()
        M.open_gitgraph("v")
    end, { desc = "Rookie GitGraph - Draw (stacked)" })

    vim.api.nvim_create_user_command("RkGit", function(opts)
        if #opts.fargs == 0 then
            vim.notify("Usage: RkGit <git command>", vim.log.levels.ERROR)
            return
        end
        local cmd_str = table.concat(opts.fargs, " ")
        vim.notify("Git " .. cmd_str .. "...", vim.log.levels.INFO)
        vim.fn.jobstart(vim.list_extend({ "git" }, opts.fargs))
    end, { nargs = "*", complete = "shellcmd" })

end

return M
