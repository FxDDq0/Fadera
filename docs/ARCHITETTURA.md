# Architettura

```
X32Remote/
├─ packages/x32_core/     motore indipendente dalla GUI (Dart puro)
│  ├─ osc/                codifica/decodifica OSC 1.0, bundle in ingresso
│  ├─ schema/             tipi di parametro, conversioni, schema dei nodi X32
│  ├─ fx/                 61 tipi di effetto (generato dall'Appendice C)
│  ├─ state/              MixerState (stato centrale), righe di nodo, valori iniziali
│  ├─ meters/             decodifica dei blob meter, dinamica di visualizzazione
│  ├─ net/                Transport (UDP/memoria) e X32Client (sessione)
│  └─ generated/          tabella dei 2127 nodi di sync, tabelle FX (tools/gen_data.py)
├─ packages/x32_sim/      simulatore X32 su 127.0.0.1 (programma separato)
├─ app/                   applicazione Flutter
│  ├─ controller/         AppController, ParamHub, MeterHub, preferenze
│  └─ ui/                 barra superiore, strip, fader, meter, pannello, pagine
├─ tools/gen_data.py      genera i dati statici dalle evidenze del reverse engineering
└─ docs/                  documentazione tecnica
```

## 1. Flusso dei dati

```
 GUI (widget)                     controller                         motore                          rete
 ───────────                      ──────────                         ──────                          ────
 Fader trascinato ──setIdx──────▶ AppController ──setIdx(local)────▶ MixerState ──changes(local)──▶ X32Client ──UDP──▶ mixer
                                                                         │
 ValueListenable ◀── ParamHub ◀──────── changes (tutte le origini) ──────┘
                                                                         ▲
 mixer ──UDP──▶ X32Client ──applyOsc(remote)─────────────────────────────┘   (mai reinviato)
 mixer ──blob meters/N──▶ X32Client ──MeterFrame──▶ MeterHub ◀── lettura a ogni frame (Ticker 60 Hz)
```

* La GUI **non** conosce il socket: parla solo con `AppController`, che usa `MixerState` e `X32Client`.
* **Anti-eco**: ogni modifica porta una `ChangeOrigin` (`local`, `remote`, `sync`, `load`). `X32Client` invia solo le `local`. Il comportamento del mixer (non rimanda la modifica al mittente) è verificato su hardware (T03c).
* **Nessun salto del fader**: durante il trascinamento il fader mostra il valore locale e ignora i valori in arrivo per quel percorso.
* **Meter**: la rete scrive in un buffer (`MeterHub.stripDb`); i painter leggono a ogni frame e applicano caduta e picco in base al tempo (`MeterBallistics`). Nessuna ricostruzione di widget per pacchetto.

## 2. Moduli richiesti → implementazione

| Modulo | Dove | Stato |
|---|---|---|
| Communication Engine | `x32_core/net/x32_client.dart`, `transport.dart` | ✔ |
| OSC Protocol | `x32_core/osc/osc.dart` | ✔ |
| Mixer State | `x32_core/state/mixer_state.dart` | ✔ |
| Parameter System | `x32_core/schema/param.dart`, `x32_schema.dart` | ✔ |
| Channel / Bus / DCA Manager | `StripRef` + schema + `AppController.stripsFor` | ✔ (logica unica per tutti i tipi di strip) |
| Effects Manager | `x32_core/fx`, `MixerState.resetFxParams`, `app/ui/pages/other_pages.dart` | ✔ base |
| Routing Manager | schema `/config/routing/*`, `/outputs/*`; pagina Routing | ✔ base |
| Scene Manager | `X32Client.dataset*`, `sendNodeLines`; pagina Scene | ✔ base |
| Meter Engine | `x32_core/meters/meters.dart`, `MeterHub` | ✔ (mappa banco 0 da verificare) |
| MIDI Manager | — | ✘ non iniziato (doc 27 disponibile) |
| UI Components | `app/ui/widgets/controls.dart` | ✔ |
| User Preferences / Layout Manager | `app/controller/prefs.dart` | ✔ |
| Logging System | `X32Client.log` → `AppController` → file giornaliero | ✔ |

## 3. Schema dei parametri

Ogni nodo X32 (`/ch/01/mix`) ha un elenco ordinato di campi (`on fader st pan mono mlevel`). Il percorso OSC di un parametro è `nodo/campo`. Lo stato memorizza solo **indici interi**; il valore fisico, il float OSC (`idx/N`) e il testo della riga si ricavano dall'indice con le formule documentate.

* I nodi senza schema documentato (preferenze, talkback, link, user control…) sono **opachi**: il testo viene conservato e reinviato intatto, ma non diventa un parametro modificabile. Così nessun indirizzo viene inventato e la sync non perde informazioni.
* Lo schema è verificato contro le 2130 righe reali della X32P (test `hardware_fixture_test.dart`).

## 4. Sessione con il mixer

| Fase | Messaggi | Fonte |
|---|---|---|
| Discovery | `"/xinfo\0\0"` in broadcast; risposta `,ssss` (IP, nome, modello, firmware) | verificato T01b |
| Connessione | `/status` → `,sss`; `/xinfo` diretto per l'identità | verificato T01b |
| Sottoscrizioni | `/formatsubscribe hidden/prefs` (15), `hidden/states` (22), `hidden/solo`; `/batchsubscribe meters/N … 0 0 1` | verificato T01b |
| Keep-alive | `/xremote` e `/renew` ogni 2 s; meter ri-sottoscritti ogni 10 s | verificato T01b |
| Perdita | nessun dato per 10 s → `lost`, nuovi `/status` ogni 2 s, ripresa automatica | statico (soglia) + simulatore |
| Sync Mixer → PC | 2127 × `/node`, stop-and-wait, ritrasmissione a 500 ms (max 20) | verificato T01b |
| Sync PC → Mixer | 2127 × `/ ,s riga`, pausa 1 ms ogni 4 righe, conferma e backup obbligatori | **non verificato** su hardware |

Scelte deliberate:
* non si inviano `/-stat/keysolo 0` e `/-stat/osc/on 0` alla connessione (X32-Edit lo fa, effetto non chiarito);
* durante la sync non si reinvia nulla (X32-Edit reinvia 15 parametri: incongruenza T01b).

## 5. Sicurezza verso mixer reali

* `TransportPolicy.loopbackOnly` usata da tutti i test e dal simulatore: un invio verso un indirizzo non di loopback lancia un'eccezione.
* Il simulatore si lega solo a 127.0.0.1, si chiama `X32-SIMULATOR` e la GUI mostra una fascia viola permanente.
* Operazioni distruttive (PC → Mixer, richiamo scena, invio di file, cambio effetto, eliminazione scena) chiedono conferma; le prime tre salvano prima un backup locale (`%APPDATA%\X32Remote\backup`).
* Il routing è bloccato per impostazione predefinita (pulsante "Sblocca").

## 6. Estendibilità (verifica del consolidamento 0.2.0)

Controlli eseguiti sul codice:
* `packages/x32_core` non importa Flutter; `dart:io` compare solo in `net/transport.dart` e `net/x32_client.dart`.
* `app/` usa solo l'API pubblica del motore (`package:x32_core/x32_core.dart`), mai file interni `src/`.
* Nessun widget apre socket: l'unico punto è `AppController.connect/discover`.

Come si aggiunge una funzione senza toccare il motore OSC:

| Funzione futura | Dove si innesta | Cosa NON va cambiato |
|---|---|---|
| Nuovo parametro documentato | una voce in `x32_schema.dart` (`nodeSpecFor`) + test sulla riga reale | codifica, coda, client |
| Nuovo tipo di effetto o editor | `fx_visuals.dart` (grafica) o tabelle generate | stato e invio (i parametri FX esistono già) |
| MIDI | nuova classe nel controller che chiama `MixerState.setIdx` (origine `local`) | il client invia già tutte le modifiche locali |
| Librerie locali | lettura/scrittura delle righe di nodo (`NodeValue.toLine`, `applyNodeLine`) + `X32Client.sendNodeLines` | formato e trasporto |
| Finestra meter/RTA | lettura di `MeterFrame` da `X32Client.meters` | decodifica (già completa per tutti i banchi) |
| Nuovo comando `/-…` verificato | metodo che chiama `sendExplicit` (comando ordinato) | coda e anti-eco |
| Nuovo trasporto (es. test, TCP) | implementare `Transport` | client e coda |
| Nuove pagine | un valore di `AppPage` + widget; voce nel menu "+" | controller e motore |

Regole per non compromettere ciò che funziona: ogni schema nuovo deve passare il test della fixture reale (righe riscritte identiche); ogni comando nuovo è "ordinato" e rifiutato durante la perdita del mixer; nessuna funzione della GUI scrive direttamente sul trasporto.
