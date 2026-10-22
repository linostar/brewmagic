class_name SettingsPanel
extends Control
## The settings panel (scenes/settings_panel.tscn), shared by the shop's pause menu
## and the title screen: the Assist and Gentle mode toggles, each with its "?" help,
## and the Music and SFX volume sliders. The host adds its own buttons (add_button:
## the shop's Resume and Quit, the title's Close) and opens the panel over its own
## controls (open), which take no keyboard focus until it closes. Process-always,
## so it works while the shop's shift is paused.
##
## Toggles save at once (Game.assist_mode, gentle_mode) and emit assist_changed /
## gentle_changed for the host (the shop restarts or rescales a running station).
## Sliders run 0..Game.VOLUME_MAX in steps of Game.VOLUME_STEP and apply and save at
## once (Game.set_music_volume, set_sfx_volume; a level above 0 also unmutes that bus,
## which the shop's HUD toggles mute); each change plays a sample tap at the
## new SFX volume. Each slider's accessibility name names the setting and its value.
## A bus muted by the shop's HUD toggle keeps its slider at the remembered level, but
## the slider is faded (MUTED_TINT) and its value reads MUTED_TEXT, so the state shows
## in words, not by the fade alone; turning the slider up unmutes it.
##
## Mode help: the "?" next to each mode toggle opens ModeHelp, a flat button laid
## exactly over the panel with the mode's description in a callout above that row.
## Any tap (on the panel or the dim around it), Enter or ui_cancel (its shortcut)
## closes it and focus goes back to the "?".
##
## Layout: the root covers the ScreenFit column, the dim the whole visible rect;
## the panel sits at the bottom of the column (the thumb zone).

signal assist_changed(on: bool)
signal gentle_changed(on: bool)

## What each mode does: the callout its "?" button opens (the only place it shows).
const ASSIST_INFO := "Auto stir, grind, pour & pump; scores Good, never Perfect"
const GENTLE_INFO := "Stir, grind, pour & pump timing is %sx more forgiving" % GameState.GENTLE_TOLERANCE_SCALE
## Height of every row (buttons, toggles, their "?" and the sliders).
const ROW_HEIGHT := 34.0
## A muted bus's slider: faded, and its value label reads MUTED_TEXT instead of the level.
const MUTED_TINT := Color(1, 1, 1, 0.45)
const MUTED_TEXT := "off"

var _game: GameState
## The host's controls, focus-disabled while the panel is open.
var _behind: Control
## The "?" button whose mode help is open.
var _help_opener: Button

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Panel
@onready var _list: VBoxContainer = $Panel/List
@onready var _title: Label = $Panel/List/Title
@onready var _assist_button: Button = $Panel/List/AssistRow/AssistButton
@onready var _gentle_button: Button = $Panel/List/GentleRow/GentleButton
@onready var _assist_help: Button = $Panel/List/AssistRow/AssistHelp
@onready var _gentle_help: Button = $Panel/List/GentleRow/GentleHelp
@onready var _music_slider: VolumeSlider = $Panel/List/MusicRow/Slider
@onready var _music_value: Label = $Panel/List/MusicRow/Value
@onready var _sfx_slider: VolumeSlider = $Panel/List/SfxRow/Slider
@onready var _sfx_value: Label = $Panel/List/SfxRow/Value
@onready var _mode_help: Button = $ModeHelp
@onready var _help_callout: PanelContainer = $ModeHelp/Callout
@onready var _help_text: Label = $ModeHelp/Callout/Text
@onready var _help_tail: TextureRect = $ModeHelp/Tail


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit)
	_fit()
	_assist_button.toggled.connect(_on_assist_toggled)
	_gentle_button.toggled.connect(_on_gentle_toggled)
	_assist_help.pressed.connect(open_mode_help.bind(_assist_help))
	_gentle_help.pressed.connect(open_mode_help.bind(_gentle_help))
	_mode_help.pressed.connect(close_mode_help)
	_dim.gui_input.connect(_on_dim_input)
	for slider: VolumeSlider in [_music_slider, _sfx_slider]:
		slider.min_value = 0
		slider.max_value = GameState.VOLUME_MAX
		slider.step = GameState.VOLUME_STEP
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	var bubble := Art.texture("ui", "bubble")
	var callout_style := StyleBoxTexture.new()
	callout_style.texture = bubble.atlas
	callout_style.region_rect = bubble.region
	callout_style.set_texture_margin_all(4.0)
	callout_style.set_content_margin_all(6.0)
	_help_callout.add_theme_stylebox_override(&"panel", callout_style)
	_help_tail.texture = Art.texture("ui", "bubble_tail")
	sync()


## The panel's heading ("Paused", "Settings").
func set_title(text: String) -> void:
	_title.text = text


## Adds a host button named `button_name` reading `text` (also its accessibility
## name), a row tall, under the heading when `first`, else at the end.
func add_button(button_name: String, text: String, first: bool) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.accessibility_name = text
	button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	_list.add_child(button)
	if first:
		_list.move_child(button, _title.get_index() + 1)
	return button


## Shows the panel over the dim, with the settings as they are now; `behind` (the
## host's controls) takes no focus until close(), and `focus` gets it.
func open(behind: Control, focus: Control) -> void:
	sync()
	_behind = behind
	_behind.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_dim.show()
	_panel.show()
	Juice.squash(_panel, 0.08)
	focus.grab_focus(true)


func close() -> void:
	if _mode_help.visible:
		close_mode_help()
	_panel.hide()
	_dim.hide()
	if is_instance_valid(_behind):
		_behind.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	_behind = null


func is_open() -> bool:
	return _panel.visible


## Shows the toggles' and sliders' state from Game without emitting their signals.
func sync() -> void:
	_assist_button.set_pressed_no_signal(_game.assist_mode)
	_gentle_button.set_pressed_no_signal(_game.gentle_mode)
	_assist_button.text = "Assist mode: %s" % ("On" if _game.assist_mode else "Off")
	_gentle_button.text = "Gentle mode: %s" % ("On" if _game.gentle_mode else "Off")
	_assist_button.accessibility_name = _assist_button.text
	_gentle_button.accessibility_name = _gentle_button.text
	_music_slider.set_value_no_signal(_game.music_volume)
	_sfx_slider.set_value_no_signal(_game.sfx_volume)
	_show_volume(_music_slider, _music_value, "Music volume", _game.music_volume, _game.music_silent())
	_show_volume(_sfx_slider, _sfx_value, "Sound effects volume", _game.sfx_volume, _game.sfx_silent())


## Shows the description of `help`'s mode (ASSIST_INFO or GENTLE_INFO) in a
## callout above its row, its tail pointing at `help`, and holds focus until closed.
func open_mode_help(help: Button) -> void:
	var text := ASSIST_INFO if help == _assist_help else GENTLE_INFO
	_help_opener = help
	_help_text.text = "\n".join(Content.wrap_bubble(text))
	_mode_help.accessibility_name = text
	_mode_help.position = _panel.position
	_mode_help.size = _panel.size
	_help_callout.size = Vector2.ZERO
	var at := _mode_help.get_global_transform().affine_inverse() * help.get_global_rect()
	var tail_x := at.get_center().x - _help_tail.size.x + 1.0
	_help_tail.position = Vector2(tail_x, at.position.y - _help_tail.size.y).round()
	var left := clampf(at.end.x - _help_callout.size.x, 0.0, _mode_help.size.x - _help_callout.size.x)
	_help_callout.position = Vector2(left, _help_tail.position.y - _help_callout.size.y + 1.0).round()
	_help_callout.pivot_offset = Vector2(tail_x - left, _help_callout.size.y)
	_list.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_mode_help.show()
	_mode_help.grab_focus(true)
	Juice.squash(_help_callout, 0.12)
	print("[Settings] Mode help: %s" % text)


func close_mode_help() -> void:
	_mode_help.hide()
	_list.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	if is_instance_valid(_help_opener):
		_help_opener.grab_focus(true)
		Juice.squash(_help_opener, 0.2)
	_help_opener = null


## A tap on the dim around the panel closes the mode help.
func _on_dim_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed and _mode_help.visible:
		close_mode_help()


func _on_assist_toggled(on: bool) -> void:
	_game.assist_mode = on
	_game.save_game()
	print("[Settings] Assist mode %s" % ("on" if on else "off"))
	sync()
	assist_changed.emit(on)


func _on_gentle_toggled(on: bool) -> void:
	_game.gentle_mode = on
	_game.save_game()
	print("[Settings] Gentle mode %s" % ("on" if on else "off"))
	sync()
	gentle_changed.emit(on)


func _on_music_changed(value: float) -> void:
	_game.set_music_volume(roundi(value))
	_show_volume(_music_slider, _music_value, "Music volume", _game.music_volume, _game.music_silent())
	_game.sfx(&"tap")


func _on_sfx_changed(value: float) -> void:
	_game.set_sfx_volume(roundi(value))
	_show_volume(_sfx_slider, _sfx_value, "Sound effects volume", _game.sfx_volume, _game.sfx_silent())
	# The sample plays on the SFX bus, so it is heard at the new volume.
	_game.sfx(&"tap")


func _show_volume(slider: VolumeSlider, label: Label, what: String, volume: int, silent: bool) -> void:
	var muted := silent and volume > 0
	label.text = MUTED_TEXT if muted else str(volume)
	slider.modulate = MUTED_TINT if muted else Color.WHITE
	slider.accessibility_name = "%s %d of %d%s" % [what, volume, GameState.VOLUME_MAX, " (muted)" if silent else ""]


func _fit() -> void:
	var screen := _game.visible_rect()
	var column := _game.column_rect()
	position = column.position
	size = column.size
	_dim.position = screen.position - column.position
	_dim.size = screen.size
