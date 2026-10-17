class_name Shop
extends Control
## The shop shift (flow SHOP): runs the ShiftConfig of story day n on the story path
## of Game.flags (Shift.story(n, flags), n from Game.flow_args["day"], default
## Game.day): its customers in order, its
## shelf, its patience scale, starting from the saved coins and stock (Game). Layout per CLAUDE.md "Shop scene
## layout": the 270x480 Stage sits at the bottom of the ScreenFit column (extra
## height on tall phones goes above it, covered by shop_ceiling copies stacked up
## from the backdrop's top edge), and its edge rows and columns are stretched
## into the rest of the visible rect so the shop fills any screen.
##
## Line: customers arrive in the day's order, one every ARRIVAL_GAP seconds while
## the line (the counter plus the queue places of Customer.SLOT_X) has room, and
## at once when it is empty. Only the one at the counter is served; the queue waits
## in front of the window (patience draining at Customer.QUEUE_PATIENCE_RATE) and
## steps forward when the served one leaves. Every visitor gets a Look from
## Look.distinct_for at the start of the day, so no two look alike. A queued
## customer whose patience runs out storms off from the queue (reputation as for
## any storm-off, its line said aside, no stamp) and the ones behind step up.
##
## Voices: while the bubble types a customer's line, every SpeechBubble.blip plays
## the speaker's voice blip (audio/sfx/voice_<archetype>.wav, tools/sfx.py) on the
## SFX bus through Game.play_sfx; narration (misbrew lines) has no voice.
##
## Loop per customer: walks in, says a hint request -> the player puts 2-3
## ingredients in the pot (tap or Enter on a shelf item, or drag it into the
## cauldron; tap a pot slot to take one back) -> Brew runs the requested potion's
## station steps -> the bottle flies over, the customer reacts, pays
## (Economy.pay plus Economy.tip) and leaves. Patience running out ends the visit (Economy
## STORMED_OFF_REPUTATION, no pay), also mid-brew (the ingredients are lost).
## After the last customer Game.finish_day() commits the day and shows the summary.
##
## Station colours: Mortar grinds the mix's colour (with the brew's `grind`
## ingredients in the bowl), Stir and Bellows show the colour of the mix; Pour pours the requested
## potion's colour when the brew is not a Misbrew, else the mix colour, always
## in the requested potion's bottle.
##
## Taps on the workspace (SkipButton) complete or advance the speech bubble; the
## bubble itself sits in the reading zone and takes no input.
##
## Keyboard focus: the pause panel keeps focus inside it (the
## Column takes no focus while it is open); the shelf and Brew take no focus
## while a station runs under its dim. Resume returns focus to the running
## station's Assist button, else to the control focused before pausing.
##
## Mode help: the "?" next to each mode toggle opens ModeHelp, a flat button over
## the whole pause panel with the mode's description in a callout above that row.
## Any tap (on the panel or the dim around it), Enter or ui_cancel (its shortcut)
## closes it and focus goes back to the "?".
##
## Grade stamp: a served customer gets a stamp on the counter front (the grade in
## words, its colour and its own icon) while "+pay" flies to the coin counter with
## the coins; a customer storming off gets none.

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const SHELF_ITEM_SCENE := preload("res://scenes/shelf_item.tscn")
const STATION_SCENES: Dictionary[String, PackedScene] = {
	"stir": preload("res://scenes/stations/stir.tscn"),
	"pour": preload("res://scenes/stations/pour.tscn"),
	"mortar": preload("res://scenes/stations/mortar.tscn"),
	"bellows": preload("res://scenes/stations/bellows.tscn"),
}
const STAGE_SIZE := Vector2(270, 480)
const POT_CAPACITY := 3
const MIN_BREW := 2
const SHELF_SPACING := 42.0
## Gap at each end of a shelf too wide for the row (it scrolls).
const SHELF_MARGIN := 4.0
## Stage-space point where flying ingredients land (the liquid surface).
const POT_MOUTH := Vector2(135, 288)
## Stage-space rect where a dragged ingredient counts as dropped into the cauldron.
const DROP_RECT := Rect2(60, 222, 150, 130)
## Stage-space point bottles fly from (the station's bottle).
const BOTTLE_START := Vector2(135, 330)
## The neutral liquid of an empty pot (palette 9) and each essence's colour (palette c, g, k, o).
const WATER_COLOR := Color("#c8c0c8")
const ESSENCE_COLORS: Array[Color] = [Color("#f07c2c"), Color("#68bede"), Color("#7cc44c"), Color("#9058c0")]
const ESSENCE_ICONS: Array[String] = ["essence_ember", "essence_frost", "essence_bloom", "essence_gloom"]
const FIRST_CUSTOMER_DELAY := 0.5
const NEXT_CUSTOMER_DELAY := 0.7
## Seconds between arrivals while the line has room.
const ARRIVAL_GAP := 8.0
const VOICE_PATH := "res://audio/sfx/voice_%s.wav"
## Each blip's pitch varies this much either way, so a line does not drone.
const VOICE_JITTER := 0.06
const STEP_GAP := 0.5
const REACTION_HOLD := 2.4
const MISBREW_HOLD := 2.8
const STORMED_HOLD := 2.2
## Side margins of a button whose caption needs more room than the theme's 12 (Refuse).
const NARROW_MARGIN := 6.0
const LIQUID_FRAME_TIME := 0.25
const FIRE_FRAME_TIME := 0.12
const COIN_FLIGHTS_MAX := 8
## Each pour's fill line lies in this range of the bottle's liquid height.
const POUR_LINE_MIN := 0.45
const POUR_LINE_MAX := 0.85
## What each mode does: its toggle's tooltip, and the callout its "?" button opens.
const ASSIST_INFO := "Auto stir, grind, pour & pump; scores Good, never Perfect"
const GENTLE_INFO := "Stir, grind, pour & pump timing is %sx more forgiving" % GameState.GENTLE_TOLERANCE_SCALE
const GOLD := Color("#ffc95c")
const CREAM := Color("#fbedcd")
const RED := Color("#c43c2c")
const GREEN := Color("#7cc44c")
const OUTLINE := Color("#1c1420")
const STONE := Color("#c8c0c8")
## Per Brew.Grade: the stamp's words, colour and icon (ui atlas; the shape tells the
## grades apart without colour: sparkle, check, tilde, cross).
const STAMP_TEXTS: Array[String] = ["PERFECT!", "GOOD", "MEH", "MISBREW"]
const STAMP_COLORS: Array[Color] = [GOLD, GREEN, STONE, RED]
const STAMP_ICONS: Array[String] = ["grade_perfect", "grade_good", "grade_meh", "grade_misbrew"]
## Stage-space centre of the stamp: the counter front, under the customer and the bubble.
const STAMP_CENTER := Vector2(135, 168)
const STAMP_HOLD := 1.2
## Stage-space point "+pay" pops at before flying to the coin counter (where the
## patience row was, right of the customer's head).
const PAY_FROM := Vector2(186, 116)
const PAY_HOLD := 0.35
## A tip pops "tip +N" this far under "+pay" and flies this much later.
const TIP_OFFSET := Vector2(0, 16)
const TIP_DELAY := 0.25
## The pot preview's mark after "in pot/needed" for each essence of the current order.
## Its shape carries the result as well as its colour: a check (MATCHED), a plus
## (MISSING: add more) or a minus (OVER: take some out). NONE: no order, no mark.
enum Need { NONE, MATCHED, MISSING, OVER }
const MARK_SIZE := Vector2(7, 7)
const NEED_COLORS: Array[Color] = [Color.TRANSPARENT, GREEN, GOLD, RED]
## Each mark as 7x7 pixel rows ("#" = lit), drawn with a 1-pixel OUTLINE around it.
const NEED_PIXELS: Array[Array] = [
	[],
	["......#", ".....##", "#...##.", "##.##..", ".###...", "..#....", "......."],
	["..###..", "..###..", "#######", "#######", "#######", "..###..", "..###.."],
	[".......", ".......", "#######", "#######", "#######", ".......", "......."],
]
## Stage-relative bands stretched sideways into extra width: [atlas, sprite, stage y].
## A row of shop_backdrop's left edge that is plain wall (art_src/shop.px), used for the fill above the stage
## beside the ceiling copies (only seen on a screen with extra width and extra height).
const WALL_ROW := 20.0
const BANDS: Array[Array] =[["shop", "shop_backdrop", 0.0], ["workspace", "workspace_bg", 192.0], ["workspace", "shelf_panel", 360.0]]

var shift: ShiftConfig
var coins := 0
## Tips received today (included in coins).
var tips := 0
var reputation := 0
## Ingredient id -> count on the shelf (not counting what is in the pot).
var stock: Dictionary[String, int] = {}
var pot: Array[Ingredient] = []
var served := 0
var perfect := 0
var stormed_off := 0
var refused := 0
## The grade of every served customer, in order.
var grades: Array[Brew.Grade] = []
## The customer at the counter (or walking up to it), or null when the line is empty.
var customer: Customer
## The customers queued behind it, in line order (place 1, 2, ...).
var queue: Array[Customer] = []
## The running station, or null.
var station: Station

var _game: GameState
var _starting_coins := 0
var _shown_coins := 0
var _next_customer := 0
## One Look per customer of the day, by index.
var _looks: Array[Look] = []
## Seconds until the next arrival (counts down only while the line has room).
var _until_arrival := FIRST_CUSTOMER_DELAY
## Customers in the shop, leaving ones included.
var _present := 0
## The current bubble line as [text, hold, then, hints, voiced], to resume after an aside.
var _line_said: Array = []
## Whose voice the bubble's blips play, or null (narration, nothing said).
var _speaker: Archetype
var _voices: Dictionary[String, AudioStream] = {}
var _rng := RandomNumberGenerator.new()
## "<kind>/<key>" -> the line picked last time, so the next pick avoids it.
var _last_lines: Dictionary[String, String] = {}
var _shelf_items: Dictionary[String, ShelfItem] = {}
## Each shelf item's x with the shelf unscrolled.
var _shelf_x: Dictionary[String, float] = {}
## How far the shelf is scrolled (0 = its left end shows) and the most it can be.
var shelf_scroll := 0.0
var _shelf_scroll_max := 0.0
var _brewing := false
var _brew := Vector4i.ZERO
var _tier := Brew.Grade.MISBREW
var _step := 0
var _qualities: Array[float] = []
## Ids of the brew's ingredients flagged `grind` (what the Mortar grinds), in pot order.
var _ground: Array[String] = []
## Called once when the bubble's current line advances.
var _after_line := Callable()
var _clock := 0.0
var _fills: Array[TextureRect] = []
## shop_ceiling copies above the stage, the first one right on the backdrop's top edge.
var _ceilings: Array[TextureRect] = []
## Per essence: the pot preview's need mark, and what it shows.
var essence_needs: Array[Need] = []
var _essence_counts: Array[Label] = []
var _essence_marks: Array[Control] = []
## The control that had focus when the pause panel opened.
var _focus_before_pause: Control
## The "?" button whose mode help is open.
var _help_opener: Button
var _stamp_tween: Tween
## Set once the last customer has left and the day is handed to Game.finish_day().
var _day_over := false

@onready var _fill: Control = $Fill
@onready var _column: Control = $Column
@onready var _stage: Control = $Column/Stage
@onready var _customers: Node2D = $Column/Stage/Customers
@onready var _bubble: SpeechBubble = $Column/Stage/Bubble
@onready var _skip_button: Button = $Column/Stage/SkipButton
@onready var _cauldron: Node2D = $Column/Stage/Cauldron
@onready var _fire: Sprite2D = $Column/Stage/Cauldron/Fire
@onready var _liquid: Sprite2D = $Column/Stage/Cauldron/Liquid
@onready var _bubbles: CPUParticles2D = $Column/Stage/Cauldron/Bubbles
@onready var _slot_row: Control = $Column/Stage/Slots
@onready var _slots: Array[Button] = [$Column/Stage/Slots/Slot0, $Column/Stage/Slots/Slot1, $Column/Stage/Slots/Slot2]
@onready var _essences: HBoxContainer = $Column/Stage/Essences
@onready var _shelf_row: Control = $Column/Stage/ShelfItems
@onready var _brew_button: Button = $Column/Stage/BrewButton
@onready var _refuse_button: Button = $Column/Stage/RefuseButton
@onready var _station_host: Control = $Column/Stage/StationHost
@onready var _station_dim: ColorRect = $Column/Stage/StationHost/Dim
@onready var _coin_icon: TextureRect = $Column/Hud/CoinIcon
@onready var _coins_label: Label = $Column/Hud/Coins
@onready var _served_label: Label = $Column/Hud/Served
@onready var _assist_tag: Label = $Column/Hud/AssistTag
@onready var _pause_button: Button = $Column/Hud/PauseButton
@onready var _fx: Node2D = $Fx
@onready var _modal: Control = $Modal
@onready var _modal_dim: ColorRect = $Modal/Dim
@onready var _pause_panel: PanelContainer = $Modal/PausePanel
@onready var _pause_list: Control = $Modal/PausePanel/List
@onready var _assist_button: Button = $Modal/PausePanel/List/AssistRow/AssistButton
@onready var _gentle_button: Button = $Modal/PausePanel/List/GentleRow/GentleButton
@onready var _assist_help: Button = $Modal/PausePanel/List/AssistRow/AssistHelp
@onready var _gentle_help: Button = $Modal/PausePanel/List/GentleRow/GentleHelp
@onready var _mode_help: Button = $Modal/ModeHelp
@onready var _help_callout: PanelContainer = $Modal/ModeHelp/Callout
@onready var _help_text: Label = $Modal/ModeHelp/Callout/Text
@onready var _help_tail: TextureRect = $Modal/ModeHelp/Tail
@onready var _stamp: PanelContainer = $Column/Stage/Stamp
@onready var _stamp_icon: TextureRect = $Column/Stage/Stamp/Row/Icon
@onready var _stamp_text: Label = $Column/Stage/Stamp/Row/Text


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_setup_art()
	_game.screen_fit_changed.connect(_fit)
	_fit()
	_bubble.advanced.connect(_on_bubble_advanced)
	_bubble.blip.connect(_on_bubble_blip)
	_skip_button.pressed.connect(_bubble.skip)
	_brew_button.pressed.connect(_on_brew_pressed)
	_refuse_button.pressed.connect(refuse_customer)
	_narrow_margins(_refuse_button)
	for i in _slots.size():
		_slots[i].pressed.connect(_on_slot_pressed.bind(i))
	_pause_button.pressed.connect(open_pause)
	$Modal/PausePanel/List/ResumeButton.pressed.connect(close_pause)
	_assist_button.toggled.connect(_on_assist_toggled)
	_gentle_button.toggled.connect(_on_gentle_toggled)
	$Modal/PausePanel/List/QuitButton.pressed.connect(_on_quit_pressed)
	_assist_button.tooltip_text = ASSIST_INFO
	_gentle_button.tooltip_text = GENTLE_INFO
	_assist_help.pressed.connect(open_mode_help.bind(_assist_help))
	_gentle_help.pressed.connect(open_mode_help.bind(_gentle_help))
	_mode_help.pressed.connect(close_mode_help)
	_modal_dim.gui_input.connect(_on_modal_dim_input)
	var number := int(_game.flow_args.get("day", _game.day))
	shift = Shift.story(number, _game.flags)
	if shift == null:
		# The title screen is the only safe place to go; the player sees why there.
		_game.abort_to(GameState.Flow.TITLE, "Day %d is missing from data/days.json; the shop cannot open." % number)
		return
	_rng.randomize()
	coins = _game.coins
	_starting_coins = coins
	_shown_coins = coins
	for item in shift.ingredients:
		stock[item.id] = _game.stock.get(item.id, 0)
	_build_shelf()
	_update_pot()
	_update_hud()
	_sync_setting_buttons()
	var parts: Array[Array] = []
	for spec in shift.customers:
		var who := Content.archetype(spec.archetype)
		parts.append(Customer.parts_of(who) if who != null else [])
	_looks = Look.distinct_for(parts, _rng.randi())
	print("[Shop] Day %d '%s': %d customers, %d coins, stock %s, patience x%.2f" % [shift.day, shift.title, shift.customers.size(), coins, stock, shift.patience_scale])


func _process(delta: float) -> void:
	_tick_arrivals(delta)
	_clock += delta
	_liquid.texture = Art.texture("brewing", "cauldron_liquid_%d" % (int(_clock / LIQUID_FRAME_TIME) % 3))
	_fire.texture = Art.texture("brewing", "fire_%d" % (int(_clock / FIRE_FRAME_TIME) % 3))


## The shelf item of ingredient `id` (tests drive it with real touches).
func shelf_item(id: String) -> ShelfItem:
	return _shelf_items.get(id)


func slot_button(index: int) -> Button:
	return _slots[index]


func brew_button() -> Button:
	return _brew_button


## True while the stations of a brew run (the shelf and the pot are locked).
func is_brewing() -> bool:
	return _brewing


## Puts one `item` from the shelf into the pot. Refused (with a shake) while
## brewing, when the pot is full or the item is out of stock.
func add_to_pot(item: ShelfItem, from_canvas: Vector2) -> bool:
	var id := item.ingredient.id
	if _brewing or pot.size() >= POT_CAPACITY or stock[id] <= 0:
		Juice.shake(item, 2.0, 0.2)
		Juice.shake(_slot_row, 2.0, 0.2)
		return false
	pot.append(item.ingredient)
	stock[id] -= 1
	item.set_stock(stock[id])
	Juice.squash(item, 0.25)
	print("[Shop] Added %s to the pot (%d/%d), %d left" % [id, pot.size(), POT_CAPACITY, stock[id]])
	_update_pot()
	_fly_ingredient(item.ingredient, from_canvas)
	return true


## Takes the ingredient in pot slot `index` back to the shelf.
func remove_from_pot(index: int) -> void:
	if _brewing or index >= pot.size():
		return
	var item: Ingredient = pot[index]
	pot.remove_at(index)
	stock[item.id] += 1
	_shelf_items[item.id].set_stock(stock[item.id])
	Juice.squash(_shelf_items[item.id], 0.25)
	Juice.squash(_slots[index], 0.3)
	print("[Shop] Took %s out of the pot (%d/%d), %d left" % [item.id, pot.size(), POT_CAPACITY, stock[item.id]])
	_update_pot()


func open_pause() -> void:
	if _day_over:
		return
	get_tree().paused = true
	_update_pot()
	_focus_before_pause = get_viewport().gui_get_focus_owner()
	_column.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_modal_dim.show()
	_pause_panel.show()
	Juice.squash(_pause_panel, 0.08)
	($Modal/PausePanel/List/ResumeButton as Button).grab_focus(true)
	print("[Shop] Paused")


func close_pause() -> void:
	if _mode_help.visible:
		close_mode_help()
	_pause_panel.hide()
	_modal_dim.hide()
	get_tree().paused = false
	_update_pot()
	_column.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	var before := _focus_before_pause
	_focus_before_pause = null
	if (station == null or station.assist_button() == null) and is_instance_valid(before) and before.is_visible_in_tree() and before.get_focus_mode_with_override() != Control.FOCUS_NONE:
		before.grab_focus(true)
	else:
		_focus_play()
	print("[Shop] Resumed")


## Shows the description of `help`'s mode (ASSIST_INFO or GENTLE_INFO) in a
## callout above its row, its tail pointing at `help`, and holds focus until closed.
func open_mode_help(help: Button) -> void:
	var text := ASSIST_INFO if help == _assist_help else GENTLE_INFO
	_help_opener = help
	_help_text.text = "\n".join(Content.wrap_bubble(text))
	_mode_help.accessibility_name = text
	_mode_help.position = _pause_panel.position
	_mode_help.size = _pause_panel.size
	_help_callout.size = Vector2.ZERO
	var at := _mode_help.get_global_transform().affine_inverse() * help.get_global_rect()
	var tail_x := at.get_center().x - _help_tail.size.x + 1.0
	_help_tail.position = Vector2(tail_x, at.position.y - _help_tail.size.y).round()
	var left := clampf(at.end.x - _help_callout.size.x, 0.0, _mode_help.size.x - _help_callout.size.x)
	_help_callout.position = Vector2(left, _help_tail.position.y - _help_callout.size.y + 1.0).round()
	_help_callout.pivot_offset = Vector2(tail_x - left, _help_callout.size.y)
	_pause_list.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_mode_help.show()
	_mode_help.grab_focus(true)
	Juice.squash(_help_callout, 0.12)
	print("[Shop] Mode help: %s" % text)


func close_mode_help() -> void:
	_mode_help.hide()
	_pause_list.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	if is_instance_valid(_help_opener):
		_help_opener.grab_focus(true)
		Juice.squash(_help_opener, 0.2)
	_help_opener = null


## A tap on the dim around the pause panel closes the mode help.
func _on_modal_dim_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed and _mode_help.visible:
		close_mode_help()


func _setup_art() -> void:
	($Column/Stage/Backdrop as TextureRect).texture = Art.texture("shop", "shop_backdrop")
	($Column/Stage/Counter as TextureRect).texture = Art.texture("shop", "shop_counter")
	($Column/Stage/Workspace as TextureRect).texture = Art.texture("workspace", "workspace_bg")
	($Column/Stage/Shelf as TextureRect).texture = Art.texture("workspace", "shelf_panel")
	($Column/Stage/Cauldron/Pot as Sprite2D).texture = Art.texture("brewing", "cauldron")
	_liquid.texture = Art.texture("brewing", "cauldron_liquid_0")
	_liquid.modulate = WATER_COLOR
	_fire.texture = Art.texture("brewing", "fire_0")
	_coin_icon.texture = Art.texture("ui", "coin_0")
	var bubble := Art.texture("ui", "bubble")
	var callout_style := StyleBoxTexture.new()
	callout_style.texture = bubble.atlas
	callout_style.region_rect = bubble.region
	callout_style.set_texture_margin_all(4.0)
	callout_style.set_content_margin_all(6.0)
	_help_callout.add_theme_stylebox_override(&"panel", callout_style)
	_help_tail.texture = Art.texture("ui", "bubble_tail")
	for k in Content.ESSENCES.size():
		var group := HBoxContainer.new()
		group.add_theme_constant_override(&"separation", 2)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = Art.texture("ui", ESSENCE_ICONS[k])
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count := Label.new()
		count.add_theme_color_override(&"font_outline_color", OUTLINE)
		count.add_theme_constant_override(&"outline_size", 4)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mark := Control.new()
		mark.custom_minimum_size = MARK_SIZE
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.draw.connect(_draw_need_mark.bind(mark, k))
		group.add_child(icon)
		group.add_child(count)
		group.add_child(mark)
		_essences.add_child(group)
		_essence_counts.append(count)
		_essence_marks.append(mark)
		essence_needs.append(Need.NONE)
	# Left and right fills per band, then the fills above and below the stage.
	for band in BANDS:
		var region := Art.texture(band[0], band[1]).region
		for column_x: float in [region.position.x, region.end.x - 1.0]:
			_fills.append(_add_fill(band[0], band[1], Rect2(column_x, region.position.y, 1.0, region.size.y)))
	var top := Art.texture("shop", "shop_backdrop").region
	# Above the stage: the plum wall (a pixel below the top beam), so tall phones see more wall.
	_fills.append(_add_fill("shop", "shop_backdrop", Rect2(top.position + Vector2(0, WALL_ROW), Vector2.ONE)))
	var bottom := Art.texture("workspace", "shelf_panel").region
	_fills.append(_add_fill("workspace", "shelf_panel", Rect2(bottom.position.x, bottom.end.y - 1.0, 1.0, 1.0)))


func _add_fill(atlas: String, sprite: String, region: Rect2) -> TextureRect:
	var texture := AtlasTexture.new()
	texture.atlas = Art.texture(atlas, sprite).atlas
	texture.region = region
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.add_child(rect)
	return rect


## Places the column and the stage (bottom of the column) and stretches the art's
## edges over the rest of the visible rect.
func _fit() -> void:
	var screen := _game.visible_rect()
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size
	_modal.position = column.position
	_modal.size = column.size
	_modal_dim.position = screen.position - column.position
	_modal_dim.size = screen.size
	Juice.reset_shake(_stage)
	_stage.position = Vector2(0.0, maxf(column.size.y - STAGE_SIZE.y, 0.0)).round()
	var stage_rect := Rect2(column.position + _stage.position, STAGE_SIZE)
	var bands := BANDS.size()
	for i in bands:
		var top: float = stage_rect.position.y + BANDS[i][2]
		var bottom: float = BANDS[i + 1][2] if i + 1 < bands else STAGE_SIZE.y
		var height: float = bottom - float(BANDS[i][2])
		_fills[i * 2].position = Vector2(screen.position.x, top)
		_fills[i * 2].size = Vector2(stage_rect.position.x - screen.position.x, height)
		_fills[i * 2 + 1].position = Vector2(stage_rect.end.x, top)
		_fills[i * 2 + 1].size = Vector2(screen.end.x - stage_rect.end.x, height)
	_fills[bands * 2].position = screen.position
	_fills[bands * 2].size = Vector2(screen.size.x, stage_rect.position.y - screen.position.y)
	_fills[bands * 2 + 1].position = Vector2(screen.position.x, stage_rect.end.y)
	_fills[bands * 2 + 1].size = Vector2(screen.size.x, screen.end.y - stage_rect.end.y)
	var ceiling := Art.texture("shop", "shop_ceiling")
	var copies := ceili((stage_rect.position.y - screen.position.y) / ceiling.get_height())
	while _ceilings.size() < copies:
		var rect := TextureRect.new()
		rect.texture = ceiling
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fill.add_child(rect)
		_ceilings.append(rect)
	for i in _ceilings.size():
		_ceilings[i].visible = i < copies
		_ceilings[i].position = stage_rect.position - Vector2(0.0, (i + 1) * ceiling.get_height())
	print("[Shop] Stage at %s, %d ceiling copies above it" % [stage_rect.position, copies])


## Lays the shelf out: centred when it fits the row, else from SHELF_MARGIN on and
## scrollable (sideways drags on the items, keyboard focus reveals the focused one).
func _build_shelf() -> void:
	var ids := stock.keys()
	var width := ids.size() * SHELF_SPACING
	var left := (STAGE_SIZE.x - width) / 2.0 + (SHELF_SPACING - ShelfItem.ITEM_SIZE.x) / 2.0
	if width > STAGE_SIZE.x:
		left = SHELF_MARGIN
		_shelf_scroll_max = SHELF_MARGIN * 2.0 + (ids.size() - 1) * SHELF_SPACING + ShelfItem.ITEM_SIZE.x - STAGE_SIZE.x
		# Items scrolled past the row's ends are hidden and cannot be tapped.
		_shelf_row.clip_contents = true
	var layout: Array[String] = []
	for i in ids.size():
		var id: String = ids[i]
		var item := SHELF_ITEM_SCENE.instantiate() as ShelfItem
		item.setup(Content.ingredient(id), stock[id])
		item.position = Vector2(roundf(left + i * SHELF_SPACING), 0.0)
		item.scrollable = _shelf_scroll_max > 0.0
		item.chosen.connect(_on_item_chosen)
		item.dropped.connect(_on_item_dropped)
		item.swiped.connect(_scroll_shelf_by)
		item.focus_entered.connect(_on_shelf_item_focused.bind(item))
		_shelf_row.add_child(item)
		_shelf_x[id] = item.position.x
		# Down from any shelf item goes to Brew (the items share a row, so Godot would pick a neighbour).
		item.focus_neighbor_bottom = item.get_path_to(_brew_button)
		_shelf_items[id] = item
		layout.append("%s@%s" % [id, item.position + _shelf_row.position + ShelfItem.ITEM_SIZE / 2.0])
	if not ids.is_empty():
		_brew_button.focus_neighbor_top = _brew_button.get_path_to(_shelf_items[ids[floori((ids.size() - 1) / 2.0)]])
	print("[Shop] Shelf (stage coordinates): %s, brew@%s%s" % [", ".join(layout), _brew_button.position + _brew_button.size / 2.0,
		(", scrolls %d" % _shelf_scroll_max) if _shelf_scroll_max > 0.0 else ""])


## Scrolls the shelf `dx` units (positive moves the items right), within 0.._shelf_scroll_max.
func _scroll_shelf_by(dx: float) -> void:
	set_shelf_scroll(shelf_scroll - dx)


## Scrolls the shelf so `scroll` units of it are left of the row (clamped to its range).
func set_shelf_scroll(scroll: float) -> void:
	shelf_scroll = clampf(scroll, 0.0, _shelf_scroll_max)
	for id in _shelf_items:
		Juice.reset_shake(_shelf_items[id])
		_shelf_items[id].position = Vector2(roundf(_shelf_x[id] - shelf_scroll), 0.0)


## Keyboard focus on a shelf item scrolls it into view. A hidden focus (the shop's own
## grab_focus(true) when a customer arrives) leaves the shelf where the thumb put it.
func _on_shelf_item_focused(item: ShelfItem) -> void:
	if item.has_focus(true):
		reveal_shelf_item(item)


## Scrolls the shelf just enough to show all of `item` (keyboard focus, tests).
func reveal_shelf_item(item: ShelfItem) -> void:
	var x := _shelf_x[item.ingredient.id] - shelf_scroll
	if x < SHELF_MARGIN:
		set_shelf_scroll(shelf_scroll + x - SHELF_MARGIN)
	elif x + ShelfItem.ITEM_SIZE.x > STAGE_SIZE.x - SHELF_MARGIN:
		set_shelf_scroll(shelf_scroll + x + ShelfItem.ITEM_SIZE.x - STAGE_SIZE.x + SHELF_MARGIN)


## Lets the next customer in when the line has room: right away (after
## NEXT_CUSTOMER_DELAY) when it is empty, else ARRIVAL_GAP after the last arrival.
func _tick_arrivals(delta: float) -> void:
	if shift == null or _next_customer >= shift.customers.size() or _line_size() >= Customer.SLOT_X.size():
		return
	if _line_size() == 0:
		_until_arrival = minf(_until_arrival, NEXT_CUSTOMER_DELAY)
	_until_arrival -= delta
	if _until_arrival <= 0.0:
		_until_arrival = ARRIVAL_GAP
		_spawn_next_customer()


## The customers in line: at (or walking to) the counter plus the queue.
func _line_size() -> int:
	return (0 if customer == null else 1) + queue.size()


## Sends in the day's next customer to the first free place in line.
func _spawn_next_customer() -> void:
	if _next_customer >= shift.customers.size():
		_check_day_done()
		return
	var spec := shift.customers[_next_customer]
	var look := _looks[_next_customer]
	_next_customer += 1
	var who := Content.archetype(spec.archetype)
	var wants := Content.potion(spec.potion)
	var says: RequestLine = null
	if who != null and wants != null:
		says = Content.request(spec.request) if spec.request != "" else _pick_request(wants.id, who.id)
	if who == null or wants == null or says == null:
		push_error("[Shop] Day %d customer %d (%s wants %s) cannot be set up; skipping" % [shift.day, _next_customer, spec.archetype, spec.potion])
		_spawn_next_customer()
		return
	var visitor := CUSTOMER_SCENE.instantiate() as Customer
	visitor.setup(who, wants, says, who.patience_seconds * shift.patience_scale, look)
	visitor.number = _next_customer
	visitor.arrived.connect(_on_customer_arrived)
	visitor.patience_ran_out.connect(_on_patience_ran_out.bind(visitor))
	visitor.left.connect(_on_customer_left.bind(visitor))
	var place := _line_size()
	if customer == null:
		customer = visitor
	else:
		queue.append(visitor)
	_customers.add_child(visitor)
	# Later arrivals are drawn behind the ones ahead of them in line.
	_customers.move_child(visitor, 0)
	_present += 1
	visitor.enter(place)
	print("[Shop] Customer %d/%d: %s wants %s (request %s, patience %.0fs, %s), place %d in line" % [visitor.number, shift.customers.size(), who.id, wants.id, says.id, visitor.patience_total, look.describe(), place])


func _pick_request(potion_id: String, archetype_id: String) -> RequestLine:
	var lines := Content.requests_for(potion_id, archetype_id)
	if lines.is_empty():
		push_error("[Shop] No request for potion '%s' in the voice of '%s'" % [potion_id, archetype_id])
		return null
	var texts := PackedStringArray()
	for line in lines:
		texts.append(line.id)
	return Content.request(_pick("request/%s/%s" % [potion_id, archetype_id], texts))


## A random entry of `options`, avoiding the one picked last time for `key` when there is a choice.
func _pick(key: String, options: PackedStringArray) -> String:
	if options.is_empty():
		push_error("[Shop] Nothing to pick for '%s'" % key)
		return ""
	var choices := Array(options)
	if choices.size() > 1:
		choices.erase(_last_lines.get(key, ""))
	var choice: String = choices[_rng.randi_range(0, choices.size() - 1)]
	_last_lines[key] = choice
	return choice


func _on_customer_arrived() -> void:
	print("[Shop] Customer %d is waiting: \"%s\"" % [customer.number, customer.request.text])
	_say(customer.request.text, -1.0, Callable(), customer.request.hints)
	_update_pot()
	_focus_play()


## Gives keyboard focus to the next thing to do: the running station's Assist
## button, else the first shelf item in stock. The focus ring shows once the
## player navigates by keyboard.
func _focus_play() -> void:
	if station != null:
		if station.assist_button() != null:
			station.assist_button().grab_focus(true)
		return
	for item: ShelfItem in _shelf_items.values():
		if not item.disabled:
			item.grab_focus(true)
			return


## Shows `text` in the bubble over the counter; `hints` (a request's hint word ids)
## marks those words; `voiced` lines blip in the customer's voice while typing.
func _say(text: String, hold: float, then: Callable, hints := PackedStringArray(), voiced := true) -> void:
	_after_line = then
	_line_said = [text, hold, then, hints, voiced]
	_speaker = customer.archetype if voiced and customer != null else null
	_bubble.say(text, Customer.COUNTER_X + Customer.CENTER_X, hold, hints)


## Says `text` over queued customer `who` for STORMED_HOLD seconds, then puts back
## the line it interrupted (if any), with its own hold and follow-up. _line_said
## keeps that line, so a second aside during the first still puts it back.
func _say_aside(text: String, who: Customer) -> void:
	var resume := _line_said.duplicate() if _bubble.visible else []
	_speaker = who.archetype
	_after_line = func() -> void:
		if resume.is_empty():
			_bubble.close()
		else:
			_say(resume[0], resume[1], resume[2], resume[3], resume[4])
	_bubble.say(text, who.position.x + Customer.CENTER_X, STORMED_HOLD)


func _on_bubble_blip() -> void:
	if _speaker == null:
		return
	var voice := _voice_of(_speaker)
	if voice != null:
		_game.play_sfx(voice, _rng.randf_range(1.0 - VOICE_JITTER, 1.0 + VOICE_JITTER))


## The voice blip of `who` (loaded once); null and reported once when missing.
func _voice_of(who: Archetype) -> AudioStream:
	if not _voices.has(who.id):
		var path := VOICE_PATH % who.id
		var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
		if stream == null:
			push_error("[Shop] No voice blip for '%s' at %s; run python3 tools/sfx.py" % [who.id, path])
		_voices[who.id] = stream
	return _voices[who.id]


func _on_bubble_advanced() -> void:
	var then := _after_line
	_after_line = Callable()
	if then.is_valid():
		then.call()


func _on_item_chosen(item: ShelfItem) -> void:
	add_to_pot(item, item.icon_canvas_center())


func _on_item_dropped(item: ShelfItem, canvas_point: Vector2) -> void:
	var local := _stage.get_global_transform().affine_inverse() * canvas_point
	if DROP_RECT.has_point(local):
		add_to_pot(item, canvas_point)
	else:
		Juice.squash(item, 0.15)


func _on_slot_pressed(index: int) -> void:
	remove_from_pot(index)


## Refreshes the slots, the essence preview, the liquid tint and the Brew button.
func _update_pot() -> void:
	for i in _slots.size():
		var filled := i < pot.size()
		_slots[i].icon = Art.texture("ingredients", pot[i].id) if filled else null
		_slots[i].disabled = not filled or _brewing
		_slots[i].focus_mode = Control.FOCUS_ALL if filled else Control.FOCUS_NONE
		_slots[i].accessibility_name = ("Take %s out of the pot" % pot[i].name) if filled else "Empty pot slot"
	var mix := _pot_essence()
	var ordered := customer != null and customer.state == Customer.State.WAIT_ORDER
	for k in _essence_counts.size():
		var needed: int = customer.potion.target[k] if ordered else 0
		var need := Need.NONE
		if ordered:
			need = Need.MATCHED if mix[k] == needed else (Need.MISSING if mix[k] < needed else Need.OVER)
		essence_needs[k] = need
		_essence_counts[k].text = ("%d/%d" % [mix[k], needed]) if ordered else str(mix[k])
		_essence_counts[k].accessibility_name = "%s: %s" % [Content.ESSENCES[k], ("%d in the pot, %d needed, %s" % [mix[k], needed, Need.keys()[need].to_lower()]) if ordered else "%d in the pot" % mix[k]]
		_essence_counts[k].get_parent().modulate.a = 1.0 if mix[k] > 0 or needed > 0 else 0.4
		_essence_marks[k].visible = need != Need.NONE
		_essence_marks[k].queue_redraw()
	var color := _mix_color(mix)
	create_tween().tween_property(_liquid, "modulate", color, 0.3)
	_bubbles.color = color.lightened(0.3)
	_bubbles.emitting = not pot.is_empty()
	_brew_button.disabled = not _can_brew()
	_refuse_button.disabled = not _can_refuse()


func _can_brew() -> bool:
	return not _brewing and pot.size() >= MIN_BREW and customer != null and customer.state == Customer.State.WAIT_ORDER


func _pot_essence() -> Vector4i:
	var essences: Array[Vector4i] = []
	for item in pot:
		essences.append(item.essence)
	return Brew.combine(essences)


## The essence colours weighted by the brew's essences; water for an empty brew.
func _mix_color(mix: Vector4i) -> Color:
	var total := mix.x + mix.y + mix.z + mix.w
	if total == 0:
		return WATER_COLOR
	var color := Color(0, 0, 0)
	for k in 4:
		color += ESSENCE_COLORS[k] * (float(mix[k]) / total)
	color.a = 1.0
	return color


## Draws essence `k`'s need mark (NEED_PIXELS) into `mark`, outline first.
func _draw_need_mark(mark: Control, k: int) -> void:
	var rows: Array = NEED_PIXELS[essence_needs[k]]
	for pass_color: Color in [OUTLINE, NEED_COLORS[essence_needs[k]]]:
		var grow := 1.0 if pass_color == OUTLINE else 0.0
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] == "#":
					mark.draw_rect(Rect2(x - grow, y - grow, 1.0 + grow * 2.0, 1.0 + grow * 2.0), pass_color)


func _fly_ingredient(item: Ingredient, from_canvas: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = Art.texture("ingredients", item.id)
	_fx.add_child(sprite)
	var mouth := _stage.get_global_transform() * POT_MOUTH
	var tween := Juice.arc(sprite, from_canvas, mouth, 40.0, 0.3)
	tween.parallel().tween_property(sprite, "rotation", TAU * 0.75, 0.3)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.3)
	tween.tween_callback(func() -> void:
		Juice.burst(_cauldron, Vector2(0, -16), _liquid.modulate.lightened(0.2), 10, Vector2(0, 160))
		Juice.squash(_cauldron, 0.15)
		sprite.queue_free())


func _on_brew_pressed() -> void:
	if not _can_brew():
		return
	_brewing = true
	_brew = _pot_essence()
	var wants := customer.potion
	var distance := Brew.distance(_brew, wants.target)
	_tier = Brew.match_tier(distance)
	var used := PackedStringArray()
	_ground.clear()
	for item in pot:
		used.append(item.id)
		if item.grind:
			_ground.append(item.id)
	print("[Shop] Brewing %s for %s: essence %s, target %s, distance %d, tier %s" % [used, wants.id, _brew, wants.target, distance, Brew.Grade.keys()[_tier]])
	pot.clear()
	_update_pot()
	Juice.squash(_brew_button, 0.2)
	Juice.squash(_cauldron, 0.25)
	customer.start_brew()
	_qualities.clear()
	_step = 0
	_start_step()


func _start_step() -> void:
	var steps := customer.potion.steps
	if _step >= steps.size():
		_finish_brew()
		return
	var step := steps[_step]
	if not STATION_SCENES.has(step):
		push_error("[Shop] Potion '%s' needs station '%s', which this build does not have; skipping it" % [customer.potion.id, step])
		_step += 1
		_start_step()
		return
	station = STATION_SCENES[step].instantiate() as Station
	station.assist = _game.assist_mode
	station.tolerance_scale = _game.tolerance_scale(step)
	station.finished.connect(_on_station_finished)
	station.feedback.connect(_on_station_feedback)
	_show_station_layer(true)
	_station_host.add_child(station)
	station.begin(_station_params(step))


## The dim behind a station; the shop's own cauldron, pot slots and essence
## preview hide under it (the station draws its own cauldron or bottle).
func _show_station_layer(on: bool) -> void:
	_station_dim.visible = on
	_cauldron.visible = not on
	_slot_row.visible = not on
	_essences.visible = not on
	# The shelf and Brew stay visible under the dim; keep keyboard focus off them.
	var behavior := Control.FOCUS_BEHAVIOR_DISABLED if on else Control.FOCUS_BEHAVIOR_INHERITED
	_shelf_row.focus_behavior_recursive = behavior
	_brew_button.focus_behavior_recursive = behavior
	_refuse_button.focus_behavior_recursive = behavior


func _station_params(step: String) -> Dictionary:
	var wants := customer.potion
	match step:
		"stir":
			return {"color": _mix_color(_brew), "tempo": Stir.DEFAULT_TEMPO}
		"pour":
			return {"color": _potion_color(), "bottle": wants.bottle, "line": pour_line(wants.bottle)}
		"mortar":
			return {"color": _mix_color(_brew), "ingredients": _ground.duplicate()}
		"bellows":
			return {"color": _mix_color(_brew)}
	return {}


## A fresh fill line for a pour into bottle `shape`: a whole liquid row of its mask
## (Pour.bottle_rows) between POUR_LINE_MIN and POUR_LINE_MAX of the liquid height.
func pour_line(shape: String) -> float:
	var rows := Pour.bottle_rows(shape)
	var height := rows.y - rows.x
	return float(_rng.randi_range(ceili(POUR_LINE_MIN * height), floori(POUR_LINE_MAX * height))) / height


## The delivered potion's colour: the requested potion's unless the brew is a Misbrew, then the mix's.
func _potion_color() -> Color:
	return customer.potion.color if _tier != Brew.Grade.MISBREW else _mix_color(_brew)


func _on_station_finished(quality: float) -> void:
	_qualities.append(quality)
	get_tree().create_timer(STEP_GAP, false).timeout.connect(_end_step.bind(station))


func _end_step(finished_station: Station) -> void:
	# The customer may have stormed off meanwhile (the station is then already gone).
	if finished_station != station or not is_instance_valid(finished_station):
		return
	station.queue_free()
	station = null
	_step += 1
	_start_step()


## The single place station feedback cues land. Visual responses only; the
## stations already animate their own part (the stream, the swirl, the pips).
func _on_station_feedback(kind: StringName) -> void:
	match kind:
		&"stir_rotation", &"mortar_stroke":
			Juice.shake(_stage, 1.0, 0.08)
		&"bellows_out":
			Juice.shake(_stage, 1.0, 0.12)
		&"pour_spill":
			Juice.shake(_stage, 2.0, 0.2)
		&"station_success":
			Juice.pop_text(_fx, station.get_global_rect().position + Vector2(135, 70), "Nice!", GOLD)
		&"station_sloppy":
			Juice.shake(_stage, 2.0, 0.2)
			Juice.pop_text(_fx, station.get_global_rect().position + Vector2(135, 70), "Sloppy...", RED)


func _finish_brew() -> void:
	_show_station_layer(false)
	var quality := Brew.gesture_quality(_qualities)
	var grade := Brew.final_grade(_tier, quality)
	customer.receive()
	_bubble.close()
	var wants := customer.potion
	var bottle := Sprite2D.new()
	bottle.texture = Art.texture("brewing", "bottle_" + wants.bottle)
	var liquid := Sprite2D.new()
	liquid.texture = Art.texture("brewing", "bottle_%s_liquid" % wants.bottle)
	liquid.modulate = _potion_color()
	liquid.show_behind_parent = true
	bottle.add_child(liquid)
	_fx.add_child(bottle)
	var hands := customer.get_global_transform() * Customer.HANDS
	bottle.scale = Vector2(Pour.BOTTLE_SCALE, Pour.BOTTLE_SCALE)
	var tween := Juice.arc(bottle, _stage.get_global_transform() * BOTTLE_START, hands, 60.0, 0.45)
	tween.parallel().tween_property(bottle, "rotation", TAU, 0.45)
	tween.parallel().tween_property(bottle, "scale", Vector2.ONE, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void:
		bottle.queue_free()
		_brewing = false
		_deliver(grade, quality))


func _deliver(grade: Brew.Grade, quality: float) -> void:
	var wants := customer.potion
	var pay := Economy.pay(wants.price, grade)
	var tip := Economy.tip(wants.price, grade, customer.archetype.tip_tendency)
	var reputation_change := Economy.reputation_delta(grade)
	coins += pay + tip
	tips += tip
	reputation += reputation_change
	served += 1
	grades.append(grade)
	if grade == Brew.Grade.PERFECT:
		perfect += 1
	print("[Shop] Served customer %d/%d (%s): %s, quality %.2f, paid %d, tip %d, reputation %+d, coins %d" % [customer.number, shift.customers.size(), customer.archetype.id, Brew.Grade.keys()[grade], quality, pay, tip, reputation_change, coins])
	_update_hud()
	_show_stamp(grade)
	var grade_key: String = Archetype.GRADES[grade]
	var reaction := _pick("reaction/%s/%s" % [customer.archetype.id, grade_key], customer.archetype.reactions[grade_key])
	if grade == Brew.Grade.MISBREW:
		var essence := Brew.misbrew_essence(_brew, wants.target)
		var effect: String = Content.MISBREW_EFFECTS[essence] if essence >= 0 else ""
		customer.react(grade, effect)
		Juice.shake(_stage, 4.0, 0.4)
		var narration := PackedStringArray()
		for line in Content.misbrews_for(maxi(essence, 0)):
			narration.append(line.text)
		print("[Shop] Misbrew: %s overshoots, effect %s" % [Content.ESSENCES[maxi(essence, 0)], effect])
		_say(_pick("misbrew/%d" % essence, narration), MISBREW_HOLD, _say.bind(reaction, REACTION_HOLD, _send_off.bind(customer)), PackedStringArray(), false)
		return
	customer.react(grade)
	_coin_burst(pay + tip)
	var stage := _stage.get_global_transform()
	if pay > 0:
		Juice.fly_text(_fx, stage * PAY_FROM, _coin_icon.get_global_rect().get_center(), "+%d" % pay, GOLD, PAY_HOLD)
	if tip > 0:
		Juice.fly_text(_fx, stage * (PAY_FROM + TIP_OFFSET), _coin_icon.get_global_rect().get_center(), "tip +%d" % tip, GOLD, PAY_HOLD + TIP_DELAY)
	_say(reaction, REACTION_HOLD, _send_off.bind(customer))


## Slams the grade stamp onto the counter front (overshooting scale, an ink puff,
## a shake for a Misbrew), holds it STAMP_HOLD seconds, then fades it out.
func _show_stamp(grade: Brew.Grade) -> void:
	if _stamp_tween != null:
		_stamp_tween.kill()
	var color := STAMP_COLORS[grade]
	_stamp_text.text = STAMP_TEXTS[grade]
	_stamp_text.add_theme_color_override(&"font_color", color)
	_stamp_icon.texture = Art.texture("ui", STAMP_ICONS[grade])
	(_stamp.get_theme_stylebox(&"panel") as StyleBoxFlat).border_color = color
	_stamp.size = Vector2.ZERO
	Juice.reset_shake(_stamp)
	_stamp.position = (STAMP_CENTER - _stamp.size / 2.0).round()
	_stamp.pivot_offset = _stamp.size / 2.0
	_stamp.scale = Vector2(2.4, 2.4)
	_stamp.modulate.a = 0.0
	_stamp.show()
	_stamp_tween = _stamp.create_tween()
	_stamp_tween.tween_property(_stamp, "modulate:a", 1.0, 0.08)
	_stamp_tween.parallel().tween_property(_stamp, "scale", Vector2(0.9, 0.9), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_stamp_tween.tween_callback(func() -> void:
		Juice.burst(_stage, STAMP_CENTER, color, 16)
		if grade == Brew.Grade.MISBREW:
			Juice.shake(_stamp, 3.0, 0.3))
	_stamp_tween.tween_property(_stamp, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stamp_tween.tween_interval(STAMP_HOLD)
	_stamp_tween.tween_property(_stamp, "modulate:a", 0.0, 0.25)
	_stamp_tween.tween_callback(_stamp.hide)


func _coin_burst(pay: int) -> void:
	if pay <= 0:
		return
	var flights := mini(pay, COIN_FLIGHTS_MAX)
	var start := customer.get_global_transform() * Customer.CHEST
	var target := _coin_icon.get_global_rect().get_center()
	for i in flights:
		var coin := Sprite2D.new()
		coin.texture = Art.texture("ui", "coin_%d" % (i % 2))
		coin.visible = false
		_fx.add_child(coin)
		var spread := Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-10.0, 4.0))
		var tween := coin.create_tween()
		tween.tween_interval(i * 0.06)
		tween.tween_callback(coin.show)
		tween.tween_property(coin, "position", start + spread, 0.0)
		tween.tween_property(coin, "position", start + spread * 2.0, 0.12).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin, "position", target, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(_coin_landed.bind(coin, i == flights - 1, ceili(float(pay) / flights)))


func _coin_landed(coin: Sprite2D, last: bool, share: int) -> void:
	coin.queue_free()
	_shown_coins = coins if last else mini(_shown_coins + share, coins)
	_coins_label.text = str(_shown_coins)
	Juice.squash(_coin_icon, 0.3, 0.16)


func _on_patience_ran_out(who: Customer) -> void:
	if who != customer:
		_storm_off_queue(who)
		return
	stormed_off += 1
	reputation += Economy.STORMED_OFF_REPUTATION
	var dropped_station := station != null
	if dropped_station:
		station.queue_free()
		station = null
	_show_station_layer(false)
	_brewing = false
	_update_pot()
	if dropped_station:
		_focus_play()
	print("[Shop] Customer %d/%d (%s) stormed off: reputation %+d" % [customer.number, shift.customers.size(), customer.archetype.id, Economy.STORMED_OFF_REPUTATION])
	Juice.shake(_stage, 2.0, 0.3)
	var lines := customer.archetype.reactions["stormed_off"]
	_say(_pick("reaction/%s/stormed_off" % customer.archetype.id, lines), STORMED_HOLD, _send_off.bind(customer))


## Gives `button` copies of its theme styles with NARROW_MARGIN side margins, so a
## caption wider than the standard 12-unit margins allow fits a narrow frame.
func _narrow_margins(button: Button) -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBox
		style.content_margin_left = NARROW_MARGIN
		style.content_margin_right = NARROW_MARGIN
		button.add_theme_stylebox_override(state, style)


## The counter customer can be refused while it waits for an order, nothing brews
## and the game is not paused.
func _can_refuse() -> bool:
	return not _brewing and not _day_over and not get_tree().paused and customer != null and customer.state == Customer.State.WAIT_ORDER


## Refuse: the counter customer is sent away (the player cannot or will not make
## its order). Anything in the pot goes back to stock, it costs
## Economy.REFUSED_REPUTATION and no pay, the customer says a refused line and
## leaves, and the queue steps forward.
func refuse_customer() -> void:
	if not _can_refuse():
		return
	var who := customer
	while not pot.is_empty():
		remove_from_pot(0)
	refused += 1
	reputation += Economy.REFUSED_REPUTATION
	who.turn_away()
	_update_pot()
	_update_hud()
	Juice.squash(_refuse_button, 0.2)
	print("[Shop] Refused customer %d/%d (%s): reputation %+d" % [who.number, shift.customers.size(), who.archetype.id, Economy.REFUSED_REPUTATION])
	_say(_pick("reaction/%s/refused" % who.archetype.id, who.archetype.reactions["refused"]), REACTION_HOLD, _send_off.bind(who))
	_focus_play()


## Queued customer `who` ran out of patience: it storms off from the queue (the
## same reputation cost, its line said aside, no stamp) and the ones behind step up.
func _storm_off_queue(who: Customer) -> void:
	stormed_off += 1
	reputation += Economy.STORMED_OFF_REPUTATION
	queue.erase(who)
	print("[Shop] Customer %d/%d (%s) stormed off from the queue: reputation %+d" % [who.number, shift.customers.size(), who.archetype.id, Economy.STORMED_OFF_REPUTATION])
	_say_aside(_pick("reaction/%s/stormed_off" % who.archetype.id, who.archetype.reactions["stormed_off"]), who)
	who.leave()
	_close_up_line()


## The customer at the counter walks out; the queue steps forward.
func _send_off(who: Customer) -> void:
	who.leave()
	if who != customer:
		return
	_bubble.close()
	_line_said = []
	_speaker = null
	customer = null if queue.is_empty() else queue.pop_front()
	_close_up_line()
	_update_pot()
	_update_hud()


## Sends everyone in line to their place: the counter, then the queue in order.
func _close_up_line() -> void:
	if customer != null and customer.slot != 0:
		customer.walk_to(0)
	for i in queue.size():
		if queue[i].slot != i + 1:
			queue[i].walk_to(i + 1)


func _on_customer_left(who: Customer) -> void:
	_present -= 1
	who.queue_free()
	_update_hud()
	_check_day_done()


## Ends the day once every customer has come in and gone.
func _check_day_done() -> void:
	if _next_customer >= shift.customers.size() and _present == 0:
		get_tree().create_timer(NEXT_CUSTOMER_DELAY, false).timeout.connect(_end_day)


## The day's results as the summary scene reads them (Game.flow_args): day, title,
## customers, served, stormed_off, refused, grades (a count per Brew.Grade), earned (pay
## without tips), tips, reputation (today's change) and coins (now).
func day_result() -> Dictionary:
	var counts: Array[int] = [0, 0, 0, 0]
	for grade in grades:
		counts[grade] += 1
	return {
		"day": shift.day, "title": shift.title, "customers": shift.customers.size(), "served": served,
		"stormed_off": stormed_off, "refused": refused, "grades": counts, "earned": coins - _starting_coins - tips, "tips": tips,
		"reputation": reputation, "coins": coins,
	}


## Commits the day. Ingredients still in the pot (put in after the last order, or
## left by a customer who stormed off before the brew) go back to stock first.
func _end_day() -> void:
	_day_over = true
	while not pot.is_empty():
		remove_from_pot(0)
	var result := day_result()
	print("[Shop] Day %d done: %s" % [shift.day, result])
	_game.finish_day(result, coins, stock, reputation)


func _update_hud() -> void:
	if shift == null:
		return
	if _shown_coins > coins:
		_shown_coins = coins
	_coins_label.text = str(_shown_coins)
	_served_label.text = "Served %d/%d" % [served, shift.customers.size()]
	_assist_tag.visible = _game.assist_mode


func _sync_setting_buttons() -> void:
	_assist_button.set_pressed_no_signal(_game.assist_mode)
	_gentle_button.set_pressed_no_signal(_game.gentle_mode)
	_assist_button.text = "Assist mode: %s" % ("On" if _game.assist_mode else "Off")
	_gentle_button.text = "Gentle mode: %s" % ("On" if _game.gentle_mode else "Off")
	_assist_button.accessibility_name = _assist_button.text
	_gentle_button.accessibility_name = _gentle_button.text
	_assist_tag.visible = _game.assist_mode


## Assist changes restart a running station in the new mode (its progress is lost).
func _on_assist_toggled(on: bool) -> void:
	_game.assist_mode = on
	_game.save_game()
	print("[Shop] Assist mode %s" % ("on" if on else "off"))
	_sync_setting_buttons()
	if station != null and station.is_running():
		station.assist = on
		station.begin(_station_params(customer.potion.steps[_step]))


## Gentle changes apply to the running station's scoring from now on.
func _on_gentle_toggled(on: bool) -> void:
	_game.gentle_mode = on
	_game.save_game()
	print("[Shop] Gentle mode %s" % ("on" if on else "off"))
	_sync_setting_buttons()
	if station != null:
		station.tolerance_scale = _game.tolerance_scale(customer.potion.steps[_step])


func _on_quit_pressed() -> void:
	get_tree().paused = false
	_game.goto(GameState.Flow.TITLE)
