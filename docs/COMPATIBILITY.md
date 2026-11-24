# Compatibility

Mixora talks to the mixer with the X32/M32 OSC remote protocol over UDP port 10023.
Only results obtained on real hardware are marked as verified.

## Verified hardware

| Mixer | Firmware | Network | Tested |
|---|---|---|---|
| Behringer X32 Producer | 4.15 | Ethernet (and Wi-Fi of the same router, reported by the tester) | 23 November 2026 |

## Function matrix (X32 Producer, firmware 4.15)

**Verified** = tested on the real mixer, value read back from the mixer and confirmed on the console.
**Simulator** = covered by the automated tests against the built-in simulator.
**Not verified** = implemented, but not yet tested on real hardware.

| Function | Status |
|---|---|
| Mixer discovery, connection, link status | Verified |
| Full read of the mixer state (2127 nodes) | Verified |
| Names, colours, icons (read and live updates from the console) | Verified |
| Fader, mute, pan changes made on the console, received live (no echo) | Verified |
| Fader (including fast drags), mute, solo, pan from the PC | Verified |
| Trim, phase, high-pass filter, delay from the PC | Verified |
| Gate and compressor from the PC | Verified |
| EQ from the PC | Verified |
| Sends to buses, DCA assignment from the PC | Verified |
| Channel name, icon and colour from the PC | Verified |
| Channel meters | Verified for channel 1; other channels follow the same layout |
| Gain reduction of gate and compressor (channels 1–32) | Verified for channel 1; other channels follow the same layout |
| Connection loss and automatic resume (cable unplugged) | Verified |
| Main LR meter, meter banks 7/8/12/13 | Not verified |
| Effects: type change and parameters | Simulator only |
| Scenes, snippets, cues (save, recall, rename) | Simulator only |
| Sending a show file / PC → mixer sync | Simulator only |
| Routing changes | Simulator only |
| Bus, matrix and main faders/mutes from the PC | Simulator only |
| Phantom power | Simulator only |

## Other models

Behringer X32 (Full, Compact, Rack, Core) and Midas M32 / M32R / M32C share the same protocol family, but they have **not been tested**.
Reports from users of these models are welcome: please open an issue with the diagnostics file.

## Mixers that are not supported

Mixers with a different protocol (for example Behringer Wing, X Air / XR series, Midas MR series) are not supported.
