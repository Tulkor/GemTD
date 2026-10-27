class_name YtWorld
extends Node3D
## Laufzeit für die Fähigkeiten aus YouTD 2 (MIT, github.com/Praytic/youtd2): Uhr, Zufall, Takt aller
## YtManualTimer, Tower-Angriffe, Gegner-Werte und Geschosse. youtd_game.gd hängt genau eine Welt an das Spielfeld;
## die portierten Klassen (Yt…) finden sie über YtWorld.node, wie in YouTD 2 die Autoloads.
##
## Einheiten: Positionen rechnen in WC3-Einheiten (128 = eine Towerbreite, wie YouTD 2). Unser Spielfeld hat
## Towerbreiten, x/y in WC3 = x/z im 3D-Feld × 128, die Höhe z (WC3) = y im 3D-Feld × 128.

const TICKS_PER_SECOND := 30
const WC3 := 128.0

static var node: YtWorld = null
static var game = null   ## youtd_game.gd

var time := 0.0
var _uid := 0
var effects := {}         ## id -> {node, t (Restzeit, < 0 = bleibt), unit, offset}
var _effect_id := 0
var fx: FxPlayer
var projectile_view: YtProjectileView
var floating: Array = []  ## schwebende Texte {label, t}


func _enter_tree() -> void:
	node = self


func _exit_tree() -> void:
	if node == self:
		node = null
		game = null


func _ready() -> void:
	fx = FxPlayer.new()
	add_child(fx)
	projectile_view = YtProjectileView.new()
	add_child(projectile_view)


## Knoten, unter dem alle Items (YtItem) hängen, egal ob im Lager, am Boden oder im Tower.
func item_holder() -> Node:
	var h := get_node_or_null("items")
	if h == null:
		h = Node.new()
		h.name = "items"
		add_child(h)
	return h


static func next_uid() -> int:
	if node == null:
		return 0
	node._uid += 1
	return node._uid


static func get_time() -> float:
	return node.time if node != null else 0.0


static func get_tick() -> int:
	return floori(get_time() * TICKS_PER_SECOND)


## WC3-Position (x, y, Höhe) → Punkt im 3D-Feld.
static func to_3d(p: Vector3) -> Vector3:
	return Vector3(p.x / WC3, p.z / WC3, p.y / WC3)


## Punkt im 3D-Feld → WC3-Position.
static func from_3d(p: Vector3) -> Vector3:
	return Vector3(p.x * WC3, p.z * WC3, p.y * WC3)


static func group(name: String) -> Array:
	if node == null or not node.is_inside_tree():
		return []
	return node.get_tree().get_nodes_in_group(name)


func _process(delta: float) -> void:
	if game == null or not game.setup_done or game.phase >= game.Phase.GAME_OVER:
		return
	time += delta
	for t in get_tree().get_nodes_in_group("yt_timers"):
		if is_instance_valid(t) and not t.is_queued_for_deletion():
			t.update(delta)
	for u in get_tree().get_nodes_in_group("yt_units"):
		if is_instance_valid(u) and not u.is_queued_for_deletion() and u.is_inside_tree():
			u.update(delta)
	for p in get_tree().get_nodes_in_group("yt_projectiles"):
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p.is_inside_tree():
			p.update(delta)
	projectile_view.refresh()
	_update_effects(delta)
	_update_floating(delta)


# --- Effekte (YtEffect) --------------------------------------------------------------
# Ein Effekt ist ein Eintrag {hit, pos, unit, part, z, scale, color, life, auto, node, shown}. Einmal-Effekte spielen am
# Ende des Takts als Treffer im FxPlayer ab (so wirken set_scale/set_color direkt nach dem Erzeugen noch); wer
# sie behält (Lebensdauer, an Einheit, auto aus), bekommt zusätzlich einen leuchtenden Ring, bis er endet.

func new_effect(e: Dictionary) -> int:
	_effect_id += 1
	effects[_effect_id] = e
	return _effect_id


func get_effect(id: int) -> Dictionary:
	return effects.get(id, {})


func remove_effect(id: int) -> void:
	var e: Dictionary = effects.get(id, {})
	if e.is_empty():
		return
	if e.get("node") != null and is_instance_valid(e.node):
		e.node.queue_free()
	effects.erase(id)


func _effect_pos(e: Dictionary) -> Vector3:
	var u = e.get("unit")
	if u != null and YtUtils.unit_is_valid(u):
		e.pos = u.get_body_part_position(e.part)
	return to_3d(e.pos + Vector3(0, 0, e.z))


func _update_effects(delta: float) -> void:
	var headless := DisplayServer.get_name() == "headless"
	for id in effects.keys():
		var e: Dictionary = effects[id]
		var u = e.get("unit")
		if u != null and not YtUtils.unit_is_valid(u):
			remove_effect(id)
			continue
		if not e.shown:
			e.shown = true
			if not headless:
				fx.play_hit({"id": e.hit}, _effect_pos(e), clampf(e.scale, 0.3, 3.0))
		var keep: bool = e.life > 0.0 or not e.auto
		if not keep:
			remove_effect(id)
			continue
		if not headless:
			if e.node == null:
				e.node = _effect_ring(e)
				add_child(e.node)
			e.node.position = _effect_pos(e)
			e.node.rotation.y += delta * 1.5
		if e.life > 0.0:
			e.life -= delta
			if e.life <= 0.0:
				remove_effect(id)


## Leuchtender Ring für Effekte, die eine Weile bleiben (Buffs, Zonen).
func _effect_ring(e: Dictionary) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	var r := 0.28 * clampf(e.scale, 0.3, 4.0)
	t.inner_radius = r * 0.8
	t.outer_radius = r
	t.rings = 24
	t.ring_segments = 6
	m.mesh = t
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var col: Color = e.color if e.color != Color.WHITE else YtEffect.hit_color(e.hit)
	col.a = 0.7
	mat.albedo_color = col
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


# --- Schwebende Texte ------------------------------------------------------------------

func floating_text(text: String, unit, col: Color) -> void:
	if YtUtils.unit_is_valid(unit):
		floating_text_at(text, unit.get_position_wc3(), col)


## Schwebender Text an einer WC3-Position (Vector2 oder Vector3).
func floating_text_at(text: String, pos, col: Color) -> void:
	if DisplayServer.get_name() == "headless" or floating.size() > 40:
		return
	var p3: Vector3 = pos if pos is Vector3 else Vector3(pos.x, pos.y, 0.0)
	var l := Label3D.new()
	l.text = text
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.font_size = 40
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = to_3d(p3) + Vector3(0, 1.0, 0)
	add_child(l)
	floating.append({"label": l, "t": 1.2})


func _update_floating(delta: float) -> void:
	for f in floating.duplicate():
		f.t -= delta
		if f.t <= 0.0 or not is_instance_valid(f.label):
			if is_instance_valid(f.label):
				f.label.queue_free()
			floating.erase(f)
			continue
		f.label.position.y += delta * 0.6
		f.label.modulate.a = clampf(f.t / 0.5, 0.0, 1.0)
