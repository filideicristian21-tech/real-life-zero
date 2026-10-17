extends Node
## Salvataggio JSON in user:// con versione, checksum, backup e recupero da file mancante/corrotto.

signal saved(ok: bool, reason: String)

const CURRENT_VERSION := 1
var save_path := "user://save.json"
var backup_path := "user://save_backup.json"
var last_error := ""

func _canon_hash(game: Dictionary) -> String:
	var norm = JSON.parse_string(JSON.stringify(game, "", true))
	return JSON.stringify(norm, "", true).md5_text()

func build_game_dict() -> Dictionary:
	return {
		"time": GameTime.to_dict(),
		"economy": Economy.to_dict(),
		"needs": Needs.to_dict(),
		"inventory": Inventory.to_dict(),
		"jobs": Jobs.to_dict(),
		"progress": Game.progress_to_dict(),
	}

func save_game() -> bool:
	var game := build_game_dict()
	var doc := {"format": "reallifezero-save", "version": CURRENT_VERSION,
		"saved_unix": int(Time.get_unix_time_from_system()), "checksum": _canon_hash(game), "game": game}
	var text := JSON.stringify(doc, "\t")
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "open:%d" % FileAccess.get_open_error()
		saved.emit(false, last_error)
		return false
	f.store_string(text)
	f.close()
	# verifica la scrittura prima di sostituire il file principale
	if inspect(tmp)["status"] != "ok":
		last_error = "verify"
		saved.emit(false, last_error)
		return false
	if FileAccess.file_exists(save_path) and inspect(save_path)["status"] == "ok":
		DirAccess.copy_absolute(save_path, backup_path)
	var err := DirAccess.rename_absolute(tmp, save_path)
	if err != OK:
		last_error = "rename:%d" % err
		saved.emit(false, last_error)
		return false
	if not FileAccess.file_exists(backup_path):
		DirAccess.copy_absolute(save_path, backup_path)
	last_error = ""
	saved.emit(true, "")
	return true

## Ritorna {status: ok|missing|corrupt, doc, summary}
func inspect(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": "missing"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"status": "corrupt", "why": "open"}
	var text := f.get_as_text()
	f.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"status": "corrupt", "why": "json"}
	var doc = parser.data
	if not (doc is Dictionary):
		return {"status": "corrupt", "why": "json"}
	if doc.get("format", "") != "reallifezero-save" or not doc.has("game") or not (doc["game"] is Dictionary):
		return {"status": "corrupt", "why": "format"}
	var ver := int(doc.get("version", 0))
	if ver < 1 or ver > CURRENT_VERSION:
		return {"status": "corrupt", "why": "version %d" % ver}
	doc = migrate(doc)
	var g: Dictionary = doc["game"]
	for k in ["time", "economy", "needs", "inventory", "jobs", "progress"]:
		if not g.has(k) or not (g[k] is Dictionary):
			return {"status": "corrupt", "why": "missing " + k}
	if str(doc.get("checksum", "")) != _canon_hash(g):
		return {"status": "corrupt", "why": "checksum"}
	var tm := float(g["time"].get("total_minutes", 0))
	var day := int(tm / 1440.0) + 1
	return {"status": "ok", "doc": doc, "day": day, "clock": Data.min_to_hhmm(int(tm) % 1440), "money": int(g["economy"].get("money_cents", 0))}

## Migrazioni future: da versione N a N+1.
func migrate(doc: Dictionary) -> Dictionary:
	# v1 è la prima versione: nessuna migrazione necessaria.
	return doc

func status() -> Dictionary:
	return inspect(save_path)

func backup_status() -> Dictionary:
	return inspect(backup_path)

func load_from(path: String) -> bool:
	var info := inspect(path)
	if info["status"] != "ok":
		last_error = info.get("why", info["status"])
		return false
	var g: Dictionary = info["doc"]["game"]
	GameTime.from_dict(g["time"])
	Economy.from_dict(g["economy"])
	Needs.from_dict(g["needs"])
	Inventory.from_dict(g["inventory"])
	Jobs.from_dict(g["jobs"])
	Game.progress_from_dict(g["progress"])
	return true

func load_game() -> bool:
	return load_from(save_path)

## Ripristina il backup come file principale e lo carica.
func load_backup() -> bool:
	if not load_from(backup_path):
		return false
	DirAccess.copy_absolute(backup_path, save_path)
	return true

func delete_all() -> void:
	for p in [save_path, backup_path, save_path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
