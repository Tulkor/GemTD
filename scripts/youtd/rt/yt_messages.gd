class_name YtMessages
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Meldungen an einen Spieler: landen im Protokoll der Seitenleiste, wenn er hier spielt.


static func add_normal(player: YtPlayer, text: String) -> void:
	if YtWorld.game != null and (player == null or player.id == YtWorld.game.local_player):
		YtWorld.game._note(text)


static func add_error(player: YtPlayer, text: String) -> void:
	add_normal(player, text)
