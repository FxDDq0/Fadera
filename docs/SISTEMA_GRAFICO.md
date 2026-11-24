# Sistema grafico di Fadera

Un solo punto per colori, misure e componenti: `app/lib/design/`.

## Token (`design/tokens.dart`)

| Classe | Contenuto |
|---|---|
| `MxTheme` | Tema completo: palette degli 8 colori del mixer (OFF RD GN YE BL MG CY WH), accento, selezione, scurimento delle intestazioni. Temi pronti: `studio` (predefinito), `live`, `minimal`, più `custom(palette)`. `MxTheme.current` è il tema attivo; `MxTheme.overrides` contiene i colori locali delle strip. |
| `AppColors` | Superfici (`bg`, `surface`, `surface2`, `surface3`, `well`), bordi, testo, stati (`mute`, `solo`, `ok`, `warn`, `error`, `sim`), meter, `series` (bande EQ e grafici); `stripColorFor(base, idx)`, `header(c)`, `onColor(c)`. |
| `Sp` | Spaziature 2 · 4 · 8 · 12 · 16 · 24. |
| `Rd` | Raggi 4 · 6 · 10. |
| `Sz` | Altezze dei controlli 24 · 28 · 32, barra superiore, barra rapida, strip (60–96 px), master, cursore del fader. |
| `Tx` | Stili di testo: `section`, `label`, `caption`, `body`, `strong`, `title`, `pageTitle`, `value` (cifre a spaziatura fissa). |
| `Shadows` | Ombre dei pannelli, del cursore, alone (`glow`). |

## Colori degli stati

| Stato | Colore |
|---|---|
| Selezione, controlli attivi | blu (accento del tema) |
| MUTE | rosso |
| SOLO | giallo |
| Connessione corretta | verde |
| Avviso, sincronizzazione in corso | arancio |
| Errore | rosa-rosso |
| Sessione simulata | viola |

I colori dei canali vengono dal tema e non sono mai usati per gli stati.

## Componenti (`design/components.dart`)

| Componente | Uso |
|---|---|
| `MxPanel` | Pannello con titolo di sezione, sottotitolo e azioni |
| `MxPageHeader` | Titolo di pagina o finestra con azioni |
| `MxSegmented` | Selettore a segmenti (gruppi di canali, canale A/B…) |
| `MxStateBadge` | Badge ON/OFF |
| `MxIconButton` | Pulsante con icona |
| `MxButton` | Pulsante: primario, secondario, pericoloso o leggero |
| `MxValueBox` | Riquadro di un valore numerico |
| `MxLabeled` | Etichetta sopra un controllo |
| `MxEmpty` | Stato vuoto |
| `MxSwatch` | Pallino di colore selezionabile |

I controlli del mixer sono in `ui/widgets/controls.dart` e usano gli stessi token:

| Controllo | Ruolo |
|---|---|
| `Fader` | Fader |
| `FaderScale` | Scala dB del fader, in una colonna propria |
| `LevelMeter` | Meter |
| `Knob` | Manopola |
| `ParamToggle` / `PillButton` | Pulsanti a due stati |
| `ParamDropdown` | Menu a tendina |

## Regole

* Nei widget nessun colore e nessuna misura scritti a mano: si usano i token.
* Meter, scala e fader non condividono mai la stessa colonna.
* Per cambiare l'aspetto di tutta l'app basta modificare i token o aggiungere un `MxTheme`.
* Il tema scelto è nelle preferenze (`colorTheme`, `customPalette`, `stripColorOverride`, `colorProfiles`) e si applica con `AppController.applyAppearance()`.
