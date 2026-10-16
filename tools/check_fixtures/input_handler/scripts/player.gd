extends Node
## Violation: an _input handler outside scripts/ui/ and the Station base.


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
