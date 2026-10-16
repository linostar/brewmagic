extends Control
## Allowed: the Station base may read the Assist press.


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event is InputEventKey:
		accept_event()
