-- @description TT Theme Font Editor
-- @author TimTechlor
-- @version 1.3
-- @license MIT
-- @tags theme fonts walter rtconfig imgui
-- @provides
--   TT_ThemeFontEditor_Manual.html
-- @changelog
--   First release via ReaPack.
--   - Element overrides table uses the full remaining window height
--   - Draggable splitter between the font list and the element overrides
-- @about
--   # TT Theme Font Editor
--
--   Find and change the font sizes of the active REAPER theme.
--
--   - Picker: hover over any text in the REAPER window, click or press Shift
--     to lock it. The editor shows which WALTER font (or ini font) is used there.
--   - Change size, bold and italic; element overrides give single WALTER
--     elements a font of their own.
--   - Changes are previewed live through a working copy; "Bake theme" writes a
--     new theme "<Name> (TimTechlor)". The original theme stays untouched.
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
-- TimTechlor brand design (black/white/acid green, Zilap Orion +
-- Liberation Sans/Mono, circuit traces).

local R = reaper
local VERSION = "1.3"
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

local function write_file(p, d)
  local f = io.open(p, "wb"); if not f then return false end
  f:write(d); f:close()
  return true
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

local function zip_close(p, zh) pcall(R.JS_Zip_Close, p, zh) end

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

local function zip_write(zh, name, data)
  R.JS_Zip_Entry_OpenByName(zh, name)
  R.JS_Zip_Entry_CompressMemory(zh, data, #data)
  R.JS_Zip_Entry_Close(zh)
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

local function set_ui_img(ini, name)
  if ini:find("\nui_img%s*=") then
    return (ini:gsub("(\nui_img%s*=%s*)[^\r\n]*", "%1" .. name, 1))
  end
  return (ini:gsub("(%[REAPER%][^\r\n]*\r?\n)", "%1ui_img=" .. name .. "\r\n", 1))
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
  for l in text:gmatch("[^\r\n]+") do
    l = l:gsub(";.*$", "")
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
      for _, bl in ipairs(m.body) do
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
    if not s then s, e = txt:find("^%[" .. pat .. "%]") end
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

local function bake_path(orig, asZip)
  local dir = split_path(orig)
  local stem = sanitize(base_stem(orig)) .. BAKE_MARK
  return dir .. stem .. (asZip and ".ReaperThemeZip" or ".ReaperTheme")
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
  local t0 = R.time_precise()
  local ok, err = pcall(function()
    while R.time_precise() - t0 < BUDGET do
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
  S.job = {
    name = T.zip and "Extracting" or "Copying", total = #list, pos = 0,
    step = function()
      i = i + 1
      S.job.pos = i
      local n = list[i]
      if not n then
        if zh then zip_close(T.path, zh) end
        write_file(S.wcFolder .. "/.tt_ready", source_sig())
        return true
      end
      local rel = T.zip and n:sub(#prefix + 1) or n
      local out = S.wcFolder .. "/" .. rel
      local d = out:match("^(.*)/[^/]+$")
      if d and not made[d] then R.RecursiveCreateDirectory(d, 0); made[d] = true end
      if T.zip then
        if zip_entry(zh, n) then
          R.JS_Zip_Entry_ExtractToFile(zh, out)
          pcall(R.JS_Zip_Entry_Close, zh)
        end
      else
        local data = read_file(T.assetDir .. "/" .. n)
        if data then write_file(out, data) end
      end
      return false
    end,
    done = function()
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
    if want and not okp then set_status("Warning: working copy rtconfig not loaded") return end
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
    -- remove the folder without a console window and without waiting
    R.ExecProcess('cmd.exe /C rmdir /S /Q "' .. S.wcFolder:gsub("/", "\\") .. '"', -1)
  end
  S.wcReady, S.wcLoaded, S.rtcSig = false, false, nil
end

local function finish_bake(final)
  sync_themeconfig(theme_stem(S.orig), theme_stem(final))
  if not load_theme(final) then set_status("Saved, but could not load: " .. final) return end
  cleanup_workcopy()
  init_theme(final)
  set_status("Baked: " .. select(2, split_path(final)))
end

-- builds a zip in slices; items = { {name, get = function() -> data} }
local function start_zip_job(final, items, closeSrc)
  local tmp = final:gsub("%.ReaperThemeZip$", ".tmp.ReaperThemeZip")
  os.remove(tmp)
  local dst = zip_open(tmp, "w")
  if not dst then if closeSrc then closeSrc() end set_status("Could not create zip") return end
  local i = 0
  S.job = {
    name = "Baking", total = #items, pos = 0,
    step = function()
      i = i + 1
      S.job.pos = i
      local it = items[i]
      if not it then
        if closeSrc then closeSrc() end
        zip_close(tmp, dst)
        -- if the target is loaded in REAPER, switch to the preview to release it
        if file_exists(final) and norm(R.GetLastColorThemeFile()) == norm(final) and file_exists(S.wcIni) then
          R.OpenColorThemeFile(S.wcIni)
        end
        os.remove(final)
        local target = final
        if not os.rename(tmp, target) then
          -- target locked: save under a new name instead of failing
          target = final:gsub("%)%.ReaperThemeZip$", " " .. os.date("%H%M%S") .. ").ReaperThemeZip")
          if not os.rename(tmp, target) then set_status("Rename failed: " .. tmp) return true end
          tlog("target locked, written as " .. target)
        end
        finish_bake(target)
        return true
      end
      local data = it.get()
      if data then zip_write(dst, it.name, data) end
      return false
    end,
    fail = function() if closeSrc then closeSrc() end zip_close(tmp, dst); os.remove(tmp) end,
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
    start_zip_job(bake_path(S.orig, true), items, function() zip_close(T.path, src) end)
    return
  end

  if not hasOvr then
    -- plain theme without overrides: new ini only, image folder stays the same
    local final = bake_path(S.orig, false)
    if not write_file(final, ini) then set_status("Write failed: " .. final) return end
    finish_bake(final)
    return
  end

  -- plain theme with overrides: build a zip from the working folder
  if not S.wcReady then start_prepare(start_bake) return end
  if S.rtcSig ~= ovr_sig(S.ovr) then
    write_file(S.wcFolder .. "/rtconfig.txt", apply_overrides(T.rtc, S.ovr))
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
  start_zip_job(bake_path(S.orig, true), items, nil)
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
    local t = S.hover
    S.target, S.hover = t, nil
    S.sel = t.slots[1] and t.slots[1].key or S.sel
    local ks = {}
    for _, sl in ipairs(t.slots) do ks[#ks + 1] = sl.key end
    tlog(string.format("pick info='%s' track='%s' P_LAYOUT='%s' -> Layout '%s' elems=%s slots=%s",
      t.info, tostring(t.track), tostring(t.rawLayout), tostring(t.layout),
      table.concat(t.elems, ","), table.concat(ks, ",")))
    set_status("Target: " .. t.info .. (t.track and (" [" .. t.track .. "]") or ""))
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
-- Brand design
--------------------------------------------------------------------
local ctx
local BLACK, WHITE, ACID = 0x000000FF, 0xFFFFFFFF, 0x39FF14FF
local function acid_a(a) return 0x39FF1400 | math.floor(a * 255 + 0.5) end
local GREY = 0x8C8C8CFF
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
  ok, f = pcall(R.ImGui_CreateFont, fallback, flags)
  if ok then return f end
end

local function init_fonts()
  local bold = R.ImGui_FontFlags_Bold and R.ImGui_FontFlags_Bold() or nil
  FONTS.brand = make_font("Zilap Orion.ttf", nil, "sans-serif", bold)
  for _, u in ipairs(UI_FONTS) do
    FONTS.ui[u.name] = make_font(u.file, u.name, "sans-serif", nil)
    FONTS.bold[u.name] = make_font(u.bfile, u.name, "sans-serif", bold)
  end
  for _, m in ipairs(MONO_FONTS) do
    FONTS.mono[m.name] = make_font(m.file, m.name, "monospace", nil)
  end
  R.ImGui_Attach(ctx, FONTS.brand)
  for _, grp in ipairs({ FONTS.ui, FONTS.bold, FONTS.mono }) do
    for _, f in pairs(grp) do R.ImGui_Attach(ctx, f) end
  end
end

local function pushf(f, size)
  if f then R.ImGui_PushFont(ctx, f, size) return true end
  return false
end
local function popf(p) if p then R.ImGui_PopFont(ctx) end end
local function push_mono(d) return pushf(FONTS.mono[OPT.mono], OPT.msize + (d or 0)) end
local function push_bold(d) return pushf(FONTS.bold[OPT.ui], OPT.size + (d or 0)) end

local function tip(text)
  if R.ImGui_SetItemTooltip then R.ImGui_SetItemTooltip(ctx, text)
  elseif R.ImGui_IsItemHovered(ctx) then R.ImGui_SetTooltip(ctx, text) end
end

local THEME_COLS = {
  { "WindowBg", BLACK }, { "ChildBg", BLACK }, { "PopupBg", 0x0A0A0AFF },
  { "Text", WHITE }, { "TextDisabled", GREY },
  { "Border", acid_a(0.55) }, { "BorderShadow", 0x00000000 },
  { "TitleBg", BLACK }, { "TitleBgActive", BLACK }, { "TitleBgCollapsed", BLACK },
  { "FrameBg", 0x0E0E0EFF }, { "FrameBgHovered", acid_a(0.18) }, { "FrameBgActive", acid_a(0.30) },
  { "Button", BLACK }, { "ButtonHovered", acid_a(0.22) }, { "ButtonActive", acid_a(0.45) },
  { "Header", acid_a(0.20) }, { "HeaderHovered", acid_a(0.30) }, { "HeaderActive", acid_a(0.45) },
  { "SliderGrab", ACID }, { "SliderGrabActive", WHITE }, { "CheckMark", ACID },
  { "Separator", acid_a(0.35) }, { "SeparatorHovered", ACID }, { "SeparatorActive", ACID },
  { "Tab", 0x0E0E0EFF }, { "TabHovered", acid_a(0.28) }, { "TabSelected", 0x1A1A1AFF },
  { "TabSelectedOverline", ACID }, { "TabDimmed", BLACK }, { "TabDimmedSelected", 0x121212FF },
  { "TableHeaderBg", 0x111111FF }, { "TableBorderStrong", acid_a(0.35) },
  { "TableBorderLight", 0x222222FF }, { "TableRowBgAlt", 0x0A0A0AFF },
  { "ScrollbarBg", BLACK }, { "ScrollbarGrab", 0x2A2A2AFF },
  { "ScrollbarGrabHovered", acid_a(0.5) }, { "ScrollbarGrabActive", ACID },
  { "ResizeGrip", acid_a(0.25) }, { "ResizeGripHovered", acid_a(0.6) }, { "ResizeGripActive", ACID },
  { "PlotHistogram", ACID }, { "TextSelectedBg", acid_a(0.35) }, { "NavCursor", ACID },
}
local THEME_VARS = {
  { "WindowRounding", 0 }, { "FrameRounding", 0 }, { "TabRounding", 0 },
  { "GrabRounding", 0 }, { "ScrollbarRounding", 0 }, { "PopupRounding", 0 },
  { "WindowBorderSize", 1 }, { "FrameBorderSize", 1 }, { "PopupBorderSize", 1 },
}

local function push_theme()
  local nc, nv = 0, 0
  for _, c in ipairs(THEME_COLS) do
    local fn = R["ImGui_Col_" .. c[1]]
    if fn then R.ImGui_PushStyleColor(ctx, fn(), c[2]); nc = nc + 1 end
  end
  for _, v in ipairs(THEME_VARS) do
    local fn = R["ImGui_StyleVar_" .. v[1]]
    if fn then R.ImGui_PushStyleVar(ctx, fn(), v[2]); nv = nv + 1 end
  end
  return nc, nv
end

-- Circuit trace: polyline with 45 degree bends, ending in a solder pad
local function trace(dl, pts, col)
  for i = 1, #pts - 1 do
    R.ImGui_DrawList_AddLine(dl, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], col, 1.5)
  end
  local e = pts[#pts]
  R.ImGui_DrawList_AddCircle(dl, e[1], e[2], 5.5, acid_a(0.45), 0, 1.2)
  R.ImGui_DrawList_AddCircleFilled(dl, e[1], e[2], 3.2, ACID)
end

local function draw_header()
  local dl = R.ImGui_GetWindowDrawList(ctx)
  local x0, y0 = R.ImGui_GetCursorScreenPos(ctx)
  local w = R.ImGui_GetContentRegionAvail(ctx)
  local H = 50
  local pf = pushf(FONTS.brand, 26)
  local word = "FONT EDITOR"
  local tw = R.ImGui_CalcTextSize(ctx, word)
  R.ImGui_DrawList_AddText(dl, x0, y0 + 2, WHITE, word)
  popf(pf)
  pf = pushf(FONTS.mono["Liberation Mono"], 12)
  local meta = "TT_ThemeFontEditor " .. VERSION .. " // TIMTECHLOR"
  R.ImGui_DrawList_AddText(dl, x0 + 1, y0 + 34, ACID, meta)
  local mw = R.ImGui_CalcTextSize(ctx, meta)
  popf(pf)
  -- three traces from the right edge, 45 degrees down to solder pads
  local tx = x0 + math.max(tw, mw) + 24
  local xR = x0 + w
  if xR - tx >= 130 then
    local yEnd = y0 + H - 6
    for i = 0, 2 do
      local y = y0 + 6 + i * 9
      local xb = tx + 40 + i * 22
      trace(dl, { { xR, y }, { xb, y }, { xb - (yEnd - y), yEnd } }, i == 1 and ACID or acid_a(0.6))
    end
  end
  R.ImGui_Dummy(ctx, w, H)
  local _, yb = R.ImGui_GetCursorScreenPos(ctx)
  R.ImGui_DrawList_AddLine(dl, x0, yb - 2, xR, yb - 2, acid_a(0.35), 1)
end

-- Section marker: small trace + title in mono
local function section(title)
  R.ImGui_Spacing(ctx)
  local dl = R.ImGui_GetWindowDrawList(ctx)
  local x, y = R.ImGui_GetCursorScreenPos(ctx)
  local pm = push_mono(-1)
  local lh = R.ImGui_GetTextLineHeight(ctx)
  trace(dl, { { x + 1, y + 1 }, { x + lh * 0.5, y + lh * 0.5 }, { x + 12, y + lh * 0.5 } }, acid_a(0.6))
  R.ImGui_Dummy(ctx, 20, lh)
  R.ImGui_SameLine(ctx)
  R.ImGui_TextColored(ctx, ACID, title)
  popf(pm)
end

--------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------
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

local function test_button(key, id)
  if R.ImGui_SmallButton(ctx, (S.test == key and "TEST OFF" or "  TEST  ") .. "##" .. id) then test_toggle(key) end
  tip(S.test == key and "End the test - font back to normal"
    or "Enlarge this font in the preview (double size, bold)\nto see where it is used in the REAPER window.")
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
  R.ImGui_SetNextItemWidth(ctx, width or 170)
  local k = font_combo("##ov" .. id, key_of_idx(curIdx), true, "(as theme)")
  if k == false then set_override(elem, nil)
  elseif k then
    local idx = idx_of_key(k)
    if idx then set_override(elem, idx) else set_status("Only WALTER fonts can be assigned to elements") end
  end
end

-- Edit block for one font: -/+, slider, bold/italic, reset
local function editor(key)
  local f = S.cur[key]; if not f then return end
  local b = S.base[key]
  local pb = push_bold(2)
  R.ImGui_TextColored(ctx, ACID, font_label(key))
  popf(pb)
  R.ImGui_SameLine(ctx)
  R.ImGui_TextDisabled(ctx, f.face .. "   (original " .. px(b) .. " px)")

  if R.ImGui_Button(ctx, " - ##ed") then set_font(key, function(x) x.height = with_px(x, px(x) - 1) end) end
  tip("1 pixel smaller")
  R.ImGui_SameLine(ctx)
  R.ImGui_SetNextItemWidth(ctx, 220)
  local ch, v = R.ImGui_SliderInt(ctx, "##px", px(f), 6, 48, "%d px")
  if ch then set_font(key, function(x) x.height = with_px(x, v) end) end
  tip("Font size in pixels (Ctrl+click: type a value).\nThe preview reloads when you release the mouse.")
  R.ImGui_SameLine(ctx)
  if R.ImGui_Button(ctx, " + ##ed") then set_font(key, function(x) x.height = with_px(x, px(x) + 1) end) end
  tip("1 pixel larger")
  R.ImGui_SameLine(ctx)
  local pm = push_mono()
  R.ImGui_Text(ctx, string.format("~%d pt", pt(f)))
  popf(pm)
  R.ImGui_SameLine(ctx)
  local cb, bold = R.ImGui_Checkbox(ctx, "Bold", f.weight >= 600)
  if cb then set_font(key, function(x) x.weight = bold and 700 or 400 end) end
  tip("Font weight bold / regular")
  R.ImGui_SameLine(ctx)
  local ci, it = R.ImGui_Checkbox(ctx, "Italic", f.italic)
  if ci then set_font(key, function(x) x.italic = it end) end
  tip("Italic style")
  R.ImGui_SameLine(ctx)
  test_button(key, "ed")
  if not font_same(f, b) then
    R.ImGui_SameLine(ctx)
    if R.ImGui_Button(ctx, "Reset##ed") then S.cur[key] = copy_font(b); touch() end
    tip("Reset this font to the value of the original theme")
  end

  local users = usage_of(key)
  if #users > 0 then
    local all = table.concat(users, ", ")
    R.ImGui_TextDisabled(ctx, "used by " .. #users .. " element" .. (#users == 1 and "" or "s") .. ": "
      .. all:sub(1, 150) .. (#all > 150 and " ..." or ""))
    tip(table.concat(users, "\n"))
  end
end

local function draw_target()
  local t = S.target
  section("TARGET")
  R.ImGui_SameLine(ctx)
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
  R.ImGui_SetNextItemWidth(ctx, 220)
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
  tip("Which font really controls this spot? If the detection is off,\n"
    .. "choose the right one here (check it with TEST).\n"
    .. "The choice is remembered for this theme.")
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
    local availW = R.ImGui_GetContentRegionAvail(ctx)
    for i, sl in ipairs(t.slots) do
      local f = S.cur[sl.key]
      local pm2 = push_mono()
      local label = string.format("%s%-15s %3d px  %s%s##t%d",
        sl.confirmed and "OK " or (sl.ovr and "EL " or "   "),
        font_label(sl.key), px(f), sl.elem or "", sl.via and (" = " .. sl.via) or "", i)
      if R.ImGui_Selectable(ctx, label, S.sel == sl.key, R.ImGui_SelectableFlags_AllowOverlap(),
          math.max(100, availW - 90), 0) then
        S.sel = sl.key
      end
      popf(pm2)
      tip(sl.confirmed and "Font chosen by you" or sl.ovr and "Element override"
        or "Computed from the rtconfig - click to edit")
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
      tip("Own WALTER font for " .. e .. " only.\nWritten to the working copy rtconfig"
        .. "\n(all layouts/scales). \"(as theme)\" removes it.")
    end
  end
end

-- Horizontal splitter: drag to change the height of the font list
local function splitter(id)
  local w = R.ImGui_GetContentRegionAvail(ctx)
  local x, y = R.ImGui_GetCursorScreenPos(ctx)
  R.ImGui_InvisibleButton(ctx, id, math.max(w, 1), 10)
  local hov, act = R.ImGui_IsItemHovered(ctx), R.ImGui_IsItemActive(ctx)
  if hov or act then R.ImGui_SetMouseCursor(ctx, R.ImGui_MouseCursor_ResizeNS()) end
  if act then
    local _, dy = R.ImGui_GetMouseDelta(ctx)
    OPT.listH = math.max(80, math.min(2000, OPT.listH + dy))
  end
  if R.ImGui_IsItemDeactivated(ctx) then save_opts() end
  local dl = R.ImGui_GetWindowDrawList(ctx)
  local col = (hov or act) and ACID or acid_a(0.35)
  local cy = y + 5
  R.ImGui_DrawList_AddLine(dl, x, cy, x + w, cy, col, (hov or act) and 2 or 1)
  local cx = x + w * 0.5
  for i = -1, 1 do R.ImGui_DrawList_AddCircleFilled(dl, cx + i * 9, cy, 2.2, col) end
  tip("Drag to change the height of the font list.\nDouble-click: default height.")
  if hov and R.ImGui_IsMouseDoubleClicked(ctx, 0) then OPT.listH = 230; save_opts() end
end

local function draw_list()
  local flags = R.ImGui_TableFlags_RowBg() | R.ImGui_TableFlags_BordersInnerH() | R.ImGui_TableFlags_ScrollY()
  if not R.ImGui_BeginTable(ctx, "fonts", 3, flags, 0, OPT.listH) then return end
  R.ImGui_TableSetupScrollFreeze(ctx, 0, 1)
  R.ImGui_TableSetupColumn(ctx, "Font / size / face", R.ImGui_TableColumnFlags_WidthStretch())
  R.ImGui_TableSetupColumn(ctx, "Elements", R.ImGui_TableColumnFlags_WidthFixed(), 70)
  R.ImGui_TableSetupColumn(ctx, "", R.ImGui_TableColumnFlags_WidthFixed(), 56)
  R.ImGui_TableHeadersRow(ctx)
  for _, key in ipairs(S.order) do
    R.ImGui_TableNextRow(ctx)
    R.ImGui_TableNextColumn(ctx)
    local pm = push_mono()
    if R.ImGui_Selectable(ctx, font_line(key) .. "##l" .. key, S.sel == key,
        R.ImGui_SelectableFlags_AllowOverlap()) then
      S.sel = key
    end
    popf(pm)
    tip("Click to edit (above, under EDIT)")
    R.ImGui_TableNextColumn(ctx)
    local u = usage_of(key)
    if #u > 0 then
      R.ImGui_TextDisabled(ctx, tostring(#u))
      tip("Elements in the default layout using this font:\n" .. table.concat(u, "\n"))
    end
    R.ImGui_TableNextColumn(ctx)
    if R.ImGui_SmallButton(ctx, "-##" .. key) then
      set_font(key, function(x) x.height = with_px(x, px(x) - 1) end)
    end
    tip("1 pixel smaller")
    R.ImGui_SameLine(ctx)
    if R.ImGui_SmallButton(ctx, "+##" .. key) then
      set_font(key, function(x) x.height = with_px(x, px(x) + 1) end)
    end
    tip("1 pixel larger")
  end
  R.ImGui_EndTable(ctx)
end

-- all elements of the default layout with their own font override
local function draw_elements()
  if not (S.T and S.T.rtc) then
    R.ImGui_TextDisabled(ctx, "This theme has no rtconfig - no elements.")
    return
  end
  R.ImGui_SetNextItemWidth(ctx, 240)
  local ch, v = R.ImGui_InputTextWithHint(ctx, "##ef", "Filter, e.g. mcp.fx", S.elemFilter)
  if ch then S.elemFilter = v end
  tip("Filter element names (substring)")
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
  if not R.ImGui_BeginTable(ctx, "elems", 3, flags, 0, math.max(160, availH - 2)) then return end
  R.ImGui_TableSetupScrollFreeze(ctx, 0, 1)
  R.ImGui_TableSetupColumn(ctx, "Element", R.ImGui_TableColumnFlags_WidthStretch())
  R.ImGui_TableSetupColumn(ctx, "Theme", R.ImGui_TableColumnFlags_WidthFixed(), 130)
  R.ImGui_TableSetupColumn(ctx, "Own font", R.ImGui_TableColumnFlags_WidthFixed(), 180)
  R.ImGui_TableHeadersRow(ctx)
  for i, e in ipairs(names) do
    R.ImGui_TableNextRow(ctx)
    R.ImGui_TableNextColumn(ctx)
    local pm = push_mono()
    R.ImGui_AlignTextToFramePadding(ctx)
    R.ImGui_TextColored(ctx, S.ovr[e] and ACID or WHITE, e)
    popf(pm)
    if S.elemVar[e] then tip("via variable " .. S.elemVar[e]) end
    R.ImGui_TableNextColumn(ctx)
    local idx = S.elemIdx[e]
    R.ImGui_TextDisabled(ctx, idx == 0 and "main font" or idx == -1 and "vol/pan" or font_label(key_of_idx(idx) or "?"))
    R.ImGui_TableNextColumn(ctx)
    ovr_combo(e, "l" .. i, -1)
    tip("Own WALTER font for this element only")
  end
  R.ImGui_EndTable(ctx)
end

local function draw_options()
  if R.ImGui_Button(ctx, "OPTIONS") then R.ImGui_OpenPopup(ctx, "tt_opts") end
  tip("Set font and size of this window")
  if R.ImGui_BeginPopup(ctx, "tt_opts") then
    section("OPTIONS")
    local changed = false
    R.ImGui_SetNextItemWidth(ctx, 200)
    if R.ImGui_BeginCombo(ctx, "Font", OPT.ui) then
      for _, u in ipairs(UI_FONTS) do
        if R.ImGui_Selectable(ctx, u.name, OPT.ui == u.name) then OPT.ui = u.name; changed = true end
      end
      R.ImGui_EndCombo(ctx)
    end
    tip("Font for texts and buttons of this window")
    R.ImGui_SetNextItemWidth(ctx, 200)
    local c1, v1 = R.ImGui_SliderInt(ctx, "Size##ui", OPT.size, 10, 22, "%d px")
    if c1 then OPT.size = v1; changed = true end
    tip("Font size for texts and buttons")
    R.ImGui_SetNextItemWidth(ctx, 200)
    if R.ImGui_BeginCombo(ctx, "Table font", OPT.mono) then
      for _, m in ipairs(MONO_FONTS) do
        if R.ImGui_Selectable(ctx, m.name, OPT.mono == m.name) then OPT.mono = m.name; changed = true end
      end
      R.ImGui_EndCombo(ctx)
    end
    tip("Fixed-width font for tables and status")
    R.ImGui_SetNextItemWidth(ctx, 200)
    local c2, v2 = R.ImGui_SliderInt(ctx, "Size##mono", OPT.msize, 9, 20, "%d px")
    if c2 then OPT.msize = v2; changed = true end
    tip("Font size for tables and status")
    if R.ImGui_Button(ctx, "Defaults") then
      OPT.ui, OPT.size, OPT.mono, OPT.msize = "Liberation Sans", 14, "Liberation Mono", 13
      changed = true
    end
    tip("Liberation Sans 14 / Liberation Mono 13")
    if changed then save_opts() end
    R.ImGui_EndPopup(ctx)
  end
end

local function draw_theme_chooser()
  R.ImGui_TextColored(ctx, ACID, "No readable theme active.")
  R.ImGui_TextWrapped(ctx, "Choose a theme to edit (it will be loaded):")
  local dir = RES .. "/ColorThemes/"
  if R.ImGui_BeginChild(ctx, "themes", 0, 260) then
    for _, f in ipairs(list_themes(dir)) do
      if R.ImGui_Selectable(ctx, f) then
        if R.OpenColorThemeFile(dir .. f) then init_theme(dir .. f)
        else set_status("Loading failed: " .. f) end
      end
    end
    R.ImGui_EndChild(ctx)
  end
end

local function draw_footer()
  R.ImGui_Separator(ctx)
  if S.job then
    local frac = S.job.total > 0 and (S.job.pos / S.job.total) or 0
    R.ImGui_ProgressBar(ctx, frac, -1, 0, string.format("%s  %d / %d", S.job.name, S.job.pos, S.job.total))
  end
  local pm = push_mono()
  local dl = R.ImGui_GetWindowDrawList(ctx)
  local sx, sy = R.ImGui_GetCursorScreenPos(ctx)
  local lh = R.ImGui_GetTextLineHeight(ctx)
  trace(dl, { { sx + 2, sy }, { sx + 2 + lh * 0.5, sy + lh * 0.5 }, { sx + 14, sy + lh * 0.5 } }, acid_a(0.6))
  R.ImGui_Dummy(ctx, 22, lh)
  R.ImGui_SameLine(ctx)
  R.ImGui_TextColored(ctx, ACID, "STATUS //")
  R.ImGui_SameLine(ctx)
  R.ImGui_TextWrapped(ctx, S.status)
  popf(pm)
end

local function draw_actions()
  local n = changed_count()
  local busy = S.job ~= nil
  if busy then R.ImGui_BeginDisabled(ctx) end
  if n == 0 then R.ImGui_BeginDisabled(ctx) end
  local pb = push_bold(1)
  if R.ImGui_Button(ctx, "  BAKE THEME  ") then
    S.test = nil
    if S.dirtyAt then apply_preview() end
    start_bake()
  end
  popf(pb)
  tip("Write a new theme with all changes and load it:\n"
    .. select(2, split_path(bake_path(S.orig, S.T.zip or next(S.ovr) ~= nil)))
    .. "\nThe original stays untouched.")
  R.ImGui_SameLine(ctx)
  if R.ImGui_Button(ctx, "Discard") then discard() end
  tip("Discard all changes and load the original theme again")
  if n == 0 then R.ImGui_EndDisabled(ctx) end
  R.ImGui_SameLine(ctx)
  if R.ImGui_Button(ctx, "Reload") then init_theme(R.GetLastColorThemeFile()) end
  tip("Read the active theme again (e.g. after switching themes in REAPER\nor changing the UI scale)")
  if busy then R.ImGui_EndDisabled(ctx) end
  R.ImGui_SameLine(ctx)
  local pm = push_mono()
  R.ImGui_TextColored(ctx, n > 0 and ACID or GREY, n .. " change" .. (n == 1 and "" or "s")
    .. (S.dirtyAt and "  (preview pending)" or ""))
  popf(pm)
end

local function draw_main()
  S.guiHovered = R.ImGui_IsWindowHovered(ctx, R.ImGui_HoveredFlags_RootAndChildWindows())
  draw_header()

  if not S.T then
    draw_theme_chooser()
    draw_footer()
    return
  end

  R.ImGui_Text(ctx, "Theme: " .. select(2, split_path(S.orig)))
  R.ImGui_SameLine(ctx)
  local pm = push_mono()
  R.ImGui_TextColored(ctx, ACID, string.format("SCALE %d%% -> layout %s", math.floor(S.uiscale * 100 + 0.5),
    S.defLayout ~= "" and S.defLayout or "default"))
  popf(pm)
  tip("UI scale from the REAPER preferences and the mixer layout\n"
    .. "used to compute the fonts")
  if S.wcLoaded then
    R.ImGui_SameLine(ctx)
    R.ImGui_TextDisabled(ctx, "- preview active")
    tip("REAPER is showing the working copy with your changes")
  end

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
      tip("Loads " .. select(2, split_path(legacy)) .. "\nFont changes of the old copy are not carried over.")
    end
  end

  -- picker + options
  if picker.armed then
    if R.ImGui_Button(ctx, "Cancel picker") then picker.armed = false; S.hover = nil end
    tip("Stop the picker without locking a target")
    R.ImGui_SameLine(ctx)
    local pb = push_bold()
    R.ImGui_TextColored(ctx, ACID, "Hover over text in the REAPER window - click or SHIFT locks it")
    popf(pb)
  else
    local pb = push_bold(1)
    if R.ImGui_Button(ctx, "  PICKER  ") then
      if not R.GetThingFromPoint then set_status("The picker needs REAPER 6.x+ (GetThingFromPoint)")
      else picker.armed = true; picker.down = false; picker.shift = true; S.hover = nil end
    end
    popf(pb)
    tip("Find a spot in the theme: move the mouse over a text in the REAPER window.\n"
      .. "SHIFT locks it without triggering anything in REAPER; a click works too.")
    R.ImGui_SameLine(ctx)
    R.ImGui_TextDisabled(ctx, "Find a spot in the theme")
  end
  R.ImGui_SameLine(ctx)
  local ow = R.ImGui_CalcTextSize(ctx, "OPTIONS") + 16
  R.ImGui_SetCursorPosX(ctx, math.max(R.ImGui_GetCursorPosX(ctx), R.ImGui_GetWindowWidth(ctx) - ow - 12))
  draw_options()

  -- scrolling body; actions + status stay visible at the bottom
  local footH = R.ImGui_GetFrameHeightWithSpacing(ctx) * 2 + R.ImGui_GetTextLineHeightWithSpacing(ctx) * 2 + 12
  if R.ImGui_BeginChild(ctx, "body", 0, -footH) then
    if S.target then draw_target() end
    if S.sel and S.cur[S.sel] then
      section("EDIT")
      editor(S.sel)
    end
    section("ALL FONTS")
    draw_list()
    splitter("##split")
    if R.ImGui_CollapsingHeader(ctx, "ELEMENT OVERRIDES") then draw_elements() end
    tip("Give any WALTER element (mcp.fxlist, tcp.label ...) a font of its own -\n"
      .. "independent of other elements using the same font.")
    R.ImGui_EndChild(ctx)
  end

  draw_actions()
  draw_footer()
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

local function frame()
  local nc, nv = push_theme()
  local pf = pushf(FONTS.ui[OPT.ui], OPT.size)
  R.ImGui_SetNextWindowSize(ctx, 800, 820, R.ImGui_Cond_FirstUseEver())
  local visible, open = R.ImGui_Begin(ctx, "TT Theme Font Editor", true)
  local ok, err = true, nil
  if visible then
    ok, err = pcall(draw_main)
    R.ImGui_End(ctx)
  end
  local ok2, err2 = pcall(draw_hover_tag)
  popf(pf)
  R.ImGui_PopStyleVar(ctx, nv)
  R.ImGui_PopStyleColor(ctx, nc)
  if not ok then error(err, 0) end
  if not ok2 then error(err2, 0) end
  return open
end

local errCount = 0
local function loop()
  pick_poll()
  run_job()
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
    if changed_count() > 0 and S.wcLoaded then
      tlog("closed with unsaved changes - preview stays active")
    end
    return
  end
  R.defer(loop)
end

local function main()
  if not R.ImGui_CreateContext then
    R.MB("ReaImGui is missing (install it via ReaPack).", "TT Theme Font Editor", 0) return
  end
  io.open(LOGF, "w"):close()
  load_opts()
  init_theme(R.GetLastColorThemeFile())
  ctx = R.ImGui_CreateContext("TT Theme Font Editor")
  init_fonts()
  R.defer(loop)
end

main()
