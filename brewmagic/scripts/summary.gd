class_name Summary
extends Control
## Evening summary (flow SUMMARY): the results of the day just played, from
## Game.flow_args (Shop.day_result(): served, a count per grade, coins earned, tips,
## reputation change, stormed-off count), then "To the market" (the next day's
## market) or, after the last story day, "Back to title". The button sits in the
## thumb zone.

## Every key Shop.day_result() provides.
const RESULT_KEYS: Array[String] = ["day", "title", "customers", "served", "stormed_off", "grades", "earned", "tips", "reputation", "coins"]
const GRADE_WORDS: Array[String] = ["Perfect", "Good", "Meh", "Misbrew"]

var _game: GameState

@onready var _column: Control = $Column
@onready var _card: PanelContainer = $Column/Card
@onready var _continue_button: Button = $Column/ContinueButton


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	_continue_button.pressed.connect(_on_continue_pressed)
	var to_market := _game.at_market
	_continue_button.text = "To the market" if to_market else "Back to title"
	_continue_button.accessibility_name = ("Go to the market for day %d" % _game.day) if to_market else "Back to title"
	_continue_button.grab_focus(true)
	var result := _game.flow_args
	if not result.has_all(RESULT_KEYS):
		# Only reachable outside the story flow (a scene opened on its own).
		print("[Summary] No day result in flow args %s; showing an empty summary" % [result])
		($Column/DayLabel as Label).text = "Day done"
		return
	_show(result)


func _show(result: Dictionary) -> void:
	($Column/DayLabel as Label).text = "Day %d done!" % int(result["day"])
	($Column/TitleLabel as Label).text = str(result["title"])
	($Column/Card/List/Served as Label).text = "Served %d of %d" % [int(result["served"]), int(result["customers"])]
	var counts: Array = result["grades"]
	var grid := $Column/Card/List/Grades as GridContainer
	for grade in GRADE_WORDS.size():
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override(&"separation", 3)
		var icon := TextureRect.new()
		icon.texture = Art.texture("ui", Shop.STAMP_ICONS[grade])
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		var count := Label.new()
		count.theme_type_variation = &"DarkLabel"
		count.text = "%s: %d" % [GRADE_WORDS[grade], int(counts[grade])]
		cell.add_child(icon)
		cell.add_child(count)
		grid.add_child(cell)
	($Column/Card/List/Money as Label).text = "Coins earned: %+d\nTips: %+d\nReputation: %+d (now %d)\nStormed off: %d\nCoins in the till: %d" % [
		int(result["earned"]), int(result["tips"]), int(result["reputation"]), _game.reputation, int(result["stormed_off"]), int(result["coins"])]
	Juice.squash(_card, 0.12)
	print("[Summary] Day %d: %s" % [int(result["day"]), result])


func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size


func _on_continue_pressed() -> void:
	Juice.squash(_continue_button, 0.2)
	_game.goto(GameState.Flow.MARKET if _game.at_market else GameState.Flow.TITLE)
