# TT Theme Font Editor for REAPER

ReaScript (Lua) · Dear ImGui tool window · find and change the font sizes of your REAPER theme

## What it does

- **Picker:** hover over any text in REAPER and press Shift (or click). The editor shows which
  theme font draws it — WALTER font 1–16 or one of the classic ini fonts — evaluated from the
  theme's `rtconfig.txt` with the layout and UI scale actually in use.
- **Edit:** size, bold and italic, with a live preview through a working copy of the theme.
- **Element overrides:** give a single WALTER element (e.g. `mcp.fxlist`) a font of its own
  without changing every other element that shares the font.
- **Bake theme:** writes `<Name> (TimTechlor).ReaperThemeZip` (or `.ReaperTheme`).
  The original theme is never modified.

The full manual with screenshots is installed next to the script:
`TT_ThemeFontEditor_Manual.html`.

## Requirements

- REAPER 6 or newer
- *ReaImGui: ReaScript binding for Dear ImGui* 0.10+ (ReaTeam Extensions)
- *js_ReaScriptAPI* (ReaTeam Extensions)
