class_name Results
extends Control
## Rush Hour results (flow RESULTS): the run just played, from Game.flow_args
## (Shop.rush_result() plus Game.finish_rush's best, best_assisted and new_best), in
## the summary's look: "Rush Hour over" ("New best!" under it when beaten), StatTiles
## for the Score in coins ("with Assist" under it for an assisted run), Served, Wave
## reached and Tips, the grade row, Stormed off and Refused, and "Best: N coins"
## ("(assisted)" when set with Assist). The same Tally reveal as the summary, completed
## by a tap anywhere or the first press of a button. Then "Again" (a new run, focused)
## and "Title", both in the thumb zone.

## Every key the results need (Shop.rush_result() and Game.finish_rush).
const RESULT_KEYS: Array[String] = ["score", "served", "stormed_off", "refused", "grades", "tips", "wave", "assisted", "best", "best_assisted", "new_best"]

var _game: GameState
var _tally: Tally

@onready var _column: Control = $Column
@onready var _layout: VBoxContainer = $Column/Layout
@onready var _again_button: Button = $Column/Layout/AgainButton
@onready var _title_button: Button = $Column/Layout/TitleButton


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	gui_input.connect(_on_screen_input)
	_again_button.pressed.connect(_on_again_pressed)
	_title_button.pressed.connect(_on_title_pressed)
	_again_button.grab_focus(true)
	var result := _game.flow_args
	if not result.has_all(RESULT_KEYS):
		# Only reachable outside a run (the scene opened on its own).
		print("[Results] No run result in flow args %s; showing empty results" % [result])
		for row: String in ["Grades", "Counts", "Best"]:
			_layout.get_node(row).hide()
		return
	_show(result)


## True while the tally reveal runs.
func is_tallying() -> bool:
	return _tally != null and _tally.is_running()


## Completes the tally reveal at once (final numbers, every row shown).
func complete_tally() -> void:
	if is_tallying():
		print("[Results] Tally completed early")
		_tally.complete()


## The stat tile captioned `caption` ("Score", "Served", "Wave reached", "Tips").
func tile(caption: String) -> StatTile:
	return _layout.get_node_or_null("Tiles/" + caption.to_pascal_case()) as StatTile


func _show(result: Dictionary) -> void:
	($Column/Layout/Header/NewBest as Label).visible = result["new_best"]
	var tiles := Summary.add_tiles(_layout.get_node("Tiles"), [
		["coin_0", "Score", int(result["score"]), "%d", "with Assist" if result["assisted"] else ""],
		["icon_served", "Served", int(result["served"]), "%d", ""],
		["icon_wave", "Wave reached", int(result["wave"]), "%d", ""],
		["icon_tips", "Tips", int(result["tips"]), "%+d", ""],
	])
	tiles[0].burst_coins = true
	Summary.fill_grades(_layout.get_node("Grades/Row") as HBoxContainer, result["grades"])
	Summary.fill_counts(_layout.get_node("Counts") as Control, int(result["stormed_off"]), int(result["refused"]))
	($Column/Layout/Best as Label).text = "Best: %d coins%s" % [int(result["best"]), " (assisted)" if result["best_assisted"] else ""]
	var rows: Array[CanvasItem] = [_layout.get_node("Grades"), _layout.get_node("Counts"), _layout.get_node("Best")]
	_tally = Tally.new(tiles, rows)
	_tally.start(self)
	print("[Results] Rush Hour: %s" % [result])


func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size


## A tap anywhere on the screen (outside the buttons) completes the tally.
func _on_screen_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		complete_tally()


func _on_again_pressed() -> void:
	Juice.squash(_again_button, 0.2)
	if is_tallying():
		complete_tally()
		return
	_game.start_rush()


func _on_title_pressed() -> void:
	Juice.squash(_title_button, 0.2)
	if is_tallying():
		complete_tally()
		return
	_game.goto(GameState.Flow.TITLE)
