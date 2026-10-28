extends YtBuilder
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func _init():
    _item_slots_bonus = 2
    _adds_extra_recipes = true


func _get_tower_modifier() -> YtModifier:
    var mod: YtModifier = YtModifier.new()
    mod.add_modification(YtModificationType.enm.MOD_ITEM_QUALITY_ON_KILL, 0.40, 0.0)

    return mod


func _get_tower_buff() -> YtBuffType:
    var backpacker_bt: YtBuffType = YtBuffType.new("backpacker_bt", 0, 0, false, self)
    backpacker_bt.add_periodic_event(backpacker_bt_periodic, 1.0)

    return backpacker_bt


func backpacker_bt_periodic(event: YtEvent):
    var buff: YtBuff = event.get_buff()
    var tower: YtTower = buff.get_buffed_unit()
    var item_list: Array[YtItem] = tower.get_items()

    var tower_rarity: YtRarity.enm = YtTowerProperties.get_rarity(tower.get_id())

    var dropped_items: bool = false

    for item in item_list:
        var item_rarity: YtRarity.enm = item.get_rarity()
        var can_wield_item: bool = item_rarity == tower_rarity || item_rarity == YtRarity.enm.UNIQUE
        
        if !can_wield_item:
            item.drop()
            item.fly_to_stash(0.0)
            dropped_items = true
    
    if dropped_items:
        tower.get_player().display_floating_text(YtUtils.text("BUILDER_BACKPACKER_ERROR_TEXT"), tower, Color.RED)
