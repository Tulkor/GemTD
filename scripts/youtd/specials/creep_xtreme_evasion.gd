extends YtBuffType
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _init(parent: Node):
	super("creep_xtreme_evasion", 0, 0, true, parent)
	add_event_on_damaged(on_damaged)


func on_damaged(event: YtEvent):
	preload("res://scripts/youtd/specials/creep_evasion.gd").evasion_effect(event, 0.66)
