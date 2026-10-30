# Netz, Koop, Lobby, Gemischt

Aus CLAUDE.md ausgelagert; der Hook `.claude/hooks/thema.py` blendet diese Notiz automatisch ein, sobald ein Thread passende Dateien anfasst.

- Netz: `scripts/net/` (`coop_sync.gd` gemeinsames Feld, `net_sync.gd`/`remote_field.gd`/`net_panel.gd` Zuschauen im Modus „jeder sein Feld“). Gemischt: in der Lobby hat jeder Spieler eine Feldnummer, gleiche Nummer = Koop-Gruppe (`Net.start_session(map, groups)`, der Erste der Gruppe rechnet, Befehle laufen über den Host weiter, `Net.group_peers()`); Test `tools/run_tests.sh gemischt` (drei Prozesse). Modi hängen sich an Koop und Spielstand über `coop_snapshot`/`save_extra`/`new_tower` im Spiel an (Beispiel eeveTD).
