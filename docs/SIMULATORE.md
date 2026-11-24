# Simulatore X32

`packages/x32_sim` è un programma separato dall'applicazione. **Non è un mixer** e non va usato come prova di compatibilità hardware.

## Avvio

```powershell
cd packages\x32_sim   # dalla cartella principale del progetto
dart run x32_sim --port 10023 --model X32
```

Poi nell'app: Connessione → indirizzo `127.0.0.1` (oppure compare nella ricerca automatica).

Più semplice: nell'app, Connessione → **Prova senza mixer** avvia il simulatore integrato, senza aprire terminali.

Opzioni: `--model X32|M32|X32P…` (stringa restituita da `/xinfo`), `--init file.txt` (righe di nodo iniziali, per esempio un'esportazione dell'app).
Comandi da tastiera: `p` pausa (simula la perdita del mixer), `r` ripresa, `f` muove il fader del ch 1 "dalla superficie", `s` statistiche, `q` esci.

## Identificazione

* Ascolta **solo** su 127.0.0.1 e ignora pacchetti da altri indirizzi.
* `/xinfo` → `127.0.0.1`, `X32-SIMULATOR`, modello, `4.15-SIM`.
* Nell'app: badge "SIMULATORE" e fascia viola "SESSIONE SIMULATA".

## Comportamenti

| Funzione | Comportamento | Base |
|---|---|---|
| `/xinfo`, `/status` | risposte con 4 e 3 stringhe | H |
| `/xremote` | il client riceve le modifiche per 10 s | A/EXT |
| modifica di un parametro | applicata e inoltrata agli altri client, **non** al mittente | H |
| `/node` | risponde con la riga del nodo | H |
| sottoscrizioni | blob ogni `fattore × 50 ms`, scadenza 10 s senza `/renew` | H (ritmi osservati in T01b) |
| meter | segnali sintetici; i bus e le matrici seguono fader e mute; banco 0 nell'ordine [EXT] | **scelta del simulatore** |
| `/ ,s riga` | applica la riga, nessuna risposta | **scelta del simulatore** (hardware non verificato) |
| `/-stat/solosw/NN` dal client | aggiorna il solo | **scelta del simulatore** |
| `/save /load /copy /delete /rename` scene | gestite in memoria; il richiamo invia le modifiche a tutti i client | **scelta del simulatore** |
| `/showdump` | righe `/-show/showfile/show` e `scene/NNN` | formato H |
| pausa, perdita pacchetti (`dropRate`) | per i test di robustezza | — |
