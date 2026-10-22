class_name Title
extends Control
## Title screen: the game's name, its tagline and the buttons that start story mode
## or Rush Hour. Everything sits in the gameplay column (Game ScreenFit), the buttons in
## the thumb zone. ContentErrorBanner stays hidden unless show_content_error()
## is called: when Content reports errors in data/*.json, the banner shows their
## count and the shop stays closed (the buttons are disabled).
## The story button (OpenShopButton, top of the menu) reads "Story mode" and starts a
## new story; with a saved story to resume (Game.can_continue()) it reads "Continue
## story" and NewGameButton ("New story") appears right under it; a new story over a
## saved one needs a second press within NEW_GAME_CONFIRM_TIME.
## RushButton (under them) starts a Rush Hour run from the first launch, with the best
## score under it once a run has set one (RushBest, "assisted" when set with Assist);
## without a saved story both move up into New story's place.
## The bottom row: SettingsButton opens the shared settings panel (Settings: the mode
## toggles with their "?" help and the Music and SFX volumes) with a Close button
## (also ui_cancel); CreditsButton opens the credits (Credits). Closing either gives
## focus back to the button that opened it.
## The reading zone (above the buttons) is the hero: the BrewMagic logo (art_src/title.px)
## pops in on arrival and then bobs, over the big animated cauldron (CauldronHero:
## bubbles and steam cycling through the essence colours).

const CONTENT_ERROR_MESSAGE := "Content error: %d problem(s) in data/*.json, see the log. The shop stays closed."
const NEW_GAME_TEXT := "New story"
const NEW_GAME_CONFIRM_TEXT := "Sure? Tap again"
## The confirm text is drawn at Silkscreen 8 (its other crisp size) so the button keeps
## its 190 width; Silkscreen 16 would widen it (playtest 2026-10-19).
const NEW_GAME_CONFIRM_FONT_SIZE := 8
const NEW_GAME_CONFIRM_TIME := 3.0
## The logo's top and the cauldron's centre, as fractions of the column height (both
## in the reading zone, above the tagline at 0.36).
const LOGO_TOP := 0.045
const POT_CENTER := 0.24
## The logo's pop-in on arrival (from POP_SCALE), then a bob of BOB_HEIGHT base units
## up and down every BOB_TIME seconds.
const POP_SCALE := 0.3
const POP_TIME := 0.45
const BOB_HEIGHT := 2.0
const BOB_TIME := 1.6

var _game: GameState
var _confirm_timer: SceneTreeTimer
var _logo_rest := Vector2.ZERO
var _bob_time := 0.0

@onready var _column: Control = $Column
@onready var _hero: CauldronHero = $Column/Hero
@onready var _logo: TextureRect = $Column/Logo
@onready var _motes: CPUParticles2D = $Column/Motes
@onready var _banner: Label = $Column/ContentErrorBanner
@onready var _open_button: Button = $Column/OpenShopButton
@onready var _new_game_button: Button = $Column/NewGameButton
@onready var _rush_button: Button = $Column/RushButton
@onready var _rush_best: Label = $Column/RushBest
@onready var _settings_button: Button = $Column/SettingsButton
@onready var _settings: SettingsPanel = $Settings
@onready var _credits_button: Button = $Column/CreditsButton
@onready var _credits: CreditsPanel = $Credits


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_logo.texture = Art.texture("title", "logo")
	_logo.size = _logo.texture.get_size()
	_logo.pivot_offset = _logo.size / 2.0
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	_logo.scale = Vector2(POP_SCALE, POP_SCALE)
	_logo.create_tween().tween_property(_logo, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_button.pressed.connect(_on_open_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_rush_button.pressed.connect(_on_rush_pressed)
	_settings_button.pressed.connect(open_settings)
	_credits_button.pressed.connect(open_credits)
	_credits.closed.connect(_on_credits_closed)
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
		_rush_button.disabled = true
		_new_game_button.hide()
		return
	var resumable := _game.can_continue()
	_open_button.text = "Continue story" if resumable else "Story mode"
	_open_button.accessibility_name = ("Continue the story on day %d" % _game.day) if resumable else "Start story mode"
	_new_game_button.visible = resumable
	_new_game_button.text = NEW_GAME_TEXT
	_new_game_button.accessibility_name = "Start a new story"
	if not resumable:
		# No New story: Rush Hour and its best line move up into its place.
		var lift := _rush_button.anchor_top - _new_game_button.anchor_top
		for control: Control in [_rush_button, _rush_best]:
			control.anchor_top -= lift
			control.anchor_bottom -= lift
	_rush_best.visible = _game.rush_best > 0
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


func open_credits() -> void:
	_credits.open(_column)


func _on_credits_closed() -> void:
	_credits_button.grab_focus(true)


## Shows `message` in the banner at the top of the screen.
func show_content_error(message: String) -> void:
	_banner.text = message
	_banner.show()


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
		# The size first: a Control grows to a wider minimum at once but never shrinks back.
		_new_game_button.add_theme_font_size_override(&"font_size", NEW_GAME_CONFIRM_FONT_SIZE)
		_new_game_button.text = NEW_GAME_CONFIRM_TEXT
		_new_game_button.accessibility_name = "Press again to erase the saved story and start a new story"
		Juice.shake(_new_game_button, 2.0, 0.2)
		_confirm_timer = get_tree().create_timer(NEW_GAME_CONFIRM_TIME)
		_confirm_timer.timeout.connect(_cancel_new_game)
		return
	_start_new_game()


func _cancel_new_game() -> void:
	_confirm_timer = null
	_new_game_button.text = NEW_GAME_TEXT
	_new_game_button.remove_theme_font_size_override(&"font_size")
	_new_game_button.accessibility_name = "Start a new story"


func _start_new_game() -> void:
	_game.new_game()
	_game.goto(GameState.Flow.MORNING)
