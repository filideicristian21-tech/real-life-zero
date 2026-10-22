class_name LifeUI
extends RefCounted
## v0.3: app del telefono (Banca, Lavori, Casa, Auto) e pannelli dei nuovi luoghi.
## Testi delle app: Anchor v03. Dati: Ledger v03 (data/life.json).

var ui   # GameUI
var tabs := {"banca": "conto", "lavori": "mio", "casa": "mia", "auto": "mia", "stato": "bisogni"}
var spese_days := 7
var cashier := {}

const DISCLAIMER := "Simulazione di gioco: non è consulenza finanziaria e non rappresenta prodotti reali."

func _init(u) -> void:
	ui = u

func L() -> Dictionary:
	return Data.life

func e(c: int) -> String:
	return "€ " + Data.euro(c)

func _rer() -> void:
	ui._render_phone()

## Mostra l'esito di un'azione: "" = ok.
func _res(err: String, ok_msg: String) -> bool:
	if err == "":
		if ok_msg != "":
			ui.show_toast(ok_msg, "ok")
		Game.save_after_purchase()
		return true
	ui.show_toast(err, "warn")
	Sfx.play("error")
	return false

func _tabs(v: VBoxContainer, app: String, items: Array, refresh: Callable) -> void:
	var h := HBoxContainer.new()
	v.add_child(h)
	for it in items:
		var b := UIKit.button(it[1], func():
			tabs[app] = it[0]
			refresh.call(), tabs[app] == it[0], 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)

func _h(v: VBoxContainer, t: String) -> void:
	v.add_child(UIKit.label(t, 21, UIKit.CORAL, true))

func _p(v: VBoxContainer, t: String, size: int = 18, col: Color = Color.WHITE) -> void:
	v.add_child(UIKit.label(t, size, col, true))

func _btn(text: String, cb: Callable, accent: bool = true, disabled: bool = false) -> Button:
	var b := UIKit.button(text, cb, accent, 46)
	b.disabled = disabled
	return b

# =====================================================================  BANCA
func app_banca(v: VBoxContainer) -> void:
	_tabs(v, "banca", [["conto", "Conto"], ["risparmi", "Risparmi"], ["spese", "Spese"], ["aff", "Affidabilità"]], _rer)
	match tabs["banca"]:
		"conto": _bank_conto(v)
		"risparmi": _bank_risparmi(v)
		"spese": _bank_spese(v)
		"aff": _bank_aff(v)
	_p(v, DISCLAIMER, 15, UIKit.MUTED)

func _bank_conto(v: VBoxContainer) -> void:
	var b: Dictionary = L()["bank"]
	v.add_child(UIKit.label("Saldo disponibile: " + e(Economy.money_cents), 28))
	_p(v, "%s · %s · canone %s al mese · Risparmi: %s" % [b.get("name", "Banca Popolare del Colle"), b["checking"]["name"], e(int(b["checking"]["monthly_fee_cents"])), e(Life.savings_cents)], 17, UIKit.MUTED)
	_p(v, "Paghi con la carta: ogni spesa viene addebitata subito sul conto. Se il saldo non basta il pagamento viene rifiutato (niente scoperto).", 16, UIKit.MUTED)
	var up := Economy.upcoming(7)
	_h(v, "In arrivo (7 giorni)")
	if up.is_empty():
		_p(v, "Nessuna spesa prevista.", 17, UIKit.MUTED)
	for u in up:
		ui._row(v, "%s · %s" % [u["voce"], e(int(u["importo"]))], null, "giorno %d" % int(u["giorno"]))
	if not Economy.pending_bills.is_empty():
		_h(v, "Da pagare (arretrati)")
	for i in Economy.pending_bills.size():
		var pb: Dictionary = Economy.pending_bills[i]
		var btn := _btn("Paga " + e(int(pb["amount"])), func():
			ui._pay_pending(i)
			_rer(), true, not Economy.can_afford(int(pb["amount"])))
		ui._row(v, pb["desc"], btn, "scadenza giorno %d%s" % [int(pb["due_day"]), " · mora già applicata" if pb.get("late_fee_applied", false) else ""])
	_h(v, "Movimenti")
	if Economy.history.is_empty():
		_p(v, Data.t("phone.hist_empty"), 17, UIKit.MUTED)
	var hist := Economy.history.duplicate()
	hist.reverse()
	for t in hist.slice(0, 40):
		_tx_row(v, t)

func _tx_row(v: VBoxContainer, t: Dictionary) -> void:
	var amt := int(t["amount"])
	var l := UIKit.label(("+" if amt > 0 else "−") + e(absi(amt)), 19, UIKit.GREEN if amt > 0 else UIKit.RED)
	l.custom_minimum_size.x = 130
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var h := HBoxContainer.new()
	var d := UIKit.label("G%d %s · %s" % [int(t["day"]), t["time"], t["desc"]], 16, Color.WHITE, true)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(d)
	h.add_child(l)
	v.add_child(h)

func _bank_risparmi(v: VBoxContainer) -> void:
	var s: Dictionary = L()["bank"]["savings"]
	v.add_child(UIKit.label("Salvadanaio: " + e(Life.savings_cents), 28))
	_p(v, "Interesse %s%% lordo l'anno sul saldo minimo del mese, accreditato a fine mese (ritenuta 26%%). Trasferimenti gratis e immediati." % str(float(s.get("interest_bp_annual_gross", 200)) / 100.0), 16, UIKit.MUTED)
	var g := GridContainer.new()
	g.columns = 4
	v.add_child(g)
	for c in [1000, 5000, 10000]:
		g.add_child(_btn("Versa " + e(c), func():
			if _res(Life.deposit(c), "Versati %s nel Salvadanaio." % e(c)): _rer(), true, Economy.money_cents < c))
	g.add_child(_btn("Versa tutto", func():
		var c := Economy.money_cents
		if _res(Life.deposit(c), "Versati %s nel Salvadanaio." % e(c)): _rer(), true, Economy.money_cents <= 0))
	for c in [1000, 5000, 10000]:
		g.add_child(_btn("Preleva " + e(c), func():
			if _res(Life.withdraw(c), "Prelevati %s: ora sono sul conto." % e(c)): _rer(), false, Life.savings_cents < c))
	g.add_child(_btn("Preleva tutto", func():
		var c := Life.savings_cents
		if _res(Life.withdraw(c), "Prelevati %s: ora sono sul conto." % e(c)): _rer(), false, Life.savings_cents <= 0))
	_h(v, "Obiettivo")
	if Life.goal.is_empty():
		_p(v, "Scegli un obiettivo di risparmio: il telefono ti mostra a che punto sei.", 17, UIKit.MUTED)
	else:
		var tgt := int(Life.goal["target_cents"])
		_p(v, "%s: %s su %s" % [Life.goal["name"], e(mini(Life.savings_cents, tgt)), e(tgt)], 19)
		v.add_child(UIKit.bar(100.0 * minf(1.0, float(Life.savings_cents) / float(maxi(1, tgt))), UIKit.GREEN))
	var gh := HBoxContainer.new()
	v.add_child(gh)
	for go in L()["weekly_goal_options"]:
		var b := _btn(go["name"], func():
			Life.goal = go.duplicate()
			_rer(), Life.goal.get("id", "") == go["id"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gh.add_child(b)
	_h(v, "Movimenti dei risparmi")
	var hs := Life.savings_history.duplicate()
	hs.reverse()
	if hs.is_empty():
		_p(v, "Ancora nessun movimento.", 17, UIKit.MUTED)
	for t in hs.slice(0, 20):
		_tx_row(v, t)

func _bank_spese(v: VBoxContainer) -> void:
	var h := HBoxContainer.new()
	v.add_child(h)
	for d in [7, 28]:
		var b := _btn("Ultimi %d giorni" % d, func():
			spese_days = d
			_rer(), spese_days == d)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	var sp := Life.spending_by_category(spese_days)
	var tot := 0
	var mx := 1
	for k in sp:
		if k != "_entrate":
			tot += int(sp[k])
			mx = maxi(mx, int(sp[k]))
	_p(v, "Entrate %s · Uscite %s · Differenza %s" % [e(int(sp["_entrate"])), e(tot), ("+" if int(sp["_entrate"]) >= tot else "−") + e(absi(int(sp["_entrate"]) - tot))], 19)
	var chart := HBoxContainer.new()
	chart.custom_minimum_size = Vector2(0, 220)
	chart.add_theme_constant_override("separation", 10)
	v.add_child(chart)
	var cols := {"Cibo": Color("#F2A65A"), "Affitto": Color("#E8664A"), "Casa": Color("#7BA7E0"), "Auto": Color("#B58AE0"), "Benzina": Color("#E0C25A"), "Assicurazione": Color("#5BC1B5"), "Altro": Color("#9A9A9A")}
	for k in cols:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_END
		chart.add_child(col)
		col.add_child(UIKit.label(Data.euro(int(sp[k])).split(",")[0], 14, UIKit.MUTED))
		var r := ColorRect.new()
		r.color = cols[k]
		r.custom_minimum_size = Vector2(30, 4.0 + 150.0 * float(sp[k]) / float(mx))
		col.add_child(r)
		var lbl := UIKit.label(k if k != "Assicurazione" else "Assic.", 13)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lbl)
	_p(v, "I trasferimenti nel Salvadanaio non sono spese e non compaiono qui.", 15, UIKit.MUTED)

func _bank_aff(v: VBoxContainer) -> void:
	var cs: Dictionary = L()["credit_score"]
	v.add_child(UIKit.label("Affidabilità: %d · %s" % [Life.credit_score, Life.score_band()], 28))
	v.add_child(UIKit.bar(100.0 * float(Life.credit_score - 300) / 550.0, UIKit.GREEN))
	_p(v, "È un punteggio del gioco (da 300 a 850, si parte da 600). Sale se paghi in tempo e lavori con costanza, scende con ritardi e arretrati. Serve per affittare casa, comprare a rate o chiedere un mutuo. Si recupera sempre: bastano pagamenti puntuali.", 16, UIKit.MUTED)
	_h(v, "Ultime variazioni")
	var names := {"rent_paid_on_time": "Affitto pagato puntuale", "rent_late": "Affitto in ritardo", "bill_paid_on_time": "Bolletta pagata puntuale", "bill_late": "Bolletta in ritardo", "eviction": "Due affitti non pagati", "loan_installment_on_time": "Rata pagata puntuale", "loan_installment_late": "Rata in ritardo", "month_no_late": "Mese senza ritardi", "shifts_month": "Lavoro costante nel mese", "savings_month": "Risparmi in crescita"}
	var lg := Life.score_log.duplicate()
	lg.reverse()
	if lg.is_empty():
		_p(v, "Ancora nessuna variazione.", 17, UIKit.MUTED)
	for s in lg.slice(0, 15):
		var d := int(s["delta"])
		ui._row(v, "%s %+d" % [names.get(s["reason"], str(s["reason"])), d], null, "giorno %d" % int(s["day"]))

# =====================================================================  LAVORI
func app_lavori(v: VBoxContainer) -> void:
	_tabs(v, "lavori", [["mio", "Il mio lavoro"], ["offerte", "Offerte"], ["cand", "Candidature"], ["promo", "Promozioni"]], _rer)
	match tabs["lavori"]:
		"mio": _jobs_mine(v)
		"offerte": _jobs_offers(v)
		"cand": _jobs_apps(v)
		"promo": _jobs_promo(v)

func _job_pay_text(id: String) -> String:
	if id == "rider":
		return "%s netti a consegna + mance" % e(Jobs.net_pay(id))
	return "%s netti a turno (lordo %s)" % [e(Jobs.net_pay(id)), e(Jobs.gross_pay(id))]

func _shifts_text(j: Dictionary) -> String:
	var p := []
	for s in j["shifts"]:
		p.append("%s–%s" % [s["start"], s["end"]])
	return "%s · %s" % [" / ".join(p), ", ".join(j["workdays"])]

func _jobs_mine(v: VBoxContainer) -> void:
	if not Jobs.any_employed():
		_p(v, "Non hai ancora un lavoro. Guarda le Offerte, oppure chiedi a Mimmo al Bar Centrale.", 19, UIKit.MUTED)
		return
	for j in Jobs.jobs_cfg():
		var id: String = j["id"]
		if not Jobs.st(id)["employed"]:
			continue
		_h(v, "%s · %s" % [Jobs.title(id), j.get("place", "")])
		_p(v, "Prossimo turno: %s · %s" % [Jobs.next_shift_text(id), _job_pay_text(id)], 18)
		_p(v, "Orari: %s · Turni completi: %d · Puntualità %d%%" % [_shifts_text(j), int(Jobs.st(id)["completed"]), Jobs.punctuality_pct(id)], 16, UIKit.MUTED)
		_p(v, "In ritardo oltre %d minuti: paga ridotta del 20%%." % int(j.get("late_policy", {}).get("late_after_min", 15)) if id != "rider" else "Paga a consegna: le consegne fatte si pagano anche se lasci il turno prima.", 16, UIKit.MUTED)
		var h := HBoxContainer.new()
		v.add_child(h)
		if id == "rider":
			var st := Jobs.check_in_status("rider")
			var b := _btn("Inizia turno consegne", func(): start_rider(), true, not st["ok"])
			b.tooltip_text = st.get("reason", "")
			h.add_child(b)
			if not st["ok"]:
				_p(v, st["reason"], 15, UIKit.MUTED)
		elif id == "cassiere":
			_p(v, "Il turno si inizia alla cassa del Market Il Girasole.", 16, UIKit.MUTED)
		else:
			_p(v, "Il turno si inizia al bancone del Bar Centrale.", 16, UIKit.MUTED)
		h.add_child(_btn("Lascia il lavoro", func():
			ui._confirm("Vuoi davvero lasciare il lavoro (%s)? Potrai ricandidarti più avanti." % Jobs.title(id), func():
				Jobs.quit_job(id)
				ui.show_toast("Hai lasciato il lavoro: %s." % Jobs.title(id), "info"), "Lascia"), false))
	_h(v, "Abilità")
	_p(v, "Caffè %d · Precisione %d · Fisico %d · Colloquio: %d punti (con i vestiti che indossi)" % [int(Life.skills["caffe"]), int(Life.skills["precisione"]), int(Life.skills["fisico"]), Life.interview_score()], 17)

func _jobs_offers(v: VBoxContainer) -> void:
	_p(v, "Lavori veri, paga uguale per tutti. La risposta arriva il giorno dopo.", 16, UIKit.MUTED)
	for j in Jobs.jobs_cfg():
		var id: String = j["id"]
		var need := int(j.get("hiring", {}).get("interview_score_min", 0))
		_h(v, j["name"])
		_p(v, "%s · %s" % [_shifts_text(j), _job_pay_text(id)], 17)
		_p(v, j.get("activity", ""), 15, UIKit.MUTED)
		var miss := Jobs.missing_requirement(id)
		if Jobs.st(id)["employed"]:
			_p(v, "Lavori già qui.", 16, UIKit.GREEN)
			continue
		if id == "barista":
			_p(v, "Per questo lavoro parla direttamente con Mimmo al bancone.", 16, UIKit.MUTED)
			continue
		if need > 0:
			_p(v, "Colloquio: servono %d punti (tu ne hai %d)." % [need, Life.interview_score()], 16, UIKit.GREEN if Life.interview_score() >= need else Color("#F2A65A"))
		if id == "rider":
			for eq in j.get("equipment", []):
				var has: bool = eq["id"] in Life.equipment
				ui._row(v, eq["name"], _btn("Ce l'hai" if has else "Compra " + e(int(eq["price_cents"])), func():
					if _res(Jobs.buy_equipment(eq["id"]), "Comprato: %s." % eq["name"]): _rer(), true, has or not Economy.can_afford(int(eq["price_cents"]))), "attrezzatura obbligatoria")
		v.add_child(_btn("Candidati", func():
			if _res(Jobs.apply(id), "Candidatura inviata: risposta domani."): _rer(), true, miss != ""))

func _jobs_apps(v: VBoxContainer) -> void:
	if Jobs.applications.is_empty():
		_p(v, "Nessuna candidatura inviata.", 18, UIKit.MUTED)
	for id in Jobs.applications:
		var a: Dictionary = Jobs.applications[id]
		var s: String = {"pending": "In attesa: risposta il giorno %d" % int(a.get("answer_day", 0)), "rejected": "Non presa: puoi riprovare dal giorno %d" % int(a.get("retry_day", 0))}.get(a["status"], "Assunto")
		if Jobs.st(id)["employed"]:
			s = "Assunto"
		ui._row(v, Jobs.job(id)["name"], null, s)

func _jobs_promo(v: VBoxContainer) -> void:
	_p(v, "Le promozioni arrivano con i turni completi, la puntualità e l'abilità del lavoro. Un turno saltato non azzera niente, ma abbassa la puntualità.", 16, UIKit.MUTED)
	for j in Jobs.jobs_cfg():
		var id: String = j["id"]
		if not Jobs.st(id)["employed"]:
			continue
		_h(v, "%s (livello %d)" % [Jobs.title(id), int(Jobs.st(id)["level"])])
		_p(v, Jobs.promotion_progress(id), 17)
		var nl := Jobs.next_level(id)
		if not nl.is_empty():
			_p(v, "Nuova paga: %s" % e(int(nl.get("net_cents_per_shift", nl.get("net_cents_per_delivery", 0)))), 16, UIKit.GREEN)

# =====================================================================  CASA
func app_casa(v: VBoxContainer) -> void:
	_tabs(v, "casa", [["mia", "La mia casa"], ["cerca", "Cerca casa"], ["mobili", "Mobili"], ["armadio", "Armadio"]], _rer)
	match tabs["casa"]:
		"mia": _home_mine(v)
		"cerca": _home_search(v)
		"mobili": _home_furniture(v)
		"armadio": _home_wardrobe(v)

func at_home() -> bool:
	if ui.main and ui.main.player:
		var p: Vector3 = ui.main.player.global_position
		return p.x > -55.0 and p.x < -47.0 and p.z > -29.0 and p.z < -20.0
	return false

func _home_mine(v: VBoxContainer) -> void:
	var h := Life.home_cfg()
	_h(v, h["name"])
	if Life.is_rental():
		_p(v, "Affitto %s ogni %d giorni · prossimo: giorno %d · cauzione versata %s" % [e(int(h["rent_cents"])), int(h["period_days"]), Economy.next_rent_due_day(), e(Life.deposit_held_cents)], 17)
		var inc: Array = h.get("bills_included", [])
		_p(v, "Bollette incluse nel canone." if not inc.is_empty() else "Luce, gas e TARI arrivano a parte (a fine mese).", 16, UIKit.MUTED)
	else:
		var o := Life.owned_home
		_p(v, "Casa tua con mutuo: rata %s al mese · capitale residuo %s · rate pagate %d" % [e(int(h["mortgage_installment_cents"])), e(int(o.get("principal_left", 0))), int(o.get("installments_paid", 0))], 17)
	_p(v, "Comfort %d/10 · Sonno: +%.0f energia l'ora · Mobili %d/%d" % [Life.comfort(), Life.sleep_energy_per_hour(), Life.furniture_used(), Life.furniture_slots()], 17)
	if Life.power_suspended:
		_p(v, "Luce sospesa per bollette non pagate: forno, piastra e macchina del caffè non funzionano. Paga gli arretrati in Banca → Conto.", 17, Color("#F2A65A"))
	_h(v, "A casa")
	var here := at_home()
	if not here:
		_p(v, "Queste azioni si fanno quando sei in casa.", 16, UIKit.MUTED)
	if "scrivania_sedia" in Life.furniture:
		var g := HBoxContainer.new()
		v.add_child(g)
		for sk in [["caffe", "Studia: caffè"], ["precisione", "Studia: cassa"], ["fisico", "Studia: percorsi"]]:
			var b := _btn(sk[1] + " (1 h)", func():
				if _res(Life.study(sk[0]), "Un'ora di studio: abilità +%d." % int(Life.furniture_by_id("scrivania_sedia")["effects"]["study_skill_per_hour"])): _rer(), false, not here)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(b)
	if "macchina_caffe" in Life.furniture:
		v.add_child(_btn("Fatti un caffè (capsule: %d)" % Life.capsules, func():
			if _res(Life.home_coffee(), "Caffè fatto in casa: un po' di energia."): _rer(), false, not here))
	if not ("scrivania_sedia" in Life.furniture) and not ("macchina_caffe" in Life.furniture):
		_p(v, "Con una scrivania puoi studiare; con la macchina del caffè fai colazione a casa.", 16, UIKit.MUTED)

func _home_search(v: VBoxContainer) -> void:
	_p(v, "Agenzia Casa Colle. Prezzi e requisiti sono stime del gioco. Il trasloco è immediato: la cauzione della casa attuale ti viene restituita.", 16, UIKit.MUTED)
	_p(v, "Affidabilità %d · Entrate nette ultimi 28 giorni %s" % [Life.credit_score, e(Life.net_income_28d())], 17)
	_h(v, "In affitto")
	for h in L()["homes_rent"]:
		var miss := Life.home_missing(h)
		var cur: bool = h["id"] == Life.home_id
		_p(v, h["name"], 19)
		_p(v, "%s ogni %d giorni · cauzione %s · bollette %s · posto per %d mobili" % [e(int(h["rent_cents"])), int(h["period_days"]), e(int(h["deposit_cents"])), "incluse" if not h.get("bills_included", []).is_empty() else "a parte", int(h["furniture_slots"])], 16, UIKit.MUTED)
		if miss != "" and not cur:
			_p(v, "Requisito: " + miss, 15, Color("#F2A65A"))
		v.add_child(_btn("Ci abiti" if cur else "Affitta (%s subito)" % e(int(h["deposit_cents"]) + int(h["rent_cents"])), func():
			ui._confirm("Trasferirti in %s? Paghi cauzione e primo affitto adesso." % h["name"], func():
				if _res(Life.rent_home(h["id"]), "Benvenuto nella nuova casa!"): _rer(), "Affitta"), true, cur or miss != ""))
	_h(v, "In vendita (con mutuo)")
	var m: Dictionary = L()["mortgage"]
	for h in L()["homes_sale"]:
		var miss := Life.home_missing(h)
		var cur: bool = h["id"] == Life.home_id
		_p(v, h["name"], 19)
		_p(v, "Prezzo %s · anticipo %s + spese %s · mutuo %s a %d anni, rata %s al mese" % [e(int(h["price_cents"])), e(int(h["down_payment_cents"])), e(int(h["closing_costs_cents"])), e(int(h["mortgage_principal_cents"])), int(m["term_months"]) / 12, e(int(h["mortgage_installment_cents"]))], 16, UIKit.MUTED)
		if miss != "" and not cur:
			_p(v, "Requisito: " + miss, 15, Color("#F2A65A"))
		v.add_child(_btn("È tua" if cur else "Compra", func():
			ui._confirm("Comprare %s? Paghi subito anticipo e spese; la rata arriva a fine mese per %d anni." % [h["name"], int(m["term_months"]) / 12], func():
				if _res(Life.buy_home(h["id"]), "Hai comprato casa. Complimenti!"): _rer(), "Compra"), true, cur or miss != ""))
	_p(v, "Se non riesci a pagare il mutuo per 3 mesi la banca rivende la casa con te: ti restituisce quello che hai già versato (meno le spese) e torni in affitto. Nessun debito nascosto.", 15, UIKit.MUTED)

func _home_furniture(v: VBoxContainer) -> void:
	_p(v, "%s · consegna e montaggio inclusi. Mobili usati: li rivendi al %d%% del prezzo." % [L()["furniture_shop"]["name"], int(L()["furniture_resale_pct"])], 16, UIKit.MUTED)
	_p(v, "Spazio: %d / %d mobili" % [Life.furniture_used(), Life.furniture_slots()], 18)
	for f in L()["furniture"]:
		if int(f["price_cents"]) == 0:
			continue
		var has: bool = f["id"] in Life.furniture
		var eff := _furn_effect_text(f)
		var b: Button
		if has:
			var r := Life.resale_cents(int(f["price_cents"]), int(L()["furniture_resale_pct"]))
			b = _btn("Vendi a " + e(r), func():
				ui._confirm("Vendere %s per %s? L'hai pagato %s." % [f["name"], e(r), e(int(f["price_cents"]))], func():
					if _res(Life.sell_furniture(f["id"]), "Venduto: %s." % f["name"]): _rer(), "Vendi"), false)
		else:
			b = _btn("Compra " + e(int(f["price_cents"])), func():
				if _res(Life.buy_furniture(f["id"]), "Consegnato a casa: %s." % f["name"]): _rer(), true, Life.furniture_used() >= Life.furniture_slots() or not Economy.can_afford(int(f["price_cents"])))
		ui._row(v, f["name"] + (" ✓" if has else ""), b, eff)

func _furn_effect_text(f: Dictionary) -> String:
	var ef: Dictionary = f.get("effects", {})
	var p := []
	if ef.has("sleep_energy_per_hour"): p.append("sonno %d energia/ora" % int(ef["sleep_energy_per_hour"]))
	if ef.has("sleep_energy_per_hour_bonus"): p.append("sonno +%d energia/ora" % int(ef["sleep_energy_per_hour_bonus"]))
	for c in f.get("provides", []): p.append("puoi usare: " + str(c))
	if ef.has("study_skill_per_hour"): p.append("studio: +%d abilità/ora" % int(ef["study_skill_per_hour"]))
	if ef.has("energy_per_use"): p.append("+%d energia a caffè" % int(ef["energy_per_use"]))
	if ef.has("comfort"): p.append("comfort +%d" % int(ef["comfort"]))
	if f.has("note"): p.append(str(f["note"]))
	return " · ".join(p) if not p.is_empty() else "arreda la casa (comfort)"

func _home_wardrobe(v: VBoxContainer) -> void:
	_p(v, "Quello che indossi si vede su Luca e conta ai colloqui. I vestiti usati si rivendono al %d%%." % int(L()["clothes_resale_pct"]), 16, UIKit.MUTED)
	if Life.clothes.size() <= 1:
		_p(v, "Per ora hai solo la maglietta di sempre. La Boutique Marisa è in Via Roma Vecchia.", 17, UIKit.MUTED)
	for id in Life.clothes:
		var c := Life.clothes_by_id(id)
		var w: bool = id in Life.wearing
		var h := HBoxContainer.new()
		h.add_child(_btn("Togli" if w else "Indossa", func():
			Life.toggle_wear(id)
			_rer(), not w))
		if id != "maglietta_base":
			h.add_child(_btn("Vendi " + e(Life.resale_cents(int(c["price_cents"]), int(L()["clothes_resale_pct"]))), func():
				ui._confirm("Vendere %s?" % c["name"], func():
					if _res(Life.sell_clothes(id), "Venduto: %s." % c["name"]): _rer(), "Vendi"), false))
		ui._row(v, c["name"] + (" (indossato)" if w else ""), h, _cloth_effect(c))

func _cloth_effect(c: Dictionary) -> String:
	var ef: Dictionary = c.get("effects", {})
	var p := []
	if ef.has("interview_bonus"): p.append("colloquio +%d" % int(ef["interview_bonus"]))
	if ef.has("gym_energy_cost_reduction"): p.append("palestra: −%d fatica" % int(ef["gym_energy_cost_reduction"]))
	if ef.has("rider_on_time_bonus_min"): p.append("consegne: +%d min di tempo" % int(ef["rider_on_time_bonus_min"]))
	if ef.has("rider_energy_per_delivery_reduction"): p.append("consegne: −%d fatica" % int(ef["rider_energy_per_delivery_reduction"]))
	if ef.has("promotion_note"): p.append(str(ef["promotion_note"]))
	return " · ".join(p) if not p.is_empty() else "solo estetica"

# =====================================================================  AUTO
func app_auto(v: VBoxContainer) -> void:
	_tabs(v, "auto", [["mia", "La mia auto"], ["conc", "Concessionario"], ["benzina", "Benzina"], ["ass", "Assicurazione"]], _rer)
	match tabs["auto"]:
		"mia": _car_mine(v)
		"conc": _car_dealer(v)
		"benzina": _car_fuel(v)
		"ass": _car_ins(v)

func _car_mine(v: VBoxContainer) -> void:
	if not Life.has_car():
		_p(v, "Non hai ancora un'auto. Puoi usare il bus (Linea 3) oppure guardare le offerte dell'Autosalone Bertoni — Usato Garantito.", 18, UIKit.MUTED)
		_bus_box(v)
		return
	var m := Life.car_model()
	var c := Life.car
	_h(v, m["name"])
	_p(v, "Benzina %d%% · %.0f km · usura %d%% · assicurazione %s · bollo fino al giorno %d" % [Life.fuel_pct(), float(c["km"]), int(c["wear_pct"]), ("fino al giorno %d" % int(c["ins_until"])) if Life.insured() else "SCADUTA", int(c["tax_until"])], 17)
	var plan: Dictionary = c.get("plan", {})
	if not plan.is_empty() and int(plan.get("left", 0)) > 0:
		_p(v, "Rate: %s al mese, ne mancano %d." % [e(int(plan["rata"])), int(plan["left"])], 17)
	var why := Life.can_drive()
	_p(v, "Pronta per guidare." if why == "" else why, 17, UIKit.GREEN if why == "" else Color("#F2A65A"))
	_p(v, "Per guidare avvicinati all'auto e premi Interagisci. In città: massimo 50 km/h, l'auto si ferma da sola davanti ai pedoni.", 16, UIKit.MUTED)
	var mt: Dictionary = L()["cars"]["maintenance"]
	v.add_child(_btn("Officina: tagliando %s" % e(int(mt["service_cents"]) if float(c["wear_pct"]) < 100.0 else int(mt["repair_at_100_pct"]["cents"])), func():
		if _res(Life.service_car(), "Auto sistemata: usura 0%."): _rer(), false, float(c["wear_pct"]) < 5.0))
	_h(v, "Parcheggio")
	var p: Dictionary = L()["cars"]["parking"]
	_p(v, "Strisce blu %s: %s l'ora (o pass residenti %s per 28 giorni). Strisce bianche gratis." % [p["blue_lines_hours"], e(int(p["blue_lines_cents_per_hour"])), e(int(p["resident_pass_cents_per_month"]))], 16, UIKit.MUTED)
	var ph := HBoxContainer.new()
	v.add_child(ph)
	ph.add_child(_btn("Ticket 2 ore " + e(2 * int(p["blue_lines_cents_per_hour"])), func():
		if _res(Life.buy_parking_ticket(2), "Ticket pagato: 2 ore."): _rer(), false))
	ph.add_child(_btn("Pass residenti", func():
		if _res(Life.buy_resident_pass(), "Pass residenti attivo per 28 giorni."): _rer(), false, GameTime.day() < Life.resident_pass_until))

func _car_dealer(v: VBoxContainer) -> void:
	var pc: Dictionary = L()["cars"]["purchase"]
	var ip: Dictionary = pc["installment_plan"]
	_p(v, "Autosalone Bertoni — Usato Garantito. Al prezzo si aggiungono passaggio di proprietà %s e bollo annuale. Nomi e modelli inventati." % e(int(pc["ownership_transfer_cents"])), 16, UIKit.MUTED)
	for m in Life.car_models():
		_h(v, m["name"])
		_p(v, "Prezzo %s · consumo %.1f L/100 km · assicurazione %s ogni 28 giorni · bollo %s l'anno" % [e(int(m["price_cents"])), float(m["fuel_l_per_100km_x10"]) / 10.0, e(int(m["insurance_monthly_cents"])), e(int(m["road_tax_annual_cents"]))], 16, UIKit.MUTED)
		var down: int = int(m["price_cents"]) * int(ip["down_payment_pct"]) / 100
		var rata := Life.installment_cents(int(m["price_cents"]) - down + int(pc["ownership_transfer_cents"]))
		var h := HBoxContainer.new()
		v.add_child(h)
		var total := int(m["price_cents"]) + int(pc["ownership_transfer_cents"]) + int(m["road_tax_annual_cents"])
		h.add_child(_btn("Compra %s" % e(total), func():
			ui._confirm("Comprare %s pagando %s subito?" % [m["name"], e(total)], func(): _buy_car(m["id"], false), "Compra"), true, Life.has_car()))
		h.add_child(_btn("A rate: anticipo %s, %d × %s" % [e(down), int(ip["term_months"]), e(rata)], func():
			ui._confirm("Comprare %s a rate? Anticipo %s + bollo subito, poi %d rate da %s (TAN %.1f%%)." % [m["name"], e(down), int(ip["term_months"]), e(rata), float(ip["tan_bp"]) / 100.0], func(): _buy_car(m["id"], true), "Firma"), false, Life.has_car()))
	_p(v, "Rate: servono affidabilità %d, %d turni completati e una rata sotto il %d%% delle entrate. Prima di partire attiva l'assicurazione." % [int(ip["min_credit_score"]), int(ip["min_shifts_completed"]), int(ip["max_installment_pct_of_net_income"])], 15, UIKit.MUTED)

func _buy_car(id: String, plan: bool) -> void:
	var spot := Vector3(66.0, 0.0, 26.0)
	if ui.main and ui.main.town and "car_spawn" in ui.main.town:
		spot = ui.main.town.car_spawn
	if _res(Life.buy_car(id, plan, spot, 0.0), "Auto tua! È parcheggiata davanti all'Autosalone. Ricordati l'assicurazione."):
		tabs["auto"] = "ass"
		_rer()

func _car_fuel(v: VBoxContainer) -> void:
	var fs: Dictionary = L()["cars"]["fuel_station"]
	_p(v, "%s · aperto %s–%s · benzina %s al litro" % [fs.get("name", "Distributore del Colle"), fs["hours"]["open"], fs["hours"]["close"], Data.euro(int(L()["cars"]["fuel_price_cents_per_liter"]))], 17)
	if not Life.has_car():
		_p(v, "Ti serve prima un'auto.", 17, UIKit.MUTED)
		return
	_p(v, "Serbatoio al %d%%. Il rifornimento si fa alla pompa: parcheggia accanto al distributore e premi Interagisci." % Life.fuel_pct(), 17, UIKit.MUTED)

func _car_ins(v: VBoxContainer) -> void:
	if not Life.has_car():
		_p(v, "L'assicurazione RC si attiva dopo aver comprato l'auto. Senza assicurazione non si guida.", 17, UIKit.MUTED)
		return
	var m := Life.car_model()
	_p(v, "Assicurazione RC (obbligatoria per guidare): %s ogni 28 giorni." % e(int(m["insurance_monthly_cents"])), 18)
	_p(v, ("Attiva fino al giorno %d." % int(Life.car["ins_until"])) if Life.insured() else "Non attiva: l'auto resta ferma.", 17, UIKit.GREEN if Life.insured() else Color("#F2A65A"))
	v.add_child(_btn("Rinnova 28 giorni" if Life.insured() else "Attiva 28 giorni", func():
		if _res(Life.buy_insurance(), "Assicurazione attiva fino al giorno %d." % int(Life.car["ins_until"])): _rer(), true))

func _bus_box(v: VBoxContainer) -> void:
	var b: Dictionary = L()["transport"]["bus"]
	_h(v, "Bus Linea 3")
	_p(v, "Biglietto %s a corsa, abbonamento %s per 28 giorni%s." % [e(int(b["ticket_cents"])), e(int(b["monthly_pass_cents"])), (" (attivo fino al giorno %d)" % Life.bus_pass_until) if Life.bus_has_pass() else ""], 16, UIKit.MUTED)
	v.add_child(_btn("Compra abbonamento", func():
		if _res(Life.buy_bus_pass(), "Abbonamento bus attivo per 28 giorni."): _rer(), false, Life.bus_has_pass()))

# =====================================================================  PANNELLI DEI LUOGHI
func open_boutique() -> void:
	ui.open_modal("boutique", "Boutique Marisa", _fill_boutique, 680)

func _reopen(kind: String) -> void:
	match kind:
		"boutique": open_boutique()
		"gym": open_gym()
		"trattoria": open_trattoria()
		"dealer": open_dealer()
		"fuel": open_fuel()
		"bank": open_bank()

func _fill_boutique(v: VBoxContainer) -> void:
	var cs: Dictionary = L()["clothes_shop"]
	var open := GameTime.is_open(cs["hours"])
	_p(v, "Abbigliamento uomo e donna, senza loghi. Orario %s–%s, chiuso %s." % [cs["hours"]["open"], cs["hours"]["close"], ", ".join(cs["hours"].get("closed_days", []))], 16, UIKit.MUTED)
	if not open:
		_p(v, "Chiuso. Riapre: %s." % GameTime.next_open_text(cs["hours"]), 18, Color("#F2A65A"))
	for c in L()["clothes"]:
		if int(c["price_cents"]) == 0:
			continue
		var has: bool = c["id"] in Life.clothes
		ui._row(v, c["name"], _btn("Ce l'hai" if has else "Compra " + e(int(c["price_cents"])), func():
			if _res(Life.buy_clothes(c["id"]), "Comprato e indossato: %s." % c["name"]): _reopen("boutique"), true, has or not open or not Economy.can_afford(int(c["price_cents"]))), _cloth_effect(c))

func open_gym() -> void:
	ui.open_modal("gym", L()["gym"]["name"], _fill_gym, 640)

func _fill_gym(v: VBoxContainer) -> void:
	var g: Dictionary = L()["gym"]
	var open := GameTime.is_open(g["hours"])
	_p(v, "Orario %s–%s, chiuso la domenica. Abbonamento %s per 28 giorni, ingresso singolo %s." % [g["hours"]["open"], g["hours"]["close"], e(int(g["monthly_pass_cents"])), e(int(g["single_entry_cents"]))], 16, UIKit.MUTED)
	_p(v, "Energia massima %d/100 · fisico %d · allenamenti contati %d. Ogni 3 giorni di allenamento +1 energia massima; dopo 7 giorni di pausa scende di 1 (mai sotto 90)." % [Life.energy_max, int(Life.skills["fisico"]), Life.gym_sessions], 17)
	if not open:
		_p(v, "Chiuso. Riapre: %s." % GameTime.next_open_text(g["hours"]), 18, Color("#F2A65A"))
	if Life.gym_has_pass():
		_p(v, "Abbonamento attivo fino al giorno %d." % Life.gym_pass_until, 17, UIKit.GREEN)
		v.add_child(_btn("Allenati (1 ora)", func(): _gym_do(false), true, not open))
	else:
		v.add_child(_btn("Abbonamento 28 giorni " + e(int(g["monthly_pass_cents"])), func():
			if _res(Life.buy_gym_pass(), "Abbonamento attivo."): _reopen("gym"), true, not Economy.can_afford(int(g["monthly_pass_cents"]))))
		v.add_child(_btn("Ingresso singolo e allenati " + e(int(g["single_entry_cents"])), func(): _gym_do(true), false, not open))

func _gym_do(single: bool) -> void:
	var r := Life.gym_session(single)
	ui.show_toast(r["text"], "ok" if r["ok"] else "warn")
	if r["ok"]:
		Game.save_after_purchase()
	_reopen("gym")

func trattoria_open() -> bool:
	var r: Dictionary = L()["restaurant"]
	var cd: Array = r.get("closed_days", [])
	var lunch := {"open": r["hours_lunch"]["open"], "close": r["hours_lunch"]["close"], "closed_days": cd}
	var dinner := {"open": r["hours_dinner"]["open"], "close": r["hours_dinner"]["close"], "closed_days": cd}
	return GameTime.is_open(lunch) or GameTime.is_open(dinner)

func open_trattoria() -> void:
	ui.open_modal("trattoria", L()["restaurant"]["name"], _fill_trattoria, 640)

func _fill_trattoria(v: VBoxContainer) -> void:
	var r: Dictionary = L()["restaurant"]
	var open := trattoria_open()
	_p(v, "Pranzo %s–%s, cena %s–%s, chiuso il lunedì. Si paga con la carta." % [r["hours_lunch"]["open"], r["hours_lunch"]["close"], r["hours_dinner"]["open"], r["hours_dinner"]["close"]], 16, UIKit.MUTED)
	if not open:
		_p(v, "Adesso la cucina è chiusa.", 18, Color("#F2A65A"))
	for it in r["menu"]:
		ui._row(v, it["name"], _btn(e(int(it["price_cents"])), func():
			if Economy.spend(int(it["price_cents"]), "Trattoria Da Rosa: " + it["name"], "trattoria"):
				Needs.eat(float(it["hunger"]), float(it["energy"]))
				GameTime.advance(30.0)
				ui.show_toast("Buon appetito! %s: fame +%d, energia +%d." % [it["name"], int(it["hunger"]), int(it["energy"])], "ok")
				Sfx.play("cup")
				Game.save_after_purchase()
				_reopen("trattoria")
			else:
				ui.show_toast("Ti servono %s, ne hai %s." % [e(int(it["price_cents"])), e(Economy.money_cents)], "warn"), true, not open or not Economy.can_afford(int(it["price_cents"]))), "fame +%d · energia +%d · 30 min" % [int(it["hunger"]), int(it["energy"])])

func open_dealer() -> void:
	ui.open_modal("dealer", "Autosalone Bertoni — Usato Garantito", func(v):
		var h: Dictionary = L()["cars"].get("dealer", {}).get("hours", {"open": "09:00", "close": "19:00", "closed_days": ["dom"]})
		if not GameTime.is_open(h):
			_p(v, "Chiuso. Riapre: %s. Puoi comunque guardare le offerte." % GameTime.next_open_text(h), 17, Color("#F2A65A"))
			for m in Life.car_models():
				_p(v, "%s · %s" % [m["name"], e(int(m["price_cents"]))], 17)
			return
		_car_dealer(v)
		if Life.has_car():
			_car_ins(v), 700)

func open_fuel() -> void:
	ui.open_modal("fuel", "Distributore del Colle", func(v):
		_car_fuel(v)
		if Life.has_car():
			var h := HBoxContainer.new()
			v.add_child(h)
			for l in [10.0, 0.0]:
				h.add_child(_btn("Pieno" if l == 0.0 else "%d litri" % int(l), func():
					var r := Life.refuel(l)
					ui.show_toast(r["text"], "ok" if r["ok"] else "warn")
					if r["ok"]: Game.save_after_purchase()
					_reopen("fuel"), true, not Life.fuel_station_open())), 620)

func open_bank() -> void:
	var b: Dictionary = L()["bank"]
	var hrs: Dictionary = b.get("hours", {"open": "08:30", "close": "13:30", "closed_days": ["sab", "dom"]})
	ui.open_modal("bank", b.get("name", "Banca Popolare del Colle"), func(v):
		_p(v, "Sportello aperto %s–%s (chiuso sabato e domenica). Il bancomat funziona sempre: saldo, risparmi e pagamenti li gestisci anche dall'app Banca." % [hrs["open"], hrs["close"]], 16, UIKit.MUTED)
		if GameTime.is_open(hrs):
			_p(v, "Lo sportello è aperto: qui si firma il mutuo (serve il completo da colloquio).", 17, UIKit.GREEN)
		v.add_child(_btn("Apri l'app Banca", func():
			ui.close_modal()
			tabs["banca"] = "conto"
			ui.toggle_phone()
			ui.phone_open_app("banca"), true))
		_bank_risparmi(v)
		_p(v, DISCLAIMER, 15, UIKit.MUTED), 680)

# =====================================================================  TURNO ALLA CASSA (minigioco del resto)
func start_cashier() -> void:
	var st := Jobs.start_shift("cassiere")
	if not st["ok"]:
		ui.show_toast(st["reason"], "warn")
		return
	ui.close_modal()
	if ui.main and ui.main.player:
		ui.main.player.teleport(Vector3(12.0, Town.CURB, 12.2), PI)
	if st.get("late", false):
		ui.show_toast("Sei in ritardo: la paga di oggi sarà ridotta del 20%.", "warn")
	cashier = {}
	var v: VBoxContainer = await ui.open_modal("shift", "Turno alla cassa · Market Il Girasole", func(_v): pass, 720, false)
	if v == null:
		return
	cashier["v"] = v
	_next_customer()

func _next_customer() -> void:
	if not Jobs.in_shift or Jobs.cur_job != "cassiere" or not cashier.has("v") or not is_instance_valid(cashier["v"]):
		return
	var v: VBoxContainer = cashier["v"]
	for c in v.get_children():
		c.queue_free()
	var n := Jobs.orders_done + Jobs.change_errors * 7 + GameTime.day() * 3
	var total := 120 + (n * 379) % 2380          # spesa da 1,20 a 25,00 €
	var notes := [500, 1000, 2000, 5000]
	var paid := 0
	for nt in notes:
		if nt >= total:
			paid = nt
			break
	if paid == 0:
		paid = 5000
	var right := paid - total
	var opts := [right, right + 100 if right + 100 <= paid else right - 50, maxi(0, right - 100) if right >= 100 else right + 50]
	var order := [0, 1, 2]
	var r := n % 3
	order = [order[r], order[(r + 1) % 3], order[(r + 2) % 3]]
	var req: Dictionary = Jobs.job("cassiere")["requirements"]
	_p(v, "Ore %s · fine turno %s · clienti serviti %d / %d · errori nel resto %d (max %d)" % [GameTime.clock_text(), Jobs.job("cassiere")["shifts"][Jobs.cur_slot]["end"], Jobs.orders_done, int(req["customers_min_served"]), Jobs.change_errors, int(req["max_change_errors"])], 18, UIKit.MUTED)
	v.add_child(UIKit.label("Totale: %s · Il cliente ti dà %s" % [e(total), e(paid)], 28, Color.WHITE, true))
	_p(v, "Quanto resto devi dare?", 20)
	var g := HBoxContainer.new()
	v.add_child(g)
	for i in order:
		var val: int = opts[i]
		var b := UIKit.button(e(val), func(): _give_change(val == right), true, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(b)
	v.add_child(UIKit.button("Lascia il turno (niente paga)", func():
		ui._confirm("Lasciare il turno adesso? Non verrai pagato per oggi.", Jobs.abandon_shift.bind("Hai lasciato il turno prima della fine."), "Lascia"), false, 46))
	cashier["right"] = right

func _give_change(ok: bool) -> void:
	if not Jobs.in_shift:
		return
	if ok:
		Jobs.complete_order()
		Sfx.play("cup")
	else:
		Jobs.change_error()
		Sfx.play("error")
		ui.show_toast("Resto sbagliato: il cliente te lo fa notare. Controlla bene!", "warn")
	# ogni cliente porta avanti l'orologio: un turno da 6 ore ≈ 14 clienti
	GameTime.advance(24.0)
	_next_customer()

# =====================================================================  RIDER
func start_rider() -> void:
	var st := Jobs.start_shift("rider")
	if not st["ok"]:
		ui.show_toast(st["reason"], "warn")
		return
	ui.close_modal()
	ui.show_toast("Turno consegne iniziato: segui il segnale arancione. Ritira l'ordine, poi consegnalo in tempo.", "info")

func rider_text() -> String:
	if not Jobs.in_shift or Jobs.cur_job != "rider":
		return ""
	var d: Dictionary = Jobs.delivery
	if d.is_empty():
		return "Consegne finite per questo turno · %d fatte. Il turno si chiude alle %s." % [Jobs.orders_done, Jobs.job("rider")["shifts"][Jobs.cur_slot]["end"]]
	var left := int(float(d["deadline"]) - GameTime.total_minutes)
	var tgt: Array = d["pickup"] if d["stage"] == "pickup" else d["drop"]
	var where := str(tgt[2]) if tgt.size() > 2 else ""
	var dist := 0
	if ui.main and ui.main.player:
		dist = int(Vector2(ui.main.player.global_position.x, ui.main.player.global_position.z).distance_to(Vector2(float(tgt[0]), float(tgt[1]))))
	return "%s: %s · %d m · %s · consegne %d" % ["Ritira" if d["stage"] == "pickup" else "Consegna", where, dist, ("%d min" % left) if left >= 0 else "in ritardo", Jobs.orders_done]
