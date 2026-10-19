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
## Once the story has been finished (Game.rush_hour_unlocked) RushButton starts a
## Rush Hour run, with the best score under it (RushBest, "assisted" when set with Assist).
## SettingsButton (bottom) opens the shared settings panel (Settings: the mode toggles
## with their "?" help and the Music and SFX volumes) with a Close button (also
## ui_cancel); closing it gives focus back to SettingsButton.
## The reading zone (above the buttons) is the hero: the BrewMagic logo (art_src/title.px)
## pops in on arrival and then bobs, over the big animated cauldron (CauldronHero:
## bubbles and steam cycling through the essence colours). GrimoireButton (thumb zone,
## under the cauldron) opens the Grimoire of Making; closing it gives focus back.

const CONTENT_ERROR_MESSAGE := "Content error: %d problem(s) in data/*.json, see the log. The shop stays closed."
const NEW_GAME_TEXT := "New game"
const NEW_GAME_CONFIRM_TEXT := "Sure? Tap again"
const NEW_GAME_CONFIRM_TIME := 3.0
## The logo's top and the cauldron's centre, as fractions of the column height (both
## in the reading zone, above the tagline at 0.36 and the Grimoire button at 0.45).
const LOGO_TOP := 0.045
const POT_CENTER := 0.24
## The logo's pop-in on arrival (from POP_SCALE), then a bob of BOB_HEIGHT base units
## up and down every BOB_TIME seconds.
const POP_SCALE := 0.3
const POP_TIME := 0.45
const BOB_HEIGHT := 2.0
const BOB_TIME := 1.6

## The Grimoire of Making while it is open.
var grimoire: Grimoire

var _game: GameState
var _confirm_timer: SceneTreeTimer
var _logo_rest := Vector2.ZERO
var _bob_time := 0.0

@onready var _column: Control = $Column
@onready var _hero: CauldronHero = $Column/Hero
@onready var _logo: TextureRect = $Column/Logo
@onready var _grimoire_button: Button = $Column/GrimoireButton
@onready var _motes: CPUParticles2D = $Column/Motes
@onready var _banner: Label = $Column/ContentErrorBanner
@onready var _open_button: Button = $Column/OpenShopButton
@onready var _new_game_button: Button = $Column/NewGameButton
@onready var _rush_button: Button = $Column/RushButton
@onready var _rush_best: Label = $Column/RushBest
@onready var _settings_button: Button = $Column/SettingsButton
@onready var _settings: SettingsPanel = $Settings


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_logo.texture = Art.texture("title", "logo")
	_logo.size = _logo.texture.get_size()
	_logo.pivot_offset = _logo.size / 2.0
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	_logo.scale = Vector2(POP_SCALE, POP_SCALE)
	_logo.create_tween().tween_property(_logo, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_grimoire_button.pressed.connect(open_grimoire)
	_open_button.pressed.connect(_on_open_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_rush_button.pressed.connect(_on_rush_pressed)
	_settings_button.pressed.connect(open_settings)
	_settings.set_title("Settings")
	var close := _settings.add_button("CloseButton", "Close", false)
	close.shortcut = Shortcut.new()
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	close.shortcut.events = [cancel]
	close.shortcut_feedback = false
	close.pressed.connect(close_settings)
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
	_rush_button.visible = _game.rush_hour_unlocked
	_rush_best.visible = _game.rush_hour_unlocked
	_rush_best.text = "Best: %d coins%s" % [_game.rush_best, " (assisted)" if _game.rush_best_assisted else ""]
	_rush_best.accessibility_name = "Rush Hour best: %s" % _rush_best.text.trim_prefix("Best: ")
	# Keyboard users can press Enter straight away; the focus ring shows once they navigate.
	_open_button.grab_focus(true)


## Opens the settings panel over the title; its first toggle takes focus.
func open_settings() -> void:
	_settings.open(_column, $Settings/Panel/List/AssistRow/AssistButton as Button)
	print("[Title] Settings opened")


func close_settings() -> void:
	if not _settings.is_open():
		return
	_settings.close()
	_settings_button.grab_focus(true)
	print("[Title] Settings closed")


## Shows `message` in the banner at the top of the screen.
func show_content_error(message: String) -> void:
	_banner.text = message
	_banner.show()


## Opens the Grimoire of Making over the title (the title's controls take no focus
## until it closes; then GrimoireButton has it again).
func open_grimoire() -> void:
	if grimoire != null:
		return
	grimoire = Grimoire.open(self, _column)
	grimoire.closed.connect(_on_grimoire_closed)
	print("[Title] Grimoire opened")


func _on_grimoire_closed() -> void:
	grimoire = null
	_grimoire_button.grab_focus(true)
	print("[Title] Grimoire closed")


## The logo bobs gently once it has popped in.
func _process(delta: float) -> void:
	_bob_time += delta
	_logo.position.y = roundf(_logo_rest.y - sin(_bob_time * TAU / BOB_TIME) * BOB_HEIGHT)


## The reading zone's art sits on whole base units (pixel art never lands between pixels).
func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size
	_logo_rest = Vector2(roundf((column.size.x - _logo.size.x) / 2.0), roundf(column.size.y * LOGO_TOP))
	_logo.position = _logo_rest
	_hero.position = Vector2(roundf((column.size.x - CauldronHero.SIZE.x) / 2.0), roundf(column.size.y * POT_CENTER - CauldronHero.SIZE.y / 2.0))
	# Magic motes drift up over the whole column, behind everything.
	_motes.position = column.size / 2.0
	_motes.emission_rect_extents = column.size / 2.0


func _on_open_pressed() -> void:
	if _game.can_continue():
		print("[Title] Continue on day %d%s" % [_game.day, " (market)" if _game.at_market else ""])
		_game.continue_game()
		return
	_start_new_game()


func _on_rush_pressed() -> void:
	print("[Title] Rush Hour (best %d)" % _game.rush_best)
	Juice.squash(_rush_button, 0.2)
	_game.start_rush()


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
