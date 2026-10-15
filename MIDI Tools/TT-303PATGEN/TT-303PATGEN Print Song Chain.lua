-- @description TT-303PATGEN Print Song Chain
-- @author TimTechlor
-- @version 0.1.0
-- @about
--   Prints the whole SONG chain of a TT-303PATGEN instance (all cells, with their repeats) as one real MIDI item, so a
--   finished arrangement of the eight slots becomes a fixed track. Turn on SEQ LINK in TT-303PATGEN first, select the
--   target track, put the edit cursor where the item should start and run the script. It asks how many times the chain
--   is printed in a row (1 = one pass). Slides are written as overlapping notes, ties as longer notes, accent and normal
--   velocities as set in the plug-in (same rules as "TT-303PATGEN Print to MIDI Item", which must be installed next to
--   this script). PROB and HUMANIZE are not printed.
--
-- Reads the chain block of the SEQ LINK protocol (gmem namespace "tt303pg"), plug-in 0.7.0 and newer:
--   gmem[0] = 30301 magic, [200] = 1 chain block valid, [201] write counter, [202] number of cells (up to the first empty one),
--   [203 + 2 * j] slot (0..7), [204 + 2 * j] repeats (1..8) for cell j (0..15); timing / velocity fields as in the pattern block
--   ([132] step length in beats, [133] swing, [134] gate length, [135] accent velocity, [136] normal velocity, [137] channel).
--   Slot k starts at 240 + 164 * k: [0] length, [1 + 4 * s] note, [2 + 4 * s] gate, [3 + 4 * s] accent, [4 + 4 * s] slide,
--   [129 + s] = 1 when step s is a tie. A tie sets the slide bit of the previous step inside its slot; for step 0 the reader does it
--   (the previous step is the last step of the previous cell, and of the whole chain for the very first step).
--
-- The chain is concatenated into one long step list and played through the same note state machine as a single pattern,
-- so slides and ties across cell borders behave exactly like the plug-in does in SONG mode.

local function msg(s) reaper.ShowMessageBox(s, "TT-303PATGEN Print Song Chain", 0) end

-- helper PG_print_notes from the sister script (same state machine as in the plug-in)
local function load_single()
  if PG_print_notes then return true end
  local src = debug.getinfo(1, "S").source or ""
  local dir = src:match("^@?(.*[\\/])") or ""
  local f = io.open(dir .. "TT-303PATGEN Print to MIDI Item.lua", "r")
  if not f then return false end
  f:close()
  local keep = PG_PRINT_NOUI
  PG_PRINT_NOUI = true            -- the sister script should only define its functions
  dofile(dir .. "TT-303PATGEN Print to MIDI Item.lua")
  PG_PRINT_NOUI = keep
  return PG_print_notes ~= nil
end

-- read the source from gmem: returns src for PG_print_notes (len = total steps of the chain) or nil, error text.
-- Review Codex 0.7.0 (R5): the plug-in sets gmem[200] to 0 while writing and raises [201] only after the data, so the read is repeated
-- up to 6 times until the valid flag and the counter agree before and after reading. (reads = test table, then there is no race.)
local function PGC_read_once(reads)
  local function rd(a) return math.floor((reads and reads[a]) or reaper.gmem_read(a)) end
  local function rf(a) return (reads and reads[a]) or reaper.gmem_read(a) end
  if rd(0) ~= 30301 then return nil, "No TT-303PATGEN pattern found. Turn on SEQ LINK in the plug-in (and let the transport or the UI run once)." end
  if rd(200) ~= 1 then return nil, "The plug-in does not provide the song chain block (or it is being rewritten). Update TT-303PATGEN to 0.7.0 or newer.", true end
  local nc = rd(202)
  if nc < 1 then return nil, "The song chain is empty. Click a chain cell in the SONG tab first." end
  local src = { L = rf(132), sw = rf(133), gl = rf(134), accv = rd(135), normv = rd(136), ch = rd(137) - 1, steps = {}, len = 0 }
  if src.L <= 0 then return nil, "Invalid timing block in gmem." end
  local n = 0
  for j = 0, nc - 1 do
    local slot = rd(203 + 2 * j)
    local reps = math.max(1, math.min(8, rd(204 + 2 * j)))
    if slot < 0 or slot > 7 then return nil, "Invalid chain cell " .. (j + 1), true end
    local base = 240 + 164 * slot
    local len = rd(base)
    if len < 1 or len > 32 then return nil, "Invalid pattern length in slot " .. string.char(65 + slot), true end
    for _ = 1, reps do
      for s = 0, len - 1 do
        src.steps[n] = { note = rd(base + 1 + 4 * s), gate = rd(base + 2 + 4 * s), acc = rd(base + 3 + 4 * s),
                         sld = rd(base + 4 + 4 * s), tie = rd(base + 129 + s) == 1 }
        n = n + 1
      end
    end
  end
  src.len = n
  -- Review Codex 0.7.0 (R4): a tie turns the predecessor into a slide. Inside a slot the plug-in already does this; the predecessor of step 0 is the last
  -- step of the previous cell (for the very first step the last of the whole chain, because the chain loops), which only the reader knows.
  for i = 0, n - 1 do
    if src.steps[i].tie then src.steps[(i - 1) % n].sld = 1 end
  end
  return src
end

function PGC_read_source(reads)
  if not reads then reaper.gmem_attach("tt303pg") end
  local last_err
  for _ = 1, 6 do
    local c0 = (reads and reads[201]) or reaper.gmem_read(201)
    local src, err, retry = PGC_read_once(reads)
    local c1 = (reads and reads[201]) or reaper.gmem_read(201)
    if src and c0 == c1 then return src end
    if src == nil and not retry then return nil, err end
    last_err = err or "The chain changed while it was being read."
    if reads then break end
  end
  return nil, last_err
end

-- chain from startTime as a MIDI item (passes = repeats of the whole chain)
function PGC_print_to_item(tr, startTime, passes, srcOverride)
  local src, err = srcOverride, nil
  if not src then src, err = PGC_read_source() end
  if not src then return nil, err end
  local startQN = reaper.TimeMap2_timeToQN(0, startTime)
  local nbeats = passes * src.len * src.L
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

if not PGC_NOUI then
  if not load_single() then
    msg("Install 'TT-303PATGEN Print to MIDI Item' next to this script (same ReaPack package).")
    return
  end
  local tr = reaper.GetSelectedTrack(0, 0)
  if not tr then msg("Select the target track first.") return end
  local ok, ret = reaper.GetUserInputs("TT-303PATGEN - Print Song Chain", 1, "Chain passes to print:", "1")
  if not ok then return end
  local passes = tonumber(ret)
  if not passes or passes < 1 or passes > 64 then msg("Enter a number of passes between 1 and 64.") return end
  reaper.Undo_BeginBlock()
  local item, n = PGC_print_to_item(tr, reaper.GetCursorPosition(), math.floor(passes), nil)
  reaper.Undo_EndBlock("TT-303PATGEN: print song chain to MIDI item", -1)
  if not item then msg(n) return end
  reaper.UpdateArrange()
end
