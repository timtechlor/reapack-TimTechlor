-- @description TT-THEMEFONTEDITOR
-- @author TimTechlor
-- @version 1.5.1
-- @license MIT
-- @tags theme fonts walter rtconfig imgui
-- @provides
--   TT_ThemeFontEditor_Manual.html
--   img/tt-theme-font-editor/tt-theme-font-editor-all-fonts-every-font-of-the-theme-changed-rows-ma.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-bake-step-1-start.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-bake-step-2-changed-rows.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-bake-step-2-changes.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-bake-step-3-tooltip.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-bake-step-4-progress.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-bake-step-5-done.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-bake-target-choice.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-baked-theme-in-reaper.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-before-after-mixer-track-name.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-before-after-third-element.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-before-after-track-name.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-discard-original-again.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-discard-preview-active.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-edit-with-a-selected-font-size-controls-bold-ital.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-element-overrides-expanded-and-filtered-to-mcp-fx.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-footer-bake-discard-reload-and-status-line.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-hover-on-a-font-row-with-tooltip.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-hover-tooltip-on-the-picker-button.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-hover-tooltip-on-the-size-slider.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-picker-label-over-the-mixer.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-target-after-locking-a-mixer-fx-list-hit-test-nam.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-the-main-window-with-a-locked-target-in-target-a.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-the-options-popup-with-font-size-table-font-and-d.webp
--   img/tt-theme-font-editor/tt-theme-font-editor-while-the-picker-is-armed-the-row-shows-cancel-pi.webp
-- @changelog
--   v1.5.1
--   - FIX: a '%' in the theme name no longer breaks the preview or the bake; CREATE COPY of an unzipped theme without a ui_img line now points the copy to the existing image folder.
--   - FIX: copying the settings of a theme whose section stands at the very top of reaper-themeconfig.ini no longer writes a broken section header ("[[Name]").
--   - FIX: if the old working folder cannot be renamed, it is no longer deleted in the background while the next edit may already be refilling it.
--   - FIX: baking a zipped theme never deletes an existing temporary file; if all temporary names are taken, the bake stops with a clear message.
--   - FIX: the script starts even if its log file cannot be opened for writing.
--   v1.5.0
--   - NEW LOOK: panels, buttons, switches and the size slider now follow the TimTechlor UI kit 7.
--   - NEW: every control has a tooltip; OPTIONS > TOOLTIPS ON / OFF switches them off (saved).
--   - NEW: OPTIONS > AUTO FIT ON / OFF (default on): resizing the window rescales the content to the largest size that fits; the UI SIZE buttons 100 / 125 / 150 / 200 / 300 % set a fixed size until the window changes again. Range 25 to 400 %, saved.
--   - NEW NAME: TT Theme Font Editor is now TT-THEMEFONTEDITOR. File name, action and saved settings stay the same.
--   - The version is shown next to the name at the top of the window.
--   - FIX: BAKE THEME right after the first change now finishes the bake after preparing the working copy (before, only the preview was made).
--   - FIX: an incomplete working copy (a file that could not be copied or extracted) is reported and no longer marked as ready.
--   - FIX: baking never deletes the previous export first: the old file is moved aside and only replaced once the new one is in place; if that fails, the old export stays.
--   - FIX: write errors (e.g. a full disk) are detected; a plain theme is written to a temporary file, checked, and only then replaces the target, so no cut-off theme is left behind.
--   - FIX: a missing or unreadable file inside a zipped theme, or a zip write error, stops the bake with "Baking failed: ..." instead of writing an incomplete theme.
--   - FIX: selecting a font larger than 48 px (or smaller than 6 px) no longer changes it; at a fixed large UI size the window scrolls instead of cutting off controls.
--   - NEW: BAKE TO chooses where BAKE THEME writes: CREATE COPY (default) makes a new theme file "<name> (TimTechlor)" next to the original, numbered "(TimTechlor 2)", "(TimTechlor 3)" ... if that name is taken, and never replaces an existing file; OVERWRITE ORIGINAL writes back into the theme you are editing and keeps its previous version as "<name>.bak". The choice is saved; the status line names the file that was written.
--   - FIX: closing the window while the working copy is being prepared or a theme is being baked now stops the job cleanly: files are closed and no half-written theme or temporary file is left behind.
--   - FIX: a change right after baking no longer races with the removal of the old working folder (the folder is renamed before it is deleted in the background).
-- @about
--   # TT-THEMEFONTEDITOR
--
--   Find and change the font sizes of the active REAPER theme.
--
--   - Picker: hover over any text in the REAPER window, click or press Shift
--     to lock it. The editor shows which WALTER font (or ini font) is used there.
--   - Change size, bold and italic; element overrides give single WALTER
--     elements a font of their own.
--   - Changes are previewed live through a working copy; "Bake theme" writes a
--     new theme `<Name> (TimTechlor)` (original untouched) or, if chosen under
--     BAKE TO, back into the original (previous version kept as .bak).
--
--   Requires ReaImGui (0.10+) and js_ReaScriptAPI (both in ReaTeam Extensions).
--   Manual: TT_ThemeFontEditor_Manual.html next to the script.
--
-- How it works:
--   1. On start the active theme is read (zip or plain .ReaperTheme). If
--      REAPER reports a path that does not exist, the original theme of the
--      same name is used.
--   2. Picker: GetThingFromPoint returns the WALTER element under the mouse
--      ("mcp.fxlist 4 fx:4"); the rtconfig is evaluated the way WALTER does
--      it (macros, layouts, scaling, variables, theme parameters) ->
--      WALTER font index -> user_fontN in the theme ini.
--   3. Preview: changes are collected and written to the working copy after
--      a short pause (debounce), then loaded. The working copy has its own
--      image folder (zip: extracted once, plain theme: copied once - in small
--      slices, without freezing REAPER) so that its rtconfig can be changed
--      as well (element overrides).
--   4. Bake theme: builds a new zip (or plain ini) with the new values, also
--      in slices; the working copy is removed afterwards.
--
-- Element overrides: after every "set <elem>.font ..." line of the rtconfig
-- a line "set <elem>.font [N . . . . . . .]" is added. "." keeps row height,
-- column widths etc.; only the font index is replaced. Applies to all layouts
-- and scales.
--
-- Requires: ReaImGui (0.10+), js_ReaScriptAPI (zip, mouse). REAPER 6.x+.
-- TimTechlor brand design; since 1.5.0 in the look of the TT UI kit 7
-- (graphite panels, acid green, Inter + Liberation Sans/Mono, circuit
-- traces), UI SIZE / AUTO FIT / TOOLTIPS in OPTIONS.
-- Name since 1.5.0: TT-THEMEFONTEDITOR (file name, action and ExtState
-- namespace unchanged, so saved settings are kept).

local R = reaper
local VERSION = "1.5.1"
local NS = "TT_ThemeFontEditor"
local EDIT_MARK = " (TT-Edit)"
local BAKE_MARK = " (TimTechlor)"
local OVR_MARK = "; TTFE"
local RES = R.GetResourcePath()
local LOGF = RES .. "/tt_themefonteditor_log.txt"
local DEBOUNCE = 0.35      -- s of quiet before the preview is reloaded
local BUDGET = 0.025       -- s of work per defer tick for extracting/building

local function tlog(s)
  local f = io.open(LOGF, "a")
  if f then f:write(os.date("%H:%M:%S "), tostring(s), "\n") f:close() end
end

--------------------------------------------------------------------
-- LOGFONT blob: 60 bytes + 1 checksum byte (sum of bytes 0-59 % 256)
-- bytes 1-4 height (px, negative = character height), 17-20 weight,
-- 21 italic, 29-60 face name
--------------------------------------------------------------------
local function hex_to_bytes(hex)
  local b = {}
  for i = 1, #hex, 2 do b[#b + 1] = tonumber(hex:sub(i, i + 1), 16) or 0 end
  return b
end

local function bytes_to_hex(b)
  local t = {}
  for i = 1, #b do t[i] = string.format("%02X", b[i] & 0xFF) end
  return table.concat(t)
end

local function le32(b, o)
  local v = b[o] + b[o + 1] * 256 + b[o + 2] * 65536 + b[o + 3] * 16777216
  if v >= 2147483648 then v = v - 4294967296 end
  return v
end

local function set_le32(b, o, v)
  v = v < 0 and (4294967296 + v) or v
  b[o] = v % 256; b[o + 1] = math.floor(v / 256) % 256
  b[o + 2] = math.floor(v / 65536) % 256; b[o + 3] = math.floor(v / 16777216) % 256
end

local function decode_font(hex)
  if type(hex) ~= "string" or #hex < 122 or not hex:match("^[0-9A-Fa-f]+$") then return nil end
  local b = hex_to_bytes(hex)
  if #b < 61 then return nil end
  local sum = 0
  for i = 1, 60 do sum = (sum + b[i]) % 256 end
  if sum ~= b[61] then return nil end -- not a font blob
  local face = {}
  for i = 29, 60 do if b[i] == 0 then break end face[#face + 1] = string.char(b[i]) end
  return {
    bytes = b, height = le32(b, 1), weight = le32(b, 17), italic = b[21] ~= 0,
    face = table.concat(face),
  }
end

local function encode_font(f)
  local b = {}
  for i = 1, #f.bytes do b[i] = f.bytes[i] end
  set_le32(b, 1, f.height)
  set_le32(b, 17, f.weight)
  b[21] = f.italic and 1 or 0
  local sum = 0
  for i = 1, 60 do sum = (sum + b[i]) % 256 end
  b[61] = sum
  return bytes_to_hex(b)
end

local function copy_font(f)
  return { bytes = f.bytes, height = f.height, weight = f.weight, italic = f.italic, face = f.face }
end

local function font_same(a, b)
  return a.height == b.height and a.weight == b.weight and a.italic == b.italic
end

local function px(f) return math.abs(f.height) end
local function pt(f) return math.floor(math.abs(f.height) * 0.75 + 0.5) end
local function with_px(f, p)
  local n = math.max(4, math.min(96, math.floor(p + 0.5)))
  return f.height < 0 and -n or n
end

--------------------------------------------------------------------
-- Files and paths
--------------------------------------------------------------------
local function file_exists(p)
  local f = p and io.open(p, "rb"); if f then f:close() return true end return false
end

local function read_file(p)
  local f = io.open(p, "rb"); if not f then return nil end
  local d = f:read("*a"); f:close()
  return d
end

-- Check the return values of write and close; a full disk
-- or a write error yields false instead of a silently truncated file
local function write_file(p, d)
  local f = io.open(p, "wb"); if not f then return false end
  local okw = f:write(d)
  local okc = f:close()
  return (okw ~= nil and okw ~= false) and (okc ~= nil and okc ~= false)
end

-- Put tmp in place of final without deleting the old file first:
-- final -> final.bak, tmp -> final, on success delete .bak, otherwise rename .bak back.
-- Returns true, or false + reason; on an error tmp is left in place (the caller decides about cleanup).
-- keep: the old file stays as final.bak
-- (one generation, the next swap replaces it); third return value = path of the backup. REAPER and list_themes
-- do not show .bak as a theme (extension .ReaperTheme.bak / .ReaperThemeZip.bak).
-- An already existing .bak (previous generation) is removed only after a successful swap; if
-- the swap fails, it is put back in its place.
local function swap_in(tmp, final, keep)
  local bak = final .. ".bak"
  local hadOld = file_exists(final)
  local prev
  if hadOld then
    if file_exists(bak) then
      prev = bak .. ".prev"
      os.remove(prev)
      if not os.rename(bak, prev) then return false, "cannot move the old backup aside" end
    end
    if not os.rename(final, bak) then
      if prev then os.rename(prev, bak) end
      return false, "cannot move the old file aside"
    end
  end
  if os.rename(tmp, final) then
    if prev then os.remove(prev) end
    if hadOld and not keep then os.remove(bak) end
    return true, nil, (hadOld and keep) and bak or nil
  end
  if hadOld and not os.rename(bak, final) then
    -- the source now exists only as .bak, the previous generation as .bak.prev (no room for both under .bak);
    -- the caller reports this and does not create a fallback copy
    return false, "rename failed, old file kept as " .. bak   -- split_path is not defined yet here
  end
  if prev then os.rename(prev, bak) end
  return false, "rename failed"
end

local function file_size(p)
  local f = io.open(p, "rb"); if not f then return 0 end
  local n = f:seek("end"); f:close()
  return n or 0
end

local function split_path(p)
  local dir, base = (p or ""):match("^(.*[\\/])([^\\/]+)$")
  return dir or "", base or (p or "")
end

local function norm(p) return (p or ""):gsub("/", "\\"):lower() end

local function theme_stem(p)
  local _, base = split_path(p)
  return (base:gsub("%.[Rr]eaper[Tt]heme[Zz]ip$", ""):gsub("%.[Rr]eaper[Tt]heme$", ""))
end

local function is_zip(p) return (p or ""):lower():match("%.reaperthemezip$") ~= nil end
local function is_theme_file(f)
  local l = f:lower()
  return l:match("%.reaperthemezip$") or l:match("%.reapertheme$")
end
local function is_edit(p) return theme_stem(p):find(EDIT_MARK, 1, true) ~= nil end

-- REAPER finds the image folder of a plain theme via ui_img reliably only
-- with ASCII names -> sanitize the working copy name.
local function sanitize(stem)
  stem = stem:gsub("\226\128\147", "-"):gsub("\226\128\148", "-")
  stem = stem:gsub("\226\128\152", "'"):gsub("\226\128\153", "'")
  stem = stem:gsub("\226\128\156", '"'):gsub("\226\128\157", '"')
  return (stem:gsub("[^\32-\126]", "_"))
end

-- Stem without markers: (TT-Edit) = working copy, (TimTechlor) = baked,
-- (TTFonts) = working copy of the older TT_ThemeFonts script
local function base_stem(p)
  local s = theme_stem(p)
  s = s:gsub("%s*%(TT%-Edit%)$", ""):gsub("%s*%(TimTechlor[^%)]*%)$", ""):gsub("%s*%(TTFonts%)$", "")
  return s
end

local function list_themes(dir)
  local t, i = {}, 0
  while true do
    local f = R.EnumerateFiles(dir, i)
    if not f then break end
    i = i + 1
    if is_theme_file(f) and not is_edit(f) then t[#t + 1] = f end
  end
  table.sort(t, function(a, b) return a:lower() < b:lower() end)
  return t
end

-- all files below a folder (relative paths with "/")
local function list_files_rec(dir)
  local out = {}
  local function walk(d, rel)
    local i = 0
    while true do
      local f = R.EnumerateFiles(d, i)
      if not f then break end
      out[#out + 1] = rel .. f; i = i + 1
    end
    i = 0
    while true do
      local s = R.EnumerateSubdirectories(d, i)
      if not s then break end
      walk(d .. "/" .. s, rel .. s .. "/"); i = i + 1
    end
  end
  walk(dir, "")
  return out
end

--------------------------------------------------------------------
-- Zip (js_ReaScriptAPI)
--------------------------------------------------------------------
local function zip_open(p, mode)
  if not R.JS_Zip_Open then return nil end
  local ok, zh = pcall(R.JS_Zip_Open, p, mode, mode == "w" and 6 or 0)
  if not ok or not zh or (type(zh) ~= "userdata" and type(zh) ~= "number") then return nil end
  return zh
end

-- true if closing succeeded (js_ReaScriptAPI: negative number = error)
local function zip_close(p, zh)
  local ok, rv = pcall(R.JS_Zip_Close, p, zh)
  return ok and not (type(rv) == "number" and rv < 0)
end

local function zip_names(zh)
  local ok, n, names = pcall(R.JS_Zip_ListAllEntries, zh)
  local t = {}
  if ok then
    if type(names) ~= "string" and type(n) == "string" then names = n end
    if type(names) == "string" then
      for x in names:gmatch("[^%z]+") do t[#t + 1] = x end
    end
  end
  return t
end

local function zip_entry(zh, name)
  local ok, rv = pcall(R.JS_Zip_Entry_OpenByName, zh, name)
  return ok and (tonumber(rv) or 0) >= 0
end

local function zip_read(zh, name)
  if not zip_entry(zh, name) then return nil end
  local _, data = R.JS_Zip_Entry_ExtractToMemory(zh)
  pcall(R.JS_Zip_Entry_Close, zh)
  return type(data) == "string" and data or nil
end

-- check every step, returns true/false
local function zip_write(zh, name, data)
  local function good(ok, rv) return ok and not (type(rv) == "number" and rv < 0) and rv ~= false end
  if not good(pcall(R.JS_Zip_Entry_OpenByName, zh, name)) then return false end
  local okc = good(pcall(R.JS_Zip_Entry_CompressMemory, zh, data, #data))
  local okx = good(pcall(R.JS_Zip_Entry_Close, zh))
  return okc and okx
end

-- reads ini + rtconfig; for a zip also the entry names, for a plain theme
-- the image folder (assetDir) that holds the rtconfig
local function read_theme(p)
  local T = { path = p, zip = is_zip(p) }
  if not T.zip then
    T.ini = read_file(p)
    if not T.ini then return nil end
    local dir = split_path(p)
    local uiimg = T.ini:match("\nui_img%s*=%s*([^\r\n]+)")
    local cands = {}
    if uiimg then cands[#cands + 1] = dir .. uiimg:gsub("%s+$", "") end
    cands[#cands + 1] = dir .. theme_stem(p)
    for _, c in ipairs(cands) do
      T.rtc = read_file(c .. "/rtconfig.txt")
      if T.rtc then T.assetDir = c break end
    end
    return T
  end
  local zh = zip_open(p, "r")
  if not zh then return nil end
  T.names = zip_names(zh)
  for _, n in ipairs(T.names) do
    if n:lower():match("%.reapertheme$") and not n:find("/") and not T.iniEntry then T.iniEntry = n end
    if n:lower():match("rtconfig%.txt$") and not T.rtcEntry then T.rtcEntry = n end
  end
  if not T.iniEntry then
    for _, n in ipairs(T.names) do
      if n:lower():match("%.reapertheme$") then T.iniEntry = n break end
    end
  end
  T.ini = T.iniEntry and zip_read(zh, T.iniEntry)
  T.rtc = T.rtcEntry and zip_read(zh, T.rtcEntry)
  zip_close(p, zh)
  if not T.ini then return nil end
  return T
end

--------------------------------------------------------------------
-- Ini fonts
--------------------------------------------------------------------
local FONT_LABELS = {
  tl_font    = "Timeline / ruler",
  mi_font    = "Item / take names",
  lb_font    = "Track/mixer values (legacy)",
  lb_font2   = "Track names (legacy)",
  trans_font = "Transport (legacy)",
}

local function font_label(key)
  if FONT_LABELS[key] then return FONT_LABELS[key] end
  local n = key:match("^user_font(%d+)$")
  if n then return "WALTER font " .. (tonumber(n) + 1) end
  return key
end

local function parse_fonts(ini)
  local fonts, order = {}, {}
  for k, v in ini:gmatch("\n([%w_]*font%d*)=([0-9A-Fa-f]+)") do
    local d = decode_font(v)
    if d and not fonts[k] then fonts[k] = d; order[#order + 1] = k end
  end
  local function rank(k)
    local n = k:match("^user_font(%d+)$")
    return n and (100 + tonumber(n)) or 0
  end
  table.sort(order, function(a, b)
    local ra, rb = rank(a), rank(b)
    if ra ~= rb then return ra < rb end
    return a < b
  end)
  return fonts, order
end

local function patch_ini(ini, cur, base)
  for key, f in pairs(cur) do
    if base[key] and not font_same(f, base[key]) then
      ini = ini:gsub("(\n" .. key .. "=)[0-9A-Fa-f]+", "%1" .. encode_font(f), 1)
    end
  end
  return ini
end

-- The name goes into the replacement as a function result, not as replacement text: sanitize() keeps '%',
-- and "%1" .. name raises "invalid use of % in replacement string" for a '%' in the theme name.
-- If the [REAPER] section is missing, the line goes below the first section header "[color theme]".
local function set_ui_img(ini, name)
  if ini:find("\nui_img%s*=") then
    return (ini:gsub("(\nui_img%s*=%s*)[^\r\n]*", function(a) return a .. name end, 1))
  end
  if ini:find("%[REAPER%]") then
    return (ini:gsub("(%[REAPER%][^\r\n]*\r?\n)", function(a) return a .. "ui_img=" .. name .. "\r\n" end, 1))
  end
  return (ini:gsub("(%[color theme%][^\r\n]*\r?\n)", function(a) return a .. "ui_img=" .. name .. "\r\n" end, 1))
end

--------------------------------------------------------------------
-- rtconfig: WALTER evaluation (first vector component = font index;
-- 1..16 = user_font0..15, 0 = main font, -1 = volume/pan font)
--------------------------------------------------------------------
local FONTVARS = { main_font = true, list_font = true, trans_font = true, header_font = true }
local OS = R.GetOS() or ""
local OS_TYPE = OS:match("^Win") and 0 or (OS:match("^OSX") or OS:match("^macOS")) and 1 or 2

-- Effective theme scale: UI scale from the preferences (uiscale) times the
-- DPI factor. REAPER uses the next larger layout step with images
-- (100/150/200 %), so 125 % uses the 150 % layouts.
local function ui_scale()
  local u = 1
  if R.get_config_var_string then
    local ok, v = R.get_config_var_string("uiscale")
    u = ok and tonumber(v) or 1
  end
  local dpi = 256
  local ok, rv, v = pcall(R.ThemeLayout_GetLayout, "global", -3)
  if ok and rv then dpi = tonumber(v) or 256 end
  return u * dpi / 256
end

local function eff_scale(s)
  if s <= 1.01 then return 1 elseif s <= 1.51 then return 1.5 end
  return 2
end

local function wtokens(rhs)
  rhs = rhs:gsub("%[", " [ "):gsub("%]", " ] ")
  local root, stack = {}, {}
  local cur = root
  for t in rhs:gmatch("%S+") do
    if t == "[" then
      local v = { vec = true }
      cur[#cur + 1] = v; stack[#stack + 1] = cur; cur = v
    elseif t == "]" then
      cur = table.remove(stack) or root
    else
      cur[#cur + 1] = t
    end
  end
  return root
end

local CMP_OPS = { "==", "!=", "<=", ">=", "<", ">" }
local ARITH = { ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true }
-- names may contain "-" (macro concatenation "Layout##X##-tcpFont")
local NAME_PAT = "^[%a_][%w_%.%-]*$"

local function wlookup(env, src, name)
  local base, sfx = name:match("^(.-){(%d+)}$")
  if base then
    if sfx ~= "0" then return nil end
    name = base
    local n = tonumber(name)
    if n then return n end   -- substituted macro parameter: "1.5{0}"
  end
  if not name:match(NAME_PAT) then return nil end
  local v = env[name]
  if type(v) ~= "number" then return nil end
  return v, (FONTVARS[name] and name) or src[name]
end

local function watom(env, src, t)
  if t == nil then return nil end
  local n = tonumber(t)
  if n then return n end
  return wlookup(env, src, t)
end

local function wcond(env, src, t)
  local neg, flag = t:match("^([%?!])(.+)$")
  if neg and not t:find("!=", 1, true) then
    local v = watom(env, src, flag)
    if v == nil then return nil end
    if neg == "?" then return v ~= 0 end
    return v == 0
  end
  for _, op in ipairs(CMP_OPS) do
    local s, e = t:find(op, 1, true)
    if s and s > 1 and e < #t then
      local a = watom(env, src, t:sub(1, s - 1))
      local b = watom(env, src, t:sub(e + 1))
      if a == nil or b == nil then return nil end
      if op == "==" then return a == b
      elseif op == "!=" then return a ~= b
      elseif op == "<=" then return a <= b
      elseif op == ">=" then return a >= b
      elseif op == "<" then return a < b
      else return a > b end
    end
  end
  return false, true -- not a comparison
end

local function weval(env, src, toks, i, cur, curSrc)
  local t = toks[i]
  if t == nil then return cur, curSrc, i end
  if type(t) == "table" then
    local f = t[1]
    if f == nil or f == "." then return cur, curSrc, i + 1 end
    if type(f) == "table" then return nil, nil, i + 1 end
    local v, s = watom(env, src, f)
    return v, s, i + 1
  end
  if t == "." then return cur, curSrc, i + 1 end
  if ARITH[t] then
    local a, sa, j = weval(env, src, toks, i + 1, cur, curSrc)
    local b, sb, k = weval(env, src, toks, j, cur, curSrc)
    if a == nil or b == nil then return nil, nil, k end
    local s = sb or sa
    if t == "+" then return a + b, s, k
    elseif t == "-" then return a - b, s, k
    elseif t == "*" then return a * b, s, k
    else return (b ~= 0) and a / b or nil, s, k end
  end
  local c, notcmp = wcond(env, src, t)
  if not notcmp then
    local tv, ts, j = weval(env, src, toks, i + 1, cur, curSrc)
    local fv, fs = cur, curSrc
    if toks[j] ~= nil then fv, fs, j = weval(env, src, toks, j, cur, curSrc) end
    if c == true then return tv, ts, j end
    if c == false then return fv, fs, j end
    if tv == fv then return tv, ts or fs, j end
    return nil, nil, j
  end
  local v, s = watom(env, src, t)
  return v, s, i + 1
end

local function theme_params(rtc)
  local p = {}
  for name, def in rtc:gmatch("define_parameter%s+([%w_%.%-]+)%s+'[^']*'%s+(%-?[%d%.]+)") do
    p[name] = tonumber(def)
  end
  if R.ThemeLayout_GetParameter then
    for i = 0, 2000 do
      local ok, name, _, val = pcall(R.ThemeLayout_GetParameter, i)
      if not ok or not name then break end
      if p[name] ~= nil then p[name] = tonumber(val) or p[name] end
    end
  end
  return p
end

local function copy_tab(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end

-- Evaluates the rtconfig like WALTER: macros with parameters (incl. "##"),
-- nested layout blocks, "set" lines in file order.
-- A layout = default (lines outside layouts and in layout '')
-- + lines of its parent layouts + its own lines.
-- Result: layout(name) = { idx = element->font index, var = element->
-- font variable }, "" = default; tags[name] = scale tag (150).
-- Layouts are evaluated on demand and cached.
local function parse_rtconfig(rtc, scale)
  local res = { layouts = { [""] = { idx = {}, var = {} } }, tags = {}, order = {}, known = {} }
  function res.layout(name) return res.layouts[name] or res.layouts[""] end
  if not rtc then return res end
  local text = rtc:gsub("\\%s*\r?\n", " ")
  local macros, lines, cur = {}, {}, nil
  local stack, parent = {}, {}
  for raw in text:gmatch("[^\r\n]+") do
    -- Loop variables are constant in newer Lua versions, so use a separate variable instead of 'l = ...'.
    local l = raw:gsub(";.*$", "")
    local first, rest = l:match("^%s*(%S+)%s*(.-)%s*$")
    local lf = first and first:lower()
    if lf == "macro" then
      local mname, margs = rest:match("^([%w_]+)%s*(.-)$")
      cur = { params = {}, body = {} }
      for p in (margs or ""):gmatch("%S+") do cur.params[#cur.params + 1] = p end
      if mname then macros[mname] = cur end
    elseif cur and lf == "endmacro" then
      cur = nil
    elseif cur then
      cur.body[#cur.body + 1] = l
    elseif lf == "layout" then
      local q = rest:sub(1, 1)
      local lname, after
      if q == '"' or q == "'" then lname, after = rest:match("^" .. q .. "([^" .. q .. "]*)" .. q .. "%s*(.-)$")
      else lname, after = rest:match("^(%S+)%s*(.-)$") end
      lname = lname or ""
      local tag = after and tonumber((after:gsub("^['\"]", "")):match("^(%d+)"))
      if lname ~= "" then
        if tag then res.tags[lname] = tag end
        if parent[lname] == nil then
          parent[lname] = stack[#stack] or false
          res.order[#res.order + 1] = lname
        end
      end
      stack[#stack + 1] = lname
    elseif lf == "endlayout" then
      stack[#stack] = nil
    elseif first then
      -- layout context: innermost named layout ('' counts as default)
      local ctxl = ""
      for i = #stack, 1, -1 do if stack[i] ~= "" then ctxl = stack[i] break end end
      lines[#lines + 1] = { l, ctxl }
    end
  end

  local function exec(env, src, l, depth)
    local first, rest = l:match("^%s*(%S+)%s*(.-)%s*$")
    if not first then return end
    if first:lower() == "set" then
      local name, rhs = rest:match("^([%a_][%w_%.%-]*)%s+(.-)$")
      if name and rhs ~= "" then
        local v, s = weval(env, src, wtokens(rhs), 1, env[name], src[name])
        if v ~= nil then env[name] = v; src[name] = s end
      end
    elseif macros[first] and depth < 20 then
      local m = macros[first]
      local args = {}
      for a in rest:gmatch("%S+") do
        args[#args + 1] = (a:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1"))
      end
      for _, bl0 in ipairs(m.body) do
        local bl = bl0
        for pi, p in ipairs(m.params) do
          local a = (args[pi] or ""):gsub("%%", "%%%%")
          bl = bl:gsub("%f[%w_]" .. p:gsub("%W", "%%%0") .. "%f[^%w_]", a)
        end
        exec(env, src, (bl:gsub("##", "")), depth + 1)
      end
    end
  end

  local function collect(env, src)
    local L = { idx = {}, var = {} }
    for k, v in pairs(env) do
      if k:match("%.font$") then
        L.idx[k] = math.floor(v + 0.5)
        if src[k] then L.var[k] = src[k] end
      end
    end
    return L
  end

  -- default
  local E0, S0 = { scale = scale, os_type = OS_TYPE }, {}
  for k, v in pairs(theme_params(rtc)) do E0[k] = v end
  for _, ln in ipairs(lines) do
    if ln[2] == "" then exec(E0, S0, ln[1], 0) end
  end
  res.layouts[""] = collect(E0, S0)

  -- per layout: default + chain of parent layouts + own lines
  for _, name in ipairs(res.order) do res.known[name] = true end
  function res.layout(name)
    if res.layouts[name] then return res.layouts[name] end
    if not res.known[name] then return res.layouts[""] end
    local chain, p = {}, name
    while p do chain[p] = true; p = parent[p] or nil end
    local env, src = copy_tab(E0), copy_tab(S0)
    local any = false
    for _, ln in ipairs(lines) do
      if ln[2] ~= "" and chain[ln[2]] then exec(env, src, ln[1], 0); any = true end
    end
    res.layouts[name] = any and collect(env, src) or res.layouts[""]
    return res.layouts[name]
  end
  return res
end

-- Which layout applies: the track's layout (or the section default), and
-- above 100 % the matching scale step ("150%_A" with tag 150).
-- Names the rtconfig does not define count as default, so the scale
-- step is still found.
local function resolve_layout(W, section, name, escale)
  name = name or ""
  if name == "" and section then
    local ok, rv, dn = pcall(R.ThemeLayout_GetLayout, section, -1)
    if ok and rv and type(dn) == "string" then name = dn end
  end
  if name ~= "" and not W.known[name] then name = "" end
  if escale > 1 then
    local tag = math.floor(escale * 100 + 0.5)
    for _, ln in ipairs(W.order) do
      if W.tags[ln] == tag and (name == "" or ln:sub(-(#name + 1)) == "_" .. name) then return ln end
    end
  end
  return name
end

-- Writes element overrides into the rtconfig: after every (logical)
-- "set <elem> ..." line, a line that replaces only the font index
local function apply_overrides(rtc, ovr)
  if not next(ovr) then return rtc end
  local out, pending = {}, nil
  for line in (rtc .. "\n"):gmatch("(.-)\r?\n") do
    out[#out + 1] = line
    local target = pending
    if not target and not line:match("^%s*;") then
      local ind, name = line:match("^(%s*)set%s+([%w_%.%-]+)%s")
      if name and ovr[name] then target = { ind = ind, name = name } end
    end
    if target then
      if line:match("\\%s*$") then
        pending = target
      else
        pending = nil
        out[#out + 1] = target.ind .. "set " .. target.name .. " [" .. ovr[target.name]
          .. " . . . . . . .] " .. OVR_MARK
      end
    end
  end
  return table.concat(out, "\r\n")
end

local function read_overrides(rtc)
  local ovr = {}
  for name, idx in (rtc or ""):gmatch("set%s+([%w_%.%-]+)%s+%[(%-?%d+)[^\r\n]-" .. OVR_MARK:gsub("%p", "%%%0")) do
    ovr[name] = tonumber(idx)
  end
  return ovr
end

local function ovr_sig(ovr)
  local t = {}
  for k, v in pairs(ovr) do t[#t + 1] = k .. "=" .. v end
  table.sort(t)
  return table.concat(t, ";")
end

--------------------------------------------------------------------
-- Keep layouts and theme parameters across theme reloads
--------------------------------------------------------------------
local LAYOUT_SECS = { "tcp", "mcp", "trans", "envcp", "master_tcp", "master_mcp" }

local function capture_layouts()
  local t = {}
  for _, sec in ipairs(LAYOUT_SECS) do
    local ok, rv, cur = pcall(R.ThemeLayout_GetLayout, sec, -1)
    if ok and rv and type(cur) == "string" and cur ~= "" then t[sec] = cur end
  end
  return t
end

local function apply_layouts(saved)
  for sec, lay in pairs(saved or {}) do pcall(R.ThemeLayout_SetLayout, sec, lay) end
  pcall(R.ThemeLayout_RefreshAll)
  R.UpdateArrange()
  R.TrackList_AdjustWindows(false)
end

-- Copy theme settings (reaper-themeconfig.ini) to the new theme name
local function sync_themeconfig(fromName, toName)
  if fromName == toName then return end
  local f = RES .. "/reaper-themeconfig.ini"
  local txt = read_file(f); if not txt then return end
  local function find_sec(name)
    local pat = name:gsub("(%W)", "%%%1")
    local s, e = txt:find("\n%[" .. pat .. "%]")
    if not s then s, e = txt:find("^%[" .. pat .. "%]"); if s then s = 0 end end
    -- At the start of the file no line break precedes the section, so s = 0: txt:sub(1, ts) must not keep the first '['.
    return s, e
  end
  local s, e = find_sec(fromName)
  if not s then return end
  local e2 = txt:find("\n%[", e)
  local body = txt:sub(e + 1, e2 or -1)
  local ts, te = find_sec(toName)
  if ts then
    local te2 = txt:find("\n%[", te)
    txt = txt:sub(1, ts) .. "[" .. toName .. "]" .. body .. txt:sub(te2 or (#txt + 1))
  else
    txt = txt .. (txt:sub(-1) == "\n" and "" or "\n") .. "[" .. toName .. "]" .. body
  end
  write_file(f, txt)
end

local function load_theme(p)
  local lay = capture_layouts()
  local ok = R.OpenColorThemeFile(p)
  if ok then apply_layouts(lay) end
  return ok
end

--------------------------------------------------------------------
-- State
--------------------------------------------------------------------
local S = {
  orig = nil,        -- original theme (zip or plain)
  T = nil,           -- parsed original (ini, rtc, names, iniEntry ...)
  base = {}, cur = {}, order = {},
  W = nil,           -- evaluated rtconfig (layouts)
  elemIdx = {}, elemVar = {},   -- default layout (for "used by")
  scale = 1, uiscale = 1, defLayout = "",
  confirm = {},      -- font chosen by the user per hit-test name
  ovr = {},          -- element overrides: "mcp.fxlist.font" -> font index
  rtcSig = nil,      -- overrides currently written to the working copy rtconfig
  test = nil,        -- font currently enlarged for identification
  wcIni = nil, wcFolder = nil, wcReady = false, wcLoaded = false, needFolder = false,
  dirtyAt = nil,     -- time of the last change (debounce)
  job = nil,         -- running sliced job
  target = nil,      -- locked picker result
  hover = nil,       -- live result under the mouse
  sel = nil,         -- font key being edited
  elemFilter = "",
  status = "Ready.",
  guiHovered = false,
}
local picker = { armed = false, down = false, shift = false }

local function set_status(s) S.status = tostring(s) tlog("status: " .. S.status) end

local function changed_count()
  local n = 0
  for k, f in pairs(S.cur) do
    if S.base[k] and not font_same(f, S.base[k]) then n = n + 1 end
  end
  for _ in pairs(S.ovr) do n = n + 1 end
  return n
end

local function usage_of(key)
  local n = key:match("^user_font(%d+)$")
  local t = {}
  if not n then return t end
  local idx = tonumber(n) + 1
  for e, i in pairs(S.elemIdx) do
    if (S.ovr[e] or i) == idx then t[#t + 1] = e end
  end
  table.sort(t)
  return t
end

local function key_of_idx(idx) return idx and idx >= 1 and ("user_font" .. (idx - 1)) or nil end
local function idx_of_key(key) local n = key:match("^user_font(%d+)$") return n and (tonumber(n) + 1) end

-- font chosen by the user (hit-test name -> font), per theme
local function confirm_key() return "confirm|" .. base_stem(S.orig or "") end

local function load_confirm()
  S.confirm = {}
  local s = R.GetExtState(NS, confirm_key())
  for e, k in s:gmatch("([^=;]+)=([^;]+)") do S.confirm[e] = k end
end

local function save_confirm()
  local t = {}
  for e, k in pairs(S.confirm) do t[#t + 1] = e .. "=" .. k end
  R.SetExtState(NS, confirm_key(), table.concat(t, ";"), true)
end

--------------------------------------------------------------------
-- Detect theme
--------------------------------------------------------------------
local function find_original(p)
  local dir = split_path(p)
  local stem = base_stem(p)
  local want = sanitize(stem)
  local best
  for _, f in ipairs(list_themes(dir)) do
    local fs = theme_stem(f)
    if fs == stem or sanitize(fs) == want then
      if not best or is_zip(f) then best = f end
    end
  end
  return best and (dir .. best) or nil
end

local function workcopy_paths(orig)
  local dir = split_path(orig)
  local stem = sanitize(base_stem(orig)) .. EDIT_MARK
  return dir .. stem .. ".ReaperTheme", dir .. stem
end

-- Bake target:
--   "copy"      = new file next to the original "<name> (TimTechlor)"; if the name is already taken (as .ReaperTheme OR
--                 .ReaperThemeZip, both show the same name in REAPER and share the themeconfig section), consecutively
--                 "(TimTechlor 2)", "(TimTechlor 3)" ... Never over an existing file.
--   "overwrite" = back into the source file itself, its previous version is kept as "<file>.bak" (swap_in with keep).
-- Default "copy": a wrong choice costs at most one extra file, never the original (not even for Default 7.0).
-- Saved in ExtState bake_target. An unpacked theme with element overrides is always baked as a zip (the
-- changed rtconfig must be included) -> overwriting is not possible there, a copy is made instead (button locked, tooltip
-- and status say so); the saved choice stays for the next themes.
-- Previously the target was always "<name> (TimTechlor)", replacing an existing target and keeping a .bak.
local function stem_taken(dir, stem)
  return file_exists(dir .. stem .. ".ReaperTheme") or file_exists(dir .. stem .. ".ReaperThemeZip")
end

local function copy_path(orig, asZip)
  local dir = split_path(orig)
  local base = sanitize(base_stem(orig))
  local stem, n = base .. BAKE_MARK, 1
  while stem_taken(dir, stem) and n < 999 do
    n = n + 1
    stem = base .. " (TimTechlor " .. n .. ")"
  end
  -- even "(TimTechlor 999)" is taken -> no name (the bake stops with a message)
  if stem_taken(dir, stem) then return nil end
  return dir .. stem .. (asZip and ".ReaperThemeZip" or ".ReaperTheme")
end

-- Place the copy: only onto a name that is taken with NO extension, and via
-- os.rename, which on Windows never replaces an existing file (no swap_in, hence no .bak that could be deleted).
-- If the name was taken since the selection (race during the job), the next free number is used.
-- Returns: path, or nil + reason; tmp is left in place on an error.
local function place_copy(tmp, target, asZip)
  if not target or stem_taken(split_path(target), theme_stem(target)) then target = copy_path(S.orig, asZip) end
  if not target then return nil, "no free name for a copy" end
  if os.rename(tmp, target) then return target end
  return nil, "rename failed"
end

local function bake_mode()
  if not S.bakeTarget then
    S.bakeTarget = R.GetExtState(NS, "bake_target") == "overwrite" and "overwrite" or "copy"
  end
  return S.bakeTarget
end

local function set_bake_mode(m, persist)
  S.bakeTarget = (m == "overwrite") and "overwrite" or "copy"
  if persist then R.SetExtState(NS, "bake_target", S.bakeTarget, true) end
end

-- actual target: path, mode ("copy" | "overwrite"), note if overwriting was chosen but is not possible
local function bake_target(asZip)
  local orig = S.orig
  if bake_mode() == "overwrite" then
    if (asZip and true or false) == is_zip(orig) then return orig, "overwrite" end
    return copy_path(orig, asZip), "copy", "overrides need a zipped theme"
  end
  return copy_path(orig, asZip), "copy"
end

local function source_sig()
  local T = S.T
  if T.zip then return T.path .. "|" .. file_size(T.path) end
  return (T.assetDir or "") .. "|" .. file_size((T.assetDir or "") .. "/rtconfig.txt")
end

local function reparse()
  S.uiscale = ui_scale()
  S.scale = eff_scale(S.uiscale)
  local t0 = R.time_precise()
  S.W = parse_rtconfig(S.T and S.T.rtc, S.scale)
  S.defLayout = resolve_layout(S.W, "mcp", nil, S.scale)
  local L = S.W.layout(S.defLayout)
  S.elemIdx, S.elemVar = L.idx, L.var
  tlog(string.format("rtconfig parsed: %.0f ms, scale %.2f -> %.1f, layout '%s'",
    (R.time_precise() - t0) * 1000, S.uiscale, S.scale, S.defLayout))
end

-- builds the state for the active theme
local function init_theme(active)
  S.T, S.base, S.cur, S.order, S.ovr = nil, {}, {}, {}, {}
  S.target, S.hover, S.sel, S.dirtyAt, S.test, S.rtcSig = nil, nil, nil, nil, nil, nil
  S.wcReady, S.wcLoaded = false, false
  if not active or active == "" then set_status("No theme active.") return false end

  local orig
  if is_edit(active) then
    -- prefer the remembered original if it matches the working copy
    local saved = R.GetExtState(NS, "orig")
    if saved ~= "" and file_exists(saved) and not is_edit(saved)
        and sanitize(base_stem(saved)) == sanitize(base_stem(active)) then
      orig = saved
    else
      orig = find_original(active)
    end
  elseif file_exists(active) then
    orig = active
  else
    orig = find_original(active)
  end
  if not orig then
    set_status("Theme file missing, no original found: " .. select(2, split_path(active)))
    return false
  end
  local T = read_theme(orig)
  if not T then
    set_status((is_zip(orig) and not R.JS_Zip_Open) and "js_ReaScriptAPI missing - cannot read zip"
      or ("Cannot read theme: " .. select(2, split_path(orig))))
    return false
  end
  S.orig, S.T = orig, T
  -- Has REAPER loaded the theme parameters (rtconfig) of the active original? An unpacked theme
  -- outside ColorThemes does not get them even for the original (there ThemeLayout_GetParameter(0) = nil,
  -- the same copy in ColorThemes provides parameters). Then the
  -- missing rtconfig of the working copy is not a preview error -> no warning (apply_preview). nil = unknown.
  if is_edit(active) or not R.ThemeLayout_GetParameter then S.origParams = nil
  else S.origParams = R.ThemeLayout_GetParameter(0) ~= nil end
  S.needFolder = T.zip or T.assetDir ~= nil
  R.SetExtState(NS, "orig", orig, true)
  S.wcIni, S.wcFolder = workcopy_paths(orig)
  S.base, S.order = parse_fonts(T.ini)
  for k, f in pairs(S.base) do S.cur[k] = copy_font(f) end

  if S.needFolder and read_file(S.wcFolder .. "/.tt_ready") == source_sig() then
    S.wcReady = true
    local wrtc = read_file(S.wcFolder .. "/rtconfig.txt")
    S.rtcSig = ovr_sig(read_overrides(wrtc))
    if is_edit(active) then S.ovr = read_overrides(wrtc) end
  end
  -- working copy already active: take its values as the current state
  if is_edit(active) and file_exists(active) then
    local wc = parse_fonts(read_file(active) or "")
    for k, f in pairs(wc) do if S.cur[k] then S.cur[k] = copy_font(f) end end
    S.wcLoaded = norm(active) == norm(S.wcIni)
  end
  reparse()
  load_confirm()
  if norm(active) ~= norm(orig) and not is_edit(active) then
    set_status("Active theme '" .. select(2, split_path(active)) .. "' missing - reading "
      .. select(2, split_path(orig)))
  else
    set_status("Ready. " .. #S.order .. " fonts, " .. (T.rtc and "rtconfig ok" or "no rtconfig"))
  end
  tlog("orig=" .. orig .. " active=" .. active .. " fonts=" .. #S.order)
  return true
end

--------------------------------------------------------------------
-- Sliced jobs: run at most BUDGET seconds per defer tick
--------------------------------------------------------------------
local function run_job()
  local J = S.job
  if not J then return end
  -- Test hook holdat:<n> (only with test_ok): pause the job at step n so the test rig can capture the progress
  if S.holdAt and (J.pos or 0) >= S.holdAt then return end
  local t0 = R.time_precise()
  local ok, err = pcall(function()
    while R.time_precise() - t0 < BUDGET do
      if S.holdAt and (J.pos or 0) >= S.holdAt then return end
      if J.step() then
        S.job = nil
        if J.done then J.done() end
        return
      end
    end
  end)
  if not ok then
    S.job = nil
    if J.fail then J.fail() end
    set_status(J.name .. " failed: " .. tostring(err))
  end
end

-- Window closed or script ended while a job is running.
-- The job is ended through its own failure path (J.fail: close source and target exactly once, delete the temporary
-- zip); a pending bake is dropped. An aborted preparation leaves no ready marker
-- (.tt_ready), the working folder is refilled next time. Calling it repeatedly (window + atexit) is harmless.
local function abort_job(why)
  S.bakePending = nil
  S.holdAt = nil
  local J = S.job
  if not J then return false end
  S.job = nil
  if J.fail then pcall(J.fail) end
  tlog(string.format("%s aborted (%s) at %d / %d - temporary files removed, target unchanged",
    J.name or "job", why, J.pos or 0, J.total or 0))
  return true
end

-- Prepare the working folder: extract the zip flat (image folder content to
-- the root) or copy the image folder of a plain theme. The working copy's
-- ui_img points to this folder.
local function start_prepare(done)
  local T = S.T
  local list, zh, prefix = {}, nil, ""
  if T.zip then
    zh = zip_open(T.path, "r")
    if not zh then set_status("Cannot read zip") return end
    prefix = T.rtcEntry and T.rtcEntry:match("^(.*/)") or nil
    if not prefix then
      local ui = T.ini:match("\nui_img%s*=%s*([^\r\n]+)")
      prefix = ui and (ui:gsub("%s+$", "") .. "/") or ""
    end
    for _, n in ipairs(T.names) do
      if n:sub(-1) ~= "/" and n:sub(1, #prefix) == prefix
          and not (prefix == "" and n:lower():match("%.reapertheme$")) then
        list[#list + 1] = n
      end
    end
  else
    list = list_files_rec(T.assetDir)
  end
  R.RecursiveCreateDirectory(S.wcFolder, 0)
  local made, i = {}, 0
  -- check every file; the ready marker .tt_ready and wcReady only after
  -- complete success, otherwise a status message and no further processing (preview/bake never build on a partial folder)
  local fails = {}
  S.job = {
    name = T.zip and "Extracting" or "Copying", total = #list, pos = 0,
    step = function()
      i = i + 1
      S.job.pos = i
      local n = list[i]
      if not n then
        if zh then zip_close(T.path, zh) end
        if #fails == 0 and not write_file(S.wcFolder .. "/.tt_ready", source_sig()) then
          fails[#fails + 1] = ".tt_ready"
        end
        return true
      end
      local rel = T.zip and n:sub(#prefix + 1) or n
      local out = S.wcFolder .. "/" .. rel
      local d = out:match("^(.*)/[^/]+$")
      if d and not made[d] then R.RecursiveCreateDirectory(d, 0); made[d] = true end
      local ok = false
      if T.zip then
        if zip_entry(zh, n) then
          pcall(R.JS_Zip_Entry_ExtractToFile, zh, out)
          pcall(R.JS_Zip_Entry_Close, zh)
          ok = file_exists(out)
        end
      else
        local data = read_file(T.assetDir .. "/" .. n)
        ok = data ~= nil and write_file(out, data)
      end
      if not ok then fails[#fails + 1] = rel end
      return false
    end,
    done = function()
      if #fails > 0 then
        S.wcReady = false
        tlog("working folder incomplete: " .. #fails .. " of " .. #list .. " files failed, first: " .. fails[1])
        set_status("Working copy incomplete: " .. #fails .. " file" .. (#fails == 1 and "" or "s")
          .. " could not be " .. (T.zip and "extracted" or "copied") .. " (first: " .. fails[1] .. ") - preview stopped")
        return
      end
      S.wcReady, S.rtcSig = true, ""
      tlog("working folder: " .. #list .. " files")
      done()
    end,
    fail = function() if zh then zip_close(T.path, zh) end end,
  }
  set_status("Preparing working copy (one time only) ...")
end

--------------------------------------------------------------------
-- Preview
--------------------------------------------------------------------
local function workcopy_ini()
  local cur = S.cur
  if S.test and S.cur[S.test] then
    -- identification test: font much larger and bold, preview only
    cur = {}
    for k, f in pairs(S.cur) do cur[k] = f end
    local f = copy_font(S.cur[S.test])
    f.height = with_px(f, math.max(px(f) * 2, px(f) + 10))
    f.weight = 800
    cur[S.test] = f
  end
  local ini = patch_ini(S.T.ini, cur, S.base)
  if S.needFolder then ini = set_ui_img(ini, select(2, split_path(S.wcFolder))) end
  return ini
end

local function apply_preview()
  S.dirtyAt = nil
  if not S.T then return end
  if S.needFolder and not S.wcReady then
    if not S.job then start_prepare(apply_preview) end
    return
  end
  -- write the working copy rtconfig only when the overrides changed
  local reread = false
  if S.needFolder and S.T.rtc then
    local sig = ovr_sig(S.ovr)
    if sig ~= S.rtcSig then
      if not write_file(S.wcFolder .. "/rtconfig.txt", apply_overrides(S.T.rtc, S.ovr)) then
        set_status("Cannot write working copy rtconfig") return
      end
      S.rtcSig = sig
      reread = S.wcLoaded
    end
  end
  if not write_file(S.wcIni, workcopy_ini()) then set_status("Cannot write working copy") return end
  local first = not S.wcLoaded
  if first then sync_themeconfig(theme_stem(S.orig), theme_stem(S.wcIni)) end
  local t0 = R.time_precise()
  -- REAPER does not re-read the rtconfig when the same path is reloaded ->
  -- load the original briefly, then the working copy
  if reread then R.OpenColorThemeFile(S.orig) end
  if not load_theme(S.wcIni) then set_status("Could not load preview") return end
  S.wcLoaded = true
  if first then
    local want = S.T.rtc and S.T.rtc:find("define_parameter") ~= nil
    local okp = R.ThemeLayout_GetParameter and R.ThemeLayout_GetParameter(0) ~= nil
    -- warn only if REAPER had loaded the original's rtconfig (S.origParams not false), see init_theme
    if want and not okp and S.origParams ~= false then set_status("Warning: working copy rtconfig not loaded") return end
  end
  local n = changed_count()
  set_status(string.format("Preview active (%d change%s, reload %.0f ms)%s", n, n == 1 and "" or "s",
    (R.time_precise() - t0) * 1000, S.test and (" - TEST: " .. font_label(S.test) .. " enlarged") or ""))
end

local function touch() S.dirtyAt = R.time_precise() end

local function set_font(key, fn)
  local f = S.cur[key]; if not f then return end
  fn(f)
  touch()
end

local function set_override(elem, idx)
  if not S.needFolder or not S.T.rtc then
    set_status("Element overrides need a theme with rtconfig") return
  end
  S.ovr[elem] = idx
  touch()
end

--------------------------------------------------------------------
-- Bake / discard
--------------------------------------------------------------------
local function cleanup_workcopy()
  if S.wcIni and file_exists(S.wcIni) then os.remove(S.wcIni) end
  if S.wcFolder and file_exists(S.wcFolder .. "/.tt_ready") then
    os.remove(S.wcFolder .. "/.tt_ready")
    -- rename first, then delete in the background. Otherwise rmdir would delete the folder under its
    -- own name while an immediately following change (e.g. baking again) was already refilling it.
    local del = S.wcFolder .. ".del" .. os.time()
    -- If the rename fails, do not delete the live folder in the background (a follow-up change may be refilling it already);
    -- without .tt_ready it is refilled the next time anyway.
    if os.rename(S.wcFolder, del) then
      -- remove the folder without a console window and without waiting
      R.ExecProcess('cmd.exe /C rmdir /S /Q "' .. del:gsub("/", "\\") .. '"', -1)
    end
  end
  S.wcReady, S.wcLoaded, S.rtcSig = false, false, nil
end

-- bak = backup of the previously existing target (swap_in with keep), otherwise nil; mode = "copy" | "overwrite";
-- note = reason if the target differs from the chosen one. The status line always names the actual target.
local function finish_bake(final, bak, mode, note)
  sync_themeconfig(theme_stem(S.orig), theme_stem(final))
  if not load_theme(final) then set_status("Saved, but could not load: " .. final) return end
  cleanup_workcopy()
  init_theme(final)
  S.lastBake, S.lastBak = final, bak
  local name = select(2, split_path(final))
  if mode == "overwrite" then
    set_status("Baked: " .. name .. " (original overwritten)"
      .. (bak and (" - previous version kept as " .. select(2, split_path(bak))) or ""))
  else
    set_status("Baked: " .. name .. " (new copy, original untouched" .. (note and (" - " .. note) or "") .. ")")
  end
end

-- builds a zip in slices; items = { {name, get = function() -> data} }
local function start_zip_job(final, items, closeSrc, mode, note)
  -- do not delete a leftover .tmp of an earlier failed bake ("new theme kept as ...");
  -- use a free tmp name instead
  local tmp = final:gsub("%.ReaperThemeZip$", ".tmp.ReaperThemeZip")
  local k = 1
  while file_exists(tmp) and k < 99 do
    k = k + 1
    tmp = final:gsub("%.ReaperThemeZip$", ".tmp" .. k .. ".ReaperThemeZip")
  end
  -- A free name needs no os.remove; if all 99 names are taken, stop instead of deleting the last .tmp.
  if file_exists(tmp) then
    if closeSrc then closeSrc() end
    set_status("No free temporary name - remove old .tmp files next to the theme")
    return
  end
  local dst = zip_open(tmp, "w")
  if not dst then if closeSrc then closeSrc() end set_status("Could not create zip") return end
  local i = 0
  local srcOpen, dstOpen = true, true
  local function close_src() if srcOpen and closeSrc then closeSrc() end srcOpen = false end
  S.job = {
    name = "Baking", total = #items, pos = 0,
    step = function()
      i = i + 1
      S.job.pos = i
      local it = items[i]
      if not it then
        close_src()
        dstOpen = false
        if not zip_close(tmp, dst) then error("could not finish " .. select(2, split_path(tmp)), 0) end
        local target, ok, why, bak = final, false, nil, nil
        if mode == "overwrite" then
          -- if the target is loaded in REAPER, switch to the preview to release it
          if norm(R.GetLastColorThemeFile()) == norm(target) and file_exists(S.wcIni) then
            R.OpenColorThemeFile(S.wcIni)
          end
          -- the old target is not deleted beforehand but swapped via swap_in.
          -- OVERWRITE ORIGINAL replaces the source itself, its old version is kept as .bak.
          -- The source has already been read completely and closed here (close_src above) before it is replaced.
          ok, why, bak = swap_in(tmp, target, true)
          if not ok and not file_exists(target) then
            -- swapping back failed: the original now exists only as .bak -> no
            -- fallback copy and no "original untouched" message; the reason names the .bak
            set_status("Rename failed (" .. why .. "): new theme kept as " .. select(2, split_path(tmp)))
            return true
          end
        else
          -- copy: never over an existing file (place_copy)
          local placed
          placed, why = place_copy(tmp, target, true)
          ok = placed ~= nil
          if ok then target = placed end
        end
        if not ok then
          -- target locked: save under a new name instead of failing (the old file stays untouched).
          -- fallback name = next free copy name (a timestamp in the name would not work for an
          -- original without a trailing parenthesis, e.g. Default_7.0)
          local alt = copy_path(S.orig, true)
          local placed = alt and norm(alt) ~= norm(target) and place_copy(tmp, alt, true) or nil
          if not placed then
            set_status("Rename failed (" .. tostring(why) .. "): new theme kept as " .. select(2, split_path(tmp)))
            return true
          end
          tlog("target locked (" .. tostring(why) .. "), written as " .. placed)
          finish_bake(placed, nil, "copy", "target was locked")
          return true
        end
        finish_bake(target, bak, mode, note)
        return true
      end
      -- missing/unreadable content or a write error aborts the bake
      -- (run_job calls fail(): tmp is removed, status "Baking failed: ...")
      local data = it.get()
      if data == nil then error("missing or unreadable content: " .. it.name, 0) end
      if not zip_write(dst, it.name, data) then error("could not write " .. it.name, 0) end
      return false
    end,
    fail = function()
      close_src()
      if dstOpen then dstOpen = false; zip_close(tmp, dst) end
      os.remove(tmp)
    end,
  }
  set_status("Writing " .. select(2, split_path(final)) .. " ...")
end

local function start_bake()
  if not S.T or S.job then return end
  S.test = nil
  local T = S.T
  local ini = patch_ini(T.ini, S.cur, S.base)
  local hasOvr = next(S.ovr) ~= nil

  if T.zip then
    local src = zip_open(T.path, "r")
    if not src then set_status("Cannot read zip") return end
    local rtc = hasOvr and T.rtc and apply_overrides(T.rtc, S.ovr) or nil
    local items = {}
    for _, n in ipairs(T.names) do
      if n:sub(-1) ~= "/" then
        items[#items + 1] = { name = n, get = function()
          if n == T.iniEntry then return ini end
          if rtc and n == T.rtcEntry then return rtc end
          return zip_read(src, n)
        end }
      end
    end
    local final, mode, note = bake_target(true)
    if not final then zip_close(T.path, src); set_status("No free name for a copy (nothing baked)") return end
    start_zip_job(final, items, function() zip_close(T.path, src) end, mode, note)
    return
  end

  if not hasOvr then
    -- plain theme without overrides: new ini only, image folder stays the same
    local final, mode, note = bake_target(false)
    if not final then set_status("No free name for a copy (nothing baked)") return end
    -- A plain theme without ui_img finds its image folder through the file stem (read_theme); a copy has a new stem,
    -- so point the line at the existing folder, otherwise the copy loads without graphics.
    -- OVERWRITE keeps the stem. If the line cannot be set, the copy is refused.
    if mode ~= "overwrite" and T.assetDir and not ini:find("\nui_img%s*=") then
      ini = set_ui_img(ini, select(2, split_path(T.assetDir)))
      if not ini:find("\nui_img%s*=") then
        set_status("Cannot set the image folder in the copy (nothing baked)")
        return
      end
    end
    -- first write final.tmp and read it back, then swap as with the zip
    local tmp = final .. ".tmp"
    os.remove(tmp)
    if not write_file(tmp, ini) or read_file(tmp) ~= ini then
      os.remove(tmp)
      set_status("Write failed: " .. select(2, split_path(final)) .. " (nothing changed)")
      return
    end
    -- with OVERWRITE ORIGINAL the old version is kept as .bak (the source is already
    -- completely in T.ini); a copy always goes to a free name (place_copy)
    local ok, why, bak
    if mode == "overwrite" then
      ok, why, bak = swap_in(tmp, final, true)
    else
      local placed
      placed, why = place_copy(tmp, final, false)
      ok = placed ~= nil
      if ok then final = placed end
    end
    if not ok then
      -- delete tmp only while the target is still in place (otherwise it is the only new version besides the .bak)
      if mode ~= "overwrite" or file_exists(final) then os.remove(tmp) end
      set_status("Write failed: " .. select(2, split_path(final)) .. " (" .. tostring(why) .. ")")
      return
    end
    finish_bake(final, bak, mode, note)
    return
  end

  -- plain theme with overrides: build a zip from the working folder
  if not S.wcReady then start_prepare(start_bake) return end
  if S.rtcSig ~= ovr_sig(S.ovr) then
    -- check the return value, otherwise a stale rtconfig would be baked
    if not write_file(S.wcFolder .. "/rtconfig.txt", apply_overrides(T.rtc, S.ovr)) then
      S.rtcSig = nil
      set_status("Write failed: working copy rtconfig (nothing baked)")
      return
    end
    S.rtcSig = ovr_sig(S.ovr)
  end
  local inner = sanitize(base_stem(S.orig))
  local items = { { name = inner .. ".ReaperTheme", get = function() return set_ui_img(ini, inner) end } }
  for _, rel in ipairs(list_files_rec(S.wcFolder)) do
    if rel ~= ".tt_ready" then
      items[#items + 1] = { name = inner .. "/" .. rel, get = function()
        return read_file(S.wcFolder .. "/" .. rel)
      end }
    end
  end
  local final, mode, note = bake_target(true)
  if not final then set_status("No free name for a copy (nothing baked)") return end
  start_zip_job(final, items, nil, mode, note)
end

-- BAKE THEME (button and test hook): first the pending preview, then bake.
-- If apply_preview first starts preparing the working copy, a job is running
-- and start_bake() returns immediately -> queue the bake, loop() resumes it after the preparation
local function request_bake()
  S.test = nil
  if S.dirtyAt then apply_preview() end
  if S.job then S.bakePending = true; set_status("Bake queued - preparing the working copy first ...")
  else start_bake() end
end

-- Discard: load the original; the working folder is kept for the next
-- preview (no need to extract again)
local function discard()
  if S.job then return end
  for k, f in pairs(S.base) do S.cur[k] = copy_font(f) end
  S.ovr = {}
  S.dirtyAt, S.test = nil, nil
  if S.wcLoaded then
    if not load_theme(S.orig) then set_status("Could not load original") return end
    S.wcLoaded = false
  end
  set_status("Discarded - original active.")
end

--------------------------------------------------------------------
-- Picker
--------------------------------------------------------------------
-- Ini fonts for areas without a WALTER element
local AREA_FONTS = {
  ruler = { "tl_font" }, timeline = { "tl_font" },
  arrange = { "mi_font" }, item = { "mi_font" },
}

-- WALTER elements for a hit-test name in the given layout: exact
-- ("mcp.fxlist" -> "mcp.fxlist.font"), else sub-elements ("mcp.volume"
-- -> "mcp.volume.label.font"), else shorten the name from the end. If only
-- the section ("mcp") remains, the result is coarse.
local function elems_for(info, master, L)
  local found = {}
  local function try(name)
    if L.idx[name .. ".font"] then found[1] = name .. ".font" return true end
    local pre = name .. "."
    for e in pairs(L.idx) do
      if e:sub(1, #pre) == pre then found[#found + 1] = e end
    end
    table.sort(found)
    return #found > 0
  end
  local name = info
  while name and name ~= "" do
    local coarse = not name:find(".", 1, true)
    if master and try("master." .. name) then return found, coarse end
    if try(name) then return found, coarse end
    name = name:match("^(.+)%.[^%.]+$")
  end
  return found, true
end

local SECTION_OF = { tcp = "tcp", mcp = "mcp", trans = "trans", envcp = "envcp" }

local function pick_at(x, y)
  local r = { info = "", slots = {}, elems = {} }
  local tr, info
  if R.GetThingFromPoint then tr, info = R.GetThingFromPoint(x, y) end
  r.info = tostring(info or "")
  -- REAPER appends extra info ("mcp.fxlist 4 fx:4") -> element name only
  r.elem = r.info:match("^(%S+)") or ""
  local head = r.elem:match("^([%a_]+)") or ""
  if tr then
    r.master = tr == R.GetMasterTrack(0)
    local _, nm = R.GetTrackName(tr)
    r.track = r.master and "MASTER" or nm
  end
  local section = SECTION_OF[head]
  if section and S.W then
    local lname = ""
    if tr and (section == "tcp" or section == "mcp") then
      local _, l = R.GetSetMediaTrackInfo_String(tr, section == "tcp" and "P_TCP_LAYOUT" or "P_MCP_LAYOUT", "", false)
      lname = l or ""
    end
    r.rawLayout = lname
    local sec = (r.master and (section == "tcp" or section == "mcp")) and ("master_" .. section) or section
    local ln = resolve_layout(S.W, sec, lname, S.scale)
    r.layout = ln
    local L = S.W.layout(ln)
    local elems, coarse = elems_for(r.elem, r.master, L)
    r.elems, r.coarse = elems, coarse
    r.computed = {}
    local seen = {}
    -- user-chosen font first
    local ck = S.confirm and S.confirm[r.elem]
    if ck and S.cur[ck] then
      seen[ck] = true
      r.slots[1] = { key = ck, elem = r.elem, confirmed = true }
    end
    for _, e in ipairs(elems) do
      local idx = S.ovr[e] or L.idx[e]
      r.computed[e] = L.idx[e]
      if idx == 0 or idx == -1 then
        r.special = idx == 0 and "theme main font (index 0)" or "volume/pan font (index -1)"
      end
      local key = key_of_idx(idx)
      if key and S.cur[key] and not seen[key] then
        seen[key] = true
        r.slots[#r.slots + 1] = { key = key, elem = e, via = L.var[e], ovr = S.ovr[e] ~= nil }
      end
    end
  else
    local area = head
    if area == "" and R.BR_GetMouseCursorContext then
      area = tostring(R.BR_GetMouseCursorContext() or "")
      r.info = area
    end
    for _, k in ipairs(AREA_FONTS[area] or {}) do
      if S.cur[k] then r.slots[#r.slots + 1] = { key = k } end
    end
  end
  return r
end

-- Lock the target (picker via click/Shift or test hook pickat:<x>,<y>)
local function lock_target(t)
  S.target, S.hover = t, nil
  S.sel = t.slots[1] and t.slots[1].key or S.sel
  local ks = {}
  for _, sl in ipairs(t.slots) do ks[#ks + 1] = sl.key end
  tlog(string.format("pick info='%s' track='%s' P_LAYOUT='%s' -> Layout '%s' elems=%s slots=%s",
    t.info, tostring(t.track), tostring(t.rawLayout), tostring(t.layout),
    table.concat(t.elems, ","), table.concat(ks, ",")))
  set_status("Target: " .. t.info .. (t.track and (" [" .. t.track .. "]") or ""))
end

local function pick_poll()
  if not picker.armed then return end
  local mx, my = R.GetMousePosition()
  if S.guiHovered then S.hover = nil return end
  S.hover = pick_at(mx, my)
  if not R.JS_Mouse_GetState then return end
  local ok, st = pcall(R.JS_Mouse_GetState, 1 | 8)
  if not ok then picker.armed = false set_status("Picker error: " .. tostring(st)) return end
  st = tonumber(st) or 0
  local lmb, shift = (st & 1) ~= 0, (st & 8) ~= 0
  local lock = false
  if lmb then picker.down = true
  elseif picker.down then picker.down = false; lock = true end
  if shift and not picker.shift then lock = true end
  picker.shift = shift
  if lock then
    picker.armed = false
    lock_target(S.hover)
  end
end

--------------------------------------------------------------------
-- Options (script fonts)
--------------------------------------------------------------------
local UI_FONTS = {
  { name = "Liberation Sans", file = "LiberationSans-Regular.ttf", bfile = "LiberationSans-Bold.ttf" },
  { name = "Segoe UI" }, { name = "Arial" }, { name = "Verdana" }, { name = "Tahoma" },
  { name = "Calibri" }, { name = "Inter" },
}
local MONO_FONTS = {
  { name = "Liberation Mono", file = "LiberationMono-Regular.ttf" },
  { name = "Consolas" }, { name = "Cascadia Mono" }, { name = "Courier New" }, { name = "Lucida Console" },
}
local OPT = { ui = "Liberation Sans", size = 14, mono = "Liberation Mono", msize = 13, listH = 230 }

local function load_opts()
  local v = R.GetExtState(NS, "opt_ui"); if v ~= "" then OPT.ui = v end
  v = R.GetExtState(NS, "opt_mono"); if v ~= "" then OPT.mono = v end
  OPT.size = tonumber(R.GetExtState(NS, "opt_size")) or OPT.size
  OPT.msize = tonumber(R.GetExtState(NS, "opt_msize")) or OPT.msize
  OPT.listH = tonumber(R.GetExtState(NS, "opt_listh")) or OPT.listH
end

local function save_opts()
  R.SetExtState(NS, "opt_ui", OPT.ui, true)
  R.SetExtState(NS, "opt_mono", OPT.mono, true)
  R.SetExtState(NS, "opt_size", tostring(OPT.size), true)
  R.SetExtState(NS, "opt_msize", tostring(OPT.msize), true)
  R.SetExtState(NS, "opt_listh", tostring(math.floor(OPT.listH + 0.5)), true)
end

--------------------------------------------------------------------
-- User interface (in its own function: Lua allows at most
-- 200 local variables per function, with the kit layer there would be more)
--------------------------------------------------------------------
local function run_gui()

--------------------------------------------------------------------
-- View: UI SIZE (zoom), AUTO FIT, TOOLTIPS
-- Zoom, AUTO FIT and TOOLTIPS are stored per REAPER installation in ExtState
-- (ui_zoom / ui_autofit / ui_tips, same namespace NS).
-- AUTO FIT as in the plugins: when
-- the window size changes, the zoom is set to the largest whole percentage
-- at which the design grid DES_W x DES_H fits in the window
-- (25..400 %). The first frame only records the window size; the
-- zoom buttons hold until the next window change.
--------------------------------------------------------------------
local DES_W, DES_H = 800, 820           -- design grid at 100 % (= start size of the window)
local ZOOM_MIN, ZOOM_MAX = 0.25, 4.0
local ZOOM_STEPS = { 1.0, 1.25, 1.5, 2.0, 3.0 }
local VIEW = { zoom = 1.0, autofit = true, tips = true, lastW = nil, lastH = nil }
-- Test hooks for the screenshot rig and the dry run:
-- only active while the unsaved ExtState test_ok = 20261001 is set.
local TEST = { on = false, dump = nil, size = nil, rects = {}, state = nil }
local UI = { openOpts = nil, ovrOpen = false, optsRect = nil }

local function clampz(z)
  if z ~= z or not z then return 1.0 end
  if z < ZOOM_MIN then return ZOOM_MIN elseif z > ZOOM_MAX then return ZOOM_MAX end
  return z
end

local function fit_zoom(w, h)
  return clampz(math.floor(math.min(w / DES_W, h / DES_H) * 100 + 0.0001) / 100)
end

local function load_view()
  local z = tonumber(R.GetExtState(NS, "ui_zoom"))
  if z then VIEW.zoom = clampz(z) end
  VIEW.autofit = R.GetExtState(NS, "ui_autofit") ~= "0"
  VIEW.tips = R.GetExtState(NS, "ui_tips") ~= "0"
end

local function set_zoom(z, persist)
  VIEW.zoom = clampz(math.floor(z * 100 + 0.5) / 100)
  if persist then R.SetExtState(NS, "ui_zoom", string.format("%.2f", VIEW.zoom), true) end
end

local function set_autofit(on, persist)
  VIEW.autofit = on
  if persist then R.SetExtState(NS, "ui_autofit", on and "1" or "0", true) end
  -- switching on adjusts once immediately
  if on and VIEW.lastW then set_zoom(fit_zoom(VIEW.lastW, VIEW.lastH), persist) end
end

local function set_tips(on, persist)
  VIEW.tips = on
  if persist then R.SetExtState(NS, "ui_tips", on and "1" or "0", true) end
end

-- Track the window size: the first frame only records it (the saved zoom
-- stays), every later change adjusts the zoom if AUTO FIT is on.
local function track_window(w, h)
  if not VIEW.lastW then VIEW.lastW, VIEW.lastH = w, h return end
  if math.abs(w - VIEW.lastW) < 1 and math.abs(h - VIEW.lastH) < 1 then return end
  VIEW.lastW, VIEW.lastH = w, h
  if VIEW.autofit then
    local z = fit_zoom(w, h)
    -- saved only after the mouse is released (save_view_pending), not at every intermediate size
    if z ~= VIEW.zoom then set_zoom(z, false); VIEW.zsave = not TEST.on end
  end
end

local function save_view_pending(mouseDown)
  if VIEW.zsave and not mouseDown then
    VIEW.zsave = false
    R.SetExtState(NS, "ui_zoom", string.format("%.2f", VIEW.zoom), true)
  end
end

--------------------------------------------------------------------
-- Brand design (in the look of the TT UI kit 7)
--------------------------------------------------------------------
local ctx
local BLACK, WHITE, ACID = 0x000000FF, 0xFFFFFFFF, 0x39FF14FF
local function acid_a(a) return 0x39FF1400 | math.floor(a * 255 + 0.5) end
local GREY = 0x8C8C8CFF
local INKC = 0xD6E2D6FF
local BGC = 0x0D0E0DFF
local FONTS = { ui = {}, bold = {}, mono = {} }

local function font_file(name)
  if not name then return nil end
  for _, d in ipairs({
    (os.getenv("LOCALAPPDATA") or "") .. "\\Microsoft\\Windows\\Fonts\\",
    (os.getenv("WINDIR") or "C:\\Windows") .. "\\Fonts\\",
  }) do
    if file_exists(d .. name) then return d .. name end
  end
end

-- Load the font file directly if present: when a font is missing, GDI
-- silently substitutes another one - the tables need real monospace widths.
local function make_font(file, family, fallback, flags)
  local p = font_file(file)
  local ok, f
  if p and R.ImGui_CreateFontFromFile then
    ok, f = pcall(R.ImGui_CreateFontFromFile, p, 0)
    if ok and f then return f end
  end
  if family then
    ok, f = pcall(R.ImGui_CreateFont, family, flags)
    if ok and f and not file then return f end
  end
  if not fallback then return nil end
  ok, f = pcall(R.ImGui_CreateFont, fallback, flags)
  if ok then return f end
end

local function init_fonts()
  local bold = R.ImGui_FontFlags_Bold and R.ImGui_FontFlags_Bold() or nil
  for _, u in ipairs(UI_FONTS) do
    FONTS.ui[u.name] = make_font(u.file, u.name, "sans-serif", nil)
    FONTS.bold[u.name] = make_font(u.bfile, u.name, "sans-serif", bold)
  end
  for _, m in ipairs(MONO_FONTS) do
    FONTS.mono[m.name] = make_font(m.file, m.name, "monospace", nil)
  end
  -- Kit font (labels of the drawn front): Inter Medium,
  -- otherwise Liberation Sans
  FONTS.kit = make_font("Inter-Medium.ttf", nil, nil, nil)
  local kitOwn = FONTS.kit ~= nil
  if not kitOwn then FONTS.kit = FONTS.ui["Liberation Sans"] end
  for _, grp in ipairs({ FONTS.ui, FONTS.bold, FONTS.mono }) do
    for _, f in pairs(grp) do R.ImGui_Attach(ctx, f) end
  end
  if kitOwn then R.ImGui_Attach(ctx, FONTS.kit) end
end

local function pushf(f, size)
  if f then R.ImGui_PushFont(ctx, f, size) return true end
  return false
end
local function popf(p) if p then R.ImGui_PopFont(ctx) end end
local function push_mono(d) return pushf(FONTS.mono[OPT.mono], (OPT.msize + (d or 0)) * VIEW.zoom) end
local function push_bold(d) return pushf(FONTS.bold[OPT.ui], (OPT.size + (d or 0)) * VIEW.zoom) end

-- Tooltips (English, one sentence): appear after hovering for 0.35 s,
-- not while dragging; OPTIONS > TOOLTIPS OFF switches them all off.
local HOVER = { id = nil, t = 0 }
local function show_tip(text)
  if R.ImGui_BeginTooltip(ctx) then
    R.ImGui_PushTextWrapPos(ctx, 420 * VIEW.zoom)
    R.ImGui_Text(ctx, text)
    R.ImGui_PopTextWrapPos(ctx)
    R.ImGui_EndTooltip(ctx)
  end
end

local function tip_hover(id, text, hovered)
  if not VIEW.tips or not text then return end
  if hovered and not R.ImGui_IsMouseDown(ctx, 0) then
    local now = R.time_precise()
    if HOVER.id ~= id then HOVER.id = id; HOVER.t = now end
    if now - HOVER.t > 0.35 then show_tip(text) end
  elseif HOVER.id == id then
    HOVER.id = nil
  end
end

-- Tooltip for the most recently drawn ImGui item
local HOV_DIS = R.ImGui_HoveredFlags_AllowWhenDisabled and R.ImGui_HoveredFlags_AllowWhenDisabled() or 0
local function tip(text)
  local x, y = R.ImGui_GetItemRectMin(ctx)
  tip_hover(text .. "@" .. math.floor(x or 0) .. "," .. math.floor(y or 0), text, R.ImGui_IsItemHovered(ctx, HOV_DIS))
end

local THEME_COLS = {
  { "WindowBg", BGC }, { "ChildBg", 0x00000000 }, { "PopupBg", 0x121412FF },
  { "Text", INKC }, { "TextDisabled", GREY },
  { "Border", acid_a(0.35) }, { "BorderShadow", 0x00000000 },
  { "TitleBg", BGC }, { "TitleBgActive", 0x121412FF }, { "TitleBgCollapsed", BGC },
  { "FrameBg", 0x1B1C1BFF }, { "FrameBgHovered", acid_a(0.18) }, { "FrameBgActive", acid_a(0.30) },
  { "Button", 0x1B1C1BFF }, { "ButtonHovered", acid_a(0.25) }, { "ButtonActive", acid_a(0.50) },
  { "Header", acid_a(0.18) }, { "HeaderHovered", acid_a(0.30) }, { "HeaderActive", acid_a(0.45) },
  { "SliderGrab", ACID }, { "SliderGrabActive", WHITE }, { "CheckMark", ACID },
  { "Separator", acid_a(0.30) }, { "SeparatorHovered", ACID }, { "SeparatorActive", ACID },
  { "TableHeaderBg", 0x161816FF }, { "TableBorderStrong", acid_a(0.30) },
  { "TableBorderLight", 0x262826FF }, { "TableRowBg", 0x00000000 }, { "TableRowBgAlt", 0xFFFFFF08 },
  { "ScrollbarBg", 0x0A0B0AFF }, { "ScrollbarGrab", 0x2A2C2AFF },
  { "ScrollbarGrabHovered", acid_a(0.5) }, { "ScrollbarGrabActive", ACID },
  { "ResizeGrip", acid_a(0.25) }, { "ResizeGripHovered", acid_a(0.6) }, { "ResizeGripActive", ACID },
  { "PlotHistogram", ACID }, { "TextSelectedBg", acid_a(0.35) }, { "NavCursor", ACID },
}
local THEME_VARS = {
  { "WindowRounding", 0 }, { "FrameRounding", 2 }, { "TabRounding", 0 }, { "ChildRounding", 0 },
  { "GrabRounding", 2 }, { "ScrollbarRounding", 0 }, { "PopupRounding", 0 },
  { "WindowBorderSize", 1 }, { "FrameBorderSize", 1 }, { "PopupBorderSize", 1 },
}
-- Spacing grows with the zoom (value at 100 %)
local THEME_VARS_Z = {
  { "FramePadding", 4, 3 }, { "ItemSpacing", 8, 4 }, { "ItemInnerSpacing", 4, 4 },
  { "CellPadding", 4, 2 }, { "WindowPadding", 8, 8 },
  { "ScrollbarSize", 14 }, { "GrabMinSize", 10 }, { "IndentSpacing", 21 },
}

local function push_theme(z)
  local nc, nv = 0, 0
  for _, c in ipairs(THEME_COLS) do
    local fn = R["ImGui_Col_" .. c[1]]
    if fn then R.ImGui_PushStyleColor(ctx, fn(), c[2]); nc = nc + 1 end
  end
  for _, v in ipairs(THEME_VARS) do
    local fn = R["ImGui_StyleVar_" .. v[1]]
    if fn then R.ImGui_PushStyleVar(ctx, fn(), v[2]); nv = nv + 1 end
  end
  for _, v in ipairs(THEME_VARS_Z) do
    local fn = R["ImGui_StyleVar_" .. v[1]]
    if fn then
      if v[3] then R.ImGui_PushStyleVar(ctx, fn(), v[2] * z, v[3] * z)
      else R.ImGui_PushStyleVar(ctx, fn(), v[2] * z) end
      nv = nv + 1
    end
  end
  return nc, nv
end

--------------------------------------------------------------------
-- UI kit 7 look (ReaImGui port)
-- Copy of the TimTechlor UI kit 7 layer.
--
-- Changes compared to the original: origin per row/section via
-- kit_at() (the front here is a flow layout with a scroll area, not a fixed
-- grid), scale = VIEW.zoom, accent fixed to Acid Green, btn() with a
-- disabled state, tooltip switch VIEW.tips; knob() is dropped.
--------------------------------------------------------------------
local floor = math.floor
local UK = { sc = 1, ox = 0, oy = 0, dl = nil, ar = 0.2235, ag = 1.0, ab = 0.0784,
             mx = 0, my = 0, mxd = 0, myd = 0, shift = false, ctrl = false }
local DRAGS = {}

local function f255(v) if v < 0 then v = 0 elseif v > 1 then v = 1 end return floor(v * 255 + 0.5) end
local function C(r, g, b, a) return (f255(r) << 24) | (f255(g) << 16) | (f255(b) << 8) | f255(a or 1) end
local function acid(a) return C(UK.ar, UK.ag, UK.ab, a) end
local function dimc(a) return C(UK.ar * 0.58, UK.ag * 0.57, UK.ab * 0.55, a) end
local function tone(g, t, a) return C(g + (UK.ar - g) * t, g + (UK.ag - g) * t, g + (UK.ab - g) * t, a) end
local INK = { 0.75, 0.81, 0.75 }
local AMBER = { 1.0, 0.70, 0.36 }

local function X(x) return UK.ox + x * UK.sc end
local function Y(y) return UK.oy + y * UK.sc end
local function Z(v) return v * UK.sc end
local function lw() local w = floor(UK.sc + 0.5); return w < 1 and 1 or w end

-- Set the origin of the kit drawing (screen point = design point 0,0)
local function kit_at(dl, ox, oy)
  UK.dl, UK.ox, UK.oy, UK.sc = dl, ox, oy, VIEW.zoom
  UK.mxd = (UK.mx - ox) / UK.sc
  UK.myd = (UK.my - oy) / UK.sc
end

-- ---- Text (pixel size = design size * scale, rounded to an integer)
local TWC = {}
local function tw(s, size)
  size = size or 13
  local k = size .. "|" .. s
  local v = TWC[k]
  if not v then
    R.ImGui_PushFont(ctx, FONTS.kit, size)
    v = R.ImGui_CalcTextSize(ctx, s)
    R.ImGui_PopFont(ctx)
    TWC[k] = v
  end
  return v
end
local function ptext(x, y, s, colr, size)
  size = size or 13
  local px_ = floor(size * UK.sc + 0.5)
  if px_ < 8 then px_ = 8 end
  R.ImGui_PushFont(ctx, FONTS.kit, px_)
  R.ImGui_DrawList_AddText(UK.dl, X(x), Y(y), colr, s)
  R.ImGui_PopFont(ctx)
end
local function ptext_c(cx, y, s, colr, size) ptext(cx - tw(s, size) / 2, y, s, colr, size) end
local function ptext_r(rx, y, s, colr, size) ptext(rx - tw(s, size), y, s, colr, size) end
local function spaced(x, y, s, colr, size, sp)
  for ch in s:gmatch(".") do
    ptext(x, y, ch, colr, size)
    x = x + tw(ch, size) + sp
  end
  return x
end
-- Shorten text to a width (design units), with "..."
local function fit_text(s, size, maxw)
  if maxw <= 0 then return "" end
  if tw(s, size) <= maxw then return s end
  local n = #s
  while n > 1 and tw(s:sub(1, n) .. "...", size) > maxw do n = n - 1 end
  return s:sub(1, n) .. "..."
end

-- ---- Primitives
local function rfill(x, y, w, h, colr, r)
  R.ImGui_DrawList_AddRectFilled(UK.dl, X(x), Y(y), X(x + w), Y(y + h), colr, Z(r or 0))
end
local function rline(x, y, w, h, colr, r)
  local o = lw() * 0.5
  R.ImGui_DrawList_AddRect(UK.dl, X(x) + o, Y(y) + o, X(x + w) - o, Y(y + h) - o, colr, Z(r or 0), 0, lw())
end
local function circ(cx, cy, r, colr) R.ImGui_DrawList_AddCircleFilled(UK.dl, X(cx), Y(cy), Z(r), colr, 0) end
local function circ_line(cx, cy, r, colr, th) R.ImGui_DrawList_AddCircle(UK.dl, X(cx), Y(cy), Z(r), colr, 0, th or lw()) end
local function line(x1, y1, x2, y2, colr, th) R.ImGui_DrawList_AddLine(UK.dl, X(x1), Y(y1), X(x2), Y(y2), colr, th or lw()) end
-- vertical gradient, also with rounded corners (bands with a clip rectangle)
local function grad(x, y, w, h, r1, g1, b1, r2, g2, b2, rad, a)
  if (rad or 0) == 0 then
    local c1, c2 = C(r1, g1, b1, a), C(r2, g2, b2, a)
    R.ImGui_DrawList_AddRectFilledMultiColor(UK.dl, X(x), Y(y), X(x + w), Y(y + h), c1, c1, c2, c2)
    return
  end
  local n = floor(h * UK.sc / 4)
  if n < 2 then n = 2 elseif n > 12 then n = 12 end
  for k = 0, n - 1 do
    local f = (k + 0.5) / n
    local colr = C(r1 + (r2 - r1) * f, g1 + (g2 - g1) * f, b1 + (b2 - b1) * f, a)
    R.ImGui_DrawList_PushClipRect(UK.dl, X(x) - 2, Y(y + h * k / n), X(x + w) + 2, Y(y + h * (k + 1) / n) + 0.5, true)
    R.ImGui_DrawList_AddRectFilled(UK.dl, X(x), Y(y), X(x + w), Y(y + h), colr, Z(rad))
    R.ImGui_DrawList_PopClipRect(UK.dl)
  end
end
-- Circuit trace with a 45-degree bend, ends in a solder pad
local function trace(pts, colr)
  for i = 1, #pts - 1 do line(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], colr, Z(1.2)) end
  local e = pts[#pts]
  circ_line(e[1], e[2], 4.4, acid(0.45), Z(1))
  circ(e[1], e[2], 2.6, acid(1))
end

-- ---- Input
local function hit(id, x, y, w, h)
  R.ImGui_SetCursorScreenPos(ctx, X(x), Y(y))
  R.ImGui_InvisibleButton(ctx, id, math.max(1, Z(w)), math.max(1, Z(h)))
  -- test hook: position of every control for the screenshot rig (mouse for hover/tooltip images)
  if TEST.on then TEST.rects[id] = { X(x), Y(y), X(x + w), Y(y + h) } end
  return R.ImGui_IsItemHovered(ctx), R.ImGui_IsItemActive(ctx)
end
local function tipfor(id, s) tip_hover(id, s, R.ImGui_IsItemHovered(ctx)) end
-- Dragging: ax "x" (slider, span = width); Shift = fine, wheel 2 %, reset via right/double/Ctrl click
local function drag_ctl(id, hov, act, val, mn, mx, def, ax, span, spanfine)
  local nv = val
  local pos = (ax == "x") and UK.mxd or UK.myd
  if R.ImGui_IsItemActivated(ctx) then
    if UK.ctrl then nv = def; DRAGS[id] = nil
    else DRAGS[id] = { p = pos, v = val, sh = UK.shift } end
  end
  if hov and R.ImGui_IsMouseDoubleClicked(ctx, 0) then nv = def; DRAGS[id] = nil end
  if R.ImGui_IsItemClicked(ctx, 1) then nv = def end
  local d = DRAGS[id]
  if act and d then
    if UK.shift ~= d.sh then d.sh = UK.shift; d.p = pos; d.v = val end
    local delta = (ax == "x") and (pos - d.p) or (d.p - pos)
    nv = d.v + delta * (mx - mn) / (d.sh and spanfine or span)
  elseif not act then
    DRAGS[id] = nil
  end
  if hov then
    local wv = R.ImGui_GetMouseWheel(ctx)
    if wv ~= 0 then nv = val + wv * (mx - mn) * 0.02 end
  end
  if nv < mn then nv = mn elseif nv > mx then nv = mx end
  return nv
end

-- ---- Widgets
local function panel(x, y, w, h, title)
  for j = 0, 5 do
    local e = 6 - j
    R.ImGui_DrawList_AddRect(UK.dl, X(x) - Z(e), Y(y) - Z(e) + Z(3), X(x + w) + Z(e), Y(y + h) + Z(e) + Z(3),
      C(0, 0, 0, 0.03 + 0.012 * j), Z(4 + e), 0, 1)
  end
  rfill(x, y, w, h, tone(0.11, 0.10), 4)
  grad(x + 1.5, y + 1.5, w - 3, h - 3, 0.090, 0.096, 0.090, 0.060, 0.064, 0.060, 3)
  rfill(x + 3, y + 1, w - 6, 1, C(1, 1, 1, 0.07))
  rfill(x + 3, y + h - 2, w - 6, 1, C(0, 0, 0, 0.35))
  rline(x, y, w, h, C(0, 0, 0, 0.5), 4)
  ptext(x + 12, y + 3, title, C(0.88, 0.98, 0.86, 1), 14)
  rfill(x + 10, y + 21, w - 20, 1, dimc(0.55))
  rfill(x + 10, y + 21, 26, 1, acid(0.85))
end

local function led(cx, cy, r, on, colr)
  if on then
    circ(cx, cy, r + 2.2, colr and C(colr[1], colr[2], colr[3], 0.25) or acid(0.25))
    circ(cx, cy, r, colr and C(colr[1], colr[2], colr[3], 1) or acid(1))
    circ(cx - r * 0.3, cy - r * 0.3, r * 0.35, C(1, 1, 1, 0.5))
  else
    circ(cx, cy, r, tone(0.17, 0.06))
  end
end

-- dis = disabled (gray, no click; tooltip stays)
local function btn(id, x, y, w, h, label, on, prim, tiptxt, dis)
  local hov, act = hit(id, x, y, w, h)
  local clicked = (not dis) and R.ImGui_IsItemActivated(ctx)
  if dis then
    rfill(x, y, w, h, C(0.075, 0.078, 0.075))
    rline(x, y, w, h, tone(0.13, 0.05), 0)
    ptext_c(x + w / 2, y + (h - 13) / 2 - 1, label, C(0.36, 0.39, 0.36))
  elseif on then
    rfill(x, y, w, h, acid(0.88))
    ptext_c(x + w / 2, y + (h - 13) / 2 - 1, label, C(0, 0, 0, 1))
  else
    rfill(x, y, w, h, C(0.098, 0.103, 0.098))
    local bc = hov and tone(0.37, 0.35) or (prim and acid(0.55) or tone(0.16, 0.12))
    rline(x, y, w, h, bc, 0)
    local tc = hov and C(0.85, 0.95, 0.82) or (prim and acid(1) or C(0.78, 0.84, 0.76))
    ptext_c(x + w / 2, y + (h - 13) / 2 - 1, label, tc)
    if act then rfill(x + 1, y + 1, w - 2, h - 2, C(1, 1, 1, 0.05)) end
  end
  tipfor(id, tiptxt)
  return clicked
end

local function toggle(id, x, y, w, h, on, label, tiptxt)
  local hov = hit(id, x, y, w, h)
  local clicked = R.ImGui_IsItemActivated(ctx)
  rfill(x, y + 1.2, w, h, C(0, 0, 0, 0.35), 3)
  if on then
    grad(x, y, w, h, 0.150, 0.170, 0.145, 0.085, 0.100, 0.082, 3)
    rline(x, y, w, h, acid(0.75), 3)
  else
    if hov then grad(x, y, w, h, 0.135, 0.142, 0.135, 0.075, 0.080, 0.075, 3)
    else grad(x, y, w, h, 0.115, 0.120, 0.115, 0.062, 0.066, 0.062, 3) end
    rline(x, y, w, h, hov and tone(0.37, 0.35) or tone(0.16, 0.12), 3)
  end
  rfill(x + 2, y + 1, w - 4, 1, C(1, 1, 1, 0.06))
  led(x + h * 0.5, y + h * 0.5, math.min(3.2, h * 0.17), on)
  local tc = on and C(0.96, 0.98, 0.96) or (hov and C(0.85, 0.95, 0.82) or C(0.72, 0.78, 0.70))
  ptext(x + h * 0.95, y + (h - 13) / 2 - 1, label, tc)
  tipfor(id, tiptxt)
  return clicked
end

local function hslider(id, x, y, w, h, val, mn, mx, def, tiptxt)
  local hov, act = hit(id, x - 6, y - 3, w + 12, h + 6)
  local nv = drag_ctl(id, hov, act, val, mn, mx, def, "x", w, w * 6)
  local t = (nv - mn) / (mx - mn)
  local ty = y + h * 0.5 - 2
  rfill(x - 1, ty - 1, w + 2, 6, C(0, 0, 0, 0.5), 3)
  rfill(x, ty, w, 4, C(0.035, 0.038, 0.035), 2)
  if t > 0.004 then rfill(x, ty, math.max(4, w * t), 4, acid(0.95), 2) end
  local hx = x + t * w
  rfill(hx - 4.5, y + 1.5, 10, h, C(0, 0, 0, 0.45), 3)
  if hov or act then grad(hx - 5, y, 10, h, 0.36, 0.38, 0.36, 0.20, 0.21, 0.20, 2)
  else grad(hx - 5, y, 10, h, 0.28, 0.30, 0.28, 0.15, 0.16, 0.15, 2) end
  rfill(hx - 4, y, 8, 1, C(1, 1, 1, 0.22))
  rfill(hx - 0.5, y + 2, 1, h - 4, acid(1))
  tipfor(id, tiptxt)
  return nv
end
-- End of the kit layer ----------------------------------------------

-- Window background: dark gradient with darkened edges
local function ground(dl, ox, oy, cw, ch)
  local top, bot = C(0.068, 0.073, 0.068), C(0.038, 0.041, 0.038)
  R.ImGui_DrawList_AddRectFilledMultiColor(dl, ox, oy, ox + cw, oy + ch, top, top, bot, bot)
  local bw = math.max(24, math.min(cw, ch) * 0.06)
  local k, zc = C(0, 0, 0, 0.30), C(0, 0, 0, 0)
  R.ImGui_DrawList_AddRectFilledMultiColor(dl, ox, oy, ox + cw, oy + bw, k, k, zc, zc)
  R.ImGui_DrawList_AddRectFilledMultiColor(dl, ox, oy + ch - bw, ox + cw, oy + ch, zc, zc, k, k)
end

-- Rectangles for the screenshot rig (ImGui screen coordinates)
local function rect(name, x0, y0, x1, y1)
  if TEST.on then TEST.rects[name] = { x0, y0, x1, y1 } end
end

-- Width for content inside a panel (right panel edge)
local function inner_w() return math.max(40, R.ImGui_GetContentRegionAvail(ctx) - 12 * VIEW.zoom) end

-- Kit row in the flow layout: draws fn(width in design units) from the
-- cursor and then occupies h design units of height
local function kit_row(h, fn)
  local z = VIEW.zoom
  local sx, sy = R.ImGui_GetCursorScreenPos(ctx)
  local wd = inner_w() / z
  kit_at(R.ImGui_GetWindowDrawList(ctx), sx, sy)
  fn(wd)
  R.ImGui_SetCursorScreenPos(ctx, sx, sy)
  R.ImGui_Dummy(ctx, wd * z, h * z)
end

-- Section as a kit panel. The panel sits behind the content and is drawn before
-- it; its height comes from the previous frame (SECH).
local SECH = {}
local function sec_begin(id, title, extra)
  local z = VIEW.zoom
  R.ImGui_Dummy(ctx, 1, 2 * z)
  local sx, sy = R.ImGui_GetCursorScreenPos(ctx)
  local w = inner_w()
  local dl = R.ImGui_GetWindowDrawList(ctx)
  kit_at(dl, sx, sy)
  panel(0, 0, w / z, (SECH[id] or 30 * z) / z, title)
  if extra then extra(w / z) end
  R.ImGui_SetCursorScreenPos(ctx, sx, sy)
  R.ImGui_Dummy(ctx, w, 26 * z)
  R.ImGui_Indent(ctx, 12 * z)
  local wx = R.ImGui_GetWindowPos(ctx)
  R.ImGui_PushTextWrapPos(ctx, sx + w - 12 * z - wx)
  return { id = id, sx = sx, sy = sy, w = w }
end

local function sec_end(s)
  local z = VIEW.zoom
  R.ImGui_PopTextWrapPos(ctx)
  R.ImGui_Unindent(ctx, 12 * z)
  R.ImGui_Dummy(ctx, 1, 6 * z)
  local _, ey = R.ImGui_GetCursorScreenPos(ctx)
  local h = math.max(30 * z, ey - s.sy - 4 * z)
  SECH[s.id] = h
  rect("sec_" .. s.id, s.sx - 6 * z, s.sy - 4 * z, s.sx + s.w + 6 * z, s.sy + h + 8 * z)
  R.ImGui_Dummy(ctx, 1, 4 * z)
end

--------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------
local WIN_TITLE = "TT-THEMEFONTEDITOR"   -- new title = new window ID: the window starts once at 800 x 820
local HEAD_H, TOOL_H, FOOT_H, JOB_H = 50, 66, 102, 20   -- FOOT_H includes the BAKE TO row
local MIN_WD, MIN_BODY = 480, 120   -- smallest design area, below that scrollbars appear

local function font_line(key)
  local f = S.cur[key]
  local changed = S.base[key] and not font_same(f, S.base[key])
  return string.format("%-24s %3d px  ~%2d pt  %s%s%s", font_label(key), px(f), pt(f), f.face,
    f.weight >= 600 and " bold" or "", changed and "  *" or "")
end

-- Identification test on/off (preview only)
local function test_toggle(key)
  S.test = (S.test ~= key) and key or nil
  touch()
end

local TIP_TEST_ON = "End the test and show this font at its normal size again."
local TIP_TEST = "Show this font twice as large and bold in the preview to see where REAPER uses it."

local function test_button(key, id)
  if R.ImGui_SmallButton(ctx, (S.test == key and "TEST OFF" or "  TEST  ") .. "##" .. id) then test_toggle(key) end
  tip(S.test == key and TIP_TEST_ON or TIP_TEST)
end

-- Combo box with all fonts; returns the chosen key
local function font_combo(id, current, allowNone, noneLabel)
  local preview = current and font_label(current) or (noneLabel or "-")
  local chosen
  if R.ImGui_BeginCombo(ctx, id, preview, R.ImGui_ComboFlags_HeightLarge()) then
    if allowNone and R.ImGui_Selectable(ctx, noneLabel or "-", current == nil) then chosen = false end
    for _, k in ipairs(S.order) do
      local lbl = string.format("%-24s %3d px", font_label(k), px(S.cur[k]))
      if R.ImGui_Selectable(ctx, lbl .. "##" .. id .. k, current == k) then chosen = k end
    end
    R.ImGui_EndCombo(ctx)
  end
  return chosen
end

-- Element override choice: "(as theme)" or a WALTER font
local function ovr_combo(elem, id, width)
  local curIdx = S.ovr[elem]
  R.ImGui_SetNextItemWidth(ctx, width or 170 * VIEW.zoom)
  local k = font_combo("##ov" .. id, key_of_idx(curIdx), true, "(as theme)")
  if k == false then set_override(elem, nil)
  elseif k then
    local idx = idx_of_key(k)
    if idx then set_override(elem, idx) else set_status("Only WALTER fonts can be assigned to elements") end
  end
end

-- Edit block for one font: -/+, slider, bold/italic, test, reset (kit row)
local function draw_edit(key)
  local f = S.cur[key]; if not f then return end
  local b = S.base[key]
  local s = sec_begin("edit", "EDIT")
  local pb = push_bold(2)
  R.ImGui_TextColored(ctx, ACID, font_label(key))
  popf(pb)
  R.ImGui_SameLine(ctx)
  R.ImGui_TextDisabled(ctx, f.face .. "   (original " .. px(b) .. " px)")

  local wide = (inner_w() / VIEW.zoom) >= 700
  kit_row(wide and 32 or 64, function(wd)
    if btn("k_minus", 0, 2, 26, 26, "-", false, false, "Make this font 1 pixel smaller.") then
      set_font(key, function(x) x.height = with_px(x, px(x) - 1) end)
    end
    -- the slider shows 6..48 px but changes the font only when it is
    -- operated. Larger/smaller theme values (e.g. 64 px) stay unchanged on selection and after RESET.
    local shown = math.max(6, math.min(48, px(f)))
    local nv = hslider("k_size", 40, 4, 200, 22, shown, 6, 48, math.max(6, math.min(48, px(b))),
      "Drag to set the font size from 6 to 48 pixels (Shift = fine, double-click or right-click = original size); the preview reloads when you release the mouse.")
    local np = floor(nv + 0.5)
    if np ~= shown then set_font(key, function(x) x.height = with_px(x, np) end) end
    if btn("k_plus", 254, 2, 26, 26, "+", false, false, "Make this font 1 pixel larger.") then
      set_font(key, function(x) x.height = with_px(x, px(x) + 1) end)
    end
    ptext(290, 8, px(f) .. " px", acid(1), 13)
    ptext(338, 9, string.format("~%d pt", pt(f)), C(0.55, 0.60, 0.55), 12)
    local x0, y0 = 390, 2
    if not wide then x0, y0 = 0, 34 end
    if toggle("k_bold", x0, y0, 70, 26, f.weight >= 600, "BOLD", "Switch the font weight between bold and regular.") then
      set_font(key, function(x) x.weight = (x.weight >= 600) and 400 or 700 end)
    end
    if toggle("k_italic", x0 + 78, y0, 78, 26, f.italic, "ITALIC", "Switch the italic style of this font on or off.") then
      set_font(key, function(x) x.italic = not x.italic end)
    end
    if btn("k_test", x0 + 164, y0, 76, 26, S.test == key and "TEST OFF" or "TEST", S.test == key, false,
        S.test == key and TIP_TEST_ON or TIP_TEST) then
      test_toggle(key)
    end
    local same = font_same(f, b)
    if btn("k_reset", x0 + 248, y0, 66, 26, "RESET", false, false,
        "Reset this font to the value of the original theme.", same) then
      S.cur[key] = copy_font(b); touch()
    end
  end)

  local users = usage_of(key)
  if #users > 0 then
    local all = table.concat(users, ", ")
    R.ImGui_TextDisabled(ctx, "used by " .. #users .. " element" .. (#users == 1 and "" or "s") .. ": "
      .. all:sub(1, 150) .. (#all > 150 and " ..." or ""))
    tip("Elements of the default layout that use this font: " .. table.concat(users, ", ") .. ".")
  end
  sec_end(s)
end

local function draw_target()
  local t = S.target
  local s = sec_begin("target", "TARGET")
  local pm = push_mono()
  R.ImGui_Text(ctx, (t.info ~= "" and t.info or "?") .. (t.track and ("   Track: " .. t.track) or "")
    .. (t.layout and ("   Layout: " .. (t.layout ~= "" and t.layout or "default")) or ""))
  popf(pm)
  if t.special then
    R.ImGui_TextDisabled(ctx, "Note: part of this element uses the " .. t.special .. ".")
  end
  local ck = (t.elem and t.elem ~= "") and t.elem or t.info

  -- responsible font: computed or chosen by the user
  R.ImGui_AlignTextToFramePadding(ctx)
  R.ImGui_Text(ctx, "Responsible font:")
  R.ImGui_SameLine(ctx)
  R.ImGui_SetNextItemWidth(ctx, 220 * VIEW.zoom)
  local cur = S.confirm[ck] or (t.slots[1] and t.slots[1].key)
  local k = font_combo("##resp", cur, true, "(automatic)")
  if k ~= nil then
    S.confirm[ck] = k or nil
    save_confirm()
    if k then S.sel = k end
    -- rebuild the list: chosen font on top
    local slots = {}
    if k then slots[1] = { key = k, elem = ck, confirmed = true } end
    for _, sl in ipairs(t.slots) do
      if not sl.confirmed and sl.key ~= k then slots[#slots + 1] = sl end
    end
    t.slots = slots
    set_status(k and (ck .. " -> " .. font_label(k) .. " remembered") or (ck .. ": automatic again"))
  end
  tip("Choose the font that really controls this spot if the detection is off; the choice is remembered for this theme.")
  if cur then
    R.ImGui_SameLine(ctx)
    test_button(cur, "resp")
  end

  if #t.slots == 0 then
    R.ImGui_TextWrapped(ctx, "The theme sets no font of its own here. Point more precisely at the text"
      .. " or choose the font above or in the list below.")
  else
    if t.coarse then
      R.ImGui_TextColored(ctx, ACID, "Coarse: REAPER only reports the area here - check the candidates with TEST.")
    end
    local availW = inner_w()
    for i, sl in ipairs(t.slots) do
      local f = S.cur[sl.key]
      local pm2 = push_mono()
      local label = string.format("%s%-15s %3d px  %s%s##t%d",
        sl.confirmed and "OK " or (sl.ovr and "EL " or "   "),
        font_label(sl.key), px(f), sl.elem or "", sl.via and (" = " .. sl.via) or "", i)
      if R.ImGui_Selectable(ctx, label, S.sel == sl.key, R.ImGui_SelectableFlags_AllowOverlap(),
          math.max(100, availW - 90 * VIEW.zoom), 0) then
        S.sel = sl.key
      end
      popf(pm2)
      tip(sl.confirmed and "Font chosen by you; click to edit it."
        or sl.ovr and "Font assigned by an element override; click to edit it."
        or "Font computed from the rtconfig; click to edit it.")
      R.ImGui_SameLine(ctx)
      test_button(sl.key, "tt" .. i)
    end
  end

  -- assign a font of their own to single elements of this spot
  if t.elems and #t.elems > 0 and #t.elems <= 6 then
    R.ImGui_Spacing(ctx)
    R.ImGui_TextDisabled(ctx, "Change this element only (other elements using the same font stay as they are):")
    for i, e in ipairs(t.elems) do
      local pm3 = push_mono()
      R.ImGui_AlignTextToFramePadding(ctx)
      local comp = t.computed and t.computed[e]
      R.ImGui_Text(ctx, string.format("%-28s %s", e, comp and ("theme: " .. font_label(key_of_idx(comp) or "?")) or ""))
      popf(pm3)
      R.ImGui_SameLine(ctx)
      ovr_combo(e, "t" .. i)
      tip("Give " .. e .. " a WALTER font of its own in all layouts and scales; \"(as theme)\" removes it.")
    end
  end
  sec_end(s)
end

-- Horizontal splitter: drag to change the height of the font list
local function splitter(id)
  local z = VIEW.zoom
  local w = inner_w()
  local x, y = R.ImGui_GetCursorScreenPos(ctx)
  R.ImGui_InvisibleButton(ctx, id, math.max(w, 1), 10 * z)
  local hov, act = R.ImGui_IsItemHovered(ctx), R.ImGui_IsItemActive(ctx)
  if hov or act then R.ImGui_SetMouseCursor(ctx, R.ImGui_MouseCursor_ResizeNS()) end
  if act then
    local _, dy = R.ImGui_GetMouseDelta(ctx)
    OPT.listH = math.max(80, math.min(2000, OPT.listH + dy / z))
  end
  if R.ImGui_IsItemDeactivated(ctx) then save_opts() end
  local dl = R.ImGui_GetWindowDrawList(ctx)
  local col = (hov or act) and ACID or acid_a(0.35)
  local cy = y + 5 * z
  R.ImGui_DrawList_AddLine(dl, x, cy, x + w, cy, col, (hov or act) and 2 or 1)
  local cx = x + w * 0.5
  for i = -1, 1 do R.ImGui_DrawList_AddCircleFilled(dl, cx + i * 9 * z, cy, 2.2 * z, col) end
  tip("Drag to change the height of the font list; double-click restores the default height.")
  if hov and R.ImGui_IsMouseDoubleClicked(ctx, 0) then OPT.listH = 230; save_opts() end
end

local function draw_list()
  local z = VIEW.zoom
  local s = sec_begin("list", "ALL FONTS")
  local flags = R.ImGui_TableFlags_RowBg() | R.ImGui_TableFlags_BordersInnerH() | R.ImGui_TableFlags_ScrollY()
  if R.ImGui_BeginTable(ctx, "fonts", 3, flags, inner_w(), OPT.listH * z) then
    R.ImGui_TableSetupScrollFreeze(ctx, 0, 1)
    R.ImGui_TableSetupColumn(ctx, "Font / size / face", R.ImGui_TableColumnFlags_WidthStretch())
    R.ImGui_TableSetupColumn(ctx, "Elements", R.ImGui_TableColumnFlags_WidthFixed(), 70 * z)
    R.ImGui_TableSetupColumn(ctx, "", R.ImGui_TableColumnFlags_WidthFixed(), 56 * z)
    R.ImGui_TableHeadersRow(ctx)
    for _, key in ipairs(S.order) do
      R.ImGui_TableNextRow(ctx)
      R.ImGui_TableNextColumn(ctx)
      local pm = push_mono()
      if R.ImGui_Selectable(ctx, font_line(key) .. "##l" .. key, S.sel == key,
          R.ImGui_SelectableFlags_AllowOverlap()) then
        S.sel = key
      end
      if TEST.on then
        local ax, ay = R.ImGui_GetItemRectMin(ctx)
        local bx, by = R.ImGui_GetItemRectMax(ctx)
        rect("row_" .. key, ax, ay, bx, by)
      end
      popf(pm)
      tip("Click to edit this font in the EDIT section above.")
      R.ImGui_TableNextColumn(ctx)
      local u = usage_of(key)
      if #u > 0 then
        R.ImGui_TextDisabled(ctx, tostring(#u))
        tip("Elements of the default layout using this font: " .. table.concat(u, ", ") .. ".")
      end
      R.ImGui_TableNextColumn(ctx)
      if R.ImGui_SmallButton(ctx, "-##" .. key) then
        set_font(key, function(x) x.height = with_px(x, px(x) - 1) end)
      end
      tip("Make this font 1 pixel smaller.")
      R.ImGui_SameLine(ctx)
      if R.ImGui_SmallButton(ctx, "+##" .. key) then
        set_font(key, function(x) x.height = with_px(x, px(x) + 1) end)
      end
      tip("Make this font 1 pixel larger.")
    end
    R.ImGui_EndTable(ctx)
  end
  splitter("##split")
  sec_end(s)
end

-- all elements of the default layout with their own font override
local function draw_elements()
  local z = VIEW.zoom
  if not (S.T and S.T.rtc) then
    R.ImGui_TextDisabled(ctx, "This theme has no rtconfig - no elements.")
    return
  end
  R.ImGui_SetNextItemWidth(ctx, 240 * z)
  local ch, v = R.ImGui_InputTextWithHint(ctx, "##ef", "Filter, e.g. mcp.fx", S.elemFilter)
  if ch then S.elemFilter = v end
  tip("Show only elements whose name contains this text.")
  R.ImGui_SameLine(ctx)
  local n = 0
  for _ in pairs(S.ovr) do n = n + 1 end
  R.ImGui_TextDisabled(ctx, n .. " override" .. (n == 1 and "" or "s")
    .. "   (layout " .. (S.defLayout ~= "" and S.defLayout or "default") .. ")")
  local names = {}
  for e in pairs(S.elemIdx) do
    if S.elemFilter == "" or e:find(S.elemFilter, 1, true) then names[#names + 1] = e end
  end
  table.sort(names)
  local flags = R.ImGui_TableFlags_RowBg() | R.ImGui_TableFlags_BordersInnerH() | R.ImGui_TableFlags_ScrollY()
  local _, availH = R.ImGui_GetContentRegionAvail(ctx)
  if not R.ImGui_BeginTable(ctx, "elems", 3, flags, inner_w(), math.max(160 * z, availH - 16 * z)) then return end
  R.ImGui_TableSetupScrollFreeze(ctx, 0, 1)
  R.ImGui_TableSetupColumn(ctx, "Element", R.ImGui_TableColumnFlags_WidthStretch())
  R.ImGui_TableSetupColumn(ctx, "Theme", R.ImGui_TableColumnFlags_WidthFixed(), 130 * z)
  R.ImGui_TableSetupColumn(ctx, "Own font", R.ImGui_TableColumnFlags_WidthFixed(), 180 * z)
  R.ImGui_TableHeadersRow(ctx)
  for i, e in ipairs(names) do
    R.ImGui_TableNextRow(ctx)
    R.ImGui_TableNextColumn(ctx)
    local pm = push_mono()
    R.ImGui_AlignTextToFramePadding(ctx)
    R.ImGui_TextColored(ctx, S.ovr[e] and ACID or INKC, e)
    popf(pm)
    tip(S.elemVar[e] and ("This element gets its font via the variable " .. S.elemVar[e] .. ".")
      or "WALTER element of the default layout.")
    R.ImGui_TableNextColumn(ctx)
    local idx = S.elemIdx[e]
    R.ImGui_TextDisabled(ctx, idx == 0 and "main font" or idx == -1 and "vol/pan" or font_label(key_of_idx(idx) or "?"))
    R.ImGui_TableNextColumn(ctx)
    ovr_combo(e, "l" .. i, -1)
    tip("Give this element a WALTER font of its own; \"(as theme)\" removes it.")
  end
  R.ImGui_EndTable(ctx)
end

local function draw_overrides()
  local s = sec_begin("ovr", "ELEMENT OVERRIDES", function(wd)
    if btn("k_ovr", wd - 12 - 70, 2, 70, 18, UI.ovrOpen and "HIDE" or "SHOW", UI.ovrOpen, false,
        "Show or hide the table that gives any WALTER element a font of its own.") then
      UI.ovrOpen = not UI.ovrOpen
    end
  end)
  if UI.ovrOpen then
    draw_elements()
  else
    R.ImGui_TextDisabled(ctx, "Give single WALTER elements (mcp.fxlist, tcp.label ...) a font of their own - click SHOW.")
  end
  sec_end(s)
end

-- OPTIONS: kit header (TOOLTIPS, UI SIZE, AUTO FIT) and the fonts of the window
local function draw_options_popup(px_, py_)
  if R.ImGui_SetNextWindowPos then R.ImGui_SetNextWindowPos(ctx, px_, py_, R.ImGui_Cond_Appearing(), 1, 0) end
  if not R.ImGui_BeginPopup(ctx, "tt_opts") then return end
  if UI.openOpts == false then UI.openOpts = nil; R.ImGui_CloseCurrentPopup(ctx) end
  local z = VIEW.zoom
  local x0, y0 = R.ImGui_GetCursorScreenPos(ctx)
  kit_at(R.ImGui_GetWindowDrawList(ctx), x0, y0)
  local PW = 400
  ptext(0, 0, "OPTIONS", C(0.88, 0.98, 0.86, 1), 14)
  rfill(0, 22, PW, 1, dimc(0.55))
  rfill(0, 22, 26, 1, acid(0.85))
  if toggle("k_tips", PW - 122, -1, 122, 20, VIEW.tips, VIEW.tips and "TOOLTIPS ON" or "TOOLTIPS OFF",
      "Show or hide the tooltips of this window.") then
    set_tips(not VIEW.tips, true)
  end
  ptext(0, 32, "UI SIZE", C(INK[1], INK[2], INK[3], 0.92), 12)
  ptext(64, 32, string.format("%d %%", floor(VIEW.zoom * 100 + 0.5)), acid(1), 12)
  for i, f in ipairs(ZOOM_STEPS) do
    local lbl = string.format("%d%%", floor(f * 100 + 0.5))
    if btn("k_z" .. i, (i - 1) * 54, 50, 50, 24, lbl, math.abs(VIEW.zoom - f) < 0.005, false,
        "Show the window content at " .. lbl .. "; the size stays until the window is resized again.") then
      set_zoom(f, not TEST.on)
    end
  end
  if toggle("k_af", PW - 116, 50, 116, 24, VIEW.autofit, VIEW.autofit and "AUTO FIT ON" or "AUTO FIT OFF",
      "When on, resizing the window rescales the content to the largest size that fits, from 25 to 400 percent.") then
    set_autofit(not VIEW.autofit, not TEST.on)
  end
  rfill(0, 86, PW, 1, dimc(0.35))
  ptext(0, 94, "WINDOW FONTS", C(INK[1], INK[2], INK[3], 0.92), 12)
  R.ImGui_SetCursorScreenPos(ctx, x0, y0)
  R.ImGui_Dummy(ctx, PW * z, 112 * z)

  local changed = false
  R.ImGui_SetNextItemWidth(ctx, 200 * z)
  if R.ImGui_BeginCombo(ctx, "Font", OPT.ui) then
    for _, u in ipairs(UI_FONTS) do
      if R.ImGui_Selectable(ctx, u.name, OPT.ui == u.name) then OPT.ui = u.name; changed = true end
    end
    R.ImGui_EndCombo(ctx)
  end
  tip("Font for the texts and lists of this window.")
  R.ImGui_SetNextItemWidth(ctx, 200 * z)
  local c1, v1 = R.ImGui_SliderInt(ctx, "Size##ui", OPT.size, 10, 22, "%d px")
  if c1 then OPT.size = v1; changed = true end
  tip("Size of that font at 100 percent UI size, from 10 to 22 pixels.")
  R.ImGui_SetNextItemWidth(ctx, 200 * z)
  if R.ImGui_BeginCombo(ctx, "Table font", OPT.mono) then
    for _, m in ipairs(MONO_FONTS) do
      if R.ImGui_Selectable(ctx, m.name, OPT.mono == m.name) then OPT.mono = m.name; changed = true end
    end
    R.ImGui_EndCombo(ctx)
  end
  tip("Fixed-width font for the tables and the target line.")
  R.ImGui_SetNextItemWidth(ctx, 200 * z)
  local c2, v2 = R.ImGui_SliderInt(ctx, "Size##mono", OPT.msize, 9, 20, "%d px")
  if c2 then OPT.msize = v2; changed = true end
  tip("Size of the table font at 100 percent UI size, from 9 to 20 pixels.")
  if R.ImGui_Button(ctx, "Defaults") then
    OPT.ui, OPT.size, OPT.mono, OPT.msize = "Liberation Sans", 14, "Liberation Mono", 13
    changed = true
  end
  tip("Back to Liberation Sans 14 px and Liberation Mono 13 px.")
  if changed then save_opts() end
  local wx, wy = R.ImGui_GetWindowPos(ctx)
  local ww, wh = R.ImGui_GetWindowSize(ctx)
  rect("options", wx, wy, wx + ww, wy + wh)
  R.ImGui_EndPopup(ctx)
end

local function draw_theme_chooser()
  local z = VIEW.zoom
  local s = sec_begin("chooser", "CHOOSE A THEME")
  R.ImGui_TextColored(ctx, ACID, "No readable theme active.")
  R.ImGui_TextWrapped(ctx, "Choose a theme to edit (it will be loaded):")
  local dir = RES .. "/ColorThemes/"
  if R.ImGui_BeginChild(ctx, "themes", inner_w(), 260 * z) then
    for _, f in ipairs(list_themes(dir)) do
      if R.ImGui_Selectable(ctx, f) then
        if R.OpenColorThemeFile(dir .. f) then init_theme(dir .. f)
        else set_status("Loading failed: " .. f) end
      end
      tip("Load this theme in REAPER and open it for editing.")
    end
    R.ImGui_EndChild(ctx)
  end
  sec_end(s)
end

-- Header: wordmark, version, preview state (kit coordinates from the window content)
local function draw_header(Wd)
  local x = spaced(14, 13, "TT-THEMEFONTEDITOR", acid(1), 19, 2.0)
  ptext(x + 8, 20, "v" .. VERSION, C(0.45, 0.48, 0.45), 12)
  local label, colr, ttxt
  if not S.T then
    label, colr, ttxt = "NO THEME", AMBER, "No readable theme is active; choose one in the list below."
  elseif S.wcLoaded then
    label, colr, ttxt = "PREVIEW ACTIVE", { UK.ar, UK.ag, UK.ab }, "REAPER is showing the working copy with your changes."
  else
    label, colr, ttxt = "ORIGINAL THEME", { 0.55, 0.60, 0.55 }, "REAPER is showing the original theme; the first change starts the preview."
  end
  local lwid = tw(label, 12) + 22
  local sx = Wd - 14 - lwid
  if sx > x + 70 then
    -- circuit traces between the wordmark and the state
    local tx = x + 60
    if sx - tx > 90 then
      trace({ { sx - 8, 16 }, { tx + 40, 16 }, { tx + 24, 32 } }, acid(0.55))
      trace({ { sx - 8, 24 }, { tx + 66, 24 }, { tx + 58, 32 } }, acid(0.35))
    end
    led(sx + 6, 25, 3.4, S.T ~= nil, colr)
    ptext(sx + 16, 18, label, C(colr[1], colr[2], colr[3], 1), 12)
    hit("k_hdr", sx, 14, lwid, 22)
    tipfor("k_hdr", ttxt)
  end
  rfill(14, HEAD_H - 3, Wd - 28, 1, dimc(0.35))
end

-- Toolbar row: PICKER / CANCEL PICKER, OPTIONS, theme and scale
local function draw_toolbar(Wd)
  local y = HEAD_H + 4
  local optx = Wd - 14 - 96
  if picker.armed then
    if btn("k_cancel", 14, y, 128, 26, "CANCEL PICKER", true, false, "Stop the picker without locking a target.") then
      picker.armed = false; S.hover = nil
    end
    ptext(152, y + 6, fit_text("Hover over text in the REAPER window - click or SHIFT locks it", 13, optx - 162), acid(1), 13)
  else
    if btn("k_picker", 14, y, 128, 26, "PICKER", false, true,
        "Arm the picker, point at any text in the REAPER window and press Shift (or click) to lock that spot.") then
      if not R.GetThingFromPoint then set_status("The picker needs REAPER 6.x+ (GetThingFromPoint)")
      else picker.armed = true; picker.down = false; picker.shift = true; S.hover = nil end
    end
    ptext(152, y + 6, fit_text("Find a spot in the theme", 13, optx - 162), C(0.55, 0.60, 0.55), 13)
  end
  if btn("k_opts", optx, y, 96, 26, "OPTIONS", R.ImGui_IsPopupOpen(ctx, "tt_opts"), false,
      "Open the window options: UI size, AUTO FIT, tooltips and the window fonts.") then
    UI.openOpts = true
  end
  local y2 = y + 36
  if S.T then
    local scl = string.format("SCALE %d%% -> LAYOUT %s", floor(S.uiscale * 100 + 0.5),
      S.defLayout ~= "" and S.defLayout or "default")
    local sw = tw(scl, 11)
    ptext(14, y2 + 1, "THEME", acid(0.9), 11)
    local tname = select(2, split_path(S.orig))
    ptext(62, y2, fit_text(tname, 12, Wd - 14 - sw - 24 - 62), INKC, 12)
    ptext_r(Wd - 14, y2 + 1, scl, acid(1), 11)
    hit("k_scale", Wd - 14 - sw, y2 - 2, sw, 16)
    tipfor("k_scale", "UI scale from the REAPER preferences and the mixer layout the editor uses to compute the fonts.")
  end
  rfill(14, HEAD_H + TOOL_H - 3, Wd - 28, 1, dimc(0.25))
end

-- Footer: progress, BAKE THEME / DISCARD / RELOAD, counter, STATUS line
local function draw_footer(Wd)
  local y = 8
  if S.job then
    local frac = S.job.total > 0 and (S.job.pos / S.job.total) or 0
    rfill(14, y, Wd - 28, 14, C(0.035, 0.038, 0.035), 2)
    rfill(14, y, math.max(2, (Wd - 28) * frac), 14, acid(0.75), 2)
    ptext(20, y, string.format("%s  %d / %d", S.job.name, S.job.pos, S.job.total), C(0.96, 0.98, 0.96), 11)
    y = y + JOB_H
  end
  local yb = y
  if S.T then
    local n = changed_count()
    local busy = S.job ~= nil
    -- selectable target (BAKE TO: CREATE COPY / OVERWRITE ORIGINAL)
    local asZip = (S.T.zip or next(S.ovr) ~= nil) and true or false
    local bp, bmode, bnote = bake_target(asZip)
    local bn = bp and select(2, split_path(bp)) or "(no free copy name)"
    local btip = bmode == "overwrite"
      and ("Write all changes back into " .. bn .. " and load it; the previous version is kept as " .. bn .. ".bak.")
      or ("Write all changes to the new theme file " .. bn .. " and load it; the original stays untouched"
        .. (bnote and " (element overrides need a zipped theme, so overwriting is not possible here)." or "."))
    if btn("k_bake", 14, yb, 132, 28, "BAKE THEME", false, true, btip, busy or n == 0) then
      request_bake()
    end
    if btn("k_discard", 154, yb, 92, 28, "DISCARD", false, false,
        "Discard all changes and load the original theme again.", busy or n == 0) then
      discard()
    end
    if btn("k_reload", 254, yb, 92, 28, "RELOAD", false, false,
        "Read the active theme again, for example after switching themes or changing the UI scale in REAPER.", busy) then
      init_theme(R.GetLastColorThemeFile())
    end
    local cnt = n .. " change" .. (n == 1 and "" or "s") .. (S.dirtyAt and "  (preview pending)" or "")
    ptext(360, yb + 7, fit_text(cnt, 12, Wd - 374), n > 0 and acid(1) or C(0.55, 0.58, 0.55), 12)
    -- BAKE TO row: choice of the target (saved), on the right the actual file name
    local yt = yb + 36
    ptext(14, yt + 4, "BAKE TO", acid(0.9), 11)
    if btn("k_bt_copy", 70, yt, 112, 22, "CREATE COPY", bmode == "copy", false,
        "Bake into a new theme file next to the original, numbered if the name is taken, so the original stays untouched.",
        busy) then
      set_bake_mode("copy", true)
    end
    local canOver = asZip == is_zip(S.orig)
    if btn("k_bt_over", 188, yt, 158, 22, "OVERWRITE ORIGINAL", bmode == "overwrite", false,
        canOver and "Bake back into the theme file you are editing; its previous version is kept as a .bak file next to it."
          or "Not available for this theme: element overrides need a zipped theme, so an unzipped theme is baked as a copy.",
        busy or not canOver) then
      set_bake_mode("overwrite", true)
    end
    local tgt = (bmode == "overwrite") and (bn .. "  (old kept as .bak)") or (bn .. "  (new file)")
    ptext(360, yt + 4, fit_text(tgt, 12, Wd - 374), C(0.78, 0.84, 0.76), 12)
    hit("k_bt_file", 360, yt, math.max(20, Wd - 374), 22)
    tipfor("k_bt_file", "File that BAKE THEME will write, depending on the BAKE TO choice.")
  end
  local ys = yb + 66
  trace({ { 15, ys - 1 }, { 21, ys + 6 }, { 28, ys + 6 } }, acid(0.55))
  ptext(38, ys, "STATUS //", acid(1), 11)
  ptext(102, ys - 1, fit_text(S.status, 12, Wd - 102 - 14), INKC, 12)
end

local function draw_main()
  local z = VIEW.zoom
  local ww, wh = R.ImGui_GetWindowSize(ctx)
  track_window(ww, wh)
  save_view_pending(R.ImGui_IsMouseDown(ctx, 0))
  S.guiHovered = R.ImGui_IsWindowHovered(ctx, R.ImGui_HoveredFlags_RootAndChildWindows())
  local wx, wy = R.ImGui_GetWindowPos(ctx)
  rect("window", wx, wy, wx + ww, wy + wh)
  UK.mx, UK.my = R.ImGui_GetMousePos(ctx)
  local mods = R.ImGui_GetKeyMods(ctx)
  UK.shift = (mods & R.ImGui_Mod_Shift()) ~= 0
  UK.ctrl = (mods & R.ImGui_Mod_Ctrl()) ~= 0

  local gx, gy = R.ImGui_GetCursorScreenPos(ctx)
  local cw0, ch0 = R.ImGui_GetContentRegionAvail(ctx)
  -- Minimum area in design units (header, toolbar row, narrow EDIT, footer up to
  -- RELOAD and counter). If the window is smaller at a fixed zoom, the area is made larger than the window and
  -- the main window gets scrollbars (frame(): VIEW.overflow) instead of cutting off controls.
  local footH0 = (FOOT_H + (S.job and JOB_H or 0)) * z
  local cw = math.max(cw0, MIN_WD * z)
  local ch = math.max(ch0, (HEAD_H + TOOL_H + MIN_BODY) * z + footH0)
  VIEW.overflow = (cw > cw0 + 0.5) or (ch > ch0 + 0.5)
  local Wd = cw / z
  local dl = R.ImGui_GetWindowDrawList(ctx)
  ground(dl, gx, gy, cw, ch)
  rect("frame", gx, gy, gx + cw, gy + ch)
  kit_at(dl, gx, gy)
  draw_header(Wd)
  kit_at(dl, gx, gy)
  draw_toolbar(Wd)
  local topH = (HEAD_H + TOOL_H) * z
  rect("top", gx, gy, gx + cw, gy + topH)
  rect("toolbar", gx, gy + HEAD_H * z, gx + cw, gy + topH)
  if UI.openOpts == true then UI.openOpts = nil; R.ImGui_OpenPopup(ctx, "tt_opts") end
  draw_options_popup(gx + cw - 14 * z, gy + (HEAD_H + 34) * z)

  local footH = (FOOT_H + (S.job and JOB_H or 0)) * z
  R.ImGui_SetCursorScreenPos(ctx, gx, gy + topH)
  local bodyH = math.max(40 * z, ch - topH - footH)
  rect("body", gx, gy + topH, gx + cw, gy + topH + bodyH)
  if R.ImGui_BeginChild(ctx, "body", cw, bodyH) then
    R.ImGui_Dummy(ctx, 1, 4 * z)
    R.ImGui_Indent(ctx, 12 * z)
    if not S.T then
      draw_theme_chooser()
    else
      -- working copy made by the older TT_ThemeFonts script: its rtconfig
      -- was rewritten and may lose scaling terms
      if S.T.rtc and S.T.rtc:find("define_parameter%s+ttf_") then
        local legacy = find_original(S.orig)
        R.ImGui_TextColored(ctx, ACID, "Warning: working copy of the older TT_ThemeFonts script - rtconfig is modified.")
        if legacy and norm(legacy) ~= norm(S.orig) then
          R.ImGui_SameLine(ctx)
          if R.ImGui_SmallButton(ctx, "Load original##legacy") then
            if load_theme(legacy) then init_theme(legacy) end
          end
          tip("Load " .. select(2, split_path(legacy)) .. "; font changes of the old copy are not carried over.")
        end
      end
      if S.target then draw_target() end
      if S.sel and S.cur[S.sel] then draw_edit(S.sel) end
      draw_list()
      draw_overrides()
    end
    R.ImGui_Unindent(ctx, 12 * z)
    R.ImGui_EndChild(ctx)
  end

  local fy = gy + ch - footH
  rect("footer", gx, fy, gx + cw, gy + ch)
  kit_at(dl, gx, fy)
  rfill(14, 0, Wd - 28, 1, dimc(0.35))
  draw_footer(Wd)
  R.ImGui_SetCursorScreenPos(ctx, gx, fy)
  R.ImGui_Dummy(ctx, cw, footH)
end

-- Floating label at the mouse pointer while the picker is active
local function draw_hover_tag()
  local h = S.hover
  if not (picker.armed and h) then return end
  local mx, my = R.GetMousePosition()
  if R.ImGui_PointConvertNative then mx, my = R.ImGui_PointConvertNative(ctx, mx, my, false) end
  R.ImGui_SetNextWindowPos(ctx, mx + 18, my + 18)
  local fl = R.ImGui_WindowFlags_NoDecoration() | R.ImGui_WindowFlags_NoInputs()
    | R.ImGui_WindowFlags_AlwaysAutoResize() | R.ImGui_WindowFlags_NoFocusOnAppearing()
    | R.ImGui_WindowFlags_NoNav() | R.ImGui_WindowFlags_NoDocking() | R.ImGui_WindowFlags_TopMost()
    | R.ImGui_WindowFlags_NoSavedSettings()
  if R.ImGui_Begin(ctx, "##tt_hover", nil, fl) then
    local pm = push_mono()
    R.ImGui_TextColored(ctx, ACID, h.info ~= "" and h.info or "?")
    if h.track then R.ImGui_SameLine(ctx); R.ImGui_TextDisabled(ctx, h.track) end
    if h.layout then R.ImGui_TextDisabled(ctx, "layout " .. (h.layout ~= "" and h.layout or "default")) end
    if #h.slots == 0 then
      R.ImGui_TextDisabled(ctx, "no theme font")
    end
    for _, sl in ipairs(h.slots) do
      R.ImGui_Text(ctx, string.format("%s%-15s %3d px", sl.confirmed and "OK " or "", font_label(sl.key),
        px(S.cur[sl.key])))
    end
    popf(pm)
    R.ImGui_End(ctx)
  end
end

--------------------------------------------------------------------
-- Test hooks (screenshot rig, dry run). Commands via ExtState
-- NS/test_cmd, several separated by ";"; acknowledgement in NS/test_ack.
-- Changes made by tests are not saved.
--   picker | cancel | options:1|0 | ovr:1|0 | filter:<text> | size:<w>x<h>
--   zoom:<percent> | autofit:1|0 | tips:1|0 | sel:<font key> | rects:<file>
--   pickat:<x>,<y> (lock the target at a screen point) | grow:<px> | bold:1|0 (selected
--   font) | bake | discard | reload | holdat:<n> (pause the job at step n, 0 = continue) | state:<file>
--   (state as key=value after the frame). rects: also contains the controls (k_*) and list rows (row_*).
--   baketarget:overwrite|copy (not saved); state: names baketarget, bakefile (target of the next
--   bake), lastbake/lastbak (target and backup of the last bake)
--------------------------------------------------------------------
local function test_poll()
  TEST.on = R.GetExtState(NS, "test_ok") == "20261001"
  if not TEST.on then return end
  local c = R.GetExtState(NS, "test_cmd")
  if c == "" then return end
  R.SetExtState(NS, "test_cmd", "", false)
  for one in c:gmatch("[^;]+") do
    local k, v = one:match("^([%w_]+):?(.*)$")
    if k == "picker" then
      if R.GetThingFromPoint then picker.armed = true; picker.down = false; picker.shift = true; S.hover = nil end
    elseif k == "cancel" then picker.armed = false; S.hover = nil
    elseif k == "options" then UI.openOpts = (v ~= "0")
    elseif k == "ovr" then UI.ovrOpen = (v ~= "0")
    elseif k == "filter" then S.elemFilter = v or ""
    elseif k == "size" then
      local w, h = (v or ""):match("^(%d+)x(%d+)$")
      if w then TEST.size = { tonumber(w), tonumber(h) } end
    elseif k == "zoom" then set_zoom((tonumber(v) or 100) / 100, false)
    elseif k == "autofit" then set_autofit(v ~= "0", false)
    elseif k == "tips" then set_tips(v ~= "0", false)
    elseif k == "sel" then if S.cur[v] then S.sel = v end
    elseif k == "rects" then TEST.dump = v
    -- controls for the REAPER verification of BAKE/DISCARD and the manual images
    elseif k == "pickat" then
      local px_, py_ = (v or ""):match("^(%-?%d+),(%-?%d+)$")
      -- clear S.sel first: if the point finds no theme font, a following grow changes nothing (instead of the old selection)
      if px_ then picker.armed = false; S.sel = nil; lock_target(pick_at(tonumber(px_), tonumber(py_))) end
    elseif k == "grow" then
      local d = tonumber(v) or 0
      if S.sel then set_font(S.sel, function(x) x.height = with_px(x, px(x) + d) end) end
    elseif k == "bold" then
      if S.sel then set_font(S.sel, function(x) x.weight = (v ~= "0") and 700 or 400 end) end
    elseif k == "bake" then if S.T and not S.job and changed_count() > 0 then request_bake() end
    elseif k == "discard" then if S.T and not S.job then discard() end
    elseif k == "reload" then if not S.job then init_theme(R.GetLastColorThemeFile()) end
    elseif k == "holdat" then S.holdAt = (tonumber(v) or 0) > 0 and tonumber(v) or nil
    elseif k == "state" then TEST.state = v
    -- set the bake target for the test (not saved)
    elseif k == "baketarget" then set_bake_mode(v, false)
    end
  end
  R.SetExtState(NS, "test_ack", c, false)
end

-- writes the rectangles of the last frame: "name x0 y0 x1 y1" in
-- screen pixels (native), plus "zoom" and "imgui_window"
local function test_state()
  if not (TEST.on and TEST.state and TEST.state ~= "") then return end
  local path = TEST.state
  TEST.state = nil
  local sel = S.sel and S.cur[S.sel]
  write_file(path, table.concat({
    "status=" .. tostring(S.status), "orig=" .. tostring(S.orig), "active=" .. tostring(R.GetLastColorThemeFile()),
    "wcLoaded=" .. tostring(S.wcLoaded), "wcReady=" .. tostring(S.wcReady), "job=" .. (S.job and S.job.name or ""),
    "jobpos=" .. (S.job and (S.job.pos .. "/" .. S.job.total) or ""), "changes=" .. (S.T and changed_count() or 0),
    "sel=" .. tostring(S.sel), "selpx=" .. (sel and px(sel) or ""), "selweight=" .. (sel and sel.weight or ""),
    "target=" .. (S.target and S.target.info or ""), "pending=" .. tostring(S.dirtyAt ~= nil),
    "baketarget=" .. bake_mode(),
    "origparams=" .. tostring(S.origParams),
    "curparams=" .. tostring(R.ThemeLayout_GetParameter ~= nil and R.ThemeLayout_GetParameter(0) ~= nil),
    "bakefile=" .. (S.T and (bake_target((S.T.zip or next(S.ovr) ~= nil) and true or false)) or ""),
    "lastbake=" .. tostring(S.lastBake or ""), "lastbak=" .. tostring(S.lastBak or ""),
  }, "\n") .. "\n")
end

local function test_dump()
  if not (TEST.on and TEST.dump and TEST.dump ~= "") then return end
  local path = TEST.dump
  TEST.dump = nil
  local out = { string.format("zoom %.2f", VIEW.zoom) }
  local names = {}
  for n in pairs(TEST.rects) do names[#names + 1] = n end
  table.sort(names)
  for _, n in ipairs(names) do
    local r = TEST.rects[n]
    local x0, y0, x1, y1 = r[1], r[2], r[3], r[4]
    if n == "window" then out[#out + 1] = string.format("imgui_window %.1f %.1f %.1f %.1f", x0, y0, x1, y1) end
    if R.ImGui_PointConvertNative then
      x0, y0 = R.ImGui_PointConvertNative(ctx, x0, y0, true)
      x1, y1 = R.ImGui_PointConvertNative(ctx, x1, y1, true)
    end
    out[#out + 1] = string.format("%s %d %d %d %d", n, floor(x0 + 0.5), floor(y0 + 0.5), floor(x1 + 0.5), floor(y1 + 0.5))
  end
  write_file(path, table.concat(out, "\n") .. "\n")
end

local function frame()
  local z = VIEW.zoom
  TEST.rects = {}
  local nc, nv = push_theme(z)
  local pf = pushf(FONTS.ui[OPT.ui], OPT.size * z)
  R.ImGui_SetNextWindowSize(ctx, DES_W, DES_H, R.ImGui_Cond_FirstUseEver())
  if TEST.size then
    R.ImGui_SetNextWindowSize(ctx, TEST.size[1], TEST.size[2], R.ImGui_Cond_Always())
    TEST.size = nil
  end
  -- main window without inner padding: header and footer reach the edge
  R.ImGui_PushStyleVar(ctx, R.ImGui_StyleVar_WindowPadding(), 0, 0)
  -- if the minimum area does not fit in the window (fixed high zoom), scrollbars also horizontally; otherwise none
  local flags = R.ImGui_WindowFlags_NoCollapse()
  if VIEW.overflow then flags = flags | R.ImGui_WindowFlags_HorizontalScrollbar()
  else flags = flags | R.ImGui_WindowFlags_NoScrollbar() | R.ImGui_WindowFlags_NoScrollWithMouse() end
  local visible, open = R.ImGui_Begin(ctx, WIN_TITLE, true, flags)
  R.ImGui_PopStyleVar(ctx, 1)
  local ok, err = true, nil
  if visible then
    ok, err = pcall(draw_main)
    R.ImGui_End(ctx)
  end
  local ok2, err2 = pcall(draw_hover_tag)
  popf(pf)
  R.ImGui_PopStyleVar(ctx, nv)
  R.ImGui_PopStyleColor(ctx, nc)
  pcall(test_dump)
  pcall(test_state)
  if not ok then error(err, 0) end
  if not ok2 then error(err2, 0) end
  return open
end

local errCount = 0
local function loop()
  test_poll()
  pick_poll()
  run_job()
  -- queued bake (see BAKE THEME): only after successful preparation, dropped on error (status stays)
  if S.bakePending and not S.job then
    S.bakePending = nil
    if S.T and (S.wcReady or not S.needFolder) then
      S.dirtyAt = nil
      start_bake()
    end
  end
  if S.dirtyAt and not S.job and R.time_precise() - S.dirtyAt >= DEBOUNCE
      and not R.ImGui_IsMouseDown(ctx, 0) then
    apply_preview()
  end
  local ok, open = pcall(frame)
  if not ok then
    errCount = errCount + 1
    tlog("GUI error: " .. tostring(open))
    set_status("Error: " .. tostring(open))
    if errCount > 20 then return end
  end
  if ok and open == false then
    abort_job("window closed")
    if changed_count() > 0 and S.wcLoaded then
      tlog("closed with unsaved changes - preview stays active")
    end
    return
  end
  R.defer(loop)
end

local function main()
  if not R.ImGui_CreateContext then
    R.MB("ReaImGui is missing (install it via ReaPack).", "TT-THEMEFONTEDITOR", 0) return
  end
  do local lf = io.open(LOGF, "w"); if lf then lf:close() end end
  load_opts()
  load_view()
  init_theme(R.GetLastColorThemeFile())
  -- context name (invisible) unchanged
  ctx = R.ImGui_CreateContext("TT Theme Font Editor")
  init_fonts()
  -- also when the script ends (action run again, "Terminate instances"), abort running jobs cleanly
  if R.atexit then R.atexit(function() abort_job("script ended") end) end
  R.defer(loop)
end

main()
end

run_gui()
