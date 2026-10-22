extends Node
## Inventario: id prodotto -> porzioni rimaste. Una confezione comprata = "uses" porzioni.

signal inventory_changed()

var portions: Dictionary = {}
var shop_stock: Dictionary = {}   # scorte del Market, ripristinate ogni giorno
var last_tap_water_min: float = -9999.0

func _ready() -> void:
	GameTime.day_changed.connect(func(_d): restock())

func reset_new_game() -> void:
	portions.clear()
	restock()
	last_tap_water_min = -9999.0
	inventory_changed.emit()

func restock() -> void:
	shop_stock.clear()
	for p in Data.economy["minimarket"]["products"]:
		shop_stock[p["id"]] = int(p["stock"])

func add_product(id: String, packs: int = 1) -> void:
	var p: Dictionary = Data.products_by_id[id]
	portions[id] = int(portions.get(id, 0)) + int(p.get("uses", 1)) * packs
	inventory_changed.emit()

func count(id: String) -> int:
	return int(portions.get(id, 0))

func total_items() -> int:
	var n := 0
	for k in portions:
		n += int(portions[k])
	return n

func remove_portion(id: String) -> bool:
	if count(id) <= 0:
		return false
	portions[id] = count(id) - 1
	if portions[id] <= 0:
		portions.erase(id)
	inventory_changed.emit()
	return true

## Acquisto atomico al Market: controlla orario, scorta e saldo, poi addebita e aggiunge UNA volta.
## Ritorna {ok, reason}.
func buy_product(id: String) -> Dictionary:
	if not Data.products_by_id.has(id):
		return {"ok": false, "reason": "unknown"}
	var mm: Dictionary = Data.economy["minimarket"]
	if not GameTime.is_open(mm["hours"]):
		return {"ok": false, "reason": "closed"}
	if int(shop_stock.get(id, 0)) <= 0:
		return {"ok": false, "reason": "stock"}
	var p: Dictionary = Data.products_by_id[id]
	if not Economy.spend(int(p["price_cents"]), "Market Il Girasole: " + str(p["name"]), "spesa"):
		return {"ok": false, "reason": "money"}
	shop_stock[id] = int(shop_stock[id]) - 1
	add_product(id)
	return {"ok": true, "reason": ""}

## Consuma una porzione. where: "anywhere" | "cucina" | "forno". Ritorna {ok, reason, text}.
func consume(id: String, has_kitchen: bool) -> Dictionary:
	if count(id) <= 0:
		return {"ok": false, "reason": "none"}
	var p: Dictionary = Data.products_by_id[id]
	var req := str(p.get("requires", ""))
	if req != "" and not has_kitchen:
		return {"ok": false, "reason": "needs_kitchen", "text": "Serve il forno di casa: mangiala a casa." if req == "forno" else "Serve la cucina di casa: cucinala a casa."}
	if req != "" and not Life.capability(req):
		if Life.power_suspended:
			return {"ok": false, "reason": "needs_oven", "text": "Luce sospesa: paga le bollette arretrate per usare forno e piastra."}
		return {"ok": false, "reason": "needs_oven", "text": "Ti serve un forno: lo trovi nell'app Casa → Mobili." if req == "forno" else "Ti serve una cucina: app Casa → Mobili."}
	if req == "forno":
		Life.use_appliance(1000)
	elif req == "cucina" and "piastra_induzione" in Life.furniture:
		Life.use_appliance(500)
	remove_portion(id)
	var hg := float(p["hunger"])
	var en := float(p["energy"])
	var extra := ""
	if p.has("bonus_with") and count(p["bonus_with"]) > 0:
		remove_portion(p["bonus_with"])
		hg += float(p.get("bonus_hunger", 0))
		extra = " (con %s)" % Data.products_by_id[p["bonus_with"]]["name"]
	# il sugo dà il bonus anche se cucinato insieme alla pasta
	for q in Data.economy["minimarket"]["products"]:
		if q.get("bonus_with", "") == id and count(q["id"]) > 0 and has_kitchen:
			remove_portion(q["id"])
			hg += float(q["hunger"]) + float(q.get("bonus_hunger", 0))
			extra = " con %s" % q["name"]
			break
	if p.has("side_effect"):
		Needs.sleep_quality_malus += -float(p["side_effect"].get("sleep_quality", 0))
	Needs.eat(hg, en)
	return {"ok": true, "reason": "", "text": "Hai consumato: %s%s. Fame +%d, Energia +%d." % [p["name"], extra, int(hg), int(en)]}

func to_dict() -> Dictionary:
	return {"portions": portions, "shop_stock": shop_stock, "last_tap_water_min": last_tap_water_min}

func from_dict(d: Dictionary) -> void:
	portions.clear()
	for k in d.get("portions", {}):
		var v := int(d["portions"][k])
		if v > 0 and Data.products_by_id.has(k):
			portions[k] = v
	restock()
	for k in d.get("shop_stock", {}):
		shop_stock[k] = int(d["shop_stock"][k])
	last_tap_water_min = float(d.get("last_tap_water_min", -9999.0))
	inventory_changed.emit()
