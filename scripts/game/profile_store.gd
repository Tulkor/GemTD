class_name ProfileStore
extends RefCounted
## Dateien des Spielerprofils (profile.gd) mit Siegel: vorne in der Datei steht eine SHA-256-Prüfsumme
## über den Rest ({"seal":"<hex>", …Werte…}). Die Werte bleiben lesbares JSON für spätere Auswertungen,
## wer sie von Hand ändert, fällt aber auf (Profil.integrity). Geschrieben wird über eine .tmp-Datei,
## damit ein Absturz beim Speichern nie die einzige Fassung zerstört; dazu eine Sicherung pro Tag.

const SALT := "TD-Hub/Profil/1:kristall-schrein"
const PREFIX := "{\"seal\":\""
const BACKUP_DAYS := 7

## Was read() über die Datei sagt
const VALID := "ok"           ## Siegel passt
const UNSIGNED := "unsigned"  ## alte Datei ohne Siegel (vor dem Siegel geschrieben)
const TAMPERED := "tampered"  ## Siegel passt nicht: von Hand geändert
const BROKEN := "broken"      ## kein gültiges JSON
const MISSING := "missing"


static func seal_of(body: String) -> String:
	return (SALT + body).sha256_text()


## d als versiegeltes JSON (pretty = Einrückung, "" = kompakt).
static func encode(d: Dictionary, pretty := "\t") -> String:
	var body := JSON.stringify(d, pretty)
	var rest := body.substr(1)
	return PREFIX + seal_of(body) + "\"" + ("" if rest.strip_edges() == "}" else ",") + rest


## Text lesen: {"data": Dictionary oder null, "state": VALID|UNSIGNED|TAMPERED|BROKEN}.
static func decode(text: String) -> Dictionary:
	# JSON.new().parse meldet kaputte Dateien nicht als Fehler im Log (das übernimmt profile.gd)
	var j := JSON.new()
	var d = j.data if j.parse(text) == OK else null
	if not d is Dictionary:
		return {"data": null, "state": BROKEN}
	if not text.begins_with(PREFIX) or not d.has("seal"):
		return {"data": d, "state": UNSIGNED}
	var seal := str(d.seal)
	d.erase("seal")
	var after := PREFIX.length() + seal.length() + 1
	var rest := text.substr(after)
	var body := "{" + (rest.substr(1) if rest.begins_with(",") else rest)
	return {"data": d, "state": VALID if seal_of(body) == seal else TAMPERED}


static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"data": null, "state": MISSING}
	return decode(FileAccess.get_file_as_string(path))


## Sicher schreiben: erst path.tmp, dann umbenennen. Vorher die alte Fassung nach path.bak.
static func write(path: String, d: Dictionary, pretty := "\t", keep_bak := false) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Profil nicht speicherbar: %s" % path)
		return false
	f.store_string(encode(d, pretty))
	f.close()
	if FileAccess.file_exists(path):
		if keep_bak:
			DirAccess.copy_absolute(path, path + ".bak")
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


## Einmal am Tag eine Kopie unter backups/ (die letzten BACKUP_DAYS Tage bleiben).
static func daily_backup(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var bdir := path.get_base_dir().path_join("backups")
	DirAccess.make_dir_recursive_absolute(bdir)
	var name := "%s_%s.json" % [path.get_file().get_basename(), Time.get_date_string_from_system()]
	if not FileAccess.file_exists(bdir.path_join(name)):
		DirAccess.copy_absolute(path, bdir.path_join(name))
	var files := Array(DirAccess.get_files_at(bdir)).filter(func(n): return n.begins_with(path.get_file().get_basename() + "_"))
	files.sort()
	while files.size() > BACKUP_DAYS:
		DirAccess.remove_absolute(bdir.path_join(files.pop_front()))


## Neueste lesbare Sicherung (für den Fall, dass profile.json und .bak kaputt sind).
static func newest_backup(path: String) -> Dictionary:
	var bdir := path.get_base_dir().path_join("backups")
	var files := Array(DirAccess.get_files_at(bdir)) if DirAccess.dir_exists_absolute(bdir) else []
	files.sort()
	files.reverse()
	for n in files:
		var r := read(bdir.path_join(n))
		if r.data is Dictionary:
			return r
	return {"data": null, "state": MISSING}
