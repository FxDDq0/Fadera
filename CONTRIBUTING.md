# Contributing to Fadera

Thank you for your interest. Bug reports, compatibility reports and pull requests are welcome.

## Compatibility reports

Reports from mixers other than the X32 Producer 4.15 are especially useful. Please include the mixer model, the firmware version, what worked and what did not, and the diagnostics file exported from *Settings → Diagnostica* (check it first: it contains your mixer's IP address and channel names).

## Ground rules

* **Nothing invented.** Every OSC address, parameter range or behaviour must come from the protocol documentation or from a test on real hardware. Unknown data stays unknown (opaque) rather than guessed.
* **Safety first.** Connecting must never write to the mixer. Commands must not be replayed after a connection loss. Features that can disturb a live show (routing, scenes, phantom power) stay behind an explicit confirmation.
* **Claims match evidence.** A feature is listed as verified in `docs/COMPATIBILITY.md` only with a hardware test that can be repeated.
* **No third-party resources.** Do not add code, graphics or files from Behringer, Midas, Music Tribe or X32-Edit.

## Development

See [docs/BUILDING.md](docs/BUILDING.md). Before opening a pull request:

```powershell
cd packages\x32_core; dart test; cd ..\x32_sim; dart test; cd ..\..\app; flutter analyze; flutter test
```

All tests run against the simulator on 127.0.0.1; they never send packets to a real mixer.

## License of contributions

Fadera is licensed under GPL-3.0-or-later. By submitting a pull request you agree that your contribution is licensed under the same terms.

## Pull requests

* One topic per pull request, with a short description of what changes and how it was tested.
* Add or update tests for behaviour changes.
* Update `CHANGELOG.md` under *Unreleased*.
