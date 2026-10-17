class_name PageArrow
extends Button
## A shelf page arrow (the shop's ShelfPrev and ShelfNext). A tap or Enter presses
## it (the shop turns the page). Moving focus on past it, ui_left on Prev or
## ui_right on Next, emits `stepped_past` instead: the item it leads to is on a page
## that is still hidden, so no focus neighbour can reach it, and the shop turns the
## page and focuses that item.
## Keyboard handling lives here (scripts/ui/) per the project's input rule.

signal stepped_past

## -1 for Prev (steps past with ui_left), 1 for Next (ui_right).
@export var direction := 1


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_right" if direction > 0 else &"ui_left", true):
		accept_event()
		stepped_past.emit()
