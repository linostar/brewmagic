class_name CreditsPanel
extends Control
## The title's credits (scenes/credits_panel.tscn): who made the game, the fonts and
## their licence, over a dim. Like SettingsPanel, the root covers the ScreenFit column,
## the dim the whole visible rect, and the panel sits at the bottom of the column (Close
## in the thumb zone). open() disables focus on the host's controls until close();
## Close (also ui_cancel, its shortcut) or a tap on the dim closes it and emits `closed`.

signal closed

var _game: GameState
## The host's controls, focus-disabled while the panel is open.
var _behind: Control

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Panel
@onready var _close: Button = $Panel/List/CloseButton


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit)
	_fit()
	_close.pressed.connect(close)
	_dim.gui_input.connect(_on_dim_input)


func open(behind: Control) -> void:
	_behind = behind
	_behind.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_dim.show()
	_panel.show()
	Juice.squash(_panel, 0.08)
	_close.grab_focus(true)
	print("[Credits] Opened")


func close() -> void:
	if not is_open():
		return
	_panel.hide()
	_dim.hide()
	if is_instance_valid(_behind):
		_behind.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	_behind = null
	print("[Credits] Closed")
	closed.emit()


func is_open() -> bool:
	return _panel.visible


func close_button() -> Button:
	return _close


func _on_dim_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		close()


func _fit() -> void:
	var screen := _game.visible_rect()
	var column := _game.column_rect()
	position = column.position
	size = column.size
	_dim.position = screen.position - column.position
	_dim.size = screen.size
