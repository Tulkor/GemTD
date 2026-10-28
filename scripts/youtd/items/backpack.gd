extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


# NOTE: original script saves item reference in buff's
# user_int. We don't need to save it because YtItemBehavior
# has access to item reference.

var backpack_bt: YtBuffType
var multiboard: YtMultiboardValues


func on_autocast(_event: YtEvent):
	var tower: YtUnit = item.get_carrier()
	backpack_bt.apply_only_timed(tower, tower, 1000)


func item_init():
	backpack_bt = YtBuffType.new("backpack_bt", 0, 0, true, self)
	backpack_bt.set_buff_icon("res://resources/icons/generic_icons/pokecog.tres")
	backpack_bt.set_buff_tooltip(YtUtils.text("XNNT"))
	backpack_bt.add_event_on_kill(backpack_bt_on_kill)
	
	multiboard = YtMultiboardValues.new(1)
	var items_backpacked_label: String = YtUtils.text("DRQK")
	multiboard.set_key(0, items_backpacked_label)


# NOTE: backpackKill() in original script
func backpack_bt_on_kill(event: YtEvent):
	var B: YtBuff = event.get_buff()
	var tower: YtTower = B.get_buffed_unit()
	var creep: YtCreep = event.get_target()

	creep.drop_item(tower, false)
	var backpacked_text: String = YtUtils.text("UEGM")
	tower.get_player().display_small_floating_text(backpacked_text, tower, Color8(255, 165, 0), 30)
	item.user_int = item.user_int + 1
	B.remove_buff()


func on_create():
#	Total items found
	item.user_int = 0


func on_tower_details() -> YtMultiboardValues:
	var items_backpacked_text: String = YtUtils.format_float(item.user_int, 0)
	multiboard.set_value(0, items_backpacked_text)

	return multiboard
