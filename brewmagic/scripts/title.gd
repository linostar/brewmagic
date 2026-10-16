class_name Title
extends Control
## Title screen: the game's name, its tagline and the button that opens the
## shop. Everything sits in the gameplay column (Game ScreenFit), the button in
## the thumb zone. ContentErrorBanner stays hidden unless show_content_error()
## is called: when Content reports errors in data/*.json, the banner shows their
## count and the shop stays closed (the button is disabled).

const CONTENT_ERROR_MESSAGE := "Content error: %d problem(s) in data/*.json, see the log. The shop stays closed."

var _game: GameState

@onready var _column: Control = $Column
@onready var _banner: Label = $Column/ContentErrorBanner
@onready var _open_button: Button = $Column/OpenShopButton


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	_open_button.pressed.connect(_on_open_pressed)
	var content_errors := Content.errors()
	if not content_errors.is_empty():
		print("[Title] Content has %d problem(s); the shop stays closed" % content_errors.size())
		show_content_error(CONTENT_ERROR_MESSAGE % content_errors.size())
		_open_button.disabled = true
		return
	# Keyboard users can press Enter straight away; the focus ring shows once they navigate.
	_open_button.grab_focus(true)


## Shows `message` in the banner at the top of the screen.
func show_content_error(message: String) -> void:
	_banner.text = message
	_banner.show()


func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size


func _on_open_pressed() -> void:
	_game.goto(GameState.Flow.SHOP)
