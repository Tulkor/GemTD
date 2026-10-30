extends SceneTree
## Liest aus der Spieldatei von YouTD 2 (YouTD2.pck, Release für Windows) die englischen Texte zu allen Zeilen
## der CSV-Tabellen unter res://data/ (Namen, Beschreibungen). Aufruf über tools/youtd/texte_holen.py.
func _init():
	var a := OS.get_cmdline_user_args()
	ProjectSettings.load_resource_pack(a[0], false)
	var tr_en: Translation = load("res://assets/texts/texts.en.translation")
	var out := {}
	var da := DirAccess.open("res://data")
	print("DATA ", da.get_files())
	for f in da.get_files():
		if not f.ends_with(".csv"):
			continue
		var fa := FileAccess.open("res://data/" + f, FileAccess.READ)
		if fa == null:
			continue
		var head := fa.get_csv_line()
		var tab := {}
		while not fa.eof_reached():
			var row := fa.get_csv_line()
			if row.size() < head.size():
				continue
			var d := {}
			for i in head.size():
				var col: String = head[i]
				var v: String = row[i]
				if col in ["name", "description", "description_short", "description_long", "tooltip", "extra_text", "flavor_text"] and v.length() > 0:
					d[col] = str(tr_en.get_message(v))
				elif col in ["id", "name_english"]:
					d[col] = v
			tab[row[0]] = d
		out[f.get_basename()] = tab
	var w := FileAccess.open(a[1], FileAccess.WRITE)
	w.store_string(JSON.stringify(out, "\t"))
	quit()
