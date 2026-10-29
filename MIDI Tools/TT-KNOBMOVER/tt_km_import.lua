-- tt_km_import.lua - gemeinsamer Code der KNOBMOVER-Import-Skripte (TT-KNOBMOVER 0.9.0)
--
-- Liest die Regionen (oder, wenn es keine gibt, die Marker) des REAPER-Projekts und schickt sie als Abschnitte an eine TT-KNOBMOVER-Instanz.
-- Weg: Liste -> gmem (Namensraum "ttknobmover") -> versteckter Regler IMPORT TOKEN dieser Instanz. Nur die Instanz, deren Regler sich aendert, liest die
-- Liste (so gehen mehrere KNOBMOVER im Projekt nicht durcheinander). Das Plugin fuegt sie wie jede Bearbeitung ein (Strg+Z macht sie rueckgaengig).
--
-- Umrechnung: Position in Viertelnoten (TimeMap2_timeToQN) geteilt durch die Taktlaenge in Viertelnoten (Taktart am Anfang der ersten Region,
-- wie das Plugin sie annimmt: es rechnet mit einer festen Taktart). Grenzen werden auf ganze Takte gerundet; START BAR = Takt der ersten Grenze.
-- Luecken zwischen Regionen schliesst der vorige Abschnitt, Ueberlappungen werden am naechsten Anfang abgeschnitten.
-- Marker: Abschnitt = von Marker zu Marker, der letzte bis zum Marker "end" (sonst bis zum Projektende).
-- Abschnittstyp aus dem Namen (Stichworte unten); ohne Treffer ROLL.

local M = {}

M.NS = "ttknobmover"
M.IMPB = 30000          -- gmem-Bruecke des Imports (wie KM_IMPB im Plugin)
M.SVCB = 30500          -- gmem-Bruecke zum Dienst (wie KM_SVCB)
M.MAXSEG = 64
M.MAXBARS = 256

-- Stichworte je Typ; geprueft wird je Wort des Namens (Anfang des Wortes). Reihenfolge = Vorrang.
local KEYS = {
  { 7, { "pre", "prechorus", "predrop", "preroll", "lead" } },
  { 4, { "fill", "turnaround" } },
  { 3, { "drop", "chorus", "hook", "climax", "peak", "main", "refrain" } },
  { 2, { "build", "riser", "rise", "lift", "ramp", "tension", "sweep" } },
  { 6, { "break", "bridge", "interlude", "down", "bridge", "silence", "pause" } },
  { 5, { "reset", "outro", "end", "fade", "out", "finish", "coda" } },
  { 0, { "tease", "intro", "start", "opening", "begin", "silent" } },
  { 1, { "verse", "groove", "roll", "loop", "vers", "bass", "theme", "a1" } },
}
local CODES = { a0 = 0, a1 = 1, a2 = 2, a3 = 3, a4 = 4, a5 = 5, brk = 6, pre = 7 }

function M.guess_type(name)
  name = (name or ""):lower()
  for w in name:gmatch("[%w]+") do
    if CODES[w] then return CODES[w] end
  end
  if name:find("pre%-?%s*drop") or name:find("pre%-?%s*chorus") then return 7 end
  for _, e in ipairs(KEYS) do
    for w in name:gmatch("[%w]+") do
      for _, k in ipairs(e[2]) do
        if w:sub(1, #k) == k then return e[1] end
      end
    end
  end
  return 1
end

-- ---------------------------------------------------------------- Projekt lesen
function M.collect(use)            -- use: "auto" | "regions" | "markers"
  local regs, marks = {}, {}
  local i = 0
  while true do
    local ret, isrgn, pos, rgnend, name = reaper.EnumProjectMarkers3(0, i)
    if ret == 0 or ret == nil then break end
    if isrgn then regs[#regs + 1] = { pos = pos, stop = rgnend, name = name }
    else marks[#marks + 1] = { pos = pos, stop = pos, name = name } end
    i = i + 1
  end
  local t0, t1 = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  local function sel(list)
    if t1 - t0 < 0.0001 then return list end
    local out = {}
    for _, e in ipairs(list) do
      if e.stop >= t0 and e.pos <= t1 then out[#out + 1] = e end
    end
    return out
  end
  local src
  if use == "markers" then src = "markers"
  elseif use == "regions" then src = "regions"
  else src = (#regs > 0) and "regions" or "markers" end
  local list = sel(src == "regions" and regs or marks)
  table.sort(list, function(a, b) return a.pos < b.pos end)
  -- Marker: ein letzter Marker mit dem Namen "end" / "!end" ist kein Abschnitt, sondern das Ende des letzten
  local stop
  if src == "markers" and #list > 1 then
    local nm = (list[#list].name or ""):lower():gsub("^%s*!", ""):gsub("%s+$", "")
    if nm == "end" then stop = list[#list].pos; list[#list] = nil end
  end
  return list, src, stop
end

-- Liste -> Abschnitte (Laenge in Takten, Typ), START BAR (1-basiert)
function M.build(list, src, stop)
  if #list == 0 then return nil, "no" end
  local first = list[1].pos
  local num, den = reaper.TimeMap_GetTimeSigAtTime(0, first)
  num = (num and num > 0) and num or 4
  den = (den and den > 0) and den or 4
  local bar_qn = num * 4 / den
  local function bar(t) return reaper.TimeMap2_timeToQN(0, t) / bar_qn end
  local bounds = {}
  for i, e in ipairs(list) do bounds[i] = math.floor(bar(e.pos) + 0.5) end
  -- Ende der letzten Region bzw. des Projekts (bei Markern)
  local last_end
  if src == "regions" then last_end = math.floor(bar(list[#list].stop) + 0.5)
  else last_end = math.floor(bar(stop or reaper.GetProjectLength(0)) + 0.5) end
  bounds[#list + 1] = last_end
  local secs, trunc = {}, false
  local total = 0
  for i = 1, #list do
    local len = bounds[i + 1] - bounds[i]
    if len < 1 then len = 1 end          -- zu kurze Abschnitte bekommen einen Takt
    if #secs >= M.MAXSEG then trunc = true break end
    if total + len > M.MAXBARS then
      len = M.MAXBARS - total
      trunc = true
    end
    if len < 1 then break end
    secs[#secs + 1] = { len = len, ty = M.guess_type(list[i].name), name = list[i].name }
    total = total + len
    if trunc then break end
  end
  return { secs = secs, start = bounds[1] + 1, total = total, truncated = trunc, bar_qn = bar_qn, src = src }
end

-- ---------------------------------------------------------------- Instanzen finden
local function fxname(tr, fx)
  local _, n = reaper.TrackFX_GetFXName(tr, fx, "")
  return n or ""
end

-- alle Instanzen: { tr =, fx =, trname =, sel = }
function M.instances()
  local out = {}
  local function scan(tr, istrack)
    local n = reaper.TrackFX_GetCount(tr)
    for fx = 0, n - 1 do
      if fxname(tr, fx):lower():find("knobmover", 1, true) then
        local _, tn = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        out[#out + 1] = { tr = tr, fx = fx, trname = (tn ~= "" and tn) or "Track", sel = istrack and reaper.IsTrackSelected(tr) or false }
      end
    end
  end
  scan(reaper.GetMasterTrack(0), false)
  for i = 0, reaper.CountTracks(0) - 1 do scan(reaper.GetTrack(0, i), true) end
  return out
end

-- Parameterindex eines versteckten Reglers nach Name (Rueckfall: Sliderzahl - 1)
function M.param_index(tr, fx, key, fallback)
  local n = reaper.TrackFX_GetNumParams(tr, fx)
  for p = 0, n - 1 do
    local _, nm = reaper.TrackFX_GetParamName(tr, fx, p, "")
    if nm and nm:upper():find(key, 1, true) then return p end
  end
  return fallback
end

function M.pick(insts)
  for _, e in ipairs(insts) do if e.sel then return e end end
  return insts[1]
end

-- ---------------------------------------------------------------- an die Instanz senden
function M.send(inst, plan)
  reaper.gmem_attach(M.NS)
  local tp = M.param_index(inst.tr, inst.fx, "IMPORT TOKEN", 21)
  local cur = reaper.TrackFX_GetParam(inst.tr, inst.fx, tp) or 0
  local tok = (math.floor(cur) + 1) % 16000000
  if tok < 1 then tok = 1 end
  local B = M.IMPB
  reaper.gmem_write(B + 1, #plan.secs)
  reaper.gmem_write(B + 2, plan.start)
  reaper.gmem_write(B + 3, plan.src == "regions" and 0 or 1)
  for i, s in ipairs(plan.secs) do
    reaper.gmem_write(B + 10 + (i - 1) * 2, s.len)
    reaper.gmem_write(B + 11 + (i - 1) * 2, s.ty)
  end
  reaper.gmem_write(B, tok)                       -- zuletzt: das Plugin prueft Token == Regler
  reaper.TrackFX_SetParam(inst.tr, inst.fx, tp, tok)
  return tok
end

-- komplett: Projekt lesen, Instanz waehlen, senden. Rueckgabe: ok, Text
function M.run(use, inst)
  local list, src, stop = M.collect(use or "auto")
  if #list == 0 then return false, "no regions or markers in the project (or none inside the time selection)" end
  local plan = M.build(list, src, stop)
  if not plan then return false, "nothing to import" end
  if not inst then
    local insts = M.instances()
    if #insts == 0 then return false, "no TT-KNOBMOVER found on any track" end
    inst = M.pick(insts)
  end
  reaper.Undo_BeginBlock2(0)
  M.send(inst, plan)
  reaper.Undo_EndBlock2(0, "TT-KNOBMOVER: import " .. src .. " as sections", -1)
  local txt = string.format("%d sections from %s, %d bars, START BAR %d, track '%s'%s", #plan.secs, src, plan.total, plan.start, inst.trname,
    plan.truncated and " (cut at 64 sections / 256 bars)" or "")
  return true, txt, plan
end

return M
