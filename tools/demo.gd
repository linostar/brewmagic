extends SceneTree
## Plays a scripted demo of the game for Movie Maker to record (frames and audio):
##   "$GODOT" --path brewmagic --resolution 1080x1920 --fixed-fps 60 --write-movie "$PWD/build/demo.avi" --script "$PWD/tools/demo.gd"
##   ffmpeg -y -i build/demo.avi -c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac -b:a 160k -movflags +faststart build/demo.mp4
## About a minute, all through the real screens with real touches (an iOS-style index):
## splash, title, Continue to day 3's morning, the queue filling, a request typed out,
## an ingredient dragged into the cauldron, every station played by gesture to a Perfect,
## a rushed sloppy brew to a Misbrew, a Rush Hour serve under its wave banner, the
## Guild Master ending and back to the title. Uses the tool save, deleted before and
## after. Prints "demo: OK"; a step that cannot happen is a push_error and exit 1.

const FLOW_FRAMES := 1200
## Game time runs this much faster while customers walk in (a short time-lapse).
const LAPSE_TIME_SCALE := 3.0
const TOUCH_INDEX := 7
## Where a thumb holds to pour and taps the bellows (station-local).
const HOLD_POINT := Vector2(135, 250)
## The bellows are pumped whenever the heat drops below this (inside the band).
const BELLOWS_KEEP := 0.6
## Frames per Mortar stroke (mark to mark).
const SCRUB_FRAMES := 16

var _game: GameState
var _failures: PackedStringArray = []


func _initialize() -> void:
	_game = root.get_node_or_null("Game") as GameState
	if _game == null:
		printerr("demo: FAILED: Game autoload not found")
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	_delete_saves()
	_game.new_game()
	_game.day = 3
	_game.coins = 64
	for item in Content.ingredients_unlocked_by(3):
		_game.stock[item.id] = 6
	_game.save_game()
	# Splash, which goes to the title by itself.
	_game.goto(GameState.Flow.SPLASH)
	if not await _until(func() -> bool: return current_scene is Title and not _game.is_transitioning(), FLOW_FRAMES):
		_fail("the splash did not reach the title")
		await _finish()
		return
	await _seconds(1.6)
	await _tap(current_scene.get_node("Column/OpenShopButton") as Button)
	if not await _until(func() -> bool: return current_scene is Morning and not _game.is_transitioning(), FLOW_FRAMES):
		_fail("Continue did not open the morning")
		await _finish()
		return
	await _seconds(2.4)
	await _tap(current_scene.get_node("Column/OpenShopButton") as Button)
	if not await _until(func() -> bool: return current_scene is Shop and not _game.is_transitioning(), FLOW_FRAMES):
		_fail("the morning did not open the shop")
		await _finish()
		return
	var shop := current_scene as Shop
	if await _perfect_serve(shop) and await _misbrew(shop):
		await _rush_hour()
		await _ending()
	await _finish()


## The queue fills (time-lapse), the first request types out, an ingredient is dragged
## into the cauldron and the rest tapped, then every station is played well: Perfect.
func _perfect_serve(shop: Shop) -> bool:
	if not await _lapse_until(func() -> bool: return shop.customer != null and shop.customer.state == Customer.State.WAIT_ORDER and shop.queue.size() >= 1):
		_fail("no customer waiting with one in line")
		return false
	_refill_patience(shop)
	await _seconds(2.6)
	var recipe := _recipe_between(shop.customer.potion, shop.stock, 0, 0)
	if recipe.is_empty():
		_fail("no exact recipe for %s" % shop.customer.potion.id)
		return false
	var first := shop.shelf_item(recipe[0])
	await _drag(first.get_global_rect().get_center(), shop.get_node("Column/Stage").get_global_transform() * Shop.POT_MOUTH)
	await _seconds(0.3)
	for id: String in recipe.slice(1):
		await _tap(shop.shelf_item(id))
		await _seconds(0.35)
	return await _brew(shop, false, Brew.Grade.PERFECT)


## The next customer gets a rushed brew three or more off the order, stirred sloppily: Misbrew.
func _misbrew(shop: Shop) -> bool:
	await _seconds(1.8)
	await _tap(shop.get_node("Column/Stage/SkipButton") as Button)
	await _tap(shop.get_node("Column/Stage/SkipButton") as Button)
	if not await _lapse_until(func() -> bool: return shop.customer != null and shop.customer.state == Customer.State.WAIT_ORDER):
		_fail("no second customer")
		return false
	_refill_patience(shop)
	await _seconds(2.0)
	var recipe := _recipe_between(shop.customer.potion, shop.stock, 3)
	if recipe.is_empty():
		_fail("no misbrew recipe for %s" % shop.customer.potion.id)
		return false
	for id in recipe:
		await _tap(shop.shelf_item(id))
		await _seconds(0.25)
	return await _brew(shop, true, Brew.Grade.MISBREW)


## Rush Hour: the wave banner, then the serve that starts wave two, played well.
func _rush_hour() -> void:
	_game.goto(GameState.Flow.SHOP, {"rush": 11})
	await _game.transition_finished
	var shop := current_scene as Shop
	if not await _lapse_until(func() -> bool: return shop.customer != null and shop.customer.state == Customer.State.WAIT_ORDER and shop.queue.size() >= 1):
		_fail("no Rush Hour customer")
		return
	_refill_patience(shop)
	await _seconds(1.2)
	shop.served = Rush.WAVE_SIZE - 1
	var every: Dictionary[String, int] = {}
	for item in Content.ingredients():
		every[item.id] = 3
	var recipe := _recipe_between(shop.customer.potion, every, 0, 0)
	if recipe.is_empty():
		_fail("no Rush Hour recipe for %s" % shop.customer.potion.id)
		return
	for id in recipe:
		var item := shop.shelf_item(id)
		if not item.is_visible_in_tree():
			shop.show_shelf_item(item)
			await _seconds(0.25)
		await _tap(item)
		await _seconds(0.3)
	await _brew(shop, false, Brew.Grade.PERFECT)


func _ending() -> void:
	_game.new_game()
	_game.day = Content.days().size() + 1
	_game.reputation = Story.GUILD_MASTER_REPUTATION
	for flag in Story.final_flags():
		_game.flags[flag] = Story.GREAT
	_game.goto(GameState.Flow.ENDING)
	await _game.transition_finished
	await _seconds(3.6)
	_game.goto(GameState.Flow.TITLE)
	await _game.transition_finished
	await _seconds(2.8)


## Taps Brew and plays each station of the order; `sloppy` rushes the Stir and lets go
## of the pour early. Waits for the delivery and holds on it.
func _brew(shop: Shop, sloppy: bool, expected: Brew.Grade) -> bool:
	var served := shop.served
	var steps := shop.customer.potion.steps
	await _tap(shop.brew_button())
	for step in steps:
		if not await _until(func() -> bool: return shop.station != null and shop.station.is_running(), FLOW_FRAMES):
			_fail("the %s station did not start" % step)
			return false
		await _seconds(0.4)
		var station := shop.station
		if station is Stir:
			await _stir(station as Stir, sloppy)
		elif station is Pour:
			await _pour(station as Pour, sloppy)
		elif station is Mortar:
			await _scrub(station as Mortar)
		elif station is Bellows:
			await _pump(station as Bellows)
		if station != null and is_instance_valid(station) and station.is_running():
			_fail("the %s station did not finish from its gesture" % step)
			return false
	if not await _until(func() -> bool: return shop.served == served + 1, FLOW_FRAMES):
		_fail("the customer was not served")
		return false
	if shop.grades.back() != expected:
		_fail("served %s, wanted %s" % [Brew.Grade.keys()[shop.grades.back()], Brew.Grade.keys()[expected]])
		return false
	await _seconds(2.6)
	return true


## Circles at the station's tempo (a sloppy brew goes twice as fast, wobbling) until it finishes.
func _stir(stir: Stir, sloppy: bool) -> void:
	var rps := stir._tempo * (2.0 if sloppy else 1.0)
	var angle := 0.0
	await _station_touch(stir, Stir.CENTRE + Vector2(Stir.RING_RADIUS, 0), true)
	for i in FLOW_FRAMES:
		if not stir.is_running():
			break
		angle += TAU * rps / 60.0
		var radius := Stir.RING_RADIUS + (14.0 * sin(angle * 3.0) if sloppy else 0.0)
		await _station_drag(stir, Stir.CENTRE + Vector2.from_angle(angle) * radius)
	await _station_touch(stir, Stir.CENTRE + Vector2.from_angle(angle) * Stir.RING_RADIUS, false)


## Holds until the bottle reaches the line (a sloppy pour lets go well short of it).
func _pour(pour: Pour, sloppy: bool) -> void:
	var target := pour._line - (0.25 if sloppy else 0.005)
	await _station_touch(pour, HOLD_POINT, true)
	for i in FLOW_FRAMES:
		if pour.fill >= target or not pour.is_running():
			break
		await process_frame
	await _station_touch(pour, HOLD_POINT, false)


## Scrubs mark to mark on the rail for Mortar.STROKES strokes, then lifts.
func _scrub(mortar: Mortar) -> void:
	var left := Vector2(Mortar.CENTRE.x - Mortar.MARK_X, Mortar.RAIL_Y)
	var right := Vector2(Mortar.CENTRE.x + Mortar.MARK_X, Mortar.RAIL_Y)
	await _station_touch(mortar, left, true)
	var from := left
	for stroke in Mortar.STROKES:
		var to := right if stroke % 2 == 0 else left
		for i in range(1, SCRUB_FRAMES + 1):
			await _station_drag(mortar, from.lerp(to, i / float(SCRUB_FRAMES)))
		from = to
		if not mortar.is_running():
			break
	await _station_touch(mortar, from, false)


## Taps whenever the heat drops below BELLOWS_KEEP until the Bellows finish.
func _pump(bellows: Bellows) -> void:
	for i in FLOW_FRAMES:
		if not bellows.is_running():
			return
		if bellows.heat < BELLOWS_KEEP:
			await _station_touch(bellows, HOLD_POINT, true)
			await _station_touch(bellows, HOLD_POINT, false)
		else:
			await process_frame


## Runs game time LAPSE_TIME_SCALE faster until `condition` holds.
func _lapse_until(condition: Callable) -> bool:
	Engine.time_scale = LAPSE_TIME_SCALE
	var met := await _until(condition, FLOW_FRAMES)
	Engine.time_scale = 1.0
	return met


func _finish() -> void:
	Engine.time_scale = 1.0
	_game.stop_audio()
	await _frames(3)
	_delete_saves()
	if _failures.is_empty():
		print("demo: OK")
		quit(0)
		return
	for failure in _failures:
		printerr("demo: FAIL " + failure)
	quit(1)


func _fail(problem: String) -> void:
	push_error("demo: " + problem)
	_failures.append(problem)


## A touch press or release at station-local `at`.
func _station_touch(station: Station, at: Vector2, pressed: bool) -> void:
	_send_touch(station.get_global_transform() * at, pressed)
	await process_frame


func _station_drag(station: Station, at: Vector2) -> void:
	_send_drag(station.get_global_transform() * at)
	await process_frame


## A tap (press and release) at the centre of `control`.
func _tap(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	_send_touch(at, true)
	await process_frame
	_send_touch(at, false)
	await process_frame


## A touch dragged from `from` to `to` (canvas points) over 20 frames.
func _drag(from: Vector2, to: Vector2) -> void:
	_send_touch(from, true)
	await process_frame
	for i in range(1, 21):
		_send_drag(from.lerp(to, i / 20.0))
		await process_frame
	_send_touch(to, false)
	await process_frame


func _send_touch(canvas_point: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = TOUCH_INDEX
	touch.position = root.get_final_transform() * canvas_point
	touch.pressed = pressed
	Input.parse_input_event(touch)


func _send_drag(canvas_point: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = TOUCH_INDEX
	drag.position = root.get_final_transform() * canvas_point
	Input.parse_input_event(drag)


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


func _refill_patience(shop: Shop) -> void:
	for visitor: Customer in [shop.customer] + shop.queue:
		if visitor != null:
			visitor.patience_left = visitor.patience_total


func _until(condition: Callable, frames: int) -> bool:
	for i in frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()


func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * 60.0))


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _delete_saves() -> void:
	for path: String in [_game.save_path, _game.backup_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
