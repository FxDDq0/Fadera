# Building Fadera from source

## Repository layout

| Folder | Content |
|---|---|
| `app/` | Flutter desktop application (`lib/` code, `test/` widget tests, `windows/` runner, `assets/`) |
| `packages/x32_core/` | Pure-Dart protocol engine: OSC, transport, mixer state, send queue, meters (`lib/`, `test/`, `tool/` hardware test tools) |
| `packages/x32_sim/` | Pure-Dart mixer simulator, used only by the automated tests and not shipped with the app (listens on 127.0.0.1 only) |
| `branding/` | Name, version and visual identity (`brand.json`), generated logo and icons (`out/`), templates |
| `installer/` | Inno Setup script for the Windows installer (generated from `branding/templates/installer.iss`) |
| `tools/` | `package.ps1` (portable package), `brand_apply.py` and `make_icon.py` (branding generator) |
| `docs/` | User and technical documentation, screenshots |
| `.github/workflows/` | Build, test, installer and release automation |

## Requirements

* Windows 10/11 x64
* Flutter SDK **3.50.1** (stable), which includes Dart 3.14
* Visual Studio 2022 with the *Desktop development with C++* workload
* Inno Setup 6 (only to build the installer)
* Python 3 with `numpy` (only to regenerate branding after editing `branding/brand.json`)

## Build

```powershell
# dependencies
cd packages\x32_core; dart pub get; cd ..\x32_sim; dart pub get; cd ..\..\app; flutter pub get; cd ..

# tests
cd packages\x32_core; dart test; cd ..\x32_sim; dart test; cd ..\..\app; flutter test; cd ..

# application
cd app; flutter build windows --release; cd ..

# portable package (dist\Fadera-<version>-windows-x64.zip) and installer (dist\Fadera-<version>-setup.exe)
powershell -File tools\package.ps1
& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" installer\Fadera.iss   # or the path of your Inno Setup install
```

The version comes from `branding/brand.json`. After changing it run `python -I tools/brand_apply.py`, which updates the app constants, the Windows version resource and the installer script.

## Running against the simulator

The simulator is a developer tool and is not part of the program. To try a development build without a mixer, start it from a terminal and connect to `127.0.0.1`:

```powershell
cd packages\x32_sim
dart run x32_sim --port 10023```

## Hardware test tools

`packages/x32_core/tool/` contains command-line tools used for hardware validation (`hw_session`, `hw_meters`, `hw_link`, `hw_write`, `hw_discover`). `hw_write` only writes to channels 31 and 32 and refuses any other path. Use them only on a mixer you are allowed to change, never during a live show.
