-- @description BPM2MS2HZ Calculator
-- @author Tim Techlor
-- @version 1.0.0
-- @license MIT
-- @provides
--   TT_Wordmark.png
-- @about
--   # BPM2MS2HZ Calculator
--
--   Wandelt Notenwerte aus dem Projekttempo in Millisekunden und Hertz um -
--   als echtes Werkzeugfenster (ReaImGui) statt Konsolentext.
--
--   - Tempo folgt standardmaessig dem Projekt; Slider schaltet auf manuelles
--     Tempo, Checkbox zurueck auf Sync.
--   - Klick auf einen Wert kopiert ihn in die Zwischenablage.
--   - OPTIONS: UI-Schriftgroesse, punktierte/Triolen-Varianten, Wordmark.
--   - Tabs: Notenwerte (1/1 .. 1/32, punktiert, Triolen) und Takte (bis 64).
--
--   Benoetigt die ReaPack-Erweiterung "ReaImGui: ReaScript binding for Dear
--   ImGui" (cfillion, im Repo "ReaTeam Extensions").
-- @changelog
--   Erste Veroeffentlichung ueber ReaPack.
--[[====================================================================
  Tim Techlor's BPM2MS2HZ Calculator for REAPER  ·  GUI  ·  v1.0
  =====================================================================
  Converts note values from the project tempo to milliseconds and Hz -
  as a real tool window instead of console text.

    ms  =  60000 / BPM * beats      (1 beat = 1 quarter note)
    Hz  =  1000 / ms

  Usage:
    - By default the tempo follows the project ("from project" checkbox).
      Touching the slider switches to a manual tempo; re-enable the
      checkbox to switch back to sync.
    - Click any value to copy it to the clipboard.
    - OPTIONS (top right): UI font size, dotted/triplet variants,
      wordmark watermark. All settings are saved permanently.
    - Tabs: note values (1/1 to 1/32, dotted, triplets)
            and bars (up to 64 bars, selectable time signature).

  Requires: ReaPack -> "Dear ImGui bindings" (cfillion)
  https://github.com/cfillion/reaimgui
  Optional: TT_Wordmark.png next to this script (brand wordmark
  image + background watermark; falls back to a system font)
====================================================================]]

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
    "Tim Techlor's BPM2MS2HZ Calculator", 0)
  return
end

--------------------------------------------------------------------
-- Constants & palette (Tim Techlor design guide)
--------------------------------------------------------------------
local WINDOW_TITLE = "Tim Techlor's BPM2MS2HZ Calculator for Reaper"
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
  { suffix = '',  factor = 1,     color = ACID,  soft = ACID_SOFT }, -- full note value
  { suffix = '.', factor = 1.5,   color = DIM,   soft = nil       }, -- dotted
  { suffix = 'T', factor = 2 / 3, color = WHITE, soft = nil       }, -- triplet
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
}

--------------------------------------------------------------------
-- Persistent settings (survive REAPER restarts via ExtState)
--------------------------------------------------------------------
local SETTINGS = 'TT_BPM_Calculator'

local function save_settings()
  reaper.SetExtState(SETTINGS, 'font_scale', string.format('%.2f', state.font_scale), true)
  reaper.SetExtState(SETTINGS, 'dotted',    state.dotted    and '1' or '0', true)
  reaper.SetExtState(SETTINGS, 'triplet',   state.triplet   and '1' or '0', true)
  reaper.SetExtState(SETTINGS, 'watermark', state.watermark and '1' or '0', true)
  reaper.SetExtState(SETTINGS, 'sig_ix',    tostring(state.sig_ix), true)
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

  local sig = tonumber(get('sig_ix'))
  if sig and sig >= 1 and sig <= #SIGNATURES then
    state.sig_ix = math.floor(sig + 0.5)
  end
end

load_settings()

-- Scaled font size helper (adjusted via OPTIONS popup)
local function fs(base)
  return math.floor(base * state.font_scale + 0.5)
end

-- Column width helper: base widths in px at 100% font scale
-- (labels: "1/16." = 56, "64 bars" = 74; values: "2812.5" = 64)
local function col_w(base)
  return math.floor(base * state.font_scale + 0.5)
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

local ctx = ImGui.CreateContext(WINDOW_TITLE)
ImGui.Attach(ctx, font_ui)
ImGui.Attach(ctx, font_bold)
ImGui.Attach(ctx, font_mono)
ImGui.Attach(ctx, font_mono_b)
ImGui.Attach(ctx, font_brand)

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

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------
local function copy_value(value)
  ImGui.SetClipboardText(ctx, value)
  state.toast   = value
  state.toast_t = os.clock()
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
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, 'Click to copy:  ' .. copy_text)
  end
end

-- Center a column header label over its value column
local function centered_header(label, col_w)
  local text_w = ImGui.CalcTextSize(ctx, label)
  local pad    = math.max(0, (col_w - text_w) / 2)
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + pad)
  ImGui.TableHeader(ctx, label)
end

--------------------------------------------------------------------
-- Decorations: wordmark watermark, circuit lines, solder pads
--------------------------------------------------------------------
local function draw_decor()
  local dl     = ImGui.GetWindowDrawList(ctx)
  local wx, wy = ImGui.GetWindowPos(ctx)
  local ww, wh = ImGui.GetWindowSize(ctx)

  -- wordmark as faint background watermark (bottom right)
  if wordmark and state.watermark then
    local wm_w = math.min(ww * 0.9, 300 * state.font_scale)
    local wm_h = wm_w / WORDMARK_ASPECT
    local x = wx + ww - wm_w - 20 * state.font_scale
    local y = wy + wh - wm_h - 42 * state.font_scale
    ImGui.DrawList_AddImage(dl, wordmark, x, y, x + wm_w, y + wm_h,
      0, 0, 1, 1, rgba(1, 1, 1, 0.05))
  end

  -- Circuit lines at 45 degrees with solder pads (bottom left)
  local base_y = wy + wh - 20 * state.font_scale
  for i = 0, 2 do
    local bx = wx + 24 * state.font_scale + i * 22
    ImGui.DrawList_AddLine(dl, bx, base_y, bx + 14, base_y - 14, ACID_FAINT, 1)
    ImGui.DrawList_AddCircleFilled(dl, bx + 16, base_y - 16, 1.6, ACID_PAD, 6)
  end

  -- brand tag on the circuit-line row, right-aligned
  local tag = '// BPM2MS2HZ'
  ImGui.PushFont(ctx, font_mono, fs(12))
  local tag_w, tag_h = ImGui.CalcTextSize(ctx, tag)
  ImGui.PopFont(ctx)
  local tx = wx + ww - tag_w - 18 * state.font_scale
  local ty = base_y - tag_h - 2
  ImGui.DrawList_AddTextEx(dl, font_mono, fs(12), tx, ty,
    rgba(0.224, 1.000, 0.078, 0.60), tag)
end

-- Acid gradient line fading out to the right (drawn under a separator)
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

--------------------------------------------------------------------
-- Options popup: font size, note variants, watermark
--------------------------------------------------------------------
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
  ImGui.SameLine(ctx, 0, 8)
  ImGui.TextColored(ctx, ACID,
    string.format('%d%%', math.floor(state.font_scale * 100 + 0.5)))
  ImGui.SameLine(ctx, 0, 8)
  if ImGui.Button(ctx, '  +  ') then
    state.font_scale = math.min(1.50, state.font_scale + 0.05)
    save_settings()
  end
  ImGui.SameLine(ctx, 0, 8)
  ImGui.TextDisabled(ctx, 'scales the whole UI')

  ImGui.SeparatorText(ctx, 'NOTE VARIANTS')
  local changed_dot, dotted = ImGui.Checkbox(ctx, 'dotted   (1/4.)', state.dotted)
  if changed_dot then
    state.dotted = dotted
    save_settings()
  end
  local changed_tri, triplet = ImGui.Checkbox(ctx, 'triplets (1/4T)', state.triplet)
  if changed_tri then
    state.triplet = triplet
    save_settings()
  end

  ImGui.SeparatorText(ctx, 'BRANDING')
  local changed_wm, watermark = ImGui.Checkbox(ctx, 'wordmark watermark', state.watermark)
  if changed_wm then
    state.watermark = watermark
    save_settings()
  end

  ImGui.PopFont(ctx)
  ImGui.EndPopup(ctx)
end

--------------------------------------------------------------------
-- Header section: brand row, tempo, slider
--------------------------------------------------------------------
local function draw_header()
  local sig     = SIGNATURES[state.sig_ix]
  local beat_ms = 60000 / state.bpm
  local bar_sec = 60 / state.bpm * sig[1] * 4 / sig[2]

  -- Row 1: wordmark, centered, nothing else in this line
  do
    local line_x  = ImGui.GetCursorPosX(ctx)
    local avail_w = ImGui.GetContentRegionAvail(ctx)
    if wordmark then
      local wm_h = fs(16)
      local wm_w = wm_h * WORDMARK_ASPECT
      ImGui.SetCursorPosX(ctx, line_x + math.max(0, (avail_w - wm_w) / 2))
      ImGui.Image(ctx, wordmark, wm_w, wm_h)
    else
      ImGui.PushFont(ctx, font_brand, fs(17))
      local tim_w   = ImGui.CalcTextSize(ctx, 'TIM')
      local tec_w   = ImGui.CalcTextSize(ctx, 'TECHLOR')
      local brand_w = tim_w + 4 + tec_w
      ImGui.SetCursorPosX(ctx, line_x + math.max(0, (avail_w - brand_w) / 2))
      ImGui.TextColored(ctx, WHITE, 'TIM')
      ImGui.SameLine(ctx, 0, 4)
      ImGui.TextColored(ctx, ACID, 'TECHLOR')
      ImGui.PopFont(ctx)
    end
  end

  -- Row 2: TEMPO label centered, OPTIONS button right
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
    draw_options_popup()
  end

  -- Row 3: large, centered BPM number (unit counts toward centering)
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

  -- Row 4: sync checkbox, centered under the BPM number
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
    if changed then
      state.sync = sync
      if sync then state.bpm = reaper.Master_GetTempo() end
    end
  end

  -- Slider: bigger frame, black inside, acid border, < > drag markers.
  -- No value text - the large number above already shows the tempo.
  -- Snaps to 0.1 BPM steps.
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

  do
    local sx, sy = ImGui.GetItemRectMin(ctx)
    local ax, ay = ImGui.GetItemRectMax(ctx)
    local dl     = ImGui.GetWindowDrawList(ctx)
    local m_col  = rgba(0.224, 1.000, 0.078, 0.65)
    local _, m_h = ImGui.CalcTextSize(ctx, '<')
    local _, r_w = ImGui.CalcTextSize(ctx, '>')
    local m_y    = (sy + ay) / 2 - m_h / 2
    ImGui.DrawList_AddTextEx(dl, font_ui, fs(15), sx + 10, m_y, m_col, '<')
    ImGui.DrawList_AddTextEx(dl, font_ui, fs(15), ax - r_w - 10, m_y, m_col, '>')
  end
  ImGui.PopStyleColor(ctx, 4)
  ImGui.PopStyleVar(ctx, 2)
  ImGui.PopFont(ctx)

  -- Info lines, split into two centered rows
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

--------------------------------------------------------------------
-- Tab 1: note values
--------------------------------------------------------------------
local function draw_notes(beat_ms)
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
  for _, division in ipairs(DIVISIONS) do
    local beats = 4 / division

    for _, variant in ipairs(VARIANTS) do
      local enabled = (variant.suffix == '') or
                      (variant.suffix == '.' and state.dotted) or
                      (variant.suffix == 'T' and state.triplet)
      if enabled then
        local ms = beat_ms * beats * variant.factor
        local hz = 1000 / ms

        ImGui.TableNextRow(ctx)

        ImGui.TableNextColumn(ctx)
        ImGui.TextColored(ctx, variant.color,
          string.format('1/%d%s', division, variant.suffix))

        ImGui.TableNextColumn(ctx)
        draw_value_cell(string.format('%6.1f', ms), string.format('%.1f', ms), variant.soft)

        ImGui.TableNextColumn(ctx)
        draw_value_cell(string.format('%6.3f', hz), string.format('%.3f', hz), variant.soft)
      end
    end
  end
  ImGui.PopFont(ctx)

  ImGui.EndTable(ctx)
end

--------------------------------------------------------------------
-- Tab 2: bars
--------------------------------------------------------------------
local function draw_bars(beat_sec)
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

  local bar_beats = sig[1] * 4 / sig[2]
  ImGui.PushFont(ctx, font_mono, fs(14))
  for _, count in ipairs(BAR_COUNTS) do
    local sec = beat_sec * bar_beats * count
    local hz  = 1 / sec

    ImGui.TableNextRow(ctx)

    ImGui.TableNextColumn(ctx)
    ImGui.TextColored(ctx, ACID,
      (count == 1) and '1 bar' or string.format('%d bars', count))

    ImGui.TableNextColumn(ctx)
    draw_value_cell(string.format('%6.3f', sec), string.format('%.3f', sec), ACID_SOFT)

    ImGui.TableNextColumn(ctx)
    draw_value_cell(string.format('%6.3f', hz), string.format('%.3f', hz), ACID_SOFT)
  end
  ImGui.PopFont(ctx)

  ImGui.EndTable(ctx)
end

--------------------------------------------------------------------
-- Footer
--------------------------------------------------------------------
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

--------------------------------------------------------------------
-- Frame loop
--------------------------------------------------------------------
local function frame()
  if state.sync then
    state.bpm = reaper.Master_GetTempo()
  end
  if state.bpm ~= state.last_bpm then
    state.last_bpm = state.bpm
    state.flash_t  = os.clock()
  end

  ImGui.SetNextWindowSize(ctx, 420, 580, ImGui.Cond_FirstUseEver)
  -- one-time reset to the compact layout after the 2026-09 tightening pass
  if reaper.GetExtState('TT_BPM_Calculator', 'layout') ~= '2' then
    ImGui.SetNextWindowSize(ctx, 420, 580, ImGui.Cond_Always)
    reaper.SetExtState('TT_BPM_Calculator', 'layout', '2', true)
  end
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
        draw_notes(60000 / state.bpm)
        ImGui.EndTabItem(ctx)
      end
      if ImGui.BeginTabItem(ctx, 'BARS') then
        draw_bars(60 / state.bpm)
        ImGui.EndTabItem(ctx)
      end
      ImGui.EndTabBar(ctx)
    end

    draw_footer()
    ImGui.End(ctx)
  end

  ImGui.PopStyleColor(ctx, #STYLE_COLORS)
  ImGui.PopStyleVar(ctx, 7)

  if open then
    reaper.defer(frame)
  end
end

reaper.defer(frame)
