class_name YtPlayer
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Ein Spieler in YouTD: was ihm allein gehört (Bücher, Food, Elemente, Tower- und Item-Lager, Baumeister, Weisheit,
## Einkommen). Gold liegt wie in allen Modi in PlayerState (game.players[id].gold). youtd_game.gd hat je Spieler einen
## (yt_players); seine Variablen tomes, elements, stash … meinen den gerade handelnden Spieler (acting).

var id := 0
var team := YtTeam.new()

var tomes := 0
var food_cap := 0
var elements := {}           ## Element -> Stufe
var stash: Array = []        ## gewürfelte Tower-IDs, die noch gebaut werden können
var item_stash: Array = []   ## YtItem im Lager
var can_reroll := true       ## Startwurf wiederholen, bis der erste Tower steht
var score := 0.0

## Weisheits-Boni (vor dem Start gewählt) und was daraus folgt
var wisdom: Array = []
var wisdom_mods := {}
var range_bonus := 0.0
var tower_exp_bonus := 0.0
var element_max_bonus := 0
var tower_max_bonus := 0
var level_at_start := 0

var builder_id := ""
var builder: YtBuilder = null
var builder_wisdom_multiplier := 1.0
var income_rate := 1.0       ## Faktor aufs Welleneinkommen
var interest_rate := 0.05


func _init(player_id := 0) -> void:
	id = player_id


## Spieler, dessen Befehl oder Ansicht gerade gilt (solo: der einzige).
static func local() -> YtPlayer:
	if YtWorld.game != null and not YtWorld.game.yt_players.is_empty():
		return YtWorld.game.yp()
	return _fallback()


static func of(player_id: int) -> YtPlayer:
	if YtWorld.game != null and player_id >= 0 and player_id < YtWorld.game.yt_players.size():
		return YtWorld.game.yt_players[player_id]
	return local()


static var _spare: YtPlayer = null
static func _fallback() -> YtPlayer:
	if _spare == null:
		_spare = YtPlayer.new()
	return _spare


func get_id() -> int:
	return id


func get_team() -> YtTeam:
	return team


func get_gold() -> float:
	if YtWorld.game == null or id >= YtWorld.game.players.size():
		return 0.0
	return float(YtWorld.game.players[id].gold)


## Gold dazu (show_text: „+12“ in Gold über der Einheit).
func give_gold(amount: float, unit, _show_effect: bool, show_text: bool) -> void:
	if YtWorld.game == null:
		return
	YtWorld.game.earn_gold(amount, id)
	if show_text and YtUtils.unit_is_valid(unit):
		display_floating_text("+%s" % String.num(amount, 0 if absf(amount) >= 1.0 else 1), unit, Color.GOLD)


func add_gold(amount: float, _source_is_income: bool = false) -> void:
	if YtWorld.game != null:
		YtWorld.game.earn_gold(amount, id)


func add_tomes(amount: int) -> void:
	tomes = maxi(0, tomes + amount)


func get_tomes() -> int:
	return tomes


func modify_food_cap(amount: int) -> void:
	var cap := int(YoutdData.rules().get("start", {}).get("food_max", 300))
	food_cap = clampi(food_cap + amount, 0, cap)


func modify_income_rate(amount: float) -> void:
	income_rate += amount


func modify_interest_rate(amount: float) -> void:
	interest_rate += amount


func set_builder_wisdom_multiplier(value: float) -> void:
	builder_wisdom_multiplier = value


func get_builder_wisdom_multiplier() -> float:
	return builder_wisdom_multiplier


func get_num_towers() -> int:
	return YtWorld.group("yt_towers").filter(func(t): return t.get_player() == self).size()


func get_max_tower_level() -> int:
	var tl: Dictionary = YoutdData.rules().get("tower_levels", {})
	return mini(int(tl.get("max", 25)) + tower_max_bonus, int(tl.get("max_bonus", 30)))


func get_tower_exp_bonus() -> float:
	return tower_exp_bonus


func get_attack_range_bonus() -> float:
	return range_bonus


func get_builder() -> YtBuilder:
	if builder == null:
		builder = YtBuilder.new()
	return builder


## Baumeister setzen (vor dem Start): Knoten unter YtWorld, einmalige Wirkung auf den Spieler.
func set_builder(bid: String) -> void:
	if builder != null and is_instance_valid(builder):
		builder.queue_free()
	builder_id = bid
	builder = YtBuilder.create_instance(bid)
	if YtWorld.node != null:
		YtWorld.node.add_child(builder)
	builder.apply_to_player(self)


func get_wisdom_modifier() -> YtModifier:
	var m := YtModifier.new()
	for k in wisdom_mods:
		m.add_modification(YtModificationType.from_string(str(k)), float(wisdom_mods[k]), 0.0)
	return m


func add_to_total_damage(_damage: float) -> void:
	pass


func display_floating_text(text: String, unit, color: Color) -> void:
	if YtWorld.node != null:
		YtWorld.node.floating_text(text, unit, color)


func display_floating_text_at_pos(text: String, pos, color: Color) -> void:
	if YtWorld.node != null:
		YtWorld.node.floating_text_at(text, pos, color)


func display_floating_text_x(text: String, unit, color: Color, _velocity: float, _fadepoint: float, _time: float) -> void:
	display_floating_text(text, unit, color)


func display_floating_text_x_2(text: String, unit, color: Color, _velocity: float, _fadepoint: float, _time: float, _scale: float, _random_offset: float) -> void:
	display_floating_text(text, unit, color)


func display_small_floating_text(text: String, unit, color: Color, _random_offset: float) -> void:
	display_floating_text(text, unit, color)


func transfer_autooils(_from, _to) -> void:
	pass
