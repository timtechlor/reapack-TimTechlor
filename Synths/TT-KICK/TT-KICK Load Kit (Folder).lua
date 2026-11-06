-- ============================================================
-- TT-KICK Load Kit (Folder)
-- TimTechlor / TT-KICK Kick Machine
--
-- One dialog instead of three: pick ANY audio file inside the kit
-- folder, the script scans that folder (*.wav / *.aif / *.aiff,
-- case-insensitive), assigns the files to the three segment slots
-- (1 = TRANSIENT, 2 = BODY, 3 = TAIL) by file name and asks for
-- confirmation before loading. The kit goes into ONE TT-KICK
-- instance: the TT-KICK window that has (or last had) the focus,
-- otherwise the first TT-KICK on the selected track.
-- The kit folder gets tt-kick-kit.bin/.txt (for "TT-KICK Recent
-- Kits") and goes on top of that list.
--
-- Usage: Actions -> Show action list -> "New action..." ->
-- load this script once -> click into the TT-KICK window (or
-- select its track) -> run it -> pick one file of the kit.
-- Cancelling the dialog or the confirmation keeps the current kit.
-- For exact control over each slot use "TT-KICK Load Kit".
--
-- NAMING CONVENTION (case-insensitive substring on the file name
-- without extension):
--   slot 1 TRANSIENT: trans  click  att
--   slot 2 BODY:      body   mid    punch
--   slot 3 TAIL:      tail   sub    room   end
-- Rules, applied in this order:
--   1. Per slot 1..3 the still unused files matching a stem of that
--      slot are candidates. A file matching only ONE slot beats a
--      file matching several; ties are broken alphabetically.
--   2. Slots without a match are filled with the remaining files in
--      alphabetical order (slot 1 first).
--   3. More than 3 files: the surplus is ignored (named in the
--      confirmation). Fewer than 3: the free slots stay empty.
-- Beware of substrings: "att" also hits "battery", "end" hits
-- "blend" - the confirmation box shows the result before writing.
--
-- Matcher examples (file names in alphabetical order -> slots):
--   1. Kick_Body.wav Kick_Click.wav Kick_Tail.wav
--        -> 1 Kick_Click, 2 Kick_Body, 3 Kick_Tail
--   2. a_sub.wav b_punch.wav c_attack.wav
--        -> 1 c_attack, 2 b_punch, 3 a_sub
--   3. kick1.wav kick2.wav kick3.wav
--        -> 1 kick1, 2 kick2, 3 kick3 (alphabetical fill)
--   4. Body_A.wav Body_B.wav Snap.wav
--        -> 1 Body_B, 2 Body_A, 3 Snap (Body_B/Snap fill the gaps)
--   5. mid.wav Room_Click.wav
--        -> 1 Room_Click (matches 1+3, slot 1 comes first),
--           2 mid, 3 empty
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
local TITLE = "TT-KICK Load Kit (Folder)"
local RECENT_MAX = 8

local names = { "TRANSIENT", "BODY", "TAIL" }
local STEMS = {
  { "trans", "click", "att" },
  { "body", "mid", "punch" },
  { "tail", "sub", "room", "end" },
}

-- ---------- pure logic (no REAPER API) ----------

local function matchesSlot(lname, slot)
  for _, stem in ipairs(STEMS[slot]) do
    if lname:find(stem, 1, true) then return true end
  end
  return false
end

local function slotCount(lname)
  local n = 0
  for s = 1, 3 do if matchesSlot(lname, s) then n = n + 1 end end
  return n
end

-- files: array of file names (with extension). Returns
-- assigned[1..3] (file name or nil) and the array of unused files.
local function assign(files)
  local list = {}
  for _, fn in ipairs(files) do
    local base = fn:gsub("%.[^%.]*$", ""):lower()
    list[#list + 1] = { fn = fn, l = base, key = fn:lower(), used = false }
  end
  table.sort(list, function(a, b) return a.key < b.key end)

  local assigned = {}
  for s = 1, 3 do
    local best
    for _, e in ipairs(list) do
      if not e.used and matchesSlot(e.l, s) then
        -- list is alphabetical: the first hit with the fewest slots wins
        if not best or slotCount(e.l) < slotCount(best.l) then best = e end
      end
    end
    if best then best.used = true; assigned[s] = best.fn end
  end
  for s = 1, 3 do
    if not assigned[s] then
      for _, e in ipairs(list) do
        if not e.used then e.used = true; assigned[s] = e.fn; break end
      end
    end
  end
  local rest = {}
  for _, e in ipairs(list) do if not e.used then rest[#rest + 1] = e.fn end end
  return assigned, rest
end

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

-- ---------- main ----------

local function main()
  -- P26: Ziel zuerst bestimmen (vor dem Dialog, der den Fokus verschiebt)
  local tr, fx, k, take, tkfx = findKick()
  if not tr then reaper.MB(fx, TITLE, 0) return end

  local rv, picked = reaper.GetUserFileNameForRead("",
    "TT-KICK: pick any file of the kit folder - Cancel keeps current", "wav")
  if not rv or not picked or picked == "" then return end

  local folder = picked:match("^(.*)[/\\]")
  if not folder or folder == "" then
    reaper.MB("Could not derive the folder from:\n" .. picked, TITLE, 0)
    return
  end

  local files = {}
  local i = 0
  while true do
    local fn = reaper.EnumerateFiles(folder, i)
    if not fn then break end
    local l = fn:lower()
    if l:match("%.wav$") or l:match("%.aif$") or l:match("%.aiff$") then
      files[#files + 1] = fn
    end
    i = i + 1
  end

  if #files == 0 then
    reaper.MB("No WAV/AIF file found in:\n" .. folder, TITLE, 0)
    return
  end

  local assigned, rest = assign(files)
  local slots = {}
  local lines = {}
  for s = 1, 3 do
    slots[s] = assigned[s] and (folder .. "/" .. assigned[s]) or ""
    if #slots[s] > 255 then
      -- Je Slot sind 255 Zeichen uebergebbar (gmem-Protokoll und kit.bin): vor dem Bestaetigungsdialog
      -- ablehnen statt still kuerzen - der Slot bleibt wie nach einem Abbruch und erscheint als (empty).
      reaper.MB("Path longer than 255 characters, slot " .. names[s] .. " skipped:\n" .. slots[s], TITLE, 0)
      slots[s] = ""
      assigned[s] = nil
    end
    lines[#lines + 1] = string.format("%-9s = %s", names[s], assigned[s] or "(empty)")
  end
  if slots[1] == "" and slots[2] == "" and slots[3] == "" then
    reaper.MB("Nothing to load: no slot has a usable path.", TITLE, 0)
    return
  end
  local msg = "Folder: " .. folder .. "\n\n" .. table.concat(lines, "\n")
  if #rest > 0 then
    msg = msg .. "\n\nIgnored (" .. #rest .. "): " .. table.concat(rest, ", ")
  end
  msg = msg .. "\n\nMatching: trans/click/att -> TRANSIENT, body/mid/punch -> BODY, " ..
    "tail/sub/room/end -> TAIL, rest alphabetical.\n\nLoad this kit?"
  if reaper.MB(msg, TITLE, 1) ~= 1 then return end   -- 1 = OK, 2 = Cancel

  -- copy into the kit folder (for Recent Kits); best effort
  local copied = writeBin(folder .. "/tt-kick-kit.bin", slots)
  if copied then writeTxt(folder .. "/tt-kick-kit.txt", slots) end
  addRecent(folder)

  sendKit(tr, fx, k, slots, TITLE, function(n)
    return string.format("Kit: %d slot(s) assigned (TRANSIENT / BODY / TAIL).%s", n,
      copied and "" or "\n\nNote: the kit folder is write-protected - it will not work via Recent Kits.")
  end, take, tkfx)
end

main()
