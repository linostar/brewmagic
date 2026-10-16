extends Control
## Violation: game code outside scripts/ui/ reads a key event.


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		accept_event()
