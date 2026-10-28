class_name MaulBank
extends RefCounted
## Konto und Deutsche Bank wie im Original (Chatbefehle -da, -wa, -ad), dazu die Stammkundin vom Tante Emma Laden.
## Werte in data/maul/pro.json unter "bank" und "stammkundin". Rechnet nur der Host (maul_game.gd ruft hier auf).
##   Konto:        Gold einzahlen, am Levelende Zinsen (4 % + 2 % je Bank-Upgrade, höchstens auf 5.000 Gold),
##                 Abheben dauert 25 s − 5 s je Upgrade. Auto-Einzahlen legt am Levelende alles Gold aufs Konto.
##   Deutsche Bank: kein eigenes Konto, bekommt dafür am Levelende 5 % aller Konten (750 Gold ab 15.000).
##   Stammkundin:  ein Altenheim des Tante Emma Ladens bringt alle paar Sekunden Gold, bis der Laden leer ist.

const OWNER := "bank"
const EMMA := "tante_emma"


static func cfg() -> Dictionary:
	return MaulData.pro().get("bank", {})


static func emma_cfg() -> Dictionary:
	return MaulData.pro().get("stammkundin", {})


static func rate(pl) -> float:
	var c := cfg()
	return float(c.get("rate", 0.04)) + float(c.get("rate_step", 0.02)) * pl.bank_level


static func withdraw_delay(pl) -> float:
	var c := cfg()
	return maxf(float(c.get("withdraw_delay", 25)) - float(c.get("delay_step", 5)) * pl.bank_level, 0.0)


## Preis des nächsten Bank-Upgrades (WC3-Forschung: Grundpreis + Aufschlag je Stufe), 0 = keins mehr.
static func upgrade_cost(pl) -> int:
	var c := cfg()
	if pl.bank_level >= int(c.get("levels", 3)):
		return 0
	return int(c.get("cost", 75)) + int(c.get("cost_step", 75)) * pl.bank_level


static func total(g: MaulGame) -> int:
	var sum := 0
	for p in g.players:
		sum += p.account
	return sum


## Anteil der Deutschen Bank am Levelende.
static func owner_income(g: MaulGame) -> int:
	var c := cfg()
	var sum := total(g)
	if sum >= int(c.get("owner_cap_sum", 15000)):
		return int(c.get("owner_cap", 750))
	return floori(sum * float(c.get("owner_share", 0.05)))


## Befehle deposit, withdraw, auto_deposit, bank_upgrade für Spieler p. Gibt false zurück, wenn nichts geschah.
static func execute(g: MaulGame, p: int, type: String) -> bool:
	var pl: MaulGame.Player = g.players[p]
	if pl.shop == OWNER:
		g._tell(p, tr_("Die Teutsche Bank kann kein Konto nutzen"))
		return false
	match type:
		"deposit":
			if pl.gold <= 0:
				return false
			pl.account += pl.gold
			g._tell(p, tr_("%d Gold eingezahlt, Kontostand %d Gold") % [pl.gold, pl.account])
			pl.gold = 0
		"withdraw":
			if pl.account <= 0:
				return false
			if pl.withdraw_in > 0.0:
				g._tell(p, tr_("Die Überweisung läuft bereits"))
				return false
			pl.withdraw_in = withdraw_delay(pl)
			if pl.withdraw_in <= 0.0:
				_pay_out(pl)
			else:
				g._tell(p, tr_("%d Gold abgehoben, Überweisung in %d s") % [pl.account, roundi(pl.withdraw_in)])
		"auto_deposit":
			pl.auto_deposit = not pl.auto_deposit
		"bank_upgrade":
			var cost := upgrade_cost(pl)
			if cost <= 0:
				return false
			if cost > pl.gold:
				g._tell(p, tr_("Zu wenig Gold"))
				return false
			pl.gold -= cost
			pl.bank_level += 1
		_:
			return false
	return true


## Laufende Überweisungen und Stammkundin (Spielzeit, nur Host).
static func process(g: MaulGame, delta: float) -> bool:
	var changed := false
	for pl in g.players:
		if pl.withdraw_in > 0.0:
			pl.withdraw_in -= delta
			if pl.withdraw_in <= 0.0:
				_pay_out(pl)
				changed = true
	var e := emma_cfg()
	if e.is_empty():
		return changed
	var mine := int(e.get("mine", 15000))
	for i in g.players.size():
		var pl: MaulGame.Player = g.players[i]
		if pl.shop != EMMA or pl.emma_mined >= mine or not has_customer(g, i):
			continue
		pl.emma_timer += delta
		var trip := maxf(float(e.get("trip", 10.0)), 0.5)
		while pl.emma_timer >= trip and pl.emma_mined < mine:
			pl.emma_timer -= trip
			var gold := mini(int(e.get("gold_per_trip", 10)), mine - pl.emma_mined)
			pl.emma_mined += gold
			pl.gold += gold
			changed = true
	return changed


## Hat Spieler p ein Altenheim (dann gibt es genau eine Stammkundin)?
static func has_customer(g: MaulGame, p: int) -> bool:
	var id := str(emma_cfg().get("tower", "n008"))
	for t in g.towers.values():
		if t.owner_player == p and t.tower_id == id:
			return true
	return false


## Levelende: Auto-Einzahlen, Zinsen, Anteil der Deutschen Bank. Gibt die Meldung für den lokalen Spieler zurück.
static func end_level(g: MaulGame) -> String:
	var c := cfg()
	var owner_gets := 0
	for pl in g.players:
		if pl.shop == OWNER:
			if pl.account > 0:
				pl.gold += pl.account
				pl.account = 0
			continue
		if pl.auto_deposit and pl.gold > 0:
			pl.account += pl.gold
			pl.gold = 0
	owner_gets = owner_income(g)
	var text := ""
	for i in g.players.size():
		var pl: MaulGame.Player = g.players[i]
		if pl.shop == OWNER:
			pl.gold += owner_gets
			if i == g.local_player and owner_gets > 0:
				text = tr_("Zinsen: +%d Gold (5 %% aller Konten)") % owner_gets
		elif pl.account > 0:
			var interest := floori(mini(pl.account, int(c.get("cap", 5000))) * rate(pl))
			pl.account += interest
			if i == g.local_player:
				text = tr_("Zinsen: +%d Gold (%d %%), Kontostand %d Gold") % [interest, roundi(rate(pl) * 100.0), pl.account]
	return text


static func _pay_out(pl) -> void:
	pl.gold += pl.account
	pl.account = 0
	pl.withdraw_in = 0.0


static func tr_(text: String) -> String:
	return str(TranslationServer.translate(text))
