class_name Morning
extends Control
## Morning screen (flow MORNING): the story day Game.day, its title, its morning
## note from data/days.json on a parchment card (the first conditioned note that
## matches Game.flags, Story.morning_note), the coins and stock the day
## starts with, and "Open the shop" (thumb zone), which starts the shift; "Codex"
## under it opens the Codex over the morning. The menu icon (PauseButton, top right like
## the shop's) opens the shared settings panel titled "Menu" with Close (also ui_cancel)
## and Quit to title.
## A day missing from the data sends the player back to the title with the reason.

var _game: GameState

@onready var _column: Control = $Column
@onready var _card: PanelContainer = $Column/Card
@onready var _open_button: Button = $Column/OpenShopButton
@onready var _codex_button: Button = $Column/CodexButton
@onready var _menu_button: Button = $Column/PauseButton
@onready var _menu: SettingsPanel = $Menu


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	(_menu_button.get_node("Icon") as TextureRect).texture = Art.texture("ui", "icon_menu")
	_menu_button.pressed.connect(open_menu)
	_menu.set_title("Menu")
	var close := _menu.add_button("CloseButton", "Close", true)
	close.shortcut = Shortcut.new()
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	close.shortcut.events = [cancel]
	close.shortcut_feedback = false
	close.pressed.connect(close_menu)
	_menu.add_button("QuitButton", "Quit to title", false).pressed.connect(_game.goto.bind(GameState.Flow.TITLE, {}))
	var spec := Content.day(_game.day)
	if spec == null:
		_open_button.disabled = true
		_game.abort_to(GameState.Flow.TITLE, "Day %d is missing from data/days.json; the morning cannot start." % _game.day)
		return
	($Column/DayLabel as Label).text = "Day %d of %d" % [spec.day, Content.days().size()]
	($Column/TitleLabel as Label).text = spec.title
	($Column/Card/Note as Label).text = "\n".join(Content.wrap_bubble(Story.morning_note(spec, _game.flags)))
	var in_stock := 0
	for id in _game.stock:
		in_stock += _game.stock[id]
	($Column/Status as Label).text = "Coins: %d\nIngredients in stock: %d\nCustomers expected: %d" % [_game.coins, in_stock, Story.customers_of(spec, _game.flags).size()]
	_open_button.pressed.connect(_on_open_pressed)
	_codex_button.pressed.connect(_on_codex_pressed)
	Juice.squash(_card, 0.12)
	_open_button.grab_focus(true)
	print("[Morning] Day %d '%s': %d coins, stock %s" % [spec.day, spec.title, _game.coins, _game.stock])


func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size


## Opens the menu over the morning; Close takes focus.
func open_menu() -> void:
	_menu.open(_column, $Menu/Panel/List/CloseButton as Button)
	print("[Morning] Menu opened")


func close_menu() -> void:
	if not _menu.is_open():
		return
	_menu.close()
	_menu_button.grab_focus(true)
	print("[Morning] Menu closed")


## Opens the Codex over the morning; focus comes back to this button when it closes.
func _on_codex_pressed() -> void:
	Juice.squash(_codex_button, 0.2)
	Codex.open(self, _column).closed.connect(_codex_button.grab_focus.bind(true))


func _on_open_pressed() -> void:
	Juice.squash(_open_button, 0.2)
	_game.goto(GameState.Flow.SHOP, {"day": _game.day})
