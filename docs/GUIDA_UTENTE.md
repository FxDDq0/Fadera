# Fadera: guida rapida

Controller professionale per mixer digitali. Versione 1.0.0.

> Pensato per i mixer della famiglia Behringer X32 / Midas M32 (protocollo OSC); verificato solo su Behringer X32 Producer con firmware 4.15. Fadera è un progetto indipendente: non è affiliato, approvato o sostenuto da Behringer, Midas o Music Tribe. I nomi X32 e M32 e i rispettivi marchi appartengono ai loro proprietari.

> Le funzioni non ancora provate su un mixer reale sono indicate in "Limiti attuali": leggili prima di usare Fadera in uno spettacolo.

## Avvio

1. Estrai la cartella `Fadera-1.0.0-windows-x64` dove vuoi (non serve installazione).
2. Avvia `Fadera.exe`.
3. Clicca sull'indicatore in alto a sinistra ("Non connesso"): la finestra cerca i mixer su ogni rete del PC (cavo e Wi-Fi). Scegli il mixer oppure scrivi l'indirizzo (es. `192.168.1.2`) e premi **Connetti**.
   * **Via Wi-Fi** il PC deve essere sulla **stessa rete del mixer** (il Wi-Fi del router a cui è collegato il mixer). L'hotspot del telefono è un'altra rete e da lì il mixer non si trova. Internet non serve: se Windows segnala "Nessuna connessione Internet" va bene lo stesso.
   * Se non trova nulla, sotto "Nessun mixer ha risposto" la finestra spiega il motivo (per esempio "il PC è su un'altra rete").
4. Scegli la sincronizzazione:
   * **Mixer → PC** (consigliata): l'app legge tutti i 2127 parametri del mixer (circa 15 s). Il mixer non viene modificato.
   * **PC → Mixer**: sostituisce i parametri del mixer con quelli dell'app. Chiede una seconda conferma e salva prima un backup.

L'indicatore diventa verde quando sei connesso e sincronizzato, arancione se connesso ma non sincronizzato, rosso se il mixer non risponde (l'app riprova da sola).

## Uso

| Cosa | Come |
|---|---|
| Cambiare pagina | barra in alto: pagine dei canali (Ch 1–8 … 25–32, oppure Ch 1–16 e 17–32), Aux·FX, Bus, Matrix·Main, ★ Utente; poi DCA, Effetti, Scene e Routing |
| 8 o 16 fader per pagina | Personalizzazione → Interfaccia e meter → Pagine dei canali |
| Riduzione di guadagno (GR) | negli editor Gate e Comp, accanto al grafico: valore reale letto dal mixer per i canali 1–32 |
| Muovere un fader | trascina; **Maiusc** per la regolazione fine; doppio clic = 0 dB; frecce ↑↓ con il fader selezionato |
| Mute / Solo | pulsanti sotto ogni fader |
| Selezionare una strip | clic sulla strip: il pannello a destra mostra Canale, EQ e Mandate |
| EQ | trascina i punti numerati nel grafico (frequenza e gain) oppure usa le manopole |
| Nome e colore | nel pannello laterale: scrivi il nome e premi Invio; clic su un colore |
| Icona | clic sull'icona nel pannello laterale (salvata solo sul PC) |
| Fader sulle mandate | menu "Fader: …" in alto: i fader controllano le mandate verso il bus scelto |
| Vista Band | layer personale: aggiungi le strip che usi di più |
| Barra rapida | 12 caselle in basso: "+ Assegna" aggiunge un parametro (oppure ⚡ Assegna in alto e clic su una strip); trascina per riordinare; clic destro per nome e colore; ✕ per togliere; layout dall'icona a sinistra o da 🎨 Personalizzazione |
| Personalizzazione | 🎨 in alto: strip del layer Band, layout della barra rapida (nuovo, rinomina, duplica, elimina) |
| Finestre strette | sotto i 1150 px il pannello del canale diventa una linguetta a destra delle strip: toccala per aprirlo |
| Routing | pagina Routing: premi **Sblocca** prima di modificare |
| Scene, snippet, cue | pagina Scene (tre schede): elenco, salva, richiama con conferma, rinomina, copia, elimina; esporta lo stato in un file; l'invio di un file manda tutte le righe; l'**ambito di richiamo** (invio parziale) è sperimentale e va attivato in ⚙ → Generale |
| Link stereo | icona a catena sulle strip in coppia (si aggiorna con la sync) |
| Diagnostica | ⚙ → Diagnostica: contatori e log |
| Cercare un canale | **Ctrl+F** o la lente in alto: scrivi un nome ("Kick") o una sigla ("12", "bus 3", "dca 2") e premi Invio |
| Avvisi | in basso compaiono i messaggi importanti (mixer che non risponde, invii non riusciti); in alto "N non inviate" conta le modifiche che non sono arrivate al mixer mentre non rispondeva: rifai la sync Mixer → PC |
| Impostazioni su file | ⚙ → Generale → Impostazioni su file: **Esporta** salva aspetto, layout, scorciatoie e preferenze; **Importa…** le applica (anche su un altro PC, copiando il file nella cartella `impostazioni`) |

Scorciatoie predefinite (modificabili in ⚙ → Tastiera): **Ctrl+F** cerca un canale · **1–7** layer · **F5–F9** Mixer, DCA, Effetti, Routing, Scene · **← →** strip precedente/successiva · **↑ ↓** fader della strip selezionata (Maiusc: passi da 10) · **M** mute · **S** solo · **Ctrl+Z** annulla l'ultima modifica fatta nell'app.

Le manopole e i fader **non** reagiscono alla rotella del mouse, per evitare modifiche accidentali.

## Dati sul PC

`%APPDATA%\Fadera`: `prefs.json` (preferenze), `backup\` (backup automatici prima delle operazioni distruttive), `logs\` (un file al giorno), `scene\` (file esportati).

## Limiti attuali

* Il meter del **Main LR** è spento: la sua posizione nei dati del mixer non è ancora verificata.
* I meter delle strip usano un ordine tratto da documentazione esterna, da confermare sul mixer reale.
* Il pulsante **SOLO** dal PC, la sync **PC → Mixer**, il salvataggio e il richiamo delle scene non sono ancora stati provati su un mixer reale.
* Non disponibili: MIDI, recall safe, attivazione dei mute group, link stereo.
