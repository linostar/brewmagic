extends Node
## Not checked: a directory with a .gdignore (like Godot's Android build template in
## android/build/) is not part of the project, so this _input handler is no violation.


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
