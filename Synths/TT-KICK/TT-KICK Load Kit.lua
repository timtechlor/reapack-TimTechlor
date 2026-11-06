-- ============================================================
-- TT-KICK Load Kit
-- TimTechlor / TT-KICK Kick Machine
--
-- Assigns one WAV to each of the three segment slots of TT-KICK
-- (1 = TRANSIENT, 2 = BODY, 3 = TAIL) - in ONE TT-KICK instance:
-- the TT-KICK window that has (or last had) the focus, otherwise
-- the first TT-KICK on the selected track.
--
-- Usage: Actions -> Show action list -> "New action..." ->
-- load this script once -> click into the TT-KICK window (or
-- select its track) -> run it. Cancelling a dialog keeps the
-- current slot assignment (empty lines change nothing).
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

-- 25.10.2026 (Review kick-R018): dieselbe Suche ueber die TakeFX-API (Take-FX-Instanz)
local function kitParamTk(take, fx)
  for k = 0, reaper.TakeFX_GetNumParams(take, fx) - 1 do
    local _, pn = reaper.TakeFX_GetParamName(take, fx, k, "")
    if pn:find("^Kit request") then return k end
  end
  return nil
end

-- Ziel-Instanz: Rueckgabe tr, fx, Parameterindex (+ take, takeFxIdx bei Take-FX) - oder nil und ein Hinweistext
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
  -- 25.10.2026 (Review kick-R016): gmem-Zugriff pruefen - schlaegt Attach/Write fehl,
  -- liefen die gmem_write-Aufrufe sonst lautlos ins Leere. gmem_attach gibt den
  -- VORHERIGEN Namespace-Namen zurueck (kein Erfolgsflag) - Nachweis per Schreib-/
  -- Leseprobe auf KQ_SER (wird ohnehin gleich mit der Seriennummer ueberschrieben).
  local attOk = pcall(reaper.gmem_attach, "ttkk")
  if attOk then
    reaper.gmem_write(KQ_SER, -1)
    attOk = (reaper.gmem_read(KQ_SER) == -1)
  end
  if not attOk then
    reaper.MB("Could not attach to the shared memory namespace 'ttkk' - kit was not sent. Please run the action again.",
              "TT-KICK Load Kit", 0)
    return
  end
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

local TITLE = "TT-KICK Load Kit"
local names = { "TRANSIENT", "BODY", "TAIL" }
local slots = { "", "", "" }
local lastDir = ""
local picked = 0

-- P26: Ziel zuerst bestimmen (vor den Dialogen, die den Fokus verschieben)
local tr, fx, k, take, tkfx = findKick()
if not tr then reaper.MB(fx, TITLE, 0) return end

for i = 1, 3 do
  local rv, file = reaper.GetUserFileNameForRead(lastDir,
    "TT-KICK: WAV for slot " .. i .. " (" .. names[i] .. ") - Cancel keeps current", "wav")
  if rv and file ~= "" then
    slots[i] = file
    lastDir = file:match("^(.*)[/\\]") or lastDir
    picked = picked + 1
  end
end

if picked == 0 then return end   -- nothing chosen: leave the current kit alone

sendKit(tr, fx, k, slots, TITLE, function(n)
  return string.format("Kit: %d slot(s) assigned (TRANSIENT / BODY / TAIL).", n)
end, take, tkfx)
