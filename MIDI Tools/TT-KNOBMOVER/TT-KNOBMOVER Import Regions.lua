-- @description TT-KNOBMOVER: import regions (or markers) as sections
-- @author TimTechlor
-- @version 1.0.0
-- @about
--   Takes the regions of the project (or, if there are none, the markers) and turns them into the sections of a TT-KNOBMOVER:
--   one section per region / marker, length in whole bars, section type guessed from the name (intro, verse, build, pre, drop, fill, break, outro ...),
--   START BAR set to the bar of the first region. Works on the TT-KNOBMOVER of the first selected track, otherwise the first one in the project.
--   A time selection limits the import to the regions / markers inside it. Undo with Ctrl+Z.
-- @changelog
--   1.0.0 - First version (TT-KNOBMOVER 0.9.0).

local dir = ((debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or ""
local lib = dofile(dir .. "tt_km_import.lua")

local ok, txt = lib.run("auto")
if not ok then
  reaper.ShowMessageBox("TT-KNOBMOVER import: " .. txt, "TT-KNOBMOVER", 0)
end
-- bei Erfolg meldet das Plugin das Ergebnis selbst in seiner Statuszeile (IMPORTED n SECTIONS)
