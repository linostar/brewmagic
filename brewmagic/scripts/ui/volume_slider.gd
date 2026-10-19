class_name VolumeSlider
extends HSlider
## A volume slider (SettingsPanel's Music and SFX rows) for one thumb. HSlider itself
## reads mouse events only, and this game's single input path is touch
## (emulate_mouse_from_touch off), so a touch on the slider, or a drag that started
## on it, sets the value under the finger (snapped to the step, mapped like HSlider
## maps a click: the knob's centre follows the finger). Keyboard ui_left/ui_right
## step it through HSlider's own handling. Touch handling lives here (scripts/ui/)
## per the project's input rule.


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	if (touch == null or not touch.pressed or touch.index != 0) and (drag == null or drag.index != 0):
		return
	var x: float = touch.position.x if touch != null else drag.position.x
	var knob := get_theme_icon(&"grabber").get_width()
	set_as_ratio(clampf((x - knob / 2.0) / maxf(size.x - knob, 1.0), 0.0, 1.0))
	if touch != null:
		grab_focus(true)
	accept_event()
