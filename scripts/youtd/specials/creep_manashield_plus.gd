extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _init(parent: Node):
	super("creep_mana_shield_plus", 0, 0, true, parent)

	add_event_on_damaged(on_damaged)


func on_damaged(event: YtEvent):
	var spend_mana: bool = false
	preload("res://scripts/youtd/specials/creep_manashield.gd").shield_effect(event, spend_mana)
