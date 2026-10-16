class_name Shop
extends Control
## The shop shift (flow SHOP): runs one story day from Content.day(n) (n from
## Game.flow_args["day"], default day 1): its starting coins and stock, its
## customers in order, its patience scale. Layout per CLAUDE.md "Shop scene
## layout": the 270x480 Stage sits at the bottom of the ScreenFit column (extra
## height on tall phones goes above it), and its edge rows and columns are
## stretched into the rest of the visible rect so the shop fills any screen.
##
## Loop per customer: walks in, says a hint request -> the player puts 2-3
## ingredients in the pot (tap or Enter on a shelf item, or drag it into the
## cauldron; tap a pot slot to take one back) -> Brew runs the requested potion's
## station steps -> the bottle flies over, the customer reacts, pays
## (Economy.pay) and leaves. Patience running out ends the visit (Economy
## STORMED_OFF_REPUTATION, no pay), also mid-brew (the ingredients are lost).
## After the last customer the summary panel shows the day's results.
##
## Station colours: Stir shows the colour of the mix; Pour pours the requested
## potion's colour when the brew is not a Misbrew, else the mix colour, always
## in the requested potion's bottle.
##
## Taps on the workspace (SkipButton) complete or advance the speech bubble; the
## bubble itself sits in the reading zone and takes no input.

signal customer_finished(customer: Customer)
signal day_finished

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const SHELF_ITEM_SCENE := preload("res://scenes/shelf_item.tscn")
const STATION_SCENES: Dictionary[String, PackedScene] = {
	"stir": preload("res://scenes/stations/stir.tscn"),
	"pour": preload("res://scenes/stations/pour.tscn"),
}
const STAGE_SIZE := Vector2(270, 480)
const POT_CAPACITY := 3
const MIN_BREW := 2
const SHELF_SPACING := 42.0
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
const STEP_GAP := 0.5
const REACTION_HOLD := 2.4
const MISBREW_HOLD := 2.8
const STORMED_HOLD := 2.2
const LIQUID_FRAME_TIME := 0.25
const FIRE_FRAME_TIME := 0.12
const COIN_FLIGHTS_MAX := 8
const GOLD := Color("#ffc95c")
const CREAM := Color("#fbedcd")
const RED := Color("#c43c2c")
## Stage-relative bands stretched sideways into extra width: [atlas, sprite, stage y].
## A row of shop_backdrop's left edge that is plain wall (art_src/shop.px), used for the fill above the stage.
const WALL_ROW := 20.0
const BANDS: Array[Array] =[["shop", "shop_backdrop", 0.0], ["workspace", "workspace_bg", 192.0], ["workspace", "shelf_panel", 360.0]]

var day: DaySpec
var coins := 0
var reputation := 0
## Ingredient id -> count on the shelf (not counting what is in the pot).
var stock: Dictionary[String, int] = {}
var pot: Array[Ingredient] = []
var served := 0
var perfect := 0
var stormed_off := 0
## The grade of every served customer, in order.
var grades: Array[Brew.Grade] = []
## The customer at the counter, or null between customers.
var customer: Customer
## The running station, or null.
var station: Station

var _game: GameState
var _starting_coins := 0
var _shown_coins := 0
var _next_customer := 0
var _rng := RandomNumberGenerator.new()
## "<kind>/<key>" -> the line picked last time, so the next pick avoids it.
var _last_lines: Dictionary[String, String] = {}
var _shelf_items: Dictionary[String, ShelfItem] = {}
var _brewing := false
var _brew := Vector4i.ZERO
var _tier := Brew.Grade.MISBREW
var _step := 0
var _qualities: Array[float] = []
## Called once when the bubble's current line advances.
var _after_line := Callable()
var _clock := 0.0
var _fills: Array[TextureRect] = []
var _essence_counts: Array[Label] = []

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
@onready var _assist_button: Button = $Modal/PausePanel/List/AssistButton
@onready var _gentle_button: Button = $Modal/PausePanel/List/GentleButton
@onready var _summary_panel: PanelContainer = $Modal/SummaryPanel
@onready var _summary_title: Label = $Modal/SummaryPanel/List/Title
@onready var _summary_stats: Label = $Modal/SummaryPanel/List/Stats


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_setup_art()
	_game.screen_fit_changed.connect(_fit)
	_fit()
	_bubble.advanced.connect(_on_bubble_advanced)
	_skip_button.pressed.connect(_bubble.skip)
	_brew_button.pressed.connect(_on_brew_pressed)
	for i in _slots.size():
		_slots[i].pressed.connect(_on_slot_pressed.bind(i))
	_pause_button.pressed.connect(open_pause)
	$Modal/PausePanel/List/ResumeButton.pressed.connect(close_pause)
	_assist_button.toggled.connect(_on_assist_toggled)
	_gentle_button.toggled.connect(_on_gentle_toggled)
	$Modal/PausePanel/List/QuitButton.pressed.connect(_on_quit_pressed)
	$Modal/SummaryPanel/List/BackButton.pressed.connect(_on_quit_pressed)
	var number := int(_game.flow_args.get("day", Content.FIRST_DAY))
	day = Content.day(number)
	if day == null:
		# Content.day() already reported the missing day; the title screen is the only safe place to go.
		_game.goto(GameState.Flow.TITLE)
		return
	_rng.randomize()
	coins = day.starting_coins
	_starting_coins = coins
	_shown_coins = coins
	for item in Content.ingredients_unlocked_by(day.day):
		stock[item.id] = day.starting_stock.get(item.id, 0)
	_build_shelf()
	_update_pot()
	_update_hud()
	_sync_setting_buttons()
	print("[Shop] Day %d '%s': %d customers, %d coins, stock %s, patience x%.2f" % [day.day, day.title, day.customers.size(), coins, stock, day.patience_scale])
	get_tree().create_timer(FIRST_CUSTOMER_DELAY, false).timeout.connect(_spawn_next_customer)


func _process(delta: float) -> void:
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
	if _summary_panel.visible:
		return
	get_tree().paused = true
	_modal_dim.show()
	_pause_panel.show()
	Juice.squash(_pause_panel, 0.08)
	($Modal/PausePanel/List/ResumeButton as Button).grab_focus(true)
	print("[Shop] Paused")


func close_pause() -> void:
	_pause_panel.hide()
	_modal_dim.hide()
	get_tree().paused = false
	print("[Shop] Resumed")


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
	for k in Content.ESSENCES.size():
		var icon := TextureRect.new()
		icon.texture = Art.texture("ui", ESSENCE_ICONS[k])
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count := Label.new()
		count.add_theme_color_override(&"font_outline_color", Color("#1c1420"))
		count.add_theme_constant_override(&"outline_size", 4)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.accessibility_name = Content.ESSENCES[k]
		_essences.add_child(icon)
		_essences.add_child(count)
		_essence_counts.append(count)
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
	print("[Shop] Stage at %s" % stage_rect.position)


func _build_shelf() -> void:
	var ids := stock.keys()
	var left := (STAGE_SIZE.x - ids.size() * SHELF_SPACING) / 2.0 + (SHELF_SPACING - ShelfItem.ITEM_SIZE.x) / 2.0
	var layout: Array[String] = []
	for i in ids.size():
		var id: String = ids[i]
		var item := SHELF_ITEM_SCENE.instantiate() as ShelfItem
		item.setup(Content.ingredient(id), stock[id])
		item.position = Vector2(roundf(left + i * SHELF_SPACING), 0.0)
		item.chosen.connect(_on_item_chosen)
		item.dropped.connect(_on_item_dropped)
		_shelf_row.add_child(item)
		_shelf_items[id] = item
		layout.append("%s@%s" % [id, item.position + _shelf_row.position + ShelfItem.ITEM_SIZE / 2.0])
	print("[Shop] Shelf (stage coordinates): %s, brew@%s" % [", ".join(layout), _brew_button.position + _brew_button.size / 2.0])


func _spawn_next_customer() -> void:
	if _next_customer >= day.customers.size():
		_end_day()
		return
	var spec := day.customers[_next_customer]
	_next_customer += 1
	var who := Content.archetype(spec.archetype)
	var wants := Content.potion(spec.potion)
	var says := Content.request(spec.request) if spec.request != "" else _pick_request(wants.id, who.id)
	if who == null or wants == null or says == null:
		push_error("[Shop] Day %d customer %d (%s wants %s) cannot be set up; skipping" % [day.day, _next_customer, spec.archetype, spec.potion])
		_spawn_next_customer()
		return
	customer = CUSTOMER_SCENE.instantiate() as Customer
	customer.setup(who, wants, says, who.patience_seconds * day.patience_scale)
	customer.arrived.connect(_on_customer_arrived)
	customer.patience_ran_out.connect(_on_patience_ran_out)
	customer.left.connect(_on_customer_left)
	_customers.add_child(customer)
	customer.enter()
	print("[Shop] Customer %d/%d: %s wants %s (request %s, patience %.0fs)" % [_next_customer, day.customers.size(), who.id, wants.id, says.id, customer.patience_total])


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
	print("[Shop] Customer %d is waiting: \"%s\"" % [_next_customer, customer.request.text])
	_say(customer.request.text, -1.0, Callable())
	_update_pot()
	var first: ShelfItem = null
	for item: ShelfItem in _shelf_items.values():
		if not item.disabled:
			first = item
			break
	if first != null:
		# Keyboard users can start picking at once; the focus ring shows once they navigate.
		first.grab_focus(true)


func _say(text: String, hold: float, then: Callable) -> void:
	_after_line = then
	_bubble.say(text, Customer.COUNTER_X + 16.0, hold)


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
	for k in _essence_counts.size():
		_essence_counts[k].text = str(mix[k])
		_essence_counts[k].modulate.a = 1.0 if mix[k] > 0 else 0.4
	var color := _mix_color(mix)
	create_tween().tween_property(_liquid, "modulate", color, 0.3)
	_bubbles.color = color.lightened(0.3)
	_bubbles.emitting = not pot.is_empty()
	_brew_button.disabled = not _can_brew()


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
	for item in pot:
		used.append(item.id)
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
	station.tolerance_scale = _game.tolerance_scale()
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


func _station_params(step: String) -> Dictionary:
	var wants := customer.potion
	match step:
		"stir":
			return {"color": _mix_color(_brew), "tempo": Stir.DEFAULT_TEMPO}
		"pour":
			var matched := _tier != Brew.Grade.MISBREW
			return {"color": wants.color if matched else _mix_color(_brew), "bottle": wants.bottle}
	return {}


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
		&"stir_rotation":
			Juice.shake(_stage, 1.0, 0.08)
		&"pour_spill":
			Juice.shake(_stage, 2.0, 0.2)
		&"station_success":
			Juice.pop_text(_fx, station.get_global_rect().position + Vector2(135, 70), "Nice!", GOLD, 22)
		&"station_sloppy":
			Juice.shake(_stage, 2.0, 0.2)
			Juice.pop_text(_fx, station.get_global_rect().position + Vector2(135, 70), "Sloppy...", RED, 22)


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
	liquid.modulate = wants.color if _tier != Brew.Grade.MISBREW else _mix_color(_brew)
	liquid.show_behind_parent = true
	bottle.add_child(liquid)
	_fx.add_child(bottle)
	var hands := customer.get_global_transform() * Vector2(16, 30)
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
	var reputation_change := Economy.reputation_delta(grade)
	coins += pay
	reputation += reputation_change
	served += 1
	grades.append(grade)
	if grade == Brew.Grade.PERFECT:
		perfect += 1
	print("[Shop] Served customer %d/%d (%s): %s, quality %.2f, paid %d, reputation %+d, coins %d" % [_next_customer, day.customers.size(), customer.archetype.id, Brew.Grade.keys()[grade], quality, pay, reputation_change, coins])
	_update_hud()
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
		_say(_pick("misbrew/%d" % essence, narration), MISBREW_HOLD, _say.bind(reaction, REACTION_HOLD, customer.leave))
		return
	customer.react(grade)
	_coin_burst(pay)
	var label := "+%d" % pay
	Juice.pop_text(_fx, customer.get_global_transform() * Vector2(64, 14), label, GOLD, 22)
	_say(reaction, REACTION_HOLD, customer.leave)


func _coin_burst(pay: int) -> void:
	if pay <= 0:
		return
	var flights := mini(pay, COIN_FLIGHTS_MAX)
	var start := customer.get_global_transform() * Vector2(16, 24)
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


func _on_patience_ran_out() -> void:
	stormed_off += 1
	reputation += Economy.STORMED_OFF_REPUTATION
	if station != null:
		station.queue_free()
		station = null
	_show_station_layer(false)
	_brewing = false
	_update_pot()
	print("[Shop] Customer %d/%d (%s) stormed off: reputation %+d" % [_next_customer, day.customers.size(), customer.archetype.id, Economy.STORMED_OFF_REPUTATION])
	Juice.shake(_stage, 2.0, 0.3)
	var lines := customer.archetype.reactions["stormed_off"]
	_say(_pick("reaction/%s/stormed_off" % customer.archetype.id, lines), STORMED_HOLD, customer.leave)


func _on_customer_left() -> void:
	var gone := customer
	customer = null
	_bubble.close()
	_update_pot()
	_update_hud()
	gone.queue_free()
	customer_finished.emit(gone)
	get_tree().create_timer(NEXT_CUSTOMER_DELAY, false).timeout.connect(_spawn_next_customer)


func _end_day() -> void:
	var earned := coins - _starting_coins
	_summary_title.text = "Day %d done!" % day.day
	_summary_stats.text = "Served %d of %d\nPerfect brews: %d\nCoins earned: %+d\nReputation: %+d" % [served, day.customers.size(), perfect, earned, reputation]
	_modal_dim.show()
	_summary_panel.show()
	Juice.squash(_summary_panel, 0.1)
	($Modal/SummaryPanel/List/BackButton as Button).grab_focus(true)
	print("[Shop] Day %d done: served %d/%d, perfect %d, stormed off %d, coins %d (%+d), reputation %+d" % [day.day, served, day.customers.size(), perfect, stormed_off, coins, earned, reputation])
	day_finished.emit()


func _update_hud() -> void:
	if day == null:
		return
	if _shown_coins > coins:
		_shown_coins = coins
	_coins_label.text = str(_shown_coins)
	_served_label.text = "Served %d/%d" % [served, day.customers.size()]
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
	print("[Shop] Assist mode %s" % ("on" if on else "off"))
	_sync_setting_buttons()
	if station != null and station.is_running():
		station.assist = on
		station.begin(_station_params(customer.potion.steps[_step]))


## Gentle changes apply to the running station's scoring from now on.
func _on_gentle_toggled(on: bool) -> void:
	_game.gentle_mode = on
	print("[Shop] Gentle mode %s" % ("on" if on else "off"))
	_sync_setting_buttons()
	if station != null:
		station.tolerance_scale = _game.tolerance_scale()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	_game.goto(GameState.Flow.TITLE)
