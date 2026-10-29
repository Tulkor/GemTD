class_name PathLights
extends Node3D
## Lichtpfad: Lichter fliegen im Abstand von INTERVAL Sekunden den Gegnerweg entlang (Umschalter
## „Lichtpfad“ im HUD, gespeichert in Display.path_lights). Jede Bahn ist eine Linie aus Punkten
## (Einheiten, X/Z); die Lichter werden nicht einzeln gespawnt, sondern aus der Zeit berechnet:
## Licht k einer Bahn steht bei Strecke (t * SPEED) mod Abstand + k * Abstand.
## Ein Licht = leuchtender Kopf, ein paar kleiner werdende Schweif-Punkte dahinter und ein flacher
## Schein auf dem Boden, alles als MultiMesh (additiv, auf Papier deckend, unbeleuchtet), damit auch 12 Bahnen billig bleiben.
## Farben je Modus in COLORS, eine Map kann sie mit "path_lights": ["#rrggbb", …] überschreiben;
## mehrere Farben wechseln sich ab.

const INTERVAL := 0.5  ## Sekunden zwischen zwei Lichtern
const SPEED := 4.0  ## Einheiten pro Sekunde (8 Felder)
const HOVER := 0.32  ## Flughöhe über dem Boden
const BOB := 0.06  ## Auf und ab beim Fliegen
const HEAD_SIZE := 0.62
const TRAIL := 4  ## Schweif-Punkte hinter jedem Licht
const TRAIL_GAP := 0.16  ## Abstand der Schweif-Punkte (Einheiten)
const GLOW_SIZE := 1.6  ## Schein auf dem Boden

## Farben je Modus (Session.game_kind), passend zum Spielfeld-Stil.
const COLORS := {
	"gemtd": ["2ef2e0", "ff36d8"],  # Neon: Cyan und Pink im Wechsel
	"eevetd": ["d9ff6b", "ffd36b"],  # Druidenhain: Glühwürmchen
	"shoppingmaul": ["ffd27a"],  # Art déco: Messinglicht
	"randgruppen": ["e8231a", "1f3fbf"],  # Plakatwand: Signalrot und Kugelschreiberblau (deckend auf Papier)
}

## Helligkeit je Spielfeld-Stil: Lichtpunkt, Schein auf dem Boden (Art déco blendet sonst mit Bloom,
## auf Papier wäre der Schein nur ein Fleck).
const STRENGTH := {
	FieldStyle.NEON: [1.0, 0.55], FieldStyle.DRUID: [1.0, 0.55], FieldStyle.DECO: [0.45, 0.25], FieldStyle.POSTER: [1.0, 0.0],
}

var board: Board3D
var _head_alpha := 1.0
var _glow_alpha := 0.55
var _lanes: Array = []  ## je Bahn {"pts": PackedVector3Array, "dist": PackedFloat32Array, "len": float}
var _colors: Array[Color] = []
var _time := 0.0
var _heads: MultiMeshInstance3D
var _trail: MultiMeshInstance3D
var _glow: MultiMeshInstance3D


func _init(b: Board3D, kind: String, map_colors: Array = []) -> void:
	board = b
	name = "PathLights"
	var list: Array = map_colors if not map_colors.is_empty() else COLORS.get(kind, COLORS.gemtd)
	for c in list:
		_colors.append(Color(str(c)))
	var st: Array = STRENGTH.get(FieldStyle.current_name(), [1.0, 0.55])
	_head_alpha = st[0]
	_glow_alpha = st[1]
	# auf Papier ein fester Farbpunkt statt weichem Leuchten (sieht sonst nach Rauch aus)
	var dot := _dot_texture() if _on_light_ground() else _glow_texture(0.0)
	_heads = _multimesh(_billboard(HEAD_SIZE, dot))
	_trail = _multimesh(_billboard(HEAD_SIZE * 0.6, dot))
	_glow = _multimesh(_flat(GLOW_SIZE, _glow_texture(0.15)))
	_glow.visible = _glow_alpha > 0.0


## Bahnen setzen: Array aus PackedVector2Array (Punkte in Einheiten, X/Z, in Laufrichtung).
func set_paths(paths: Array) -> void:
	_lanes = []
	for p in paths:
		if p.size() < 2:
			continue
		var pts := PackedVector3Array()
		for q in _smooth(p):
			pts.append(Vector3(q.x, board.ground_y(q) + HOVER, q.y))
		var dist := PackedFloat32Array([0.0])
		for i in range(1, pts.size()):
			dist.append(dist[i - 1] + pts[i].distance_to(pts[i - 1]))
		_lanes.append({"pts": pts, "dist": dist, "len": dist[dist.size() - 1]})
	var count := 0
	for l in _lanes:
		count += lights_on(l.len)
	for mmi in [_heads, _glow]:
		mmi.multimesh.instance_count = count
	_trail.multimesh.instance_count = count * TRAIL
	_update()


## Anzahl Lichter auf einer Bahn der Länge len.
static func lights_on(len: float) -> int:
	return int(ceil(len / (SPEED * INTERVAL))) + 1


func lane_count() -> int:
	return _lanes.size()


func light_count() -> int:
	return _heads.multimesh.instance_count


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _lanes.is_empty():
		return
	_time += delta
	_update()


func _update() -> void:
	var gap := SPEED * INTERVAL
	var phase := fmod(_time * SPEED, gap)
	var n := 0
	var hm := _heads.multimesh
	var tm := _trail.multimesh
	var gm := _glow.multimesh
	for li in _lanes.size():
		var l: Dictionary = _lanes[li]
		var cnt := lights_on(l.len)
		# fortlaufende Nummer je Licht, damit die Farbe beim Weiterrücken am Licht hängen bleibt
		var first := int(floor(_time * SPEED / gap))
		for k in cnt:
			var d: float = phase + k * gap
			var col := _colors[posmod(first - k, _colors.size())]
			# am Anfang ein- und am Ende ausblenden
			var fade := clampf(minf(d, l.len - d) / 0.6, 0.0, 1.0)
			var bob := sin(_time * 5.0 + d * 1.7) * BOB
			var pos := _at(l, d) + Vector3(0, bob, 0)
			var c := Color(col, fade * _head_alpha)
			hm.set_instance_transform(n, Transform3D(Basis(), pos))
			hm.set_instance_color(n, c)
			gm.set_instance_transform(n, Transform3D(Basis(), Vector3(pos.x, pos.y - HOVER - bob + 0.03, pos.z)))
			gm.set_instance_color(n, Color(col, fade * _glow_alpha))
			for j in TRAIL:
				var f := 1.0 - float(j + 1) / (TRAIL + 1)
				var tp := _at(l, d - (j + 1) * TRAIL_GAP) + Vector3(0, bob, 0)
				tm.set_instance_transform(n * TRAIL + j, Transform3D(Basis().scaled(Vector3.ONE * (0.5 + 0.5 * f)), tp))
				tm.set_instance_color(n * TRAIL + j, Color(col, fade * f * 0.8 * _head_alpha))
			n += 1


## Punkt bei Strecke d auf einer Bahn (Binärsuche über die aufsummierten Längen).
func _at(l: Dictionary, d: float) -> Vector3:
	var dist: PackedFloat32Array = l.dist
	var pts: PackedVector3Array = l.pts
	d = clampf(d, 0.0, l.len)
	var i := clampi(dist.bsearch(d), 1, pts.size() - 1)
	var seg := dist[i] - dist[i - 1]
	var t := 0.0 if seg <= 0.0 else (d - dist[i - 1]) / seg
	return pts[i - 1].lerp(pts[i], t)


## Ecken runden (Chaikin, zweimal), damit die Lichter in Kurven fliegen statt abzuknicken.
## Erster und letzter Punkt bleiben.
static func _smooth(p: PackedVector2Array) -> PackedVector2Array:
	var cur := p
	for _r in 2:
		var out := PackedVector2Array([cur[0]])
		for i in cur.size() - 1:
			var a := cur[i]
			var b := cur[i + 1]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		out.append(cur[cur.size() - 1])
		cur = out
	return cur


func _multimesh(mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Die Lichter wandern über die ganze Karte: nie wegschneiden
	mmi.custom_aabb = AABB(Vector3(-1000, -50, -1000), Vector3(2000, 100, 2000))
	add_child(mmi)
	return mmi


func _material(tex: Texture2D, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Auf hellem Papier (Plakatwand) würde additives Licht weiß ausbleichen: dort deckend mischen
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if _on_light_ground() else BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	return m


static func _on_light_ground() -> bool:
	return FieldStyle.current_name() == FieldStyle.POSTER


func _billboard(size: float, tex: Texture2D) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _material(tex, true)
	return q


func _flat(size: float, tex: Texture2D) -> PlaneMesh:
	var q := PlaneMesh.new()
	q.size = Vector2(size, size)
	q.material = _material(tex, false)
	return q


## Runder Lichtpunkt: heller weißer Kern (core > 0 macht ihn weicher), außen in die Farbe auslaufend.
static func _glow_texture(core: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12 + core, 0.4, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.85 - core), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## Fester runder Punkt mit kurzem weichen Rand (Plakatwand).
static func _dot_texture() -> GradientTexture2D:
	var t := _glow_texture(0.0)
	t.gradient.offsets = PackedFloat32Array([0.0, 0.5, 0.7, 1.0])
	t.gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	return t
