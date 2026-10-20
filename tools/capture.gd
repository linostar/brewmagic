extends SceneTree
## Renders the itch page's cover and screenshots from the game itself into submission/.
## Needs a real window (the headless renderer draws nothing):
##   "$GODOT" --path brewmagic --audio-driver Dummy --resolution 1080x1920 --fixed-fps 60 --script "$PWD/tools/capture.gd"
## Each screenshot stages a moment through the real scenes, as test_gameplay.gd does
## (goto with flow args, real touches, a station ended at full quality like a flawless
## player), and is saved at 1080x1920 (4x the 270x480 base). The cover is composed at
## runtime from the game's art in a 630x500 SubViewport, so the export ships nothing new.
## Uses the tool save (GameState.TOOL_SAVE_PATH), deleted before and after. Prints
## "capture: OK" when every file is written; a moment that cannot be staged is a
## push_error and exit 1.

const SHOT_SIZE := Vector2i(1080, 1920)
const COVER_SIZE := Vector2i(630, 500)
## Frames the capture waits for one step of the flow (a walk, a station, a delivery).
const FLOW_FRAMES := 1200
## Game time runs this much faster while waiting for customers to walk in and queue.
const WAIT_TIME_SCALE := 4.0
const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const CAULDRON_HERO_SCENE := preload("res://scenes/cauldron_hero.tscn")
## The cover's ground: the morning screen's plum.
const COVER_GROUND := Color(0.29, 0.204, 0.251)

var _game: GameState
var _out_dir := ""
var _failures: PackedStringArray = []


func _initialize() -> void:
	_game = root.get_node_or_null("Game") as GameState
	if _game == null:
		printerr("capture: FAILED: Game autoload not found")
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	_out_dir = ProjectSettings.globalize_path("res://").path_join("../submission").simplify_path()
	var made := DirAccess.make_dir_recursive_absolute(_out_dir)
	if made != OK:
		_fail("cannot create %s: %s" % [_out_dir, error_string(made)])
		_finish()
		return
	_delete_saves()
	DisplayServer.window_set_size(SHOT_SIZE)
	await _frames(10)
	if root.size != SHOT_SIZE:
		_fail("window is %s, not %s (the screen may be too small)" % [root.size, SHOT_SIZE])
		_finish()
		return
	await _shot_title()
	var shop := await _open_story_shop()
	if shop != null:
		if await _shot_request(shop) and await _shot_stir_and_perfect(shop):
			await _shot_misbrew(shop)
	await _shot_market()
	await _shot_rush_hour()
	await _shot_ending()
	await _cover()
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	_delete_saves()
	if _failures.is_empty():
		print("capture: OK (%s)" % _out_dir)
		quit(0)
		return
	for failure in _failures:
		printerr("capture: FAIL " + failure)
	quit(1)


func _fail(problem: String) -> void:
	push_error("capture: " + problem)
	_failures.append(problem)


## Saves the window as submission/<file_name>.png (exactly SHOT_SIZE).
func _save_window(file_name: String) -> void:
	_save(root.get_texture().get_image(), SHOT_SIZE, file_name)


func _save(image: Image, expected: Vector2i, file_name: String) -> void:
	if image == null or image.get_size() != expected:
		_fail("%s: rendered %s, expected %s" % [file_name, image.get_size() if image != null else Vector2i.ZERO, expected])
		return
	var path := _out_dir.path_join(file_name + ".png")
	var saved := image.save_png(path)
	if saved != OK:
		_fail("%s: cannot write %s: %s" % [file_name, path, error_string(saved)])
		return
	print("capture: wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])


## 1: the title with a saved story (Continue, New game) and Rush Hour unlocked with a best.
func _shot_title() -> void:
	_game.new_game()
	_game.day = 3
	_game.rush_hour_unlocked = true
	_game.rush_best = 412
	_game.rush_best_assisted = false
	_game.save_game()
	await _goto(GameState.Flow.TITLE)
	await _frames(90)
	_save_window("1-title")


## A story shop on day 3 (the Guild arrives) with a full shelf of the day's ingredients.
func _open_story_shop() -> Shop:
	_game.new_game()
	_game.day = 3
	_game.coins = 64
	for item in Content.ingredients_unlocked_by(3):
		_game.stock[item.id] = 6
	var shop := await _goto(GameState.Flow.SHOP, {"day": 3}) as Shop
	if shop == null:
		_fail("the day-3 shop did not open")
	return shop


## 2: a customer at the counter saying a request with its hint words, two more in line.
func _shot_request(shop: Shop) -> bool:
	Engine.time_scale = WAIT_TIME_SCALE
	var lined_up := await _until(func() -> bool: return shop.customer != null and shop.customer.state == Customer.State.WAIT_ORDER and shop.queue.size() >= 2 and shop.queue.all(func(visitor: Customer) -> bool: return visitor.state == Customer.State.QUEUED), FLOW_FRAMES)
	Engine.time_scale = 1.0
	if not lined_up:
		_fail("2-request: no customer waiting with two in line")
		return false
	_refill_patience(shop)
	await _frames(150)
	_save_window("2-request")
	return true


## 3: the Stir station with its ghost ladle; then the brew finishes at full quality and
## 4: the Perfect stamp lands with the coins flying.
func _shot_stir_and_perfect(shop: Shop) -> bool:
	var potion := shop.customer.potion
	if not potion.steps.has("stir"):
		_fail("3-stir: the waiting customer's %s has no Stir step" % potion.id)
		return false
	if not await _fill_pot(shop, _recipe_between(potion, shop.stock, 0, 0)):
		_fail("3-stir: no exact recipe for %s in %s" % [potion.id, shop.stock])
		return false
	var served := shop.served
	await _tap(shop.brew_button())
	for step in potion.steps:
		if not await _until(func() -> bool: return shop.station != null and shop.station.is_running(), FLOW_FRAMES):
			_fail("3-stir: the %s station did not start" % step)
			return false
		if step == "stir":
			await _frames(45)
			_save_window("3-stir")
		shop.station._finish(1.0)
		await _frames(2)
	if not await _until(func() -> bool: return shop.served == served + 1, FLOW_FRAMES):
		_fail("4-perfect: the customer was not served")
		return false
	await _frames(24)
	await _complete_line(shop)
	if shop.grades.back() != Brew.Grade.PERFECT:
		_fail("4-perfect: served %s" % Brew.Grade.keys()[shop.grades.back()])
		return false
	_save_window("4-perfect")
	return true


## 5: a Misbrew (a brew three or more off the order) with its effect on the customer.
func _shot_misbrew(shop: Shop) -> void:
	await _skip_lines(shop)
	Engine.time_scale = WAIT_TIME_SCALE
	var waiting := await _until(func() -> bool: return shop.customer != null and shop.customer.state == Customer.State.WAIT_ORDER, FLOW_FRAMES)
	Engine.time_scale = 1.0
	if not waiting:
		_fail("5-misbrew: no next customer")
		return
	_refill_patience(shop)
	if not await _fill_pot(shop, _recipe_between(shop.customer.potion, shop.stock, 3)):
		_fail("5-misbrew: no recipe three or more off %s" % shop.customer.potion.id)
		return
	var served := shop.served
	await _tap(shop.brew_button())
	for step in shop.customer.potion.steps:
		if not await _until(func() -> bool: return shop.station != null and shop.station.is_running(), FLOW_FRAMES):
			_fail("5-misbrew: the %s station did not start" % step)
			return
		shop.station._finish(1.0)
		await _frames(2)
	if not await _until(func() -> bool: return shop.served == served + 1, FLOW_FRAMES):
		_fail("5-misbrew: the customer was not served")
		return
	await _frames(40)
	await _complete_line(shop)
	if shop.grades.back() != Brew.Grade.MISBREW:
		_fail("5-misbrew: served %s" % Brew.Grade.keys()[shop.grades.back()])
		return
	_save_window("5-misbrew")


## 6: the market the evening before day 4 (cinderroot and the Bellows arrive).
func _shot_market() -> void:
	_game.new_game()
	_game.day = 4
	_game.at_market = true
	_game.coins = 96
	for item in Content.ingredients_unlocked_by(3):
		_game.stock[item.id] = 2
	await _goto(GameState.Flow.MARKET)
	await _frames(40)
	_save_window("6-market")


## 7: Rush Hour: the serve that starts wave two (its banner) with a Perfect stamp.
func _shot_rush_hour() -> void:
	_game.new_game()
	_game.rush_hour_unlocked = true
	var shop := await _goto(GameState.Flow.SHOP, {"rush": 7}) as Shop
	if shop == null:
		_fail("7-rush-hour: the Rush Hour shop did not open")
		return
	Engine.time_scale = WAIT_TIME_SCALE
	var waiting := await _until(func() -> bool: return shop.customer != null and shop.customer.state == Customer.State.WAIT_ORDER, FLOW_FRAMES)
	Engine.time_scale = 1.0
	if not waiting:
		_fail("7-rush-hour: no customer waiting")
		return
	await _frames(150)
	shop.served = Rush.WAVE_SIZE - 1
	var every: Dictionary[String, int] = {}
	for item in Content.ingredients():
		every[item.id] = 3
	if not await _fill_pot(shop, _recipe_between(shop.customer.potion, every, 0, 0)):
		_fail("7-rush-hour: no exact recipe for %s" % shop.customer.potion.id)
		return
	await _tap(shop.brew_button())
	for step in shop.customer.potion.steps:
		if not await _until(func() -> bool: return shop.station != null and shop.station.is_running(), FLOW_FRAMES):
			_fail("7-rush-hour: the %s station did not start" % step)
			return
		shop.station._finish(1.0)
		await _frames(2)
	if not await _until(func() -> bool: return shop.served == Rush.WAVE_SIZE, FLOW_FRAMES):
		_fail("7-rush-hour: the customer was not served")
		return
	# The coins have landed on the score; the banner holds Shop.WAVE_BANNER_HOLD.
	await _frames(55)
	await _complete_line(shop)
	if shop.get_node_or_null("Column/Stage/WaveBanner") == null:
		_fail("7-rush-hour: no wave banner")
		return
	_save_window("7-rush-hour")


## 8: the Guild Master ending's first page.
func _shot_ending() -> void:
	_game.new_game()
	_game.day = Content.days().size() + 1
	_game.reputation = Story.GUILD_MASTER_REPUTATION
	for flag in Story.final_flags():
		_game.flags[flag] = Story.GREAT
	var screen := await _goto(GameState.Flow.ENDING) as EndingScreen
	if screen == null:
		_fail("8-ending: the ending screen did not open")
		return
	await _frames(60)
	_save_window("8-ending")


## The cover: the shop under its ceiling at 2x with two visitors behind the counter, the
## logo at 3x over the beams and the title's bubbling cauldron in front on the left.
func _cover() -> void:
	var viewport := SubViewport.new()
	viewport.size = COVER_SIZE
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var ground := ColorRect.new()
	ground.color = COVER_GROUND
	ground.size = COVER_SIZE
	viewport.add_child(ground)
	var shop := Node2D.new()
	shop.scale = Vector2(2, 2)
	shop.position = Vector2(floorf((COVER_SIZE.x - 540) / 2.0), COVER_SIZE.y - 384)
	viewport.add_child(shop)
	_cover_sprite(shop, "shop", "shop_ceiling", Vector2(0, -112))
	_cover_sprite(shop, "shop", "shop_backdrop", Vector2.ZERO)
	var visitors: Array[Array] = [["stranger", Customer.COUNTER_X], ["gossip_granny", Customer.COUNTER_X + 48.0]]
	for visit in visitors:
		var who := Content.archetype(visit[0])
		if who == null:
			_fail("cover: no archetype %s" % visit[0])
			continue
		var figure := CUSTOMER_SCENE.instantiate() as Customer
		figure.setup(who, null, null, 1.0, who.fixed_look if who.is_story() else Look.from_seed(who.id.hash()))
		shop.add_child(figure)
		figure.position = Vector2(visit[1], Customer.CANVAS_Y)
		# A customer is transparent until it walks in (as on the ending's pages).
		figure.modulate.a = 1.0
	_cover_sprite(shop, "shop", "shop_counter", Vector2(0, 136))
	var hero := CAULDRON_HERO_SCENE.instantiate() as Control
	viewport.add_child(hero)
	hero.scale = Vector2(2, 2)
	hero.position = Vector2(12, COVER_SIZE.y - 172 - 4)
	var logo := TextureRect.new()
	logo.texture = Art.texture("title", "logo")
	logo.scale = Vector2(3, 3)
	logo.position = Vector2(floorf((COVER_SIZE.x - logo.texture.get_width() * 3) / 2.0), 14)
	viewport.add_child(logo)
	await _frames(90)
	_save(viewport.get_texture().get_image(), COVER_SIZE, "cover")
	viewport.queue_free()


func _cover_sprite(parent: Node, atlas: String, sprite: String, at: Vector2) -> void:
	var rect := TextureRect.new()
	rect.texture = Art.texture(atlas, sprite)
	if rect.texture == null:
		_fail("cover: no sprite %s/%s" % [atlas, sprite])
		return
	rect.position = at
	parent.add_child(rect)


func _goto(state: GameState.Flow, args: Dictionary = {}) -> Node:
	_game.goto(state, args)
	await _game.transition_finished
	return current_scene


## Taps each ingredient of `recipe` into the pot and waits until Brew is enabled.
func _fill_pot(shop: Shop, recipe: Array[String]) -> bool:
	if recipe.is_empty():
		return false
	for id in recipe:
		var item := shop.shelf_item(id)
		shop.show_shelf_item(item)
		await _tap(item)
	return await _until(func() -> bool: return not shop.brew_button().disabled, FLOW_FRAMES)


## Ingredient ids from `stock` (2, else 3) whose brew is `low`..`high` away from `potion`.
func _recipe_between(potion: PotionType, stock: Dictionary[String, int], low: int, high := 99) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(stock.keys())
	for a in ids:
		for b in ids:
			var pair: Array[String] = [a, b]
			if _affordable(pair, stock) and _within(pair, potion, low, high):
				return pair
	for a in ids:
		for b in ids:
			for c in ids:
				var triple: Array[String] = [a, b, c]
				if _affordable(triple, stock) and _within(triple, potion, low, high):
					return triple
	return [] as Array[String]


func _affordable(recipe: Array[String], stock: Dictionary[String, int]) -> bool:
	return recipe.all(func(id: String) -> bool: return recipe.count(id) <= stock[id])


func _within(recipe: Array[String], potion: PotionType, low: int, high: int) -> bool:
	var mix := Vector4i.ZERO
	for id in recipe:
		mix += Content.ingredient(id).essence
	var distance := Brew.distance(mix, potion.target)
	return distance >= low and distance <= high


## Completes the line the speech bubble is typing (as a tap on the workspace would) and
## lets it draw.
func _complete_line(shop: Shop) -> void:
	(shop.get_node("Column/Stage/Bubble") as SpeechBubble).skip()
	await _frames(2)


## Fills the patience of everyone in line, so the slow capture makes no one storm off.
func _refill_patience(shop: Shop) -> void:
	for visitor: Customer in [shop.customer] + shop.queue:
		if visitor != null:
			visitor.patience_left = visitor.patience_total


## Taps the workspace until the counter customer leaves (skipping the reaction lines).
func _skip_lines(shop: Shop) -> void:
	var skip := shop.get_node("Column/Stage/SkipButton") as Button
	var leaving := shop.customer
	for i in 12:
		if leaving == null or leaving.state == Customer.State.LEAVE or leaving.state == Customer.State.GONE:
			return
		await _tap(skip)
		await _frames(10)


## A real touch (press and release) at the centre of `control`, with an iOS-style index.
func _tap(control: Control) -> void:
	var at := root.get_final_transform() * control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 7
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame


func _until(condition: Callable, frames: int) -> bool:
	for i in frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _delete_saves() -> void:
	for path: String in [_game.save_path, _game.backup_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
