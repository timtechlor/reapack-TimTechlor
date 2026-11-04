-- @description TT Theme Adjuster (Tim Techlor REAPER theme: background, accent, items, contrast - live)
-- @version 1.0.0
-- @author Tim Techlor
-- @about
--   Live adjuster for the Tim Techlor REAPER theme: background lift, tint, panel steps, grid,
--   eleven accent schemes (including ACID DARK) or a custom colour, item brightness, track colours,
--   font sizes, UI scale, a contrast check, and BAKE THEME.
--   Menu: load Scripts/Cockos/Tim Techlor_theme_adjuster.lua once. Options > Themes > Theme Adjuster
--   then opens this window while Clean & Flat Acid by Tim Techlor, or Clean & Flat Acid (Adjusted), is selected.
--   Persist with BAKE THEME, or set TT_ThemeAdjuster_Apply.lua as the SWS startup action.
--   The startup action restores colours without a window. If SELECTION FRAME or LOGO WATERMARK
--   was on, it keeps drawing those overlays.
--   Needs ReaImGui 0.10+ for the window. js_ReaScriptAPI for BAKE, APPLY FONTS and the overlays.
--   SWS for the UI scale buttons and the startup action. UNDO ALL returns the theme defaults.
--   GENERATED FILE: edit TT_ThemeAdjuster.lua.tpl and run gen_adjuster.py.
-- @changelog
--   1.0.0 First public build. Live background, grid, accent, items, track colours, fonts and UI scale.
--         BAKE THEME writes Clean & Flat Acid (Adjusted). The theme menu opens this adjuster.
--         With the startup action, a selection frame or logo watermark that was switched on stays drawn.

local R = reaper
local VERSION = "1.0.0"
local NS = "TT_ThemeAdjuster"
local APPLY_ONLY = rawget(_G, "TT_ADJ_APPLY_ONLY") == true

local THEME_META = {
  name = "Clean & Flat Acid",
  list = "Clean & Flat Acid by Tim Techlor",
  match = "clean & flat acid",
  legacy = "tim techlor",
  adjusted = "Clean & Flat Acid (Adjusted)",
  presets_file = "tt_themeadjuster_presets.txt",
}
local SCHEMES = {
  { "ACID", "#39FF14", "#FFB35C" },
  { "CYAN", "#22D3EE", "#FF9E4C" },
  { "ORANGE", "#FF5A1F", "#59D9FF" },
  { "MAGENTA", "#E040FB", "#59FFBF" },
  { "YELLOW", "#FFD60A", "#73BFFF" },
  { "RED", "#FF2D55", "#FFC759" },
  { "BLUE", "#4C8CFF", "#FFBF4C" },
  { "VIOLET", "#9E7AFF", "#FFB866" },
  { "MINT", "#2DE2A6", "#FF9973" },
  { "ICE", "#E6EDF5", "#FFB25C" },
  { "ACID DARK", "#24B810", "#FFB35C" },
}
local OVERLAYS = {
  ["col_gridlines"] = { "col_gridlines1dm", 26 },
  ["col_gridlines2"] = { "col_gridlines2dm", 56 },
  ["col_gridlines3"] = { "col_gridlines3dm", 22 },
  ["midi_grid1"] = { "midi_griddm1", 18 },
  ["midi_grid2"] = { "midi_griddm2", 34 },
  ["midi_grid3"] = { "midi_griddm3", 60 },
  ["midi_gridh"] = { "midi_gridhdm", 22 },
  ["midi_gridhc"] = { "midi_gridhcdm", 48 },
  ["tcp_list_scrollbar"] = { "tcp_list_scrollbar_mode", 30 },
}
local NOTE_TEXT_MODES = {
  ["midifont_mode_unsel"] = 235,
  ["midifont_mode"] = 235,
  ["mute_overlay_mode"] = 90,
}
local NOTE_CHANNELS = { "#39FF14", "#00E5FF", "#FF5CC8", "#FFD60A", "#FF7A1A", "#B388FF", "#6A9CFF", "#FF6670", "#2DE2A6", "#E6EDF5", "#C6FF00", "#FF9EC7", "#7FDBFF", "#FFA94D", "#9AA9FF", "#A0FFB0" }
local SKIP_LIVE = {
  ["col_main_bg"] = true,
  ["col_seltrack2"] = true,
  ["col_tr1_ps2"] = true,
}

-- ---------------------------------------------------------------- Helfer (handgeschrieben, wie tt_theme_palette.py)
local function clamp(x, lo, hi) lo = lo or 0; hi = hi or 255; if x < lo then return lo elseif x > hi then return hi end return x end
local function mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end
local function scale(c, k) return { clamp(c[1] * k), clamp(c[2] * k), clamp(c[3] * k) } end
local function lin(c) c = c / 255.0; if c <= 0.04045 then return c / 12.92 end return ((c + 0.055) / 1.055) ^ 2.4 end
local function luminance(c) return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3]) end
local function contrast(a, b)
  local la, lb = luminance(a), luminance(b)
  if la < lb then la, lb = lb, la end
  return (la + 0.05) / (lb + 0.05)
end
local function lift_to_contrast(fg, bg, target)
  local toward = (luminance(bg) < 0.4) and { 255, 255, 255 } or { 0, 0, 0 }
  for i = 0, 40 do
    local c = mix(fg, toward, i / 40.0)
    if contrast(c, bg) >= target then return c end
  end
  return toward
end
local function pick_text(bg, light, dark)
  light = light or { 255, 255, 255 }; dark = dark or { 0, 0, 0 }
  if contrast(light, bg) >= contrast(dark, bg) then return light end
  return dark
end
local function hex2rgb(h)
  h = h:gsub("^#", "")
  return { tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16) }
end
local function accent_of(p)
  if p.accent_hex and p.accent_hex ~= "" then return hex2rgb(p.accent_hex) end
  return hex2rgb(SCHEMES[p.scheme + 1][2])
end
local function alt_of(p) return hex2rgb(SCHEMES[p.scheme + 1][3]) end
local Ladder = {}
Ladder.__index = Ladder
local function new_ladder(p)
  local self = setmetatable({}, Ladder)
  self.v0 = 13 + 61 * (p.lift ^ 1.25)
  self.dv = 3.0 * p.step
  local a = accent_of(p)
  local m = (a[1] + a[2] + a[3]) / 3.0
  self.tintv = {}
  for i = 1, 3 do self.tintv[i] = 1 + p.tint * 0.22 * ((a[i] - m) / 255.0) end
  return self
end
function Ladder:S(n)
  local v = self.v0 + n * self.dv
  return { clamp(v * self.tintv[1]), clamp(v * self.tintv[2]), clamp(v * self.tintv[3]) }
end
function Ladder:cap(rgb, vmax)
  local m = (rgb[1] + rgb[2] + rgb[3]) / 3.0
  if m <= vmax then return rgb end
  return { rgb[1] * vmax / m, rgb[2] * vmax / m, rgb[3] * vmax / m }
end

local function build_overrides(p)
  local o = {}
  local A = accent_of(p)
  local ALT = alt_of(p)
  local L = new_ladder(p)
  local function S(n) return L:S(n) end
  local ink = mix({ 191, 207, 191 }, { 255, 255, 255 }, (0.18 + (0.7 * p.text)))
  local ink2 = mix(ink, S(0), 0.38)
  local dim = scale(A, 0.58)
  local deep = scale(A, 0.4)
  local gk = p.grid
  local P = S(4)
  o["col_main_bg2"] = P
  o["col_main_text2"] = lift_to_contrast(ink2, P, 4.5)
  o["col_main_textshadow"] = P
  o["col_main_3dhl"] = P
  o["col_main_3dsh"] = P
  o["col_main_resize2"] = dim
  o["col_main_bg"] = S(5)
  o["col_main_text"] = lift_to_contrast(ink, S(5), 7.0)
  o["col_main_editbk"] = S(1)
  o["col_transport_editbk"] = S((-4))
  o["col_toolbar_text"] = lift_to_contrast(ink2, S(4), 4.5)
  o["col_toolbar_text_on"] = A
  o["col_toolbar_frame"] = S(9)
  o["toolbararmed_color"] = ALT
  o["io_text"] = ink
  o["io_3dhl"] = S(8)
  o["io_3dsh"] = S((-1))
  o["genlist_bg"] = S(1.5)
  o["genlist_fg"] = ink
  o["genlist_grid"] = S(4)
  o["genlist_selbg"] = deep
  o["genlist_selfg"] = pick_text(deep)
  o["genlist_seliabg"] = S(6)
  o["genlist_seliafg"] = ink
  o["genlist_hilite"] = A
  o["genlist_hilite_sel"] = mix(A, { 255, 255, 255 }, 0.5)
  o["col_buttonbg"] = S(0)
  o["col_tcp_text"] = ink
  o["col_tcp_textsel"] = { 255, 255, 255 }
  o["col_seltrack"] = mix(S(7), A, 0.22)
  o["col_seltrack2"] = mix(S(7), A, 0.22)
  o["tcplocked_color"] = S(2)
  o["col_tracklistbg"] = P
  o["col_mixerbg"] = P
  o["col_arrangebg"] = S(0)
  o["col_tr1_bg"] = S(1.2)
  o["col_tr2_bg"] = S(2.2)
  o["selcol_tr1_bg"] = mix(S(5), A, 0.1)
  o["selcol_tr2_bg"] = mix(S(4), A, 0.1)
  o["col_tr1_divline"] = S(0)
  o["col_tr2_divline"] = S(0)
  o["col_envlane1_divline"] = S((6 * gk))
  o["col_envlane2_divline"] = S((6 * gk))
  o["track_lane_tabcol"] = S(8)
  o["track_lane_gutter"] = S(4)
  o["col_tl_fg"] = lift_to_contrast(ink, S(4), 7.0)
  o["col_tl_fg2"] = lift_to_contrast(ink2, S(4), 4.5)
  o["col_tl_bg"] = S(4)
  o["col_tl_bgsel"] = A
  o["col_tl_bgsel2"] = dim
  o["col_trans_bg"] = S(3)
  o["col_trans_fg"] = lift_to_contrast(ink2, S(3), 4.5)
  o["playrate_edited"] = ALT
  o["col_cursor"] = A
  o["col_cursor2"] = A
  o["playcursor_color"] = { 255, 255, 255 }
  local it_u = p.item_unsel
  local it_s = p.item_sel
  local selbg1 = mix(S(5), A, 0.1)
  local unsel_body = lift_to_contrast(scale(mix(S(10), { 150, 175, 150 }, 0.55), it_u), selbg1, 3.0)
  local sel_body = lift_to_contrast(scale(mix(unsel_body, { 255, 255, 255 }, 0.42), it_s), selbg1, 4.5)
  o["col_tr1_itembgsel"] = sel_body
  o["col_tr2_itembgsel"] = sel_body
  o["col_tr1_peaks"] = { 12, 16, 12 }
  o["col_tr2_peaks"] = { 12, 16, 12 }
  o["col_peaksedge"] = S((-1))
  o["col_peaksedge2"] = S((-1))
  o["col_peaksedgesel"] = { 255, 255, 255 }
  o["col_peaksedgesel2"] = { 255, 255, 255 }
  o["col_mi_label"] = { 12, 16, 12 }
  o["col_mi_label_sel"] = { 0, 0, 0 }
  o["col_mi_label_float"] = ink
  o["col_mi_label_float_sel"] = { 255, 255, 255 }
  o["col_mi_bg"] = unsel_body
  o["col_mi_bg2"] = sel_body
  o["selitem_dot"] = A
  o["selitem_tag"] = A
  o["item_grouphl"] = A
  o["activetake_tag"] = ALT
  o["col_offlinetext"] = lift_to_contrast(ink2, S(2), 3.0)
  o["mute_overlay_col"] = S(2)
  o["inactive_take_overlay_col"] = S(0)
  o["region_lane_bg"] = S(3)
  o["region_lane_text"] = lift_to_contrast(ink, S(3), 7.0)
  o["marker_lane_bg"] = S(3)
  o["marker_lane_text"] = lift_to_contrast(ink2, S(3), 4.5)
  o["ts_lane_bg"] = S(3)
  o["ts_lane_text"] = lift_to_contrast(ink2, S(3), 4.5)
  o["docker_shadow"] = S(0)
  o["docker_selface"] = S(7)
  o["docker_unselface"] = S(3)
  o["docker_text"] = ink
  o["docker_text_sel"] = { 255, 255, 255 }
  o["docker_bg"] = S(2)
  o["windowtab_bg"] = S(2)
  o["auto_item_unsel"] = S(8)
  o["midi_rulerbg"] = S(4)
  o["midi_rulerfg"] = lift_to_contrast(ink2, S(4), 4.5)
  local lane1 = L:cap(S(1.6), 40.0)
  local lane2 = L:cap(S((-1.2)), 31.0)
  o["midi_trackbg1"] = lane1
  o["midi_trackbg2"] = lane2
  o["midi_trackbg_outer1"] = L:cap(S(0), 30.0)
  o["midi_trackbg_outer2"] = L:cap(S((-0.5)), 26.0)
  o["midi_selpitch1"] = mix(S(5), A, 0.18)
  o["midi_selpitch2"] = mix(S(4), A, 0.18)
  o["midi_ccbut"] = S(7)
  o["midi_ccbut_text"] = lift_to_contrast(ink, S(7), 4.5)
  o["midi_ccbut_arrow"] = lift_to_contrast(ink, S(7), 4.5)
  o["midi_inline_trackbg1"] = lane1
  o["midi_inline_trackbg2"] = lane2
  o["midi_endpt"] = A
  o["midi_notebg"] = { 0, 0, 0 }
  o["midi_notefg"] = { 255, 255, 255 }
  o["midi_notemute"] = (p.mute_amber and ALT or { 255, 0, 0 })
  o["midi_notemute_sel"] = mix(ALT, { 255, 255, 255 }, 0.5)
  o["midi_ofsn"] = dim
  o["midi_ofsnsel"] = A
  o["midi_editcurs"] = A
  o["midi_pkey1"] = { 236, 240, 236 }
  o["midi_pkey2"] = { 14, 16, 14 }
  o["midi_pkey3"] = dim
  o["midi_noteon_flash"] = A
  o["midi_leftbg"] = S(4)
  o["midifont_col_light_unsel"] = { 255, 255, 255 }
  o["midifont_col_dark_unsel"] = { 0, 0, 0 }
  o["midifont_col_light"] = { 255, 255, 255 }
  o["midifont_col_dark"] = { 0, 0, 0 }
  o["midieditorlist_bg"] = S(1.5)
  o["midieditorlist_fg"] = ink
  o["midieditorlist_grid"] = S(4)
  o["midieditorlist_selbg"] = deep
  o["midieditorlist_selfg"] = pick_text(deep)
  o["midieditorlist_seliabg"] = S(6)
  o["midieditorlist_seliafg"] = ink
  o["midieditorlist_bg2"] = S(2.5)
  o["midieditorlist_fg2"] = lift_to_contrast(ink2, S(2.5), 4.5)
  o["midieditorlist_selbg2"] = deep
  o["midieditorlist_selfg2"] = pick_text(deep)
  o["col_explorer_sel"] = A
  o["explorer_grid"] = S(6)
  o["explorer_pitchtext"] = ink
  o["mcp_sends_normal"] = mix(ink, { 255, 255, 255 }, 0.6)
  o["mcp_sends_muted"] = lift_to_contrast(ink2, P, 4.0)
  o["mcp_fx_normal"] = mix(ink, { 255, 255, 255 }, 0.6)
  o["mcp_fx_bypassed"] = ALT
  o["mcp_fx_offlined"] = lift_to_contrast(ink2, P, 4.0)
  o["mcp_fxparm_normal"] = mix(ink, { 255, 255, 255 }, 0.5)
  o["mcp_fxparm_bypassed"] = scale(ALT, 0.7)
  o["mcp_fxparm_offlined"] = lift_to_contrast(scale(ink2, 0.7), P, 3.0)
  o["tcp_list_scrollbar_mouseover"] = dim
  o["mcp_list_scrollbar_mouseover"] = dim
  o["wiring_grid2"] = S(3)
  o["wiring_grid"] = S(2)
  o["wiring_border"] = S(9)
  o["wiring_tbg"] = S(4)
  o["wiring_ticon"] = ink
  o["wiring_recbg"] = S(5)
  o["wiring_parent"] = S(9)
  o["wiring_pin_normal"] = lift_to_contrast(ink2, S(4), 4.5)
  o["wiring_pin_connected"] = dim
  o["wiring_pin_disconnected"] = S(5)
  o["wiring_horz_col"] = S(7)
  o["wiring_sendwire"] = lift_to_contrast(S(9), S(2), 3.0)
  o["wiring_hwoutwire"] = lift_to_contrast(S(9), S(2), 3.0)
  o["wiring_hwout"] = S(6)
  o["wiring_recinput"] = S(6)
  o["wiring_activity"] = A
  o["vu_gr_bgcol"] = S(2)
  o["vu_gr_fgcol"] = A
  o["col_vuintcol"] = S(2)
  o["col_vubot"] = { 57, 230, 64 }
  o["col_vumid"] = { 231, 222, 58 }
  o["col_vutop"] = { 255, 153, 48 }
  o["col_vuclip"] = { 245, 64, 72 }
  o["col_vuind1"] = S(2)
  o["pinned_track_gap"] = S(0)
  o["track_lanesolo_text"] = ink
  o["arrange_vgrid"] = S((3.5 + (2 * gk)))
  o["midioct"] = S((7 + (3 * gk)))
  o["midioct_inline"] = S((7 + (3 * gk)))
  local lv = clamp((30 + ((225 * (0.4 + gk)) / 3.4)))
  for key, _ in pairs(OVERLAYS) do
    o[key] = { lv, lv, lv }
  end
  return o
end

local function build_modes(p)
  local out = {}
  for _, def in pairs(OVERLAYS) do
    local al = math.floor(clamp(def[2] * 3.4, 0, 255) + 0.5)
    out[def[1]] = (2 << 16) | (al << 8)
  end
  for key, al in pairs(NOTE_TEXT_MODES) do out[key] = (2 << 16) | (al << 8) end
  return out
end


-- ---------------------------------------------------------------- Zustand
local DEFAULTS = {
  scheme = 0, accent_hex = "", lift = 0.35, tint = 0.6, step = 1.0, grid = 1.0, text = 0.0,
  item_unsel = 1.0, item_sel = 1.0, mute_amber = true, sel_frame = false, wm_on = false, wm_op = 0.08, wm_size = 0.55, wm_corner = false, tc_int = 1.0, tc_pick = 0,
  fs_names = 1.0, fs_values = 1.0, fs_master = 1.0, fs_trans = 1.0, fs_items = 1.0, fs_ruler = 1.0, fs_general = 1.0,
}
local ORDER = { "scheme", "accent_hex", "lift", "tint", "step", "grid", "text", "item_unsel", "item_sel", "mute_amber", "sel_frame", "wm_on", "wm_op", "wm_size", "wm_corner", "tc_int", "tc_pick",
  "fs_names", "fs_values", "fs_master", "fs_trans", "fs_items", "fs_ruler", "fs_general" }
local FS_KEYS = { "fs_names", "fs_values", "fs_master", "fs_trans", "fs_items", "fs_ruler", "fs_general" }
local FS_MIN, FS_MAX, FS_MINPX = 0.7, 2.0, 12
local PRESETS_BUILTIN = {
  { "ACID BLACK", { lift = 0.0, tint = 0.6, step = 1.0, grid = 1.0, text = 0.0 } },
  { "GRAPHITE", { lift = 0.35, tint = 0.6, step = 1.0, grid = 1.0, text = 0.0 } },
  { "SLATE", { lift = 0.8, tint = 0.4, step = 1.1, grid = 1.2, text = 0.2 } },
  { "SLATE HIGH CONTRAST", { lift = 1.0, tint = 0.3, step = 1.3, grid = 1.6, text = 0.6 } },
}

local function copy(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end
local S = copy(DEFAULTS)

local function ser(t)
  local out = {}
  for _, k in ipairs(ORDER) do
    local v = t[k]
    if v ~= nil then out[#out + 1] = k .. "=" .. tostring(v) end
  end
  return table.concat(out, ";")
end

local function deser(s, base)
  local t = copy(base or DEFAULTS)
  for k, v in (s or ""):gmatch("([%w_]+)=([^;]*)") do
    if DEFAULTS[k] ~= nil then
      if type(DEFAULTS[k]) == "number" then t[k] = tonumber(v) or t[k]
      elseif type(DEFAULTS[k]) == "boolean" then t[k] = (v == "true")
      else t[k] = v end
    end
  end
  return t
end

local STATUS = "Ready."
local function set_status(s) STATUS = tostring(s) end

local function save_state() R.SetExtState(NS, "state", ser(S), true) end
local function load_state()
  local s = R.GetExtState(NS, "state")
  if s and s ~= "" then S = deser(s) end
  for _, k in ipairs(FS_KEYS) do
    local v = tonumber(S[k]) or 1.0
    S[k] = math.max(FS_MIN, math.min(FS_MAX, v))
  end
end

-- Signatur der Schriftfaktoren (auf 0,01 gerundet): erkennt, ob das geladene Theme zu S passt
local function fs_sig(t)
  local o = {}
  for _, k in ipairs(FS_KEYS) do o[#o + 1] = string.format("%.2f", tonumber(t[k]) or 1.0) end
  return table.concat(o, ",")
end

-- ---------------------------------------------------------------- Anwenden (live)
local function native(c)
  local r, g, b = math.floor(clamp(c[1]) + 0.5), math.floor(clamp(c[2]) + 0.5), math.floor(clamp(c[3]) + 0.5)
  return r | (g << 8) | (b << 16)
end

local function theme_path() return (R.GetLastColorThemeFile and R.GetLastColorThemeFile()) or "" end
local function is_tt_theme()
  local p = theme_path():lower()
  if p == "" then return false end
  p = p:match("([^/\\]+)$") or p   -- nur der Dateiname zaehlt (ein Ordner "Tim Techlor" im Pfad macht kein Theme zum TT-Theme)
  if R.GetExtState and R.GetExtState(NS, "allow_any_theme") == "1" then return true end
  local custom_match = R.GetExtState and R.GetExtState(NS, "theme_match") or ""
  if custom_match ~= "" then return p:find(custom_match:lower(), 1, true) ~= nil end
  local pat = (THEME_META and THEME_META.match) or "clean & flat acid"
  local legacy = (THEME_META and THEME_META.legacy) or "tim techlor"
  return p:find(pat, 1, true) ~= nil or p:find(legacy, 1, true) ~= nil
end

local ORIG_PARAMS = {}     -- Index -> Originalwert (fuer UNDO ALL)

local PARAM_BG = {   -- rtconfig-Parameter (Basisname, Stufe der Flaechenleiter)
  { "tcpBgCol", 4 }, { "mcpBgCol", 4 }, { "masterTcpBgCol", 3 }, { "masterMcpBgCol", 3 },
  { "envcpBgCol", 3 }, { "transBgCol", 3 }, { "transStatusCol", -4 },
}

local function set_layout_params(p)
  if not R.ThemeLayout_GetParameter or not R.ThemeLayout_SetParameter then return 0 end
  local idx, vals = {}, {}
  for i = 0, 3000 do
    local ok, a, b, v, def = pcall(R.ThemeLayout_GetParameter, i)
    if not ok or a == nil then break end
    if type(a) == "string" then idx[a] = i end
    if type(b) == "string" then idx[b] = idx[b] or i end
    -- Historie: vals[i] war der aktuelle Wert (3. Rueckgabewert); in einer neuen Sitzung ist der schon der angepasste.
    -- UNDO ALL braucht den Theme-Default (4. Rueckgabewert, defValue); Rueckfall auf den aktuellen Wert, falls es ihn nicht gibt.
    vals[i] = tonumber(def) or tonumber(v) or tonumber(b)
  end
  local L = new_ladder(p)
  local n = 0
  for _, d in ipairs(PARAM_BG) do
    local c = L:S(d[2])
    for j, ch in ipairs({ "R", "G", "B" }) do
      local i = idx[d[1] .. ch]
      if i then
        if ORIG_PARAMS[i] == nil then ORIG_PARAMS[i] = vals[i] end
        R.ThemeLayout_SetParameter(i, math.floor(clamp(c[j]) + 0.5), true)
        n = n + 1
      end
    end
  end
  -- Akzent als Layout-Parameter (18.10.2026): Fader-Schienen, 0-dB-Linien und Auswahlmarken im rtconfig folgen ttAccR/G/B
  local a = accent_of(p)
  for j, ch in ipairs({ "R", "G", "B" }) do
    local i = idx["ttAcc" .. ch]
    if i then
      if ORIG_PARAMS[i] == nil then ORIG_PARAMS[i] = vals[i] end
      R.ThemeLayout_SetParameter(i, math.floor(clamp(a[j]) + 0.5), true)
      n = n + 1
    end
  end
  return n
end

local LAST_APPLY = { miss = 0, set = 0, params = 0 }

local function restore_params()
  if not R.ThemeLayout_SetParameter then return end
  for i, v in pairs(ORIG_PARAMS) do if v then R.ThemeLayout_SetParameter(i, v, true) end end
  ORIG_PARAMS = {}
end

local function apply(p, quick)
  if not is_tt_theme() then
    set_status("The Tim Techlor theme is not loaded - nothing applied")
    return 0, 0, 0
  end
  local ov = build_overrides(p)
  local modes = build_modes(p)
  local set, miss = 0, 0
  for k, c in pairs(ov) do
    if not SKIP_LIVE[k] then
      local rv = R.SetThemeColor(k, native(c), 0)
      if rv == -1 then miss = miss + 1 else set = set + 1 end
    end
  end
  for k, v in pairs(modes) do
    local rv = R.SetThemeColor(k, v, 0)
    if rv == -1 then miss = miss + 1 else set = set + 1 end
  end
  -- GRID: die Staerke steckt in der Linienfarbe (live); der Drawmode-Alpha ist konstant -> keine Rueckkontrolle noetig
  local np = LAST_APPLY.params or 0
  if not quick then np = set_layout_params(p) end
  if R.ThemeLayout_RefreshAll then R.ThemeLayout_RefreshAll() end
  R.UpdateArrange()
  if R.UpdateTimeline then R.UpdateTimeline() end
  R.TrackList_AdjustWindows(false)
  LAST_APPLY = { miss = miss, set = set, params = np }
  return set, miss, np
end

-- ---------------------------------------------------------------- Kontrastbericht
local function contrast_report(p)
  local ov = build_overrides(p)
  local rows = {}
  local function row(name, fg, bg, need)
    local c = contrast(fg, bg)
    rows[#rows + 1] = { name = name, c = c, need = need }
  end
  row("TRACK TEXT / PANEL", ov["col_tcp_text"], ov["col_tracklistbg"], 4.5)
  row("RULER TEXT / RULER", ov["col_tl_fg"], ov["col_tl_bg"], 4.5)
  row("MENU TEXT / MENU", ov["col_main_text"], ov["col_main_bg"], 4.5)
  row("TRACK BG / ARRANGE BG", ov["col_tr1_bg"], ov["col_arrangebg"], 1.02)
  row("MIDI LANE LIGHT / DARK", ov["midi_trackbg1"], ov["midi_trackbg2"], 1.1)
  local worst, wi = 99, 0
  for i, hx in ipairs(NOTE_CHANNELS) do
    local c = math.min(contrast(hex2rgb(hx), ov["midi_trackbg1"]), contrast(hex2rgb(hx), ov["midi_trackbg2"]))
    if c < worst then worst, wi = c, i end
  end
  rows[#rows + 1] = { name = "WORST NOTE (CH " .. wi .. ") / LANE", c = worst, need = 4.5 }
  return rows
end

-- ---------------------------------------------------------------- Presets (Datei im Ressourcenordner)
local PRESET_FILE = R.GetResourcePath() .. "/" .. ((THEME_META and THEME_META.presets_file) or "tt_themeadjuster_presets.txt")
local USER_PRESETS = {}

local function load_presets()
  USER_PRESETS = {}
  local f = io.open(PRESET_FILE, "r")
  if not f then return end
  for line in f:lines() do
    local name, rest = line:match("^(.-)\t(.*)$")
    if name and name ~= "" then USER_PRESETS[#USER_PRESETS + 1] = { name, rest } end
  end
  f:close()
end

local function save_presets()   -- 25.10.2026 (Review R018): true/false zurueckgeben, Schreib-/Close-Fehler pruefen
  local f = io.open(PRESET_FILE, "w")
  if not f then set_status("Cannot write preset file") return false end
  local ok = true
  for _, p in ipairs(USER_PRESETS) do ok = (f:write(p[1], "\t", p[2], "\n") ~= nil) and ok end
  ok = (f:close() ~= false) and ok
  if not ok then set_status("Cannot write preset file") return false end
  return true
end

-- ---------------------------------------------------------------- Bake (persistente .ReaperTheme)
local function read_file(p)
  local f = io.open(p, "rb"); if not f then return nil end
  local d = f:read("*a"); f:close(); return d
end

-- Schriftgruppen. user_font0..14 = 3 Massstaebe (100/150/200 %) x 5 Groessenklassen (n % 5, siehe rtconfig.txt:
-- font #1/6/11 ... #5/10/15); user_font15 und die Altschriften lb_font/lb_font2 gehoeren zu GENERAL.
local function font_group(key)
  local n = key:match("^user_font(%d+)$")
  if n then
    n = tonumber(n)
    if n >= 15 then return "fs_general" end
    local c = n % 5
    if c == 0 then return "fs_values" elseif c == 1 or c == 2 then return "fs_master" end
    return "fs_names"
  end
  if key == "trans_font" then return "fs_trans" elseif key == "mi_font" then return "fs_items" elseif key == "tl_font" then return "fs_ruler" end
  return "fs_general"
end

-- LOGFONT-Blob (60 Bytes + Pruefsumme, Codec wie TT_ThemeFontEditor): nur die Hoehe (Bytes 1-4) wird geaendert, nie der Name.
-- Rueckgabe: neuer Hex-Text (oder der alte bei f == 1), oder nil wenn kein gueltiger Blob.
local function font_scaled(hex, f)
  if type(hex) ~= "string" or #hex < 122 or #hex % 2 ~= 0 or not hex:match("^[0-9A-Fa-f]+$") then return nil end
  local b = {}
  for i = 1, #hex, 2 do b[#b + 1] = tonumber(hex:sub(i, i + 1), 16) end
  local sum = 0
  for i = 1, 60 do sum = (sum + b[i]) % 256 end
  if sum ~= b[61] then return nil end
  local v = b[1] + b[2] * 256 + b[3] * 65536 + b[4] * 16777216
  if v >= 2147483648 then v = v - 4294967296 end
  if v == 0 then return nil end
  if f == 1 then return hex end
  local px = math.max(FS_MINPX, math.min(96, math.floor(math.abs(v) * f + 0.5)))
  local nv = (v < 0) and -px or px
  if nv < 0 then nv = 4294967296 + nv end
  b[1] = nv % 256; b[2] = math.floor(nv / 256) % 256
  b[3] = math.floor(nv / 65536) % 256; b[4] = math.floor(nv / 16777216) % 256
  sum = 0
  for i = 1, 60 do sum = (sum + b[i]) % 256 end
  b[61] = sum
  local o = {}
  for i = 1, #b do o[i] = string.format("%02X", b[i]) end
  return table.concat(o)
end

-- Die unveraenderte Theme-Datei: ist das geladene Theme die Variante "(Adjusted)", liegt das Original als .ReaperThemeZip daneben
local function locate_original(path)
  if path == "" or path:lower():match("%.reaperthemezip$") then return path end
  local dir, base = path:match("^(.*[/\\])([^/\\]+)$")
  if not dir then return path end
  local stem = base:gsub("%.[Rr]eaper[Tt]heme$", ""):gsub("%s*%([Aa]djusted%)$", "")
  local zp = dir .. stem .. ".ReaperThemeZip"
  local f = R.JS_Zip_Open and io.open(zp, "rb")
  if f then f:close() return zp end
  return path
end

-- Schreibt "Clean & Flat Acid (Adjusted).ReaperTheme" (Farben aus p, Schriften aus S.fs_*). opt.keep_cfg: vorhandenen
-- [themeconfig]-Abschnitt nicht ueberschreiben. Rueckgabe: Zielpfad, Zahl Farben, Zahl geaenderter Schriften (nil = Schriften
-- nicht angefasst, weil nur die schon angepasste Datei lesbar war) - oder nil, Fehlertext.
local function write_adjusted(p, opt)
  opt = opt or {}
  if not is_tt_theme() then return nil, "The Tim Techlor theme is not loaded - nothing written" end
  local path = R.GetLastColorThemeFile and R.GetLastColorThemeFile() or ""
  if path == "" then return nil, "No theme file known - select the Tim Techlor theme first" end
  path = locate_original(path)
  local fonts_ok = not path:lower():match("%(adjusted%)%.reapertheme$")
  local text, zipname
  if path:lower():match("%.reapertheme$") then
    text = read_file(path)
  elseif path:lower():match("%.reaperthemezip$") and R.JS_Zip_Open then
    zipname = path:match("([^/\\]+)$")
    local ok, zh = pcall(R.JS_Zip_Open, path, "r", 0)
    if ok and zh then
      local inner = zipname:gsub("%.[Rr]eaper[Tt]heme[Zz]ip$", ".ReaperTheme")
      local okE, rv = pcall(R.JS_Zip_Entry_OpenByName, zh, inner)
      if (not okE or (tonumber(rv) or -1) < 0) and R.JS_Zip_ListAllEntries then
        -- umbenanntes ZIP: der Eintragsname im Archiv bleibt der urspruengliche -> ersten .ReaperTheme-Eintrag nehmen
        local okL, count, entries = pcall(R.JS_Zip_ListAllEntries, zh, "")
        if okL and type(count) == "number" and count > 0 and type(entries) == "string" then
          for entry in entries:gmatch("[^%z]+") do
            if entry:lower():match("%.reapertheme$") then
              okE, rv = pcall(R.JS_Zip_Entry_OpenByName, zh, entry)
              break
            end
          end
        end
      end
      if okE and (tonumber(rv) or 0) >= 0 then
        local okX, rvX, data = pcall(R.JS_Zip_Entry_ExtractToMemory, zh)
        pcall(R.JS_Zip_Entry_Close, zh)
        if okX and type(rvX) == "number" and rvX >= 0 and type(data) == "string" and data ~= ""
            and data:find("[color theme]", 1, true) then text = data end
      end
      pcall(R.JS_Zip_Close, path, zh)
    end
  end
  if not text then return nil, "Could not read the theme (zip needs js_ReaScriptAPI)" end
  if opt.need_fonts and not fonts_ok then return nil, "Original theme zip not readable (needs js_ReaScriptAPI) - fonts not changed" end
  local ov, modes = build_overrides(p), build_modes(p)
  local out, n, in_color, nfonts = {}, 0, false, fonts_ok and 0 or nil
  for rawline in (text .. "\n"):gmatch("(.-)\r?\n") do
    local line = rawline
    local sec = line:match("^%[(.-)%]$")
    if sec then in_color = (sec == "color theme") end
    local key, val = line:match("^([^=;%[]+)=(-?%d+)$")
    local k2 = line:match("^([^=;%[]+)=")
    local fkey, fhex = line:match("^([%w_]*font%d*)=([0-9A-Fa-f]+)$")
    if fkey and fonts_ok then
      local f = tonumber(p[font_group(fkey)]) or 1.0
      local nh = font_scaled(fhex, f)
      if nh and nh ~= fhex then line = fkey .. "=" .. nh; nfonts = nfonts + 1 end
    elseif k2 == "ui_img" and zipname then
      line = "ui_img=" .. zipname
    elseif in_color and key and (ov[key] or modes[key]) then
      local old = math.tointeger(tonumber(val)) or 0
      if modes[key] then
        line = key .. "=" .. modes[key]
      else
        local flags = old & 0xFF000000
        local nv = flags | native(ov[key])
        if nv >= 0x80000000 then nv = nv - 0x100000000 end
        line = key .. "=" .. nv
      end
      n = n + 1
    end
    out[#out + 1] = line
  end
  local dir = R.GetResourcePath() .. "/ColorThemes/"
  local from = (zipname or path:match("([^/\\]+)$") or ""):gsub("%.[Rr]eaper[Tt]heme[Zz]?[Ii]?[Pp]?$", ""):gsub("%s*%([Aa]djusted%)$", "")
  local adj_stem = (THEME_META and THEME_META.adjusted) or "Clean & Flat Acid (Adjusted)"
  local function named(s)
    local a = ((THEME_META and THEME_META.match) or "clean & flat acid")
    local b = ((THEME_META and THEME_META.legacy) or "tim techlor")
    s = s:lower()
    return s:find(a, 1, true) or s:find(b, 1, true)
  end
  if from ~= "" and not named(from) then
    adj_stem = from .. " (Adjusted)"
  end
  local target = dir .. adj_stem .. ".ReaperTheme"
  local f = io.open(target, "wb")
  if not f then return nil, "Cannot write " .. target end
  local ok = f:write(table.concat(out, "\n"), "\n")
  local okc = f:close()
  -- 25.10.2026 (Review R016): Schreib-/Close-Fehler nicht als Erfolg melden
  if not ok or not okc then return nil, "Write failed: " .. target end
  -- Layout-Parameter (Hintergrund-Stufen) gehoeren zum Theme-Namen: Abschnitt in reaper-themeconfig.ini uebertragen
  pcall(function()
    local cfg = R.GetResourcePath() .. "/reaper-themeconfig.ini"
    local txt = read_file(cfg)
    if not txt then return end
    -- Historie: der erste Abschnitt der Datei hatte kein "\n" davor; der Treffer ab Position 1 liess beim Ersetzen ein "[" stehen
    -- ("[[Name]"). Jetzt steht immer ein "\n" vor dem ersten Abschnitt (am Ende wieder entfernt).
    local pre = txt:sub(1, 1) ~= "\n"
    if pre then txt = "\n" .. txt end
    local function find_sec(name)
      local pat = name:gsub("(%W)", "%%%1")
      return txt:find("\n%[" .. pat .. "%]")
    end
    -- Quelle = Abschnitt des aktuell geladenen Themes (dort liegen die frischen persist-Parameter), nicht des Originals.
    -- Historie: frueher immer `from` (Name des Originals) -> BAKE ueberschrieb den Adjusted-Abschnitt mit alten Werten.
    local cur = (R.GetLastColorThemeFile and R.GetLastColorThemeFile() or ""):match("([^/\\]+)$") or ""
    cur = cur:gsub("%.[Rr]eaper[Tt]heme[Zz]?[Ii]?[Pp]?$", "")
    local src = (cur ~= "" and find_sec(cur)) and cur or from
    if src == adj_stem then return end   -- Quelle gleich Ziel: nichts zu kopieren
    local s, e = find_sec(src)
    if not s then return end
    local e2 = txt:find("\n%[", e)
    local body = txt:sub(e + 1, e2 or -1)
    local to = adj_stem
    local ts, te = find_sec(to)
    if ts and opt.keep_cfg then return end
    if ts then
      local te2 = txt:find("\n%[", te)
      txt = txt:sub(1, ts) .. "[" .. to .. "]" .. body .. txt:sub(te2 or (#txt + 1))
    else
      txt = txt .. (txt:sub(-1) == "\n" and "" or "\n") .. "[" .. to .. "]" .. body
    end
    if pre then txt = txt:sub(2) end
    local wf = io.open(cfg, "wb"); if wf then wf:write(txt); wf:close() end
  end)
  return target, n, nfonts
end

local function bake(p)
  local target, n = write_adjusted(p)
  if not target then set_status(n) return end
  set_status(("Baked %d colours -> Options > Themes > 'Clean & Flat Acid (Adjusted)'"):format(n))
end

local last_theme_path = theme_path()
local dirty, last_apply_t, pending_params = false, 0, false
local fonts_dirty, fonts_t, fonts_seen, fonts_applied, fonts_force = false, 0, nil, nil, false
local function revert_theme()
  local path = locate_original(theme_path())
  dirty, pending_params, fonts_dirty, fonts_force = false, false, false, false
  restore_params()
  S = copy(DEFAULTS)
  fonts_applied = fs_sig(S)
  save_state()
  if path ~= "" and R.OpenColorThemeFile then
    local ok = R.OpenColorThemeFile(path)
    last_theme_path = theme_path()
    if ok == false then   -- 25.10.2026 (Review R017): fehlgeschlagener Reload -> Defaults live anwenden, Fonts ausstehend
      dirty, fonts_applied = true, nil
      set_status("Theme reload failed")
    else
      set_status("Theme reloaded - all adjustments undone")
    end
  end
end

-- Schriftgroessen: Schriften lassen sich nicht live aendern -> Theme-Datei neu schreiben (Basis = Originalhoehen aus der
-- unveraenderten Theme-Datei, Faktor aus S.fs_*) und neu laden. Danach dirty = true: Farben/Layout-Parameter neu anwenden.
local function run_fonts()
  fonts_dirty, fonts_force = false, false
  if not is_tt_theme() then set_status("The Tim Techlor theme is not loaded - fonts not written") return end
  if not R.OpenColorThemeFile then set_status("OpenColorThemeFile is not available - fonts not applied") return end
  local ok, target, n, nfonts = pcall(write_adjusted, S, { keep_cfg = true, need_fonts = true })
  if not ok then set_status("Fonts failed: " .. tostring(target)) return end
  if not target then set_status(n) return end
  local okr, loaded = pcall(R.OpenColorThemeFile, target)
  if not okr or not loaded then set_status("Theme reload failed: " .. tostring(loaded)) return end
  last_theme_path = theme_path()
  fonts_applied = fs_sig(S)
  dirty = true
  set_status(("Fonts applied: %d fonts resized, theme reloaded"):format(nfonts or 0))
end

-- UI-Skalierung (uiscale in reaper.ini, 1.0 / 1.25 / 1.5 / 2.0). Eine Systemeinstellung: nicht in S und nicht in Presets,
-- wird bei jedem Start gelesen. Historie: "HINWEIS: Das Setzen (SNM_SetDoubleConfigVar / ini-Schreiben) ist in REAPER nicht getestet."
-- In REAPER belegt (18.10.2026, Frische-Installation q1448, tests/fresh_install): 150 % setzen (live + reaper.ini), Neustart haelt 150 %,
-- zurueck auf 100 %, Neustart haelt 100 %. Die Oberflaeche skaliert erst nach dem Neustart sichtbar.
local function read_uiscale()
  if not R.get_config_var_string then return 1.0 end
  local okc, rv, s = pcall(R.get_config_var_string, "uiscale")
  local v = okc and rv and tonumber(s)
  if v and v > 0 then return v end
  return 1.0
end
local UI_SCALE = read_uiscale()
local UI_STEPS = { 1.0, 1.25, 1.5, 2.0 }

local function set_uiscale(v)
  local have_snm = R.SNM_SetDoubleConfigVar ~= nil
  local have_ini = R.BR_Win32_WritePrivateProfileString ~= nil and R.get_ini_file ~= nil
  if not have_snm and not have_ini then set_status("UI scale needs SWS (SNM_/BR_ functions)") return end
  local live_ok, ini_ok = false, false
  if have_snm then
    local ok, rv = pcall(R.SNM_SetDoubleConfigVar, "uiscale", v)
    live_ok = ok and rv == true
  end
  if have_ini then
    local ok, rv = pcall(function() return R.BR_Win32_WritePrivateProfileString("REAPER", "uiscale", tostring(v), R.get_ini_file()) end)
    ini_ok = ok and rv == true
  end
  if not live_ok and not ini_ok then set_status("UI scale could not be written") return end
  if R.ThemeLayout_RefreshAll then pcall(R.ThemeLayout_RefreshAll) end
  pcall(R.UpdateArrange)
  pcall(R.TrackList_AdjustWindows, true)
  UI_SCALE = read_uiscale()
  local pc = math.floor(v * 100 + 0.5)
  if math.abs(UI_SCALE - v) < 0.005 then set_status(("UI scale set to %d %%"):format(pc))
  else set_status(("UI scale set to %d %% (REAPER restart may be needed)"):format(pc)) end
end

-- ---------------------------------------------------------------- nur anwenden (Startup-Modus)
-- Farben sofort. Rahmen und Wasserzeichen erst weiter unten: die Zeichenfunktionen
-- stehen nach dem UI-Teil. Ohne diese Schalter endet das Skript hier, ohne Fenster.
-- ReaImGui ist fuer diesen Weg nicht noetig.
if APPLY_ONLY then
  load_state()
  local ok, err = pcall(apply, S, false)
  if not ok then R.ShowConsoleMsg("TT Theme Adjuster (apply): " .. tostring(err) .. "\n") end
  if not (S.sel_frame or S.wm_on) then return end
end

-- ---------------------------------------------------------------- Oberflaeche (ReaImGui)
local ctx
if not APPLY_ONLY then
  if not R.ImGui_CreateContext then
    R.MB("This script needs the ReaImGui extension (ReaPack: ReaTeam Extensions).", "TT Theme Adjuster", 0)
    return
  end
  ctx = R.ImGui_CreateContext("TT Theme Adjuster")
end
local ACID = 0x39FF14FF
local function rgba(c, a)
  return (math.floor(clamp(c[1]) + 0.5) << 24) | (math.floor(clamp(c[2]) + 0.5) << 16) | (math.floor(clamp(c[3]) + 0.5) << 8) | (a or 255)
end
local function acid_a(a) return 0x39FF1400 | math.floor(255 * a + 0.5) end

local FONT_UI
do
  -- Inter Medium: Windows-Schriftordner, Benutzer-Schriften, macOS; sonst Systemschrift
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
      if R.ImGui_CreateFontFromFile then local ok, fo = pcall(R.ImGui_CreateFontFromFile, d, 0); if ok then FONT_UI = fo; break end end
    end
  end
  if not FONT_UI then local ok, fo = pcall(R.ImGui_CreateFont, "sans-serif", 0); if ok then FONT_UI = fo end end
  if FONT_UI and ctx then R.ImGui_Attach(ctx, FONT_UI) end
end

local THEME_COLS = {
  { "WindowBg", 0x0D0E0DFF }, { "ChildBg", 0x0D0E0DFF }, { "PopupBg", 0x121412FF },
  { "Text", 0xD6E2D6FF }, { "TextDisabled", 0x8C8C8CFF },
  { "Border", acid_a(0.35) }, { "FrameBg", 0x1B1C1BFF }, { "FrameBgHovered", acid_a(0.18) }, { "FrameBgActive", acid_a(0.30) },
  { "Button", 0x1B1C1BFF }, { "ButtonHovered", acid_a(0.25) }, { "ButtonActive", acid_a(0.5) },
  { "Header", acid_a(0.18) }, { "HeaderHovered", acid_a(0.30) }, { "HeaderActive", acid_a(0.45) },
  { "SliderGrab", ACID }, { "SliderGrabActive", 0xFFFFFFFF }, { "CheckMark", ACID },
  { "Separator", acid_a(0.30) }, { "TitleBg", 0x0D0E0DFF }, { "TitleBgActive", 0x121412FF },
  { "ResizeGrip", acid_a(0.25) }, { "ResizeGripHovered", acid_a(0.6) }, { "ResizeGripActive", ACID },
}
local THEME_VARS = { { "WindowRounding", 0 }, { "FrameRounding", 0 }, { "GrabRounding", 0 }, { "PopupRounding", 0 }, { "FrameBorderSize", 1 } }

local function push_theme(kit)
  local nc, nv = 0, 0
  for _, c in ipairs(THEME_COLS) do
    local fn = R["ImGui_Col_" .. c[1]]
    if fn then R.ImGui_PushStyleColor(ctx, fn(), c[2]); nc = nc + 1 end
  end
  for _, v in ipairs(THEME_VARS) do
    local fn = R["ImGui_StyleVar_" .. v[1]]
    if fn then R.ImGui_PushStyleVar(ctx, fn(), v[2]); nv = nv + 1 end
  end
  if kit then R.ImGui_PushStyleVar(ctx, R.ImGui_StyleVar_WindowPadding(), 0, 0); nv = nv + 1 end
  return nc, nv
end

local function tip(text)
  if R.ImGui_SetItemTooltip then R.ImGui_SetItemTooltip(ctx, text)
  elseif R.ImGui_IsItemHovered(ctx) then R.ImGui_SetTooltip(ctx, text) end
end

local preset_name = ""
local custom_rgb = 0x39FF14

local function changed(flag) if flag then dirty = true end end

-- ---------------------------------------------------------------- UIKit-7-Look (ReaImGui-Portierung)
-- Die Widgets (panel2, knob2, hslider, toggle, btn, led, Leitbahn/Loetpunkt, Tooltips nach 0,35 s, Ziehen mit Shift = fein,
-- Rechts-/Doppel-/Strg-Klick = Standardwert, Mausrad) folgen _shared/tt-uikit.jsfx-inc (UKIT_VER 7). Gezeichnet wird im
-- Designraster ueber die DrawList; der Massstab folgt der Fenstergroesse (wie AUTO FIT der Plugins).
local floor = math.floor
local UK = { sc = 1, ox = 0, oy = 0, dl = nil, ar = 0.2235, ag = 1.0, ab = 0.0784, mxd = 0, myd = 0, shift = false, ctrl = false }
local DRAGS = {}
local HOVER = { id = nil, t = 0 }
local TIPS_ON = (R.GetExtState(NS, "tips") ~= "0")
-- Fenster-Skalierung des Adjusters: WIN_RESIZE = Faktor, der im naechsten Frame angewendet wird (gespeicherter Wert beim Start)
local WIN_RESIZE = tonumber(R.GetExtState(NS, "winscale"))
if WIN_RESIZE and (WIN_RESIZE < 0.9 or WIN_RESIZE > 2.1) then WIN_RESIZE = nil end
local WIN_DES = nil   -- { Designbreite, Designhoehe, Rand x, Rand y } aus dem letzten Frame
local KIT_ERR = nil
local TEST = { on = false, rects = {}, dump = nil, state = nil }

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

-- ---- Text (Inter, Pixelgroesse = Designgroesse * Massstab, ganzzahlig gerundet)
local TWC = {}
local function tw(s, size)
  size = size or 13
  local k = size .. "|" .. s
  local v = TWC[k]
  if not v then
    R.ImGui_PushFont(ctx, FONT_UI, size)
    v = R.ImGui_CalcTextSize(ctx, s)
    R.ImGui_PopFont(ctx)
    TWC[k] = v
  end
  return v
end
local function ptext(x, y, s, colr, size)
  size = size or 13
  local px = floor(size * UK.sc + 0.5)
  if px < 8 then px = 8 end
  R.ImGui_PushFont(ctx, FONT_UI, px)
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

-- ---- Primitive
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
-- Bogen im Designraster; Winkel in Grad, 0 = oben, im Uhrzeigersinn
local function arc(cx, cy, rad, a1, a2, colr, th)
  R.ImGui_DrawList_PathClear(UK.dl)
  R.ImGui_DrawList_PathArcTo(UK.dl, X(cx), Y(cy), Z(rad), math.rad(a1 - 90), math.rad(a2 - 90))
  R.ImGui_DrawList_PathStroke(UK.dl, colr, 0, Z(th))
end
-- senkrechter Verlauf, auch mit abgerundeten Ecken (Baender mit Clip-Rechteck)
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

-- ---- Eingabe
local function hit(id, x, y, w, h)
  R.ImGui_SetCursorScreenPos(ctx, X(x), Y(y))
  R.ImGui_InvisibleButton(ctx, id, Z(w), Z(h))
  if TEST.on then TEST.rects[id] = { X(x), Y(y), X(x + w), Y(y + h) } end
  return R.ImGui_IsItemHovered(ctx), R.ImGui_IsItemActive(ctx)
end
local function tipfor(id, s)
  if not TIPS_ON or not s then return end
  if R.ImGui_IsItemHovered(ctx) and not R.ImGui_IsMouseDown(ctx, 0) then
    local now = R.time_precise()
    if HOVER.id ~= id then HOVER.id = id; HOVER.t = now end
    if now - HOVER.t > 0.35 then R.ImGui_SetTooltip(ctx, s) end
  elseif HOVER.id == id then
    HOVER.id = nil
  end
end
-- Ziehen: ax "x" (Schieber, span = Breite) oder "y" (Knopf, span = 170 / fein 900); Shift fein, Rad 2 %, Reset per Rechts-/Doppel-/Strg-Klick
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

local function btn(id, x, y, w, h, label, on, prim, tiptxt)
  local hov, act = hit(id, x, y, w, h)
  local clicked = R.ImGui_IsItemActivated(ctx)
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

local function knob(id, cx, cy, r, val, mn, mx, def, tiptxt)
  local hov, act = hit(id, cx - r - 4, cy - r - 4, 2 * r + 8, 2 * r + 8)
  local nv = drag_ctl(id, hov, act, val, mn, mx, def, "y", 170, 900)
  local t = (nv - mn) / (mx - mn)
  local on = hov or act
  local rb = r - 6
  arc(cx, cy, r - 1.2, -135, 135, C(0.115, 0.130, 0.115), 2.4)
  if t > 0.004 then
    if on then arc(cx, cy, r - 1.8, -135, -135 + 270 * t, acid(0.20), 4.2) end
    arc(cx, cy, r - 1.2, -135, -135 + 270 * t, acid(1), 2.4)
  end
  circ(cx + 1.8, cy + 3.2, rb + 3.0, C(0, 0, 0, 0.26))
  circ(cx + 1.2, cy + 2.2, rb + 1.4, C(0, 0, 0, 0.30))
  for j = 0, 7 do
    local f = j / 7
    circ(cx - f * rb * 0.20, cy - f * rb * 0.26, rb * (1 - 0.80 * f), C(0.062 + 0.105 * f, 0.066 + 0.110 * f, 0.062 + 0.105 * f))
  end
  circ_line(cx, cy, rb, C(0, 0, 0, 0.75))
  arc(cx, cy, rb - 0.8, -125, -25, C(1, 1, 1, on and 0.40 or 0.28), 1.2)
  arc(cx, cy, rb - 0.8, 55, 155, C(0, 0, 0, 0.55), 1.2)
  local a = math.rad(-135 + 270 * t)
  local ax, ay = math.sin(a), -math.cos(a)
  line(cx + ax * rb * 0.28 + 0.7, cy + ay * rb * 0.28 + 0.9, cx + ax * rb * 0.88 + 0.7, cy + ay * rb * 0.88 + 0.9, C(0, 0, 0, 0.5), lw() * 2)
  line(cx + ax * rb * 0.28, cy + ay * rb * 0.28, cx + ax * rb * 0.88, cy + ay * rb * 0.88, C(1, 1, 1, 1), lw() * 2)
  tipfor(id, tiptxt)
  return nv
end

-- ---- Zwischenspeicher fuer abgeleitete Werte (ein Wechsel von S rechnet einmal neu)
local CACHE = { k = nil, ov = nil, rows = nil }
local function derived()
  local k = ser(S)
  if CACHE.k ~= k then CACHE.k = k; CACHE.ov = build_overrides(S); CACHE.rows = contrast_report(S) end
  return CACHE.ov, CACHE.rows
end

local function pct(v) return string.format("%d%%", floor(v * 100 + 0.5)) end

-- ---------------------------------------------------------------- SELECTION FRAME (js_ReaScriptAPI-Overlay)
-- Themes koennen keinen Selektionsrahmen zeichnen. Der Adjuster legt eine LICE-Bitmap per JS_Composite ueber das Arrange
-- und zeichnet um jedes selektierte Item einen Rahmen (Zustandsfarbe: Mute Amber, gesperrt Blau, gefroren Violett, sonst Akzent).
-- Historie: "HINWEIS: in REAPER nicht getestet." In REAPER belegt 19.10.2026 (Frische-Installation q1453: an, Bild, aus, Rueckkehr
-- zum Ausgangsbild, nach Neustart wieder aktiv, UNDO ALL aus). Das Overlay blockiert keine Klicks; mehr als SF.MAX selektierte Items -> nur die ersten SF.MAX.
-- Y-Annahme: I_LASTY ist relativ zur Spur (laut API-Doku), daher wird I_TCPY der Spur addiert.
-- Nicht erkennbar: "anderes Item inaktiv" (kein verlaesslicher API-Zugriff) - nur Spur-Freeze (I_FREEZECOUNT) faerbt Violett.
local SF = { bm = nil, hwnd = nil, w = 0, h = 0, sig = "", t = 0, MAX = 400 }
SF.have = function()
  return R.JS_Window_Find ~= nil and R.JS_Composite ~= nil and R.JS_LICE_CreateBitmap ~= nil and R.JS_LICE_FillRect ~= nil
    and R.JS_LICE_Clear ~= nil and R.JS_Window_GetClientSize ~= nil
end
SF.off = function()
  if SF.bm then
    if SF.hwnd and R.JS_Composite_Unlink then pcall(R.JS_Composite_Unlink, SF.hwnd, SF.bm, true) end
    if R.JS_LICE_DestroyBitmap then pcall(R.JS_LICE_DestroyBitmap, SF.bm) end
  end
  SF.bm, SF.hwnd, SF.w, SF.h, SF.sig = nil, nil, 0, 0, ""
end
SF.set = function(on)
  if on and not SF.have() then S.sel_frame = false; set_status("SELECTION FRAME needs js_ReaScriptAPI"); return end
  S.sel_frame = on; dirty = true
  if not on then SF.off() end
end
SF.rect = function(x0, y0, x1, y1, th, col)
  local w, h = SF.w, SF.h
  local function fill(x, y, ww, hh)
    local cx0, cy0, cx1, cy1 = math.max(0, x), math.max(0, y), math.min(w, x + ww), math.min(h, y + hh)
    if cx1 > cx0 and cy1 > cy0 then R.JS_LICE_FillRect(SF.bm, cx0, cy0, cx1 - cx0, cy1 - cy0, col, 1, "COPY") end
  end
  local ww, hh = x1 - x0, y1 - y0
  if y0 >= 0 then fill(x0, y0, ww, th) end
  if y1 <= h then fill(x0, y1 - th, ww, th) end
  if x0 >= 0 then fill(x0, y0, th, hh) end
  if x1 <= w then fill(x1 - th, y0, th, hh) end
end
SF.tick = function()
  if not S.sel_frame then if SF.bm then SF.off() end return end
  if not SF.have() then S.sel_frame = false; dirty = true; SF.off(); set_status("SELECTION FRAME needs js_ReaScriptAPI") return end
  local now = R.time_precise()
  if now - SF.t < 0.1 then return end
  SF.t = now
  local hwnd = R.JS_Window_FindChildByID and R.JS_Window_FindChildByID(R.GetMainHwnd(), 0x3E8) or nil
  if not hwnd then hwnd = R.JS_Window_Find("trackview", true) end
  if not hwnd then return end
  local a, b, c = R.JS_Window_GetClientSize(hwnd)
  local w, h
  if type(a) == "boolean" then w, h = b, c else w, h = a, b end
  w, h = tonumber(w) or 0, tonumber(h) or 0
  if w < 2 or h < 2 then return end
  local t0, t1 = R.GetSet_ArrangeView2(0, false, 0, 0)
  if not t0 or not t1 or t1 <= t0 then return end
  local pps = w / (t1 - t0)
  local ac = accent_of(S)
  local cols = { [0] = 0xFF000000 | (floor(ac[1] + 0.5) << 16) | (floor(ac[2] + 0.5) << 8) | floor(ac[3] + 0.5), 0xFFFFB35C, 0xFF4DA3FF, 0xFFB08CFF }
  local rects, sg = {}, { string.format("%d,%d,%.4f,%.4f,%x", w, h, t0, t1, cols[0]) }
  for i = 0, math.min(R.CountSelectedMediaItems(0), SF.MAX) - 1 do
    local it = R.GetSelectedMediaItem(0, i)
    local tr = it and R.GetMediaItemTrack(it)
    if tr and R.IsTrackVisible(tr, false) and R.GetMediaTrackInfo_Value(tr, "I_TCPH") > 0
        and R.GetMediaItemInfo_Value(it, "B_FIXEDLANE_HIDDEN") == 0 then
      local pos, len = R.GetMediaItemInfo_Value(it, "D_POSITION"), R.GetMediaItemInfo_Value(it, "D_LENGTH")
      local ly, lh = R.GetMediaItemInfo_Value(it, "I_LASTY"), R.GetMediaItemInfo_Value(it, "I_LASTH")
      local x0 = floor((pos - t0) * pps + 0.5)
      local x1 = floor((pos + len - t0) * pps + 0.5)
      local y0 = floor(R.GetMediaTrackInfo_Value(tr, "I_TCPY") + ly + 0.5)
      local y1 = y0 + floor(lh + 0.5)
      if lh > 0 and x1 >= 0 and x0 <= w and y1 >= 0 and y0 <= h then
        local mute = R.GetMediaItemInfo_Value(it, "B_MUTE") > 0.5 or R.GetMediaTrackInfo_Value(tr, "B_MUTE") > 0.5
        local lock = (floor(R.GetMediaItemInfo_Value(it, "C_LOCK")) & 1) ~= 0
        local frz = R.GetMediaTrackInfo_Value(tr, "I_FREEZECOUNT") > 0
        local kind = mute and 1 or (lock and 2 or (frz and 3 or 0))
        rects[#rects + 1] = { x0, y0, x1, y1, kind }
        sg[#sg + 1] = x0 .. "," .. y0 .. "," .. x1 .. "," .. y1 .. "," .. kind
      end
    end
  end
  local sig = table.concat(sg, ";")
  if sig == SF.sig and SF.bm and SF.hwnd == hwnd then return end
  if SF.bm and (SF.hwnd ~= hwnd or SF.w ~= w or SF.h ~= h) then SF.off() end
  if not SF.bm then
    SF.bm = R.JS_LICE_CreateBitmap(true, w, h)
    if not SF.bm then set_status("SELECTION FRAME: could not create bitmap") S.sel_frame = false; dirty = true return end
    SF.hwnd, SF.w, SF.h = hwnd, w, h
  end
  R.JS_LICE_Clear(SF.bm, 0)
  for _, r in ipairs(rects) do
    SF.rect(r[1], r[2], r[3], r[4], 2, cols[r[5]])
    if r[5] == 1 and (r[3] - r[1]) > 12 and (r[4] - r[2]) > 12 then SF.rect(r[1] + 4, r[2] + 4, r[3] - 4, r[4] - 4, 2, cols[1]) end
  end
  local rvc = R.JS_Composite(hwnd, 0, 0, w, h, SF.bm, 0, 0, w, h, true)
  if rvc ~= 1 then
    SF.off(); S.sel_frame = false; dirty = true
    set_status("Selection frame composite failed: " .. tostring(rvc)); return
  end
  if R.JS_Window_InvalidateRect then R.JS_Window_InvalidateRect(hwnd, 0, 0, w, h, false) end
  SF.sig = sig
end
R.atexit(function() pcall(SF.off) end)

-- ---------------------------------------------------------------- Logo-Wasserzeichen auf der Arrange-Buehne
-- Das Theme kennt kein Hintergrundbild fuer das Arrange. Wie beim Selektionsrahmen legt der Adjuster eine LICE-Bitmap
-- per JS_Composite ueber das Arrange (blockiert keine Klicks). Sie liegt UEBER den Items: darum niedrige Deckkraft.
-- Historie: "HINWEIS: in REAPER nicht getestet." In REAPER belegt 19.10.2026 (q1453, Logo neben dem Skript in Scripts/TimTechlor
-- gefunden, 8 % Deckkraft im Bild, aus = Ausgangsbild, nach Neustart wieder aktiv). Logo-Datei TT_Logo_T.png (liegt neben diesem Skript, oder unter Scripts/TimTechlor).
local WM = { bm = nil, hwnd = nil, sig = "", t = 0, src = nil, srcw = 0, srch = 0, path = nil }
WM.have = function()
  return R.JS_Window_Find ~= nil and R.JS_Composite ~= nil and R.JS_LICE_CreateBitmap ~= nil and R.JS_LICE_LoadPNG ~= nil
    and R.JS_LICE_ScaledBlit ~= nil and R.JS_LICE_Clear ~= nil and R.JS_Window_GetClientSize ~= nil
end
WM.find_path = function()
  if WM.path then return WM.path end
  local cands = {}
  -- Quelle dieses Chunks (TT_ThemeAdjuster.lua), auch wenn der Menue-Einstieg ihn per dofile laedt.
  local src = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  local sdir = src:match("^(.*[/\\])")
  if sdir and sdir ~= "" then cands[#cands + 1] = sdir .. "TT_Logo_T.png" end
  local okc, _, fname = pcall(R.get_action_context)
  if okc and type(fname) == "string" and fname ~= "" then cands[#cands + 1] = (fname:match("^(.*)[/\\]") or ".") .. "/TT_Logo_T.png" end
  cands[#cands + 1] = R.GetResourcePath() .. "/Scripts/TimTechlor/TT_Logo_T.png"
  for _, p in ipairs(cands) do
    local f = io.open(p, "rb")
    if f then f:close(); WM.path = p; return p end
  end
  return nil
end
WM.off = function()
  if WM.bm then
    if WM.hwnd and R.JS_Composite_Unlink then pcall(R.JS_Composite_Unlink, WM.hwnd, WM.bm, true) end
    if R.JS_LICE_DestroyBitmap then pcall(R.JS_LICE_DestroyBitmap, WM.bm) end
  end
  WM.bm, WM.hwnd, WM.sig = nil, nil, ""
end
WM.unload = function()
  WM.off()
  if WM.src and R.JS_LICE_DestroyBitmap then pcall(R.JS_LICE_DestroyBitmap, WM.src) end
  WM.src = nil
end
WM.set = function(on)
  if on and not WM.have() then S.wm_on = false; set_status("LOGO WATERMARK needs js_ReaScriptAPI"); return end
  if on and not WM.find_path() then S.wm_on = false; set_status("LOGO WATERMARK: TT_Logo_T.png not found next to the script"); return end
  S.wm_on = on; dirty = true
  if not on then WM.off() end
end
WM.tick = function()
  if not S.wm_on then if WM.bm then WM.off() end return end
  if not WM.have() then S.wm_on = false; dirty = true; WM.off(); set_status("LOGO WATERMARK needs js_ReaScriptAPI") return end
  local now = R.time_precise()
  if now - WM.t < 0.25 then return end
  WM.t = now
  local hwnd = R.JS_Window_FindChildByID and R.JS_Window_FindChildByID(R.GetMainHwnd(), 0x3E8) or nil
  if not hwnd then hwnd = R.JS_Window_Find("trackview", true) end
  if not hwnd then return end
  local a, b, c = R.JS_Window_GetClientSize(hwnd)
  local w, h
  if type(a) == "boolean" then w, h = b, c else w, h = a, b end
  w, h = tonumber(w) or 0, tonumber(h) or 0
  if w < 40 or h < 40 then return end
  local ar = 1000.05 / 866.12
  local dh = math.max(24, floor(h * math.max(0.1, math.min(1.0, S.wm_size)) + 0.5))
  local dw = floor(dh * ar + 0.5)
  if dw > w - 8 then dw = w - 8; dh = floor(dw / ar + 0.5) end
  local alpha = math.max(0.01, math.min(0.6, S.wm_op))
  local x0 = S.wm_corner and (w - dw - 24) or floor((w - dw) / 2)
  local y0 = S.wm_corner and (h - dh - 24) or floor((h - dh) / 2)
  if x0 < 0 then x0 = 0 end
  if y0 < 0 then y0 = 0 end
  local sig = string.format("%d,%d,%d,%d,%d,%d,%.3f", w, h, dw, dh, x0, y0, alpha)
  if sig == WM.sig and WM.bm and WM.hwnd == hwnd then return end
  if not WM.src then
    WM.src = R.JS_LICE_LoadPNG(WM.find_path())
    if not WM.src then set_status("LOGO WATERMARK: could not load TT_Logo_T.png"); S.wm_on = false; dirty = true; return end
    WM.srcw, WM.srch = R.JS_LICE_GetWidth(WM.src), R.JS_LICE_GetHeight(WM.src)
  end
  WM.off()
  WM.bm = R.JS_LICE_CreateBitmap(true, dw, dh)
  if not WM.bm then set_status("LOGO WATERMARK: could not create bitmap"); S.wm_on = false; dirty = true; return end
  R.JS_LICE_Clear(WM.bm, 0)
  R.JS_LICE_ScaledBlit(WM.bm, 0, 0, dw, dh, WM.src, 0, 0, WM.srcw, WM.srch, alpha, "ALPHA")
  local rv = R.JS_Composite(hwnd, x0, y0, dw, dh, WM.bm, 0, 0, dw, dh, true)
  if rv ~= 1 and rv ~= true then
    WM.off(); S.wm_on = false; dirty = true; set_status("LOGO WATERMARK: composite refused (code " .. tostring(rv) .. ")"); return
  end
  WM.hwnd, WM.sig = hwnd, sig
end
R.atexit(function() pcall(WM.unload) end)

-- Startup-Aktion: Fenster bleibt zu, angeschaltete Overlays laufen weiter.
if APPLY_ONLY then
  local function overlay_loop()
    local oks, errs = pcall(SF.tick)
    if not oks then
      S.sel_frame = false
      pcall(SF.off)
      R.ShowConsoleMsg("TT Theme Adjuster (apply): selection frame: " .. tostring(errs) .. "\n")
    end
    local okw, errw = pcall(WM.tick)
    if not okw then
      S.wm_on = false
      pcall(WM.off)
      R.ShowConsoleMsg("TT Theme Adjuster (apply): watermark: " .. tostring(errw) .. "\n")
    end
    if S.sel_frame or S.wm_on then R.defer(overlay_loop)
    else pcall(SF.off); pcall(WM.unload) end
  end
  R.defer(overlay_loop)
  return
end

-- ---------------------------------------------------------------- TRACK COLOURS (Palette aus den Akzentschemata)
-- Alle Schemata + 2 Neutrale. TC.color(i, int) skaliert Saettigung/Helligkeit mit der Intensitaet und dunkelt so weit
-- ab, dass heller Text (TC.TEXT) darauf mindestens 4,5 : 1 hat.
local TC = { TEXT = { 235, 240, 235 }, NEUTRAL = { { "GRAPHITE", "#7A828C" }, { "FROST", "#B7CCDC" } }, cache = { int = nil, cols = {} } }
TC.COUNT = #SCHEMES + #TC.NEUTRAL
TC.hsv = function(c)
  local r, g, b = c[1] / 255, c[2] / 255, c[3] / 255
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local d, h = mx - mn, 0
  if d > 0 then
    if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
    h = h / 6
  end
  return h, (mx > 0) and d / mx or 0, mx
end
TC.rgb = function(h, s, v)
  local f6 = h * 6
  local i, f = floor(f6) % 6, f6 - floor(f6)
  local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
  local r, g, b
  if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
  return { r * 255, g * 255, b * 255 }
end
TC.name = function(i) if i <= #SCHEMES then return SCHEMES[i][1] end return TC.NEUTRAL[i - #SCHEMES][1] end
TC.color = function(i, int)
  if TC.cache.int ~= int then TC.cache = { int = int, cols = {} } end
  local hit_c = TC.cache.cols[i]
  if hit_c then return hit_c end
  local hx = (i <= #SCHEMES) and SCHEMES[i][2] or TC.NEUTRAL[i - #SCHEMES][2]
  local h, s, v = TC.hsv(hex2rgb(hx))
  -- Die Spurfläche mischt die Farbe nur schwach ein. Eine enge Sättigung
  -- hat Rainbow im Screenshot und live auf ein einziges Graugrün gezogen.
  if s < 0.25 then s = clamp(0.45 * int, 0.15, 0.6) else s = clamp(0.82 * int, 0.4, 1) end
  v = clamp(0.5 + 0.22 * int, 0.45, 0.92)
  local c = TC.rgb(h, s, v)
  c = { floor(c[1] + 0.5), floor(c[2] + 0.5), floor(c[3] + 0.5) }
  TC.cache.cols[i] = c
  return c
end
TC.sel = function()
  local t = {}
  for i = 0, R.CountSelectedTracks(0) - 1 do t[#t + 1] = R.GetSelectedTrack(0, i) end
  return t
end
TC.set = function(tr, c)
  R.SetTrackColor(tr, R.ColorToNative(floor(c[1] + 0.5), floor(c[2] + 0.5), floor(c[3] + 0.5)) | 0x1000000)
end
-- fn(sel) gibt den Statustext zurueck; needsel: ohne selektierte Spur nur Statusmeldung
TC.run = function(needsel, fn)
  local sel = TC.sel()
  if needsel and #sel == 0 then set_status("Select tracks first") return end
  R.Undo_BeginBlock()
  R.PreventUIRefresh(1)
  local ok, res = pcall(fn, sel)
  R.PreventUIRefresh(-1)
  R.Undo_EndBlock("TT: colour tracks", -1)
  R.TrackList_AdjustWindows(false)
  R.UpdateArrange()
  set_status(ok and res or ("Track colours failed: " .. tostring(res)))
end
TC.act = {
  pick = function(sel)
    local c = TC.color(floor(S.tc_pick) + 1, S.tc_int)
    for _, tr in ipairs(sel) do TC.set(tr, c) end
    return ("Coloured %d track(s) %s"):format(#sel, TC.name(floor(S.tc_pick) + 1))
  end,
  rainbow = function()
    local n, k, cur = R.CountTracks(0), 0, {}
    for i = 0, n - 1 do
      local tr = R.GetTrack(0, i)
      local d = R.GetTrackDepth(tr)
      local c
      if d <= 0 then c = TC.color(k % TC.COUNT + 1, S.tc_int); k = k + 1
      else c = scale(cur[d - 1] or TC.color(1, S.tc_int), 0.85) end
      cur[d] = c
      TC.set(tr, c)
    end
    return ("Rainbow: %d track(s) coloured"):format(n)
  end,
  ramp = function(sel)
    local a = accent_of(S)
    local _, sat = TC.hsv(a)
    if sat < 0.25 then a = { 57, 255, 20 } end -- weisser/grauer Akzent gaebe nur Grau: Acid Green
    -- Hellende nicht auf Textkontrast 4.5 druecken: das hat die helle Seite
    -- dunkler gemacht als die dunkle, die Stufen waren ein einziges Gruen.
    -- Die Flaeche zeigt die Farbe nur als Auflage, der Text bleibt lesbar.
    local dk, lt = scale(a, 0.08), mix(a, { 255, 255, 255 }, 0.28)
    local n = #sel
    for i, tr in ipairs(sel) do
      local t = (n > 1) and ((i - 1) / (n - 1)) or 0.75
      t = t ^ 0.4
      TC.set(tr, mix(dk, lt, t))
    end
    return ("Accent ramp on %d track(s)"):format(n)
  end,
  clear = function(sel)
    for _, tr in ipairs(sel) do
      if R.SetMediaTrackInfo_Value then R.SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", 0)
      else R.SetTrackColor(tr, 0) end
    end
    return ("Cleared colour on %d track(s)"):format(#sel)
  end,
}

-- Zeile: Beschriftung links, Schieber, Wert rechts
local function srow(key, label, y, ix, iw, mn, mx, tiptxt)
  ptext(ix, y + 4, label, C(INK[1], INK[2], INK[3], 0.92))
  local sx, sw = ix + 140, iw - 140 - 50
  local nv = hslider("s_" .. key, sx, y, sw, 22, S[key], mn, mx, DEFAULTS[key], tiptxt)
  if nv ~= S[key] then S[key] = nv; dirty = true end
  ptext_r(ix + iw, y + 4, pct(S[key]), acid(1))
end

-- ---- Panels (Hoehen sind Funktionen der Breite und der Zahl der Benutzer-Presets)
local COLW, MARG, GAP, HEAD, FOOT, FOOT1 = 440, 14, 14, 56, 46, 64

local function user_chips(iw)
  local out, x, y = {}, 0, 0
  for i, up in ipairs(USER_PRESETS) do
    local bw = math.max(56, tw(up[1], 13) + 18)
    local cw = bw + 22
    if x > 0 and x + cw > iw then x = 0; y = y + 28 end
    out[#out + 1] = { i = i, x = x, y = y, bw = bw }
    x = x + cw + 8
  end
  return out, (#out > 0) and (y + 28) or 0
end

local function h_presets(w) local _, uh = user_chips(w - 24); return 30 + 60 + 8 + (uh > 0 and uh + 6 or 0) + 26 + 12 end
local H_BG, H_PRV, H_ACC, H_TXT, H_CON, H_ACT, H_ACT2 = 160, 282, 126, 330, 196, 102, 66
local H_FNT, H_TRK = 360, 190

local function same_preset(pr)
  for k, v in pairs(pr) do if math.abs((S[k] or 0) - v) > 0.004 then return false end end
  return true
end

local function p_presets(x, y, w, h)
  panel(x, y, w, h, "PRESETS")
  local ix, iw, cy = x + 12, w - 24, y + 30
  local bw = (iw - 8) / 2
  for i, pr in ipairs(PRESETS_BUILTIN) do
    local cx, ry = ix + ((i - 1) % 2) * (bw + 8), cy + floor((i - 1) / 2) * 34
    if btn("pb" .. i, cx, ry, bw, 26, pr[1], same_preset(pr[2]), false,
        "Load " .. pr[1] .. ": sets background lift, tint, steps, grid and text brightness.") then
      for k, v in pairs(pr[2]) do S[k] = v end
      dirty = true
    end
  end
  cy = cy + 68
  local chips, uh = user_chips(iw)
  for _, c in ipairs(chips) do
    local up = USER_PRESETS[c.i]
    if up then
      if btn("up" .. c.i, ix + c.x, cy + c.y, c.bw, 24, up[1], false, false, "Load your preset " .. up[1] .. ".") then
        S = deser(up[2], S); dirty = true
        if S.accent_hex ~= "" then custom_rgb = tonumber(S.accent_hex:sub(2), 16) or custom_rgb end
      end
      if btn("ud" .. c.i, ix + c.x + c.bw + 2, cy + c.y, 20, 24, "X", false, false, "Delete the preset " .. up[1] .. ".") then
        table.remove(USER_PRESETS, c.i); if save_presets() then set_status("Preset deleted") end; break
      end
    end
  end
  if uh > 0 then cy = cy + uh + 6 end
  -- Name + SAVE
  R.ImGui_SetCursorScreenPos(ctx, X(ix), Y(cy))
  R.ImGui_SetNextItemWidth(ctx, Z(iw - 108))
  local fs = R.ImGui_GetFontSize(ctx)
  R.ImGui_PushStyleVar(ctx, R.ImGui_StyleVar_FramePadding(), Z(8), math.max(0, (Z(26) - fs) / 2))
  local rv, nm = R.ImGui_InputText(ctx, "##pname", preset_name)
  R.ImGui_PopStyleVar(ctx, 1)
  if rv then preset_name = nm end
  if preset_name == "" then ptext(ix + 10, cy + 5, "preset name", C(0.45, 0.48, 0.45, 0.8)) end
  tipfor("pname", "Name for a new preset (type, then SAVE).")
  if btn("psave", ix + iw - 100, cy, 100, 26, "SAVE PRESET", false, true, "Store all current values as a named preset (tt_themeadjuster_presets.txt in the resource folder).") and preset_name ~= "" then
    local nmv = preset_name:gsub("[\t\r\n]", " ")
    local done = false
    for _, up in ipairs(USER_PRESETS) do if up[1] == nmv then up[2] = ser(S); done = true end end
    if not done then USER_PRESETS[#USER_PRESETS + 1] = { nmv, ser(S) } end
    if save_presets() then set_status("Preset saved: " .. nmv) end
  end
end

local function p_background(x, y, w, h)
  panel(x, y, w, h, "BACKGROUND")
  local ix, iw, cy = x + 12, w - 24, y + 30
  srow("lift", "BG LIFT", cy + 4, ix, iw, 0, 1, "Raises the whole background from black (0) to slate grey (100). Right-click or double-click resets, Shift = fine.")
  cy = cy + 40
  local cw = iw / 3
  local knobs = { { "tint", "TINT", 0, 1, "How much of the accent colour tints the grey surfaces (0 = neutral grey)." },
    { "step", "PANEL STEPS", 0.5, 2.5, "Distance between surface levels: arrange, track panel, borders, hover." },
    { "grid", "GRID", 0, 3, "Contrast of grid lines and dividers in arrange and MIDI editor." } }
  for i, k in ipairs(knobs) do
    local kx = ix + (i - 0.5) * cw
    local nv = knob("k_" .. k[1], kx, cy + 26, 22, S[k[1]], k[3], k[4], DEFAULTS[k[1]], k[5] .. " Drag up/down, Shift = fine, double-click resets.")
    if nv ~= S[k[1]] then S[k[1]] = nv; dirty = true end
    ptext_c(kx, cy + 56, k[2], C(INK[1], INK[2], INK[3], 0.92))
    ptext_c(kx, cy + 71, pct(S[k[1]]), acid(1), 12)
  end
end

-- Vorschau: Arrange (Audio, MIDI) und MIDI-Editor mit den aktuellen Farben; Item-Koerper wie im Theme (col_mi_bg / col_mi_bg2)
local function rgbc(c, a, k) k = k or 1; return C(c[1] / 255 * k, c[2] / 255 * k, c[3] / 255 * k, a) end
local function hexc(hx, a, wk)
  local n = tonumber(hx:sub(2), 16) or 0
  local r, g, b = ((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255
  if wk then r, g, b = r + (1 - r) * wk, g + (1 - g) * wk, b + (1 - b) * wk end
  return C(r, g, b, a)
end
UK.chip = function(cx, cy, sz, colr, sel, hov)
  local x0, y0 = cx - sz / 2, cy - sz / 2
  rfill(x0, y0, sz, sz, colr)
  if sel then
    rline(x0 - 2, y0 - 2, sz + 4, sz + 4, acid(1), 0)
    rline(x0 - 1, y0 - 1, sz + 2, sz + 2, acid(1), 0)
  else
    rline(x0, y0, sz, sz, hov and C(1, 1, 1, 0.6) or C(0, 0, 0, 0.6), 0)
  end
end
local function p_preview(x, y, w, h)
  panel(x, y, w, h, "LIVE PREVIEW")
  local ix, iw, cy = x + 12, w - 24, y + 30
  local ov = derived()
  local hw = 78
  local function lane(ly, lh, bg, name, ink_c)
    rfill(ix, ly, iw, lh, rgbc(bg, 1))
    rfill(ix, ly, hw, lh, rgbc(ov["col_tracklistbg"], 1))
    rfill(ix + hw - 1, ly, 1, lh, C(0, 0, 0, 0.4))
    rfill(ix, ly + lh - 1, iw, 1, C(0, 0, 0, 0.35))
    ptext(ix + 6, ly + (lh - 11) / 2 - 1, name, rgbc(ink_c or ov["col_tcp_text"], 1), 11)
  end
  local function frame_sel(fx, fy, fw, fh) rline(fx, fy, fw, fh, acid(1), 0) end
  local la, lb = 38, 38
  -- Audio
  lane(cy, la, ov["col_tr1_bg"], "AUDIO")
  local ix2 = ix + hw
  local iy = cy + 4
  local iwd = (iw - hw - 40) / 2
  rfill(ix2 + 12, iy, iwd, la - 8, rgbc(ov["col_mi_bg"], 1))
  rline(ix2 + 12, iy, iwd, la - 8, C(0, 0, 0, 0.55), 0)
  rfill(ix2 + 28 + iwd, iy, iwd, la - 8, rgbc(ov["col_mi_bg2"], 1))
  frame_sel(ix2 + 28 + iwd, iy, iwd, la - 8)
  local pk = rgbc(ov["col_tr1_peaks"], 0.9)
  for i = 0, floor(iwd / 2) - 3 do
    local a = math.abs(math.sin(i * 0.9) * math.cos(i * 0.31)) * (la - 14) * 0.5 + 1
    rfill(ix2 + 16 + i * 2, iy + (la - 8) / 2 - a, 1, a * 2, pk)
    rfill(ix2 + 32 + iwd + i * 2, iy + (la - 8) / 2 - a, 1, a * 2, pk)
  end
  -- MIDI-Item im Arrange
  local my0 = cy + la
  lane(my0, lb, ov["col_tr2_bg"], "SYNTH")
  local function midi_item(mx0, sel)
    rfill(mx0, my0 + 4, iwd, lb - 8, rgbc(sel and ov["col_mi_bg2"] or ov["col_mi_bg"], 1))
    if sel then frame_sel(mx0, my0 + 4, iwd, lb - 8) else rline(mx0, my0 + 4, iwd, lb - 8, C(0, 0, 0, 0.55), 0) end
    for i = 0, floor(iwd / 11) - 1 do
      local nx = mx0 + 6 + i * 11
      rfill(nx, my0 + 7 + ((i * 7) % 5) * 3, 8, 2.5, C(0.05, 0.06, 0.05, 1))
    end
  end
  midi_item(ix2 + 12, false)
  midi_item(ix2 + 28 + iwd, true)
  -- Spur mit gemutetem und selektiertem Item (Akzentrahmen 2 px)
  local mu0 = my0 + lb
  lane(mu0, lb, ov["col_tr1_bg"], "MUTED")
  local mc = S.mute_amber and C(AMBER[1], AMBER[2], AMBER[3], 0.9) or C(1, 0.4, 0.44, 0.9)
  rfill(ix2 + 12, mu0 + 4, iwd, lb - 8, rgbc(ov["col_mi_bg"], 0.45))
  rline(ix2 + 12, mu0 + 4, iwd, lb - 8, mc, 0)
  ptext(ix2 + 18, mu0 + 4 + (lb - 8) / 2 - 6, "muted", mc, 10)
  rfill(ix2 + 28 + iwd, mu0 + 4, iwd, lb - 8, rgbc(ov["col_mi_bg2"], 1))
  frame_sel(ix2 + 28 + iwd, mu0 + 4, iwd, lb - 8)
  rline(ix2 + 29 + iwd, mu0 + 5, iwd - 2, lb - 10, acid(1), 0)
  ptext(ix2 + 34 + iwd, mu0 + 4 + (lb - 8) / 2 - 6, "selected", C(1, 1, 1, 0.8), 10)
  -- MIDI-Editor: gleiche Kopfspalte wie die Spuren, Notenfeld buendig mit den Items; Kanalfarben, selektiert (heller + weisser Rand), stumm (Amber)
  local ey = mu0 + lb + 4
  local eh = 56
  local ex, ew = ix + hw, iw - hw
  rfill(ix, ey, hw, eh, rgbc(ov["col_tracklistbg"], 1))
  rfill(ix + hw - 1, ey, 1, eh, C(0, 0, 0, 0.4))
  ptext(ix + 6, ey + (eh - 11) / 2 - 1, "MIDI EDITOR", rgbc(ov["col_tcp_text"], 1), 10)
  rfill(ex, ey, ew, eh, rgbc(ov["midi_trackbg1"], 1))
  for r = 0, 3 do if r % 2 == 1 then rfill(ex, ey + r * 14, ew, 14, rgbc(ov["midi_trackbg2"], 1)) end end
  local ga = C(1, 1, 1, math.min(0.5, 0.05 * S.grid))
  for g = 0, floor(ew / 16) do rfill(ex + g * 16, ey, 1, eh, ga) end
  for r = 1, 3 do rfill(ex, ey + r * 14, ew, 1, ga) end
  local notes = { { 6, 1, 26, 1 }, { 38, 2, 20, 2 }, { 62, 0, 34, 3 }, { 104, 3, 24, 4 }, { 134, 1, 20, 5 }, { 162, 2, 32, 7 }, { 202, 0, 22, 8 },
    { 230, 3, 28, 9 }, { 264, 1, 20, 11 }, { 290, 2, 34, 12 } }
  for i, nt in ipairs(notes) do
    local nx, nr, nw, ch = ex + nt[1] * (ew / 330), nt[2], nt[3] * (ew / 330), nt[4]
    local hx = NOTE_CHANNELS[ch] or "#39FF14"
    local muted = (i == 5)
    local sel = (i >= 7 and i <= 9)
    local col2
    if muted then col2 = S.mute_amber and C(AMBER[1], AMBER[2], AMBER[3], 1) or hexc("#FF6670", 1)
    elseif sel then col2 = hexc(hx, 1, 0.58)
    else col2 = hexc(hx, 1) end
    rfill(nx, ey + nr * 14 + 1, nw, 12, col2)
    if sel then rline(nx, ey + nr * 14 + 1, nw, 12, C(1, 1, 1, 0.95), 0) end
  end
  rline(ex, ey, ew, eh, C(0, 0, 0, 0.5), 0)
  -- Legende unter dem Notenfeld (ueberdeckt keine Noten)
  local ly = ey + eh + 6
  local lx = ex
  local function legend(txt, col, framed)
    rfill(lx, ly + 1, 12, 8, col)
    if framed then rline(lx, ly + 1, 12, 8, C(1, 1, 1, 0.95), 0) end
    ptext(lx + 16, ly - 1, txt, C(INK[1], INK[2], INK[3], 0.75), 10)
    lx = lx + 16 + tw(txt, 10) + 14
  end
  legend("selected", hexc(NOTE_CHANNELS[8] or "#39FF14", 1, 0.58), true)
  legend("muted", S.mute_amber and C(AMBER[1], AMBER[2], AMBER[3], 1) or hexc("#FF6670", 1), false)
  legend("channel colours", hexc(NOTE_CHANNELS[3] or "#39FF14", 1), false)
  local sy = ly + 18
  rfill(ix, sy, iw, 1, C(0, 0, 0, 0.35))
  sy = sy + 6
  ptext(ix + 6, sy + 8, "COLOURS", rgbc(ov["col_tcp_text"], 1), 10)
  for k = 0, 2 do
    local ci = (floor(S.tc_pick) + k) % TC.COUNT + 1
    local c = TC.color(ci, S.tc_int)
    UK.chip(ex + 17 + k * 40, sy + 14, 32, C(c[1] / 255, c[2] / 255, c[3] / 255), k == 0, false)
  end
  hit("prv", ix, cy, iw, la + lb + lb + 4 + eh + 8 + 40)
  tipfor("prv", "Live preview with the current values: audio and MIDI items (unselected, selected, muted) in the arrange, notes in the MIDI editor (channel colours, selected = lighter with white frame, muted = amber) and three track colours in the current style.")
end

local function p_accent(x, y, w, h)
  panel(x, y, w, h, "ACCENT")
  local ix, iw, cy = x + 12, w - 24, y + 30
  local cw = iw / #SCHEMES
  for i, sch in ipairs(SCHEMES) do
    local cx = ix + (i - 0.5) * cw
    local n = tonumber(sch[2]:sub(2), 16) or 0
    local sel = (S.accent_hex == "" and S.scheme == i - 1)
    local hov = hit("sc" .. i, cx - 14, cy - 2, 28, 28)
    if R.ImGui_IsItemActivated(ctx) then
      S.scheme = i - 1; S.accent_hex = ""; custom_rgb = n; dirty = true
    end
    local rr, gg, bb = ((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255
    UK.chip(cx, cy + 12, 24, C(rr, gg, bb), sel, hov)
    tipfor("sc" .. i, "Accent scheme " .. sch[1] .. (i == 1 and " (brand default)" or ""))
  end
  cy = cy + 36
  local nm = (S.accent_hex ~= "") and ("CUSTOM " .. S.accent_hex) or SCHEMES[S.scheme + 1][1]
  ptext_c(x + w / 2, cy, nm, acid(1))
  cy = cy + 26
  ptext(ix, cy + 3, "CUSTOM COLOUR", C(INK[1], INK[2], INK[3], 0.92))
  R.ImGui_SetCursorScreenPos(ctx, X(ix + 128), Y(cy))
  local flags = R.ImGui_ColorEditFlags_NoInputs() | R.ImGui_ColorEditFlags_NoLabel()
  local rve, ncol = R.ImGui_ColorEdit3(ctx, "##custom", custom_rgb, flags)
  if rve then
    custom_rgb = ncol
    S.accent_hex = string.format("#%06X", ncol & 0xFFFFFF)
    dirty = true
  end
  tipfor("custom", "Free accent colour (overrides the scheme accent). Pick a scheme chip to go back.")
  ptext(ix + 128 + 34, cy + 3, string.format("#%06X", custom_rgb & 0xFFFFFF), C(0.55, 0.60, 0.55))
end

local WM_TIP = "Lays the T logo (TT_Logo_T.png) at low opacity over the arrange stage via js_ReaScriptAPI while the adjuster is open. It sits above items, so keep the opacity low. Off by default."
local SEL_TIP = "Frames selected items (amber = muted, blue = locked, violet = frozen track) via js_ReaScriptAPI while the adjuster is open; frames up to the first 400 selected items. Off by default."
local function p_text(x, y, w, h)
  panel(x, y, w, h, "TEXT AND ITEMS")
  local ix, iw, cy = x + 12, w - 24, y + 32
  srow("text", "TEXT", cy, ix, iw, 0, 1, "Text brightness: 0 = brand ink, 100 = white.")
  srow("item_unsel", "ITEM UNSELECTED", cy + 32, ix, iw, 0.5, 1.5, "Brightness of the default item body (items without a track colour).")
  srow("item_sel", "ITEM SELECTED", cy + 64, ix, iw, 0.5, 1.5, "Brightness of the selected item body.")
  if toggle("t_amber", ix, cy + 100, iw, 26, S.mute_amber, "MUTED NOTES AMBER", "Muted MIDI notes use amber (on) instead of red (off).") then
    S.mute_amber = not S.mute_amber; dirty = true
  end
  if toggle("t_selframe", ix, cy + 132, iw, 26, S.sel_frame, "SELECTION FRAME", SEL_TIP) then SF.set(not S.sel_frame) end
  if toggle("t_wm", ix, cy + 164, iw, 26, S.wm_on, "LOGO WATERMARK", WM_TIP) then WM.set(not S.wm_on) end
  srow("wm_op", "LOGO OPACITY", cy + 196, ix, iw, 0.02, 0.4, "Opacity of the logo watermark on the arrange stage (2 to 40 percent).")
  srow("wm_size", "LOGO SIZE", cy + 228, ix, iw, 0.2, 1.0, "Logo height as a share of the arrange height.")
  if toggle("t_wmc", ix, cy + 262, iw, 26, S.wm_corner, "LOGO IN CORNER", "Off = centred, on = bottom right corner of the arrange.") then
    S.wm_corner = not S.wm_corner; dirty = true
  end
end

local function p_trk(x, y, w, h)
  panel(x, y, w, h, "TRACK COLOURS")
  local ix, iw, cy = x + 12, w - 24, y + 30
  local cw = iw / TC.COUNT
  for i = 1, TC.COUNT do
    local cx = ix + (i - 0.5) * cw
    local c = TC.color(i, S.tc_int)
    local rr, gg, bb = c[1] / 255, c[2] / 255, c[3] / 255
    local sel = (floor(S.tc_pick) == i - 1)
    local hov = hit("tcp" .. i, cx - 14, cy - 2, 28, 28)
    if R.ImGui_IsItemActivated(ctx) then S.tc_pick = i - 1; dirty = true end
    UK.chip(cx, cy + 12, math.min(22, cw - 3), C(rr, gg, bb), sel, hov)
    tipfor("tcp" .. i, "Track colour " .. TC.name(i) .. " (click to pick it for COLOUR SELECTED).")
  end
  cy = cy + 32
  ptext_c(x + w / 2, cy, TC.name(floor(S.tc_pick) + 1), acid(1))
  cy = cy + 24
  srow("tc_int", "INTENSITY", cy, ix, iw, 0.2, 2.0, "Track colour intensity: scales saturation and brightness of the palette; light text stays readable.")
  cy = cy + 34
  local bw = (iw - 8) / 2
  if btn("tc_sel", ix, cy, bw, 26, "COLOUR SELECTED", false, true, "Paint the picked palette colour onto all selected tracks.") then TC.run(true, TC.act.pick) end
  if btn("tc_rbw", ix + bw + 8, cy, bw, 26, "RAINBOW ALL", false, false, "Colour all top-level tracks through the palette; folder children get a darker shade of their folder.") then TC.run(false, TC.act.rainbow) end
  cy = cy + 34
  if btn("tc_ramp", ix, cy, bw, 26, "ACID RAMP", false, false, "Colour the selected tracks in a gradient from dark to light accent; with a grey or near-grey accent it falls back to Acid Green, since grey alone gives no gradient.") then TC.run(true, TC.act.ramp) end
  if btn("tc_clr", ix + bw + 8, cy, bw, 26, "CLEAR SELECTED", false, false, "Reset the colour of the selected tracks to the theme default.") then TC.run(true, TC.act.clear) end
end

-- Gruppen und Zuordnung: siehe font_group (user_font n % 5: 0 = VALUES, 1/2 = MASTER, 3/4 = NAMES; trans_font, mi_font, tl_font; Rest = GENERAL)
local FS_ROWS = {
  { "fs_names", "TRACK NAMES", "Size of track and mixer channel names (the largest panel text)." },
  { "fs_values", "TRACK VALUES", "Size of volume, pan, width, input, FX list, send list and FX parameter text in the track panel and mixer." },
  { "fs_master", "MASTER / ENV", "Size of master track names, track numbers, envelope labels, time signature and the transport rate text." },
  { "fs_trans", "TRANSPORT", "Size of the big transport time display." },
  { "fs_items", "ITEM LABELS", "Size of item and take names in the arrange view." },
  { "fs_ruler", "RULER", "Size of the timeline ruler numbers." },
  { "fs_general", "GENERAL", "Size of all remaining theme fonts (legacy track/mixer fonts and spare slots)." },
}

local function pc_fmt(v) return string.format("%d%%", floor(v * 100 + 0.5)) end

local function p_fonts(x, y, w, h)
  panel(x, y, w, h, "FONT SIZES AND UI SCALE")
  local ix, iw, cy = x + 12, w - 24, y + 32
  for i, r in ipairs(FS_ROWS) do
    srow(r[1], r[2], cy + (i - 1) * 32, ix, iw, FS_MIN, FS_MAX, r[3] .. " 100% = theme size; applied by reloading the theme.")
  end
  cy = cy + #FS_ROWS * 32 + 6
  local pend = fonts_dirty or (fs_sig(S) ~= fonts_applied)
  if btn("f_apply", ix, cy, iw, 26, pend and "APPLY FONTS (PENDING)" or "APPLY FONTS", false, true,
      "Write the font sizes into 'Clean & Flat Acid (Adjusted)' and reload the theme (also happens 1.2 s after your last change).") then
    fonts_force = true
  end
  cy = cy + 40
  ptext(ix, cy + 5, "UI SCALE", C(INK[1], INK[2], INK[3], 0.92))
  local bx0 = ix + 92
  local bw = (iw - 92 - 3 * 6) / 4
  for i, v in ipairs(UI_STEPS) do
    if btn("u_" .. i, bx0 + (i - 1) * (bw + 6), cy, bw, 26, pc_fmt(v), math.abs(UI_SCALE - v) < 0.01, false,
        "Set the REAPER UI scale to " .. pc_fmt(v) .. " (needs SWS; a REAPER restart may be needed).") then
      local ok, e = pcall(set_uiscale, v)
      if not ok then set_status("UI scale failed: " .. tostring(e)) end
    end
  end
  ptext(ix, cy + 34, "REAPER UI scale now: " .. pc_fmt(UI_SCALE), C(0.45, 0.48, 0.45), 11)
end

local function p_contrast(x, y, w, h)
  panel(x, y, w, h, "CONTRAST CHECK")
  local ix, iw, cy = x + 12, w - 24, y + 32
  local _, rows = derived()
  for i, r in ipairs(rows) do
    local ry = cy + (i - 1) * 26
    local ok = r.c >= r.need
    local colr = ok and { UK.ar, UK.ag, UK.ab } or AMBER
    led(ix + 6, ry + 9, 3.2, true, colr)
    ptext(ix + 18, ry + 2, r.name, C(INK[1], INK[2], INK[3], 0.92), 12)
    local bx, bwid = ix + iw - 170, 100
    rfill(bx, ry + 6, bwid, 6, C(0.035, 0.038, 0.035), 3)
    local fill = math.min(1, r.c / (r.need * 2))
    rfill(bx, ry + 6, math.max(3, bwid * fill), 6, ok and acid(0.9) or C(AMBER[1], AMBER[2], AMBER[3], 0.9), 3)
    local nx = bx + bwid * 0.5
    rfill(nx - 0.5, ry + 3, 1, 12, C(1, 1, 1, 0.55))
    ptext_r(ix + iw, ry + 2, string.format("%.1f : 1", r.c), ok and acid(1) or C(AMBER[1], AMBER[2], AMBER[3], 1), 12)
    hit("cr" .. i, ix, ry, iw, 22)
    tipfor("cr" .. i, string.format("%s: contrast %.2f : 1, minimum %.2g : 1. The white tick marks the minimum; the bar is full at twice the minimum.", r.name, r.c, r.need))
  end
end

local function p_actions(x, y, w, h)
  panel(x, y, w, h, "ACTIONS")
  local ix, iw, cy = x + 12, w - 24, y + 32
  local wide = w > 600
  local bw = wide and (iw - 24) / 4 or (iw - 8) / 2
  local function pos(n)
    if wide then return ix + (n - 1) * (bw + 8), cy end
    return ix + ((n - 1) % 2) * (bw + 8), cy + floor((n - 1) / 2) * 34
  end
  local bx, by = pos(1)
  if btn("a_apply", bx, by, bw, 26, "APPLY NOW", false, true, "Apply everything again (also writes the track/mixer background parameters).") then
    dirty = true; last_apply_t = 0
  end
  bx, by = pos(2)
  if btn("a_reset", bx, by, bw, 26, "RESET", false, false, "Back to the GRAPHITE defaults.") then
    S = copy(DEFAULTS); custom_rgb = 0x39FF14; dirty = true
  end
  bx, by = pos(3)
  if btn("a_undo", bx, by, bw, 26, "UNDO ALL", false, false, "Reload the theme file: all live adjustments are dropped.") then revert_theme() end
  bx, by = pos(4)
  if btn("a_bake", bx, by, bw, 26, "BAKE THEME", false, true, "Write the current colours into a new theme file 'Clean & Flat Acid (Adjusted)' that survives restarts.") then
    local ok, e = pcall(bake, S)
    if not ok then set_status("Bake failed: " .. tostring(e)) end
  end
end

-- ---- Grund, Kopf, Fuss
local function ground(cw, ch)
  local dl, ox, oy = UK.dl, UK.gx, UK.gy
  local top, bot = C(0.068, 0.073, 0.068), C(0.038, 0.041, 0.038)
  R.ImGui_DrawList_AddRectFilledMultiColor(dl, ox, oy, ox + cw, oy + ch, top, top, bot, bot)
  local bw = math.max(24, math.min(cw, ch) * 0.09)
  local k, z = C(0, 0, 0, 0.34), C(0, 0, 0, 0)
  R.ImGui_DrawList_AddRectFilledMultiColor(dl, ox, oy, ox + cw, oy + bw, k, k, z, z)
  R.ImGui_DrawList_AddRectFilledMultiColor(dl, ox, oy + ch - bw, ox + cw, oy + ch, z, z, k, k)
  R.ImGui_DrawList_AddRectFilledMultiColor(dl, ox, oy, ox + bw, oy + ch, k, z, z, k)
  R.ImGui_DrawList_AddRectFilledMultiColor(dl, ox + cw - bw, oy, ox + cw, oy + ch, z, k, k, z)
end

local function header(W, loaded)
  local narrow = W < 600
  local x = spaced(MARG, narrow and 8 or 15, "TT THEME ADJUSTER", acid(1), 19, 2.2)
  ptext(x + 8, narrow and 15 or 22, "v" .. VERSION, C(0.45, 0.48, 0.45), 12)
  local label = loaded and "TIM TECHLOR THEME ACTIVE" or "THEME NOT LOADED"
  local colr = loaded and { UK.ar, UK.ag, UK.ab } or AMBER
  local sx = narrow and MARG or (W - MARG - 214)
  local sy = narrow and 42 or 28
  if not narrow then
    local tx = x + 60
    if sx - tx > 30 then line(tx, sy, sx + 8, sy, dimc(1)) end
  end
  led(sx + 6, sy, 3.4, true, colr)
  ptext(sx + 16, sy - 7, label, C(colr[1], colr[2], colr[3], 1), 12)
  hit("hdr", sx, sy - 10, 200, 20)
  tipfor("hdr", loaded and "The Tim Techlor theme is the active REAPER theme; changes apply live." or "Select 'Tim Techlor' in Options > Themes; until then nothing is applied.")
  rfill(MARG, HEAD - 4, W - 2 * MARG, 1, dimc(0.35))
end

local function footer(W, y, loaded)
  local narrow = W < 600
  local dimt = C(0.45, 0.48, 0.45)
  local counters = string.format("last apply: %d colours, %d missing, %d layout params", LAST_APPLY.set, LAST_APPLY.miss, LAST_APPLY.params)
  ptext(MARG + 2, y + 6, STATUS, acid(0.9), 12)
  if narrow then
    if loaded then ptext(MARG + 2, y + 24, counters, dimt, 11)
    else ptext(MARG + 2, y + 24, "Select the theme in Options > Themes.", C(AMBER[1], AMBER[2], AMBER[3], 1), 11) end
    ptext(MARG + 2, y + 40, "Not live (BAKE only): main window background.", dimt, 11)
  else
    ptext(MARG + 2, y + 24, counters .. "   |   Not live (BAKE only): main window background.", dimt, 11)
    if not loaded then ptext_r(W - MARG - 94, y + 6, "Select the theme in Options > Themes.", C(AMBER[1], AMBER[2], AMBER[3], 1), 12) end
  end
  local tx, ty = W - MARG - 84, narrow and y + 4 or y + 20
  -- Fenster-Skalierung des Adjusters selbst (nicht die REAPER-UI-Skalierung): setzt die Fenstergroesse auf Designmass x Faktor
  local wx0, wy0 = narrow and (tx - 4 * 44 - 8) or (tx - 4 * 44 - 8), narrow and y + 34 or ty
  if narrow then wx0, wy0 = W - MARG - 4 * 44 + 4, y + 34 end
  for i, f in ipairs({ 1.0, 1.25, 1.5, 2.0 }) do
    if btn("w_" .. i, wx0 + (i - 1) * 44, wy0, 40, 22, pc_fmt(f), math.abs(UK.sc - f) < 0.03, false,
        "Resize this window to " .. pc_fmt(f) .. " (the adjuster's own size; REAPER's UI scale is in FONT SIZES AND UI SCALE).") then
      WIN_RESIZE = f
      R.SetExtState(NS, "winscale", tostring(f), true)
    end
  end
  if toggle("t_tips", tx, ty, 84, 22, TIPS_ON, "TIPS", "Show or hide tooltips (like OPTIONS > TOOLTIPS in the plugins).") then
    TIPS_ON = not TIPS_ON
    R.SetExtState(NS, "tips", TIPS_ON and "1" or "0", true)
  end
end

-- ---- Layout: drei Spalten (breit, Designhoehe <= ca. 800) oder eine (hoch); die Variante mit dem groesseren Massstab gewinnt
-- Vorgabe des Nutzers (14.10.2026): bei 100 % hoechstens 850 px Fensterhoehe.
local function layout_for(mode, hp)
  local items = {}
  if mode == 2 then
    local cols = {
      { { p_presets, hp }, { p_background, H_BG }, { p_accent, H_ACC }, { p_contrast, H_CON } },
      { { p_preview, H_PRV }, { p_text, H_TXT } },
      { { p_fonts, H_FNT }, { p_trk, H_TRK }, { p_actions, H_ACT } },
    }
    local bottom = 0
    for c, col in ipairs(cols) do
      local x, y = MARG + (c - 1) * (COLW + GAP), HEAD
      for _, e in ipairs(col) do items[#items + 1] = { e[1], x, y, COLW, e[2] }; y = y + e[2] + GAP end
      bottom = math.max(bottom, y - GAP)
    end
    return items, 2 * MARG + 3 * COLW + 2 * GAP, bottom + MARG + FOOT
  end
  local y = HEAD
  local list = { { p_presets, hp }, { p_background, H_BG }, { p_preview, H_PRV }, { p_accent, H_ACC }, { p_text, H_TXT }, { p_trk, H_TRK }, { p_fonts, H_FNT }, { p_contrast, H_CON }, { p_actions, H_ACT } }
  for i, e in ipairs(list) do
    items[#items + 1] = { e[1], MARG, y, COLW, e[2] }
    y = y + e[2] + (i < #list and GAP or 0)
  end
  return items, 2 * MARG + COLW, y + MARG + FOOT1
end

local function draw_ui_kit(cw, ch)
  local mx, my = R.ImGui_GetMousePos(ctx)
  local mods = R.ImGui_GetKeyMods(ctx)
  UK.shift = (mods & R.ImGui_Mod_Shift()) ~= 0
  UK.ctrl = (mods & R.ImGui_Mod_Ctrl()) ~= 0
  local ar, ag, ab
  do
    local hex = (S.accent_hex ~= "" and S.accent_hex) or SCHEMES[S.scheme + 1][2]
    local n = tonumber(hex:sub(2), 16) or 0x39FF14
    ar, ag, ab = ((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255
  end
  UK.ar, UK.ag, UK.ab = ar, ag, ab
  UK.dl = R.ImGui_GetWindowDrawList(ctx)
  local gx, gy = R.ImGui_GetCursorScreenPos(ctx)
  UK.gx, UK.gy = gx, gy
  -- Massstab: drei Spalten (breit) oder eine (hoch); die Variante mit dem groesseren Massstab gewinnt
  local hp = h_presets(COLW)
  local i1, W1, H1 = layout_for(1, hp)
  local i2, W2, H2 = layout_for(2, hp)
  local s1, s2 = math.min(cw / W1, ch / H1), math.min(cw / W2, ch / H2)
  local items, W, H, sc
  if s2 >= s1 then items, W, H, sc = i2, W2, H2, s2 else items, W, H, sc = i1, W1, H1, s1 end
  if sc < 0.35 then sc = 0.35 elseif sc > 3 then sc = 3 end
  UK.sc = sc
  local okw, ww, wh = pcall(R.ImGui_GetWindowSize, ctx)
  if okw and ww then WIN_DES = { W, H, ww - cw, wh - ch } end
  UK.ox = gx + (cw - W * sc) / 2
  UK.oy = gy + (ch - H * sc) / 2
  UK.mxd = (mx - UK.ox) / sc
  UK.myd = (my - UK.oy) / sc

  ground(cw, ch)
  local loaded = is_tt_theme()
  header(W, loaded)
  for _, it in ipairs(items) do it[1](it[2], it[3], it[4], it[5]) end
  footer(W, H - ((W < 600) and FOOT1 or FOOT), loaded)
end

-- ---------------------------------------------------------------- klassische Oberflaeche (Rueckfall)
local function slider_pct(label, key, mn, mx, tooltip, scale_k)
  scale_k = scale_k or 100
  local v = math.floor(S[key] * scale_k + 0.5)
  local rv, nv = R.ImGui_SliderInt(ctx, label, v, mn, mx, "%d%%")
  if rv then S[key] = nv / scale_k; dirty = true end
  tip(tooltip)
end

local function section(title)
  R.ImGui_Spacing(ctx)
  R.ImGui_TextColored(ctx, ACID, title)
  R.ImGui_Separator(ctx)
end

local function draw_ui_classic()
  R.ImGui_TextColored(ctx, ACID, "TT THEME ADJUSTER")
  R.ImGui_SameLine(ctx); R.ImGui_TextColored(ctx, 0x8C8C8CFF, "v" .. VERSION)

  section("PRESETS")
  for i, pr in ipairs(PRESETS_BUILTIN) do
    if i > 1 and (i - 1) % 2 ~= 0 then R.ImGui_SameLine(ctx) end
    if R.ImGui_Button(ctx, pr[1]) then
      for k, v in pairs(pr[2]) do S[k] = v end
      dirty = true
    end
    tip("Load the built-in preset " .. pr[1] .. " (only background, grid and text values change).")
  end
  for i, up in ipairs(USER_PRESETS) do
    if R.ImGui_Button(ctx, up[1] .. "##u" .. i) then S = deser(up[2], S); dirty = true end
    tip("Load your preset.")
    R.ImGui_SameLine(ctx)
    if R.ImGui_Button(ctx, "X##d" .. i) then
      table.remove(USER_PRESETS, i); if save_presets() then set_status("Preset deleted") end; break
    end
    tip("Delete this preset.")
    R.ImGui_SameLine(ctx)
  end
  R.ImGui_NewLine(ctx)
  R.ImGui_SetNextItemWidth(ctx, 180)
  local rv, nm = R.ImGui_InputText(ctx, "##pname", preset_name)
  if rv then preset_name = nm end
  tip("Name for a new preset (type, then SAVE PRESET).")
  R.ImGui_SameLine(ctx)
  if R.ImGui_Button(ctx, "SAVE PRESET") and preset_name ~= "" then
    local nmv = preset_name:gsub("[\t\r\n]", " ")
    local done = false
    for _, up in ipairs(USER_PRESETS) do if up[1] == nmv then up[2] = ser(S); done = true end end
    if not done then USER_PRESETS[#USER_PRESETS + 1] = { nmv, ser(S) } end
    if save_presets() then set_status("Preset saved: " .. nmv) end
  end
  tip("Store all current values as a named preset (resource folder, tt_themeadjuster_presets.txt).")

  section("BACKGROUND")
  slider_pct("BG LIFT", "lift", 0, 100, "Raises the whole background from black (0) to slate grey (100).")
  slider_pct("TINT", "tint", 0, 100, "How much of the accent colour tints the grey surfaces (0 = neutral grey).")
  slider_pct("PANEL STEPS", "step", 50, 250, "Distance between surface levels: arrange, track panel, borders, hover.")
  slider_pct("GRID", "grid", 0, 300, "Contrast of grid lines and dividers in arrange and MIDI editor.")

  section("ACCENT")
  local names = ""
  for _, sch in ipairs(SCHEMES) do names = names .. sch[1] .. "\0" end
  names = names .. "\0"
  R.ImGui_SetNextItemWidth(ctx, 180)
  local rvc, sidx = R.ImGui_Combo(ctx, "SCHEME", S.scheme, names)
  if rvc then S.scheme = sidx; S.accent_hex = ""; custom_rgb = tonumber(SCHEMES[sidx + 1][2]:sub(2), 16); dirty = true end
  -- Historie: tip("The ten Tim Techlor accent schemes ...") - seit ACID DARK sind es elf (Argon-Zweitmeinung, 19.10.2026)
  tip("The eleven Tim Techlor accent schemes (ACID is the brand default).")
  R.ImGui_SetNextItemWidth(ctx, 180)
  local rve, ncol = R.ImGui_ColorEdit3(ctx, "CUSTOM", custom_rgb)
  if rve then
    custom_rgb = ncol
    S.accent_hex = string.format("#%06X", ncol & 0xFFFFFF)
    dirty = true
  end
  tip("Free accent colour (overrides the scheme accent).")

  section("TEXT AND ITEMS")
  slider_pct("TEXT", "text", 0, 100, "Text brightness: 0 = brand ink, 100 = white.")
  slider_pct("ITEM UNSELECTED", "item_unsel", 50, 150, "Brightness of the default item body (items without a track colour).")
  slider_pct("ITEM SELECTED", "item_sel", 50, 150, "Brightness of the selected item body.")
  local rvm, mv = R.ImGui_Checkbox(ctx, "MUTED NOTES AMBER", S.mute_amber)
  if rvm then S.mute_amber = mv; dirty = true end
  tip("Muted MIDI notes use amber (on) instead of red (off).")
  local rvs, sv = R.ImGui_Checkbox(ctx, "SELECTION FRAME", S.sel_frame)
  if rvs then SF.set(sv) end
  tip(SEL_TIP)
  local rvw, wv = R.ImGui_Checkbox(ctx, "LOGO WATERMARK", S.wm_on)
  if rvw then WM.set(wv) end
  tip(WM_TIP)
  slider_pct("LOGO OPACITY", "wm_op", 2, 40, "Opacity of the logo watermark (2 to 40 percent).")
  slider_pct("LOGO SIZE", "wm_size", 20, 100, "Logo height as a share of the arrange height.")
  local rvc2, cv = R.ImGui_Checkbox(ctx, "LOGO IN CORNER", S.wm_corner)
  if rvc2 then S.wm_corner = cv; dirty = true end
  tip("Off = centred, on = bottom right corner of the arrange.")

  section("TRACK COLOURS")
  local tnames = ""
  for i = 1, TC.COUNT do tnames = tnames .. TC.name(i) .. "\0" end
  tnames = tnames .. "\0"
  R.ImGui_SetNextItemWidth(ctx, 180)
  local rvt, tidx = R.ImGui_Combo(ctx, "PALETTE COLOUR", floor(S.tc_pick), tnames)
  if rvt then S.tc_pick = tidx; dirty = true end
  tip("Palette colour used by COLOUR SELECTED.")
  slider_pct("COLOUR INTENSITY", "tc_int", 20, 200, "Track colour intensity: scales saturation and brightness of the palette; light text stays readable.")
  if R.ImGui_Button(ctx, "COLOUR SELECTED") then TC.run(true, TC.act.pick) end
  tip("Paint the picked palette colour onto all selected tracks.")
  R.ImGui_SameLine(ctx)
  if R.ImGui_Button(ctx, "RAINBOW ALL") then TC.run(false, TC.act.rainbow) end
  tip("Colour all top-level tracks through the palette; folder children get a darker shade of their folder.")
  R.ImGui_SameLine(ctx)
  if R.ImGui_Button(ctx, "ACID RAMP") then TC.run(true, TC.act.ramp) end
  tip("Colour the selected tracks in a gradient from dark to light accent; with a grey or near-grey accent it falls back to Acid Green, since grey alone gives no gradient.")
  R.ImGui_SameLine(ctx)
  if R.ImGui_Button(ctx, "CLEAR SELECTED") then TC.run(true, TC.act.clear) end
  tip("Reset the colour of the selected tracks to the theme default.")

  section("FONT SIZES AND UI SCALE")
  for _, r in ipairs(FS_ROWS) do slider_pct(r[2], r[1], 70, 200, r[3], 100) end
  if R.ImGui_Button(ctx, "APPLY FONTS") then fonts_force = true end
  tip("Write the font sizes into 'Clean & Flat Acid (Adjusted)' and reload the theme.")
  for i, v in ipairs(UI_STEPS) do
    R.ImGui_SameLine(ctx)
    if R.ImGui_Button(ctx, "UI " .. pc_fmt(v) .. "##u" .. i) then
      local ok, e = pcall(set_uiscale, v)
      if not ok then set_status("UI scale failed: " .. tostring(e)) end
    end
    tip("Set the REAPER UI scale to " .. pc_fmt(v) .. " (needs SWS; a REAPER restart may be needed).")
  end

  section("CONTRAST CHECK")
  for _, r in ipairs(contrast_report(S)) do
    local ok = r.c >= r.need
    R.ImGui_TextColored(ctx, ok and ACID or 0xFFB35CFF, string.format("%-30s %4.1f : 1   %s", r.name, r.c, ok and "OK" or ("LOW (< " .. r.need .. ")")))
  end

  section("ACTIONS")
  if R.ImGui_Button(ctx, "APPLY NOW") then dirty = true; last_apply_t = 0 end
  tip("Apply everything again (also writes the track/mixer background parameters).")
  R.ImGui_SameLine(ctx)
  if R.ImGui_Button(ctx, "RESET") then S = copy(DEFAULTS); custom_rgb = 0x39FF14; dirty = true end
  tip("Back to the GRAPHITE defaults.")
  R.ImGui_SameLine(ctx)
  if R.ImGui_Button(ctx, "UNDO ALL") then revert_theme() end
  tip("Reload the theme file: all live adjustments are dropped.")
  R.ImGui_SameLine(ctx)
  if R.ImGui_Button(ctx, "BAKE THEME") then local ok, e = pcall(bake, S); if not ok then set_status("Bake failed: " .. tostring(e)) end end
  tip("Write the current colours into a new theme file 'Clean & Flat Acid (Adjusted)' that survives restarts.")

  R.ImGui_Spacing(ctx)
  if not is_tt_theme() then R.ImGui_TextColored(ctx, 0xFFB35CFF, "Tim Techlor theme not loaded: select it in Options > Themes.") end
  R.ImGui_TextColored(ctx, 0x8C8C8CFF, STATUS)
  R.ImGui_TextColored(ctx, 0x8C8C8CFF, "Not live (BAKE only): main window background.")
  R.ImGui_TextColored(ctx, 0x8C8C8CFF, string.format("last apply: %d colours, %d missing, %d layout params", LAST_APPLY.set, LAST_APPLY.miss, LAST_APPLY.params))
end

-- ---------------------------------------------------------------- Test-Haken (nur mit ExtState test_ok = 20261001)
local function test_poll()
  TEST.on = (R.GetExtState and R.GetExtState(NS, "test_ok") == "20261001") or false
  if not TEST.on then return end
  local c = R.GetExtState(NS, "test_cmd")
  if not c or c == "" then return end
  R.SetExtState(NS, "test_cmd", "", false)
  for one in c:gmatch("[^;]+") do
    local k, v = one:match("^([%w_]+):?(.*)$")
    if k == "rects" then TEST.dump = v
    elseif k == "state" then TEST.state = v
    elseif k == "reset" then S = copy(DEFAULTS); custom_rgb = 0x39FF14; dirty = true; last_apply_t = 0
    elseif k == "apply" then dirty = true; last_apply_t = 0
    elseif k == "bake" then pcall(bake, S)
    elseif k == "fonts" then fonts_force = true
    elseif k == "undo" then revert_theme()
    elseif k == "uiscale" then pcall(set_uiscale, tonumber(v) or 1.0)
    elseif k == "winscale" then WIN_RESIZE = tonumber(v) or 1.0
    elseif k == "tips" then TIPS_ON = (v ~= "0")
    elseif k == "selframe" then SF.set(v ~= "0")
    elseif k == "watermark" then WM.set(v ~= "0")
    elseif k == "tc" then
      if TC.act[v] then TC.run(v ~= "rainbow", TC.act[v]) end
    elseif k == "set" then
      local sk, sv = (v or ""):match("^([%w_]+)=(.*)$")
      if sk and DEFAULTS[sk] ~= nil then
        if type(DEFAULTS[sk]) == "number" then S[sk] = tonumber(sv) or S[sk]
        elseif type(DEFAULTS[sk]) == "boolean" then S[sk] = (sv == "true" or sv == "1")
        else S[sk] = sv end
        dirty = true; last_apply_t = 0
      end
    end
  end
  R.SetExtState(NS, "test_ack", c, false)
end

local function test_flush()
  if not TEST.on then return end
  if TEST.dump and TEST.dump ~= "" then
    local path = TEST.dump; TEST.dump = nil
    local out = { string.format("scale %.4f", UK.sc) }
    local names = {}
    for n in pairs(TEST.rects) do names[#names + 1] = n end
    table.sort(names)
    for _, n in ipairs(names) do
      local r = TEST.rects[n]
      local x0, y0, x1, y1 = r[1], r[2], r[3], r[4]
      if R.ImGui_PointConvertNative then
        x0, y0 = R.ImGui_PointConvertNative(ctx, x0, y0, true)
        x1, y1 = R.ImGui_PointConvertNative(ctx, x1, y1, true)
      end
      out[#out + 1] = string.format("%s %d %d %d %d", n, floor(x0 + 0.5), floor(y0 + 0.5), floor(x1 + 0.5), floor(y1 + 0.5))
    end
    local f = io.open(path, "wb"); if f then f:write(table.concat(out, "\n"), "\n"); f:close() end
  end
  if TEST.state and TEST.state ~= "" then
    local path = TEST.state; TEST.state = nil
    local lines = {
      "version=" .. VERSION,
      "status=" .. tostring(STATUS),
      "active=" .. tostring(theme_path()),
      "loaded=" .. tostring(is_tt_theme()),
      "set=" .. tostring(LAST_APPLY.set),
      "miss=" .. tostring(LAST_APPLY.miss),
      "params=" .. tostring(LAST_APPLY.params),
      "uiscale=" .. string.format("%.2f", UI_SCALE),
      "winscale=" .. string.format("%.3f", UK.sc),
      "tips=" .. tostring(TIPS_ON),
      "sf_bm=" .. tostring(SF.bm ~= nil),
      "wm_bm=" .. tostring(WM.bm ~= nil),
      "fonts_applied=" .. tostring(fonts_applied or ""),
      "state=" .. ser(S),
    }
    local f = io.open(path, "wb"); if f then f:write(table.concat(lines, "\n"), "\n"); f:close() end
  end
end

local function loop()
  test_poll()
  TEST.rects = {}
  local tp = theme_path()
  if tp ~= last_theme_path then
    last_theme_path = tp
    ORIG_PARAMS = {}
    if is_tt_theme() and tp:lower():match("%.reaperthemezip$") then fonts_applied, fonts_seen = fs_sig(DEFAULTS), nil end
    if is_tt_theme() then dirty = true; set_status("Theme changed - re-applying") end
  end
  local kit = (FONT_UI ~= nil) and (KIT_ERR == nil)
  local nc, nv = push_theme(kit)
  local pf = false
  if FONT_UI then R.ImGui_PushFont(ctx, FONT_UI, 15); pf = true end
  if kit then R.ImGui_SetNextWindowSize(ctx, 1380, 845, R.ImGui_Cond_FirstUseEver())
  else R.ImGui_SetNextWindowSize(ctx, 470, 760, R.ImGui_Cond_FirstUseEver()) end
  if kit and WIN_RESIZE and WIN_DES then
    -- Nutzervorgabe: bei 100 % hoechstens 850 px Fensterhoehe (auch bei vielen Benutzer-Presets oder einspaltigem Layout)
    R.ImGui_SetNextWindowSize(ctx, math.floor(WIN_DES[1] * WIN_RESIZE + WIN_DES[3] + 0.5),
      math.min(math.floor(850 * WIN_RESIZE + 0.5), math.floor(WIN_DES[2] * WIN_RESIZE + WIN_DES[4] + 0.5)), R.ImGui_Cond_Always())
    WIN_RESIZE = nil
  end
  local wflags = kit and (R.ImGui_WindowFlags_NoScrollbar() | R.ImGui_WindowFlags_NoScrollWithMouse() | R.ImGui_WindowFlags_NoCollapse()) or 0
  local visible, open = R.ImGui_Begin(ctx, "TT Theme Adjuster", true, wflags)
  if visible then
    local ok, err
    if kit then
      local cw, ch = R.ImGui_GetContentRegionAvail(ctx)
      ok, err = pcall(draw_ui_kit, cw, ch)
      if not ok then
        KIT_ERR = tostring(err)
        R.ShowConsoleMsg("TT Theme Adjuster: UIKit view failed, using the classic view." .. "\n" .. KIT_ERR .. "\n")
      end
    else
      ok, err = pcall(draw_ui_classic)
      if not ok then set_status("UI error: " .. tostring(err)) end
    end
    R.ImGui_End(ctx)
  end
  if pf then R.ImGui_PopFont(ctx) end
  R.ImGui_PopStyleVar(ctx, nv)
  R.ImGui_PopStyleColor(ctx, nc)

  if dirty and (R.time_precise() - last_apply_t) > 0.06 then
    dirty = false
    last_apply_t = R.time_precise()
    local ok, set = pcall(apply, S, true)
    if not ok then set_status("Apply failed: " .. tostring(set)) end
    save_state()
    pending_params = true
  elseif pending_params and not dirty and (R.time_precise() - last_apply_t) > 0.4 then
    pending_params = false
    if is_tt_theme() then
      local okp, np = pcall(set_layout_params, S)
      if okp then LAST_APPLY.params = np end
      if R.ThemeLayout_RefreshAll then R.ThemeLayout_RefreshAll() end
    end
  end
  -- Schriften: Aenderung erkennen (Schieber, RESET, Preset), 1,2 s nach der letzten Aenderung (Maus losgelassen) schreiben + neu laden
  local okf, errf = pcall(function()
    local now = R.time_precise()
    local sg = fs_sig(S)
    if sg ~= fonts_seen then fonts_seen = sg; fonts_t = now; fonts_dirty = (sg ~= fonts_applied) end
    if fonts_force or (fonts_dirty and (now - fonts_t) > 1.2 and not R.ImGui_IsMouseDown(ctx, 0)) then run_fonts() end
  end)
  if not okf then fonts_dirty, fonts_force = false, false; set_status("Fonts error: " .. tostring(errf)) end
  local oks, errs = pcall(SF.tick)
  if not oks then S.sel_frame = false; dirty = true; pcall(SF.off); set_status("Selection frame error: " .. tostring(errs)) end
  local okw, errw = pcall(WM.tick)
  if not okw then S.wm_on = false; dirty = true; pcall(WM.off); set_status("Watermark error: " .. tostring(errw)) end
  test_flush()
  if open then R.defer(loop) else pcall(SF.off); pcall(WM.unload) end
end

load_state(); load_presets()
if type(S.scheme) ~= "number" or S.scheme < 0 or S.scheme >= #SCHEMES then S.scheme = 0 end
S.tc_pick = clamp(floor(tonumber(S.tc_pick) or 0), 0, TC.COUNT - 1)
S.tc_int = clamp(tonumber(S.tc_int) or 1.0, 0.2, 2.0)
if S.accent_hex ~= "" then custom_rgb = tonumber(S.accent_hex:sub(2), 16) or custom_rgb
else custom_rgb = tonumber(SCHEMES[S.scheme + 1][2]:sub(2), 16) end
fonts_applied = theme_path():lower():match("%.reaperthemezip$") and fs_sig(DEFAULTS) or fs_sig(S)   -- Annahme: das geladene Theme passt zu den gespeicherten Faktoren (sonst APPLY FONTS)
dirty = true   -- gespeicherten Zustand sofort auf das (neu geladene) Theme anwenden
R.defer(loop)
