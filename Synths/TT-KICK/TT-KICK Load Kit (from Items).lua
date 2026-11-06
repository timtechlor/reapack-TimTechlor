-- ============================================================
-- TT-KICK Load Kit (from Items)
-- TimTechlor / TT-KICK Kick Machine
--
-- Drag&drop feeling: drop audio files onto a track as media items,
-- select them, run this action. The selected items become the
-- segment slots of TT-KICK (1 = TRANSIENT, 2 = BODY, 3 = TAIL) in
-- ONE TT-KICK instance: the TT-KICK window that has (or last had)
-- the focus, otherwise the first TT-KICK on the selected track.
-- The folder of the slot-1 file gets tt-kick-kit.bin/.txt (for
-- "TT-KICK Recent Kits") and goes on top of that list.
--
-- Usage: Actions -> Show action list -> "New action..." ->
-- load this script once. Then: select 1-3 media items, click into
-- the TT-KICK window (or select its track as well) and run it.
--   Order = slot order: track number, then position, then lane.
--   1 item -> slot 1; 2 items -> slots 1+2; 3+ items -> slots 1-3
--   (surplus is ignored and counted in the report).
--   MIDI items and items without a file source are skipped (counted).
-- Cancelling the confirmation keeps the current kit. The item
-- selection stays untouched; the kit assignment gets one undo point.
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
local TITLE = "TT-KICK Load Kit (from Items)"
local RECENT_MAX = 8

local names = { "TRANSIENT", "BODY", "TAIL" }

-- ---------- kit folder copy (for Recent Kits) ----------

-- kit.bin: per slot one float32 length + up to 255 float32 chars,
-- each slot padded to 256 words (matches the FX parser exactly)
local function writeBin(path, slots)
  local f = io.open(path, "wb")
  if not f then return false end
  for i = 1, 3 do
    local p = slots[i] or ""
    -- Keine gekuerzten Pfade in die Kopie: laenger als 255 Zeichen passt nicht ins bin-Format
    -- (main hat den Slot schon abgelehnt und gemeldet); ein leerer Eintrag laesst den Slot stehen.
    if #p > 255 then p = "" end
    f:write(string.pack("f", #p))
    for c = 1, #p do f:write(string.pack("f", p:byte(c))) end
    for c = #p + 1, 255 do f:write(string.pack("f", 0)) end
  end
  -- Kopie im Kit-Ordner nur fuer "Recent Kits" (768 Worte; die Seriennummer gehoert zur gmem-Anfrage).
  f:close()
  return true
end

local function writeTxt(path, slots)
  local t = io.open(path, "w")
  if not t then return false end
  t:write("TT-KICK kit (machine-readable: tt-kick-kit.bin)\r\n")
  for i = 1, 3 do
    t:write(i, " ", names[i], "\t", slots[i] or "", "\r\n")
  end
  t:close()
  return true
end

-- Recent list: one kit folder per line, newest on top, max 8
local function addRecent(folder)
  local path = reaper.GetResourcePath() .. "/tt-kick-recent.txt"
  local function norm(p) return (p:gsub("\\", "/"):gsub("/+$", ""):lower()) end
  local out = { folder }
  local f = io.open(path, "r")
  if f then
    for raw in f:lines() do
      local line = raw:gsub("\r$", "")   -- P25: Schleifenvariable nicht neu zuweisen (in Lua 5.5 konstant)
      if line ~= "" and norm(line) ~= norm(folder) and #out < RECENT_MAX then
        out[#out + 1] = line
      end
    end
    f:close()
  end
  local w = io.open(path, "w")
  if not w then return false end
  w:write(table.concat(out, "\n"), "\n")
  w:close()
  return true
end

-- ---------- item helpers ----------

-- File path of the active take's source, or nil (no take, MIDI,
-- in-memory source). Section sources resolve to their parent file.
local function sourcePath(item)
  local take = reaper.GetActiveTake(item)
  if not take then return nil, "empty" end
  if reaper.TakeIsMIDI(take) then return nil, "midi" end
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return nil, "empty" end
  local typ = reaper.GetMediaSourceType(src, "")
  if typ == "SECTION" then
    local parent = reaper.GetMediaSourceParent(src)
    if parent then src = parent end
  end
  -- Lua binding returns the name; older builds return (retval, name)
  local a, b = reaper.GetMediaSourceFileName(src, "")
  local p = (type(b) == "string") and b or a
  if type(p) ~= "string" or p == "" then return nil, "empty" end
  return (p:gsub("\\", "/"))
end

local function itemNum(item, key)
  local v = reaper.GetMediaItemInfo_Value(item, key)
  return type(v) == "number" and v or 0
end

-- ---------- main ----------

local function main()
  -- P26: Ziel zuerst bestimmen
  local tr, fx, k, take, tkfx = findKick()
  if not tr then reaper.MB(fx, TITLE, 0) return end

  local n = reaper.CountSelectedMediaItems(0)
  if n == 0 then
    reaper.MB("No media item selected.\n\nDrop up to 3 audio files on a track, " ..
      "select the items and run the action again.", TITLE, 0)
    return
  end

  local entries, skippedMidi, skippedOther = {}, 0, 0
  for i = 0, n - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if item then
      local p, why = sourcePath(item)
      if p then
        local tr = reaper.GetMediaItem_Track(item)
        entries[#entries + 1] = {
          path = p,
          track = tr and reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER") or 0,
          pos = itemNum(item, "D_POSITION"),
          lane = itemNum(item, "I_FIXEDLANE"),
          idx = i,
        }
      elseif why == "midi" then
        skippedMidi = skippedMidi + 1
      else
        skippedOther = skippedOther + 1
      end
    end
  end

  if #entries == 0 then
    reaper.MB(string.format("No audio file source among the %d selected item(s) " ..
      "(%d MIDI, %d without file).", n, skippedMidi, skippedOther), TITLE, 0)
    return
  end

  table.sort(entries, function(a, b)
    if a.track ~= b.track then return a.track < b.track end
    if a.pos ~= b.pos then return a.pos < b.pos end
    if a.lane ~= b.lane then return a.lane < b.lane end
    return a.idx < b.idx
  end)

  local slots, lines = { "", "", "" }, {}
  for s = 1, 3 do
    local e = entries[s]
    slots[s] = e and e.path or ""
    if #slots[s] > 255 then
      -- Je Slot sind 255 Zeichen uebergebbar (gmem-Protokoll und kit.bin): vor dem Bestaetigungsdialog
      -- ablehnen statt still kuerzen - der Slot bleibt wie nach einem Abbruch und erscheint als (empty).
      reaper.MB("Path longer than 255 characters, slot " .. names[s] .. " skipped:\n" .. slots[s], TITLE, 0)
      slots[s] = ""
      e = nil
    end
    lines[#lines + 1] = string.format("%-9s = %s", names[s],
      e and (e.path:match("[^/]+$") or e.path) or "(empty)")
  end
  if slots[1] == "" and slots[2] == "" and slots[3] == "" then
    reaper.MB("Nothing to load: no slot has a usable path.", TITLE, 0)
    return
  end

  local msg = "Selected items: " .. n .. "\n\n" .. table.concat(lines, "\n")
  local notes = {}
  if #entries > 3 then notes[#notes + 1] = (#entries - 3) .. " surplus audio item(s) ignored" end
  if skippedMidi > 0 then notes[#notes + 1] = skippedMidi .. " MIDI item(s) skipped" end
  if skippedOther > 0 then notes[#notes + 1] = skippedOther .. " item(s) without file skipped" end
  if #notes > 0 then msg = msg .. "\n\n" .. table.concat(notes, "; ") end
  msg = msg .. "\n\nLoad this kit?"
  if reaper.MB(msg, TITLE, 1) ~= 1 then return end   -- 1 = OK, 2 = Cancel

  -- copy into the folder of the slot-1 file (for Recent Kits); best effort
  local folder = slots[1]:match("^(.*)/")
  local copied = false
  if folder and folder ~= "" then
    copied = writeBin(folder .. "/tt-kick-kit.bin", slots)
    if copied then writeTxt(folder .. "/tt-kick-kit.txt", slots) end
    addRecent(folder)
  end

  sendKit(tr, fx, k, slots, TITLE, function(n)
    return string.format("Kit: %d slot(s) assigned (TRANSIENT / BODY / TAIL).%s", n,
      copied and "" or "\n\nNote: no copy in the item folder - it will not work via Recent Kits.")
  end, take, tkfx)
end

main()
