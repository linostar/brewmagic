class_name Summary
extends Control
## Evening summary (flow SUMMARY): the results of the day just played, from
## Game.flow_args (Shop.day_result()). "Day N done!" and the day's title, a 2x2 grid of
## StatTiles (Served "x/N", Coins earned, Tips, Reputation with the new total under
## it), a row of the four grade counts with their stamp icons, Stormed off and
## Refused, and "In the till: N". A Tally reveals them (tiles pop in and count up,
## then the rows fade in); a tap anywhere or the first press of the button completes
## it at once. Then "To the market" (the next day's market) or, after the last story
## day, "The ending" (the ending scene). The button is focused from the start and
## sits in the thumb zone; the layout stretches with the column (ScreenFit).

## Every key Shop.day_result() provides.
const RESULT_KEYS: Array[String] = ["day", "title", "customers", "served", "stormed_off", "refused", "grades", "earned", "tips", "reputation", "coins"]
const GRADE_WORDS: Array[String] = ["Perfect", "Good", "Meh", "Misbrew"]
const STAT_TILE := preload("res://scenes/stat_tile.tscn")
## Size the grade stamp icons are drawn at in the grade row (2x their 9x9 art).
const GRADE_ICON_SIZE := Vector2(18, 18)

var _game: GameState
var _tally: Tally

@onready var _column: Control = $Column
@onready var _layout: VBoxContainer = $Column/Layout
@onready var _continue_button: Button = $Column/Layout/ContinueButton


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	gui_input.connect(_on_screen_input)
	_continue_button.pressed.connect(_on_continue_pressed)
	var to_market := _game.at_market
	_continue_button.text = "To the market" if to_market else ("The ending" if _game.story_over() else "Back to title")
	_continue_button.accessibility_name = ("Go to the market for day %d" % _game.day) if to_market else ("See how the story ends" if _game.story_over() else "Back to title")
	_continue_button.grab_focus(true)
	var result := _game.flow_args
	if not result.has_all(RESULT_KEYS):
		# Only reachable outside the story flow (a scene opened on its own).
		print("[Summary] No day result in flow args %s; showing an empty summary" % [result])
		for row: String in ["Grades", "Counts", "Till"]:
			_layout.get_node(row).hide()
		return
	_show(result)


## True while the tally reveal runs.
func is_tallying() -> bool:
	return _tally != null and _tally.is_running()


## Completes the tally reveal at once (final numbers, every row shown).
func complete_tally() -> void:
	if is_tallying():
		print("[Summary] Tally completed early")
		_tally.complete()


## The stat tile captioned `caption` ("Served", "Coins earned", "Tips", "Reputation").
func tile(caption: String) -> StatTile:
	return _layout.get_node_or_null("Tiles/" + caption.to_pascal_case()) as StatTile


func _show(result: Dictionary) -> void:
	($Column/Layout/Header/DayLabel as Label).text = "Day %d done!" % int(result["day"])
	($Column/Layout/Header/TitleLabel as Label).text = str(result["title"])
	var tiles := add_tiles(_layout.get_node("Tiles"), [
		["icon_served", "Served", int(result["served"]), "%d/" + str(int(result["customers"])), ""],
		["coin_0", "Coins earned", int(result["earned"]), "%+d", ""],
		["icon_tips", "Tips", int(result["tips"]), "%+d", ""],
		["heart_full", "Reputation", int(result["reputation"]), "%+d", "now %d" % _game.reputation],
	])
	tiles[1].burst_coins = true
	fill_grades(_layout.get_node("Grades/Row") as HBoxContainer, result["grades"])
	fill_counts(_layout.get_node("Counts") as Control, int(result["stormed_off"]), int(result["refused"]))
	($Column/Layout/Till/Icon as TextureRect).texture = Art.texture("ui", "coin_0")
	($Column/Layout/Till/Text as Label).text = "In the till: %d" % int(result["coins"])
	var rows: Array[CanvasItem] = [_layout.get_node("Grades"), _layout.get_node("Counts"), _layout.get_node("Till")]
	_tally = Tally.new(tiles, rows)
	_tally.start(self)
	print("[Summary] Day %d: %s" % [int(result["day"]), result])


## Adds one StatTile per spec [icon sprite, caption, value, format, sub] to `grid`.
static func add_tiles(grid: Node, specs: Array) -> Array[StatTile]:
	var tiles: Array[StatTile] = []
	for spec: Array in specs:
		var stat := STAT_TILE.instantiate() as StatTile
		grid.add_child(stat)
		stat.setup(spec[0], spec[1], spec[2], spec[3], spec[4])
		tiles.append(stat)
	return tiles


## Fills `row` with one cell per grade: its stamp icon (shape-coded), the count and
## the grade's word. Cells are named after the grade (Perfect, Good, Meh, Misbrew),
## each with Icon, Count and Word.
static func fill_grades(row: HBoxContainer, counts: Array) -> void:
	for grade in GRADE_WORDS.size():
		var cell := VBoxContainer.new()
		cell.name = GRADE_WORDS[grade]
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override(&"separation", 0)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = Art.texture("ui", Shop.STAMP_ICONS[grade])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = GRADE_ICON_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count := Label.new()
		count.name = "Count"
		count.theme_type_variation = &"DarkLabel"
		count.add_theme_font_size_override(&"font_size", 25)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.text = str(int(counts[grade]))
		var word := Label.new()
		word.name = "Word"
		word.theme_type_variation = &"DarkLabel"
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word.text = GRADE_WORDS[grade]
		cell.add_child(icon)
		cell.add_child(count)
		cell.add_child(word)
		row.add_child(cell)


## Sets the Stormed off and Refused counts (each with its own icon) of `counts`.
static func fill_counts(counts: Control, stormed_off: int, refused: int) -> void:
	(counts.get_node("StormedOff/Icon") as TextureRect).texture = Art.texture("ui", "icon_stormed")
	(counts.get_node("StormedOff/Text") as Label).text = "Stormed off: %d" % stormed_off
	(counts.get_node("Refused/Icon") as TextureRect).texture = Art.texture("ui", "icon_refused")
	(counts.get_node("Refused/Text") as Label).text = "Refused: %d" % refused


func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size


## A tap anywhere on the screen (outside the button) completes the tally.
func _on_screen_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		complete_tally()


func _on_continue_pressed() -> void:
	Juice.squash(_continue_button, 0.2)
	if is_tallying():
		# The first press (Enter on the focused button, or a tap on it) completes the tally.
		complete_tally()
		return
	if _game.at_market:
		_game.goto(GameState.Flow.MARKET)
	else:
		_game.goto(GameState.Flow.ENDING if _game.story_over() else GameState.Flow.TITLE)
