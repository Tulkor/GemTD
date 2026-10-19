class_name FieldStyle
extends RefCounted
## Aussehen des 3D-Spielfelds je Oberflächen-Stil (UiTheme.skin): Boden, Raster, Sperrzonen, Wegpunkte,
## Felsbrocken, Tower-Sockel, Licht und Himmel. Board3D, Tower und CameraRig lesen current().
## - Arcade (GemTD): Neon-Gitter über dem Weltraum, wie bisher.
## - Druidenhain (eeveTD): Gras und Erde bei Tageslicht, dunkles Raster wie in den Boden geritzt, Steinsockel.
## - Art déco (Shopping Maul): Petrol-Marmor mit Messingfugen und Messingrauten, Messingsockel, Abendlicht.

const NEON := "neon"
const DRUID := "druid"
const DECO := "deco"

## Werte je Stil. "floor" sind Parameter für neon_floor.gdshader, "env" für CameraRig.add_environment.
const STYLES := {
	NEON: {
		"ground_alpha": 0.0,
		"floor": {},
		"path": Color("2ef2e0"), "path_energy": 2.2,
		"marker": Color("ff36d8"), "marker_energy": 2.2,
		"rock": "glass",
		"base": "glass",
	},
	DRUID: {
		"ground_alpha": 1.0,
		"ground": {
			"brightness": 0.5, "saturation": 0.55, "tint": Vector3(0.9, 0.97, 0.8),
			"grass_tile": 2.6, "detail_blur": 2.2, "grass_contrast": 0.4, "normal_strength": 0.35,
		},
		"floor": {
			"floor_alpha": 0.0,
			"line_color": Color("1c2416"), "edge_color": Color("3a2a1a"),
			"line_energy": 1.0, "major_energy": 1.0, "minor_energy": 1.0, "cell_energy": 1.0,
			"cell_alpha": 0.0, "minor_alpha": 0.2, "major_alpha": 0.42,
			"edge_energy": 1.0, "core_white": 0.0, "halo_width": 0.004, "line_width": 0.012,
			"zone_color": Color("b0563a"), "zone_alpha": 0.28, "zone_edge_energy": 0.9,
			"zone_edge_color": Color("5a2a18"),
		},
		"path": Color("e8d27a"), "path_energy": 1.3,
		"marker": Color("d8c888"), "marker_energy": 1.0,
		"rock": "stone",
		"base": "stone",
		"env": {
			"sky_top": Color("6f97a8"), "sky_horizon": Color("c9d6b8"), "ground_bottom": Color("2e3a26"),
			"ambient": Color("b8c6d0"), "ambient_energy": 0.2,
			"sun": Color("ffecc8"), "sun_energy": 1.55, "sun_pitch": -36.0,
			"fog": Color("8a9a80"), "fog_density": 0.0015,
			"glow_threshold": 1.4, "glow_intensity": 0.5, "exposure": 0.95,
		},
	},
	DECO: {
		"ground_alpha": 0.0,
		"floor": {
			"floor_color": Color("0f2a2c"), "floor_alpha": 1.0,
			"line_color": Color("c9a36a"), "edge_color": Color("d8b97f"),
			"line_energy": 1.0, "major_energy": 1.0, "minor_energy": 0.55, "cell_energy": 0.5,
			"cell_alpha": 0.0, "minor_alpha": 0.22, "major_alpha": 0.9,
			"edge_energy": 1.1, "core_white": 0.0, "halo_width": 0.004, "line_width": 0.011,
			"major_double": 1.0, "diamond_size": 0.2, "marble": 1.0,
			"blocked_color": Color("071618"), "blocked_alpha": 1.0,
			"zone_color": Color("b4553f"), "zone_alpha": 0.3, "zone_edge_energy": 1.0,
			"zone_edge_color": Color("d8b97f"),
		},
		"path": Color("d8b97f"), "path_energy": 1.25,
		"marker": Color("d8b97f"), "marker_energy": 1.2,
		"zone_own": Color("e8c87a"), "zone_other": Color("4d7a78"), "zone_leak": Color("b4553f"),
		"rock": "marble",
		"base": "brass",
		"env": {
			"sky_top": Color("061517"), "sky_horizon": Color("1d4446"), "ground_bottom": Color("061214"),
			"ambient": Color("9fc8c0"), "ambient_energy": 0.42,
			"sun": Color("ffe2b0"), "sun_energy": 0.95, "sun_pitch": -42.0,
			"glow_threshold": 1.0, "glow_intensity": 0.6, "exposure": 1.0,
		},
	},
}


## Name des Stils, der zum aktiven Oberflächen-Stil passt.
static func current_name() -> String:
	match UiTheme.skin:
		UiTheme.DRUID:
			return DRUID
		UiTheme.DECO:
			return DECO
	return NEON


static func current() -> Dictionary:
	return STYLES[current_name()]


static func is_neon() -> bool:
	return current_name() == NEON


## Material für Wegpunkt-Ringe, Zonenränder und Wegpunkte: Neonröhre im Arcade-Stil,
## sonst Metall bzw. warmes Licht in der Stilfarbe (leicht leuchtend, energy wie bei Neon).
static func line_material(col: Color, energy: float) -> Material:
	if is_neon():
		return Board3D.neon_material(col, energy)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.85 if current_name() == DECO else 0.0
	m.roughness = 0.3 if current_name() == DECO else 0.7
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = maxf(energy - 1.0, 0.0) * 0.6 + 0.15
	return m
