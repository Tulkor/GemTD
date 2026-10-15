"""Liest ein entpacktes .unitypackage (Ordner mit GUID-Unterordnern) als Python-Daten.

Nur so viel Unity-YAML, wie die Effekt-Umwandlung braucht: Prefabs, Materialien, Texturen.
"""
import os
import re

import yaml

_DOC = re.compile(r"^--- !u!(\d+) &(-?\d+)(?: stripped)?\s*$", re.M)


class _Loader(yaml.SafeLoader):
	pass


def _ignore_tag(loader, suffix, node):
	if isinstance(node, yaml.MappingNode):
		return loader.construct_mapping(node, deep=True)
	if isinstance(node, yaml.SequenceNode):
		return loader.construct_sequence(node, deep=True)
	return loader.construct_scalar(node)


_Loader.add_multi_constructor("", _ignore_tag)


def lade_paket(ordner):
	"""{pfad: {"guid", "datei", "meta"}} für alle Einträge des entpackten Pakets."""
	eintraege = {}
	for guid in os.listdir(ordner):
		pn = os.path.join(ordner, guid, "pathname")
		if not os.path.isfile(pn):
			continue
		with open(pn, encoding="utf-8") as f:
			pfad = f.readline().strip()
		eintraege[pfad] = {"guid": guid, "datei": os.path.join(ordner, guid, "asset")}
	return eintraege


def lade_yaml(datei):
	"""{fileID: (classID, daten)} aus einer Unity-YAML-Datei."""
	with open(datei, encoding="utf-8", errors="replace") as f:
		text = f.read()
	teile = _DOC.split(text)
	objekte = {}
	# teile = [kopf, klasse, id, inhalt, klasse, id, inhalt, ...]
	for i in range(1, len(teile) - 2, 3):
		klasse, fid, inhalt = int(teile[i]), teile[i + 1], teile[i + 2]
		daten = yaml.load(inhalt, Loader=_Loader) or {}
		objekte[fid] = (klasse, next(iter(daten.values())) if daten else {})
	return objekte
