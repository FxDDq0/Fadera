# Coda di invio verso il mixer

Codice: `packages/x32_core/lib/src/net/send_queue.dart` (classe `SendQueue`), usata da `X32Client` e dal simulatore.
Test: `packages/x32_core/test/send_queue_test.dart` (10), `packages/x32_sim/test/integration_test.dart` (trascinamenti ad alto carico), `soak_test.dart`.

## Perché serve

Su Windows `RawDatagramSocket.send` è non bloccante e restituisce 0 byte quando il sistema non può accettare il datagramma. Con la sola chiamata diretta il pacchetto si perdeva in silenzio (difetto trovato nella 0.1.0). La prima correzione era una coda FIFO **illimitata** con ritentativo, che però:
* inviava **tutti** i valori intermedi di un trascinamento, anche se ormai superati;
* poteva crescere senza limite;
* non distingueva i parametri continui dai comandi.

## Funzionamento attuale

```
modifica locale ──► enqueueLatest(chiave = percorso)  ─┐
keep-alive (/xremote, /renew) ─► enqueueLatest(chiave) ─┤
comandi (scene, solo, sync, /node, sottoscrizioni) ─► enqueueOrdered ─┤
                                                        ▼
                                  coda unica, in ordine di arrivo
                                                        │ flush()
                                                        ▼
                         Transport.trySend → sent | wouldBlock | error
```

| Regola | Come è garantita |
|---|---|
| **Mai un valore vecchio dopo uno nuovo** | al massimo una voce in attesa per parametro: un nuovo valore sostituisce quello in coda nella stessa posizione |
| **Coalescenza** | durante la congestione resta solo l'ultimo valore di ogni parametro (contatore `coalesced`) |
| **Ordine dei comandi** | `enqueueOrdered` non fonde e non scarta; i comandi partono nell'ordine di accodamento |
| **Barriere** | un parametro si fonde solo con una voce accodata *dopo* l'ultimo comando: con *fader=1, richiamo scena, fader=2* partono fader=1, la scena, fader=2. Senza barriera fader=2 partirebbe prima della scena e verrebbe cancellato |
| **Coda limitata** | parametri: una voce per percorso (al massimo qualche migliaio). Comandi: `maxOrdered` = 4096; oltre, `QueueFullException` e messaggio di errore nel log, mai uno scarto silenzioso |
| **Contropressione** | sync PC → Mixer e invio di file attendono `drained()` ogni 32 righe: la coda non cresce oltre ~32 voci |
| **Socket occupato** (`wouldBlock`) | la coda si ferma e riparte all'evento "scrivibile" del socket, con un controllo di sicurezza ogni 20 ms |
| **Errore del socket** (`error`, es. rete assente) | ritentativo ogni 50 ms fino a 20 volte, poi la voce viene scartata con un messaggio (errore per i comandi, avviso per i parametri) |
| **Perdita del mixer** (10 s senza dati) | la coda viene svuotata: nessun comando vecchio parte minuti dopo, alla ripresa. Lo stato viene segnato "non sincronizzato" |
| **Disconnessione** | `/unsubscribe` accodato e inviato, poi coda svuotata |

## Classificazione dei messaggi

| Messaggio | Classe |
|---|---|
| parametri da modifiche locali (`/ch/01/mix/fader`…) | ultimo valore, chiave = percorso |
| `/xremote`, `/renew <alias>` | ultimo valore (ripetitivi) |
| `/-stat/solosw/NN`, altri `/-…` espliciti | ordinato |
| `/save /load /copy /delete /rename /add /showdump` | ordinato |
| `/node`, `/ ,s riga` (sync e file) | ordinato |
| `/batchsubscribe`, `/formatsubscribe`, `/unsubscribe` | ordinato |
| `/status`, `/xinfo` | ordinato |

Simulatore: stessa coda per ogni client; i blob delle sottoscrizioni (meter, `hidden/*`) sono "ultimo valore", tutto il resto è ordinato.

## Misure

| Prova | Risultato |
|---|---|
| 40 raffiche da 1000 movimenti su 16 fader, con solo intercalati, 17 banchi meter attivi (simulatore) | valore finale nel simulatore = ultimo valore scelto per tutti i 16 fader; 0 scartati; 0 errori (2 esecuzioni su 2) |
| Stress con congestione casuale (100 000 modifiche, 1 tentativo su 3 rifiutato) | valore finale di ogni fader = ultimo scelto |
| Carico 60 s (soak) | 14 472 modifiche locali, 0 scartati, profondità massima 21 voci, 388 valori fusi, 0 errori |

Nota sul contatore `wouldBlock` (≈ 4 700 al secondo nel carico): su Windows il socket di Dart tiene in volo un solo invio alla volta (I/O sovrapposto) e risponde "occupato" finché il precedente non è completato. Il contatore misura questo comportamento del sistema; non indica perdite (0 scartati, coda sempre corta).

## Limiti noti

* La priorità è solo l'ordine di arrivo: un trascinamento continuo non può "superare" un comando già in coda (è voluto: preserva l'ordine).
* Il ritmo di invio non è limitato: se il mixer reale soffrisse raffiche molto fitte (X32-Edit invia fino a un messaggio ogni ~1,5 ms, verificato in T03c) servirebbe un limitatore. Da verificare su hardware.
