-- @description TT-303PATGEN Print to MIDI Item
-- @author TimTechlor
-- @version 0.1.1
-- @about
--   Prints the pattern of a TT-303PATGEN instance as a real MIDI item, so the live generator becomes a fixed track.
--   Turn on SEQ LINK in TT-303PATGEN first (the script reads the pattern from the gmem namespace tt303pg),
--   select the target track, put the edit cursor where the item should start, run the script and enter the
--   number of bars. Slide is written as overlapping notes, ties as longer notes, accent and normal velocities as
--   set in the plug-in. PROB and HUMANIZE are not printed (the item contains the pattern as written).
--
-- Protocol (SEQ LINK, gmem namespace "tt303pg"):
--   gmem[0]=30301 magic, [1]=1 version, [2]=pattern length, [3]=write counter,
--   [4+4*s+k] step s (0..31), field k: 0 MIDI note (absolute, without input transpose), 1 gate (tie = 1),
--   2 accent, 3 slide (a tie is exported as a slide of the previous step into the same pitch),
--   [132]=step length in beats, [133]=swing (0.5..0.75), [134]=gate length (share of a step), [135]=accent velocity,
--   [136]=normal velocity, [137]=MIDI channel 1..16, [138]=1 when the extension block [132..137] is valid.
--   0.1.1: [139]=1 when the tie flags are valid, [140+s]=1 when step s is a tie (the previous note is held, the stored pitch of
--   the tie is ignored, exactly like the plug-in does when it plays). Without [139] the old encoding is used.
--
-- Written from scratch for TT-303PATGEN (no code shared with other products).

local function msg(s) reaper.ShowMessageBox(s, "TT-303PATGEN Print to MIDI Item", 0) end

-- Kernfunktion: rein rechnerisch, testbar. src = {len, L, sw, gl, accv, normv, ch, steps = { [s] = {note, gate, acc, sld} }}
-- returns: list {startQN, endQN, pitch, vel, ch} for nbeats beats from beat 0
function PG_print_notes(src, nbeats)
  local out = {}
  local len, L, sw, gl = src.len, src.L, src.sw, src.gl
  local function pos(n) return n * L + ((n % 2) == 1 and (2 * sw - 1) * L or 0) end
  local glq = math.max(1e-6, gl * L)
  local ovl = math.max(1e-6, 0.5 * glq)
  local open = nil   -- klingende Note: {i = Index in out, note, slide}
  local n = 0
  while pos(n) < nbeats - 1e-9 do
    local st = src.steps[n % len]
    local nx = src.steps[(n + 1) % len]
    local t = pos(n)
    local tn = pos(n + 1)
    -- 0.1.1: tie as in the plug-in (pg_fire): if a note sounds, it holds across the tie (own pitch irrelevant); otherwise the tie starts as a note
    if st.tie and open then
      -- continuation of the open note: only recompute the end (like cont in the plug-in)
      local e = t + glq
      if nx.tie then
        open.slide = false
        out[open.i][2] = tn
      elseif st.sld == 1 and nx.gate == 1 then
        open.slide = true
        out[open.i][2] = tn
      else
        if nx.gate >= 1 then e = math.min(e, tn - 1e-6) end
        out[open.i][2] = math.max(e, t + 1e-6)
        open = nil
      end
    elseif st.gate == 1 then
      local vel = st.acc == 1 and src.accv or src.normv
      local started = false
      local cont = false
      if open then
        if open.slide and st.note ~= open.note then
          out[#out + 1] = { t, t + glq, st.note, vel, src.ch }
          out[open.i][2] = t + ovl
          open = { i = #out, note = st.note }
          started = true
        elseif open.slide and st.note == open.note then
          cont = true
        else
          out[open.i][2] = t
          out[#out + 1] = { t, t + glq, st.note, vel, src.ch }
          open = { i = #out, note = st.note }
          started = true
        end
      else
        out[#out + 1] = { t, t + glq, st.note, vel, src.ch }
        open = { i = #out, note = st.note }
        started = true
      end
      if started or cont then
        if nx.tie then
          open.slide = false
          out[open.i][2] = tn
        elseif st.sld == 1 and nx.gate == 1 then
          open.slide = true
        else
          local e = t + glq
          if nx.gate >= 1 then e = math.min(e, tn - 1e-6) end
          out[open.i][2] = math.max(e, t + 1e-6)
          open = nil
        end
      end
    else
      if open then out[open.i][2] = t; open = nil end
    end
    n = n + 1
  end
  if open and open.slide then out[open.i][2] = nbeats end   -- slide/tie continues past the end of the printed range
  for _, nt in ipairs(out) do if nt[2] > nbeats then nt[2] = nbeats end end
  return out
end

local function read_source()
  reaper.gmem_attach("tt303pg")
  if reaper.gmem_read(0) ~= 30301 then return nil, "No TT-303PATGEN pattern found. Turn on SEQ LINK in the plug-in (and let the transport or the UI run once)." end
  if reaper.gmem_read(138) ~= 1 then return nil, "The pattern block has no timing extension. Update TT-303PATGEN." end
  local src = { len = math.floor(reaper.gmem_read(2)), L = reaper.gmem_read(132), sw = reaper.gmem_read(133), gl = reaper.gmem_read(134),
                accv = math.floor(reaper.gmem_read(135)), normv = math.floor(reaper.gmem_read(136)), ch = math.floor(reaper.gmem_read(137)) - 1, steps = {} }
  if src.len < 1 or src.len > 32 or src.L <= 0 then return nil, "Invalid pattern header in gmem." end
  for s = 0, src.len - 1 do
    local b = 4 + 4 * s
    src.steps[s] = { note = math.floor(reaper.gmem_read(b)), gate = math.floor(reaper.gmem_read(b + 1)), acc = math.floor(reaper.gmem_read(b + 2)), sld = math.floor(reaper.gmem_read(b + 3)) }
    if reaper.gmem_read(139) == 1 then src.steps[s].tie = reaper.gmem_read(140 + s) == 1 end   -- 0.1.1: Tie-Flag (alte Plug-ins: nil)
  end
  return src
end

function PG_print_to_item(tr, startTime, bars, srcOverride)
  local src, err = srcOverride, nil
  if not src then src, err = read_source() end
  if not src then return nil, err end
  local startQN = reaper.TimeMap2_timeToQN(0, startTime)
  local bt = 4
  local num, den = reaper.TimeMap_GetTimeSigAtTime(0, startTime)
  if num and den and den > 0 then bt = num * 4 / den end
  local nbeats = bars * bt
  local notes = PG_print_notes(src, nbeats)
  local endTime = reaper.TimeMap2_QNToTime(0, startQN + nbeats)
  local item = reaper.CreateNewMIDIItemInProj(tr, startTime, endTime, false)
  local take = reaper.GetActiveTake(item)
  for _, n in ipairs(notes) do
    local p1 = reaper.MIDI_GetPPQPosFromProjQN(take, startQN + n[1])
    local p2 = reaper.MIDI_GetPPQPosFromProjQN(take, startQN + n[2])
    reaper.MIDI_InsertNote(take, false, false, p1, p2, n[5], n[3], n[4], true)
  end
  reaper.MIDI_Sort(take)
  return item, #notes
end

-- script start (not in a test run via PG_PRINT_NOUI)
if not PG_PRINT_NOUI then
  local tr = reaper.GetSelectedTrack(0, 0)
  if not tr then msg("Select the target track first.") return end
  local ok, ret = reaper.GetUserInputs("TT-303PATGEN - Print to MIDI Item", 1, "Bars to print:", "4")
  if not ok then return end
  local bars = tonumber(ret)
  if not bars or bars < 1 or bars > 256 then msg("Enter a number of bars between 1 and 256.") return end
  reaper.Undo_BeginBlock()
  local item, n = PG_print_to_item(tr, reaper.GetCursorPosition(), math.floor(bars), nil)
  reaper.Undo_EndBlock("TT-303PATGEN: print pattern to MIDI item", -1)
  if not item then msg(n) return end
  reaper.UpdateArrange()
end
