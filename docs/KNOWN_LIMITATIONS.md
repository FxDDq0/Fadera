# Known limitations

* **Platform:** only Windows 10/11 x64 is released. The code is written in Flutter, but Android, iPadOS, macOS and Linux builds are not provided or tested.
* **Hardware coverage:** only the Behringer X32 Producer with firmware 4.15 has been tested. See [COMPATIBILITY.md](COMPATIBILITY.md).
* **Not yet verified on hardware:** effect type/parameter changes, scene/snippet/cue operations, sending a show file to the mixer, routing changes, bus/matrix/main control from the PC, phantom power, the Main LR meter.
* **Languages:** the interface is available in English, Italian, Spanish, French, German and Portuguese. The user guide shipped with the program is in Italian; the online documentation is in English.
* **Not implemented:** MIDI control, mute group activation, editing channel links, automatic updates.
* **Read-only in Fadera:** the user routing is shown but cannot be edited; stereo links are shown but cannot be changed.
* **Names are ASCII only:** the mixer protocol carries plain ASCII text, so scene names, notes and scene-file lines with accented letters cannot be sent (Fadera refuses or filters them instead of losing them silently).
* **Changes made while the mixer is unreachable are discarded on purpose** (they are never replayed later). After a reconnection, run a new sync to be sure the view matches the mixer.
* **Fader display after a sync** can differ by one step from the mixer's internal value (the protocol's text format has 0.1 dB resolution); later changes are exact.
* **Unsigned installer:** Windows SmartScreen may warn on first run. See [CODE_SIGNING.md](CODE_SIGNING.md).
* **Silent installation** (`/VERYSILENT`) needs `/CURRENTUSER` or `/ALLUSERS`, otherwise the installer stops at the "install for" choice.
