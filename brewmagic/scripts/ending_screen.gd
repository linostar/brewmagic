class_name EndingScreen
extends Control
## The story's ending (flow ENDING), after the last day's summary. Game.finish_story()
## (run by Game.finish_day when the last day ends) has picked the ending (Story.ending),
## recorded it and unlocked Rush Hour; this scene shows the recorded one (opened on its
## own, before the story is over, it shows the ending of the flags so far and records nothing). Its pages
## (data/endings.json) are illustrated: the page's cast stands behind the shop counter
## (story characters in their fixed look, villagers in a look seeded by their id),
## the text sits on a parchment card. Next (tap, click or Enter, focused) turns the
## page; on the last page it reads "The end" and goes back to the title.

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
## Canvas x between two cast members standing side by side.
const CAST_SPACING := 72.0

var ending: Ending
var page := 0

var _game: GameState

@onready var _column: Control = $Column
@onready var _cast: Node2D = $Column/Picture/Cast
@onready var _title: Label = $Column/Title
@onready var _card: PanelContainer = $Column/Body/Card
@onready var _text: Label = $Column/Body/Card/Text
@onready var _page_label: Label = $Column/Body/Page
@onready var _next_button: Button = $Column/NextButton


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	($Column/Picture/Backdrop as TextureRect).texture = Art.texture("shop", "shop_backdrop")
	($Column/Picture/Counter as TextureRect).texture = Art.texture("shop", "shop_counter")
	var id := Story.ending(_game.flags, _game.reputation)
	if _game.story_over():
		# Game.finish_day recorded it when the last day ended; a save from before that records it now.
		id = str(_game.flags.get(Story.ENDING_FLAG, "")) if _game.flags.has(Story.ENDING_FLAG) else _game.finish_story()
	else:
		# Only reachable outside the story flow (the scene opened on its own).
		print("[Ending] The story is not over (day %d); showing %s without recording it" % [_game.day, id])
	ending = Content.ending(id)
	if ending == null:
		_next_button.disabled = true
		_game.abort_to(GameState.Flow.TITLE, "The ending is missing from data/endings.json; back to the title.")
		return
	_title.text = ending.title
	_next_button.pressed.connect(next_page)
	show_page(0)
	_next_button.grab_focus(true)
	print("[Ending] %s: %d pages" % [ending.id, ending.pages.size()])


## Shows page `index`: its cast and its text, and what Next does next.
func show_page(index: int) -> void:
	page = index
	_text.text = "\n".join(Content.wrap_bubble(ending.pages[index]))
	_page_label.text = "Page %d of %d" % [index + 1, ending.pages.size()]
	var last := index == ending.pages.size() - 1
	_next_button.text = "The end" if last else "Next"
	_next_button.accessibility_name = "Back to the title" if last else "Next page"
	for child in _cast.get_children():
		child.queue_free()
	var cast := ending.casts[index]
	for i in cast.size():
		var who := Content.archetype(cast[i])
		if who == null:
			continue
		var look := who.fixed_look if who.is_story() else Look.from_seed(who.id.hash())
		var figure := CUSTOMER_SCENE.instantiate() as Customer
		figure.setup(who, null, null, 1.0, look)
		_cast.add_child(figure)
		figure.position = Vector2(Customer.COUNTER_X + (i - (cast.size() - 1) / 2.0) * CAST_SPACING, Customer.CANVAS_Y).round()
		figure.modulate.a = 1.0
	Juice.squash(_card, 0.1)
	print("[Ending] Page %d/%d: cast %s" % [index + 1, ending.pages.size(), cast])


## Turns to the next page, or after the last one goes back to the title.
func next_page() -> void:
	Juice.squash(_next_button, 0.2)
	if page + 1 < ending.pages.size():
		show_page(page + 1)
	else:
		_game.goto(GameState.Flow.TITLE)


func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size
