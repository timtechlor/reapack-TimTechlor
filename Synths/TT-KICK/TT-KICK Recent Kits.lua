-- ============================================================
-- TT-KICK Recent Kits
-- TimTechlor / TT-KICK Kick Machine
--
-- Zero-dialog re-load: shows a menu with the last kits (up to 8)
-- and loads the chosen one into ONE TT-KICK instance: the TT-KICK
-- window that has (or last had) the focus, otherwise the first
-- TT-KICK on the selected track.
--
-- How it works: "TT-KICK Load Kit (Folder)" and "(from Items)"
-- store the kit folder in <REAPER resource path>/tt-kick-recent.txt
-- (one path per line, newest on top, duplicates rotate to the top)
-- and leave a copy of tt-kick-kit.bin/.txt in that folder. This
-- script reads the folder's tt-kick-kit.bin and sends the three
-- paths to the target instance. Works across projects.
--
-- Limits: kits loaded with the old "TT-KICK Load Kit" are not
-- listed (it writes no copy). Entries whose folder or
-- tt-kick-kit.bin is gone are greyed out in the menu.
--
-- Usage: Actions -> Show action list -> "New action..." ->
-- load this script once -> click into the TT-KICK window (or
-- select its track) -> run it -> pick a kit.
-- ============================================================

-- ------------------------------------------------------------
-- Kit JE INSTANZ: ein Kit geht an genau EINE Instanz: das fokussierte (oder zuletzt fokussierte, noch
-- offene) TT-KICK-Fenster, sonst den ersten TT-KICK auf der ersten ausgewaehlten Spur. Uebergabe: Pfade in gmem
-- (Namespace "ttkk", Worte 16..783, je Slot Laenge + Zeichen, 256 Worte), Seriennummer in gmem[0]; dann setzt das
-- Skript den Parameter "Kit request" dieser Instanz auf dieselbe Nummer. Das FX quittiert in gmem[1]; danach legt
-- das Skript einen Undo-Punkt an (die Pfade stehen dann im Projekt). Leere Eintraege lassen den Slot stehen.
-- ------------------------------------------------------------
local KQ_SER, KQ_ACK, KQ_DAT = 0, 1, 16

local function kitParam(tr, fx)
  for k = 0, reaper.TrackFX_GetNumParams(tr, fx) - 1 do
    local _, pn = reaper.TrackFX_GetParamName(tr, fx, k, "")
    if pn:find("^Kit request") then return k end
  end
  return nil
end

-- Ziel-Instanz: Rueckgabe tr, fx, Parameterindex - oder nil und ein Hinweistext
-- 25.10.2026 (Review kick-R018): dieselbe Suche ueber die TakeFX-API (Take-FX-Instanz)
local function kitParamTk(take, fx)
  for k = 0, reaper.TakeFX_GetNumParams(take, fx) - 1 do
    local _, pn = reaper.TakeFX_GetParamName(take, fx, k, "")
    if pn:find("^Kit request") then return k end
  end
  return nil
end

local function findKick()
  local function probe(tr, fx)
    return kitParam(tr, fx)
  end
  local getf = reaper.GetFocusedFX2 or reaper.GetFocusedFX
  local rv, trn, itm, fxn = getf()
  -- 25.10.2026 (Review kick-R018): Take-FX (Bit 2) mitbehandeln; vorher fiel ein fokussiertes
  -- Take-Fenster auf die Spurensuche zurueck und meldete dort "No TT-KICK found". Bit 4 heisst
  -- nur "Fenster offen, aber nicht fokussiert" (kein eigener FX-Typ); Master-FX kommt ueber den
  -- Track-FX-Pfad mit trn == 0 -> GetMasterTrack mit.
  if rv and rv ~= 0 and (rv & 2) == 2 and trn and itm and itm >= 0 then  -- Take-FX: fxnumber = take-Idx<<16 | FX-Idx
    local tr = reaper.GetTrack(0, trn - 1)
    local item = tr and reaper.GetTrackMediaItem(tr, itm)
    local take = item and reaper.GetTake(item, (fxn or 0) >> 16)
    local tkfx = (fxn or 0) & 0xFFFF
    local k = take and kitParamTk(take, tkfx)
    if k then return tr, fxn, k, take, tkfx end
  elseif rv and rv ~= 0 and (rv & 1) == 1 and trn and fxn then
    local tr = (trn == 0) and reaper.GetMasterTrack(0) or reaper.GetTrack(0, trn - 1)
    if tr then
      local k = probe(tr, fxn)
      if k then return tr, fxn, k end
    end
  end
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    local tr = reaper.GetSelectedTrack(0, i)
    for fx = 0, reaper.TrackFX_GetCount(tr) - 1 do
      local k = probe(tr, fx)
      if k then return tr, fx, k end
    end
  end
  return nil, "No TT-KICK found.\n\nClick into the TT-KICK window (or select its track), then run this action again."
end

local function trackLabel(tr)
  local n = reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
  if n == -1 then return "the master track" end
  local _, nm = reaper.GetTrackName(tr)
  return string.format("track %d (%s)", math.floor(n), nm)
end

-- Kit an die Instanz senden, auf die Quittung warten (defer, hoechstens 3 s), dann Undo-Punkt + Meldung.
-- report: Text oder Funktion(n) mit n = Zahl der tatsaechlich uebergebenen Slots.
local function sendKit(tr, fx, k, slots, title, report, take, tkfx)
  -- 25.10.2026 (Review kick-R018): Take-FX-Instanz? Dann Parameterpfad ueber TakeFX_* statt TrackFX_*
  local getP = take and (function() return reaper.TakeFX_GetParam(take, tkfx, k) end)
                    or  (function() return reaper.TrackFX_GetParam(tr, fx, k) end)
  local setP = take and (function(v) reaper.TakeFX_SetParam(take, tkfx, k, v) end)
                    or  (function(v) reaper.TrackFX_SetParam(tr, fx, k, v) end)
  local label = trackLabel(tr) .. (take and ", take FX" or "")
  -- Das Protokoll fasst je Slot 255 Zeichen (kitReq liest nur 255): einen laengeren Pfad ablehnen
  -- statt still zu kuerzen - gekuerzt zeigte er auf eine nicht existierende Datei ("LOAD ERROR").
  local sent, n = {}, 0
  for s = 1, 3 do
    local p = slots[s] or ""
    if #p > 255 then
      reaper.MB("Path longer than 255 characters, slot " .. s .. " skipped:\n" .. p, title, 0)
      p = ""
    end
    sent[s] = p
    if p ~= "" then n = n + 1 end
  end
  if n == 0 then return end   -- nichts zu uebergeben: keine Anfrage, kein Undo-Punkt, keine Erfolgsmeldung
  if type(report) == "function" then report = report(n) end
  reaper.gmem_attach("ttkk")
  for s = 1, 3 do
    local p = sent[s]
    local a = KQ_DAT + (s - 1) * 256
    reaper.gmem_write(a, #p)
    for c = 1, #p do reaper.gmem_write(a + c, p:byte(c)) end
  end
  -- neue Nummer: nie gleich dem aktuellen Parameterwert (sonst laeuft @slider nicht) und nie gleich der letzten Quittung
  local cur = math.floor(getP() + 0.5)
  local ack = reaper.gmem_read(KQ_ACK)
  local sn = math.floor(reaper.time_precise() * 1000) % 16777215 + 1
  while sn == cur or sn == ack do sn = sn % 16777215 + 1 end
  reaper.gmem_write(KQ_SER, sn)
  setP(sn)
  local t0 = reaper.time_precise()
  local function poll()
    if reaper.gmem_read(KQ_ACK) == sn then
      if not pcall(reaper.Undo_OnStateChangeEx2, 0, "TT-KICK: assign kit", 2, -1) then
        reaper.Undo_OnStateChange("TT-KICK: assign kit")
      end
      reaper.MB(report .. "\n\nLoaded into TT-KICK on " .. label .. ".", title, 0)
    elseif reaper.time_precise() - t0 > 3 then
      reaper.MB(report .. "\n\nTT-KICK on " .. label .. " has not confirmed yet (audio engine stopped, " ..
        "FX bypassed or offline?). It loads the kit as soon as it runs again; if not, run this action again.", title, 0)
    else
      reaper.defer(poll)
    end
  end
  poll()
end

local TITLE = "TT-KICK Recent Kits"
local BIN_SIZE = 768 * 4   -- 3 slots x 256 words x float32
-- aeltere Kopien tragen zusaetzlich eine Seriennummer (769. Wort) - beide Laengen sind gueltig

local function readAll(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("a")
  f:close()
  return d
end

local function binOk(folder)
  local d = readAll(folder .. "/tt-kick-kit.bin")
  return d ~= nil and (#d == BIN_SIZE or #d == BIN_SIZE + 4), d
end

-- P26: die drei Pfade aus einer Ordner-bin lesen (je Slot float32-Laenge + 255 float32-Zeichen, wie geschrieben)
local function binSlots(d)
  local slots, pos = {}, 1
  for s = 1, 3 do
    local L = math.floor(string.unpack("f", d, pos) + 0.5)
    L = math.max(0, math.min(255, L))
    local t = {}
    for c = 1, 255 do
      if c <= L then
        local v = math.floor(string.unpack("f", d, pos + 4 * c) + 0.5)
        t[#t + 1] = string.char(math.max(0, math.min(255, v)))
      end
    end
    slots[s] = table.concat(t)
    pos = pos + 256 * 4
  end
  return slots
end

-- menu-safe label: | separates items, leading # ! > < are menu flags
local function label(s)
  s = s:gsub("|", "/")
  return (s:gsub("^[#!<>]+", ""))
end

local function main()
  -- P26: Ziel zuerst bestimmen (das Menue verschiebt den Fokus)
  local tr, fx, k, take, tkfx = findKick()
  if not tr then reaper.MB(fx, TITLE, 0) return end

  local recent = {}
  local f = io.open(reaper.GetResourcePath() .. "/tt-kick-recent.txt", "r")
  if f then
    for raw in f:lines() do
      local line = raw:gsub("\r$", "")   -- P25: Schleifenvariable nicht neu zuweisen (in Lua 5.5 konstant)
      if line ~= "" and #recent < 8 then recent[#recent + 1] = line end
    end
    f:close()
  end

  if #recent == 0 then
    reaper.MB("No recent kit yet.\n\nLoad a kit with \"TT-KICK Load Kit (Folder)\" " ..
      "or \"TT-KICK Load Kit (from Items)\" first.", TITLE, 0)
    return
  end

  local items = {}
  for i, folder in ipairs(recent) do
    local base = folder:gsub("\\", "/"):match("([^/]+)/*$") or folder
    local parent = folder:gsub("\\", "/"):match("([^/]+)/[^/]+/*$")
    local text = label(base .. (parent and ("   (" .. parent .. ")") or ""))
    items[i] = (binOk(folder) and "" or "#") .. text
  end

  -- ShowMenu needs a gfx window; open it hidden-small at the mouse
  local mx, my = reaper.GetMousePosition()
  gfx.init("TT-KICK Recent Kits", 0, 0, 0, mx, my)
  gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
  local choice = gfx.showmenu(table.concat(items, "|"))
  gfx.quit()
  if choice < 1 then return end

  local folder = recent[choice]
  local ok, data = binOk(folder)
  if not ok then
    reaper.MB("tt-kick-kit.bin is missing or invalid in:\n" .. folder ..
      "\n\nLoad the kit again with one of the other loaders.", TITLE, 0)
    return
  end

  sendKit(tr, fx, k, binSlots(data), TITLE, "Kit loaded from:\n" .. folder, take, tkfx)
end

main()
