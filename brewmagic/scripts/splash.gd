class_name Splash
extends Control
## The splash (flow SPLASH, the main scene): the big cauldron bubbles the BrewMagic logo
## up out of itself, "made with Claude" fades in under it, and after SHOW_TIME seconds
## the title follows. A touch anywhere or any key skips straight to the title. It plays
## no sound of its own (and nothing may play before the first input anyway).

const SHOW_TIME := 1.5
## When the logo starts rising and how long it takes.
const RISE_DELAY := 0.15
const RISE_TIME := 0.6
## When "made with Claude" starts fading in, and how long it takes.
const CREDIT_DELAY := 0.75
const CREDIT_TIME := 0.3
## The pot's centre and the logo's resting centre, as fractions of the column height.
const POT_CENTER := 0.52
const LOGO_REST := 0.24

## Seconds since the splash started.
var elapsed := 0.0
## True once it has gone (or is going) to the title.
var finished := false

var _game: GameState

@onready var _column: Control = $Column
@onready var _hero: CauldronHero = $Column/Hero
@onready var _logo: TextureRect = $Column/Logo
@onready var _credit: Label = $Column/Credit


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	# The main scene is loaded by the engine, not by goto(): it says where the flow is.
	_game.state = GameState.Flow.SPLASH
	_logo.texture = Art.texture("title", "logo")
	_logo.size = _logo.texture.get_size()
	_logo.pivot_offset = _logo.size / 2.0
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	($AnyInput as AnyInput).received.connect(skip)
	_logo.scale = Vector2(0.2, 0.2)
	_logo.modulate.a = 0.0
	_credit.modulate.a = 0.0
	var surface := _hero.position + CauldronHero.SURFACE - _logo.size / 2.0
	var rest := _logo.position
	_logo.position = surface.round()
	var tween := create_tween()
	tween.tween_interval(RISE_DELAY)
	tween.tween_callback(_hero.burst)
	tween.tween_property(_logo, "modulate:a", 1.0, RISE_TIME * 0.3)
	tween.parallel().tween_property(_logo, "position", rest, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_logo, "scale", Vector2.ONE, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_credit, "modulate:a", 1.0, CREDIT_TIME).set_delay(CREDIT_DELAY - RISE_DELAY - RISE_TIME)
	tween.tween_interval(SHOW_TIME - CREDIT_DELAY - CREDIT_TIME)
	tween.tween_callback(_finish.bind("done"))
	print("[Splash] Started: the cauldron brews the logo for %.1f s (a touch or a key skips)" % SHOW_TIME)


func _process(delta: float) -> void:
	elapsed += delta


## Goes to the title now (a touch or a key).
func skip() -> void:
	_finish("skipped")


func _finish(how: String) -> void:
	if finished:
		return
	finished = true
	print("[Splash] %s after %.2f s; to the title" % ["Done" if how == "done" else "Skipped by input", elapsed])
	if _game.is_transitioning():
		await _game.transition_finished
	_game.goto(GameState.Flow.TITLE)


## Centres the pot and the logo in the column, on whole base units.
func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size
	_hero.position = (Vector2(column.size.x, column.size.y * POT_CENTER * 2.0) / 2.0 - CauldronHero.SIZE / 2.0).round()
	_logo.position = (Vector2(column.size.x / 2.0, column.size.y * LOGO_REST) - _logo.size / 2.0).round()
	_credit.position = Vector2(0, _hero.position.y + CauldronHero.SIZE.y + 12)
	_credit.size = Vector2(column.size.x, _credit.size.y)
