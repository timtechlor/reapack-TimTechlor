# TT-FREIRAUM – Modern Presets

Plugin v1.0.0

16 new factory presets complement the five existing settings. You'll find them directly in the preset bar under FACTORY. The existing presets remain at the beginning, with the same values and indices.

These settings serve as musical starting points. Technical testing verifies loading, value ranges, and saving; it does not replace listening to your own material. No setting guarantees a fixed attenuation in dB.

## Setup

1. Place FREIRAUM on the track or bus you want to free up. For reverb and delay, place it on the return **after** the effect.
2. Send the important signal as a sidechain: in REAPER, route Audio 1/2 from the source track to 3/4 of the FREIRAUM track, using at least four track channels. In FREIRAUM, select SC SOURCE = CH 3/4. Alternatively, use the sender and GMEM LINK; the preset does not configure the link.
3. For the starting point, set MIX = 100%, AUDITION = NORM, ZONE SOLO = OFF, and LEARN = OFF. Then load the appropriate FACTORY preset.
4. With the sidechain playing, adjust THRESH to the actual level. If there is too little activity, lower THRESH gradually; if it reacts to breathing sounds or decays, raise it. The bell and filters also affect the detection level.
5. Adjust AMOUNT in the overall mix. Use DELTA briefly to check what is being removed: if too much of the wanted sound is cut, reduce AMOUNT. Then select NORM again.

**What a preset saves:** AMOUNT, three TRIMs, both XOVERs, six ATK/REL values, five SC pre-EQ values, LOOK, OUT, THRESH, and RANGE. **SC SOURCE, MIX, AUDITION, SOLO, LEARN (including the snapshot), and OPTIONS are retained when loading.** A previously active LEARN snapshot must therefore be turned off manually.

**Reading TRIM and RANGE correctly:** A negative TRIM reduces the attenuation of a zone; −12 dB does not switch it off completely. RANGE is the level distance above THRESH over which the spectral weight rises from 0 to 1. It does not limit the attenuation to a specific dB value. PRE-EQ affects the sidechain detection, not the sound of the main signal.

LOOK increases the latency compensated by REAPER. The release values are in milliseconds and are not tempo-synchronized; actual decay time and effect also depend on analysis, sidechain, and spectral tracking. All new presets use OUT = 0 dB.

## Overview

| Preset | Put FREIRAUM on | Sidechain from |
|---|---|---|
| **Vocal Clean Pocket** | Instrumental, pad or music bus | Lead vocal |
| **Rap Front Seat** | Beat or instrumental bus | Rap vocal |
| **Vocal Air Safe** | Bright pads, strings or guitar bus | Lead vocal |
| **Lead Over Pads** | Pad, chord or texture bus | Melodic lead synth |
| **Kick Sub Tight** | Sub or bass track | Short kick |
| **Techno Kick Pocket** | Bass, rumble or low synth bus | Kick |
| **Kick Into 808** | 808 or very low bass track | Kick |
| **Fast DnB Bass** | Bass bus with fast notes | Kick |
| **Snare Body Space** | Synth, guitar or music bus | Snare or clap |
| **Hats Air Slot** | Bright synth, noise or FX bus | Hi-hats or shaker |
| **Acid Lead Pocket** | Chord, pad or competing synth bus | Acid or resonant lead |
| **Reece Mid Space** | Reece, reese or mid-bass layer | Lead or vocal |
| **Pluck Through Pad** | Pad or chord bus | Pluck, arp or short keys |
| **Reverb Vocal Duck** | Reverb return, after the reverb | Dry lead vocal |
| **Delay Lead Duck** | Delay return, after the delay | Dry vocal or lead |
| **Bus Gentle Space** | Music or background bus | Vocal or important lead |

## Vocal Clean Pocket

**FACTORY slot 6 · FREIRAUM on:** instrumental, pad or music bus. **Sidechain:** lead vocal.

Unobtrusive space for a pop or R&B voice. The mids react more clearly than bass and highs; the softer ballistics are meant to keep the backing calm.

For syllables that audibly thin out the bus, first take AMOUNT back to 30–35 %.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | -9 | 10 | 150 |
| MID | 0 | 12 | 220 |
| HIGH | -6 | 8 | 150 |

- **AMOUNT:** 42 % · **THRESH:** -44 dB · **RANGE:** 14 dB.
- **XOVER:** LOW 160 Hz · HIGH 4800 Hz.
- **SC pre-EQ:** HPF 120 Hz · LPF 10000 Hz · BELL 2600 Hz / Q 0.8 / +2 dB.
- **LOOK:** 2 ms · **OUT:** 0 dB.

## Rap Front Seat

**FACTORY slot 7 · FREIRAUM on:** beat or instrumental bus. **Sidechain:** rap vocal.

Stronger midrange space for fast, dense rap phrases. The sidechain bell lifts the detection region around 2.4 kHz; bass and the highest highs receive clearly less attenuation.

If the beat starts to breathe between words, carefully lengthen MID REL from 150 to 200 ms.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | -10 | 5 | 100 |
| MID | 1 | 6 | 150 |
| HIGH | -7 | 4 | 100 |

- **AMOUNT:** 60 % · **THRESH:** -42 dB · **RANGE:** 18 dB.
- **XOVER:** LOW 170 Hz · HIGH 5200 Hz.
- **SC pre-EQ:** HPF 110 Hz · LPF 11000 Hz · BELL 2400 Hz / Q 1 / +3 dB.
- **LOOK:** 3 ms · **OUT:** 0 dB.

## Vocal Air Safe

**FACTORY slot 8 · FREIRAUM on:** bright pads, strings or guitar bus. **Sidechain:** lead vocal.

The voice gets room in the mids while the air of the backing signal is preserved as far as possible. LPF 6.5 kHz limits the influence of very high sidechain content; HIGH TRIM is set to −12 dB.

For strong sibilance, de-ess the vocal sidechain signal before it reaches FREIRAUM. The preset is not a de-esser for the main signal.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | -10 | 12 | 170 |
| MID | 0 | 16 | 240 |
| HIGH | -12 | 10 | 170 |

- **AMOUNT:** 38 % · **THRESH:** -45 dB · **RANGE:** 14 dB.
- **XOVER:** LOW 160 Hz · HIGH 4500 Hz.
- **SC pre-EQ:** HPF 140 Hz · LPF 6500 Hz · BELL 3000 Hz / Q 0.8 / +2 dB.
- **LOOK:** 2 ms · **OUT:** 0 dB.

## Lead Over Pads

**FACTORY slot 9 · FREIRAUM on:** pad, chord or texture bus. **Sidechain:** melodic lead synth.

Calm space for a melodic lead over broad chords. MID REL 240 ms lets the gap between closely played lead notes close more slowly.

For short, percussive leads, use Pluck Through Pad instead.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | -7 | 8 | 140 |
| MID | 0 | 10 | 240 |
| HIGH | -4 | 8 | 160 |

- **AMOUNT:** 55 % · **THRESH:** -44 dB · **RANGE:** 16 dB.
- **XOVER:** LOW 200 Hz · HIGH 4500 Hz.
- **SC pre-EQ:** HPF 180 Hz · LPF 9000 Hz · BELL 1800 Hz / Q 0.9 / +2 dB.
- **LOOK:** 3 ms · **OUT:** 0 dB.

## Kick Sub Tight

**FACTORY slot 10 · FREIRAUM on:** sub or bass track. **Sidechain:** short kick.

Fast space in the low end for short house or electro kicks. LOW REL 55 ms keeps the effect compact; the sidechain is limited to 1 kHz.

For long kick tails, raise LOW REL toward 90–130 ms or load Techno Kick Pocket.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | 0 | 0.5 | 55 |
| MID | -10 | 6 | 100 |
| HIGH | -12 | 4 | 70 |

- **AMOUNT:** 78 % · **THRESH:** -40 dB · **RANGE:** 18 dB.
- **XOVER:** LOW 150 Hz · HIGH 3800 Hz.
- **SC pre-EQ:** HPF 25 Hz · LPF 1000 Hz · BELL 100 Hz / Q 0.7 / +2 dB.
- **LOOK:** 4 ms · **OUT:** 0 dB.

## Techno Kick Pocket

**FACTORY slot 11 · FREIRAUM on:** bass, rumble or low synth bus. **Sidechain:** kick.

A more pronounced, longer-held space for the kick body. The LOW zone reaches up to 180 Hz; 135 ms LOW REL is a good starting value for a decaying kick.

Judge the rumble in context. Correct gaps that are too large with less AMOUNT first; there is no fixed tempo grid built in.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | 0 | 1 | 135 |
| MID | -8 | 6 | 180 |
| HIGH | -12 | 4 | 100 |

- **AMOUNT:** 85 % · **THRESH:** -42 dB · **RANGE:** 20 dB.
- **XOVER:** LOW 180 Hz · HIGH 3500 Hz.
- **SC pre-EQ:** HPF 25 Hz · LPF 1300 Hz · BELL 100 Hz / Q 0.7 / +2 dB.
- **LOOK:** 5 ms · **OUT:** 0 dB.

## Kick Into 808

**FACTORY slot 12 · FREIRAUM on:** 808 or very low bass track. **Sidechain:** kick.

Space for the deep part of the kick while the overtones of the 808 are less affected. LOW ends at 110 Hz; the sidechain bell stays neutral so the actual kick fundamental drives the detection.

Adapt XOVER LOW to the kick body, roughly 80–160 Hz. With a long 808, lengthen LOW REL carefully.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | 0 | 1 | 90 |
| MID | -12 | 8 | 140 |
| HIGH | -12 | 6 | 100 |

- **AMOUNT:** 68 % · **THRESH:** -42 dB · **RANGE:** 18 dB.
- **XOVER:** LOW 110 Hz · HIGH 3000 Hz.
- **SC pre-EQ:** HPF 25 Hz · LPF 1000 Hz · BELL 1000 Hz / Q 1 / +0 dB.
- **LOOK:** 4 ms · **OUT:** 0 dB.

## Fast DnB Bass

**FACTORY slot 13 · FREIRAUM on:** bass bus with fast notes. **Sidechain:** kick.

Short, fast ducking for dense drum-and-bass or breakbeat material. LOW REL 45 ms and MID REL 70 ms let the bass come back sooner.

If the bass flutters, lengthen LOW REL in small steps toward 70 ms. Very short times can modulate the low tone.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | 0 | 0.5 | 45 |
| MID | -7 | 4 | 70 |
| HIGH | -12 | 3 | 45 |

- **AMOUNT:** 70 % · **THRESH:** -40 dB · **RANGE:** 16 dB.
- **XOVER:** LOW 160 Hz · HIGH 3500 Hz.
- **SC pre-EQ:** HPF 30 Hz · LPF 1600 Hz · BELL 100 Hz / Q 0.8 / +2 dB.
- **LOOK:** 3 ms · **OUT:** 0 dB.

## Snare Body Space

**FACTORY slot 14 · FREIRAUM on:** synth, guitar or music bus. **Sidechain:** snare or clap.

Space for the body and presence of a snare or clap. The HPF holds back low sidechain content; the focus is on the MID zone.

For thin claps, move BELL FREQ from 1.5 kHz toward 2–4 kHz; for broad snare tails, lengthen MID REL.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | -10 | 4 | 80 |
| MID | 0 | 5 | 120 |
| HIGH | -6 | 3 | 70 |

- **AMOUNT:** 50 % · **THRESH:** -43 dB · **RANGE:** 14 dB.
- **XOVER:** LOW 180 Hz · HIGH 4500 Hz.
- **SC pre-EQ:** HPF 160 Hz · LPF 9000 Hz · BELL 1500 Hz / Q 0.9 / +3 dB.
- **LOOK:** 3 ms · **OUT:** 0 dB.

## Hats Air Slot

**FACTORY slot 15 · FREIRAUM on:** bright synth, noise or FX bus. **Sidechain:** hi-hats or shaker.

A short slot in the HIGH zone for bright rhythmic content. HIGH starts at 6.5 kHz, the bell emphasizes 9 kHz; LOW and MID receive strongly reduced attenuation.

Only load it if the hat delivers enough energy at the top. For dull hats, lower XOVER HIGH to about 4–5 kHz.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | -12 | 4 | 70 |
| MID | -10 | 6 | 80 |
| HIGH | 0 | 1 | 40 |

- **AMOUNT:** 42 % · **THRESH:** -48 dB · **RANGE:** 12 dB.
- **XOVER:** LOW 200 Hz · HIGH 6500 Hz.
- **SC pre-EQ:** HPF 500 Hz · LPF 18000 Hz · BELL 9000 Hz / Q 0.7 / +3 dB.
- **LOOK:** 2 ms · **OUT:** 0 dB.

## Acid Lead Pocket

**FACTORY slot 16 · FREIRAUM on:** chord, pad or competing synth bus. **Sidechain:** acid or resonant lead.

Space for the wandering, resonant mids of an acid lead. The MID zone reaches up to 6 kHz; the sidechain bell puts more weight on 3.2 kHz.

With harsh resonance peaks, reduce AMOUNT first. The preset follows the lead spectrum and does not replace a fixed notch EQ.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | -9 | 6 | 110 |
| MID | 0 | 7 | 170 |
| HIGH | -5 | 4 | 100 |

- **AMOUNT:** 58 % · **THRESH:** -43 dB · **RANGE:** 16 dB.
- **XOVER:** LOW 200 Hz · HIGH 6000 Hz.
- **SC pre-EQ:** HPF 180 Hz · LPF 12000 Hz · BELL 3200 Hz / Q 1 / +3 dB.
- **LOOK:** 3 ms · **OUT:** 0 dB.

## Reece Mid Space

**FACTORY slot 17 · FREIRAUM on:** reece, reese or mid-bass layer. **Sidechain:** lead or vocal.

Sorts out competition in a dense mid-bass layer. LOW TRIM −12 dB largely takes the sub range out of the processing; MID REL 200 ms smooths the curve.

With a separately routed sub, put FREIRAUM only on the mid-bass layer. A negative TRIM does not switch a zone off completely.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | -12 | 8 | 140 |
| MID | 0 | 12 | 200 |
| HIGH | -9 | 6 | 120 |

- **AMOUNT:** 48 % · **THRESH:** -44 dB · **RANGE:** 16 dB.
- **XOVER:** LOW 180 Hz · HIGH 5000 Hz.
- **SC pre-EQ:** HPF 140 Hz · LPF 8500 Hz · BELL 1000 Hz / Q 0.7 / +2 dB.
- **LOOK:** 2 ms · **OUT:** 0 dB.

## Pluck Through Pad

**FACTORY slot 18 · FREIRAUM on:** pad or chord bus. **Sidechain:** pluck, arp or short keys.

Short space for the attack of a pluck or arpeggio. Fast attack times and 4 ms LOOK add to the spectral ducking; MID REL 160 ms lets the pad sound return.

If the pad disappears with continuous sixteenth notes, lower AMOUNT or shorten MID REL to 100–130 ms.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | -9 | 3 | 90 |
| MID | 0 | 4 | 160 |
| HIGH | -4 | 2 | 80 |

- **AMOUNT:** 52 % · **THRESH:** -45 dB · **RANGE:** 14 dB.
- **XOVER:** LOW 200 Hz · HIGH 5000 Hz.
- **SC pre-EQ:** HPF 180 Hz · LPF 11000 Hz · BELL 2200 Hz / Q 0.8 / +2 dB.
- **LOOK:** 4 ms · **OUT:** 0 dB.

## Reverb Vocal Duck

**FACTORY slot 19 · FREIRAUM on:** reverb return, after the reverb. **Sidechain:** dry lead vocal.

The reverb gives way to the dry voice during a phrase. The longer MID release of 350 ms is meant to bring the reverb back more smoothly after the phrase ends.

Put FREIRAUM after the reverb. Take the sidechain from the dry voice so the reverb does not control itself.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | -6 | 8 | 200 |
| MID | 0 | 10 | 350 |
| HIGH | -3 | 6 | 220 |

- **AMOUNT:** 70 % · **THRESH:** -46 dB · **RANGE:** 20 dB.
- **XOVER:** LOW 180 Hz · HIGH 5000 Hz.
- **SC pre-EQ:** HPF 150 Hz · LPF 12000 Hz · BELL 2500 Hz / Q 0.8 / +2 dB.
- **LOOK:** 3 ms · **OUT:** 0 dB.

## Delay Lead Duck

**FACTORY slot 20 · FREIRAUM on:** delay return, after the delay. **Sidechain:** dry vocal or lead.

The repeats step back on new lead notes and come forward again between phrases. 280 ms MID REL is a starting value for the transition, not a synchronized note length.

Put it after the delay. For short slap echoes, shorten MID REL to about 120–180 ms.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | -8 | 5 | 170 |
| MID | 0 | 7 | 280 |
| HIGH | -5 | 4 | 180 |

- **AMOUNT:** 62 % · **THRESH:** -45 dB · **RANGE:** 18 dB.
- **XOVER:** LOW 180 Hz · HIGH 5000 Hz.
- **SC pre-EQ:** HPF 140 Hz · LPF 11000 Hz · BELL 2000 Hz / Q 0.9 / +2 dB.
- **LOOK:** 3 ms · **OUT:** 0 dB.

## Bus Gentle Space

**FACTORY slot 21 · FREIRAUM on:** music or background bus. **Sidechain:** vocal or important lead.

Very restrained space on the bus. Low AMOUNT, negative trims and slow attack times avoid an audible gap at the onset.

Not a classic bus compressor. Compare with the sidechain active in the full mix at the end; for more space, raise AMOUNT step by step.

| Zone | TRIM (dB) | ATK (ms) | REL (ms) |
|---|---:|---:|---:|
| LOW | -6 | 18 | 220 |
| MID | -2 | 32 | 420 |
| HIGH | -6 | 20 | 280 |

- **AMOUNT:** 24 % · **THRESH:** -46 dB · **RANGE:** 10 dB.
- **XOVER:** LOW 160 Hz · HIGH 4500 Hz.
- **SC pre-EQ:** HPF 120 Hz · LPF 14000 Hz · BELL 2000 Hz / Q 0.7 / +1 dB.
- **LOOK:** 0 ms · **OUT:** 0 dB.

## Existing projects and your own presets

The five existing factory presets remain unchanged: Vocal Carve, Kick Space, Gentle Glue, Hard Duck and Presence Gap. The 32 user slots are retained. An older project loads its own values and user slots without automatically adopting a new factory preset.

After exchanging files, reload the project or recompile the JSFX instance so that REAPER reads the expanded factory list again. Simply closing and reopening the interface is not enough. To save your own presets, use SAVE in the FREIRAUM bar. To transfer a bank, save a native REAPER preset or an FX chain.
