extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func on_drop():
	var tower: YtTower = item.get_carrier()

	if tower.get_element() == YtElement.enm.ASTRAL:
		tower.modify_property(YtModificationType.enm.MOD_EXP_RECEIVED, -1.00)
	elif tower.get_element() == YtElement.enm.DARKNESS:
		tower.modify_property(YtModificationType.enm.MOD_SPELL_DAMAGE_DEALT, -0.45)
	elif tower.get_element() == YtElement.enm.NATURE:
		tower.modify_property(YtModificationType.enm.MOD_ATK_CRIT_CHANCE, -0.10)
	elif tower.get_element() == YtElement.enm.FIRE:
		tower.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, -0.40)
	elif tower.get_element() == YtElement.enm.ICE:
		tower.modify_property(YtModificationType.enm.MOD_BUFF_DURATION, -0.50)
	elif tower.get_element() == YtElement.enm.STORM:
		tower.modify_property(YtModificationType.enm.MOD_ATTACKSPEED, -0.25)
	elif tower.get_element() == YtElement.enm.IRON:
		tower.modify_property(YtModificationType.enm.MOD_ITEM_CHANCE_ON_KILL, -0.30)


func on_pickup():
	var tower: YtTower = item.get_carrier()

	if tower.get_element() == YtElement.enm.ASTRAL:
		tower.modify_property(YtModificationType.enm.MOD_EXP_RECEIVED, 1.00)
	elif tower.get_element() == YtElement.enm.DARKNESS:
		tower.modify_property(YtModificationType.enm.MOD_SPELL_DAMAGE_DEALT, 0.45)
	elif tower.get_element() == YtElement.enm.NATURE:
		tower.modify_property(YtModificationType.enm.MOD_ATK_CRIT_CHANCE, 0.10)
	elif tower.get_element() == YtElement.enm.FIRE:
		tower.modify_property(YtModificationType.enm.MOD_DAMAGE_ADD_PERC, 0.40)
	elif tower.get_element() == YtElement.enm.ICE:
		tower.modify_property(YtModificationType.enm.MOD_BUFF_DURATION, 0.50)
	elif tower.get_element() == YtElement.enm.STORM:
		tower.modify_property(YtModificationType.enm.MOD_ATTACKSPEED, 0.25)
	elif tower.get_element() == YtElement.enm.IRON:
		tower.modify_property(YtModificationType.enm.MOD_ITEM_CHANCE_ON_KILL, 0.30)
