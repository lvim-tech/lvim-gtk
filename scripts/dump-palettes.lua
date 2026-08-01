-- lvim-gtk: evaluate every lvim-colorscheme style and write the raw colours as JSON.
--
-- Neovim does the reading, and it has to. Twelve of the styles are not tables at all: a `*_light`
-- file returns a FUNCTION that computes its palette from another style at call time, and the
-- `*_soft` / `*_darker` ones inherit through `vim.deepcopy(require(...))`. Parsing the Lua text
-- instead yields the dark styles and silently drops the rest — a first attempt here produced 36
-- palettes and no warning that a quarter was missing.
--
-- BOTH PATHS ARE REQUIRED, AND THERE IS NO DEFAULT ON PURPOSE. This file used to fall back to
-- ~/lvim-tech/lvim-colorscheme when the variable was unset, which made it a SECOND place that
-- decides where the colorscheme lives — `scripts/palettes` being the first. Two sources of truth
-- for one question always end the same way: the day the resolution order changes in one of them,
-- the other quietly disagrees, and `--repo` builds from the local checkout while reporting that it
-- downloaded. Better to refuse than to guess wrong silently.

local root = vim.env.LVIM_COLORSCHEME
local out_path = vim.env.LVIM_GTK_PALETTES_JSON

if not root or root == "" or not out_path or out_path == "" then
    error("LVIM_COLORSCHEME and LVIM_GTK_PALETTES_JSON must both be set — run scripts/palettes")
end

local colors_dir = root .. "/lua/lvim-colorscheme/colors"
if vim.fn.isdirectory(colors_dir) == 0 then
    error("no lvim-colorscheme in " .. root)
end

vim.opt.rtp:prepend(root)

local out, n = {}, 0
for _, f in ipairs(vim.fn.readdir(colors_dir)) do
    local style = f:gsub("%.lua$", "")
    if style ~= "init" and f:match("%.lua$") then
        local ok, mod = pcall(require, "lvim-colorscheme.colors." .. style)
        if ok then
            local pal = mod
            if type(mod) == "function" then
                local ok2, r = pcall(mod, { style = style, transparent = false, terminal_colors = true, styles = {} })
                pal = ok2 and r or nil
            end
            if type(pal) == "table" and pal.bg then
                local flat = {}
                for k, v in pairs(pal) do
                    if type(v) == "string" and v:match("^#%x%x%x%x%x%x$") then
                        flat[k] = v
                    end
                end
                out[style] = flat
                n = n + 1
            end
        end
    end
end

vim.fn.writefile({ vim.json.encode(out) }, out_path)
print("palettes: " .. n)
