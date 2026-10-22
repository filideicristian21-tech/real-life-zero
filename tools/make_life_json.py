#!/usr/bin/env python3
"""Genera data/life.json dai dati v0.3 di Ledger (fonte di verità), con le correzioni di Guard/Spark:
nomi auto inventati, nomi dei luoghi di Spark, aggiunte per luoghi/eventi/serbatoio (STIMA)."""
import json, copy, sys
SRC = "/workspace/gioco-team/v03build/economy_v03.json"
d = json.load(open(SRC))
L = copy.deepcopy(d)
# --- Guard: niente marchi reali ---
ren = {"panda_2010": ("utilitaria_ginestra", "Ginestra 1.2 utilitaria (2010, 160.000 km)", 160000, "#C9C2B2"),
       "polo_2015": ("compatta_corallo", "Corallo 1.0 compatta (2015, 110.000 km)", 110000, "#3A5A8C")}
for m in L["cars"]["models"]:
    nid, nm, km, col = ren[m["id"]]
    m["id"], m["name"], m["km_start"], m["color"] = nid, nm, km, col
    m["tank_l"] = 35
L["cars"]["tank_note"] = "STIMA: serbatoio 35 L per entrambe; nomi dei modelli inventati (Guard: niente marchi reali)"
L["cars"]["dealer"] = {"name": "Autosalone Bertoni — Usato Garantito", "hours": {"open": "09:00", "close": "19:00", "closed_days": ["dom"]}}
L["cars"]["fuel_station"] = {"name": "Distributore del Colle", "hours": {"open": "07:00", "close": "21:00", "closed_days": []}}
L["cars"]["drive"] = {"max_speed_kmh": 50, "reverse_kmh": 12, "km_per_world_unit": 0.004, "note": "1 m di gioco = 4 m di strada reale per rendere sensibili i consumi in una mappa piccola (STIMA)"}
# --- nomi dei luoghi (Spark) ---
L["jobs"][0]["name"] = "Barista – Bar Centrale da Mimmo"
L["jobs"][1]["name"] = "Cassiere – Market Il Girasole"
L["jobs"][0]["place"] = "Bar Centrale"
L["jobs"][1]["place"] = "Market Il Girasole"
L["jobs"][2]["place"] = "ConsegnaGiù"
L["jobs"][2]["name"] = "Rider in bici – ConsegnaGiù"
L["homes_rent"][0]["name"] = "Stanza in affitto, Via dei Tigli 12"
L["homes_rent"][0]["zona"] = "Via dei Tigli"
L["homes_rent"][0]["provides"] = ["cucina", "forno"]
L["homes_rent"][0]["provides_note"] = "la stanza ha già una cucina con forno (si vede nella scena): scostamento da Ledger"
L["homes_rent"][1]["zona"] = "Corso Italia"
L["homes_rent"][2]["zona"] = "Piazza Garibaldi"
L["homes_sale"][0]["zona"] = "Via Garibaldi"
L["homes_sale"][1]["zona"] = "Via del Mulino"
L["gym"]["name"] = "Palestra Fit Colle"
L["bank"]["name"] = "Banca Popolare del Colle"
L["bank"]["hours"] = {"open": "08:30", "close": "13:30", "closed_days": ["sab", "dom"]}
L["bank"]["disclaimer"] = "Simulazione di gioco: non è consulenza finanziaria e non rappresenta prodotti reali."
L["credit_score"]["label"] = "Affidabilità (punteggio nel gioco)"
L["clothes_shop"] = {"name": "Boutique Marisa", "hours": {"open": "09:30", "close": "19:30", "closed_days": ["dom"]}}
L["furniture_shop"] = {"name": "Arredo Casa Colle (consegna in giornata)"}
L["restaurant"] = {
  "name": "Trattoria Da Rosa",
  "hours_lunch": {"open": "12:00", "close": "14:30"},
  "hours_dinner": {"open": "19:00", "close": "22:00"},
  "closed_days": ["lun"],
  "note": "STIMA prezzi trattoria di paese 2026",
  "menu": [
    {"id": "primo_giorno", "name": "Primo del giorno", "price_cents": 850, "hunger": 40, "energy": 6},
    {"id": "menu_pranzo", "name": "Menu pranzo (primo, secondo, acqua)", "price_cents": 1300, "hunger": 65, "energy": 10},
    {"id": "secondo_contorno", "name": "Secondo con contorno", "price_cents": 1100, "hunger": 45, "energy": 8},
    {"id": "tiramisu", "name": "Tiramisù della casa", "price_cents": 450, "hunger": 12, "energy": 6}
  ]
}
L["equipment_shop_note"] = "Bici e zaino si comprano dall'app Lavori (ConsegnaGiù li consegna a casa)"
# --- Nova: imprevisto del giovedì, deterministico (ciclo per settimana, niente azzardo) ---
L["thursday_events"] = [
  {"id": "schermo", "text": "Lo schermo dello Zero Phone si è crepato: riparazione dal tecnico.", "amount_cents": -2500, "category": "Altro"},
  {"id": "mancia", "text": "Un cliente abituale ti lascia una busta di ringraziamento per le feste del paese.", "amount_cents": 1500, "category": "Entrate", "requires_job": True},
  {"id": "scarpe", "text": "Si è scollata una scarpa: risuolatura dal calzolaio.", "amount_cents": -1200, "category": "Altro"},
  {"id": "nonna", "text": "La nonna ti manda un piccolo regalo per la nuova casa.", "amount_cents": 2000, "category": "Entrate"},
  {"id": "farmacia", "text": "Raffreddore: spesa in farmacia.", "amount_cents": -800, "category": "Altro"}
]
L["weekly_goal_options"] = [
  {"id": "cuscinetto", "name": "Fondo imprevisti", "target_cents": 30000},
  {"id": "auto_ginestra", "name": "Anticipo auto (Ginestra)", "target_cents": 64500},
  {"id": "monolocale", "name": "Cauzione monolocale", "target_cents": 144000}
]
L["bus_v03"] = {"stops": [
  {"id": "fontana", "name": "Piazza della Fontana", "pos": [-21.0, -5.2]},
  {"id": "roma_est", "name": "Via Roma Est (Autosalone)", "pos": [64.0, 5.2]}
 ], "ride_minutes": 6}
L["gambling"] = {"enabled": False, "note": "nessun gioco d'azzardo e nessuna speculazione: l'unica rendita passiva è il conto risparmio"}
L["_source"] = "Ledger reallife-ledger-v03.md (STIME, centesimi). Correzioni: nomi auto inventati (Guard), nomi luoghi (Spark), luoghi/eventi/serbatoio aggiunti (STIMA) da tools/make_life_json.py"
json.dump(L, open(sys.argv[1], "w"), ensure_ascii=False, indent=1)
print("ok", len(json.dumps(L)))
