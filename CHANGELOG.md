# Changelog

All notable changes to Mixora are listed here. Dates are in YYYY-MM-DD format.

## Unreleased

## 1.0.0 — 2026-11-24

First public release for Windows x64. Some advanced features are not yet verified on hardware: see [Known limitations](docs/KNOWN_LIMITATIONS.md).

### Features

* Mixer view with 8 or 16 channel strips per page (switch in the top bar or in *Personalizzazione → Interfaccia*), Aux/FX returns, buses, matrices, main, DCA and a user-defined layer.
* Channel editor: gain/trim, phase, high-pass filter, delay, gate and compressor with live gain reduction (channels 1–32), parametric EQ with graph, sends.
* Channel meters with configurable ballistics.
* Effects rack with graphical editors; routing overview (editing locked by default); scenes, snippets and cues.
* Quick controls bar, keyboard shortcuts, colour themes, touch mode, profiles.
* Discovery on every network adapter, manual IP address, clear explanations when the mixer is not found.
* First-run welcome screen and built-in simulator to try Mixora without a mixer.
* Interface in six languages: English, Italian, Spanish, French, German, Portuguese. "Automatic" follows the Windows language; the choice is in *Settings → General* and on the welcome screen, and applies immediately.
* Diagnostics view with export; license page for the bundled components.
* Windows installer (per-user by default, no administrator rights needed) and portable ZIP.

### Hardware validation

Verified on a Behringer X32 Producer with firmware 4.15: see [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md).

### Fixes found during hardware validation

* After a connection loss, the session restart (`/xremote`, `/formatsubscribe`, meter subscriptions) was discarded because the link was still marked as lost: live updates and meters could stay stopped. Fixed, with a regression test.
* Meter subscription renewals are no longer attempted while the mixer is unreachable.
