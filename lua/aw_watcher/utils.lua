local function get_filename()
    local path = vim.fn.expand("%p") or ""

    if path:match("^oil://") then
        path = path:gsub("^oil://", "")
    end

    if path:match("^fugitive://") then
        path = path:gsub("^fugitive://", "")
    end

    return path
end

local function get_filetype() return vim.bo.filetype end

local function set_project_name()
    vim.b.project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
    local current_file_path = vim.api.nvim_buf_get_name(0)
    if current_file_path:match("^oil://") then
        current_file_path = current_file_path:gsub("^oil://", "")
    end

    if current_file_path:match("^fugitive://") then
        current_file_path = current_file_path:gsub("^fugitive://", "")
    end

    -- Traverse parent directories to find Git root or worktree
    for dir in vim.fs.parents(vim.api.nvim_buf_get_name(0)) do
        -- Check if .git is a directory (standard repository)
        if vim.fn.isdirectory(dir .. "/.git") == 1 then
            local url = vim.fn.system("git -C " .. dir .. " config --local remote.origin.url")
            url = url:gsub("%s+$", "") -- Remove trailing whitespace
            if url ~= "" then
                vim.b.project_name = url:match(".+/(.+)%.git$") or url
                return vim.b.project_name
            end
            vim.b.project_name = vim.fn.fnamemodify(dir, ":t") -- Fallback to directory name
            return vim.b.project_name

        -- Check if .git is a file (worktree)
        elseif vim.fn.filereadable(dir .. "/.git") == 1 then
            local git_file = vim.fn.readfile(dir .. "/.git")[1]
            local gitdir = git_file:match("gitdir:%s*(.+)")
            if gitdir then
                local main_repo_path = vim.fn.fnamemodify(gitdir, ":h:h:h")
                local url = vim.fn.system("git -C " .. main_repo_path .. " config --local remote.origin.url")
                url = url:gsub("%s+$", "")
                local repo_name = url ~= "" and (url:match(".+/(.+)%.git$") or url)
                    or vim.fn.fnamemodify(main_repo_path, ":t")
                local worktree_name = vim.fn.fnamemodify(dir, ":t")
                if worktree_name == "." then
                    vim.b.project_name = repo_name
                else
                    vim.b.project_name = repo_name .. "." .. worktree_name
                end

                return vim.b.project_name
            end
        end
    end

    return nil
end

local function set_branch_name()
    local branch = vim.fn.system("git rev-parse --abbrev-ref HEAD")

    -- If the command fails, it returns the error as a string
    if branch:match("fatal:") or branch == "" then
        branch = "unknown"
    end

    vim.b.branch_name = branch
    return vim.b.branch_name
end

local has_notify, notify = pcall(require, "notify")
if has_notify then
    function notify(msg, level)
        vim.schedule(function() notify(msg, level, { title = "Activity Watcher" }) end)
    end
else
    function notify(msg, level)
        vim.schedule(function() vim.notify("[Activity Watcher] " .. msg, level) end)
    end
end

return {
    get_filename = get_filename,
    get_filetype = get_filetype,
    set_project_name = set_project_name,
    set_branch_name = set_branch_name,
    notify = notify,
}
