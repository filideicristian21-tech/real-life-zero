# REAL LIFE: ZERO (v0.1.0, build di test)

Life sim 3D in terza persona per smartphone (Godot 4). Sei Luca Ferraro, hai 20 anni, 500 € e una stanza in affitto a San Vito al Colle, una cittadina inventata.
Lavori al Bar Centrale da Mimmo, fai la spesa al Market Il Girasole, paghi l'affitto e gestisci fame, energia e sonno.
Il gioco è offline: niente pubblicità, niente acquisti, nessun dato raccolto. I salvataggi stanno solo in `user://`.

- **Versione web:** https://filideicristian21-tech.github.io/real-life-zero/ (single-thread, gira anche su GitHub Pages)
- **Sorgenti:** https://github.com/filideicristian21-tech/real-life-zero

## Comandi
Sul telefono: joystick a sinistra; trascina a destra per girare la camera; pulsanti Interagisci, Corri e Telefono; pausa in alto a destra.
Sul PC: WASD o frecce, Shift per correre, E o Spazio per interagire, Tab o P per il telefono, Esc per la pausa, mouse trascinato nella metà destra per la camera.

## Aprire il progetto
1. Scarica Godot **4.7.2-stable** (standard, non .NET) da https://godotengine.org/download/archive/4.7.2-stable/ (Linux: `Godot_v4.7.2-stable_linux.x86_64`).
2. Apri Godot, fai Importa, scegli `project.godot` nella cartella del repo, poi premi F5.
   Da riga di comando: `godot --path . ` (gioco) oppure `godot -e --path .` (editor).
3. Al primo avvio Godot importa gli asset: ci vuole circa un minuto.

## Struttura
- `scenes/main.tscn`: scena principale. Il mondo viene costruito da codice (`scripts/world/town.gd`).
- `scripts/autoload/`: singleton `Data`, `GameTime` (unica fonte del tempo), `Economy`, `Needs`, `Inventory`, `Jobs`, `SaveSystem`, `Game`, `Sfx`.
- `scripts/world/`, `scripts/actors/`, `scripts/ui/`: città, porte, giorno e notte, giocatore, NPC, interfaccia touch e telefono.
- `data/`: tutti i valori di bilanciamento e i testi.
  - `economy.json`: prezzi, orari, paga, affitto.
  - `balance.json`: tempo, sonno, velocità, autosave.
  - `texts.json`, `dialogues.json`, `places.json`, `credits.txt`.
  Si modificano senza toccare il codice.
- `tests/`: test automatici (`run_tests.sh`) e lo strumento per gli screenshot (`shots.tscn`).
- `docs/`: `TEST-REPORT.md`, `LICENSES.md` / `LICENZE-ASSET.md` (una riga per asset), il brief.

## Test automatici
```
GODOT=/percorso/godot bash tests/run_tests.sh
```
Fa due processi headless: il secondo riapre il salvataggio del primo. Scrive `tests/results.json`, `tests/test_log.txt` e `tests/errors.txt`. Esce con codice 0 solo se è tutto PASS e il log ha 0 errori. I risultati sono in `docs/TEST-REPORT.md`.

Screenshot (serve un display, va bene anche Xvfb):
```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/shots.tscn
```

## Export
I template di export di Godot 4.7.2 si installano dall'editor (Editor > Gestisci template di export) oppure si estraggono da `Godot_v4.7.2-stable_export_templates.tpz` in `~/.local/share/godot/export_templates/4.7.2.stable/`.
I preset sono in `export_presets.cfg` e non contengono password.

**Web** (single-thread, nessun header COOP/COEP necessario):
```
godot --headless --path . --export-release "Web" build/web/index.html
```
Poi pubblica la cartella `build/web/` su un hosting statico (qui il branch `gh-pages`). Per provarla in locale: `python3 -m http.server -d build/web 8080`.

**Android APK di debug:**
1. Servono OpenJDK 17 e l'Android SDK (cmdline-tools, `platform-tools`, `build-tools;35.0.1`, `platforms;android-35`). In Editor > Impostazioni editor > Export > Android imposta i percorsi di Java SDK e Android SDK.
2. Crea un keystore di debug **fuori dal repo**:
   `keytool -genkeypair -keystore ~/debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"`
3. Lancia:
```
GODOT_ANDROID_KEYSTORE_DEBUG_PATH=~/debug.keystore GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android \
godot --headless --path . --export-debug "Android" build/android/RealLifeZero-test-debug.apk
```
4. Per controllare i permessi: `aapt dump permissions build/android/RealLifeZero-test-debug.apk`. Deve risultare nessun `uses-permission`. Installa con `adb install`, oppure copia il file sul telefono e consenti l'installazione da origini sconosciute.

Il package è `it.reallifezero.buildtest`, un nome provvisorio da confermare. L'APK è solo arm64-v8a.

**iOS:** non incluso. Serve un Mac con Xcode e un account Apple Developer, che è a pagamento, quindi fuori dal budget zero.

## Limiti noti della v1
- Arredi, auto e cibo sono placeholder Kenney in stile toy, diverso dai personaggi Quaternius: vanno sostituiti.
- L'appartamento è al piano terra, per semplicità.
- Il bus non si prende: alla fermata si leggono gli orari e ci si può sedere.
- Gli FPS su un telefono vero non sono ancora stati misurati: vedi `docs/TEST-REPORT.md`.
