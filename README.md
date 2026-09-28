# TimTechlor ReaScripts & JSFX

ReaPack-Repository mit Scripts und Plugins für [REAPER](https://www.reaper.fm/).

## Installation

1. In REAPER **ReaPack** installieren, falls noch nicht vorhanden:
   <https://reapack.com/> → passende Datei herunterladen, in den
   `UserPlugins`-Ordner legen, REAPER neu starten.
2. **Extensions → ReaPack → Import repositories…**
3. Diese URL einfügen und bestätigen:

   ```
   https://raw.githubusercontent.com/timtechlor/reapack-TimTechlor/main/index.xml
   ```

4. **Extensions → ReaPack → Browse packages…**, nach `TimTechlor` filtern,
   Paket(e) per Rechtsklick → *Install* installieren, dann **Apply**.

Updates danach über **Extensions → ReaPack → Synchronize packages**.

## Pakete

| Paket | Typ | Kategorie | Beschreibung |
|---|---|---|---|
| TT-303 Acid Machine | JSFX (Instrument) | Synths | Monophoner Acid-Bass-Synth im Stil der TB-303 |
| BPM2MS2HZ Calculator | Lua-Script | Tempo Tools | Notenwerte → Millisekunden & Hertz (ReaImGui) |
| TT Theme Font Editor | Lua-Script | Theme Tools | Theme-Schriften per Picker finden und ändern, neues Theme schreiben (ReaImGui) |

### Abhängigkeiten

- **BPM2MS2HZ Calculator** benötigt *ReaImGui: ReaScript binding for Dear ImGui*
  (cfillion). In ReaPack über das Repo **ReaTeam Extensions** verfügbar.
- **TT Theme Font Editor** benötigt *ReaImGui* (0.10+) und *js_ReaScriptAPI*,
  beide ebenfalls über **ReaTeam Extensions**.

## Lizenz

MIT — siehe [LICENSE](LICENSE).
