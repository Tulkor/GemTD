class_name YtTowerBehavior
extends Node
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.


# YtTowerBehavior is used to implement behavior for a
# particular tower. Each tower family has it's own
# YtTowerBehavior script which is attached to YtTower base class
# to create a complete tower.


var tower: YtTower
var _stats: Dictionary = {}


#########################
###       Public      ###
#########################

func init(tower_arg: YtTower, preceding_tower: YtTower):
	tower = tower_arg

# 	Load stats for current tier. Stats are defined in
# 	subclass.
	var tier: int = tower.get_tier()
	var stats_for_all_tiers: Dictionary = get_tier_stats()
	if stats_for_all_tiers.has(tier):
		_stats = stats_for_all_tiers[tier]
	else:
		_stats = {}

#	NOTE: need to call load_triggers() after loading stats
#	because stats must be available in load_triggers().
	var triggers_bt: YtBuffType = YtBuffType.new("triggers_bt", 0, 0, true, self)
	triggers_bt.set_hidden()
	triggers_bt.disable_stacking_behavior()
	triggers_bt.set_buff_tooltip("DEBUG Triggers buff for tower")
	load_triggers(triggers_bt)
	triggers_bt.apply_to_unit_permanent(tower, tower, 0)

	tower_init()

#	NOTE: must setup auras and autocasts after calling
#	tower_init() because some auras and autocasts use buff
#	types which are initialized inside tower_init().
	for aura_id in tower._p.get("auras", []):
		tower.add_aura(int(aura_id), self)

	for autocast_id in tower._p.get("autocasts", []):
		var autocast: YtAutocast = YtAutocast.make(int(autocast_id), self)
		tower.add_autocast(autocast)

	on_create(preceding_tower)


# Override in subclass to define custom stats for each tower
# tier. Access as _stats.
func get_tier_stats() -> Dictionary:
	return {}


# Override in subclass to attach trigger handlers to
# triggers buff passed in the argument.
func load_triggers(_triggers_bt: YtBuffType):
	pass


# Override in subclass to initialize tower.
# NOTE: do NOT use _init() function - that's a native Godot
# function and it's called too early which will make some
# variables unavailable.
# NOTE: tower.init() in JASS
func tower_init():
	pass
	

# NOTE: tower.onCreate() in JASS
func on_create(_preceding_tower: YtTower):
	pass


# NOTE: tower.onDestruct() in JASS
func on_destruct():
	pass


# NOTE: tower.onTowerDetails() in JASS
func on_tower_details() -> YtMultiboardValues:
	var empty_multiboard: YtMultiboardValues = YtMultiboardValues.new(0)

	return empty_multiboard


func get_tower() -> YtTower:
	return tower
