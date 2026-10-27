extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


var chain_lightning_st: YtSpellType
var stun_bt: YtBuffType


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_attack(on_attack)


# NOTE: drol_chainStun() in original script
func chain_lightning_st_on_damage(event: YtEvent, d: YtDummyUnit):
	var creep: YtCreep = event.get_target()
	var creep_category: YtCreepCategory.enm = creep.get_category()

	if creep_category == YtCreepCategory.enm.UNDEAD || creep_category == YtCreepCategory.enm.ORC:
		stun_bt.apply_only_timed(d.get_caster(), event.get_target(), 0.5)


func item_init():
	stun_bt = YtCbStun.new("stun_bt", 0, 0, false, self)
	
	chain_lightning_st = YtSpellType.new(YtSpellType.Name.CHAIN_LIGHTNING, 5.0, self)
	chain_lightning_st.set_damage_event(chain_lightning_st_on_damage)
	chain_lightning_st.data.chain_lightning.damage = 250
	chain_lightning_st.data.chain_lightning.damage_reduction = 0.25
	chain_lightning_st.data.chain_lightning.chain_count = 3


func on_attack(event: YtEvent):
	var tower: YtTower = item.get_carrier()
	var speed: float = tower.get_base_attack_speed()

	if tower.calc_chance(0.125 * speed):
		YtCombatLog.log_item_ability(item, event.get_target(), "Purify")
		chain_lightning_st.target_cast_from_caster(tower, event.get_target(), 1, tower.calc_spell_crit_no_bonus())
