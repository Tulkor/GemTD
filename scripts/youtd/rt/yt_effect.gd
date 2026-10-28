class_name YtEffect
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Effekte der Fähigkeiten. YouTD 2 spielt Sprite-Animationen (Pfade "res://src/effects/<name>.tscn"); deren Bilder
## stehen unter CC-BY-NC und sind nicht im Spiel. Wir ordnen jeden Namen über Stichwörter einem unserer Treffer-
## Effekte (data/fx/hits) zu; Effekte, die bleiben, bekommen dazu einen Ring in ihrer Farbe (YtWorld._update_effects).

const Z_INDEX_BELOW_CREEPS: int = 9
const Z_INDEX_BELOW_TOWERS: int = 19

## Stichwort im Effektnamen → Treffer-Effekt (erste passende Zeile gilt)
const KEYWORDS: Array = [
	["level_up", "gold_star"], ["stun", "yellow_spark"], ["blood", "red_spark"],
	["frost", "cyan_shock"], ["freez", "cyan_shock"], ["ice", "blue_ring"], ["ziggurat", "cyan_shock"],
	["thunder", "kb_shock_ring"], ["warstomp", "kb_shock_ring"], ["roar", "kb_shock_ring"], ["shockwave", "kb_shock_ring"],
	["crushing_wave", "teal_ring"], ["monsoon", "lime_shock"], ["storm", "lime_shock"], ["lightning", "lime_shock"],
	["firelord", "bk_explosion"], ["frag_boom", "bk_explosion"], ["barrel", "bk_explosion"], ["mortar", "bk_explosion"],
	["death_explode", "bk_explosion"], ["fire", "orange_fire"], ["flame", "bk_fire"], ["incinerate", "bk_fire"],
	["immolation", "bk_fire"], ["holy_bolt_green", "green_poison"], ["holy", "gold_star"], ["starfall", "gold_star"],
	["moonwell", "kb_magic_ring"], ["astral", "gold_star"], ["revive", "gold_star"], ["spell_aire", "gold_star"],
	["death_coil", "violet_dark"], ["doom", "violet_dark"], ["darkness", "violet_dark"], ["zombify", "violet_dark"],
	["skeleton", "violet_dark"], ["undead", "violet_dark"], ["naga", "violet_dark"], ["devour", "violet_dark"],
	["crypt", "violet_dark"], ["wisp", "blue_magic"], ["mana", "blue_magic"], ["arcane", "purple_magic"],
	["spell_breaker", "purple_magic"], ["purge", "purple_magic"], ["charm", "pink_star"], ["blink", "purple_magic"],
	["teleport", "purple_magic"], ["silence", "blue_ring"], ["nature", "kb_nature_rays"], ["roots", "kb_nature_rays"],
	["keeper_grove", "green_poison"], ["chimaera", "green_poison"], ["acid", "green_poison"], ["ancient", "kb_nature_rays"],
	["ne_", "kb_nature_rays"], ["voodoo", "rose_fire"], ["vampiric", "rose_fire"], ["impale", "brown_dirt"],
	["dust", "brown_dirt"], ["iron", "white_slash"], ["glaive", "white_slash"], ["shackle", "white_slash"],
	["cripple", "white_slash"], ["fog", "teal_ring"], ["cyclone", "teal_ring"], ["spirit", "kb_magic_ring"],
	["spell_a", "kb_magic_ring"], ["witch", "green_poison"], ["stampede", "brown_dirt"], ["upgrade", "gold_star"],
]
## Grundfarbe je Treffer (für die Ringe und für set_color)
const HIT_COLORS := {
	"red_spark": Color(1, 0.25, 0.2), "orange_fire": Color(1, 0.55, 0.15), "brown_dirt": Color(0.7, 0.5, 0.3),
	"gold_star": Color(1, 0.85, 0.3), "yellow_spark": Color(1, 0.95, 0.3), "lime_shock": Color(0.7, 1, 0.3),
	"green_poison": Color(0.35, 0.9, 0.3), "teal_ring": Color(0.3, 0.9, 0.75), "cyan_shock": Color(0.3, 0.9, 1),
	"blue_ring": Color(0.35, 0.55, 1), "blue_magic": Color(0.3, 0.45, 1), "violet_dark": Color(0.55, 0.25, 0.8),
	"purple_magic": Color(0.75, 0.35, 1), "pink_star": Color(1, 0.45, 0.8), "rose_fire": Color(1, 0.3, 0.45),
	"white_slash": Color(0.9, 0.9, 0.95), "white_spark": Color(1, 1, 1), "bk_explosion": Color(1, 0.6, 0.2),
	"bk_fire": Color(1, 0.5, 0.15), "kb_shock_ring": Color(0.8, 0.85, 1), "kb_nature_rays": Color(0.5, 1, 0.4),
	"kb_magic_ring": Color(0.6, 0.5, 1), "kb_splash": Color(0.4, 0.7, 1),
}
## Farbton → Treffer, wenn ein Skript die Farbe eines Effekts setzt
const HUE_HITS: Array = [[0.0, "red_spark"], [0.07, "orange_fire"], [0.14, "yellow_spark"], [0.24, "lime_shock"],
	[0.33, "green_poison"], [0.45, "teal_ring"], [0.52, "cyan_shock"], [0.62, "blue_ring"], [0.75, "purple_magic"],
	[0.88, "pink_star"], [0.96, "red_spark"]]

static var _cache := {}


## Treffer-Effekt für einen YouTD-Effektpfad.
static func hit_for(path: String) -> String:
	if _cache.has(path):
		return _cache[path]
	var n := path.get_file().get_basename().to_lower()
	var out := "white_spark"
	for k in KEYWORDS:
		if n.contains(k[0]):
			out = k[1]
			break
	_cache[path] = out
	return out


static func hit_color(hit: String) -> Color:
	return HIT_COLORS.get(hit, Color.WHITE)


static func _make(effect_path: String, pos: Vector3, unit: YtUnit = null, part: YtUnit.BodyPart = YtUnit.BodyPart.CHEST, z: float = 0.0, attached := false) -> int:
	if YtWorld.node == null:
		return 0
	return YtWorld.node.new_effect({"hit": hit_for(effect_path), "pos": pos, "unit": unit if attached else null, "part": part,
			"z": z, "scale": 1.0, "color": Color.WHITE, "life": 0.0, "auto": true, "node": null, "shown": false})


static func _entry(effect_id: int) -> Dictionary:
	if YtWorld.node == null:
		return {}
	return YtWorld.node.get_effect(effect_id)


# NOTE: Effect.createAnimated() in JASS
static func create_animated(effect_path: String, effect_pos: Vector3, _facing: float) -> int:
	return _make(effect_path, effect_pos)


# NOTE: Effect.createAnimatedScaled() in JASS
static func create_animated_scaled(effect_path: String, effect_pos: Vector3, facing: float, scale: float) -> int:
	var effect: int = create_animated(effect_path, effect_pos, facing)
	set_scale(effect, scale)
	return effect


# NOTE: Effect.createSimple() in JASS
static func create_simple(effect_path: String, effect_pos: Vector2) -> int:
	return create_animated(effect_path, Vector3(effect_pos.x, effect_pos.y, 0), 0.0)


# Creates an effect at position of unit. Effect will *not* follow the unit if it moves.
# NOTE: Effect.createSimpleAtUnit() in JASS
static func create_simple_at_unit(effect_path: String, unit: YtUnit, body_part: YtUnit.BodyPart = YtUnit.BodyPart.CHEST, z_offset: float = 0.0) -> int:
	if unit == null or not is_instance_valid(unit):
		return create_animated(effect_path, Vector3.ZERO, 0.0)
	return _make(effect_path, unit.get_body_part_position(body_part), null, body_part, z_offset)


# Creates an effect on the unit. Effect will follow the unit and go away if the unit dies.
# NOTE: Effect.createSimpleOnUnit() in JASS
static func create_simple_at_unit_attached(effect_path: String, unit: YtUnit, body_part: YtUnit.BodyPart = YtUnit.BodyPart.CHEST, z_offset: float = 0.0) -> int:
	if unit == null or not is_instance_valid(unit):
		return create_animated(effect_path, Vector3.ZERO, 0.0)
	return _make(effect_path, unit.get_body_part_position(body_part), unit, body_part, z_offset, true)


# NOTE: AddSpecialEffect() in JASS()
static func add_special_effect(effect_path: String, effect_pos: Vector2) -> int:
	return create_simple(effect_path, effect_pos)


# NOTE: Effect.createScaled() in JASS()
static func create_scaled(effect_path: String, effect_pos: Vector3, facing: float, scale: float) -> int:
	return create_animated_scaled(effect_path, effect_pos, facing, scale)


# NOTE: Effect.createColored() in JASS()
static func create_colored(effect_path: String, effect_pos: Vector3, facing: float, scale: float, color: Color) -> int:
	var effect: int = create_animated_scaled(effect_path, effect_pos, facing, scale)
	set_color(effect, color)
	return effect


# NOTE: effect.setScale() in JASS()
static func set_scale(effect_id: int, scale: float) -> void:
	var e := _entry(effect_id)
	if not e.is_empty():
		e.scale = scale


static func set_color(effect_id: int, color: Color) -> void:
	var e := _entry(effect_id)
	if e.is_empty():
		return
	e.color = color
	if not e.shown and color.s > 0.25:
		var best: String = e.hit
		var dist := 2.0
		for h in HUE_HITS:
			var d := absf(color.h - float(h[0]))
			if d < dist:
				dist = d
				best = h[1]
		e.hit = best


# Effect stays for the given time.
# NOTE: effect.setLifetime() in JASS()
static func set_lifetime(effect_id: int, lifetime: float) -> void:
	var e := _entry(effect_id)
	if not e.is_empty():
		e.life = lifetime


static func set_animation_speed(_effect_id: int, _speed: float) -> void:
	pass


# NOTE: Effect.destroy() and DestroyEffect() in JASS()
static func destroy_effect(effect_id: int) -> void:
	if YtWorld.node != null:
		YtWorld.node.remove_effect(effect_id)


# Disabled = the effect stays until destroy_effect().
static func set_auto_destroy_enabled(effect_id: int, enabled: bool) -> void:
	var e := _entry(effect_id)
	if not e.is_empty():
		e.auto = enabled


static func set_position(effect_id: int, pos_wc3: Vector2) -> void:
	var e := _entry(effect_id)
	if not e.is_empty():
		e.pos = Vector3(pos_wc3.x, pos_wc3.y, 0)


static func set_z_index(_effect_id: int, _z_index) -> void:
	pass
