-- @description TT-PHALYX Save Bank
-- @author TimTechlor
-- @version 1.0
-- @license MIT
-- @about
--   # TT-PHALYX Save Bank
--
--   Saves the complete parameter and FX state of TT-PHALYX to one of
--   8 bank slots. Requires the TT-PHALYX Drum Sampler JSFX to be
--   installed.
-- @changelog
--   Erste Veroeffentlichung ueber ReaPack.
-- TT-PHALYX Save Bank (v0.6.0)
-- Saves the complete parameter and FX state of TT-PHALYX as
-- tt-phalyx-bank1..8.bin (slot is asked for). Loading: B1-B8 in the
-- SYSTEM tab.
--
-- Mechanism: JSFX may only READ files, so this takes the detour over
-- the project serialize blob: the project is written as a copy to a
-- temp RPP, the base64 JS_SER is extracted, decoded and stored as a
-- binary file - exactly the format bankLoad in the FX expects
-- (magic, phxVer, 2112 words pad state, 96 words FX).
local FXDIR = reaper.GetResourcePath() .. "/Effects/TimTechlor/TT-PHALYX"

local b64tab = {}
for i = 1, #("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/") do
  b64tab[("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"):sub(i, i)] = i - 1
end

local function b64decode(s)
  local out, buf, bits = {}, 0, 0
  for c in s:gmatch("[A-Za-z0-9+/]") do
    buf = buf * 64 + b64tab[c]
    bits = bits + 6
    if bits >= 8 then
      bits = bits - 8
      out[#out + 1] = string.char(math.floor(buf / 2 ^ bits) % 256)
    end
  end
  return table.concat(out)
end

local function main()
  local ok, slot = reaper.GetUserInputs("TT-PHALYX Save Bank", 1, "Slot (1-8):", "1")
  if not ok then return end
  slot = math.floor(tonumber(slot) or 0)
  if slot < 1 or slot > 8 then
    reaper.ShowConsoleMsg("TT-PHALYX: invalid slot " .. tostring(slot) .. " (1-8)\n")
    return
  end

  -- Save the project as a copy (does not modify the project itself)
  local proj = reaper.EnumProjects(-1)
  local tmpRpp = FXDIR .. "/_banktmp.rpp"
  reaper.Main_SaveProjectEx(proj, tmpRpp, 1)

  local fh = io.open(tmpRpp, "r")
  if not fh then
    reaper.ShowConsoleMsg("TT-PHALYX: temp RPP not writable\n")
    return
  end
  local blob = ""
  for line in fh:lines() do
    local b = line:match("JS_SER%s+([A-Za-z0-9+/=]+)")
    if b then blob = b break end
  end
  fh:close()
  os.remove(tmpRpp)

  if blob == "" then
    reaper.ShowConsoleMsg("TT-PHALYX: no JS_SER in the project - play/save once first, then save the bank\n")
    return
  end

  local raw = b64decode(blob)
  local magic, ver = string.unpack("<I4", raw, 1)
  if magic ~= 1480923721 then
    reaper.ShowConsoleMsg("TT-PHALYX: unexpected blob (magic " .. tostring(magic) .. ")\n")
    return
  end

  local out = assert(io.open(FXDIR .. "/tt-phalyx-bank" .. slot .. ".bin", "wb"))
  out:write(raw)
  out:close()
  reaper.ShowConsoleMsg(string.format("TT-PHALYX: bank %d saved (%d bytes, version %d)\n", slot, #raw, ver))
end

main()
