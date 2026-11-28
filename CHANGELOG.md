# Changelog

All notable changes to Fadera are listed here. Dates are in YYYY-MM-DD format.

## Unreleased

Upgrade "Fadera v2": see [docs/UPGRADE_PLAN.md](docs/UPGRADE_PLAN.md). Nothing in this release has been tested on a real mixer yet; the protocol traffic is unchanged except where noted.

### Added

* Quick channel search with **Ctrl+F** (or the search button in the top bar).
* Notices when the mixer stops responding and when it responds again, and a counter of changes that did not reach the mixer.
* Export and import of the settings (*Settings → General → Impostazioni su file*).
* Screen-reader labels for faders, knobs and strips; WCAG AA contrast for secondary text.

### Fixed

* The sync window could stay stuck with no way out when the connection dropped; PC → Mixer now reports complete, stopped or failed.
* A damaged `prefs.json` silently reset every setting and was overwritten; now each value is read on its own and the file is kept as `prefs.json.corrupt-<time>`.
* Ctrl+Z after a scene recall or a sync could send old values back to the mixer.
* Scene, snippet and cue commands now say when they could not be sent.
* Disconnecting during a connection, or reconnecting, no longer leaves a hidden client running.
* An effect type changed on the mixer now refreshes its parameters on the PC.
* Shortcut conflicts, duplicate quick-bar layout names, slow drags on the quick bar, icon confirmation, meter floor.
* The log on disk is limited in size and old logs are deleted.

### Security

* Only packets from the mixer's address **and** port are accepted; OSC bundles and unknown nodes are limited.
* Scene files send only known mixer nodes (never `/-action`, `/-prefs`, `/-stat`); the confirmation warns about phantom power lines.
* GitHub Actions pinned to commit SHAs; the tag name is validated and no longer interpolated into scripts.

### Performance

* Meters stop redrawing when no meter data arrives; meter, signal LED and EQ graph drawing are cheaper.

### Removed

* The built-in simulator is no longer part of the program: the *Try with the simulator* / *Try without a mixer* buttons are gone and the package no longer contains `simulatore\x32_sim.exe`. The simulator remains in the source tree only for the automated tests.

## 1.0.0 — 2026-11-24

First public release for Windows x64. Some advanced features are not yet verified on hardware: see [Known limitations](docs/KNOWN_LIMITATIONS.md).

### Features

* Mixer view with 8 or 16 channel strips per page (switch in the top bar or in *Personalizzazione → Interfaccia*), Aux/FX returns, buses, matrices, main, DCA and a user-defined layer.
* Channel editor: gain/trim, phase, high-pass filter, delay, gate and compressor with live gain reduction (channels 1–32), parametric EQ with graph, sends.
* Channel meters with configurable ballistics.
* Effects rack with graphical editors; routing overview (editing locked by default); scenes, snippets and cues.
* Quick controls bar, keyboard shortcuts, colour themes, touch mode, profiles.
* Discovery on every network adapter, manual IP address, clear explanations when the mixer is not found.
* First-run welcome screen and built-in simulator to try Fadera without a mixer.
* Interface in six languages: English, Italian, Spanish, French, German, Portuguese. "Automatic" follows the Windows language; the choice is in *Settings → General* and on the welcome screen, and applies immediately.
* Diagnostics view with export; license page for the bundled components.
* Windows installer (per-user by default, no administrator rights needed) and portable ZIP.

### Hardware validation

Verified on a Behringer X32 Producer with firmware 4.15: see [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md).

### Fixes found during hardware validation

* After a connection loss, the session restart (`/xremote`, `/formatsubscribe`, meter subscriptions) was discarded because the link was still marked as lost: live updates and meters could stay stopped. Fixed, with a regression test.
* Meter subscription renewals are no longer attempted while the mixer is unreachable.
