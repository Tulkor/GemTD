class_name TooltipHost
extends PanelContainer
## PanelContainer mit eigenem Tooltip-Inhalt: make liefert ein Control, sonst der normale Text-Tooltip.

var make: Callable


func _make_custom_tooltip(_for_text: String) -> Object:
	if make.is_valid():
		return make.call()
	return null
