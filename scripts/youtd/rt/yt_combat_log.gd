class_name YtCombatLog
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Kampfprotokoll: im Original zum Nachlesen, hier ohne Wirkung.


static func log_ability(_caster, _target, _ability: String) -> void:
	pass


static func log_buff_apply(_caster, _target, _buff) -> void:
	pass


static func log_autocast(_caster, _target, _autocast) -> void:
	pass


static func log_damage(_caster, _target, _source, _damage, _crit_count) -> void:
	pass


static func log_experience(_unit, _amount) -> void:
	pass


static func log_kill(_caster, _target) -> void:
	pass


static func log_item_ability(_item, _target, _ability: String) -> void:
	pass
