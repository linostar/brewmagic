class_name Morning
extends Control
## Morning screen (flow MORNING): the story day Game.day, its title, its morning
## note from data/days.json on a parchment card, the coins and stock the day
## starts with, and "Open the shop" (thumb zone), which starts the shift.
## A day missing from the data sends the player back to the title with the reason.

var _game: GameState

@onready var _column: Control = $Column
@onready var _card: PanelContainer = $Column/Card
@onready var _open_button: Button = $Column/OpenShopButton


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	var spec := Content.day(_game.day)
	if spec == null:
		_open_button.disabled = true
		_game.abort_to(GameState.Flow.TITLE, "Day %d is missing from data/days.json; the morning cannot start." % _game.day)
		return
	($Column/DayLabel as Label).text = "Day %d" % spec.day
	($Column/TitleLabel as Label).text = spec.title
	($Column/Card/Note as Label).text = "\n".join(Content.wrap_bubble(spec.morning_note))
	var in_stock := 0
	for id in _game.stock:
		in_stock += _game.stock[id]
	($Column/Status as Label).text = "Coins: %d\nIngredients in stock: %d\nCustomers expected: %d" % [_game.coins, in_stock, spec.customers.size()]
	_open_button.pressed.connect(_on_open_pressed)
	Juice.squash(_card, 0.12)
	_open_button.grab_focus(true)
	print("[Morning] Day %d '%s': %d coins, stock %s" % [spec.day, spec.title, _game.coins, _game.stock])


func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size


func _on_open_pressed() -> void:
	Juice.squash(_open_button, 0.2)
	_game.goto(GameState.Flow.SHOP, {"day": _game.day})
