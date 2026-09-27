-- @description TT-PHALYX Load Kit
-- @author TimTechlor
-- @version 1.0
-- @license MIT
-- @about
--   # TT-PHALYX Load Kit
--
--   Picks any WAV from a kit folder and distributes the folder's
--   contents sorted across the 16 sample-A pads of TT-PHALYX. Requires
--   the TT-PHALYX Drum Sampler JSFX to be installed.
-- @changelog
--   Erste Veroeffentlichung ueber ReaPack.
-- ============================================================
-- TT-PHALYX Load Kit
-- TimTechlor / TT-PHALYX Drum Sampler
--
-- Picks any WAV from the kit folder, reads the folder and
-- distributes the WAVs sorted across the 16 sample-A slots of
-- TT-PHALYX. Writes:
--   tt-phalyx-kit.bin  machine format (float32 byte stream,
--                      polled by the FX every ~0.5 s)
--   tt-phalyx-kit.txt  readable reference (32 lines of paths)
--
-- Usage: Actions -> Show action list -> "New action..." ->
-- load this script once -> run it.
-- ============================================================

local DIR = reaper.GetResourcePath() .. "/Effects/TimTechlor/TT-PHALYX"

local rv, file = reaper.GetUserFileNameForRead("", "TT-PHALYX: Pick any WAV from the kit folder", "wav")
if not rv or file == "" then return end

local dir = file:match("^(.*)[/\\]")
if not dir or dir == "" then
  reaper.MB("Could not determine the folder.", "TT-PHALYX Load Kit", 0)
  return
end

local _, listing = reaper.ExecProcess('cmd /c dir /b "' .. dir .. '"', 0)
if not listing then
  reaper.MB("Folder could not be read:\n" .. dir, "TT-PHALYX Load Kit", 0)
  return
end

local wavs = {}
for line in listing:gmatch("[^\r\n]+") do
  if line:lower():match("%.wav$") then wavs[#wavs + 1] = line end
end
table.sort(wavs)

if #wavs == 0 then
  reaper.MB("No WAV files in:\n" .. dir, "TT-PHALYX Load Kit", 0)
  return
end

-- Assemble 32 paths (1-16 = sample A P01-P16, 17-32 = sample B empty)
local slots = {}
for i = 1, 32 do
  slots[i] = (i <= 16 and wavs[i]) and (dir .. "\\" .. wavs[i]) or ""
end

-- kit.bin: per slot one float32 length + one float32 byte per character
local f = io.open(DIR .. "/tt-phalyx-kit.bin", "wb")
if not f then
  reaper.MB("Could not write the kit binary file.", "TT-PHALYX Load Kit", 0)
  return
end
for i = 1, 32 do
  local p = slots[i]
  f:write(string.pack("f", #p))
  for c = 1, #p do f:write(string.pack("f", p:byte(c))) end
  for c = #p + 1, 127 do f:write(string.pack("f", 0)) end  -- pad slot to 128 words
end
f:close()

-- kit.txt: readable reference
local t = io.open(DIR .. "/tt-phalyx-kit.txt", "w")
if t then
  for i = 1, 32 do t:write(slots[i], "\r\n") end
  t:close()
end

local n = math.min(#wavs, 16)
reaper.MB(string.format(
  "Kit written: %d WAV(s) distributed to P01-P%02d.\n\nSource folder:\n%s\n\nTT-PHALYX adopts the kit automatically (~0.5 s).",
  n, n, dir), "TT-PHALYX Load Kit", 0)
