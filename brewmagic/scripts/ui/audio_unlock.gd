class_name AudioUnlock
extends Node
## Child of the Game autoload. Browsers only let a page start audio after the
## player's first input, so the game plays no sound before it: this node waits
## for the first touch (desktop clicks arrive as touches) or key press, tells
## Game.unlock_audio() and stops listening. It only watches; the event goes on
## to the game as usual. Raw input reads live in scripts/ui/ (CLAUDE.md hard rule).


func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var key := event as InputEventKey
	if (touch != null and touch.pressed) or (key != null and key.pressed):
		set_process_input(false)
		(get_parent() as GameState).unlock_audio()
