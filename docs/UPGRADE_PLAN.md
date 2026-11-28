# Fadera v2: piano di aggiornamento

Branch: `upgrade/fadera-v2`. Un commit per ogni tappa; dopo ogni tappa compilazione, `flutter analyze` e tutti i test devono passare.

## Da dove partiamo (analisi del 27/11/2026)

Analisi fatta con gli agenti ECC: code-explorer, code-reviewer, security-reviewer, flutter-reviewer, silent-failure-hunter e performance-optimizer, più la misura della copertura dei test.

* **Architettura sana nel cuore.**
  * `x32_core` (codec OSC, coda di invio, stato del mixer) è ben separato dall'interfaccia.
  * I meter non passano mai da `notifyListeners`.
  * Ogni parametro ha il suo `ValueNotifier`.
* **Punti deboli.**
  * **Errori nascosti:**
    * la finestra di sincronizzazione non gestisce le eccezioni;
    * un `prefs.json` illeggibile viene azzerato e sovrascritto senza avviso;
    * i comandi delle scene non dicono se sono partiti.
  * **Rete:** accetta qualunque pacchetto dall'IP del mixer (anche da un'altra porta) e non limita i nodi sconosciuti.
  * **Ciclo di vita:** il client non viene mai rilasciato a ogni riconnessione; non c'è cattura globale degli errori.
  * **Prestazioni:**
    * i meter si ridisegnano a 60 Hz anche a mixer spento;
    * ogni disegno di meter crea gradienti e decine di rettangoli;
    * il grafico EQ ricalcola i coefficienti a ogni disegno.
  * **Struttura:** file molto grandi (`other_pages.dart` 1013 righe, `controls.dart` 951); logica dentro i callback dell'interfaccia.
* **Copertura dei test:** 62,5% delle righe scritte a mano (file generati esclusi).
  * Scoperti: `sync_dialog` (0%), `color_picker` (0%), `connect_dialog` (12%), `personalize_dialog` (19%).

## Regole che restano valide

* Nessun pacchetto OSC sperimentale verso il mixer reale, nessun reset, nessun aggiornamento firmware.
* Le modifiche al protocollo che cambiano cosa viene inviato al mixer (per esempio una sync a finestra) richiedono una prova su hardware: **non** fanno parte di questo aggiornamento.
* Le novità sono provate con test automatici e con il simulatore di test. Non sono presentate come verificate sul mixer reale.

## Stato

* 27/11/2026: fasi 1 (analisi) e 2 (piano) completate.
* 28/11/2026: fasi 3 e 4 completate. Tutte le tappe sono state eseguite. A ogni blocco è seguita una revisione ECC, con correzioni, poi `/ecc:review-pr` sull'intero branch.
  * Test: 98 app, 73 motore, 28 simulatore. Copertura 72 % (prima 62,5 %, misura senza i test del simulatore).
  * Misure:
    * costruzione dello stato del mixer 6,9 → 6,5 ms;
    * contrasto del testo secondario da 3,0 a 5,7:1.
  * Prove sulla build di rilascio senza mixer: ricerca canali (pulsante e Ctrl+F), esportazione e importazione delle impostazioni.
  * Nulla è stato provato sul mixer reale.

## Tappe

### 1. Sicurezza e bug critici

| # | Tappa | Tipo | Esito atteso |
|---|---|---|---|
| 1.1 | Finestra di sincronizzazione | bug | Le eccezioni vengono mostrate e la finestra non resta bloccata. PC → Mixer distingue riuscito, interrotto e fallito. A fine invio aspetta che la coda si svuoti e riporta i comandi scartati. |
| 1.2 | Preferenze illeggibili | bug | Il file guasto viene conservato come `prefs.json.corrupt-<data>`. Ogni campo è letto da solo, con i valori limitati a intervalli sensati. Avviso all'utente. Gli errori di salvataggio non sono più silenziosi. |
| 1.3 | Rete più robusta | sicurezza | Sono accettati solo i pacchetti dall'IP **e dalla porta** del mixer. Limiti su nodi sconosciuti, testi opachi, avvisi, profondità e numero di messaggi nei bundle. Testi di `/xinfo` ripuliti. |
| 1.4 | Invio di file di scena | sicurezza | Sono inviate solo le righe di nodi noti allo schema; `/-action` e i comandi fuori schema sono rifiutati. File oltre 1 MB rifiutati. Prima dell'invio un riepilogo (righe inviabili, scartate, alimentazione phantom). Dopo l'invio, inviate e attese a confronto. |
| 1.5 | Workflow GitHub | sicurezza | Nome del tag passato in variabile d'ambiente e controllato. `persist-credentials: false`. Azioni fissate a commit SHA. |

### 2. Stabilità e gestione degli errori

| # | Tappa | Tipo | Esito atteso |
|---|---|---|---|
| 2.1 | Cattura globale degli errori | funzione | `FlutterError.onError` e `PlatformDispatcher.onError` scrivono nel registro. In versione finale un riquadro neutro al posto della schermata rossa. |
| 2.2 | Ciclo di vita del collegamento | bug | `disconnect` rilascia il client (`dispose`). Connessioni sovrapposte serializzate. `dispose` del controller sicuro. Ricerca dei mixer che chiude sempre i socket. |
| 2.3 | Comandi e file con esito | bug | Scene, snippet e cue segnalano "Comando non inviato" se il mixer non è raggiungibile. Backup, esportazioni e ripristini mostrano un messaggio in caso di errore. |
| 2.4 | Registro su disco | bug | Riduzione dei messaggi ripetuti per i pacchetti non validi. File del registro limitato e pulizia dei file vecchi (30 giorni). |
| 2.5 | Annulla (Ctrl+Z) dopo sync e scene | bug | La cronologia di annullamento si svuota dopo sync Mixer → PC, richiamo di scena, caricamento di file, ripristino di un backup e connessione: Ctrl+Z non può più rimandare al mixer valori vecchi. |
| 2.6 | Cambio di effetto dal mixer | bug | Quando il tipo di effetto cambia dal mixer o da una scena, i parametri mostrati vengono aggiornati (rilettura di `/fx/N/par`, già usata dal cambio locale). |
| 2.7 | Client dopo la disconnessione | bug | Dopo la disconnessione o una connessione fallita nessun comando può partire. Le preferenze sono salvate anche alla chiusura della finestra. |
| 2.8 | Piccoli difetti dell'interfaccia | bug | Scorciatoie: un tasto assegnato a un'azione viene tolto dalle altre (anche dai predefiniti). Layout della barra rapida: niente nomi doppi o riservati. Trascinamento lento sulle caselle della barra rapida. Conferma dell'icona senza falsi positivi. Pavimento dei meter (`floorDb`) rispettato. |

### 3. Test

* Test di regressione per ogni bug delle tappe 1 e 2, scritti prima della correzione.
* Nuovi test per `sync_dialog`, preferenze, codec OSC (bundle annidati, limiti), filtro dei file di scena e controller (connessione e disconnessione con il simulatore di test).
* Obiettivo: superare il 70% di copertura senza toccare il mixer reale.

### 4. Struttura del codice (comportamento invariato)

* `other_pages.dart` diviso in `dca_page.dart`, `routing_page.dart` e `scenes_page.dart`, con il flusso "file di scena" spostato in un servizio testabile.
* `analysis_options.yaml` anche per `x32_core`; espressioni regolari dei percorsi caricate una volta sola.

### 5. Prestazioni

* Orologio dei meter: notifica solo quando c'è qualcosa da muovere (dati nuovi, caduta o picco in corso); fermo a mixer scollegato.
* Disegno dei meter: gradiente e pennelli in cache, segmenti in un unico tracciato.
* LED di segnale: ricostruito solo quando cambia stato.
* Nomi di scene, snippet e cue: una notifica raggruppata invece di una per riga.
* Grafico EQ e dinamiche: coefficienti calcolati una volta per banda, curve riusate per la somma, `shouldRepaint` reale.

### 6. Miglioramenti per l'utente

1. **Ricerca rapida dei canali (Ctrl+F):** scrivi un nome o un numero; Fadera apre la pagina giusta e seleziona la strip.
2. **Avvisi visibili:** gli errori e gli avvisi importanti compaiono in basso, senza aprire la diagnostica. Nella barra in alto un indicatore dice quante modifiche non sono partite mentre il mixer non rispondeva.
3. **Esporta e importa le impostazioni:** un file con aspetto, layout della barra rapida, layer Band, scorciatoie e preferenze, per portarle su un altro PC o tenerne una copia.
4. **Più leggibile e accessibile:** contrasto del testo secondario conforme a WCAG AA; fader, manopole e strip leggibili dagli screen reader e utilizzabili da tastiera.

## Fuori da questo aggiornamento

* Sync Mixer → PC a finestra (più veloce): cambia il traffico verso il mixer, va provata su hardware.
* Fase C su hardware (effetti, scene, routing, bus/matrix/main) e phantom: serve un'autorizzazione separata.
* Firma digitale dell'installer: serve un certificato reale.

## Verifica finale

* `/ecc:review-pr` su tutto il branch e correzione dei problemi trovati.
* Build di rilascio, avvio dell'app installata, controllo delle novità senza collegarsi al mixer.
* README e CHANGELOG aggiornati, push del branch e Pull Request (senza merge).
