-- @description TT-BPM2MS2HZ (note values to milliseconds and Hertz)
-- @author Tim Techlor
-- @version 1.5.0
-- @license MIT
-- @provides
--   TT_Wordmark.png
--   bpm2ms2hz-manual.html
--   img/bpm2ms2hz/bpm2ms2hz-web-console.png
--   img/bpm2ms2hz/tt-bpm2ms2hz-front.png
--   img/bpm2ms2hz/tt-bpm2ms2hz-options.png
--   img/bpm2ms2hz/tt-bpm2ms2hz-wide-bars.png
-- @about
--   # TT-BPM2MS2HZ
--
--   Converts note values at the project tempo into milliseconds and Hertz,
--   in a tool window drawn in the TimTechlor UI kit look (ReaImGui).
--
--   - The tempo follows the project by default; the slider switches to a
--     manual tempo, FROM PROJECT switches back to sync.
--   - Click any value to copy it to the clipboard.
--   - Tabs: NOTE VALUES (1/1 to 1/32, dotted, triplets) and BARS (1 to 64
--     bars, selectable time signature).
--   - OPTIONS: tooltips on/off, AUTO FIT, UI size, font size, dotted and
--     triplet rows, wordmark watermark. All settings are saved.
--
--   Manual: bpm2ms2hz-manual.html next to the script.
--
--   Requires the ReaPack extension "ReaImGui: ReaScript binding for Dear
--   ImGui" (cfillion, repository "ReaTeam Extensions").
-- @changelog
--   v1.5.0
--   - New name: TT-BPM2MS2HZ (formerly "BPM2MS2HZ Calculator"); file name and saved settings stay the same.
--   - New look after the TT UI kit 7: panels, LED switches, tempo slider and value tables drawn like the TimTechlor plugins.
--   - Every control has a tooltip; OPTIONS > TOOLTIPS ON / OFF switches them off (saved).
--   - NEW: OPTIONS > AUTO FIT ON / OFF (default on): dragging the window edge rescales the UI to the new window size (25 to 400 %); the UI SIZE buttons 100 / 125 / 150 / 200 / 300 % resize the window. Saved.
--   - Wide windows show the tempo panel and the table side by side.
--   - Mouse wheel over the tempo slider: 1 BPM per step (Shift: 0.1 BPM).
--   - Version shown in the window header.
--[[====================================================================
  TT-BPM2MS2HZ for REAPER  ·  GUI  ·  v1.5.0
  =====================================================================
  Converts note values at the project tempo into milliseconds and Hertz.

    ms  =  60000 / BPM * beats      (1 beat = 1 quarter note)
    Hz  =  1000 / ms

  Structure:
    - Data and calculation: DIVISIONS, VARIANTS,
      BAR_COUNTS, SIGNATURES, note_rows(), bar_rows().
    - UI kit layer: copy of the TimTechlor UI kit 7 layer,
      rewritten for the ImGui shim (require 'imgui' '0.10').
      Drawing happens in the design grid via the DrawList,
      the scale follows the window size (AUTO FIT).
    - Classic view as a fallback if the
      kit view throws an error (message in the REAPER console).
  Settings: ExtState namespace 'TT_BPM_Calculator' (do not
  change), keys: tips, autofit, zoom, layout = '3'.
  Test hook: global table TT_BPM2MS2HZ_HOOK (tests/screenshots only):
    .defaults (do not load settings), .nosave (save nothing),
    .notitle (window without title bar), .diag (receives sc/mode/W/H each
    frame), .pending = { tab = 1|2, options = bool, winsize = {w, h},
    winpos = {x, y} }
    is applied in the next frame and cleared.

  Requires: ReaPack -> "Dear ImGui bindings" (cfillion)
  https://github.com/cfillion/reaimgui
  Optional: TT_Wordmark.png next to this script (watermark)
====================================================================]]

local VERSION = "1.5.0"

--------------------------------------------------------------------
-- Load ImGui (ReaPack package "Dear ImGui bindings")
--------------------------------------------------------------------
local ok, ImGui = pcall(function()
  package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
  return require('imgui') '0.10'
end)

if not ok then
  reaper.MB(
    'This script requires the "Dear ImGui bindings" by cfillion.\n\n' ..
    'Install them via ReaPack:\n' ..
    'Extensions -> ReaPack -> Browse Packages -> "Dear ImGui" -> Install.',
    'TT-BPM2MS2HZ', 0)
  return
end

local HOOK = TT_BPM2MS2HZ_HOOK   -- nil in normal operation

--------------------------------------------------------------------
-- Constants & palette (Tim Techlor design guide)
--------------------------------------------------------------------
local WINDOW_TITLE = "TT-BPM2MS2HZ"
local WORDMARK_ASPECT = 1120 / 107   -- TT_Wordmark.png

local rgba = function(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a)
end

-- Core Black / Core White / Acid Green (#39FF14)
local ACID       = rgba(0.224, 1.000, 0.078, 1.0)
local ACID_SOFT  = rgba(0.180, 0.640, 0.110, 1.0)   -- dimmed acid green
local ACID_FAINT = rgba(0.224, 1.000, 0.078, 0.22)  -- decorative lines
local ACID_PAD   = rgba(0.224, 1.000, 0.078, 0.50)  -- solder pads
local WHITE      = rgba(0.930, 0.930, 0.930, 1.0)
local DIM        = rgba(0.470, 0.480, 0.490, 1.0)
local BLACK      = rgba(0.016, 0.016, 0.020, 1.0)
local PANEL      = rgba(0.055, 0.058, 0.063, 1.0)
local LINE       = rgba(0.145, 0.145, 0.150, 1.0)
local ACID_DARK  = rgba(0.090, 0.250, 0.050, 0.850)
local TITLE_BG   = rgba(0.024, 0.024, 0.027, 1.0)

local DIVISIONS  = { 1, 2, 4, 8, 16, 32 }
local BAR_COUNTS = { 1, 2, 4, 8, 16, 32, 64 }
local SIGNATURES = { { 4, 4 }, { 3, 4 }, { 5, 4 }, { 7, 4 },
                     { 6, 8 }, { 9, 8 }, { 12, 8 } }

local VARIANTS = {
  { suffix = '',  factor = 1,     color = ACID,  soft = ACID_SOFT, kind = 'full'    }, -- full note value
  { suffix = '.', factor = 1.5,   color = DIM,   soft = nil,       kind = 'dotted'  }, -- dotted
  { suffix = 'T', factor = 2 / 3, color = WHITE, soft = nil,       kind = 'triplet' }, -- triplet
}

local state = {
  bpm        = reaper.Master_GetTempo(),
  sync       = true,
  sig_ix     = 1,
  toast      = nil,
  toast_t    = 0,
  last_bpm   = nil,
  flash_t    = 0,
  font_scale = 1.0,
  dotted     = true,
  triplet    = true,
  watermark  = true,
  --
  tab        = 1,      -- 1 = NOTE VALUES, 2 = BARS (not saved)
  options    = false,  -- OPTIONS box open
  tips       = true,
  autofit    = true,
  zoom       = 1.0,
}

--------------------------------------------------------------------
-- Persistent settings (survive REAPER restarts via ExtState)
--------------------------------------------------------------------
local SETTINGS = 'TT_BPM_Calculator'

local function save_settings()
  if HOOK and HOOK.nosave then return end   -- screenshot run: do not touch the user's settings
  reaper.SetExtState(SETTINGS, 'font_scale', string.format('%.2f', state.font_scale), true)
  reaper.SetExtState(SETTINGS, 'dotted',    state.dotted    and '1' or '0', true)
  reaper.SetExtState(SETTINGS, 'triplet',   state.triplet   and '1' or '0', true)
  reaper.SetExtState(SETTINGS, 'watermark', state.watermark and '1' or '0', true)
  reaper.SetExtState(SETTINGS, 'sig_ix',    tostring(state.sig_ix), true)
  --
  reaper.SetExtState(SETTINGS, 'tips',      state.tips      and '1' or '0', true)
  reaper.SetExtState(SETTINGS, 'autofit',   state.autofit   and '1' or '0', true)
  reaper.SetExtState(SETTINGS, 'zoom',      string.format('%.2f', state.zoom), true)
end

local function load_settings()
  local function get(key)
    return reaper.GetExtState(SETTINGS, key)
  end

  local scale = tonumber(get('font_scale'))
  if scale then
    state.font_scale = math.min(1.50, math.max(0.80, scale))
  end

  if get('dotted')    ~= '' then state.dotted    = get('dotted')    == '1' end
  if get('triplet')   ~= '' then state.triplet   = get('triplet')   == '1' end
  if get('watermark') ~= '' then state.watermark = get('watermark') == '1' end
  if get('tips')      ~= '' then state.tips      = get('tips')      == '1' end
  if get('autofit')   ~= '' then state.autofit   = get('autofit')   == '1' end

  local zoom = tonumber(get('zoom'))
  if zoom then
    state.zoom = math.min(4.0, math.max(0.25, zoom))
  end

  local sig = tonumber(get('sig_ix'))
  if sig and sig >= 1 and sig <= #SIGNATURES then
    state.sig_ix = math.floor(sig + 0.5)
  end
end

if not (HOOK and HOOK.defaults) then load_settings() end

-- Scaled font size helper (adjusted via OPTIONS)
local function fs(base)
  return math.floor(base * state.font_scale + 0.5)
end

-- Column width helper: base widths in px at 100% font scale
-- (labels: "1/16." = 56, "64 bars" = 74; values: "2812.5" = 64)
local function col_w(base)
  return math.floor(base * state.font_scale + 0.5)
end

--------------------------------------------------------------------
-- Calculation (extracted as a row list)
--------------------------------------------------------------------
-- Note values: up to three variants per division; text as copied to the clipboard (%.1f ms, %.3f Hz)
local function note_rows()
  local beat_ms = 60000 / state.bpm
  local rows = {}
  for _, division in ipairs(DIVISIONS) do
    local beats = 4 / division
    for _, variant in ipairs(VARIANTS) do
      local enabled = (variant.suffix == '') or
                      (variant.suffix == '.' and state.dotted) or
                      (variant.suffix == 'T' and state.triplet)
      if enabled then
        local ms = beat_ms * beats * variant.factor
        local hz = 1000 / ms
        rows[#rows + 1] = {
          label = string.format('1/%d%s', division, variant.suffix),
          variant = variant,
          a = string.format('%.1f', ms), b = string.format('%.3f', hz),
        }
      end
    end
  end
  return rows
end

-- Bars: bar length from the time signature (6/8 = six eighths), seconds and Hz with %.3f
local function bar_rows()
  local sig = SIGNATURES[state.sig_ix]
  local beat_sec = 60 / state.bpm
  local bar_beats = sig[1] * 4 / sig[2]
  local rows = {}
  for _, count in ipairs(BAR_COUNTS) do
    local sec = beat_sec * bar_beats * count
    local hz  = 1 / sec
    rows[#rows + 1] = {
      label = (count == 1) and '1 bar' or string.format('%d bars', count),
      a = string.format('%.3f', sec), b = string.format('%.3f', hz),
    }
  end
  return rows
end

--------------------------------------------------------------------
-- Fonts & context
--------------------------------------------------------------------
local font_ui     = ImGui.CreateFont('sans-serif')
local font_bold   = ImGui.CreateFont('sans-serif', ImGui.FontFlags_Bold)
local font_mono   = ImGui.CreateFont('monospace')
local font_mono_b = ImGui.CreateFont('monospace', ImGui.FontFlags_Bold)

-- Brand wordmark: Zilap Orion (installed variants), fallback sans bold
local font_brand
do
  local candidates = { 'Zilap Orion Urban', 'Zilap Orion Futuristic',
                       'Zilap Orion Linear' }
  for _, family in ipairs(candidates) do
    local ok_font, font = pcall(ImGui.CreateFont, family)
    if ok_font and font then
      font_brand = font
      break
    end
  end
  font_brand = font_brand or font_bold
end

-- Kit font: Inter Medium (Windows font folder, user fonts, macOS); otherwise the system font
local FONT_UI
do
  local cands = {
    (os.getenv("WINDIR") or "C:/Windows") .. "/Fonts/Inter-Medium.ttf",
    (os.getenv("LOCALAPPDATA") or "") .. "/Microsoft/Windows/Fonts/Inter-Medium.ttf",
    (os.getenv("HOME") or "") .. "/Library/Fonts/Inter-Medium.ttf",
    "/Library/Fonts/Inter-Medium.ttf",
  }
  for _, d in ipairs(cands) do
    local f = io.open(d, "rb")
    if f then
      f:close()
      local ok_f, fo = pcall(ImGui.CreateFontFromFile, d, 0)
      if ok_f and fo then FONT_UI = fo; break end
    end
  end
  FONT_UI = FONT_UI or font_ui
end

local ctx = ImGui.CreateContext(WINDOW_TITLE)
ImGui.Attach(ctx, font_ui)
ImGui.Attach(ctx, font_bold)
ImGui.Attach(ctx, font_mono)
ImGui.Attach(ctx, font_mono_b)
if font_brand ~= font_bold then ImGui.Attach(ctx, font_brand) end
if FONT_UI ~= font_ui then ImGui.Attach(ctx, FONT_UI) end

-- Branding asset: rendered wordmark, searched next to this script first,
-- then in the REAPER Scripts folder
local function find_asset(name)
  local script_src = debug.getinfo(1, 'S').source
  local script_dir = script_src:match('@?(.*[/\\])') or ''
  local candidates = {
    script_dir .. name,
    reaper.GetResourcePath() .. '/Scripts/' .. name,
  }
  for _, path in ipairs(candidates) do
    local file = io.open(path, 'rb')
    if file then
      file:close()
      return path
    end
  end
  return nil
end

local function load_image(name)
  local path = find_asset(name)
  if not path then
    return nil
  end
  local ok_img, image = pcall(ImGui.CreateImage, path)
  if ok_img and image then
    ImGui.Attach(ctx, image)
    return image
  end
  return nil
end

local wordmark = load_image('TT_Wordmark.png')

--------------------------------------------------------------------
-- Copy helper (shared by both views)
--------------------------------------------------------------------
local function copy_value(value)
  ImGui.SetClipboardText(ctx, value)
  state.toast   = value
  state.toast_t = os.clock()
end

local function set_sync(sync)
  state.sync = sync
  if sync then state.bpm = reaper.Master_GetTempo() end
end

local function set_manual_bpm(bpm)
  state.bpm  = math.floor(math.min(300, math.max(40, bpm)) * 10 + 0.5) / 10
  state.sync = false
end

-- ==================================================================================================================
-- UI kit 7 look: copy of the TimTechlor UI kit 7 layer, rewritten for the ImGui shim
-- (R.ImGui_X(...) -> ImGui.X(...), constants as
-- values). Differences from the original, otherwise identical:
--   * ptext/tw: optional font key (FONTS: ui, mono, monob) for the number columns
--   * hit: minimum size 1 px (InvisibleButton requires w, h > 0)
--   * tipfor: switch state.tips instead of TIPS_ON
--   * dropped: knob (no rotary knob here)
-- The widgets follow the UI kit 7 widgets: panel, led, btn, toggle, hslider; tooltips after 0.35 s,
-- drag with Shift = fine, right/double/Ctrl click = default value, mouse wheel.
-- ==================================================================================================================
local floor = math.floor
local UK = { sc = 1, ox = 0, oy = 0, dl = nil, ar = 0.2235, ag = 1.0, ab = 0.0784, mxd = 0, myd = 0, shift = false, ctrl = false }
local DRAGS = {}
local HOVER = { id = nil, t = 0 }
local KIT_ERR = nil
local FONTS = { ui = FONT_UI, mono = font_mono, monob = font_mono_b }

local function f255(v) if v < 0 then v = 0 elseif v > 1 then v = 1 end return floor(v * 255 + 0.5) end
local function C(r, g, b, a) return (f255(r) << 24) | (f255(g) << 16) | (f255(b) << 8) | f255(a or 1) end
local function acid(a) return C(UK.ar, UK.ag, UK.ab, a) end
local function dimc(a) return C(UK.ar * 0.58, UK.ag * 0.57, UK.ab * 0.55, a) end
local function tone(g, t, a) return C(g + (UK.ar - g) * t, g + (UK.ag - g) * t, g + (UK.ab - g) * t, a) end

local function X(x) return UK.ox + x * UK.sc end
local function Y(y) return UK.oy + y * UK.sc end
local function Z(v) return v * UK.sc end
local function lw() local w = floor(UK.sc + 0.5); return w < 1 and 1 or w end

-- ---- Text (pixel size = design size * scale, rounded to an integer)
local TWC = {}
local function tw(s, size, font)
  size = size or 13
  font = font or 'ui'
  local k = font .. "|" .. size .. "|" .. s
  local v = TWC[k]
  if not v then
    ImGui.PushFont(ctx, FONTS[font], size); UK.fonts = (UK.fonts or 0) + 1
    v = ImGui.CalcTextSize(ctx, s)
    ImGui.PopFont(ctx); UK.fonts = UK.fonts - 1
    TWC[k] = v
  end
  return v
end
local function ptext(x, y, s, colr, size, font)
  size = size or 13
  local px = floor(size * UK.sc + 0.5)
  if px < 8 then px = 8 end
  ImGui.PushFont(ctx, FONTS[font or 'ui'], px); UK.fonts = (UK.fonts or 0) + 1
  ImGui.DrawList_AddText(UK.dl, X(x), Y(y), colr, s)
  ImGui.PopFont(ctx); UK.fonts = UK.fonts - 1
end
local function ptext_c(cx, y, s, colr, size, font) ptext(cx - tw(s, size, font) / 2, y, s, colr, size, font) end
local function ptext_r(rx, y, s, colr, size, font) ptext(rx - tw(s, size, font), y, s, colr, size, font) end
local function spaced(x, y, s, colr, size, sp)
  for ch in s:gmatch(".") do
    ptext(x, y, ch, colr, size)
    x = x + tw(ch, size) + sp
  end
  return x
end

-- ---- Primitives
local function rfill(x, y, w, h, colr, r)
  ImGui.DrawList_AddRectFilled(UK.dl, X(x), Y(y), X(x + w), Y(y + h), colr, Z(r or 0))
end
local function rline(x, y, w, h, colr, r)
  local o = lw() * 0.5
  ImGui.DrawList_AddRect(UK.dl, X(x) + o, Y(y) + o, X(x + w) - o, Y(y + h) - o, colr, Z(r or 0), 0, lw())
end
local function circ(cx, cy, r, colr) ImGui.DrawList_AddCircleFilled(UK.dl, X(cx), Y(cy), Z(r), colr, 0) end
local function line(x1, y1, x2, y2, colr, th) ImGui.DrawList_AddLine(UK.dl, X(x1), Y(y1), X(x2), Y(y2), colr, th or lw()) end
-- vertical gradient, also with rounded corners (bands with a clip rectangle)
local function grad(x, y, w, h, r1, g1, b1, r2, g2, b2, rad, a)
  if (rad or 0) == 0 then
    local c1, c2 = C(r1, g1, b1, a), C(r2, g2, b2, a)
    ImGui.DrawList_AddRectFilledMultiColor(UK.dl, X(x), Y(y), X(x + w), Y(y + h), c1, c1, c2, c2)
    return
  end
  local n = floor(h * UK.sc / 4)
  if n < 2 then n = 2 elseif n > 12 then n = 12 end
  for k = 0, n - 1 do
    local f = (k + 0.5) / n
    local colr = C(r1 + (r2 - r1) * f, g1 + (g2 - g1) * f, b1 + (b2 - b1) * f, a)
    ImGui.DrawList_PushClipRect(UK.dl, X(x) - 2, Y(y + h * k / n), X(x + w) + 2, Y(y + h * (k + 1) / n) + 0.5, true); UK.clips = (UK.clips or 0) + 1
    ImGui.DrawList_AddRectFilled(UK.dl, X(x), Y(y), X(x + w), Y(y + h), colr, Z(rad))
    ImGui.DrawList_PopClipRect(UK.dl); UK.clips = UK.clips - 1
  end
end

-- ---- Input
local function hit(id, x, y, w, h)
  ImGui.SetCursorScreenPos(ctx, X(x), Y(y))
  ImGui.InvisibleButton(ctx, id, math.max(1, Z(w)), math.max(1, Z(h)))
  return ImGui.IsItemHovered(ctx), ImGui.IsItemActive(ctx)
end
local function tipfor(id, s)
  if not state.tips or not s then return end
  if ImGui.IsItemHovered(ctx) and not ImGui.IsMouseDown(ctx, 0) then
    local now = reaper.time_precise()
    if HOVER.id ~= id then HOVER.id = id; HOVER.t = now end
    if now - HOVER.t > 0.35 then ImGui.SetTooltip(ctx, s) end
  elseif HOVER.id == id then
    HOVER.id = nil
  end
end

-- ---- Widgets
local function panel(x, y, w, h, title)
  for j = 0, 5 do
    local e = 6 - j
    ImGui.DrawList_AddRect(UK.dl, X(x) - Z(e), Y(y) - Z(e) + Z(3), X(x + w) + Z(e), Y(y + h) + Z(e) + Z(3),
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

local function btn(id, x, y, w, h, label, on, prim, tiptxt)
  local hov, act = hit(id, x, y, w, h)
  local clicked = ImGui.IsItemActivated(ctx)
  if on then
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
  local clicked = ImGui.IsItemActivated(ctx)
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

-- Slider drawing of the kit (hslider), here without its own input: the tempo input sets the value absolutely from
-- the mouse position (see tempo_slider), so only the drawing is used.
local function hslider_draw(x, y, w, h, t, hot)
  local ty = y + h * 0.5 - 2
  rfill(x - 1, ty - 1, w + 2, 6, C(0, 0, 0, 0.5), 3)
  rfill(x, ty, w, 4, C(0.035, 0.038, 0.035), 2)
  if t > 0.004 then rfill(x, ty, math.max(4, w * t), 4, acid(0.95), 2) end
  local hx = x + t * w
  rfill(hx - 4.5, y + 1.5, 10, h, C(0, 0, 0, 0.45), 3)
  if hot then grad(hx - 5, y, 10, h, 0.36, 0.38, 0.36, 0.20, 0.21, 0.20, 2)
  else grad(hx - 5, y, 10, h, 0.28, 0.30, 0.28, 0.15, 0.16, 0.15, 2) end
  rfill(hx - 4, y, 8, 1, C(1, 1, 1, 0.22))
  rfill(hx - 0.5, y + 2, 1, h - 4, acid(1))
end
-- ==================================================================================================================
-- End of the kit layer
-- ==================================================================================================================

--------------------------------------------------------------------
-- Kit view: layout in the design grid (values at 100 % UI size)
--------------------------------------------------------------------
local MARG, GAP, HEAD, FOOT = 12, 10, 40, 34
local COL1 = 336              -- width of the table column (and of the single-column view)
local COL_T = 300             -- width of the tempo panel in the wide view
local TABS_H = 24
local OPT_W, OPT_H = 318, 196 -- OPTIONS box
local ZOOMS = { 1.0, 1.25, 1.5, 2.0, 3.0 }
local WIN_RESIZE = nil        -- factor applied to the window size in the next frame
local WIN_DES = nil           -- { design width, design height, margin x, margin y } from the last frame
local HOLD = nil              -- zoom button with AUTO FIT on: the zoom holds until the next window change
local WIN_SET = nil           -- fixed window size for the next frame (test hook only)
local WIN_POS = nil           -- fixed window position for the next frame (test hook only)
local GRAY = C(0.45, 0.48, 0.45)

-- Variant colors in the kit (full = acid, dotted = gray, triplet = white)
local KV = {
  full    = { label = function() return acid(1) end,              value = function() return C(0.180, 0.640, 0.110) end },
  dotted  = { label = function() return C(0.47, 0.48, 0.49) end,  value = function() return C(0.86, 0.90, 0.85) end },
  triplet = { label = function() return C(0.93, 0.93, 0.93) end,  value = function() return C(0.86, 0.90, 0.85) end },
}

local function sizes()
  local f = state.font_scale
  local z = {
    bpm  = 34 * f,             -- large tempo number (mono bold)
    info = 11 * f,             -- info lines below the slider
    row  = floor(17 * f + 0.5),-- table row
    tbl  = 13 * f,             -- table text (mono)
    hdr  = 11 * f,             -- column header
  }
  z.tempo_h = 30 + z.bpm * 1.2 + 6 + 22 + 10 + 18 + 10 + 2 * (z.info + 5) + 6
  return z
end

local function n_note_rows()
  return #DIVISIONS * (1 + (state.dotted and 1 or 0) + (state.triplet and 1 or 0))
end

local function table_h(z)
  -- always the larger of the two tables, so that a tab change does not change the scale
  local notes = 30 + z.hdr + 10 + n_note_rows() * z.row + 8
  local bars = 30 + 30 + z.hdr + 10 + #BAR_COUNTS * z.row + 8
  return math.max(notes, bars)
end

-- mode 1 = one column (narrow/tall), mode 2 = tempo on the left, table on the right (wide)
local function layout_for(mode, z)
  local th = table_h(z)
  if mode == 2 then
    local W = MARG + COL_T + GAP + COL1 + MARG
    local body = math.max(z.tempo_h, TABS_H + 6 + th)
    return {
      W = W, H = HEAD + body + GAP + FOOT,
      tempo = { MARG, HEAD, COL_T, z.tempo_h },
      tabs  = { MARG + COL_T + GAP, HEAD, COL1 },
      tbl   = { MARG + COL_T + GAP, HEAD + TABS_H + 6, COL1, th },
    }
  end
  local W = MARG + COL1 + MARG
  local ty = HEAD + z.tempo_h + GAP
  return {
    W = W, H = ty + TABS_H + 6 + th + GAP + FOOT,
    tempo = { MARG, HEAD, COL1, z.tempo_h },
    tabs  = { MARG, ty, COL1 },
    tbl   = { MARG, ty + TABS_H + 6, COL1, th },
  }
end

-- ---- Background, header, footer
local function ground(cw, ch)
  local dl, ox, oy = UK.dl, UK.gx, UK.gy
  local top, bot = C(0.068, 0.073, 0.068), C(0.038, 0.041, 0.038)
  ImGui.DrawList_AddRectFilledMultiColor(dl, ox, oy, ox + cw, oy + ch, top, top, bot, bot)
  local bw = math.max(24, math.min(cw, ch) * 0.09)
  local k, zz = C(0, 0, 0, 0.34), C(0, 0, 0, 0)
  ImGui.DrawList_AddRectFilledMultiColor(dl, ox, oy, ox + cw, oy + bw, k, k, zz, zz)
  ImGui.DrawList_AddRectFilledMultiColor(dl, ox, oy + ch - bw, ox + cw, oy + ch, zz, zz, k, k)
  ImGui.DrawList_AddRectFilledMultiColor(dl, ox, oy, ox + bw, oy + ch, k, zz, zz, k)
  ImGui.DrawList_AddRectFilledMultiColor(dl, ox + cw - bw, oy, ox + cw, oy + ch, zz, k, k, zz)
end

-- Watermark (OPTIONS > WATERMARK): faint wordmark image at the bottom right
local function watermark_draw(W, H)
  if not (wordmark and state.watermark) then return end
  local wm_w = math.min(W * 0.9, 300)
  local wm_h = wm_w / WORDMARK_ASPECT
  local x, y = W - wm_w - 20, H - FOOT - wm_h - 8
  ImGui.DrawList_AddImage(UK.dl, wordmark, X(x), Y(y), X(x + wm_w), Y(y + wm_h), 0, 0, 1, 1, C(1, 1, 1, 0.05))
end

local function header(W)
  local x = spaced(MARG, 11, "TT-BPM2MS2HZ", acid(1), 17, 1.6)
  ptext(x + 8, 16, "v" .. VERSION, GRAY, 11)
  if btn("b_options", W - MARG - 76, 9, 76, 22, "OPTIONS", state.options, true,
      "Show or hide OPTIONS: tooltips, AUTO FIT, UI size, font size, note variants and watermark.") then
    state.options = not state.options
  end
  rfill(MARG, HEAD - 5, W - 2 * MARG, 1, dimc(0.35))
end

-- Circuit traces with solder pads (decoration)
local function traces(x, y)
  for i = 0, 2 do
    local bx = x + i * 16
    line(bx, y, bx + 10, y - 10, acid(0.22))
    circ(bx + 11.5, y - 11.5, 1.6, acid(0.50))
  end
end

local function footer(W, y)
  local gw = W - 2 * MARG
  ImGui.DrawList_AddRectFilledMultiColor(UK.dl, X(MARG), Y(y), X(MARG + gw), Y(y + 1.5),
    acid(0.85), acid(0), acid(0), acid(0.85))
  if state.toast and (os.clock() - state.toast_t) < 3 then
    ptext(MARG + 2, y + 5, '>>  copied:  ' .. state.toast, acid(1), 11, 'mono')
  else
    ptext(MARG + 2, y + 5, 'Click any value to copy it to the clipboard', GRAY, 11, 'mono')
  end
  -- second line: circuit traces + brand tag on the right
  local tag = '// BPM2MS2HZ'
  local tx = W - MARG - tw(tag, 11, 'mono')
  traces(tx - 56, y + 31)
  ptext(tx, y + 19, tag, acid(0.60), 11, 'mono')
end

-- ---- Tempo panel
-- Slider: a click/drag sets the value absolutely from the mouse position (40..300 BPM, 0.1 BPM grid) and
-- switches to manual tempo; mouse wheel: 1 BPM, with Shift 0.1 BPM.
local function tempo_slider(x, y, w, h)
  local hov, act = hit("s_bpm", x - 6, y - 3, w + 12, h + 6)
  if act then
    local t = (UK.mxd - x) / w
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local nv = 40 + t * 260
    if math.abs(nv - state.bpm) > 0.049 then set_manual_bpm(nv) end
  elseif hov then
    local wv = ImGui.GetMouseWheel(ctx)
    if wv and wv ~= 0 then set_manual_bpm(state.bpm + wv * (UK.shift and 0.1 or 1)) end
  end
  hslider_draw(x, y, w, h, math.max(0, math.min(1, (state.bpm - 40) / 260)), hov or act)
  local mc = acid(0.65)
  ptext_r(x - 6, y + h / 2 - 8, '<', mc, 12)
  ptext(x + w + 6, y + h / 2 - 8, '>', mc, 12)
  tipfor("s_bpm", "Manual tempo from 40 to 300 BPM in 0.1 BPM steps; click or drag switches FROM PROJECT off, the wheel moves 1 BPM (Shift: 0.1 BPM).")
end

local function p_tempo(x, y, w, h, z)
  panel(x, y, w, h, "TEMPO")
  local cx = x + w / 2
  local yy = y + 30
  -- large tempo number, the unit counts toward the centering
  local flashing  = (os.clock() - state.flash_t) < 0.35
  local bpm_color = flashing and C(0.93, 0.93, 0.93) or (state.sync and acid(1) or C(0.93, 0.93, 0.93))
  local bpm_text  = string.format('%.2f', state.bpm)
  local tw_b, tw_u = tw(bpm_text, z.bpm, 'monob'), tw('BPM', 13)
  local bx = cx - (tw_b + 8 + tw_u) / 2
  ptext(bx, yy, bpm_text, bpm_color, z.bpm, 'monob')
  ptext(bx + tw_b + 8, yy + z.bpm * 0.62, 'BPM', C(0.47, 0.48, 0.49), 13)
  hit("t_bpm", bx, yy, tw_b + 8 + tw_u, z.bpm * 1.1)
  tipfor("t_bpm", "Current tempo in BPM: green follows the project tempo, white is a manual tempo (40 to 300 BPM).")
  yy = yy + z.bpm * 1.2 + 6
  -- sync switch, centered below the number
  if toggle("t_sync", cx - 75, yy, 150, 22, state.sync, "FROM PROJECT",
      "On: the tempo follows the project tempo live, including tempo automation; off: manual tempo from the slider.") then
    set_sync(not state.sync)
  end
  yy = yy + 22 + 10
  tempo_slider(x + 16, yy, w - 32, 18)
  yy = yy + 18 + 10
  -- info lines
  local sig = SIGNATURES[state.sig_ix]
  local beat_ms = 60000 / state.bpm
  local bar_sec = 60 / state.bpm * sig[1] * 4 / sig[2]
  ptext_c(cx, yy, string.format('1 beat = %.2f ms', beat_ms), C(0.47, 0.48, 0.49), z.info, 'mono')
  ptext_c(cx, yy + z.info + 5, string.format('1 bar (%d/%d) = %.3f s', sig[1], sig[2], bar_sec), C(0.47, 0.48, 0.49), z.info, 'mono')
end

-- ---- Tabs and tables
local function p_tabs(x, y, w)
  local bw = (w - 6) / 2
  if btn("tab_notes", x, y, bw, TABS_H, "NOTE VALUES", state.tab == 1, false,
      "Note values 1/1 to 1/32 (plain, dotted, triplet) in milliseconds and Hertz.") then
    state.tab = 1
  end
  if btn("tab_bars", x + bw + 6, y, bw, TABS_H, "BARS", state.tab == 2, false,
      "Whole bars 1 to 64 in seconds and Hertz for the selected time signature.") then
    state.tab = 2
  end
end

-- Columns: label on the left, values right-aligned (mono)
local function columns(x, w)
  local x0 = x + 14
  return x0, x0 + (w - 28) * 0.62, x + w - 14
end

-- Width of the label column: longest row label at the current table font size + spacing, at least 70
local function labw(rows, z)
  local m = 70
  for _, r in ipairs(rows) do
    local v = tw(r.label, z.tbl, 'mono') + 12
    if v > m then m = v end
  end
  return m
end

local function value_cell(id, x1, x2, y, h, text, unit, colr, z)
  local hov = hit(id, x1, y, x2 - x1, h)
  if ImGui.IsItemActivated(ctx) then copy_value(text) end
  if hov then rfill(x1, y, x2 - x1, h, acid(0.10)) end
  ptext_r(x2 - 4, y + (h - z.tbl) / 2 - 1, text, hov and acid(1) or colr, z.tbl, 'mono')
  tipfor(id, string.format('Click to copy %s %s to the clipboard.', text, unit))
end

local function table_head(x, y, w, a, b, z)
  local _, c1, c2 = columns(x, w)
  local x0 = x + 14
  local mid = (c1 + (x0 + 70)) / 2
  ptext(x0, y, a == 'SEC' and 'BARS' or 'NOTE', acid(0.85), z.hdr, 'monob')
  ptext_r(c1 - 4, y, a, acid(0.85), z.hdr, 'monob')
  ptext_r(c2 - 4, y, b, acid(0.85), z.hdr, 'monob')
  rfill(x + 10, y + z.hdr + 5, w - 20, 1, tone(0.16, 0.12))
  return mid
end

local function p_notes(x, y, w, h, z)
  panel(x, y, w, h, "NOTE VALUES")
  local x0, c1, c2 = columns(x, w)
  local yy = y + 30
  table_head(x, yy, w, 'MS', 'HZ', z)
  yy = yy + z.hdr + 10
  local rows = note_rows()
  local lw0 = labw(rows, z)
  for i, r in ipairs(rows) do
    if i % 2 == 0 then rfill(x + 8, yy, w - 16, z.row, C(1, 1, 1, 0.022)) end
    local kv = KV[r.variant.kind]
    ptext(x0, yy + (z.row - z.tbl) / 2 - 1, r.label, kv.label(), z.tbl, 'mono')
    value_cell("c_" .. r.label .. "_ms", x0 + lw0, c1, yy, z.row, r.a, 'ms', kv.value(), z)
    value_cell("c_" .. r.label .. "_hz", c1, c2, yy, z.row, r.b, 'Hz', kv.value(), z)
    yy = yy + z.row
  end
end

local function p_bars(x, y, w, h, z)
  local sig = SIGNATURES[state.sig_ix]
  panel(x, y, w, h, string.format("BARS  %d/%d", sig[1], sig[2]))
  local x0, c1, c2 = columns(x, w)
  local yy = y + 30
  -- Time signature: chips instead of a combo box (same list, saved)
  ptext(x0, yy + 5, 'TIME SIG', acid(1), 11)
  local cx = x0 + 62
  local cw = (x + w - 14 - cx - 6 * 3) / #SIGNATURES
  for i, s in ipairs(SIGNATURES) do
    local lab = string.format('%d/%d', s[1], s[2])
    if btn("sig" .. i, cx + (i - 1) * (cw + 3), yy, cw, 22, lab, state.sig_ix == i, false,
        string.format('Time signature %s: one bar = %d %s notes; sets the bar length of this table.',
          lab, s[1], s[2] == 8 and 'eighth' or 'quarter')) then
      state.sig_ix = i
      save_settings()
    end
  end
  yy = yy + 30
  table_head(x, yy, w, 'SEC', 'HZ', z)
  yy = yy + z.hdr + 10
  local rows = bar_rows()
  local lw0 = labw(rows, z)
  for i, r in ipairs(rows) do
    if i % 2 == 0 then rfill(x + 8, yy, w - 16, z.row, C(1, 1, 1, 0.022)) end
    ptext(x0, yy + (z.row - z.tbl) / 2 - 1, r.label, acid(1), z.tbl, 'mono')
    value_cell("c_" .. r.label .. "_s", x0 + lw0, c1, yy, z.row, r.a, 's', C(0.180, 0.640, 0.110), z)
    value_cell("c_" .. r.label .. "_hz", c1, c2, yy, z.row, r.b, 'Hz', C(0.180, 0.640, 0.110), z)
    yy = yy + z.row
  end
end

-- ---- OPTIONS box (overlay)
local function pct(v) return string.format("%d%%", floor(v * 100 + 0.5)) end

local function set_zoom(f)
  state.zoom = f
  WIN_RESIZE = f
  if state.autofit then HOLD = { n = 0 } end
  save_settings()
end

local function p_options(x, y)
  local w, h = OPT_W, OPT_H
  -- shadow + box
  rfill(x + 3, y + 4, w, h, C(0, 0, 0, 0.45), 5)
  panel(x, y, w, h, "OPTIONS")
  if toggle("o_tips", x + w - 128, y + 3, 118, 18, state.tips, state.tips and "TOOLTIPS ON" or "TOOLTIPS OFF",
      "Show or hide the tooltips of all controls (saved).") then
    state.tips = not state.tips
    save_settings()
  end
  local lx, yy = x + 12, y + 32
  local lab = C(0.72, 0.78, 0.70)
  -- UI SIZE: zoom buttons
  ptext(lx, yy + 4, "UI SIZE", lab, 11)
  for i, f in ipairs(ZOOMS) do
    if btn("o_z" .. i, lx + 64 + (i - 1) * 45, yy, 41, 22, pct(f), math.abs(UK.sc - f) < 0.005, false,
        "Resize this window to " .. pct(f) .. " of its design size; with AUTO FIT on, the next window change rescales again.") then
      set_zoom(f)
    end
  end
  yy = yy + 28
  if toggle("o_autofit", lx + 64, yy, 136, 22, state.autofit, state.autofit and "AUTO FIT ON" or "AUTO FIT OFF",
      "On: the UI rescales to the window size (25 to 400 %); off: the UI size stays fixed and scrollbars appear if needed.") then
    state.autofit = not state.autofit
    HOLD = nil
    state.zoom = floor(UK.sc * 100 + 0.5) / 100
    save_settings()
  end
  ptext(lx + 210, yy + 4, "now " .. pct(UK.sc), GRAY, 11)
  yy = yy + 32
  -- FONT SIZE (80..150 %, step 5 %): tempo number, info lines and tables
  ptext(lx, yy + 4, "FONT SIZE", lab, 11)
  if btn("o_fdn", lx + 64, yy, 30, 22, "-", false, false, "Smaller text in the tempo display and the tables, down to 80 %.") then
    state.font_scale = math.max(0.80, state.font_scale - 0.05)
    save_settings()
  end
  ptext_c(lx + 64 + 30 + 28, yy + 4, pct(state.font_scale), acid(1), 12)
  if btn("o_fup", lx + 64 + 86, yy, 30, 22, "+", false, false, "Larger text in the tempo display and the tables, up to 150 %.") then
    state.font_scale = math.min(1.50, state.font_scale + 0.05)
    save_settings()
  end
  yy = yy + 32
  -- NOTE VARIANTS
  ptext(lx, yy + 4, "VARIANTS", lab, 11)
  if toggle("o_dotted", lx + 64, yy, 104, 22, state.dotted, "DOTTED 1/4.",
      "Show or hide the dotted rows (x1.5, e.g. 1/4.).") then
    state.dotted = not state.dotted
    save_settings()
  end
  if toggle("o_triplet", lx + 172, yy, 122, 22, state.triplet, "TRIPLETS 1/4T",
      "Show or hide the triplet rows (x2/3, e.g. 1/4T).") then
    state.triplet = not state.triplet
    save_settings()
  end
  yy = yy + 32
  -- BRANDING
  ptext(lx, yy + 4, "BRANDING", lab, 11)
  if toggle("o_wm", lx + 64, yy, 136, 22, state.watermark, "WATERMARK",
      "Show or hide the faint Tim Techlor wordmark in the background.") then
    state.watermark = not state.watermark
    save_settings()
  end
  return w, h
end

-- ---- whole kit view
local ZOOM_DIRTY = false
local function draw_ui_kit(cw, ch)
  local mx, my = ImGui.GetMousePos(ctx)
  local mods = ImGui.GetKeyMods(ctx)
  UK.shift = (mods & ImGui.Mod_Shift) ~= 0
  UK.ctrl = (mods & ImGui.Mod_Ctrl) ~= 0
  UK.dl = ImGui.GetWindowDrawList(ctx)
  local gx, gy = ImGui.GetCursorScreenPos(ctx)
  UK.gx, UK.gy = gx, gy

  local z = sizes()
  local L1, L2 = layout_for(1, z), layout_for(2, z)
  local s1, s2 = math.min(cw / L1.W, ch / L1.H), math.min(cw / L2.W, ch / L2.H)
  local Lo, fit, mode
  if s2 > s1 then Lo, fit, mode = L2, s2, 2 else Lo, fit, mode = L1, s1, 1 end
  local W, H = Lo.W, Lo.H

  -- AUTO FIT: largest whole percentage at which everything fits in the window (25..400 %). A zoom button holds until the
  -- next window change (HOLD: remember the window size two frames after the size change, any deviation releases it).
  if HOLD then
    HOLD.n = HOLD.n + 1
    if HOLD.n == 3 then HOLD.cw, HOLD.ch = cw, ch
    elseif HOLD.n > 3 and (math.abs(cw - HOLD.cw) > 1 or math.abs(ch - HOLD.ch) > 1) then HOLD = nil end
  end
  local sc
  if state.autofit and not HOLD then
    sc = floor(fit * 100 + 0.0001) / 100
    if sc < 0.25 then sc = 0.25 elseif sc > 4 then sc = 4 end
    -- the fitted zoom becomes the saved zoom (AUTO FIT OFF keeps it), saved only once the mouse is released
    if math.abs(sc - state.zoom) > 0.001 then state.zoom = sc; ZOOM_DIRTY = true end
    if ZOOM_DIRTY and not ImGui.IsMouseDown(ctx, 0) then ZOOM_DIRTY = false; save_settings() end
  else
    sc = state.zoom
  end
  if sc < 0.25 then sc = 0.25 elseif sc > 4 then sc = 4 end
  UK.sc = sc
  local okw, ww, wh = pcall(ImGui.GetWindowSize, ctx)
  if okw and ww then WIN_DES = { W, H, ww - cw, wh - ch } end
  UK.ox = gx + math.max(0, (cw - W * sc) / 2)
  UK.oy = gy + math.max(0, (ch - H * sc) / 2)
  UK.mxd = (mx - UK.ox) / sc
  UK.myd = (my - UK.oy) / sc
  if HOOK and HOOK.diag then
    HOOK.diag.sc, HOOK.diag.mode, HOOK.diag.W, HOOK.diag.H = sc, mode, W, H
  end

  ground(math.max(cw, W * sc), math.max(ch, H * sc))
  watermark_draw(W, H)
  header(W)
  -- while the OPTIONS box is open the front is locked (clicks go only to the box and the OPTIONS button)
  local locked = state.options
  if locked then ImGui.BeginDisabled(ctx, true); UK.disabled = true end
  p_tempo(Lo.tempo[1], Lo.tempo[2], Lo.tempo[3], Lo.tempo[4], z)
  p_tabs(Lo.tabs[1], Lo.tabs[2], Lo.tabs[3])
  if state.tab == 2 then p_bars(Lo.tbl[1], Lo.tbl[2], Lo.tbl[3], Lo.tbl[4], z)
  else p_notes(Lo.tbl[1], Lo.tbl[2], Lo.tbl[3], Lo.tbl[4], z) end
  footer(W, H - FOOT)
  if locked then ImGui.EndDisabled(ctx); UK.disabled = false end
  if state.options then
    local ox, oy = math.max(MARG, W - MARG - OPT_W), HEAD - 2
    p_options(ox, oy)
    -- a click outside the box and the OPTIONS button closes it
    if ImGui.IsMouseClicked(ctx, 0) then
      local inbox = UK.mxd >= ox and UK.mxd <= ox + OPT_W and UK.myd >= oy and UK.myd <= oy + OPT_H
      local inbtn = UK.mxd >= W - MARG - 76 and UK.mxd <= W - MARG and UK.myd >= 9 and UK.myd <= 31
      if not inbox and not inbtn then state.options = false end
    end
  end
  -- content size for the scrollbars (only when a fixed zoom is larger than the window)
  ImGui.SetCursorScreenPos(ctx, gx, gy)
  ImGui.Dummy(ctx, math.max(1, W * sc), math.max(1, H * sc))
end

-- Style colors of the kit view
local function acid_a(a) return 0x39FF1400 | math.floor(255 * a + 0.5) end
local KIT_COLS = {
  { ImGui.Col_WindowBg, 0x0D0E0DFF }, { ImGui.Col_ChildBg, 0x0D0E0DFF }, { ImGui.Col_PopupBg, 0x121412FF },
  { ImGui.Col_Text, 0xD6E2D6FF }, { ImGui.Col_TextDisabled, 0x8C8C8CFF },
  { ImGui.Col_Border, acid_a(0.35) }, { ImGui.Col_FrameBg, 0x1B1C1BFF }, { ImGui.Col_FrameBgHovered, acid_a(0.18) },
  { ImGui.Col_FrameBgActive, acid_a(0.30) },
  { ImGui.Col_Button, 0x1B1C1BFF }, { ImGui.Col_ButtonHovered, acid_a(0.25) }, { ImGui.Col_ButtonActive, acid_a(0.5) },
  { ImGui.Col_ScrollbarBg, 0x0D0E0DFF }, { ImGui.Col_ScrollbarGrab, 0x1B1C1BFF }, { ImGui.Col_ScrollbarGrabHovered, acid_a(0.35) },
  { ImGui.Col_Separator, acid_a(0.30) }, { ImGui.Col_TitleBg, 0x0D0E0DFF }, { ImGui.Col_TitleBgActive, 0x121412FF },
  { ImGui.Col_ResizeGrip, acid_a(0.25) }, { ImGui.Col_ResizeGripHovered, acid_a(0.6) }, { ImGui.Col_ResizeGripActive, 0x39FF14FF },
}

local function kit_frame()
  for _, c in ipairs(KIT_COLS) do ImGui.PushStyleColor(ctx, c[1], c[2]) end
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 0, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowMinSize, 160, 160)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowTitleAlign, 0.5, 0.5)
  ImGui.PushFont(ctx, FONT_UI, 14)

  ImGui.SetNextWindowSize(ctx, MARG * 2 + COL1, 700, ImGui.Cond_FirstUseEver)
  -- once, to the new start size (kit view: 100 % single column)
  if reaper.GetExtState(SETTINGS, 'layout') ~= '3' and not (HOOK and HOOK.nosave) then
    ImGui.SetNextWindowSize(ctx, MARG * 2 + COL1, 700, ImGui.Cond_Always)
    reaper.SetExtState(SETTINGS, 'layout', '3', true)
  end
  if WIN_SET then
    ImGui.SetNextWindowSize(ctx, WIN_SET[1], WIN_SET[2], ImGui.Cond_Always)
    WIN_SET = nil
  end
  if WIN_POS then
    ImGui.SetNextWindowPos(ctx, WIN_POS[1], WIN_POS[2], ImGui.Cond_Always)
    WIN_POS = nil
  end
  if WIN_RESIZE and WIN_DES then
    ImGui.SetNextWindowSize(ctx, math.floor(WIN_DES[1] * WIN_RESIZE + WIN_DES[3] + 0.5),
      math.floor(WIN_DES[2] * WIN_RESIZE + WIN_DES[4] + 0.5), ImGui.Cond_Always)
    WIN_RESIZE = nil
  end
  local flags = ImGui.WindowFlags_NoCollapse
  if state.autofit and not HOLD then flags = flags | ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse
  else flags = flags | ImGui.WindowFlags_HorizontalScrollbar end
  if HOOK and HOOK.notitle then flags = flags | ImGui.WindowFlags_NoTitleBar end
  local visible, open = ImGui.Begin(ctx, WINDOW_TITLE, true, flags)
  if visible then
    local cw, ch = ImGui.GetContentRegionAvail(ctx)
    local ok_k, err = pcall(draw_ui_kit, cw, ch)
    if not ok_k then
      if UK.disabled then ImGui.EndDisabled(ctx); UK.disabled = false end
      -- close open font/clip stacks of the kit view before the classic view takes over
      while (UK.fonts or 0) > 0 do ImGui.PopFont(ctx); UK.fonts = UK.fonts - 1 end
      while (UK.clips or 0) > 0 and UK.dl do ImGui.DrawList_PopClipRect(UK.dl); UK.clips = UK.clips - 1 end
      KIT_ERR = tostring(err)
      reaper.ShowConsoleMsg("TT-BPM2MS2HZ: UI kit view failed, using the classic view.\n" .. KIT_ERR .. "\n")
    end
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)
  ImGui.PopStyleVar(ctx, 4)
  ImGui.PopStyleColor(ctx, #KIT_COLS)
  return open
end

--------------------------------------------------------------------
-- Classic view (fallback only, used if the kit view fails)
--------------------------------------------------------------------
local STYLE_COLORS = {
  { ImGui.Col_WindowBg,             BLACK },
  { ImGui.Col_TitleBg,              TITLE_BG },
  { ImGui.Col_TitleBgActive,        TITLE_BG },
  { ImGui.Col_TitleBgCollapsed,     TITLE_BG },
  { ImGui.Col_Border,               LINE },
  { ImGui.Col_PopupBg,              PANEL },
  { ImGui.Col_Text,                 WHITE },
  { ImGui.Col_TextDisabled,         DIM },
  { ImGui.Col_Separator,            LINE },
  { ImGui.Col_Tab,                  BLACK },
  { ImGui.Col_TabHovered,           rgba(0.070, 0.130, 0.050, 1.0) },
  { ImGui.Col_TabSelected,          PANEL },
  { ImGui.Col_TabSelectedOverline,  ACID },
  { ImGui.Col_TableHeaderBg,        PANEL },
  { ImGui.Col_TableRowBg,           rgba(0, 0, 0, 0) },
  { ImGui.Col_TableRowBgAlt,        rgba(1, 1, 1, 0.022) },
  { ImGui.Col_TableBorderStrong,    LINE },
  { ImGui.Col_TableBorderLight,     rgba(0.085, 0.085, 0.090, 1.0) },
  { ImGui.Col_Header,               ACID_DARK },
  { ImGui.Col_HeaderHovered,        ACID_DARK },
  { ImGui.Col_HeaderActive,         rgba(0.110, 0.300, 0.060, 0.9) },
  { ImGui.Col_FrameBg,              PANEL },
  { ImGui.Col_FrameBgHovered,       rgba(0.085, 0.088, 0.094, 1.0) },
  { ImGui.Col_FrameBgActive,        ACID_DARK },
  { ImGui.Col_SliderGrab,           ACID },
  { ImGui.Col_SliderGrabActive,     WHITE },
  { ImGui.Col_CheckMark,            ACID },
  { ImGui.Col_Button,               PANEL },
  { ImGui.Col_ButtonHovered,        ACID_DARK },
  { ImGui.Col_ButtonActive,         rgba(0.110, 0.300, 0.060, 0.9) },
  { ImGui.Col_ScrollbarBg,          BLACK },
  { ImGui.Col_ScrollbarGrab,        PANEL },
  { ImGui.Col_ScrollbarGrabHovered, LINE },
}

local function tip(text)
  if state.tips and ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, text) end
end

local function draw_value_cell(text, copy_text, color)
  if color then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, color)
  end

  local clicked = ImGui.Selectable(ctx, text)

  if color then
    ImGui.PopStyleColor(ctx, 1)
  end
  if clicked then
    copy_value(copy_text)
  end
  tip('Click to copy:  ' .. copy_text)
end

-- Center a column header label over its value column
local function centered_header(label, cwid)
  local text_w = ImGui.CalcTextSize(ctx, label)
  local pad    = math.max(0, (cwid - text_w) / 2)
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + pad)
  ImGui.TableHeader(ctx, label)
end

local function draw_decor()
  local dl     = ImGui.GetWindowDrawList(ctx)
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)

  if wordmark and state.watermark then
    local wm_w = math.min(ww * 0.9, 300 * state.font_scale)
    local wm_h = wm_w / WORDMARK_ASPECT
    local x = wx + ww - wm_w - 20 * state.font_scale
    local y = wy + wh - wm_h - 42 * state.font_scale
    ImGui.DrawList_AddImage(dl, wordmark, x, y, x + wm_w, y + wm_h,
      0, 0, 1, 1, rgba(1, 1, 1, 0.05))
  end

  local base_y = wy + wh - 20 * state.font_scale
  for i = 0, 2 do
    local bx = wx + 24 * state.font_scale + i * 22
    ImGui.DrawList_AddLine(dl, bx, base_y, bx + 14, base_y - 14, ACID_FAINT, 1)
    ImGui.DrawList_AddCircleFilled(dl, bx + 16, base_y - 16, 1.6, ACID_PAD, 6)
  end

  local tag = '// BPM2MS2HZ'
  ImGui.PushFont(ctx, font_mono, fs(12))
  local tag_w, tag_h = ImGui.CalcTextSize(ctx, tag)
  ImGui.PopFont(ctx)
  local tx = wx + ww - tag_w - 18 * state.font_scale
  local ty = base_y - tag_h - 2
  ImGui.DrawList_AddTextEx(dl, font_mono, fs(12), tx, ty,
    rgba(0.224, 1.000, 0.078, 0.60), tag)
end

local function draw_gradient_separator()
  ImGui.Separator(ctx)
  local ix, iy = ImGui.GetItemRectMin(ctx)
  local ax, _  = ImGui.GetItemRectMax(ctx)
  local dl     = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilledMultiColor(dl,
    ix, iy + 1.5, ax, iy + 3.0,
    rgba(0.224, 1.000, 0.078, 0.85), rgba(0.224, 1.000, 0.078, 0.0),
    rgba(0.224, 1.000, 0.078, 0.0), rgba(0.224, 1.000, 0.078, 0.85))
end

local function draw_options_popup()
  if not ImGui.BeginPopup(ctx, '##options') then
    return
  end
  ImGui.PushFont(ctx, font_ui, fs(12))
  ImGui.SeparatorText(ctx, 'FONT SIZE')
  if ImGui.Button(ctx, '  -  ') then
    state.font_scale = math.max(0.80, state.font_scale - 0.05)
    save_settings()
  end
  tip('Smaller font size for tempo, info lines and tables (80 to 150 %).')
  ImGui.SameLine(ctx, 0, 8)
  ImGui.TextColored(ctx, ACID,
    string.format('%d%%', math.floor(state.font_scale * 100 + 0.5)))
  ImGui.SameLine(ctx, 0, 8)
  if ImGui.Button(ctx, '  +  ') then
    state.font_scale = math.min(1.50, state.font_scale + 0.05)
    save_settings()
  end
  tip('Larger font size for tempo, info lines and tables (80 to 150 %).')
  ImGui.SameLine(ctx, 0, 8)
  ImGui.TextDisabled(ctx, 'scales the whole UI')

  ImGui.SeparatorText(ctx, 'NOTE VARIANTS')
  local changed_dot, dotted = ImGui.Checkbox(ctx, 'dotted   (1/4.)', state.dotted)
  if changed_dot then
    state.dotted = dotted
    save_settings()
  end
  tip('Show dotted note values (x 1.5) in the note table.')
  local changed_tri, triplet = ImGui.Checkbox(ctx, 'triplets (1/4T)', state.triplet)
  if changed_tri then
    state.triplet = triplet
    save_settings()
  end
  tip('Show triplet note values (x 2/3) in the note table.')

  ImGui.SeparatorText(ctx, 'BRANDING')
  local changed_wm, watermark = ImGui.Checkbox(ctx, 'wordmark watermark', state.watermark)
  if changed_wm then
    state.watermark = watermark
    save_settings()
  end
  tip('Show the TimTechlor wordmark as a faint watermark behind the window.')
  local changed_tp, tips = ImGui.Checkbox(ctx, 'tooltips', state.tips)
  if changed_tp then
    state.tips = tips
    save_settings()
  end
  tip('Show or hide these tooltips.')
  ImGui.PopFont(ctx)
  ImGui.EndPopup(ctx)
end

local function draw_header()
  local sig     = SIGNATURES[state.sig_ix]
  local beat_ms = 60000 / state.bpm
  local bar_sec = 60 / state.bpm * sig[1] * 4 / sig[2]

  do
    local line_x  = ImGui.GetCursorPosX(ctx)
    local avail_w = ImGui.GetContentRegionAvail(ctx)
    ImGui.PushFont(ctx, font_brand, fs(17))
    local name_w = ImGui.CalcTextSize(ctx, 'TT-BPM2MS2HZ  v' .. VERSION)
    ImGui.SetCursorPosX(ctx, line_x + math.max(0, (avail_w - name_w) / 2))
    ImGui.TextColored(ctx, ACID, 'TT-BPM2MS2HZ')
    ImGui.SameLine(ctx, 0, 8)
    ImGui.TextColored(ctx, DIM, 'v' .. VERSION)
    ImGui.PopFont(ctx)
  end

  do
    local line_x  = ImGui.GetCursorPosX(ctx)
    local avail_w = ImGui.GetContentRegionAvail(ctx)
    local pad_x, _pad_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
    ImGui.PushFont(ctx, font_ui, fs(12))
    local opt_w = ImGui.CalcTextSize(ctx, 'OPTIONS')
    ImGui.PopFont(ctx)
    local btn_w = opt_w + pad_x * 2 + 2

    ImGui.PushFont(ctx, font_bold, fs(11))
    local tempo_w = ImGui.CalcTextSize(ctx, 'TEMPO')
    ImGui.SetCursorPosX(ctx, line_x + math.max(0, (avail_w - tempo_w) / 2))
    ImGui.TextColored(ctx, ACID, 'TEMPO')
    ImGui.PopFont(ctx)

    ImGui.SameLine(ctx, math.max(0, line_x + avail_w - btn_w))
    if ImGui.Button(ctx, 'OPTIONS') then
      ImGui.OpenPopup(ctx, '##options')
    end
    tip('Font size, note variants, watermark and tooltips.')
    draw_options_popup()
  end

  local flashing  = (os.clock() - state.flash_t) < 0.35
  local bpm_color = flashing and WHITE or (state.sync and ACID or WHITE)
  local bpm_text  = string.format('%.2f', state.bpm)

  ImGui.PushFont(ctx, font_ui, fs(13))
  local unit_w = ImGui.CalcTextSize(ctx, 'BPM')
  ImGui.PopFont(ctx)

  ImGui.PushFont(ctx, font_mono_b, fs(36))
  local text_w = ImGui.CalcTextSize(ctx, bpm_text)
  local free_w = ImGui.GetContentRegionAvail(ctx)
  local pad    = math.max(0, (free_w - text_w - 8 - unit_w) / 2)
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + pad)
  ImGui.TextColored(ctx, bpm_color, bpm_text)
  ImGui.SameLine(ctx, 0, 8)
  ImGui.PushFont(ctx, font_ui, fs(13))
  ImGui.TextColored(ctx, DIM, 'BPM')
  ImGui.PopFont(ctx)
  ImGui.PopFont(ctx)

  do
    local pad_x, _pad_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
    ImGui.PushFont(ctx, font_ui, fs(12))
    local cb_text_w = ImGui.CalcTextSize(ctx, '  from project')
    local cb_w  = cb_text_w + pad_x * 2 + 15
    local av_w  = ImGui.GetContentRegionAvail(ctx)
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + math.max(0, (av_w - cb_w) / 2))
    ImGui.PopFont(ctx)

    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, rgba(0.070, 0.180, 0.040, 1.0))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, ACID)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 1)
    local changed, sync = ImGui.Checkbox(ctx, '  from project', state.sync)
    ImGui.PopStyleVar(ctx, 1)
    ImGui.PopStyleColor(ctx, 2)
    tip('On: the tempo follows the project tempo live; off: manual tempo from the slider.')
    if changed then
      set_sync(sync)
    end
  end

  ImGui.PushFont(ctx, font_ui, fs(15))
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 0, 6)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 1)
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg,        BLACK)
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, rgba(0.045, 0.045, 0.050, 1.0))
  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive,  ACID_DARK)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border,         ACID)
  ImGui.SetNextItemWidth(ctx, -1)
  local moved, bpm = ImGui.SliderDouble(ctx, '##bpm', state.bpm, 40, 300,
    ' ', ImGui.SliderFlags_AlwaysClamp)
  if moved then
    state.bpm  = math.floor(bpm * 10 + 0.5) / 10
    state.sync = false
  end
  tip('Manual tempo from 40 to 300 BPM in 0.1 BPM steps.')
  ImGui.PopStyleColor(ctx, 4)
  ImGui.PopStyleVar(ctx, 2)
  ImGui.PopFont(ctx)

  ImGui.PushFont(ctx, font_mono, fs(12))
  local info_1 = string.format('1 beat = %.2f ms', beat_ms)
  local info_2 = string.format('1 bar (%d/%d) = %.3f s', sig[1], sig[2], bar_sec)
  local w1 = ImGui.CalcTextSize(ctx, info_1)
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) +
    math.max(0, (ImGui.GetContentRegionAvail(ctx) - w1) / 2))
  ImGui.TextColored(ctx, DIM, info_1)
  local w2 = ImGui.CalcTextSize(ctx, info_2)
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) +
    math.max(0, (ImGui.GetContentRegionAvail(ctx) - w2) / 2))
  ImGui.TextColored(ctx, DIM, info_2)
  ImGui.PopFont(ctx)

  draw_gradient_separator()
end

local function draw_notes()
  if not ImGui.BeginTable(ctx, 'notes', 3, ImGui.TableFlags_RowBg) then
    return
  end
  ImGui.TableSetupColumn(ctx, 'NOTE', ImGui.TableColumnFlags_WidthFixed, col_w(56))
  ImGui.TableSetupColumn(ctx, 'MS',   ImGui.TableColumnFlags_WidthFixed, col_w(64))
  ImGui.TableSetupColumn(ctx, 'HZ',   ImGui.TableColumnFlags_WidthFixed, col_w(64))

  ImGui.PushFont(ctx, font_mono_b, fs(12))
  ImGui.TableNextRow(ctx, ImGui.TableRowFlags_Headers)
  ImGui.TableNextColumn(ctx)
  ImGui.TableHeader(ctx, 'NOTE')
  ImGui.TableNextColumn(ctx)
  centered_header('MS', col_w(64))
  ImGui.TableNextColumn(ctx)
  centered_header('HZ', col_w(64))
  ImGui.PopFont(ctx)

  ImGui.PushFont(ctx, font_mono, fs(14))
  for _, r in ipairs(note_rows()) do
    ImGui.TableNextRow(ctx)
    ImGui.TableNextColumn(ctx)
    ImGui.TextColored(ctx, r.variant.color, r.label)
    ImGui.TableNextColumn(ctx)
    draw_value_cell(string.format('%6s', r.a), r.a, r.variant.soft)
    ImGui.TableNextColumn(ctx)
    draw_value_cell(string.format('%6s', r.b), r.b, r.variant.soft)
  end
  ImGui.PopFont(ctx)
  ImGui.EndTable(ctx)
end

local function draw_bars()
  local sig = SIGNATURES[state.sig_ix]

  ImGui.PushFont(ctx, font_bold, fs(11))
  ImGui.TextColored(ctx, ACID, 'TIME SIGNATURE')
  ImGui.PopFont(ctx)

  ImGui.SameLine(ctx, 0, 10)
  ImGui.SetNextItemWidth(ctx, 90)
  local current = string.format('%d/%d', sig[1], sig[2])
  if ImGui.BeginCombo(ctx, '##signature', current) then
    for index, s in ipairs(SIGNATURES) do
      if ImGui.Selectable(ctx, string.format('%d/%d', s[1], s[2])) then
        state.sig_ix = index
        save_settings()
      end
    end
    ImGui.EndCombo(ctx)
  end
  tip('Time signature: sets the bar length of this table.')

  if not ImGui.BeginTable(ctx, 'bars', 3, ImGui.TableFlags_RowBg) then
    return
  end
  ImGui.TableSetupColumn(ctx, 'BARS', ImGui.TableColumnFlags_WidthFixed, col_w(74))
  ImGui.TableSetupColumn(ctx, 'SEC',  ImGui.TableColumnFlags_WidthFixed, col_w(64))
  ImGui.TableSetupColumn(ctx, 'HZ',   ImGui.TableColumnFlags_WidthFixed, col_w(64))

  ImGui.PushFont(ctx, font_mono_b, fs(12))
  ImGui.TableNextRow(ctx, ImGui.TableRowFlags_Headers)
  ImGui.TableNextColumn(ctx)
  ImGui.TableHeader(ctx, 'BARS')
  ImGui.TableNextColumn(ctx)
  centered_header('SEC', col_w(64))
  ImGui.TableNextColumn(ctx)
  centered_header('HZ', col_w(64))
  ImGui.PopFont(ctx)

  ImGui.PushFont(ctx, font_mono, fs(14))
  for _, r in ipairs(bar_rows()) do
    ImGui.TableNextRow(ctx)
    ImGui.TableNextColumn(ctx)
    ImGui.TextColored(ctx, ACID, r.label)
    ImGui.TableNextColumn(ctx)
    draw_value_cell(string.format('%6s', r.a), r.a, ACID_SOFT)
    ImGui.TableNextColumn(ctx)
    draw_value_cell(string.format('%6s', r.b), r.b, ACID_SOFT)
  end
  ImGui.PopFont(ctx)
  ImGui.EndTable(ctx)
end

local function draw_footer()
  draw_gradient_separator()
  ImGui.PushFont(ctx, font_mono, fs(12))
  ImGui.PushTextWrapPos(ctx, 0)
  if state.toast and (os.clock() - state.toast_t) < 3 then
    ImGui.TextColored(ctx, ACID, '>>  copied:  ' .. state.toast)
  else
    ImGui.TextColored(ctx, DIM, 'Click any value to copy it to the clipboard')
  end
  ImGui.PopTextWrapPos(ctx)
  ImGui.PopFont(ctx)
end

local function classic_frame()
  ImGui.SetNextWindowSize(ctx, 420, 580, ImGui.Cond_FirstUseEver)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowMinSize, 280, 360)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding, 6, 3)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowTitleAlign, 0.5, 0.5)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 8, 5)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, 10, 10)
  for _, style in ipairs(STYLE_COLORS) do
    ImGui.PushStyleColor(ctx, style[1], style[2])
  end

  local visible, open = ImGui.Begin(ctx, WINDOW_TITLE, true)
  if visible then
    draw_decor()
    draw_header()
    if ImGui.BeginTabBar(ctx, '##tabs') then
      if ImGui.BeginTabItem(ctx, 'NOTE VALUES') then
        draw_notes()
        ImGui.EndTabItem(ctx)
      end
      if ImGui.BeginTabItem(ctx, 'BARS') then
        draw_bars()
        ImGui.EndTabItem(ctx)
      end
      ImGui.EndTabBar(ctx)
    end
    draw_footer()
    ImGui.End(ctx)
  end

  ImGui.PopStyleColor(ctx, #STYLE_COLORS)
  ImGui.PopStyleVar(ctx, 7)
  return open
end

--------------------------------------------------------------------
-- Frame loop
--------------------------------------------------------------------
local function frame()
  if HOOK and HOOK.pending then
    local p = HOOK.pending
    HOOK.pending = nil
    if p.tab then state.tab = p.tab end
    if p.options ~= nil then state.options = p.options end
    if p.winsize then WIN_SET = { p.winsize[1], p.winsize[2] } end
    if p.winpos then WIN_POS = { p.winpos[1], p.winpos[2] } end
  end
  if state.sync then
    state.bpm = reaper.Master_GetTempo()
  end
  if state.bpm ~= state.last_bpm then
    state.last_bpm = state.bpm
    state.flash_t  = os.clock()
  end

  local open
  if KIT_ERR then open = classic_frame() else open = kit_frame() end

  if open then
    reaper.defer(frame)
  end
end

reaper.defer(frame)
