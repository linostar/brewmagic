class_name AnyInput
extends Node
## Emits `received` once, on the first touch (a click arrives as one) or key press after
## it enters the tree, then stops listening; the event is left for everyone else (the
## splash skips on it, and AudioUnlock still sees it). Raw input belongs in scripts/ui/.

signal received


func _input(event: InputEvent) -> void:
	var touched := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var key := event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if touched or key:
		set_process_input(false)
		received.emit()
