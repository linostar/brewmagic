class_name Shop
extends Control
## The shop shift (flow SHOP): runs the ShiftConfig of story day n on the story path
## of Game.flags at Game.difficulty (Shift.story(n, flags, difficulty), n from
## Game.flow_args["day"], default Game.day; the level sets its visitors, patience,
## arrival gap and station tolerance): its customers in order, its shelf, starting
## from the saved coins and stock (Game). Layout per CLAUDE.md "Shop scene
## layout": the 270x480 Stage sits at the bottom of the ScreenFit column (extra
## height on tall phones goes above it, covered by shop_ceiling copies stacked up
## from the backdrop's top edge), and its edge rows and columns are stretched
## into the rest of the visible rect so the shop fills any screen.
##
## Line: customers arrive in the day's order, one every ShiftConfig.arrival_gap seconds while
## the line (the counter plus the queue places of Customer.SLOT_X) has room, and
## at once when it is empty. Only the one at the counter is served; the queue waits
## in front of the window (patience draining at Customer.QUEUE_PATIENCE_RATE) and
## steps forward when the served one leaves. Every visitor gets a Look from
## Look.distinct_for at the start of the day, so no two look alike; a story
## character wears its fixed look (Archetype.fixed_look) instead. A queued
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
## Pause menu: the shared SettingsPanel (Modal: the mode toggles with their "?"
## help, the Music and SFX volumes) with Resume and Quit to title added.
##
## Sound: every action and event plays its sound effect through Game.sfx in the same
## frame as its visual feedback (each station cue through STATION_SOUNDS, each grade
## stamp through STAMP_SOUNDS); the pour's fill sound stops with the pour.
##
## Codex: the Codex button (right of Brew) opens the Codex overlay and pauses the
## shift until it closes. Every delivery notes its request's hint words in the Codex,
## and a Good or better brew its recipe (Game.learn_words, Game.learn_recipe).
##
## Story beats: a visitor whose day entry is a story beat (Customer.visit) records its
## outcome (Story: great, poor, refused or stormed_off) in story_outcomes and says the
## beat's own line for it instead of an archetype reaction; the day's end commits the
## outcomes to Game.flags (Game.finish_day), so a quit mid-shift records none.
##
## Rush Hour (ShiftConfig.Mode.RUSH, flow_args {"rush": seed}): the same shop with an
## endless line (Rush.customer, looks from Look.next_distinct, both from a generator
## seeded by the run), arrivals and patience on Rush's curve, every ingredient
## unlimited (ShelfItem.UNLIMITED), coins counted from 0 (the score) and the run's own
## reputation from Rush.START_REPUTATION. Each wave is announced as it starts; when
## the reputation reaches 0 the run ends (RUSH_END_DELAY later Game.finish_rush shows
## the results). The story's coins, stock and reputation are never touched.
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
## The sound (Game.sfx) of each Station.feedback cue.
const STATION_SOUNDS: Dictionary[StringName, StringName] = {
	&"stir_rotation": &"stir", &"pour_start": &"pour_fill", &"pour_spill": &"pour_spill", &"pour_stop": &"pour_stop",
	&"mortar_stroke": &"mortar", &"bellows_pump": &"bellows_pump", &"bellows_out": &"bellows_out",
	&"station_success": &"success", &"station_sloppy": &"sloppy",
}
## The sound of each grade's stamp, per Brew.Grade.
const STAMP_SOUNDS: Array[StringName] = [&"stamp_perfect", &"stamp_good", &"stamp_meh", &"stamp_misbrew"]
const STAGE_SIZE := Vector2(270, 480)
const POT_CAPACITY := Brew.MAX_INGREDIENTS
const MIN_BREW := Brew.MIN_INGREDIENTS
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
const VOICE_PATH := "res://audio/sfx/voice_%s.wav"
## Each blip's pitch varies this much either way, so a line does not drone.
const VOICE_JITTER := 0.06
const STEP_GAP := 0.5
const REACTION_HOLD := 2.4
const MISBREW_HOLD := 2.8
const STORMED_HOLD := 2.2
## Seconds from a Rush Hour run's end (reputation 0) to its results screen.
const RUSH_END_DELAY := 1.6
## Stage-space centre of the Rush Hour wave banner (the workspace top, under the
## counter and the grade stamp) and how long it holds.
const WAVE_BANNER_CENTER := Vector2(135, 211)
const WAVE_BANNER_HOLD := 1.8
## Side margins of a button whose caption needs more room than the theme's 12 (Refuse).
const NARROW_MARGIN := 6.0
const LIQUID_FRAME_TIME := 0.25
const FIRE_FRAME_TIME := 0.12
const COIN_FLIGHTS_MAX := 8
## Each pour's fill line lies in this range of the bottle's liquid height.
const POUR_LINE_MIN := 0.45
const POUR_LINE_MAX := 0.85
## What each mode does: the callout its "?" button opens.
const ASSIST_INFO := SettingsPanel.ASSIST_INFO
const GENTLE_INFO := SettingsPanel.GENTLE_INFO
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
## Per Brew.Grade: the hit-stop (Juice.hit_stop, seconds) as the stamp lands; the
## best and the worst grade freeze the moment, Good and Meh do not.
const STAMP_HIT_STOPS: Array[float] = [0.08, 0.0, 0.0, 0.1]
## Stage-space point "+pay" pops at before flying to the coin counter (where the
## patience row was, right of the customer's head).
const PAY_FROM := Vector2(186, 116)
const PAY_HOLD := 0.35
## A tip pops "tip +N" this far under "+pay" and flies this much later.
const TIP_OFFSET := Vector2(0, 16)
const TIP_DELAY := 0.25
## Units between "Codex +N" and the shelf page label to its right.
const CODEX_POP_GAP := 4.0
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
## Today's story beat outcomes: flag -> Story outcome (Game.finish_day records them in Game.flags).
var story_outcomes: Dictionary[String, String] = {}
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
## The ingredient ids on each shelf page (one page when the shelf fits the row).
var _shelf_pages: Array[Array] = []
## The shelf page showing.
var shelf_page := 0
var _brewing := false
var _brew := Vector4i.ZERO
var _tier := Brew.Grade.MISBREW
var _step := 0
var _qualities: Array[float] = []
## Per delivery, the fraction of the customer's patience left (0 per storm-off), and the
## quality of every station finished by gesture (not by an Assist press): the day's
## measure of skill (Difficulty.day_score, day_result).
var patience_left: Array[float] = []
var gestures: Array[float] = []
## Ids of the brew's ingredients, in pot order (the Codex notes a good brew's recipe).
var _brew_ids := PackedStringArray()
## The open Codex overlay, or null.
var codex: Codex
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
## True while the pour's fill sound runs (pour_start until the pour stops, spills or is
## dropped): pausing the shift holds it, resuming continues it.
var _pour_sounding := false
var _stamp_tween: Tween
## Set once the last customer has left and the day is handed to Game.finish_day(),
## or a Rush Hour run's reputation reached 0.
var _day_over := false
## Rush Hour: customers and their looks come from this generator (seeded by the run),
## so a seed always brings the same line; the signatures of the run's looks so far.
var _rush_rng := RandomNumberGenerator.new()
var _rush_looks := {}
## Rush Hour: true once Assist was on at any moment of the run (marks its score).
var _assisted := false
## Rush Hour: the wave banner (built on the first wave) and its running tween.
var _wave_banner: PanelContainer
var _wave_tween: Tween

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
@onready var _shelf_prev: PageArrow = $Column/Stage/ShelfPrev
@onready var _shelf_next: PageArrow = $Column/Stage/ShelfNext
@onready var _shelf_page_label: Label = $Column/Stage/ShelfPage
@onready var _brew_button: Button = $Column/Stage/BrewButton
@onready var _refuse_button: Button = $Column/Stage/RefuseButton
@onready var _codex_button: Button = $Column/Stage/CodexButton
@onready var _station_host: Control = $Column/Stage/StationHost
@onready var _station_dim: ColorRect = $Column/Stage/StationHost/Dim
@onready var _coin_icon: TextureRect = $Column/Hud/CoinIcon
@onready var _coins_label: Label = $Column/Hud/Coins
@onready var _served_label: Label = $Column/Hud/Served
@onready var _reputation_icon: TextureRect = $Column/Hud/ReputationIcon
@onready var _reputation_label: Label = $Column/Hud/Reputation
@onready var _assist_tag: Label = $Column/Hud/AssistTag
@onready var _pause_button: Button = $Column/Hud/PauseButton
@onready var _music_toggle: Button = $Column/Hud/MusicToggle
@onready var _sfx_toggle: Button = $Column/Hud/SfxToggle
@onready var _fx: Node2D = $Fx
## The pause menu: the shared settings panel with Resume and Quit to title added.
@onready var _modal: SettingsPanel = $Modal
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
	_codex_button.pressed.connect(open_codex)
	_shelf_prev.pressed.connect(turn_shelf.bind(-1))
	_shelf_next.pressed.connect(turn_shelf.bind(1))
	_shelf_prev.stepped_past.connect(_step_past_shelf_arrow.bind(-1))
	_shelf_next.stepped_past.connect(_step_past_shelf_arrow.bind(1))
	_narrow_margins(_refuse_button)
	for i in _slots.size():
		_slots[i].pressed.connect(_on_slot_pressed.bind(i))
	_pause_button.pressed.connect(open_pause)
	(_pause_button.get_node("Icon") as TextureRect).texture = Art.texture("ui", "icon_menu")
	_music_toggle.pressed.connect(toggle_music)
	_sfx_toggle.pressed.connect(toggle_sfx)
	_game.audio_settings_changed.connect(_sync_sound_toggles)
	# The top-right row sits above everything else; Down from it goes to Brew.
	for button: Button in [_music_toggle, _sfx_toggle, _pause_button]:
		button.focus_neighbor_bottom = button.get_path_to(_brew_button)
	_sync_sound_toggles()
	_modal.set_title("Paused")
	_modal.add_button("ResumeButton", "Resume", true).pressed.connect(close_pause)
	_modal.add_button("QuitButton", "Quit to title", false).pressed.connect(_on_quit_pressed)
	_modal.assist_changed.connect(_on_assist_toggled)
	_modal.gentle_changed.connect(_on_gentle_toggled)
	_rng.randomize()
	if _game.flow_args.has("rush"):
		shift = Shift.rush(int(_game.flow_args["rush"]))
		_rush_rng.seed = shift.run_seed
		reputation = Rush.START_REPUTATION
		_assisted = _game.assist_mode
		for item in shift.ingredients:
			stock[item.id] = ShelfItem.UNLIMITED
	else:
		var number := int(_game.flow_args.get("day", _game.day))
		shift = Shift.story(number, _game.flags, _game.difficulty)
		if shift == null:
			# The title screen is the only safe place to go; the player sees why there.
			_game.abort_to(GameState.Flow.TITLE, "Day %d is missing from data/days.json; the shop cannot open." % number)
			return
		coins = _game.coins
		for item in shift.ingredients:
			stock[item.id] = _game.stock.get(item.id, 0)
		var parts: Array[Array] = []
		for spec in shift.customers:
			var who := Content.archetype(spec.archetype)
			parts.append(Customer.parts_of(who) if who != null else [])
		_looks = Look.distinct_for(parts, _rng.randi())
	_starting_coins = coins
	_shown_coins = coins
	_reputation_icon.texture = Art.texture("ui", "heart_full")
	_reputation_icon.visible = shift.is_rush()
	_reputation_label.visible = shift.is_rush()
	_build_shelf()
	_update_pot()
	_update_hud()
	_sync_setting_buttons()
	if shift.is_rush():
		print("[Shop] Rush Hour run (seed %d): %d coins, reputation %d, unlimited stock of %d ingredients, patience x%.2f" % [shift.run_seed, coins, reputation, stock.size(), shift.patience_scale])
		_announce_wave()
	else:
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
	if _brewing or pot.size() >= POT_CAPACITY or stock[id] == 0:
		Juice.shake(item, 2.0, 0.2)
		Juice.shake(_slot_row, 2.0, 0.2)
		_game.sfx(&"nope")
		return false
	pot.append(item.ingredient)
	if stock[id] != ShelfItem.UNLIMITED:
		stock[id] -= 1
		item.set_stock(stock[id])
	Juice.squash(item, 0.25)
	_game.sfx(&"drop")
	print("[Shop] Added %s to the pot (%d/%d), %s left" % [id, pot.size(), POT_CAPACITY, _stock_text(id)])
	_update_pot()
	_fly_ingredient(item.ingredient, from_canvas)
	return true


## Takes the ingredient in pot slot `index` back to the shelf.
func remove_from_pot(index: int) -> void:
	if _brewing or index >= pot.size():
		return
	var item: Ingredient = pot[index]
	pot.remove_at(index)
	if stock[item.id] != ShelfItem.UNLIMITED:
		stock[item.id] += 1
		_shelf_items[item.id].set_stock(stock[item.id])
	Juice.squash(_shelf_items[item.id], 0.25)
	Juice.squash(_slots[index], 0.3)
	_game.sfx(&"slot_remove")
	print("[Shop] Took %s out of the pot (%d/%d), %s left" % [item.id, pot.size(), POT_CAPACITY, _stock_text(item.id)])
	_update_pot()


## How many of ingredient `id` are left, in words for the log.
func _stock_text(id: String) -> String:
	return "unlimited" if stock[id] == ShelfItem.UNLIMITED else str(stock[id])


func open_pause() -> void:
	if _day_over:
		return
	get_tree().paused = true
	_hold_pour_sound(true)
	_update_pot()
	_focus_before_pause = get_viewport().gui_get_focus_owner()
	_modal.open(_column, $Modal/Panel/List/ResumeButton as Button)
	print("[Shop] Paused")


func close_pause() -> void:
	_modal.close()
	_resume()
	print("[Shop] Resumed")


## Opens the Codex over the shop; the shift pauses until it closes.
func open_codex() -> void:
	if _day_over or codex != null or get_tree().paused:
		return
	get_tree().paused = true
	_hold_pour_sound(true)
	_update_pot()
	# Closing the Codex returns to the button that opened it.
	_focus_before_pause = _codex_button
	_column.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	Juice.squash(_codex_button, 0.2)
	codex = Codex.open(self, _column)
	codex.closed.connect(_on_codex_closed)
	print("[Shop] Codex opened, shift paused")


func _on_codex_closed() -> void:
	codex = null
	_resume()
	print("[Shop] Codex closed, shift resumed")


## Unpauses the shift and gives focus back: to the running station's Assist button,
## else to the control focused before the pause (or the Codex) opened.
func _resume() -> void:
	get_tree().paused = false
	_hold_pour_sound(false)
	_update_pot()
	_column.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	var before := _focus_before_pause
	_focus_before_pause = null
	if (station == null or station.assist_button() == null) and is_instance_valid(before) and before.is_visible_in_tree() and before.get_focus_mode_with_override() != Control.FOCUS_NONE:
		before.grab_focus(true)
	else:
		_focus_play()


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


## Lays the shelf out. When every item fits the row it is centred and has no
## arrows; else it is split into pages of as many whole items as fit between the
## ShelfPrev and ShelfNext arrows, each page centred between them, and one page
## shows at a time. Items keep their page and place all shift (an item out of
## stock stays), so pages never reflow.
func _build_shelf() -> void:
	var ids: Array = stock.keys()
	var left_end := 0.0
	var span := STAGE_SIZE.x
	var per_page := ids.size()
	if ids.size() * SHELF_SPACING > STAGE_SIZE.x:
		left_end = _shelf_prev.position.x + _shelf_prev.size.x
		span = _shelf_next.position.x - left_end
		per_page = floori((span - ShelfItem.ITEM_SIZE.x) / SHELF_SPACING) + 1
	for start in range(0, maxi(ids.size(), 1), maxi(per_page, 1)):
		_shelf_pages.append(ids.slice(start, start + per_page))
	var paged := _shelf_pages.size() > 1
	_shelf_prev.visible = paged
	_shelf_next.visible = paged
	_shelf_page_label.visible = paged
	var layout: Array[String] = []
	for page in _shelf_pages:
		var left := left_end + (span - (page.size() - 1) * SHELF_SPACING - ShelfItem.ITEM_SIZE.x) / 2.0
		for i in page.size():
			var id: String = page[i]
			var item := SHELF_ITEM_SCENE.instantiate() as ShelfItem
			item.setup(Content.ingredient(id), stock[id])
			item.position = Vector2(roundf(left + i * SHELF_SPACING), 0.0)
			item.chosen.connect(_on_item_chosen)
			item.dropped.connect(_on_item_dropped)
			_shelf_row.add_child(item)
			# Down from any shelf item goes to Brew (the items share a row, so Godot would pick a neighbour).
			item.focus_neighbor_bottom = item.get_path_to(_brew_button)
			# A page's end items lead onto its arrows (which lead on to the next page).
			if paged and i == 0:
				item.focus_neighbor_left = item.get_path_to(_shelf_prev)
			if paged and i == page.size() - 1:
				item.focus_neighbor_right = item.get_path_to(_shelf_next)
			_shelf_items[id] = item
			layout.append("%s@%s" % [id, item.position + _shelf_row.position + ShelfItem.ITEM_SIZE / 2.0])
	set_shelf_page(0)
	print("[Shop] Shelf (stage coordinates): %s, brew@%s%s" % [", ".join(layout), _brew_button.position + _brew_button.size / 2.0,
		(", %d pages of %d" % [_shelf_pages.size(), per_page]) if paged else ""])


## Shows shelf page `page` (clamped) and hides the others: the arrows disable at
## the ends (no wrap), the label reads "N/M", and the arrows and Brew lead
## keyboard focus onto this page's items.
func set_shelf_page(page: int) -> void:
	shelf_page = clampi(page, 0, _shelf_pages.size() - 1)
	for p in _shelf_pages.size():
		for id: String in _shelf_pages[p]:
			_shelf_items[id].visible = p == shelf_page
	var shown: Array = _shelf_pages[shelf_page]
	if shown.is_empty():
		return
	var first := _shelf_items[shown[0]]
	var last := _shelf_items[shown[-1]]
	_brew_button.focus_neighbor_top = _brew_button.get_path_to(_shelf_items[shown[floori((shown.size() - 1) / 2.0)]])
	_shelf_prev.focus_neighbor_right = _shelf_prev.get_path_to(first)
	_shelf_next.focus_neighbor_left = _shelf_next.get_path_to(last)
	_shelf_prev.disabled = shelf_page == 0
	_shelf_next.disabled = shelf_page == _shelf_pages.size() - 1
	_shelf_page_label.text = "%d/%d" % [shelf_page + 1, _shelf_pages.size()]
	_shelf_page_label.accessibility_name = "Ingredients page %d of %d" % [shelf_page + 1, _shelf_pages.size()]


## Turns the shelf `step` pages (an arrow's tap or Enter), with a squash on the
## arrow and the items that come into view.
func turn_shelf(step: int) -> void:
	var to := clampi(shelf_page + step, 0, _shelf_pages.size() - 1)
	var arrow := _shelf_next if step > 0 else _shelf_prev
	Juice.squash(arrow, 0.2)
	if to == shelf_page:
		return
	set_shelf_page(to)
	_game.sfx(&"page_flip")
	for id: String in _shelf_pages[shelf_page]:
		Juice.squash(_shelf_items[id], 0.12)
	print("[Shop] Shelf page %d/%d: %s" % [shelf_page + 1, _shelf_pages.size(), ", ".join(_shelf_pages[shelf_page])])


## Focus moved on past an arrow (ui_left on Prev, ui_right on Next): turns the
## page and focuses the item next to that arrow on the new page.
func _step_past_shelf_arrow(step: int) -> void:
	if (_shelf_prev if step < 0 else _shelf_next).disabled:
		return
	turn_shelf(step)
	var shown: Array = _shelf_pages[shelf_page]
	_shelf_items[shown[-1] if step < 0 else shown[0]].grab_focus()


## Turns the shelf to the page holding `item` (tests reach every item this way).
func show_shelf_item(item: ShelfItem) -> void:
	for p in _shelf_pages.size():
		if item.ingredient.id in _shelf_pages[p]:
			set_shelf_page(p)
			return


## Lets the next customer in when the line has room: right away (after
## NEXT_CUSTOMER_DELAY) when it is empty, else ShiftConfig.arrival_gap after the last
## arrival (ShiftConfig.arrival_gap: the difficulty's gap on a story day; shrinking in Rush Hour, which is endless).
func _tick_arrivals(delta: float) -> void:
	if shift == null or _day_over or _line_size() >= Customer.SLOT_X.size() or not shift.has_customer(_next_customer):
		return
	if _line_size() == 0:
		_until_arrival = minf(_until_arrival, NEXT_CUSTOMER_DELAY)
	_until_arrival -= delta
	if _until_arrival <= 0.0:
		_until_arrival = shift.arrival_gap(served)
		_spawn_next_customer()


## "N/M" for customer number `number` of a story day; just "N" in endless Rush Hour.
func _of_total(number: int) -> String:
	return str(number) if shift.is_rush() else "%d/%d" % [number, shift.customers.size()]


## The customers in line: at (or walking to) the counter plus the queue.
func _line_size() -> int:
	return (0 if customer == null else 1) + queue.size()


## Sends in the day's next customer to the first free place in line.
func _spawn_next_customer() -> void:
	if not shift.has_customer(_next_customer):
		_check_day_done()
		return
	var spec := shift.customer_at(_next_customer, served, _rush_rng)
	var who := Content.archetype(spec.archetype)
	var look: Look
	if shift.is_rush():
		var part_names: Array[String] = []
		part_names.assign(Customer.parts_of(who) if who != null else [])
		look = Look.next_distinct(part_names, _rush_rng, _rush_looks, _next_customer + 1)
	else:
		look = _looks[_next_customer]
	_next_customer += 1
	var patience_scale := shift.patience_at(served)
	var wants := Content.potion(spec.potion)
	var says: RequestLine = null
	if who != null and wants != null:
		says = Content.request(spec.request) if spec.request != "" else _pick_request(wants.id, who.id)
	if who == null or wants == null or says == null:
		push_error("[Shop] %s customer %d (%s wants %s) cannot be set up; skipping" % [shift.title, _next_customer, spec.archetype, spec.potion])
		_spawn_next_customer()
		return
	if who.is_story():
		# A story character always wears its own look, so it is recognised on every visit.
		look = who.fixed_look
	var visitor := CUSTOMER_SCENE.instantiate() as Customer
	visitor.setup(who, wants, says, who.patience_seconds * patience_scale, look)
	visitor.number = _next_customer
	visitor.visit = spec
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
	_game.sfx(&"door_bell")
	print("[Shop] Customer %s: %s wants %s (request %s, patience %.0fs, %s), place %d in line" % [_of_total(visitor.number), who.id, wants.id, says.id, visitor.patience_total, look.describe(), place])


func _pick_request(potion_id: String, archetype_id: String) -> RequestLine:
	var lines := Content.requests_for(potion_id, archetype_id)
	if lines.is_empty():
		push_error("[Shop] No request for potion '%s' in the voice of '%s'" % [potion_id, archetype_id])
		return null
	var texts := PackedStringArray()
	for line in lines:
		texts.append(line.id)
	return Content.request(_pick("request/%s/%s" % [potion_id, archetype_id], texts))


## The line `who` says for reaction `key` (a grade of Archetype.GRADES, "stormed_off" or
## "refused") whose story outcome is `outcome` (Story.OUTCOMES). A story beat records the
## outcome under its flag (story_outcomes, committed with the day) and says its own line;
## anyone else says one of its archetype's lines.
func _reaction_line(who: Customer, key: String, outcome: String) -> String:
	if who.visit != null and who.visit.beat != "":
		story_outcomes[who.visit.flag()] = outcome
		print("[Shop] Story beat %s: %s" % [who.visit.flag(), outcome])
		return who.visit.lines[outcome]
	return _pick("reaction/%s/%s" % [who.archetype.id, key], who.archetype.reactions[key])


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
## button, else the first shelf item in stock on the page showing (the page stays
## where the thumb left it), else a shelf arrow that can turn the page. The focus
## ring shows once the player navigates by keyboard.
func _focus_play() -> void:
	if station != null:
		if station.assist_button() != null:
			station.assist_button().grab_focus(true)
		return
	var choices: Array[Button] = []
	for id: String in _shelf_pages[shelf_page]:
		choices.append(_shelf_items[id])
	choices.append_array([_shelf_next, _shelf_prev])
	for choice in choices:
		if choice.visible and not choice.disabled:
			choice.grab_focus(true)
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
		_game.sfx(&"splash")
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
	_brew_ids = used
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
	station.tolerance_scale = _game.tolerance_scale(step) * shift.tolerance_scale
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
	_shelf_prev.focus_behavior_recursive = behavior
	_shelf_next.focus_behavior_recursive = behavior
	_brew_button.focus_behavior_recursive = behavior
	_refuse_button.focus_behavior_recursive = behavior
	_codex_button.focus_behavior_recursive = behavior


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
	if not station.assist:
		gestures.append(quality)
	get_tree().create_timer(STEP_GAP, false).timeout.connect(_end_step.bind(station))


func _end_step(finished_station: Station) -> void:
	# The customer may have stormed off meanwhile (the station is then already gone).
	if finished_station != station or not is_instance_valid(finished_station):
		return
	station.queue_free()
	station = null
	_step += 1
	_start_step()


## The single place station feedback cues land: each plays its sound (STATION_SOUNDS)
## and some add a visual response; the stations already animate their own part (the
## stream, the swirl, the pips). The pour's fill sound runs from pour_start until the
## pour stops or spills (held while the shift is paused).
func _on_station_feedback(kind: StringName) -> void:
	if kind == &"pour_stop" or kind == &"pour_spill":
		_stop_pour_sound()
	elif kind == &"pour_start":
		_pour_sounding = true
	if STATION_SOUNDS.has(kind):
		_game.sfx(STATION_SOUNDS[kind])
	else:
		push_error("[Shop] Station feedback '%s' has no sound in STATION_SOUNDS" % kind)
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


## Drops the running station, if any (a storm-off, the end of a Rush Hour run), with its pour sound.
func _drop_station() -> bool:
	_stop_pour_sound()
	if station == null:
		return false
	station.queue_free()
	station = null
	return true


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
	# A Rush Hour run that ended while the bottle flew pays nothing more.
	if _day_over:
		return
	var wants := customer.potion
	var pay := Economy.pay(wants.price, grade)
	var tip := Economy.tip(wants.price, grade, customer.archetype.tip_tendency)
	var reputation_change := Rush.reputation_delta(grade) if shift.is_rush() else Economy.reputation_delta(grade)
	coins += pay + tip
	tips += tip
	reputation += reputation_change
	served += 1
	grades.append(grade)
	patience_left.append(customer.patience_left / customer.patience_total)
	if grade == Brew.Grade.PERFECT:
		perfect += 1
	print("[Shop] Served customer %s (%s): %s, quality %.2f, paid %d, tip %d, reputation %+d, coins %d" % [_of_total(customer.number), customer.archetype.id, Brew.Grade.keys()[grade], quality, pay, tip, reputation_change, coins])
	_update_hud()
	if shift.is_rush() and Rush.wave(served) > Rush.wave(served - 1):
		_announce_wave()
	_check_rush_over()
	_show_stamp(grade)
	_note_in_codex(grade)
	var grade_key: String = Archetype.GRADES[grade]
	var reaction := _reaction_line(customer, grade_key, Story.outcome_for(grade))
	if grade == Brew.Grade.MISBREW:
		var essence := Brew.misbrew_essence(_brew, wants.target)
		var effect: String = Content.MISBREW_EFFECTS[essence] if essence >= 0 else ""
		customer.react(grade, effect)
		Juice.shake(_stage, 4.0, 0.4)
		_game.sfx(&"misbrew")
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
		_game.sfx(&"coins")
	if tip > 0:
		Juice.fly_text(_fx, stage * (PAY_FROM + TIP_OFFSET), _coin_icon.get_global_rect().get_center(), "tip +%d" % tip, GOLD, PAY_HOLD + TIP_DELAY)
		_game.sfx(&"tip")
	_say(reaction, REACTION_HOLD, _send_off.bind(customer))


## Notes what this delivery taught in the Codex: the request's hint words (any grade),
## and the recipe when the brew was Good or better. "Codex +N" pops above the Codex button,
## ending CODEX_POP_GAP left of the shelf page label (centred over the button it read
## "Codex 1/43" on a paged shelf; screenshot capture 2026-10-20).
func _note_in_codex(grade: Brew.Grade) -> void:
	var learned := _game.learn_words(customer.request.hints)
	if grade == Brew.Grade.PERFECT or grade == Brew.Grade.GOOD:
		if _game.learn_recipe(customer.potion, _brew_ids):
			learned += 1
	if learned > 0:
		var pop := Juice.pop_text(_fx, _codex_button.get_global_rect().get_center() - Vector2(0, 30), "Codex +%d" % learned, CREAM)
		pop.position.x = minf(pop.position.x, _shelf_page_label.get_global_rect().position.x - CODEX_POP_GAP - pop.size.x)
		Juice.squash(_codex_button, 0.3)
		_game.sfx(&"codex_new")


## Slams the grade stamp onto the counter front (overshooting scale, an ink puff,
## a shake for a Misbrew, a hit-stop for Perfect and Misbrew as it lands), holds it
## STAMP_HOLD seconds, then fades it out.
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
	_game.sfx(STAMP_SOUNDS[grade])
	_stamp_tween = _stamp.create_tween()
	_stamp_tween.tween_property(_stamp, "modulate:a", 1.0, 0.08)
	_stamp_tween.parallel().tween_property(_stamp, "scale", Vector2(0.9, 0.9), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_stamp_tween.tween_callback(func() -> void:
		Juice.burst(_stage, STAMP_CENTER, color, 16)
		if grade == Brew.Grade.MISBREW:
			Juice.shake(_stamp, 3.0, 0.3)
		# The impact freezes for a beat (the stamp, coins and sounds already started on the delivery frame).
		Juice.hit_stop(get_tree(), STAMP_HIT_STOPS[grade]))
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
	_game.sfx(&"coin_tick")


func _on_patience_ran_out(who: Customer) -> void:
	if who != customer:
		_storm_off_queue(who)
		return
	stormed_off += 1
	patience_left.append(0.0)
	reputation += Economy.STORMED_OFF_REPUTATION
	var dropped_station := _drop_station()
	_show_station_layer(false)
	_brewing = false
	_update_pot()
	if dropped_station:
		_focus_play()
	print("[Shop] Customer %s (%s) stormed off: reputation %+d" % [_of_total(customer.number), customer.archetype.id, Economy.STORMED_OFF_REPUTATION])
	Juice.shake(_stage, 2.0, 0.3)
	_game.sfx(&"storm_off")
	_say(_reaction_line(customer, "stormed_off", Story.STORMED_OFF), STORMED_HOLD, _send_off.bind(customer))
	_update_hud()
	_check_rush_over()


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
	_game.sfx(&"refuse")
	print("[Shop] Refused customer %s (%s): reputation %+d" % [_of_total(who.number), who.archetype.id, Economy.REFUSED_REPUTATION])
	_say(_reaction_line(who, "refused", Story.REFUSED), REACTION_HOLD, _send_off.bind(who))
	_focus_play()
	_check_rush_over()


## Queued customer `who` ran out of patience: it storms off from the queue (the
## same reputation cost, its line said aside, no stamp) and the ones behind step up.
func _storm_off_queue(who: Customer) -> void:
	stormed_off += 1
	patience_left.append(0.0)
	reputation += Economy.STORMED_OFF_REPUTATION
	queue.erase(who)
	print("[Shop] Customer %s (%s) stormed off from the queue: reputation %+d" % [_of_total(who.number), who.archetype.id, Economy.STORMED_OFF_REPUTATION])
	_say_aside(_reaction_line(who, "stormed_off", Story.STORMED_OFF), who)
	_game.sfx(&"storm_off")
	who.leave()
	_close_up_line()
	_update_hud()
	_check_rush_over()


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


## Ends the day once every customer has come in and gone (a Rush Hour run ends
## only by its reputation, _check_rush_over).
func _check_day_done() -> void:
	if shift.is_rush():
		return
	if _next_customer >= shift.customers.size() and _present == 0:
		get_tree().create_timer(NEXT_CUSTOMER_DELAY, false).timeout.connect(_end_day)


## The day's results as the summary scene reads them (Game.flow_args): day, title,
## customers, served, stormed_off, refused, grades (a count per Brew.Grade), earned (pay
## without tips), tips, reputation (today's change), coins (now) and the skill measures
## patience_left and gestures (Game.finish_day scores them, Difficulty.day_score).
func day_result() -> Dictionary:
	var counts: Array[int] = [0, 0, 0, 0]
	for grade in grades:
		counts[grade] += 1
	return {
		"day": shift.day, "title": shift.title, "customers": shift.customers.size(), "served": served,
		"stormed_off": stormed_off, "refused": refused, "grades": counts, "earned": coins - _starting_coins - tips, "tips": tips,
		"reputation": reputation, "coins": coins, "patience_left": patience_left.duplicate(), "gestures": gestures.duplicate(),
	}


## The run's results as the results scene reads them (Game.finish_rush adds the best):
## score (coins earned), served, stormed_off, refused, grades (a count per Brew.Grade),
## tips, wave (1-based) and assisted (Assist was on at some moment of the run).
func rush_result() -> Dictionary:
	var counts: Array[int] = [0, 0, 0, 0]
	for grade in grades:
		counts[grade] += 1
	return {
		"score": coins, "served": served, "stormed_off": stormed_off, "refused": refused, "grades": counts,
		"tips": tips, "wave": Rush.wave(served) + 1, "assisted": _assisted,
	}


## "Wave N" pops over the counter as a Rush Hour wave starts (it brings new potions).
func _announce_wave() -> void:
	var index := Rush.wave(served)
	var potions := PackedStringArray()
	for potion in Rush.potions_of_wave(index):
		potions.append(potion.id)
	if _wave_banner == null:
		_build_wave_banner()
	if _wave_tween != null:
		_wave_tween.kill()
	(_wave_banner.get_node("List/Name") as Label).text = Rush.WAVE_NAMES[index]
	(_wave_banner.get_node("List/Note") as Label).text = Rush.WAVE_NOTES[index]
	_wave_banner.size = Vector2.ZERO
	_wave_banner.position = (WAVE_BANNER_CENTER - _wave_banner.size / 2.0).round()
	_wave_banner.pivot_offset = _wave_banner.size / 2.0
	_wave_banner.scale = Vector2(1.6, 1.6)
	_wave_banner.modulate.a = 0.0
	_wave_banner.show()
	_wave_tween = _wave_banner.create_tween()
	_wave_tween.tween_property(_wave_banner, "modulate:a", 1.0, 0.1)
	_wave_tween.parallel().tween_property(_wave_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_wave_tween.tween_interval(WAVE_BANNER_HOLD)
	_wave_tween.tween_property(_wave_banner, "modulate:a", 0.0, 0.3)
	_wave_tween.tween_callback(_wave_banner.hide)
	Juice.squash(_served_label, 0.3)
	_game.sfx(&"wave")
	print("[Shop] Rush Hour %s (%s): %s" % [Rush.WAVE_NAMES[index].to_lower(), Rush.WAVE_NOTES[index], ", ".join(potions)])


## The wave banner: the grade stamp's dark plate with a gold border, the wave's name
## (Silkscreen) over what it adds (VT323), centred on WAVE_BANNER_CENTER in the
## workspace, under the counter and clear of the grade stamp; it takes no input.
func _build_wave_banner() -> void:
	_wave_banner = PanelContainer.new()
	_wave_banner.name = "WaveBanner"
	_wave_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _stamp.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
	style.border_color = GOLD
	_wave_banner.add_theme_stylebox_override(&"panel", style)
	var list := VBoxContainer.new()
	list.name = "List"
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_theme_constant_override(&"separation", 0)
	var title := Label.new()
	title.name = "Name"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_color_override(&"font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var note := Label.new()
	note.name = "Note"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)
	list.add_child(note)
	_wave_banner.add_child(list)
	_stage.add_child(_wave_banner)


## Ends a Rush Hour run once its reputation reaches 0: the running station is
## dropped, everyone in line walks out, and RUSH_END_DELAY later Game.finish_rush
## shows the results. Story days never end this way.
func _check_rush_over() -> void:
	if not shift.is_rush() or _day_over or reputation > 0:
		return
	_day_over = true
	_drop_station()
	_show_station_layer(false)
	_brewing = false
	pot.clear()
	_update_pot()
	for visitor: Customer in [customer] + queue:
		if visitor != null and visitor.state != Customer.State.LEAVE and visitor.state != Customer.State.GONE:
			visitor.leave()
	Juice.shake(_stage, 4.0, 0.4)
	_game.sfx(&"rush_over")
	var result := rush_result()
	print("[Shop] Rush Hour over: %s" % result)
	get_tree().create_timer(RUSH_END_DELAY, false).timeout.connect(_game.finish_rush.bind(result))


## Commits the day. Ingredients still in the pot (put in after the last order, or
## left by a customer who stormed off before the brew) go back to stock first.
func _end_day() -> void:
	_day_over = true
	while not pot.is_empty():
		remove_from_pot(0)
	var result := day_result()
	print("[Shop] Day %d done: %s" % [shift.day, result])
	_game.finish_day(result, coins, stock, reputation, story_outcomes)


func _update_hud() -> void:
	if shift == null:
		return
	if _shown_coins > coins:
		_shown_coins = coins
	_coins_label.text = str(_shown_coins)
	if shift.is_rush():
		_served_label.text = "Served %d, wave %d" % [served, Rush.wave(served) + 1]
		_reputation_label.text = str(reputation)
		_reputation_label.accessibility_name = "Reputation %d; the run ends at 0" % reputation
	else:
		_served_label.text = "Day %d, served %d/%d" % [shift.day, served, shift.customers.size()]
	_assist_tag.visible = _game.assist_mode


func _sync_setting_buttons() -> void:
	_assist_tag.visible = _game.assist_mode


## The HUD's music toggle: mutes or unmutes the music (its volume is kept).
## Silent at volume 0 (its slider all the way down), a press brings the default volume back.
func toggle_music() -> void:
	Juice.squash(_music_toggle, 0.2)
	if _game.music_volume == 0:
		_game.set_music_volume(GameState.DEFAULT_MUSIC_VOLUME)
	else:
		_game.set_music_muted(not _game.music_muted)
	_game.sfx(&"tap")


## The HUD's sound toggle: mutes or unmutes the sound effects and voices (volume kept).
## Unmuting plays a sample tap; muting plays nothing. At volume 0 a press brings the
## default volume back.
func toggle_sfx() -> void:
	Juice.squash(_sfx_toggle, 0.2)
	if _game.sfx_volume == 0:
		_game.set_sfx_volume(GameState.DEFAULT_SFX_VOLUME)
	else:
		_game.set_sfx_muted(not _game.sfx_muted)
	if not _game.sfx_silent():
		_game.sfx(&"tap")


## Shows each toggle's state: the icon (slashed when silent) and its accessibility name.
func _sync_sound_toggles() -> void:
	_show_sound_toggle(_music_toggle, "icon_music", "Music", _game.music_silent())
	_show_sound_toggle(_sfx_toggle, "icon_sound", "Sound effects", _game.sfx_silent())


static func _show_sound_toggle(toggle: Button, icon: String, what: String, silent: bool) -> void:
	(toggle.get_node("Icon") as TextureRect).texture = Art.texture("ui", icon + ("_off" if silent else ""))
	toggle.accessibility_name = "%s muted, tap to unmute" % what if silent else "%s on, tap to mute" % what


## Assist changes restart a running station in the new mode (its progress is lost).
## (The settings panel has already set and saved the mode.)
func _on_assist_toggled(on: bool) -> void:
	_assisted = _assisted or on
	print("[Shop] Assist mode %s" % ("on" if on else "off"))
	_sync_setting_buttons()
	if station != null and station.is_running():
		_stop_pour_sound()
		station.assist = on
		station.begin(_station_params(customer.potion.steps[_step]))


## Gentle changes apply to the running station's scoring from now on.
func _on_gentle_toggled(on: bool) -> void:
	print("[Shop] Gentle mode %s" % ("on" if on else "off"))
	_sync_setting_buttons()
	if station != null:
		station.tolerance_scale = _game.tolerance_scale(customer.potion.steps[_step]) * shift.tolerance_scale


func _on_quit_pressed() -> void:
	get_tree().paused = false
	_stop_pour_sound()
	_game.goto(GameState.Flow.TITLE)


## Ends the pour's fill sound wherever it is (playing or held).
func _stop_pour_sound() -> void:
	_pour_sounding = false
	_game.stop_sfx(&"pour_fill")


## Holds (pausing) or continues (resuming) the pour's fill sound, if a pour is filling.
func _hold_pour_sound(held: bool) -> void:
	if not _pour_sounding:
		return
	if held:
		_game.pause_sfx(&"pour_fill")
	else:
		_game.resume_sfx(&"pour_fill")
