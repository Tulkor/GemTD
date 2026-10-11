class_name TooltipButton
extends Button
## Knopf mit eigenem, verziertem Tooltip (siehe TooltipHost); make liefert das Control.

var make: Callable


func _make_custom_tooltip(_for_text: String) -> Object:
	if make.is_valid():
		return make.call()
	return null
