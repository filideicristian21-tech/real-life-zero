# REAL LIFE: ZERO - Report dei test

Build: v0.1.0 (Godot 4.7.2-stable, renderer Compatibility). Data esecuzione: 17 ott 2026, sul box Linux (headless).
Comando: `bash tests/run_tests.sh` (due processi Godot separati: il secondo riapre il salvataggio del primo).
Output grezzo: `tests/results.json`, log completo `tests/test_log.txt`, errori filtrati `tests/errors.txt` (vuoto: 0 errori di script/motore nel log).

**Legenda.** ESEGUITO = test automatico che è stato davvero lanciato, con il risultato qui sotto. PIANIFICATO = non eseguito, nessun risultato dichiarato.
Ciò che i test automatici NON possono provare: il tocco con le dita su un telefono vero, gli FPS su un Android vero e l'avvio dell'APK su un dispositivo. Questi punti restano PIANIFICATI.

Nota sull'elenco: i 12 titoli T01-T12 sono quelli del brief originale dell'utente (sezione 13 del messaggio, quella dei test obbligatori). `docs/BRIEF-utente.md` è un riassunto e non li ripete. Il piano di Hook (20 casi, colonna "Mappa Hook") è mappato sotto.

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
