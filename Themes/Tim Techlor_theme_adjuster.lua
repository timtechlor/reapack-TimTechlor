-- @description Tim Techlor Theme Adjuster
-- @version 1.0.0
-- @author Tim Techlor
-- @about
--   Opens the Tim Techlor Theme Adjuster from Options > Themes > Theme Adjuster / Color Controls.
--   The theme names this file in rtconfig (adjuster_script). The window itself is TT_ThemeAdjuster.lua
--   in Scripts/TimTechlor. Load this file once from the action list; after that the menu finds it.
-- @changelog
--   1.0.0 Menu entry for the Tim Techlor theme. Runs TT_ThemeAdjuster.lua.

local R = reaper
local VERSION = "1.0.0"
local sep = package.config:sub(1, 1)

local function dirname(p)
  return (p or ""):gsub("^@", ""):match("^(.*[/\\])") or ""
end

local here = dirname(debug.getinfo(1, "S").source)
local res = (R.GetResourcePath and R.GetResourcePath()) or ""
local cands = {
  here .. "TT_ThemeAdjuster.lua",
  here .. ".." .. sep .. "TimTechlor" .. sep .. "TT_ThemeAdjuster.lua",
}
if res ~= "" then
  cands[#cands + 1] = res .. sep .. "Scripts" .. sep .. "TimTechlor" .. sep .. "TT_ThemeAdjuster.lua"
end

local target
for _, p in ipairs(cands) do
  local f = io.open(p, "rb")
  if f then f:close(); target = p; break end
end

if not target then
  local expect = (res ~= "" and (res .. sep) or "") .. "Scripts" .. sep .. "TimTechlor" .. sep .. "TT_ThemeAdjuster.lua"
  R.MB("The Tim Techlor Theme Adjuster was not found.\n\nExpected:\n" .. expect
    .. "\n\nCopy the Scripts folder from the theme package into the REAPER resource path, then load this script once from the action list.",
    "Tim Techlor", 0)
  return
end

local ok, err = pcall(dofile, target)
if not ok then
  R.ShowConsoleMsg("Tim Techlor Theme Adjuster: " .. tostring(err) .. "\n")
  R.MB(tostring(err), "Tim Techlor Theme Adjuster", 0)
end
