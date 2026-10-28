class_name YtItem
extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Ein Item im Spiel: Werte-Modifikator, Auren, Autocast und das Item-Skript (scripts/youtd/items/<script>.gd).
## Statt ItemDrop/ItemContainer aus YouTD 2 liegt jedes Item unter YtWorld (Knoten "items") und merkt sich, wo es
## gerade ist: am Boden (frisch erzeugt oder abgelegt), im Lager eines Spielers oder in einem Tower (YoutdTower.items
## bzw. .oils). Das Lager selbst führt youtd_game.gd (stash_add/stash_remove).

signal charges_changed()
signal consumed()

enum Place {NONE, GROUND, STASH, TOWER}

var user_int: int = 0
var user_int2: int = 0
var user_int3: int = 0
var user_real: float = 0.0
var user_real2: float = 0.0
var user_real3: float = 0.0

var place: Place = Place.NONE
var horadric_lock := false   ## im Lager gegen den Horadrischen Würfel gesperrt

var _id: int = 0
var _carrier: YtTower = null
var _charge_count: int = -1
var _visible: bool = true
var _uses_charges: bool = false
var _is_oil_and_was_applied_already: bool = false

var _modifier: YtModifier
var _autocast: YtAutocast = null
var _aura_carrier_bt: YtBuffType
var _triggers_bt: YtBuffType
var _triggers_buff: YtBuff = null
var _inherited_periodic_timers: Dictionary = {}
var _player: YtPlayer = null
var _item_behavior: YtItemBehavior

var _uid: int = 0


#########################
###     Built-in      ###
#########################

func _init(id: int, player: YtPlayer):
	_uid = YtWorld.next_uid()
	YtGroupManager.add("items", self, _uid)
	_id = id
	_player = player

	_modifier = YtModifier.new()
	for m in YoutdData.item(str(_id)).get("mods", []):
		_modifier.add_modification(YtModificationType.from_string(str(m[0])), float(m[1]), float(m[2]))

	var item_name: String = get_display_name()

#	NOTE: need to insert item id into bufftype names to make
#	them unique.
	_aura_carrier_bt = YtBuffType.new("item-%d-_aura_carrier_bt" % _id, 0, 0, true, self)
	_aura_carrier_bt.set_buff_tooltip("DEBUG Aura carrier buff for item %s" % item_name)
	_aura_carrier_bt.set_hidden()
	_aura_carrier_bt.disable_stacking_behavior()

	_triggers_bt = YtBuffType.new("item-%d-_triggers_bt" % _id, 0, 0, true, self)
	_triggers_bt.set_buff_tooltip("DEBUG Triggers buff for item %s" % item_name)
	_triggers_bt.set_hidden()
	_triggers_bt.disable_stacking_behavior()


#########################
###       Public      ###
#########################

func get_uid() -> int:
	return _uid


func toggle_horadric_lock():
	horadric_lock = !horadric_lock


func get_horadric_lock_is_enabled() -> bool:
	return horadric_lock


func add_aura(aura_id: int, object_with_buff_var: Object):
	_aura_carrier_bt.add_aura(aura_id, object_with_buff_var)


# Consume item. Only applicable to items of consumable type.
func consume():
	_item_behavior.on_consume()
	consumed.emit()


# NOTE: SetItemVisible() in JASS
func set_visible(visible: bool):
	_visible = visible


func is_visible() -> bool:
	return _visible


func set_autocast(autocast: YtAutocast):
	autocast.set_item_owner(self)
	_autocast = autocast
	add_child(autocast)


func get_autocast() -> YtAutocast:
	return _autocast


# NOTE: item.onTowerDetails() in JASS
func on_tower_details() -> YtMultiboardValues:
	return _item_behavior.on_tower_details()


func disable_autocast():
	if _autocast != null:
		_autocast.set_caster(null)


# NOTE: item.getItemType() in JASS returns the id.
func get_id() -> int:
	return _id


# NOTE: item.getCarrier() in JASS
func get_carrier() -> YtTower:
	return _carrier


# NOTE: item.getOwner() in JASS
func get_player() -> YtPlayer:
	return _player


func belongs_to_local_player() -> bool:
	return _player == YtPlayer.local()


func get_display_name() -> String:
	return str(YoutdData.item(str(_id)).get("name", _id))


func get_rarity() -> YtRarity.enm:
	return YtRarity.convert_from_string(str(YoutdData.item(str(_id)).get("rarity", "common")))


func get_type_name() -> String:
	return str(YoutdData.item(str(_id)).get("type", "regular"))


func is_oil() -> bool:
	return get_type_name() == "oil"


func is_consumable() -> bool:
	return get_type_name() == "consumable"


func get_required_wave_level() -> int:
	return int(YoutdData.item(str(_id)).get("level", 0))


# Picks up an item from the ground (or the stash) and moves
# it to a tower. Returns true if item was picked up.
# NOTE: item.pickup() in JASS
func pickup(tower: YtTower) -> bool:
	if place == Place.TOWER or not YtUtils.unit_is_valid(tower) or tower.body == null:
		return false
	if not (is_oil() or tower.have_item_space()):
		return false
	if place == Place.STASH and YtWorld.game != null:
		YtWorld.game.stash_remove(self)
	place = Place.NONE
	add_to_tower(tower)
	return true


# Drops item from tower inventory onto the ground. This f-n
# does nothing if item is currently not in tower inventory.
# NOTE: item.drop() in JASS
func drop():
	if _carrier == null:
		return
	var body = _carrier.body
	if body != null:
		body.items.erase(self)
		body.oils.erase(self)
	_remove_from_tower()
	place = Place.GROUND
	if body != null and is_instance_valid(body):
		body.items_changed()


# Item goes to the stash of its player. Does nothing if
# item is not on the ground.
# NOTE: item.flyToStash() in JASS
func fly_to_stash(_mystery_float: float):
	if place != Place.GROUND:
		return
	if YtWorld.game != null:
		YtWorld.game.stash_add(self)
	else:
		place = Place.NONE


## Item in den Tower legen (Öle in die Öl-Liste, ohne Platz). Der Aufrufer prüft Platz und entfernt es vorher von
## seinem alten Ort.
func add_to_tower(tower: YtTower):
	var body = tower.body
	if is_oil():
		body.oils.append(self)
	else:
		body.items.append(self)
	place = Place.TOWER
	_add_to_tower(tower)
	_is_oil_and_was_applied_already = true
	body.items_changed()


# NOTE: this f-n only applies the effects. Use pickup() or
# add_to_tower() to fully add an item to a tower.
func _add_to_tower(tower: YtTower):
	_carrier = tower

# 	NOTE: call on_pick() after setting carrier so that it's
# 	available inside on_pickup() implementations.
	_item_behavior.on_pickup()

	_carrier.add_modifier(_modifier)

	if _autocast != null:
		_autocast.set_caster(_carrier)

	_triggers_buff = _triggers_bt.apply_to_unit_permanent(_carrier, _carrier, 0)
#	NOTE: sort keys to ensure deterministic iteration order
	var sorted_timer_keys: Array = _inherited_periodic_timers.keys()
	sorted_timer_keys.sort()
	for key in sorted_timer_keys:
		var timer: YtManualTimer = _inherited_periodic_timers[key]
		timer.set_paused(false)
	if _triggers_buff != null:
		_triggers_buff.inherit_periodic_timers(_inherited_periodic_timers)
	_aura_carrier_bt.apply_to_unit_permanent(_carrier, _carrier, 0)


# NOTE: this f-n only removes the effects.
#
# NOTE: the code for _inherited_periodic_timers is a hack to
# preserve item cooldowns when item is removed from tower:
# the timers of the triggers buff are kept in the item and
# given to the next triggers buff.
func _remove_from_tower():
	if _carrier == null:
		return

	_item_behavior.on_drop()

	if YtUtils.unit_is_valid(_carrier):
		_carrier.remove_modifier(_modifier)

	if _autocast != null:
		_autocast.set_caster(null)

	if _triggers_buff != null and is_instance_valid(_triggers_buff):
		_inherited_periodic_timers = _triggers_buff.get_periodic_timers()
	var sorted_timer_keys: Array = _inherited_periodic_timers.keys()
	sorted_timer_keys.sort()
	for key in sorted_timer_keys:
		var timer: YtManualTimer = _inherited_periodic_timers[key]
		if is_instance_valid(timer):
			if timer.get_parent() != null:
				timer.reparent(self)
			else:
				add_child(timer)
			timer.set_paused(true)

#	Buffs des Items vom Tower nehmen (in YouTD 2 geht das über
#	das Verlassen des Baums; hier bleibt das Item im Baum).
	for bt in [_triggers_bt, _aura_carrier_bt]:
		if YtUtils.unit_is_valid(_carrier):
			var b: YtBuff = _carrier.get_buff_of_type(bt)
			if b != null:
				b.remove_buff()
	_triggers_buff = null

	_carrier = null


func _set_item_behavior(item_behavior: YtItemBehavior):
	_item_behavior = item_behavior
	_item_behavior.init(self, _triggers_bt)


#########################
### Setters / Getters ###
#########################

# Sets the charge count that is displayed on the item icon.
# NOTE: item.setCharges() in JASS
func set_charges(new_count: int):
	_charge_count = new_count
	_uses_charges = true
	charges_changed.emit()


# NOTE: item.getCharges() in JASS
func get_charges() -> int:
	return _charge_count


func uses_charges() -> bool:
	return _uses_charges


#########################
###       Static      ###
#########################

# Creates item on the ground. The script then picks it up
# into a tower or lets it fly to the stash.
# NOTE: Item.create() in JASS
static func create(player: YtPlayer, item_id: int, _position: Vector3) -> YtItem:
	var item: YtItem = YtItem.make(item_id, player)
	if item != null:
		item.place = Place.GROUND
	return item


## Neues Item id (Skript aus items.json, Feld "script"), hängt unter YtWorld.
static func make(id: int, player: YtPlayer) -> YtItem:
	if player == null:
		player = YtPlayer.local()
	var data: Dictionary = YoutdData.item(str(id))
	if data.is_empty():
		return null
	var script_name: String = str(data.get("script", ""))
	var path := "res://scripts/youtd/items/%s.gd" % script_name
	var item_behavior: YtItemBehavior
	if script_name != "" and ResourceLoader.exists(path):
		item_behavior = load(path).new()
	else:
		item_behavior = YtItemBehavior.new()

	var item: YtItem = YtItem.new(id, player)
	item.name = "item_%d" % item._uid
	if YtWorld.node != null:
		YtWorld.node.item_holder().add_child(item)
	item._set_item_behavior(item_behavior)
	item.add_child(item_behavior)

	return item
