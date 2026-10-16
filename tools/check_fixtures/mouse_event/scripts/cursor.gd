extends Control
## Violation: game code outside scripts/ui/ reads a mouse event.


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()
