# Marchio Mixora

## Un solo punto di modifica

Tutto il marchio è in [`branding/brand.json`](../branding/brand.json): nome, nome dell'eseguibile, descrizione, produttore, copyright, versione e build, cartella dei dati, identificativo dell'app, identificativo dell'installer, palette, testo di compatibilità.

Dopo una modifica, dalla cartella principale del progetto:

```powershell
python -I tools\brand_apply.py
```

```powershell
cd app; Remove-Item build\windows -Recurse -Force; flutter build windows --release; cd ..
```

```powershell
powershell -File tools\package.ps1
```

## Cosa genera `tools/brand_apply.py`

| Destinazione | Contenuto |
|---|---|
| `branding/out/` | `simbolo.svg`, `logo_scuro.svg`, `logo_chiaro.svg`, `icona_256/512/1024.png`, `icona_chiara_512.png`, `Mixora.ico` |
| `app/windows/runner/resources/app_icon.ico` | icona dell'eseguibile, della finestra e della barra delle applicazioni (16–256 px) |
| `app/windows/CMakeLists.txt`, `runner/main.cpp`, `runner/Runner.rc` | nome dell'eseguibile, titolo della finestra, informazioni sulla versione |
| `app/pubspec.yaml` | versione e build |
| `app/lib/brand.g.dart` | costanti usate dall'app: nome, descrizione, versione, cartella dei dati, colori, compatibilità |
| `app/assets/brand/icona_256.png` | icona della schermata iniziale e delle informazioni |
| Android: `mipmap-*/ic_launcher.png`, `applicationId`, etichetta | icona e identità |
| iOS/iPadOS: `AppIcon.appiconset`, `CFBundleDisplayName`, bundle id | icona e identità |
| `installer/Mixora.iss` | installer (dal modello `branding/templates/installer.iss`) |
| `docs/GUIDA_UTENTE.md` | guida (dal modello `branding/templates/GUIDA_UTENTE.md`) |

`tools/package.ps1` legge nome e versione dallo stesso file: il pacchetto si chiama `<exeName>-<versione>-windows-x64`.

## Identità grafica

* Simbolo: un anello (la manopola) attraversato da una forma d'onda. Disegno originale: nessun elemento di Behringer, Midas o X32-Edit.
* Colori: fondo `#0E1117`, superficie `#1C212B`, primo piano `#E9ECF2`, segnale `#3E8EFA`, accento dell'interfaccia `#F2C230`.
* Versioni: logo scuro e chiaro (SVG, con il carattere Segoe UI o equivalente), icona scura per app e finestre, icona chiara per sfondi chiari.

## Indipendenza da X32-Edit

| Elemento | Mixora | X32-Edit |
|---|---|---|
| Eseguibile | `Mixora.exe` | `X32-Edit.exe` |
| Cartella di installazione | `C:\Program Files\Mixora` | propria |
| Preferenze, backup, log | `%APPDATA%\Mixora` | proprie |
| Identificativo dell'installer | `{8C1F4D52-6B3E-4A7D-9E21-5F0C7A3B9D46}` | proprio |
| Identificativo Android/iOS | `app.mixora.controller` | — |

Mixora non legge, non modifica e non sovrascrive file di X32-Edit. I due programmi possono essere installati e usati sullo stesso PC; collegati allo stesso mixer funzionano come due client distinti.

Alla prima esecuzione Mixora copia `prefs.json` dalla cartella della versione con il nome provvisorio (`%APPDATA%\X32Remote`), se esiste. La cartella vecchia non viene modificata.

## Dichiarazione

Compatibile con i mixer Behringer X32 e Midas M32. Mixora è un progetto indipendente: non è affiliato, approvato o sostenuto da Behringer, Midas o Music Tribe. I nomi X32 e M32 e i rispettivi marchi appartengono ai loro proprietari.

Nota: la disponibilità del nome "Mixora" come marchio non è stata verificata (EUIPO, domini, store).
