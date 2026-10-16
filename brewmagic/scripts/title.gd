class_name Title
extends Control
## Title screen: the game's name, its tagline and the button that opens the
## shop. Everything sits in the gameplay column (Game ScreenFit), the buttons in
## the thumb zone. ContentErrorBanner stays hidden unless show_content_error()
## is called: when Content reports errors in data/*.json, the banner shows their
## count and the shop stays closed (the buttons are disabled).
## With a saved story to resume (Game.can_continue()) the main button reads
## "Continue" and NewGameButton appears under it; a new game over a saved one
## needs a second press within NEW_GAME_CONFIRM_TIME. Without one the main button
## starts a new game.

const CONTENT_ERROR_MESSAGE := "Content error: %d problem(s) in data/*.json, see the log. The shop stays closed."
const NEW_GAME_TEXT := "New game"
const NEW_GAME_CONFIRM_TEXT := "Sure? Tap again"
const NEW_GAME_CONFIRM_TIME := 3.0

var _game: GameState
var _confirm_timer: SceneTreeTimer

@onready var _column: Control = $Column
@onready var _banner: Label = $Column/ContentErrorBanner
@onready var _open_button: Button = $Column/OpenShopButton
@onready var _new_game_button: Button = $Column/NewGameButton


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	_open_button.pressed.connect(_on_open_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	var content_errors := Content.errors()
	if not content_errors.is_empty():
		print("[Title] Content has %d problem(s); the shop stays closed" % content_errors.size())
		show_content_error(CONTENT_ERROR_MESSAGE % content_errors.size())
		_open_button.disabled = true
		_new_game_button.hide()
		return
	var resumable := _game.can_continue()
	_open_button.text = "Continue" if resumable else "Open the shop"
	_open_button.accessibility_name = ("Continue the story on day %d" % _game.day) if resumable else "Open the shop"
	_new_game_button.visible = resumable
	_new_game_button.text = NEW_GAME_TEXT
	_new_game_button.accessibility_name = "Start a new game"
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
	if _game.can_continue():
		print("[Title] Continue on day %d%s" % [_game.day, " (market)" if _game.at_market else ""])
		_game.continue_game()
		return
	_start_new_game()


## The first press asks for a second one (the saved story would be lost).
func _on_new_game_pressed() -> void:
	if _confirm_timer == null:
		_new_game_button.text = NEW_GAME_CONFIRM_TEXT
		_new_game_button.accessibility_name = "Press again to erase the saved story and start a new game"
		Juice.shake(_new_game_button, 2.0, 0.2)
		_confirm_timer = get_tree().create_timer(NEW_GAME_CONFIRM_TIME)
		_confirm_timer.timeout.connect(_cancel_new_game)
		return
	_start_new_game()


func _cancel_new_game() -> void:
	_confirm_timer = null
	_new_game_button.text = NEW_GAME_TEXT
	_new_game_button.accessibility_name = "Start a new game"


func _start_new_game() -> void:
	_game.new_game()
	_game.goto(GameState.Flow.MORNING)
