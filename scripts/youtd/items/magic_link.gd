extends YtItemBehavior
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2) von tools/youtd/faehigkeiten.py, nicht von Hand ändern.


func on_autocast(event: YtEvent):
	event.get_target().add_exp_flat(item.get_carrier().remove_exp_flat(30))
