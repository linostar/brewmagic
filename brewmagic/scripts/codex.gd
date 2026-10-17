class_name Codex
extends Control
## The Codex overlay (scenes/codex.tscn): what the player has learned, from Game.codex.
## Two tabs: Words (every hint word served so far, with its essence's icon and name,
## never colour alone) and Recipes (every potion brewed at Good or better: its
## ingredients and stations). Pages of WORDS_PER_PAGE / RECIPES_PER_PAGE entries.
## The shop, the morning and the market open it on top of themselves (open()); it
## runs while the tree is paused (the shop pauses its shift while it is open). Every
## control sits in the thumb zone; Close (or ui_cancel, its shortcut) closes it and
## emits `closed`.

signal closed

enum Tab { WORDS, RECIPES }

const SCENE_PATH := "res://scenes/codex.tscn"
const WORDS_PER_PAGE := 14
const RECIPES_PER_PAGE := 5
const ICON_SIZE := Vector2(12, 12)
## Potion names on the parchment: wood mid, darker than the text around it.
const NAME_COLOR := Color("#8a5a3c")

var tab := Tab.WORDS
var page := 0

var _game: GameState

@onready var _column: Control = $Column
@onready var _words_tab: Button = $Column/Panel/List/Tabs/WordsTab
@onready var _recipes_tab: Button = $Column/Panel/List/Tabs/RecipesTab
@onready var _heading: Label = $Column/Panel/List/Heading
@onready var _entries: VBoxContainer = $Column/Panel/List/Entries
@onready var _prev_button: Button = $Column/Panel/List/Footer/PrevButton
@onready var _page_label: Label = $Column/Panel/List/Footer/Page
@onready var _next_button: Button = $Column/Panel/List/Footer/NextButton
@onready var _close_button: Button = $Column/Panel/List/Footer/CloseButton


## Opens a Codex on top of `host` (added as its last child) and returns it. `behind`
## (the host's own controls) takes no keyboard focus while the Codex is open.
static func open(host: Node, behind: Control) -> Codex:
	var codex := (load(SCENE_PATH) as PackedScene).instantiate() as Codex
	behind.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	codex.closed.connect(func() -> void: behind.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED)
	host.add_child(codex)
	return codex


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	_words_tab.pressed.connect(show_tab.bind(Tab.WORDS))
	_recipes_tab.pressed.connect(show_tab.bind(Tab.RECIPES))
	_prev_button.pressed.connect(_turn.bind(-1))
	_next_button.pressed.connect(_turn.bind(1))
	_close_button.pressed.connect(close)
	show_tab(Tab.WORDS)
	Juice.squash($Column/Panel, 0.08)
	_words_tab.grab_focus(true)
	print("[Codex] Opened: %d hint words, %d recipes" % [_game.codex_words().size(), _game.codex_recipes().size()])


## Shows tab `which` from its first page.
func show_tab(which: Tab) -> void:
	tab = which
	page = 0
	_words_tab.set_pressed_no_signal(which == Tab.WORDS)
	_recipes_tab.set_pressed_no_signal(which == Tab.RECIPES)
	_render()


func close() -> void:
	print("[Codex] Closed")
	closed.emit()
	queue_free()


## The texts of the entries shown on this page (tests read them).
func entry_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for entry in _entries.get_children():
		var parts := PackedStringArray()
		for label in entry.find_children("*", "Label", true, false):
			parts.append((label as Label).text)
		texts.append(" ".join(parts))
	return texts


func page_count() -> int:
	var per_page := WORDS_PER_PAGE if tab == Tab.WORDS else RECIPES_PER_PAGE
	return maxi(1, ceili(float(_entry_ids().size()) / per_page))


func _turn(step: int) -> void:
	page = clampi(page + step, 0, page_count() - 1)
	_render()
	Juice.squash(_entries, 0.06)


## The ids listed on the open tab, in data order: hint words (vocabulary order) or potions.
func _entry_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if tab == Tab.WORDS:
		var learned := _game.codex_words()
		for word in Content.hint_words():
			if word.id in learned:
				ids.append(word.id)
	else:
		var recipes := _game.codex_recipes()
		for potion in Content.potions():
			if recipes.has(potion.id):
				ids.append(potion.id)
	return ids


func _render() -> void:
	for child in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
	var ids := _entry_ids()
	var per_page := WORDS_PER_PAGE if tab == Tab.WORDS else RECIPES_PER_PAGE
	page = clampi(page, 0, page_count() - 1)
	var shown := ids.slice(page * per_page, (page + 1) * per_page)
	if tab == Tab.WORDS:
		_heading.text = "Hint words: %d of %d" % [ids.size(), Content.hint_words().size()]
		for row in ceili(shown.size() / 2.0):
			var line := HBoxContainer.new()
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for column in 2:
				var index := row * 2 + column
				var cell := _word_cell(Content.hint_word(shown[index])) if index < shown.size() else HBoxContainer.new()
				cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				line.add_child(cell)
			_entries.add_child(line)
	else:
		_heading.text = "Recipes: %d of %d" % [ids.size(), Content.potions().size()]
		for id in shown:
			_entries.add_child(_recipe_row(Content.potion(id), _game.codex_recipes()[id]))
	if ids.is_empty():
		var empty := _label("Serve customers to learn what their words mean." if tab == Tab.WORDS else "Brew a potion at Good or better to note its recipe.")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(230, 0)
		_entries.add_child(empty)
	_page_label.text = "Page %d/%d" % [page + 1, page_count()]
	_prev_button.disabled = page == 0
	_next_button.disabled = page >= page_count() - 1
	_page_label.accessibility_name = "%s, page %d of %d" % [_heading.text, page + 1, page_count()]


## A hint word: its essence's icon, the word and the essence's name.
func _word_cell(word: HintWord) -> HBoxContainer:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override(&"separation", 3)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(_icon(Art.texture("ui", Shop.ESSENCE_ICONS[word.essence]), Vector2(9, 9)))
	cell.add_child(_label("%s: %s" % [word.word, Content.ESSENCES[word.essence]]))
	return cell


## A recipe: the potion's name and stations, then each ingredient's icon and the names.
func _recipe_row(potion: PotionType, ingredient_ids: PackedStringArray) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override(&"separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label(potion.name)
	title.add_theme_color_override(&"font_color", NAME_COLOR)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(_label(", ".join(potion.steps)))
	row.add_child(top)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 2)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var names := PackedStringArray()
	for id in ingredient_ids:
		var item := Content.ingredient(id)
		if item == null:
			continue
		bottom.add_child(_icon(Art.texture("ingredients", id), ICON_SIZE))
		names.append(item.name)
	# Three long names are wider than the column: they wrap under each other instead.
	var listed := _label(" + ".join(names))
	listed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	listed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(listed)
	row.add_child(bottom)
	return row


func _icon(texture: Texture2D, icon_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"DarkLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size
