class_name YtItemBehavior
extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.


# YtItemBehavior is used to implement behavior for a
# particular item. Each item has it's own YtItemBehavior
# script which is attached to YtItem base class to create a
# complete item.


var item: YtItem


#########################
###       Public      ###
#########################

func init(item_arg: YtItem, triggers_buff_type: YtBuffType):
	item = item_arg

	item_init()

#	NOTE: Order is important here! Auras and autocasts must
#	be loaded after calling item_init() because buffs are
#	setup in item_init() and auras/autocasts rely on buffs.
	var data: Dictionary = YoutdData.item(str(item.get_id()))
	for aura_id in data.get("auras", []):
		item.add_aura(int(aura_id), self)

	for autocast_id in data.get("autocasts", []):
		var autocast: YtAutocast = YtAutocast.make(int(autocast_id), self)
		item.set_autocast(autocast)

	load_triggers(triggers_buff_type)
	on_create()


# Override this in subclass to attach trigger handlers to
# triggers buff passed in the argument.
func load_triggers(_triggers: YtBuffType):
	pass


# Override in subclass to initialize subclass item
# NOTE: item.init() in JASS
func item_init():
	pass


# Override in subclass script to implement the effect that
# should happen when the item is consumed.
func on_consume():
	pass


# NOTE: item.onCreate() in JASS
func on_create():
	pass


# NOTE: item.onPickup() in JASS
func on_pickup():
	pass


# NOTE: item.onDrop() in JASS
func on_drop():
	pass


# NOTE: item.onTowerDetails() in JASS
func on_tower_details() -> YtMultiboardValues:
	return null
