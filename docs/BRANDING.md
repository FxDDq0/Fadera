# Marchio Fadera

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
| `branding/out/` | `simbolo.svg`, `logo_scuro.svg`, `logo_chiaro.svg`, `icona_256/512/1024.png`, `icona_chiara_512.png`, `Fadera.ico` |
| `app/windows/runner/resources/app_icon.ico` | icona dell'eseguibile, della finestra e della barra delle applicazioni (16–256 px) |
| `app/windows/CMakeLists.txt`, `runner/main.cpp`, `runner/Runner.rc` | nome dell'eseguibile, titolo della finestra, informazioni sulla versione |
| `app/pubspec.yaml` | versione e build |
| `app/lib/brand.g.dart` | costanti usate dall'app: nome, descrizione, versione, cartella dei dati, colori, compatibilità |
| `app/assets/brand/icona_256.png` | icona della schermata iniziale e delle informazioni |
| Android: `mipmap-*/ic_launcher.png`, `applicationId`, etichetta | icona e identità |
| iOS/iPadOS: `AppIcon.appiconset`, `CFBundleDisplayName`, bundle id | icona e identità |
| `installer/Fadera.iss` | installer (dal modello `branding/templates/installer.iss`) |
| `docs/GUIDA_UTENTE.md` | guida (dal modello `branding/templates/GUIDA_UTENTE.md`) |

`tools/package.ps1` legge nome e versione dallo stesso file: il pacchetto si chiama `<exeName>-<versione>-windows-x64`.

## Identità grafica

* Simbolo: un anello (la manopola) attraversato da una forma d'onda. Disegno originale: nessun elemento di Behringer, Midas o X32-Edit.
* Colori: fondo `#0E1117`, superficie `#1C212B`, primo piano `#E9ECF2`, segnale `#3E8EFA`, accento dell'interfaccia `#F2C230`.
* Versioni: logo scuro e chiaro (SVG, con il carattere Segoe UI o equivalente), icona scura per app e finestre, icona chiara per sfondi chiari.

## Indipendenza da X32-Edit

| Elemento | Fadera | X32-Edit |
|---|---|---|
| Eseguibile | `Fadera.exe` | `X32-Edit.exe` |
| Cartella di installazione | `C:\Program Files\Fadera` | propria |
| Preferenze, backup, log | `%APPDATA%\Fadera` | proprie |
| Identificativo dell'installer | `{8C1F4D52-6B3E-4A7D-9E21-5F0C7A3B9D46}` | proprio |
| Identificativo Android/iOS | `app.fadera.controller` | — |

Fadera non legge, non modifica e non sovrascrive file di X32-Edit. I due programmi possono essere installati e usati sullo stesso PC; collegati allo stesso mixer funzionano come due client distinti.

Alla prima esecuzione Fadera copia `prefs.json` dalla cartella del nome precedente (`%APPDATA%\Mixora`, altrimenti `%APPDATA%\X32Remote`), se esiste. La cartella vecchia non viene modificata. L'installer usa lo stesso identificativo di Mixora: installato sopra una versione Mixora, la aggiorna.

## Dichiarazione

Pensato per i mixer della famiglia Behringer X32 / Midas M32; verificato su X32 Producer firmware 4.15. Fadera è un progetto indipendente: non è affiliato, approvato o sostenuto da Behringer, Midas o Music Tribe. I nomi X32 e M32 e i rispettivi marchi appartengono ai loro proprietari.

Nome scelto il 2026-11-24 al posto di "Mixora" (già usato da un'app audio per Windows). Verifica preliminare: nessun marchio attivo "Fadera" in TMview (UE, USA e altri registri), nessuna app audio con lo stesso nome; non è stata fatta una ricerca professionale di somiglianza né la verifica dei domini.
