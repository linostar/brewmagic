extends Control
## Allowed: scripts/ui/ may handle raw input for focus navigation.


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
