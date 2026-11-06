-- ============================================================
-- TT-KICK Export Kick (v0.7.1)
-- TimTechlor / TT-KICK Kick Machine
--
-- Rendert einen Kick der ausgewaehlten Spur in ein Audio-Item -
-- das REAPER-native "Export by drag&drop" (PLAN.md § 4.3): das
-- WAV-Item kann direkt weiterverwendet oder aus dem Projekt
-- gezogen werden. Geschwister-Skript zu "TT-PHALYX Save Bank.lua":
-- JSFX kann Dateien lesen, aber nicht rendern - diese Aktion
-- steuert deshalb REAPER selbst.
--
-- Mechanik: ein temporaeres MIDI-Item feuert ueber die Export-
-- Range eine Note (Pitch = PG_ROOT-Mirror slider63), dann rendert
-- die native Aktion "Item: apply track/take FX to items"
-- (Command 40209) das Item in-place durch die Spur-Kette. Der
-- neue Take heisst TTKICK_<preset>.wav; der Preset-Index kommt
-- aus dem Mirror slider64. Range = bestehende Time Selection,
-- sonst 4 Takte (16 Viertelnoten) ab Edit-Cursor.
--
-- v0.7.1 (Findings 8/9): der Render-Rumpf laeuft in xpcall -
-- PreventUIRefresh und der Undo-Block werden auch im Fehlerfall
-- geschlossen, die Item-Auswahl des Nutzers wird vorher gemerkt
-- und restauriert. Mirror-Reads (Param 62/63) laufen nur, wenn
-- die FX-Kette wirklich > 63 Parameter meldet - sonst Fallback
-- ROOT 36 / Preset "kick".
-- Die Mirror-Parameter werden per NAME gesucht ("Root note (Lua mirror)",
-- "Preset index (Lua mirror)"); REAPER zaehlt die Parameter fortlaufend.
--
-- Ausfuehren: TT-KICK-Spur selektieren, Cursor an den Start,
-- Actions -> "TT-KICK Export Kick".
-- ============================================================

-- v0.9.4: INIT + 44 Werks-Presets (Index = slider64, gleiche Reihenfolge wie psetName)
local PRESETS = {
  "INIT", "909 TIGHT", "909 PUNCH", "909 DEEP", "909 SOFT", "808 SUB",
  "808 LONG", "808 PUNCHY", "HARD TECHNO", "HARDER", "HARDCORE",
  "INDUSTRIAL", "MACHINE FUNK", "RUMBLE DEEP", "RUMBLE FAST", "RUMBLE DRY",
  "RUMBLE DARK", "MINIMAL CLUB", "DUB DRY", "CLUB PUNCH", "BERGHAIN",
  "ROLL TIGHT", "ROLL SHARP", "ROLL DEEP", "SUB FOCUS", "DEEP MELODIC",
  "SOFT DEEP", "ACID GLIDE", "REVERSE BLOOM", "WAREHOUSE", "CLICK MINIMAL",
  "909 SLAM", "909 CLICKY", "808 TIGHT", "HARD SCOOP", "NOISE INDUSTRIAL",
  "RUMBLE SUB", "MINIMAL DRY", "CLUB WARM", "ROLL SOFT", "SUB RUMBLE",
  "DEEP PUNCH", "TECHNO CLASSIC", "WAREHOUSE TIGHT", "REVERSE RISE"
}
local NOTE_VEL = 100

-- Kern des Exports: baut das MIDI-Item, rendert via 40209 und
-- benennt den Take. Rueckgabe: ok, rendered - laeuft im xpcall,
-- Fehler hier verlassen niemals den Aufraeum-Pfad (unten).
local function renderCore(tr, root, rs, re_, preset)
  -- temporaeres MIDI-Item ueber die Range, ein Trigger am Start;
  -- One-Shot-Engine: die Notenlaenge ist unkritisch (~1 s genuegt)
  local item = reaper.CreateNewMIDIItemInProj(tr, rs, re_, false)
  -- 25.10.2026 (Review kick-R015): Fehler nach dem Anlegen liess das
  -- temporaere MIDI-Item im Projekt stehen -> Rumpf in xpcall, bei
  -- Fehler das Item loeschen (nur solange der Take noch MIDI ist -
  -- ein fertig gerendertes Audio-Item bleibt unangetastet).
  local okC, ok, rendered = xpcall(function()
    local take = reaper.GetActiveTake(item)
    local ppq0 = reaper.MIDI_GetPPQPosFromProjTime(take, rs)
    local ppq1 = reaper.MIDI_GetPPQPosFromProjTime(take, math.min(re_, rs + 1.0))
    if ppq1 <= ppq0 then ppq1 = ppq0 + 240 end
    reaper.MIDI_InsertNote(take, false, false, ppq0, ppq1, 0, root,
                           NOTE_VEL, true)
    reaper.MIDI_Sort(take)

    -- in-place rendern: "Item: apply track/take FX to items"
    -- (Multichannel-Variante waere 42432; TT-KICK ist stereo-out)
    reaper.SelectAllMediaItems(0, false)
    reaper.SetMediaItemSelected(item, true)
    reaper.UpdateArrange()
    reaper.Main_OnCommand(40209, 0)

    -- das Item traegt jetzt den gerenderten Take; falls die Aktion ein
    -- Ersatz-Item erzeugt hat, das Audio-Item an der Range suchen
    local rendered
    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
      local it = reaper.GetSelectedMediaItem(0, i)
      local at = reaper.GetActiveTake(it)
      if at and not reaper.TakeIsMIDI(at) then rendered = it break end
    end
    if not rendered then rendered = item end

    local ok = false
    local atake = reaper.GetActiveTake(rendered)
    if atake and not reaper.TakeIsMIDI(atake) then
      reaper.GetSetMediaItemTakeInfo_String(atake, "P_NAME",
        "TTKICK_" .. preset .. ".wav", true)
      ok = true
    end
    return ok, rendered
  end, function(e) return e end)
  if not okC then
    if reaper.ValidatePtr(item, "MediaItem*") then
      local t = reaper.GetActiveTake(item)
      if t and reaper.TakeIsMIDI(t) then
        reaper.DeleteTrackMediaItem(tr, item)
      end
    end
    error(ok, 0)
  end
  return ok, rendered
end

local function main()
  -- defensiv: ohne selektierte Spur gibt es nichts zu rendern
  local tr = reaper.GetSelectedTrack(0, 0)
  if not tr then
    reaper.MB("No track selected - select the track that holds " ..
              "TT-KICK, then run the action again.",
              "TT-KICK Export Kick", 0)
    return
  end

  -- TT-KICK auf der Spur suchen (Preset-Name + Root-Note);
  -- ohne Treffer wird trotzdem gerendert - generischer Name.
  -- Finding 9: Param 62/63 nur lesen, wenn die FX sie auch hat -
  -- TrackFX_GetNumParams liefert die reale Anzahl, sonst bleibt
  -- der Fallback (root 36 / "kick").
  -- P25 (Review A5): REAPER nummeriert die Host-Parameter eines JSFX fortlaufend (Root-Mirror = 0, Preset-Mirror
  -- = 1, UI Color = 2, Q CMD.. = 3..6, danach Bypass/Wet/Delta) - Slidernummer 63/64 ist NICHT der Index. Die
  -- alte Abfrage (> 63 Parameter, Index 62/63) war nie wahr: der Export nahm immer Note 36 und "kick". Jetzt per
  -- Name, wie die Testskripte (kk_pbtest.lua). Ohne Treffer bleibt der Fallback root 36 / "kick".
  -- Auch andere Plugins enthalten "tt-kick": gesucht wird deshalb das FX, das den Parameter "Root note" hat.
  local preset, root = "kick", 36
  for i = 0, reaper.TrackFX_GetCount(tr) - 1 do
    local _, nm = reaper.TrackFX_GetFXName(tr, i, "")
    if nm:lower():find("tt%-kick") then
      local found = false
      for k = 0, reaper.TrackFX_GetNumParams(tr, i) - 1 do
        local _, pn = reaper.TrackFX_GetParamName(tr, i, k, "")
        if pn:find("^Root note") then
          found = true
          root = math.floor(reaper.TrackFX_GetParam(tr, i, k) + 0.5)
          if root < 0 then root = 0 elseif root > 127 then root = 127 end
        elseif pn:find("^Preset index") then
          local p = math.floor(reaper.TrackFX_GetParam(tr, i, k) + 0.5)
          if PRESETS[p + 1] then preset = PRESETS[p + 1] end
        end
      end
      if found then break end
    end
  end

  -- Zustand merken, den die Aktion anfasst: Cursor, Time Selection
  -- und die Item-Auswahl des Nutzers (Finding 8 - der Render legt
  -- eine eigene Auswahl an; die alte wird unten restauriert).
  local curPos = reaper.GetCursorPosition()
  local s0, s1 = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  local hadSel = s1 > s0
  local selItems = {}
  for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    selItems[#selItems + 1] = reaper.GetSelectedMediaItem(0, i)
  end

  -- Export-Range: bestehende Time Selection oder 4 Takte ab Cursor
  local rs, re_
  if hadSel then
    rs, re_ = s0, s1
  else
    rs = curPos
    local qn = reaper.TimeMap_timeToQN(0, rs)
    re_ = reaper.TimeMap_QNToTime(0, qn + 16)   -- 4 Takte in 4/4
    reaper.GetSet_LoopTimeRange(true, false, rs, re_, false)
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  -- Render-Rumpf geschuetzt: auch ein API-Fehler endet kontrolliert
  local okRender, rendered
  local presetOk
  presetOk, okRender, rendered = xpcall(
    function() return renderCore(tr, root, rs, re_, preset) end,
    function(e) return e end)

  -- aufraeumen IMMER (Finding 8): selbst gesetzte Time Selection
  -- und Cursor zurueck, Nutzer-Selektion restaurieren (das frisch
  -- gerenderte Item bleibt zusaetzlich selektiert - es ist das
  -- Ergebnis), UI-Refresh freigeben, Undo-Block schliessen.
  if not hadSel then
    reaper.GetSet_LoopTimeRange(true, false, 0, 0, false)
  end
  reaper.SetEditCurPos(curPos, false, false)
  for _, it in ipairs(selItems) do
    if reaper.ValidatePtr(it, "MediaItem*") then
      reaper.SetMediaItemSelected(it, true)
    end
  end
  if presetOk and rendered and reaper.ValidatePtr(rendered, "MediaItem*") then
    reaper.SetMediaItemSelected(rendered, true)
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("TT-KICK Export Kick", -1)

  if not presetOk then
    reaper.MB("Export failed: " .. tostring(okRender),
              "TT-KICK Export Kick", 0)
    return
  end

  reaper.ShowConsoleMsg(string.format(
    "TT-KICK Export: TTKICK_%s.wav  (%.2f s, note %d)%s\n",
    preset, re_ - rs, root,
    okRender and "" or " - WARNUNG: kein Audio-Take im Item gefunden"))
end

main()
