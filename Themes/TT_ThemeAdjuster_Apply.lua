-- @description TT Theme Adjuster - apply saved adjustments silently (use as REAPER startup action)
-- @version 1.0.0
-- Re-applies the last values of TT_ThemeAdjuster (colours and layout parameters) without opening a window.
-- If SELECTION FRAME or LOGO WATERMARK was on, those overlays keep drawing. ReaImGui is not required.
-- Set it up once: SWS "Set global startup action" (or add a line to Scripts/__startup.lua).
TT_ADJ_APPLY_ONLY = true
local src = (debug and debug.getinfo and debug.getinfo(1, "S") and debug.getinfo(1, "S").source or ""):gsub("^@", "")
local dir = src:match("^(.*[/\\])") or (({ reaper.get_action_context() })[2] or ""):match("^(.*[/\\])") or ""
local ok, err = pcall(dofile, dir .. "TT_ThemeAdjuster.lua")
TT_ADJ_APPLY_ONLY = nil
if not ok then reaper.ShowConsoleMsg("TT Theme Adjuster (apply): " .. tostring(err) .. "\n") end
