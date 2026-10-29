-- @description TT-KNOBMOVER: import service (makes the REGIONS button in the plug-in work)
-- @author TimTechlor
-- @version 1.0.0
-- @about
--   Start this action once (it keeps running in the background, also via a startup action). While it runs, the REGIONS button in the TT-KNOBMOVER
--   header imports the project's regions / markers as sections - the plug-in cannot read project markers itself, this script does it for the instance
--   whose button was pressed. Without the service, run "TT-KNOBMOVER: import regions (or markers) as sections" from the Action list instead.
--   Stop it from the Action list (terminate instances) or by closing REAPER.
-- @changelog
--   1.0.0 - First version (TT-KNOBMOVER 0.9.0).

local dir = ((debug.getinfo(1, "S").source or ""):match("^@(.*[/\\])")) or ""
local lib = dofile(dir .. "tt_km_import.lua")

reaper.gmem_attach(lib.NS)
local B = lib.SVCB
local seen = reaper.gmem_read(B) or 0
local beat, last_beat = 0, 0

local function find_by_cookie(cookie)
  for _, inst in ipairs(lib.instances()) do
    local cp = lib.param_index(inst.tr, inst.fx, "IMPORT COOKIE", 22)
    local v = reaper.TrackFX_GetParam(inst.tr, inst.fx, cp)
    if v and math.floor(v + 0.5) == cookie then return inst end
  end
end

local function loop()
  reaper.gmem_attach(lib.NS)
  local now = reaper.time_precise()
  if now - last_beat > 0.4 then                    -- Herzschlag: das Plugin sieht, dass der Dienst laeuft
    beat = (beat % 1000000) + 1
    reaper.gmem_write(B + 2, beat)
    last_beat = now
  end
  local req = reaper.gmem_read(B)
  if req ~= seen then
    seen = req
    local cookie = math.floor(reaper.gmem_read(B + 1) + 0.5)
    local inst = find_by_cookie(cookie)
    if not inst then
      reaper.gmem_write(B + 3, 2)                  -- 2: Instanz nicht gefunden
      -- 25.10.2026 (Review knobmover-R017): auch der Fehler muss den Ergebniszaehler erhoehen -
      -- die Front wartet auf B+4 und sah den Fehler sonst nie.
      reaper.gmem_write(B + 4, (reaper.gmem_read(B + 4) or 0) + 1)
    else
      local ok, txt = lib.run("auto", inst)
      reaper.gmem_write(B + 3, ok and 0 or 1)      -- 1: keine Regionen/Marker
      reaper.gmem_write(B + 4, (reaper.gmem_read(B + 4) or 0) + 1)   -- Ergebniszaehler
    end
  end
  reaper.defer(loop)
end

loop()
