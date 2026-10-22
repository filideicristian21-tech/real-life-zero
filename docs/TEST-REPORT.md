# REAL LIFE: ZERO - Report dei test

Build attuale: v0.3.0 (Godot 4.7.2-stable, renderer Compatibility). Ultima esecuzione: 17 ott 2026, sul box Linux (headless).
Comando: `bash tests/run_tests.sh` (due processi Godot separati: il secondo riapre il salvataggio del primo).
Output grezzo: `tests/results.json`, log completo `tests/test_log.txt`, errori filtrati `tests/errors.txt` (vuoto: 0 errori di script/motore nel log).

**Legenda.** ESEGUITO = test automatico che è stato davvero lanciato, con il risultato qui sotto. PIANIFICATO = non eseguito, nessun risultato dichiarato.
Ciò che i test automatici NON possono provare: il tocco con le dita su un telefono vero, gli FPS su un Android vero e l'avvio dell'APK su un dispositivo. Questi punti restano PIANIFICATI.

Nota sull'elenco: i 12 titoli T01-T12 sono quelli del brief originale dell'utente (sezione 13 del messaggio, quella dei test obbligatori). `docs/BRIEF-utente.md` è un riassunto e non li ripete. Il piano di Hook (20 casi, colonna "Mappa Hook") è mappato sotto.

## v0.3.0 (17 ott 2026) - riepilogo
Build: v0.3.0 (Godot 4.7.2-stable, Compatibility). Comando: `bash tests/run_tests.sh`.
**Risultato: 59 + 1 test automatici ESEGUITI (T10b nel secondo processo), 0 falliti, 0 errori di script/motore nel log** (`tests/errors.txt` vuoto).
- 32 test di regressione v0.1/v0.2 (T01-T12, BAL, X01-X17, T10a) + T10b.
- 27 test nuovi v0.3 in `tests/v03_tests.gd`: casi di Hook v0.3, i 6 test di bilanciamento di Ledger (portati da Python a GDScript), le regole di Guard sui testi.
- Piano di Hook v0.3: 38 casi. **31 ESEGUITI** (anche parziali/adattati, spiegati sotto), gli altri PIANIFICATI (manuali, su telefono) o NON PREVISTI dalla v0.3.
- Un bug vero trovato dai test nuovi e corretto: nell'app Banca la lista «In arrivo (7 giorni)» leggeva chiavi sbagliate (errore di script, righe vuote).

### Piano di Hook v0.3 (38 casi): mappa e stato
| # | Caso Hook v0.3 | Stato | Test / note |
|---|---|---|---|
| B1 | App Banca | ESEGUITO | V-B1/J6/X4 (saldo e «In arrivo» coincidono con il gioco; il test ha trovato un bug vero nelle righe «In arrivo», corretto) |
| B2 | Versa e preleva | ESEGUITO | V-B2/B3/B5 |
| B3 | Oltre il saldo / oltre i contanti | ESEGUITO | V-B2/B3/B5 |
| B4 | Doppio tocco su Conferma | PIANIFICATO (manuale) | nella banca non c'è una conferma in due passi; il doppio tap vero sullo schermo non è simulabile qui. Il doppio acquisto nei negozi è coperto da T05 |
| B5 | Importi limite | ESEGUITO | V-B2/B3/B5 (0, negativo, enorme rifiutati; centesimi interi) |
| B6 | Stipendio sul conto | ESEGUITO | V-J1 (paga una volta, voce giusta), T06 |
| B7 | Interessi e canone in un mese, save/load | ESEGUITO | V-B7, LEDGER-3 |
| L1 | Scadenza bolletta | ESEGUITO | V-L1/L2/L6 |
| L2 | Pagamento anticipato | ESEGUITO (adattato) | V-L1/L2/L6: nella v0.3 le bollette si addebitano a fine mese; gli arretrati si pagano dal telefono senza secondo addebito (V-L3/L4) |
| L3 | Bolletta non pagata | ESEGUITO | V-L3/L4 (mora una volta) |
| L4 | Distacco luce e ritorno | ESEGUITO (logica) | V-L3/L4, V-L4b. L'effetto visivo in casa è PIANIFICATO (manuale) |
| L5 | Consumo legato all'uso | NON PREVISTO | le bollette v0.3 sono a importo fisso per casa (dati di Ledger): niente da testare |
| L6 | Chiusura forzata il giorno della scadenza | ESEGUITO | V-L1/L2/L6 (salva/carica prima e dopo l'addebito), T10b |
| J1 | Tre lavori, turno puntuale | ESEGUITO | V-J1 (barista, cassiere, rider) |
| J2 | Ritardo, mezzo turno, requisiti | ESEGUITO | V-J2/J3/J4 |
| J3 | Turni sovrapposti | ESEGUITO | V-J2/J3/J4 (impossibile iniziarne due) |
| J4 | Dimissioni | ESEGUITO | V-J2/J3/J4 |
| J5 | Lavoro che richiede auto o notte | ESEGUITO (parziale) | nessun lavoro v0.3 richiede l'auto; il rider ha fasce serali (V-J1, LEDGER-4). Il bus è l'alternativa (V-X6) |
| J6 | Telefono Lavori con 0/1/2 lavori | ESEGUITO | V-B1/J6/X4 (0, 1, 2 lavori; con 3 non testato perché J3 lo limita negli orari) |
| H1 | Compra mobile | ESEGUITO | V-H1/H2/H4 |
| H2 | Mobile senza soldi | ESEGUITO | V-H1/H2/H4 |
| H3 | Posiziona, sposta, ruota | NON PREVISTO / PIANIFICATO | nella v0.3 i mobili hanno posti fissi (slot) e non si trascinano; la collisione con il personaggio va provata a mano |
| H4 | Rivendita, niente compra-vendi | ESEGUITO | V-H1/H2/H4, LEDGER-2 |
| H5 | Mobili interattivi | ESEGUITO (parziale) | V-H1/H2/H4 (comfort→sonno), V-X6; X01 + V-B1/J6/X4 per i pulsanti |
| H6 | Trasloco | ESEGUITO | V-H6 |
| H7 | Salva con 10+ mobili | ESEGUITO (adattato) | V-H7 con tutti i 9 mobili del catalogo (10 non esistono) |
| A1 | Compra auto con/senza soldi | ESEGUITO | V-A1/A4 |
| A2 | Sali, guida, scendi, parcheggia (touch) | PIANIFICATO (manuale) | salita/discesa provate in V-A7 e negli screenshot; il touch vero no |
| A3 | Collisioni con muri e NPC | PIANIFICATO (manuale) | il codice frena davanti a pedoni e NPC (Guard), ma non c'è un test automatico di guida |
| A4 | Serbatoio vuoto e rifornimento | ESEGUITO | V-A1/A4 |
| A5 | Costi ricorrenti | ESEGUITO | V-A5 |
| A6 | Uscire dall'auto in punti stretti | PIANIFICATO (manuale) | - |
| A7 | Salva con auto parcheggiata | ESEGUITO (parcheggiata) | V-A7; il salvataggio con il personaggio dentro l'auto non è testato |
| A8 | FPS guidando 5 minuti | PIANIFICATO, NON MISURATO | nessun telefono nel box |
| X1 | 30 giorni con lavori, bollette, affitto, auto | ESEGUITO | V-X1 (2 lavori + auto), LEDGER-1, X17 |
| X2 | Ripresa da 0 € | ESEGUITO | V-X2, LEDGER-6 |
| X3 | Salvataggio v0.2 → v0.3 | ESEGUITO | V-X3 (salvataggio vero creato con la v0.2.0, commit c297243) |
| X4 | Ogni nuova app e pulsante | ESEGUITO | V-B1/J6/X4: 66 schermate (4 app × 4 schede × 3 stati + 6 sportelli dei luoghi), 514 pulsanti, 0 senza azione |

### Dettaglio dei test v0.3 (output reale di tests/results.json)
### V-B2/B3/B5 - Banca: versa/preleva, rifiuti oltre il saldo e importi non validi: **PASS**
- OK  versati € 100 e prelevati € 40: conto e risparmi si spostano dello stesso importo
- OK  nessuna moneta creata o persa (totale € 400,01)
- OK  2 voci nello storico del conto, 2 nei risparmi
- OK  prelievo e versamento oltre il disponibile rifiutati: «Nei risparmi hai solo 60,00 €.» / «Nel conto hai solo 340,01 €.»
- OK  0, negativi e importo enorme rifiutati
- OK  dopo i rifiuti niente cambia; saldo = storico

### V-B7 - Interessi sul saldo minimo del mese (2% lordo, 26% ritenuta) e canone mensile: **PASS**
- OK  € 10.000 fermi per 28 giorni: € 12,33 netti (Ledger: 12,33)
- OK  meno di un turno da barista (€ 45,00)
- OK  versamento il giorno 28: interessi € 0,00 (non sfruttabile)
- OK  canone del conto (€ 2) addebitato una volta a fine mese
- OK  dopo salva/carica nessun accredito o canone ripetuto
- OK  saldo = storico

### V-L1/L2/L6 - Bollette luce/gas del monolocale: una volta per mese, anche dopo salva/carica: **PASS**
- OK  mese 1: luce 1, gas 1 (attese 1 e 1)
- OK  dopo salva/carica e un giorno in più: ancora 1 bolletta luce
- OK  storico intatto (14 voci)
- OK  saldo = storico, mai negativo

### V-L3/L4 - Bollette non pagate: mora una volta, luce sospesa dopo 2 bollette, si riparte pagando: **PASS**
- OK  bollette del mese 1 in sospeso, una per tipo
- OK  mora applicata alle bollette scadute (8)
- OK  luce sospesa con 2+ bollette non pagate (piastra non utilizzabile)
- OK  saldo mai negativo e coerente

### V-L4b - Dopo il pagamento la luce torna: **PASS**
- OK  nessuna bolletta in sospeso, luce attiva

### V-J1 - Tre lavori: un turno puntuale ciascuno, paga dai dati e una sola volta: **PASS**
- OK  barista: € 45,00 (dati € 45,00) 
- OK  cassiere: € 42,00 (dati € 42,00) 
- OK  rider: 3 consegne = € 9,40 (3 × € 2,80 + mancia € 1,00) 
- OK  bici (€ 140) e zaino termico (€ 35) comprati: requisiti del rider
- OK  saldo = storico

### V-J2/J3/J4 - Ritardo −20%, turni sovrapposti impossibili, mezzo turno non pagato, dopo le dimissioni niente turni: **PASS**
- OK  barista in ritardo di 20 min: € 36,00 (atteso € 36,00)
- OK  cassiere mentre sei al bar: «Sei già in turno.»
- OK  cassiere con 5 clienti su 12: paga € 0,00
- OK  rider senza bici/zaino: «È presto: il turno inizia alle 11:30 (puoi timbrare dalle 11:15).»
- OK  dopo le dimissioni: «Non lavori ancora per Market Il Girasole: candidati dal telefono (Lavori).»
- OK  saldo = storico

### V-H1/H2/H4 - Mobili: acquisto, rifiuto senza soldi, comfort→sonno, niente trucco compra-rivendi: **PASS**
- OK  senza soldi: «Ti servono 199,00 €, ne hai 30,00.», niente cambia
- OK  materasso comprato a € 199,00
- OK  sonno 12.0→14.0 energia/ora, comfort 2→10
- OK  5 cicli vendi+ricompra: perdita € 696,50
- OK  ogni mobile e vestito si rivende sotto il prezzo (30%/20%)
- OK  stanza piena: «Non c'è più spazio. Vendi un mobile o cerca una casa più grande.»
- OK  saldo = storico

### V-H6 - Trasloco: cauzione restituita, nuovo affitto una volta, il vecchio si ferma: **PASS**
- OK  senza requisiti: «Non hai ancora i requisiti: entrate nette negli ultimi 28 giorni di almeno € 960,00 (ora € 0,00).»
- OK  spesa netta € 1.260,00 = cauzione + primo canone − cauzione della stanza (€ 1.260,00)
- OK  nessun affitto della stanza dopo il trasloco
- OK  affitto del monolocale addebitato 1 volta in 17 giorni (periodo 28)
- OK  saldo = storico

### V-A1/A4 - Auto: acquisto con e senza soldi, assicurazione obbligatoria, benzina e rifornimento: **PASS**
- OK  senza soldi: «Ti servono 3.380,00 €, ne hai 400,01.»
- OK  con i soldi: € 3.380,00 (prezzo + passaggio + bollo = € 3.380,00)
- OK  senza assicurazione non si guida («Senza assicurazione non puoi guidare.»), dopo l'RC sì
- OK  serbatoio vuoto: «Benzina finita. L'auto non parte.»
- OK  10 L a € 1,85 = € 18,50
- OK  senza soldi il rifornimento è rifiutato
- OK  dopo salva/carica l'auto e la benzina restano
- OK  saldo = storico

### V-A5 - Costi ricorrenti: bollo una volta l'anno, assicurazione 28 giorni, strisce blu: **PASS**
- OK  bollo pagato all'acquisto e non ripetuto entro l'anno
- OK  pass residenti: niente ticket
- OK  senza pass serve il ticket; dopo il ticket da 2 h si può lasciare l'auto
- OK  dopo le 20 le strisce blu sono gratis
- OK  dopo 28 giorni l'assicurazione scade e va rinnovata
- OK  saldo = storico

### V-X5 - Imprevisto del giovedì deterministico (Nova): **PASS**
- OK  4 imprevisti nei giovedì 4, 11, 18, 25
- OK  due partite uguali danno gli stessi imprevisti
- OK  saldo = storico

### V-X6 - Palestra (energia massima 90→100) e bus (biglietto o abbonamento): **PASS**
- OK  abbonamento non comprabile due volte: «Hai già l'abbonamento fino al giorno 29.»
- OK  3 sessioni in 3 giorni: energia massima 90→91
- OK  corsa in bus € 1,50
- OK  con l'abbonamento la corsa è gratis
- OK  saldo = storico

### V-X7 - Affidabilità: sale pagando in tempo, con tetto mensile, tra 300 e 850: **PASS**
- OK  60 giorni di affitti puntuali: 605 → 633
- OK  crescita entro il tetto (25/mese)
- OK  nei limiti

### V-X1 - 30 giorni con 2 lavori, auto, affitto e bollette (simulazione automatica): **PASS**
- OK  saldo = storico ogni sera per 30 giorni
- OK  mai sotto zero
- OK  nessun addebito o stipendio doppio
- OK  giorno finale 30, € 5.713,02, 64 voci

### V-X2 - A zero euro: si lavora a piedi, si incassa, il debito resta lieve e recuperabile: **PASS**
- OK  arretrati in sospeso: 2
- OK  turno al bar raggiungibile a piedi, pagato € 45,00
- OK  saldo mai negativo, coerente

### V-X3 - Salvataggio v0.2 reale → v0.3: migrato senza perdere soldi né storico: **PASS**
- OK  riconosciuto (versione 1) e migrato
- OK  saldo identico: € 400,00
- OK  storico identico (6 voci) e coerente
- OK  nessun addebito retroattivo al caricamento
- OK  nuovi sistemi ai valori iniziali di Ledger
- OK  risalvato come versione 2

### LEDGER-1 - Nessun bug di soldi: scenario barista + stanza, 30 giorni: **PASS**
- OK  minimo € 391,15, fine € 760,22 (Ledger, modello Python: min 391,11 / fine 708,52)
- OK  dopo 30 giorni si risparmia qualcosa

### LEDGER-2 - Nessun ciclo compra/rivendi in guadagno: **PASS**
- OK  ogni oggetto si rivende sotto il prezzo

### LEDGER-3 - Interesse non sfruttabile: **PASS**
- OK  € 10.000 per un mese = € 12,33 < un turno

### LEDGER-4 - Rider: niente guadagno infinito (tetto consegne, energia insufficiente per due fasce piene): **PASS**
- OK  due fasce piene richiedono 103 di energia (massimo 100)

### LEDGER-5 - Mutuo coerente: rata dai dati, rata × n > capitale: **PASS**
- OK  monolocale_garibaldi € 217,92, casa_bilocale_mulino € 388,30 (Ledger: 217,92 / 388,30)

### LEDGER-6 - Economia stretta: senza lavoro i soldi finiscono in circa 3 settimane: **PASS**
- OK  senza lavoro non si riesce più a pagare il giorno 22 (Ledger: ~22)
- OK  saldo mai negativo, coerente

### V-G1 - Regole di Guard nei testi del gioco: **PASS**
- OK  etichetta: «Versione di prova (demo) — v0.3»
- OK  privacy web
- OK  avviso della banca inventata presente
- OK  nessuna parola vietata (PEGI, azzardo, trading, marchi reali): []

### V-B1/J6/X4 - App nuove del telefono (Banca, Lavori, Casa, Auto) e sportelli dei luoghi: niente pulsanti finti: **PASS**
- OK  66 schermate, 514 pulsanti controllati, senza azione: []
- OK  B1: l'app Banca mostra il saldo del gioco (€ 523,46)
- OK  B1: «In arrivo (7 giorni)» elenca l'affitto con l'importo
- OK  J6: 0 lavori → «Non hai ancora un lavoro»
- OK  J6: 1 lavoro → solo Barista
- OK  J6: 2 lavori → Barista e Rider, con prossimo turno

### V-H7 - Salva con tutti i mobili (bilocale, 12 posti) e ricarica: identici: **PASS**
- OK  9 mobili comprati (il catalogo ne ha 9; 10+ non è possibile: il caso Hook usa tutti quelli esistenti)
- OK  dopo salva/carica l'elenco dei mobili è identico
- OK  saldo invariato e = storico

### V-A7 - Salva con l'auto parcheggiata, ricarica: posizione e direzione uguali: **PASS**
- OK  salito e sceso dall'auto
- OK  scarto posizione 0.000 m, direzione -1.57 → -1.57 rad

---

# Report v0.1/v0.2 (storico, test ancora eseguiti ogni volta)

## 1. I 12 test obbligatori (ESEGUITI, automatici)
### T01 - Il personaggio si muove e si ferma correttamente: **PASS**
- OK  camminata 1 s: 2.20 m (atteso ~2.4 m), animazione 'walk'
- OK  dopo il rilascio: velocità 0.000 m/s, deriva 0.000 m, animazione 'idle'
- OK  corsa 1 s: 4.77 m (> 1,6× camminata), animazione 'run'
- OK  con energia 5 la corsa non parte (soglia 15)
- OK  animazioni walk/idle/run attive

### T02 - La telecamera non attraversa pareti o pavimenti: **PASS**
- OK  216 pose camera (6 punti, 12 direzioni, 3 inclinazioni): 0 con un muro tra personaggio e camera 
- OK  camera sotto il pavimento: 0 casi

### T03 - Le porte si aprono e si chiudono: **PASS**
- OK  porta chiusa blocca il passaggio (x massimo raggiunto -47.49, soglia muro -47,0)
- OK  Interagisci apre la porta di casa (rotazione cerniera -1.57 rad)
- OK  con la porta aperta il personaggio esce in strada (x=-42.92)
- OK  Interagisci richiude la porta
- OK  Market: porta bloccata la domenica e lunedì alle 07:30 (apre alle 08:00), aperta lunedì alle 09:00
- OK  Bar Centrale: porta bloccata il lunedì (giorno di chiusura)

### T04 - Non si possono comprare prodotti senza denaro sufficiente: **PASS**
- OK  Pasta € 1,20 con saldo € 1,00: rifiutato (money)
- OK  Panino € 3,50: rifiutato
- OK  saldo invariato (€ 1,00), mai negativo
- OK  inventario invariato
- OK  anche al bar l'ordine senza soldi è rifiutato
- OK  saldo == iniziale + somma storico

### T05 - Un acquisto riduce il saldo e aggiorna l'inventario una sola volta: **PASS**
- OK  acquisto riuscito
- OK  saldo 405,00 → 403,20 (−1,80)
- OK  inventario: 3 porzioni (1 confezione da 3)
- OK  una sola voce nello storico
- OK  scorta scaffale −1
- OK  doppio tocco su Compra: 1 addebito, 1 confezione (secondo tocco: debounce)
- OK  Market chiuso alle 21:00: acquisto bloccato, saldo invariato
- OK  saldo coerente con lo storico

### T06 - Il completamento del turno accredita lo stipendio corretto: **PASS**
- OK  giorno 1 (lunedì, bar chiuso): turno non disponibile → il tutorial manda al primo turno di martedì
- OK  turno puntuale con 10 ordini: +€ 45,00 (atteso € 45,00)
- OK  seconda chiusura: nessun doppio pagamento (voci stipendio: 1)
- OK  ritardo di 20 min: +€ 35,00 (atteso € 35,00)
- OK  solo 6 ordini su 10: niente paga
- OK  turno lasciato a metà: niente paga
- OK  oltre 45 min di ritardo: turno perso (Troppo tardi: oltre 45 minuti di ritardo il turno di oggi è perso.)
- OK  domenica: nessun turno
- OK  saldo coerente con lo storico

### T07 - I bisogni cambiano nel tempo: **PASS**
- OK  1 ora di gioco: fame −4.00 (dati: 4.0)
- OK  energia −3.00 da fermo (dati: 3.0)
- OK  sonno −5.00
- OK  correndo l'energia scende di più: −9.00/h
- OK  giornata = 20 minuti reali (1.20 min di gioco al secondo)

### T08 - Dormire recupera energia: **PASS**
- OK  8 ore: energia 20 → 100.0 (atteso 100.0)
- OK  sonno 15 → 100.0
- OK  la fame scende più piano dormendo: −16.0 in 8 h
- OK  l'ora avanza: giorno 2, 06:00

### T09 - L'affitto viene addebitato una sola volta per periodo: **PASS**
- OK  giorno 1: 1 addebito anche richiamando il controllo 2 volte
- OK  giorni 2-7: nessun altro addebito
- OK  giorno 8: secondo affitto (€ 90,00) + telefono (€ 5,00) addebitati una volta
- OK  dopo salvataggio + caricamento + nuovo controllo: ancora 2 addebiti
- OK  fino al giorno 14 nessun addebito extra
- OK  senza soldi: affitto in arretrato (1), saldo mai negativo (€ 115,00)
- OK  l'arretrato si salda dal telefono quando arrivano i soldi
- OK  saldo coerente con lo storico

### T10 - Il salvataggio ripristina correttamente la partita (stesso processo): **PASS**
- OK  denaro, inventario, bisogni, giorno/ora e lavoro identici dopo il caricamento
- OK  file corrotto riconosciuto (json) e backup caricato
- OK  file modificato a mano: checksum non valido
- OK  file mancante: stato 'missing', nessun crash
- OK  versione 99 non supportata: rifiutata (version 99)

### T11 - L'interfaccia funziona su schermi di dimensioni differenti: **PASS**
- OK  16:9 (1920x1080) → logico 1280x720: comandi dentro lo schermo=true, sovrapposizioni=false, joystick ok=true, telefono dentro=true, pulsante minimo 64 px
- OK  20:9 (2400x1080) → logico 1600x720: comandi dentro lo schermo=true, sovrapposizioni=false, joystick ok=true, telefono dentro=true, pulsante minimo 64 px
- OK  21:9 (2560x1080) → logico 1707x720: comandi dentro lo schermo=true, sovrapposizioni=false, joystick ok=true, telefono dentro=true, pulsante minimo 64 px
- OK  4:3 tablet (2048x1536) → logico 1280x960: comandi dentro lo schermo=true, sovrapposizioni=false, joystick ok=true, telefono dentro=true, pulsante minimo 64 px
- OK  3:2 (2160x1440) → logico 1280x853: comandi dentro lo schermo=true, sovrapposizioni=false, joystick ok=true, telefono dentro=true, pulsante minimo 64 px

### T12 - Nessun errore critico durante il normale utilizzo (sessione automatica): **PASS**
- OK  telefono: home + 6 app aperte
- OK  uscito di casa camminando (x=5.0)
- OK  3 turni lavorati e pagati (3)
- OK  dialoghi con 2 NPC presenti
- OK  salva/carica a fine sessione
- OK  denaro coerente dopo 4 giorni (saldo € 535,30)
- OK  errori di script/motore: verificati dal runner shell sul log (vedi TEST-REPORT)

### BAL - Test di bilanciamento di Ledger (B2 = T06, B3 = T09): **PASS**
- OK  B1: 1500 azioni casuali (acquisti, tempo, bollette): saldo mai negativo, coerente (finale € 0,20)
- OK  B4: senza pasti l'energia va sotto 20 dopo 16 ore di gioco (entro 48)
- OK  valori letti da data/economy.json (affitto € 90, paga € 45)

### X01 - Nessun pulsante finto (telefono, pannelli, HUD): **PASS**
- OK  64 pulsanti controllati, senza azione: []

### X02 - NPC con orari e dialoghi collegati ai dati: **PASS**
- OK  martedì 08:30 in giro: Mimmo, Rosa, Sig. Bianchi, Signora Ada, Dario, Marta
- OK  alle 02:00 tutti a casa (0 visibili)
- OK  32 blocchi di dialogo: segnaposto non risolti = 0

### X03 - Mangiare dall'inventario (caso Hook 10): **PASS**
- OK  pane: fame 40 → 55 (effetto dai dati +15)
- OK  porzioni 3 → 2
- OK  a 0 porzioni non si mangia (fame invariata)
- OK  la pasta senza cucina è rifiutata: Serve la cucina di casa: cucinala a casa.

### X04 - App in background/chiusa durante il turno (caso Hook 13): **PASS**
- OK  turno iniziato martedì 06:30
- OK  background: compare la pausa del turno, il turno resta sospeso
- OK  dopo chiusura e riapertura il turno è annullato
- OK  nessuno stipendio senza aver lavorato (voci storico 2 → 2)
- OK  non si ripete il turno lo stesso giorno: Il turno di oggi è stato interrotto e non si può ripetere. Prossimo: domani 06:30–12:30.
- OK  saldo coerente con lo storico

### T10a - Preparazione chiusura/riapertura: partita salvata, il processo ora si chiude: **PASS**
- OK  salvato in /home/box/.local/share/godot/app_userdata/REAL LIFE- ZERO/test_save.json

### T10b - Chiusura e riapertura del gioco: i dati restano corretti (secondo processo): **PASS**
- OK  Continua dal menu: caricamento riuscito in un nuovo processo
- OK  time identico dopo la riapertura
- OK  economy identico dopo la riapertura
- OK  needs identico dopo la riapertura
- OK  inventory identico dopo la riapertura
- OK  jobs identico dopo la riapertura
- OK  posizione del personaggio ripristinata (scarto 0.01 m)
- OK  saldo € 401,90

Note:
- T10 è diviso in due parti: T10 (salva/carica nello stesso processo, file corrotto, manomesso, mancante, versione futura) e T10a+T10b (chiusura vera del processo e riapertura in un nuovo processo con «Continua»).
- T12 è una sessione automatica di 4 giorni di gioco: telefono, uscita da casa, 3 turni, dialoghi, salvataggio. Gli errori vengono contati dal runner shell sul log di Godot, con 0 errori. Esclusi solo i messaggi di uscita del motore ("ObjectDB instances leaked"/"resources still in use" all'exit forzato dei test).
- BAL = test di bilanciamento di Ledger: B1 e B4 qui, B2 dentro T06, B3 dentro T09.
- X01-X04 sono controlli in più: nessun pulsante finto, NPC/dialoghi, mangiare e app in background durante il turno.

## 2. Piano di Hook (20 casi): mappa e stato
| # | Caso Hook | Stato | Dove / note |
|---|---|---|---|
| 1 | Avvio, nuova partita | ESEGUITO (parziale) | T10b (menu Continua in processo nuovo), T12. Diverso dal piano: alla nuova partita si pagano subito affitto settimana 1 (90 €) e telefono (5 €), quindi il saldo parte da 500 € e diventa 405 €, con le due voci nello storico. L'avvio dell'APK su un telefono vero è PIANIFICATO |
| 2 | Joystick 8 direzioni + Corri | ESEGUITO (input simulato) | T01. Il dito vero sul joystick è PIANIFICATO |
| 3 | Corsa con poca energia | ESEGUITO | T01 (energia 5: la corsa non parte), T07 |
| 4 | Camera e muri | ESEGUITO | T02 (216 pose, 0 attraversamenti). Il trascinamento con il dito vero è PIANIFICATO |
| 5 | Entrare e uscire da casa, bar e market | ESEGUITO (parziale) | T03 (porta di casa attraversata davvero, porte di market e bar con orari). X01. Tutti gli edifici di contorno sono senza porte, per costruzione |
| 6 | Comprare 1 prodotto | ESEGUITO | T05 |
| 7 | Negozio chiuso | ESEGUITO | T05 (21:00), T03 (domenica, 07:30) |
| 8 | Doppio tap su Compra | ESEGUITO | T05 (1 addebito, 1 confezione) |
| 9 | Saldo insufficiente | ESEGUITO | T04, BAL B1 |
| 10 | Mangiare | ESEGUITO | X03 |
| 11 | Turno al bar e stipendio | ESEGUITO | T06, T12 |
| 12 | Ritardo / fuori orario | ESEGUITO | T06 (20 min: -10 €; oltre 45 min: turno perso; domenica e lunedì: niente turno) |
| 13 | App in background durante il turno | ESEGUITO (simulato) | X04 (notifica PAUSED inviata al codice). Il vero background Android è PIANIFICATO |
| 14 | Giornata intera, giorno/notte | ESEGUITO (accelerato) | T07 (20 min reali = 1 giorno), T12 (4 giorni), X02 (NPC alle 08:30 e alle 02:00), screenshot giorno/sera/notte |
| 15 | Dormire | ESEGUITO | T08 |
| 16 | Affitto con e senza soldi | ESEGUITO | T09 |
| 17 | Saldo a 0 | ESEGUITO | BAL B1 (1500 azioni casuali), T09 (arretrato), T04. Il lavoro resta disponibile (T06) |
| 18 | Ogni pulsante del telefono | ESEGUITO | X01 (64 pulsanti), T12 (6 app aperte) |
| 19 | Chiusura forzata e riapertura | ESEGUITO | T10a + T10b (due processi) |
| 20 | Save corrotto + 30 FPS su telefono medio | Save: ESEGUITO (T10). FPS: **PIANIFICATO, NON MISURATO** | Nessun telefono disponibile nel box. Gli screenshot sono fatti con un renderer software (llvmpipe), che non dice niente sugli FPS reali |

## 3. Altre verifiche ESEGUITE
- Export Web (single-thread, senza SharedArrayBuffer): caricato in Chromium headless (WebGL2 via SwiftShader). Console: «Godot Engine v4.7.2.stable.official», «OpenGL ES 3.0 (WebGL 2.0) - Compatibility», «single-threaded», città costruita (3930 istanze MultiMesh); il menu principale compare. Verificato anche l'URL pubblico https://filideicristian21-tech.github.io/real-life-zero/ (HTTP 200, wasm 39,5 MB `application/wasm`): con un clic su «Nuova partita» parte la partita e con W il personaggio cammina fino al prompt «Letto · Dormi». Screenshot: `reallife-shots/16_web_pages_menu.png`, `17_web_pages_gioco.png`.
- APK Android di debug: export riuscito, `aapt dump permissions` non mostra **nessun** `uses-permission`. Firma debug verificata con `apksigner verify` (CN=Android Debug). arm64-v8a, minSdk 24, package `it.reallifezero.buildtest`.
- Screenshot reali del gioco: `/workspace/reallife-shots/` (16 immagini, renderer opengl3 su Xvfb).

## 4. PIANIFICATI (non eseguiti)
- Installazione e avvio dell'APK su un Android vero; FPS medi (obiettivo 30) entrando nei negozi.
- Multi-touch vero (joystick + trascinamento camera insieme) su schermo touch.
- Background e ritorno dall'app con il sistema operativo vero (nei test la notifica è simulata).
- Prova sul browser di un telefono (iOS Safari / Chrome Android) della versione web.
- iOS: impossibile qui (serve macOS e un account Apple Developer a pagamento).

## v0.2.0 (passata di realismo), 17 ott 2026
- `tests/run_tests.sh`: 31 + 1 test, 0 falliti, 0 errori nel log (T01-T12, BAL, X01-X17, T10b in un secondo processo).
- Draw call misurate con `tests/shots.gd` (Compatibility, 1280x720, xvfb + llvmpipe): da 120 a 338 per inquadratura (in v0.2 prima dell'ottimizzazione: 465-765). Ridotte con batching statico (box, cilindri e sfere in MultiMesh), LOD a distanza automatico per gli oggetti piccoli, ombre solo per gli oggetti sopra 0,9 m e luci dei lampioni spente di giorno.
- FPS su un telefono reale: NON MISURATO (non c'è un dispositivo). Le draw call sono un indicatore, non una misura di FPS.
- APK debug 0.2.0-test (versionCode 2): nessun permesso dichiarato (aapt dump permissions), package it.reallifezero.buildtest.
