extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func load_triggers(triggers: YtBuffType):
	triggers.add_event_on_damage(on_damage)


func on_autocast(_event: YtEvent):
	item.user_int = 0


func on_damage(event: YtEvent):
	var tower: YtTower = item.get_carrier()

	if item.user_int >= 12 && item.user_int < 28:
		event.damage = event.damage * 0.5

		if event.is_main_target():
			var exhausted_text: String = YtUtils.text("LW28")
			tower.get_player().display_small_floating_text(exhausted_text, tower, Color8(255, 150, 0), 30)
			item.user_int = item.user_int + 1

	if item.user_int < 12:
		event.damage = event.damage * 2

		if event.is_main_target():
			var insane_text: String = YtUtils.text("ELMO")
			tower.get_player().display_small_floating_text(insane_text, tower, Color8(255, 150, 0), 30)
			item.user_int = item.user_int + 1


func on_create():
	item.user_int = 50


func on_drop():
	item.user_int = 50
