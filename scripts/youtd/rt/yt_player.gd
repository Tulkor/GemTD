class_name YtPlayer
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Der Spieler, wie ihn Tower-Skripte sehen: Gold, Einkommen, schwebende Texte. Alles geht an youtd_game.gd
## (YtWorld.game). Etappe 2: ein Spieler.

static var _local: YtPlayer = null

var team := YtTeam.new()


static func local() -> YtPlayer:
	if _local == null:
		_local = YtPlayer.new()
	return _local


func get_team() -> YtTeam:
	return team


func get_gold() -> float:
	return float(YtWorld.game.gold) if YtWorld.game != null else 0.0


## Gold dazu (show_text: „+12“ in Gold über der Einheit).
func give_gold(amount: float, unit, _show_effect: bool, show_text: bool) -> void:
	if YtWorld.game == null:
		return
	YtWorld.game.earn_gold(amount, YtWorld.game.local_player)
	if show_text and YtUtils.unit_is_valid(unit):
		display_floating_text("+%s" % String.num(amount, 0 if absf(amount) >= 1.0 else 1), unit, Color.GOLD)


func add_gold(amount: float, _source_is_income: bool = false) -> void:
	if YtWorld.game != null:
		YtWorld.game.earn_gold(amount, YtWorld.game.local_player)


func modify_income_rate(amount: float) -> void:
	if YtWorld.game != null:
		YtWorld.game.income_rate += amount


func get_num_towers() -> int:
	return YtWorld.group("yt_towers").size()


func get_max_tower_level() -> int:
	return int(YtWorld.game.max_tower_level()) if YtWorld.game != null else YtConstants.TOWER_MAX_LEVEL_BASE


func get_tower_exp_bonus() -> float:
	return float(YtWorld.game.tower_exp_bonus) if YtWorld.game != null else 0.0


func get_attack_range_bonus() -> float:
	return float(YtWorld.game.range_bonus) if YtWorld.game != null else 0.0


func get_builder() -> YtBuilder:
	return YtBuilder.new()


func get_wisdom_modifier() -> YtModifier:
	return YtWorld.game.wisdom_modifier() if YtWorld.game != null else YtModifier.new()


func add_to_total_damage(_damage: float) -> void:
	pass


func display_floating_text(text: String, unit, color: Color) -> void:
	if YtWorld.node != null:
		YtWorld.node.floating_text(text, unit, color)


func display_floating_text_x(text: String, unit, color: Color, _velocity: float, _fadepoint: float, _time: float) -> void:
	display_floating_text(text, unit, color)


func display_floating_text_x_2(text: String, unit, color: Color, _velocity: float, _fadepoint: float, _time: float, _scale: float, _random_offset: float) -> void:
	display_floating_text(text, unit, color)


func display_small_floating_text(text: String, unit, color: Color, _random_offset: float) -> void:
	display_floating_text(text, unit, color)


func transfer_autooils(_from, _to) -> void:
	pass
