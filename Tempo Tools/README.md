# Tim Techlor's BPM2MS2HZ Calculator for REAPER

ReaScript (Lua) · Dear ImGui tool window · converts your project tempo into milliseconds and Hz

---

## English

### What it does

The BPM2MS2HZ Calculator is a compact tool window for REAPER that reads your
project tempo and converts every note value into the two numbers plugins and
hardware actually want:

- **Milliseconds (ms)** — how long a note value lasts at the current tempo
- **Hertz (Hz)** — the matching frequency (1000 / ms)

It covers all note values from **1/1 down to 1/32**, each in three variants:
plain, **dotted** (× 1.5) and **triplet** (× 2/3). A second tab converts whole
**bars (1–64)** into seconds and Hz, with a selectable time signature.

The window follows your project tempo live — including tempo automation during
playback. Or unlink it and dial in any tempo manually (40–300 BPM, 0.1 BPM steps).

### What you need it for

Whenever a delay, synth, LFO or compressor wants a raw number instead of a
note value:

- **Delays and echoes** — exact note-synced delay times in ms; dotted and
  triplet delays included.
- **LFO rates** — enter the Hz value to sync filter sweeps, tremolo, auto-pan
  or wobble to 1/8, 1/16, 1/16T and so on.
- **Sidechain pumping** — match compressor release or ducking times to the grid.
- **Reverb pre-delay and decay** — place the tail precisely between the kicks.
- **Envelopes, gates, transient design** — attack, hold and release values
  that sit on subdivisions.
- **Arrangement math** — how long is a 16-bar break at 128 BPM? (30.0 seconds.)
  Useful for risers, transitions and checking whether a loop fills exactly 2 bars.

**Click any value to copy it to the clipboard** and paste it straight into
your plugin.

### The two tabs

- **NOTE VALUES** — subdivisions of the beat, from 1/1 to 1/32, each with
  dotted and triplet variants, shown as ms and Hz side by side.
  Color code: **green rows** = full note values (1/4, 1/8, 1/16 …),
  **grey rows** = dotted values, **white rows** = triplets.
- **BARS** — whole bars from 1 to 64 in seconds and Hz. Choose the time
  signature first (dropdown next to TIME SIGNATURE: 4/4, 3/4, 5/4, 7/4,
  6/8, 9/8, 12/8) — bar lengths adapt automatically, so a 6/8 bar correctly
  equals six eighth notes.

### OPTIONS (top right)

- **FONT SIZE  − / +** — scales the whole UI from 80 % to 150 %.
- **dotted (1/4.)** — show or hide the dotted rows.
- **triplets (1/4T)** — show or hide the triplet rows.
- **wordmark watermark** — background branding on or off.

Every option (and the selected time signature) is saved permanently and
survives REAPER restarts.

### Tempo handling

- Checkbox **from project** checked: the large number mirrors the project
  tempo live, automation included.
- Dragging the slider switches to a manual tempo; it snaps to 0.1 BPM.
- Re-check **from project** to return to sync.

### Requirements

- REAPER (any recent version)
- **Dear ImGui bindings (ReaImGui) v0.10 or newer** by cfillion — install
  via ReaPack: Extensions -> ReaPack -> Browse Packages -> "Dear ImGui" -> Install

### Installation

1. Make sure ReaImGui is installed (see above).
2. Copy the folder — `TT_BPM_Calculator.lua` and `TT_Wordmark.png` together —
   into your REAPER Scripts folder, for example
   `Scripts/Tim Techlor - BPM2MS2HZ Calculator/`.
   (Options -> Show REAPER resource path in explorer/finder -> Scripts)
3. In REAPER: Actions -> Show action list -> New action -> Load ReaScript,
   then select the .lua file and run it. Optionally assign a shortcut or
   toolbar button.

The wordmark image is found automatically next to the script file. Without it
the script still runs, using a plain system font.

### The math

```
ms  = 60000 / BPM * beats          (1 beat = 1 quarter note)
Hz  = 1000 / ms
dotted = value x 1.5               triplet = value x 2/3
bar seconds = 60 / BPM * (numerator * 4 / denominator)
```

### Credits & License

Script by **Tim Techlor**. Built on the Dear ImGui bindings for REAPER
(ReaImGui) by Christian Fillion. Provided as-is, free to use and share —
keep the credits. The bundled wordmark was rendered in Zilap Orion, so no
font installation is required.

---

## Deutsch

### Was das Script macht

Der BPM2MS2HZ Calculator ist ein kompaktes Tool-Fenster für REAPER, das dein
Projekt-Tempo ausliest und jeden Notenwert in die beiden Zahlen umrechnet,
die Plugins und Geräte tatsächlich wollen:

- **Millisekunden (ms)** — wie lang ein Notenwert beim aktuellen Tempo ist
- **Hertz (Hz)** — die zugehörige Frequenz (1000 / ms)

Abgedeckt sind alle Notenwerte von **1/1 bis 1/32**, jeweils in drei Varianten:
normal, **punktiert** (× 1,5) und **Triole** (× 2/3). Ein zweiter Tab rechnet
ganze **Takte (1–64)** in Sekunden und Hz um — mit einstellbarer Taktart.

Das Fenster folgt dem Projekt-Tempo live — inklusive Tempo-Automatisierung
während der Wiedergabe. Oder du koppelst es ab und stellst jedes Tempo manuell
ein (40–300 BPM, 0,1-BPM-Raster).

### Wofür man es braucht

Immer dann, wenn Delay, Synth, LFO oder Compressor eine nackte Zahl will
statt eines Notenwerts:

- **Delays und Echos** — exakt notensynchrone Delay-Zeiten in ms; punktierte
  Delays und Triolen inklusive.
- **LFO-Tempo** — den Hz-Wert eintragen und Filter-Sweeps, Tremolo, Auto-Pan
  oder Wobble auf 1/8, 1/16, 1/16T usw. synchronisieren.
- **Sidechain-Pumpen** — Compressor-Release oder Ducking aufs Raster legen.
- **Reverb Pre-Delay und Decay** — den Tail präzise zwischen die Kicks setzen.
- **Envelopes, Gates, Transient-Design** — Attack-, Hold- und Release-Werte,
  die auf Unterteilungen sitzen.
- **Arrangement-Mathematik** — wie lang ist eine 16-Takt-Break bei 128 BPM?
  (30,0 Sekunden.) Nützlich für Riser, Übergänge und um zu prüfen, ob ein
  Loop exakt 2 Takte füllt.

**Jeden Wert anklicken kopiert ihn in die Zwischenablage** — direkt in das
Plugin einfügen, fertig.

### Die zwei Tabs

- **NOTE VALUES** — Unterteilungen des Beats, von 1/1 bis 1/32, jeweils mit
  punktierter und Triolen-Variante, als ms und Hz nebeneinander.
  Farbcodes: **grüne Zeilen** = volle Notenwerte (1/4, 1/8, 1/16 …),
  **graue Zeilen** = punktierte Werte, **weiße Zeilen** = Triolen.
- **BARS** — ganze Takte von 1 bis 64 in Sekunden und Hz. Zuerst die Taktart
  wählen (Dropdown neben TIME SIGNATURE: 4/4, 3/4, 5/4, 7/4, 6/8, 9/8, 12/8) —
  die Taktlängen passen sich automatisch an, ein 6/8-Takt entspricht also
  korrekt sechs Achteln.

### OPTIONS (oben rechts)

- **FONT SIZE  − / +** — skaliert die komplette UI von 80 % bis 150 %.
- **dotted (1/4.)** — punktierte Zeilen anzeigen oder ausblenden.
- **triplets (1/4T)** — Triolen-Zeilen anzeigen oder ausblenden.
- **wordmark watermark** — Hintergrund-Branding ein- oder ausschalten.

Jede Option (und die gewählte Taktart) wird dauerhaft gespeichert und
übersteht REAPER-Neustarts.

### Tempo-Steuerung

- Haken bei **from project**: Die große Zahl folgt dem Projekt-Tempo live,
  Automation inklusive.
- Slider ziehen schaltet auf manuelles Tempo; er rastet auf 0,1 BPM.
- Haken wieder setzen bei **from project** = zurück zur Synchronisation.

### Voraussetzungen

- REAPER (eine aktuelle Version)
- **Dear ImGui bindings (ReaImGui) v0.10 oder neuer** von cfillion —
  Installation über ReaPack: Extensions -> ReaPack -> Browse Packages ->
  "Dear ImGui" -> Install

### Installation

1. Sicherstellen, dass ReaImGui installiert ist (siehe oben).
2. Den Ordner — `TT_BPM_Calculator.lua` und `TT_Wordmark.png` zusammen — in
   den REAPER-Scripts-Ordner kopieren, zum Beispiel
   `Scripts/Tim Techlor - BPM2MS2HZ Calculator/`.
   (Options -> Show REAPER resource path in explorer/finder -> Scripts)
3. In REAPER: Actions -> Show action list -> New action -> Load ReaScript,
   die .lua-Datei auswählen und starten. Optional Hotkey oder Toolbar-Button
   zuweisen.

Das Schriftzug-Bild wird automatisch neben dem Script gefunden. Ohne es läuft
das Script weiter, dann mit normaler System-Schrift.

### Die Mathematik

```
ms  = 60000 / BPM * Beats          (1 Beat = 1 Viertelnote)
Hz  = 1000 / ms
punktiert = Wert x 1,5             Triole = Wert x 2/3
Taktsekunden = 60 / BPM * (Zähler * 4 / Nenner)
```

### Credits & Lizenz

Script von **Tim Techlor**. Baut auf den Dear ImGui bindings für REAPER
(ReaImGui) von Christian Fillion auf. Bereitgestellt wie besehen, frei nutzbar
und teilbar — Credits bitte drinlassen. Der beiliegende Schriftzug wurde in
Zilap Orion gerendert, eine Font-Installation ist nicht nötig.
