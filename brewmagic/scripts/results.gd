class_name Results
extends Control
## Rush Hour results (flow RESULTS): the run just played, from Game.flow_args
## (Shop.rush_result() plus Game.finish_rush's best, best_assisted and new_best): the
## score in coins, customers served, the wave reached, a count per grade, the best
## score ("New best!" when beaten, "assisted" when set with Assist), then "Again" (a
## new run, focused) and "Title". The buttons sit in the thumb zone.

## Every key the results need (Shop.rush_result() and Game.finish_rush).
const RESULT_KEYS: Array[String] = ["score", "served", "stormed_off", "refused", "grades", "tips", "wave", "assisted", "best", "best_assisted", "new_best"]

var _game: GameState

@onready var _column: Control = $Column
@onready var _card: PanelContainer = $Column/Card
@onready var _again_button: Button = $Column/AgainButton
@onready var _title_button: Button = $Column/TitleButton


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	_again_button.pressed.connect(_on_again_pressed)
	_title_button.pressed.connect(_on_title_pressed)
	_again_button.grab_focus(true)
	var result := _game.flow_args
	if not result.has_all(RESULT_KEYS):
		# Only reachable outside a run (the scene opened on its own).
		print("[Results] No run result in flow args %s; showing empty results" % [result])
		return
	_show(result)


func _show(result: Dictionary) -> void:
	($Column/ScoreLabel as Label).text = "%d coins" % int(result["score"])
	($Column/NewBest as Label).visible = result["new_best"]
	($Column/Card/List/Served as Label).text = "Served %d, reached wave %d%s" % [int(result["served"]), int(result["wave"]), "\n(with Assist)" if result["assisted"] else ""]
	var counts: Array = result["grades"]
	var grid := $Column/Card/List/Grades as GridContainer
	for grade in Summary.GRADE_WORDS.size():
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override(&"separation", 3)
		var icon := TextureRect.new()
		icon.texture = Art.texture("ui", Shop.STAMP_ICONS[grade])
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		var count := Label.new()
		count.theme_type_variation = &"DarkLabel"
		count.text = "%s: %d" % [Summary.GRADE_WORDS[grade], int(counts[grade])]
		cell.add_child(icon)
		cell.add_child(count)
		grid.add_child(cell)
	($Column/Card/List/Details as Label).text = "Tips: %d\nStormed off: %d  Refused: %d\nBest: %d coins%s" % [
		int(result["tips"]), int(result["stormed_off"]), int(result["refused"]), int(result["best"]), " (assisted)" if result["best_assisted"] else ""]
	Juice.squash(_card, 0.12)
	print("[Results] Rush Hour: %s" % [result])


func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size


func _on_again_pressed() -> void:
	Juice.squash(_again_button, 0.2)
	_game.start_rush()


func _on_title_pressed() -> void:
	Juice.squash(_title_button, 0.2)
	_game.goto(GameState.Flow.TITLE)
