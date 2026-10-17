extends Node
## Carica tutti i valori di bilanciamento e i testi da res://data/*.json.

var economy: Dictionary = {}
var balance: Dictionary = {}
var places: Dictionary = {}
var texts: Dictionary = {}
var dialogues: Array = []
var products_by_id: Dictionary = {}
var bar_menu_by_id: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	economy = _load("res://data/economy.json")
	balance = _load("res://data/balance.json")
	places = _load("res://data/places.json")
	texts = _load("res://data/texts.json")
	var d = _load_any("res://data/dialogues.json")
	dialogues = d if d is Array else []
	products_by_id.clear()
	for p in economy.get("minimarket", {}).get("products", []):
		products_by_id[p["id"]] = p
	bar_menu_by_id.clear()
	for m in economy.get("bar", {}).get("menu", []):
		bar_menu_by_id[m["id"]] = m

func _load(path: String) -> Dictionary:
	var v = _load_any(path)
	return v if v is Dictionary else {}

func _load_any(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Data: impossibile aprire %s" % path)
		return null
	var v = JSON.parse_string(f.get_as_text())
	if v == null:
		push_error("Data: JSON non valido in %s" % path)
	return v

## Testo con segnaposto {chiave}. path tipo "feedback.bought".
func t(path: String, vars: Dictionary = {}) -> String:
	var node = texts
	for k in path.split("."):
		if node is Dictionary and node.has(k):
			node = node[k]
		else:
			return path
	return fmt(str(node), vars)

static func fmt(s: String, vars: Dictionary) -> String:
	for k in vars:
		s = s.replace("{" + str(k) + "}", str(vars[k]))
	return s

static func euro(cents: int) -> String:
	var neg := cents < 0
	var c: int = abs(cents)
	var euros := c / 100
	var s := str(euros)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	return ("-" if neg else "") + out + "," + ("%02d" % (c % 100))

static func hhmm_to_min(s: String) -> int:
	var p := s.split(":")
	return int(p[0]) * 60 + int(p[1])

static func min_to_hhmm(m: int) -> String:
	m = posmod(m, 1440)
	return "%02d:%02d" % [m / 60, m % 60]
