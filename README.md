# rookie_git.nvim

Tools to enhance Git workflows in Neovim: integrates git graph drawing, diffview integration, gitsigns keymaps and a few small helper commands to inspect and operate on commits/hunks.

Features

- Open a Git graph and draw commits (commands: `:RkGitGraph`, `:Gg`).
- Run git commands asynchronously and refresh the graph (`:RkGit <args>`).
- diffview integration for comparing commits under cursor (keymap: `<leader>diff`).
- gitsigns integration with convenient hunk mappings (e.g. `<leader>hs`, `<leader>hu`, `<leader>hp`).
- Jump to next differing column in a diff split (`<leader>jd` / command `:RkGitdiffJumpToNextChange`).

Requirements

- Neovim (0.7+ recommended).
- Optional plugins that enhance full functionality:
  - `sindrets/diffview.nvim` (provides `require("diffview")`)
  - `lewis6991/gitsigns.nvim` (provides `require("gitsigns")`)
  - A plugin that exposes the `gitgraph` Lua module (the code calls `require("gitgraph")`).
  - Optional: `folke/tokyonight.nvim` for nicer gitgraph colors.

Installation (lazy.nvim)

Example lazy.nvim configuration entry:

```lua
require("lazy").setup({
  {
    -- replace with your GitHub path, e.g. "yourname/rookie_git.nvim"
    "modulomedito/rookie_git.nvim",
    -- Recommended dependencies; replace the gitgraph entry with whichever plugin
    -- you use that provides a `require("gitgraph")` module.
    dependencies = {
      "sindrets/diffview.nvim",
      "lewis6991/gitsigns.nvim",
      "modulomedito/gitgraph.nvim",
      "tpope/vim-fugitive",
    },
    config = function()
      require("rookie_git").setup()
    end,
  },
})
```

Usage

- After installation, the plugin will register a few commands and keymaps. Call `require("rookie_git").setup()` manually if you prefer not to auto-run on load.

Notes

- The plugin code uses `require("gitgraph")`, `require("diffview")` and `require("gitsigns")`. Make sure the corresponding plugin that provides those Lua modules is installed for the related features to work.

License: MIT
