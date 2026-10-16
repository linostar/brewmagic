extends SceneTree
## Headless gameplay tests. Run with --fixed-fps 60 so one frame = one physics tick:
##   "$GODOT" --headless --path brewmagic --fixed-fps 60 --script "$PWD/tools/test_gameplay.gd"
## Prints "test_gameplay: OK" when every test passes; exits 1 otherwise.
## To add a test: write a `_test_*` func (it may await) that reports through _check(),
## and append it to the list in _tests(). Tests run in that order on one SceneTree, so
## each one restores whatever it changes (window size, Game.scene_paths, quiet_errors).

const TITLE_SCENE := preload("res://scenes/title.tscn")
const TITLE_PATH := "res://scenes/title.tscn"
const STIR_SCENE := preload("res://scenes/stations/stir.tscn")
const POUR_SCENE := preload("res://scenes/stations/pour.tscn")
const POTION_COLOR := Color("#f07c2c")
## One synthetic input frame for the station streams.
const FRAME := 1.0 / 60.0
## A station-local point low in the station, where a thumb holds to pour.
const POUR_HOLD_POINT := Vector2(135, 250)
const BASE_WINDOW := Vector2i(270, 480)
## Window sizes in pixels for the aspect ratios the game must fit: 9:16, 9:19.5 and 16:9.
const PHONE_9_16 := Vector2i(1080, 1920)
const PHONE_9_19_5 := Vector2i(1080, 2340)
const DESKTOP_16_9 := Vector2i(1920, 1080)
const MIN_TARGET := 32.0
const THUMB_ZONE_TOP := 0.4
## Real-time limit for the whole run; a test stuck on an await fails instead of hanging.
const WATCHDOG_MSEC := 60000

var _failures: Array[String] = []
var _passed := 0
var _deadline_msec := 0
## The "Game" autoload; this script compiles before autoloads exist, so it is fetched at start.
var _game: GameState


func _initialize() -> void:
	_deadline_msec = Time.get_ticks_msec() + WATCHDOG_MSEC
	_game = root.get_node_or_null("Game") as GameState
	if _game == null:
		printerr("test_gameplay: FAILED: Game autoload not found")
		quit(1)
		return
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > _deadline_msec:
		printerr("test_gameplay: FAILED watchdog: tests did not finish within %d ms" % WATCHDOG_MSEC)
		quit(1)
	return false


func _tests() -> Array[Callable]:
	return [
		_test_goto_logs_transition,
		_test_goto_missing_scene_shows_error,
		_test_goto_ignored_during_transition,
		_test_screen_fit_column_9_16,
		_test_screen_fit_column_9_19_5,
		_test_screen_fit_column_16_9,
		_test_safe_area_notch,
		_test_title_button_size_and_zone,
		_test_title_button_tap_goes_to_shop,
		_test_brew_combine_and_distance,
		_test_brew_match_tiers,
		_test_brew_misbrew_essence,
		_test_brew_gesture_quality,
		_test_brew_final_grade,
		_test_stir_perfect,
		_test_stir_sloppy,
		_test_stir_idle_and_wiggle,
		_test_stir_tolerance_scale,
		_test_pour_perfect,
		_test_pour_sloppy_and_overflow,
		_test_pour_idle,
		_test_pour_tolerance_scale,
		_test_stations_assist_tap,
		_test_stations_assist_ui_accept,
	]


func _run() -> void:
	root.size = BASE_WINDOW
	await process_frame
	for test in _tests():
		await test.call()
	for failure in _failures:
		printerr("test_gameplay: FAIL " + failure)
	if _failures.is_empty():
		print("test_gameplay: OK (%d checks)" % _passed)
		quit(0)
	else:
		printerr("test_gameplay: FAILED %d of %d checks" % [_failures.size(), _failures.size() + _passed])
		quit(1)


func _test_goto_logs_transition() -> void:
	var logged := _game.transition_log.size()
	_game.goto(GameState.Flow.TITLE, {"from": "test"})
	await _game.transition_finished
	_check(_game.transition_log.size() == logged + 1, "goto logs transition", "log grew by %d" % (_game.transition_log.size() - logged))
	_check(_game.transition_log.back().begins_with("TITLE -> TITLE (%s)" % TITLE_PATH), "goto log entry", str(_game.transition_log.back()))
	_check(current_scene != null and current_scene.scene_file_path == TITLE_PATH, "goto swaps scene", str(current_scene))
	_check(_game.state == GameState.Flow.TITLE and _game.flow_args.get("from") == "test", "goto sets state and args", "%s %s" % [_game.state, _game.flow_args])
	_check(is_zero_approx((_game.get_node("Fade/Curtain") as ColorRect).color.a), "goto fades back in", "curtain still visible")


func _test_goto_missing_scene_shows_error() -> void:
	var real_path: String = _game.scene_paths[GameState.Flow.SHOP]
	_game.scene_paths[GameState.Flow.SHOP] = "res://scenes/does_not_exist.tscn"
	_game.quiet_errors = true
	var errors := _game.reported_errors.size()
	var logged := _game.transition_log.size()
	var scene_before := current_scene
	_game.goto(GameState.Flow.SHOP)
	await process_frame
	_game.quiet_errors = false
	_game.scene_paths[GameState.Flow.SHOP] = real_path
	var error_label := _game.get_node("Fade/ErrorLabel") as Label
	_check(_game.reported_errors.size() == errors + 1, "missing scene reports error", "%d new errors" % (_game.reported_errors.size() - errors))
	_check(error_label.visible and "does_not_exist" in error_label.text, "missing scene shows error label", error_label.text)
	_check(_game.state == GameState.Flow.TITLE and current_scene == scene_before, "missing scene keeps current scene", "state %s" % _game.state)
	_check(_game.transition_log.size() == logged and not _game.is_transitioning(), "missing scene is not a transition", "log %d" % (_game.transition_log.size() - logged))
	error_label.hide()


func _test_goto_ignored_during_transition() -> void:
	var logged := _game.transition_log.size()
	_game.goto(GameState.Flow.TITLE)
	_game.goto(GameState.Flow.TITLE)
	await _game.transition_finished
	_check(_game.transition_log.size() == logged + 1, "goto during transition is ignored", "log grew by %d" % (_game.transition_log.size() - logged))


func _test_screen_fit_column_9_16() -> void:
	await _check_column(PHONE_9_16, Vector2(270, 480), "9:16")


func _test_screen_fit_column_9_19_5() -> void:
	await _check_column(PHONE_9_19_5, Vector2(270, 585), "9:19.5")


func _test_screen_fit_column_16_9() -> void:
	await _check_column(DESKTOP_16_9, Vector2(853, 480), "16:9")


## A notch inset of 132 px top and 132 px bottom at 4x scale is 33 base units each way.
func _test_safe_area_notch() -> void:
	var visible := Rect2(0, 0, 270, 585)
	var safe := GameState.safe_rect_in(visible, Rect2i(0, 132, 1080, 2076), Vector2i.ZERO, Transform2D.IDENTITY.scaled(Vector2(4, 4)))
	_check(safe.is_equal_approx(Rect2(0, 33, 270, 519)), "safe area converts to base units", str(safe))
	var column := GameState.column_in(safe)
	_check(column.is_equal_approx(Rect2(0, 33, 270, 519)), "column spans the safe area", str(column))
	var empty := GameState.safe_rect_in(visible, Rect2i(), Vector2i.ZERO, Transform2D.IDENTITY)
	_check(empty == visible, "empty safe area means the visible rect", str(empty))


func _test_title_button_size_and_zone() -> void:
	for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
		root.size = window
		var title := TITLE_SCENE.instantiate() as Title
		root.add_child(title)
		await process_frame
		await process_frame
		var button := title.get_node("Column/OpenShopButton") as Button
		var rect := button.get_global_rect()
		var label := "title button at %s" % window
		_check(rect.size.x >= MIN_TARGET and rect.size.y >= MIN_TARGET, label + " size", str(rect.size))
		_check(rect.position.y >= _game.visible_rect().size.y * THUMB_ZONE_TOP, label + " in thumb zone", str(rect))
		_check(_game.safe_rect().encloses(rect), label + " inside safe area", "%s not in %s" % [rect, _game.safe_rect()])
		_check(button.accessibility_name != "" and button.focus_mode == Control.FOCUS_ALL, label + " accessible", button.accessibility_name)
		_check(button.get_theme_stylebox("focus") is StyleBoxFlat, label + " focus style", str(button.get_theme_stylebox("focus")))
		_check(not (title.get_node("Column/ContentErrorBanner") as Label).visible, label + " banner hidden", "content error banner visible")
		title.free()
	root.size = BASE_WINDOW
	await process_frame


## A real touch (as the web build delivers it) on the title button runs goto(SHOP).
## SHOP points at the title scene here so the test does not depend on the shop scene.
func _test_title_button_tap_goes_to_shop() -> void:
	var real_path: String = _game.scene_paths[GameState.Flow.SHOP]
	_game.scene_paths[GameState.Flow.SHOP] = TITLE_PATH
	var title := current_scene as Title
	var button := title.get_node("Column/OpenShopButton") as Button
	var screen_point := root.get_final_transform() * button.get_global_rect().get_center()
	var logged := _game.transition_log.size()
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = screen_point
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame
	if _game.is_transitioning():
		await _game.transition_finished
	_game.scene_paths[GameState.Flow.SHOP] = real_path
	_check(_game.transition_log.size() == logged + 1 and _game.transition_log.back().begins_with("TITLE -> SHOP"), "title tap goes to shop", str(_game.transition_log.slice(logged)))
	_check(_game.state == GameState.Flow.SHOP, "title tap sets SHOP state", str(_game.state))
	_game.goto(GameState.Flow.TITLE)
	await _game.transition_finished


func _test_brew_combine_and_distance() -> void:
	var pepper := Vector4i(2, 0, 0, 0)
	var sunpetal := Vector4i(0, 0, 2, 0)
	var moonmoss := Vector4i(0, 1, 0, 2)
	var pair := Brew.combine([pepper, sunpetal] as Array[Vector4i])
	_check(pair == Vector4i(2, 0, 2, 0), "brew combines two", str(pair))
	var triple := Brew.combine([pepper, pepper, moonmoss] as Array[Vector4i])
	_check(triple == Vector4i(4, 1, 0, 2), "brew combines three with a repeat", str(triple))
	_check(Brew.distance(Vector4i(2, 0, 2, 0), Vector4i(2, 0, 2, 0)) == 0, "brew distance exact", "not 0")
	var over := Brew.distance(Vector4i(4, 1, 0, 2), Vector4i(2, 1, 0, 2))
	_check(over == 2, "brew distance overshoot", str(over))
	var mixed := Brew.distance(Vector4i(0, 3, 1, 0), Vector4i(1, 1, 2, 3))
	_check(mixed == 7, "brew distance is L1 over both signs", str(mixed))


func _test_brew_match_tiers() -> void:
	var expected: Array[Brew.Grade] = [Brew.Grade.PERFECT, Brew.Grade.GOOD, Brew.Grade.MEH, Brew.Grade.MISBREW, Brew.Grade.MISBREW]
	for match_distance in expected.size():
		var tier := Brew.match_tier(match_distance)
		_check(tier == expected[match_distance], "brew tier at distance %d" % match_distance, Brew.Grade.keys()[tier])


func _test_brew_misbrew_essence() -> void:
	var target := Vector4i(2, 1, 0, 2)
	# [brew, expected essence index, name]
	var cases: Array[Array] = [
		[Vector4i(2, 1, 3, 2), 2, "single overshoot"],
		[Vector4i(3, 4, 0, 0), 1, "largest overshoot wins"],
		[Vector4i(0, 3, 2, 0), 1, "tie goes to the lowest index"],
		[Vector4i(0, 1, 2, 4), 2, "tie bloom before gloom"],
		[Vector4i(4, 3, 2, 4), 0, "four-way tie goes to ember"],
	]
	for entry in cases:
		var essence := Brew.misbrew_essence(entry[0], target)
		_check(essence == entry[1], "misbrew " + str(entry[2]), str(essence))


func _test_brew_gesture_quality() -> void:
	var quality := Brew.gesture_quality([1.0, 0.5] as Array[float])
	_check(is_equal_approx(quality, 0.75), "gesture quality is the mean", str(quality))
	quality = Brew.gesture_quality([0.6] as Array[float])
	_check(is_equal_approx(quality, 0.6), "gesture quality of one station", str(quality))


func _test_brew_final_grade() -> void:
	# [match tier, gesture quality, expected grade]
	var cases: Array[Array] = [
		[Brew.Grade.PERFECT, 1.0, Brew.Grade.PERFECT],
		[Brew.Grade.PERFECT, Brew.PERFECT_QUALITY, Brew.Grade.PERFECT],
		[Brew.Grade.PERFECT, Brew.PERFECT_QUALITY - 0.01, Brew.Grade.GOOD],
		[Brew.Grade.PERFECT, Station.ASSIST_QUALITY, Brew.Grade.GOOD],
		[Brew.Grade.PERFECT, 0.0, Brew.Grade.GOOD],
		[Brew.Grade.GOOD, 1.0, Brew.Grade.GOOD],
		[Brew.Grade.GOOD, Brew.GOOD_QUALITY, Brew.Grade.GOOD],
		[Brew.Grade.GOOD, Brew.GOOD_QUALITY - 0.01, Brew.Grade.MEH],
		[Brew.Grade.GOOD, 0.0, Brew.Grade.MEH],
		[Brew.Grade.MEH, 1.0, Brew.Grade.MEH],
		[Brew.Grade.MEH, 0.0, Brew.Grade.MEH],
		[Brew.Grade.MISBREW, 1.0, Brew.Grade.MISBREW],
		[Brew.Grade.MISBREW, 0.0, Brew.Grade.MISBREW],
	]
	for entry in cases:
		var tier: Brew.Grade = entry[0]
		var quality: float = entry[1]
		var grade := Brew.final_grade(tier, quality)
		_check(grade == entry[2], "final grade %s at quality %.2f" % [Brew.Grade.keys()[tier], quality], Brew.Grade.keys()[grade])


## A clean circle on the guide ring at exactly the asked tempo scores Perfect.
func _test_stir_perfect() -> void:
	var stir := _add_station(STIR_SCENE) as Stir
	var results := _collect_finished(stir)
	var cues: Array[StringName] = []
	stir.feedback.connect(func(kind: StringName) -> void: cues.append(kind))
	stir.begin({"color": POTION_COLOR, "tempo": 0.8})
	_stir_circles(stir, 0.8, Stir.ROTATIONS, 0.0)
	_check(results.size() == 1, "stir perfect finishes once", str(results))
	_check(not results.is_empty() and results[0] >= Station.PERFECT_QUALITY, "stir perfect quality", str(results))
	_check(cues.count(&"stir_rotation") == Stir.ROTATIONS and cues.back() == &"station_success", "stir feedback every rotation", str(cues))
	_check(not stir.is_running(), "stir stops after finishing", "still running")
	stir.free()


## Twice the tempo with a wobbling radius scores below Good.
func _test_stir_sloppy() -> void:
	var stir := _add_station(STIR_SCENE) as Stir
	var results := _collect_finished(stir)
	stir.begin({"color": POTION_COLOR, "tempo": 0.8})
	_stir_circles(stir, 1.6, Stir.ROTATIONS, 20.0)
	_check(results.size() == 1, "stir sloppy finishes once", str(results))
	_check(not results.is_empty() and results[0] < Station.ASSIST_QUALITY, "stir sloppy quality below Good", str(results))
	stir.free()


## No touches never finish; wiggling back and forth never completes a rotation.
func _test_stir_idle_and_wiggle() -> void:
	var stir := _add_station(STIR_SCENE) as Stir
	var results := _collect_finished(stir)
	stir.begin({"color": POTION_COLOR, "tempo": 0.8})
	for i in 1800:
		stir.advance(FRAME)
	_check(results.is_empty() and stir.is_running(), "stir idle does not finish", str(results))
	stir.feed(_touch(Stir.CENTRE + Vector2(Stir.RING_RADIUS, 0), true))
	for i in 600:
		stir.advance(FRAME)
		stir.feed(_drag(Stir.CENTRE + Vector2.from_angle(sin(i * 0.1) * 2.5) * Stir.RING_RADIUS))
	_check(results.is_empty() and stir.rotation_scores().is_empty(), "stir wiggle completes no rotation", str(stir.rotation_scores()))
	stir.free()


## Stirring 25% too fast: a wider tolerance window scores higher.
func _test_stir_tolerance_scale() -> void:
	var qualities: Array[float] = []
	for scale: float in [1.0, 2.0]:
		var stir := _add_station(STIR_SCENE) as Stir
		var results := _collect_finished(stir)
		stir.tolerance_scale = scale
		stir.begin({"color": POTION_COLOR, "tempo": 0.8})
		_stir_circles(stir, 1.0, Stir.ROTATIONS, 0.0)
		qualities.append(results[0] if results.size() == 1 else -1.0)
		stir.free()
	_check(qualities[0] >= 0.0 and qualities[0] < Station.PERFECT_QUALITY, "stir 25% fast is not Perfect", str(qualities))
	_check(qualities[1] > qualities[0] and qualities[1] >= Station.PERFECT_QUALITY, "stir tolerance scale widens", str(qualities))


## Releasing on the line scores Perfect in every bottle; feedback marks start and stop.
func _test_pour_perfect() -> void:
	for shape in Pour.BOTTLES:
		var pour := _add_station(POUR_SCENE) as Pour
		var results := _collect_finished(pour)
		var cues: Array[StringName] = []
		pour.feedback.connect(func(kind: StringName) -> void: cues.append(kind))
		pour.begin({"color": POTION_COLOR, "bottle": shape, "line": 0.7})
		_pour_to(pour, pour.target_line())
		_check(results.size() == 1 and results[0] >= Station.PERFECT_QUALITY, "pour %s on the line is Perfect" % shape, "%s at fill %.3f line %.3f" % [results, pour.fill, pour.target_line()])
		_check(cues == [&"pour_start", &"pour_stop", &"station_success"], "pour %s feedback" % shape, str(cues))
		pour.free()


## Releasing far over the line scores low; holding past the brim spills and ends the pour by itself.
func _test_pour_sloppy_and_overflow() -> void:
	var pour := _add_station(POUR_SCENE) as Pour
	var results := _collect_finished(pour)
	pour.begin({"color": POTION_COLOR, "bottle": "round", "line": 0.7})
	_pour_to(pour, 0.95)
	_check(results.size() == 1 and results[0] < Station.ASSIST_QUALITY, "pour far over the line scores low", str(results))
	var cues: Array[StringName] = []
	pour.feedback.connect(func(kind: StringName) -> void: cues.append(kind))
	results.clear()
	pour.begin({"color": POTION_COLOR, "bottle": "tall", "line": 0.7})
	pour.feed(_touch(POUR_HOLD_POINT, true))
	for i in 300:
		pour.advance(FRAME)
	_check(results == [0.0], "pour overflow ends with zero quality", str(results))
	_check(cues == [&"pour_start", &"pour_spill", &"pour_stop", &"station_sloppy"], "pour overflow feedback", str(cues))
	_check(pour.fill >= Pour.OVERFLOW_LIMIT, "pour overflow fill", str(pour.fill))
	pour.free()


## Without a touch nothing fills and nothing finishes.
func _test_pour_idle() -> void:
	var pour := _add_station(POUR_SCENE) as Pour
	var results := _collect_finished(pour)
	pour.begin({"color": POTION_COLOR, "bottle": "flask"})
	for i in 1800:
		pour.advance(FRAME)
	_check(results.is_empty() and pour.is_running() and is_zero_approx(pour.fill), "pour idle does not fill or finish", "%s fill %.2f" % [results, pour.fill])
	pour.free()


## Releasing 0.08 over the line: a wider tolerance window scores higher.
func _test_pour_tolerance_scale() -> void:
	var qualities: Array[float] = []
	for scale: float in [1.0, 2.0]:
		var pour := _add_station(POUR_SCENE) as Pour
		var results := _collect_finished(pour)
		pour.tolerance_scale = scale
		pour.begin({"color": POTION_COLOR, "bottle": "teardrop", "line": 0.7})
		_pour_to(pour, pour.target_line() + 0.08)
		qualities.append(results[0] if results.size() == 1 else -1.0)
		pour.free()
	_check(qualities[0] >= 0.0 and qualities[0] < Station.ASSIST_QUALITY, "pour 0.08 over is below Good", str(qualities))
	_check(qualities[1] > qualities[0] and qualities[1] >= Station.PERFECT_QUALITY, "pour tolerance scale widens", str(qualities))


## Assist: one focused "Brew!" button in the thumb zone; gestures do nothing;
## a real tap on it finishes with exactly ASSIST_QUALITY.
func _test_stations_assist_tap() -> void:
	for scene: PackedScene in [STIR_SCENE, POUR_SCENE]:
		var station := _add_station(scene)
		var results := _collect_finished(station)
		station.assist = true
		station.begin({"color": POTION_COLOR, "bottle": "round"})
		await process_frame
		var label := "assist %s" % station.name
		var button := station.get_node_or_null("AssistButton") as Button
		_check(button != null, label + " shows the Brew button", "no AssistButton")
		if button == null:
			station.free()
			continue
		var rect := button.get_global_rect()
		_check(rect.size.x >= MIN_TARGET and rect.size.y >= MIN_TARGET, label + " button size", str(rect.size))
		_check(rect.position.y >= _game.visible_rect().size.y * THUMB_ZONE_TOP, label + " button in thumb zone", str(rect))
		_check(button.has_focus() and button.accessibility_name != "", label + " button focused and named", button.accessibility_name)
		station.feed(_touch(POUR_HOLD_POINT, true))
		for i in 300:
			station.advance(FRAME)
		station.feed(_touch(POUR_HOLD_POINT, false))
		_check(results.is_empty(), label + " ignores gestures", str(results))
		var screen_point := root.get_final_transform() * rect.get_center()
		for pressed: bool in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.position = screen_point
			touch.pressed = pressed
			Input.parse_input_event(touch)
			await process_frame
		_check(results == [Station.ASSIST_QUALITY], label + " tap gives exactly ASSIST_QUALITY", str(results))
		station.free()


## Assist: ui_accept (Enter/Space on desktop) on the focused button gives exactly ASSIST_QUALITY.
func _test_stations_assist_ui_accept() -> void:
	for scene: PackedScene in [STIR_SCENE, POUR_SCENE]:
		var station := _add_station(scene)
		var results := _collect_finished(station)
		station.assist = true
		station.begin({"color": POTION_COLOR, "bottle": "round"})
		await process_frame
		for pressed: bool in [true, false]:
			var accept := InputEventAction.new()
			accept.action = &"ui_accept"
			accept.pressed = pressed
			Input.parse_input_event(accept)
			await process_frame
		_check(results == [Station.ASSIST_QUALITY], "assist %s ui_accept gives exactly ASSIST_QUALITY" % station.name, str(results))
		station.free()


func _add_station(scene: PackedScene) -> Station:
	var station := scene.instantiate() as Station
	root.add_child(station)
	return station


func _collect_finished(station: Station) -> Array[float]:
	var results: Array[float] = []
	station.finished.connect(func(quality: float) -> void: results.append(quality))
	return results


## Drags `rotations` clockwise circles around the stir centre at `rps`, one event
## per FRAME, the radius wobbling by up to `wobble` around the guide ring.
func _stir_circles(stir: Stir, rps: float, rotations: int, wobble: float) -> void:
	var start := Stir.CENTRE + Vector2(Stir.RING_RADIUS, 0)
	stir.feed(_touch(start, true))
	var frames := ceili(rotations / rps / FRAME) + 2
	for i in range(1, frames + 1):
		stir.advance(FRAME)
		var radius := Stir.RING_RADIUS + wobble * sin(i * 0.9)
		stir.feed(_drag(Stir.CENTRE + Vector2.from_angle(i * FRAME * rps * TAU) * radius))
	stir.feed(_touch(start, false))


## Holds until the fill is within half a frame of `level`, then releases.
func _pour_to(pour: Pour, level: float) -> void:
	pour.feed(_touch(POUR_HOLD_POINT, true))
	while pour.fill + FRAME / Pour.FILL_TIME / 2.0 < level:
		pour.advance(FRAME)
	pour.feed(_touch(POUR_HOLD_POINT, false))


func _touch(at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	return touch


func _drag(at: Vector2) -> InputEventScreenDrag:
	var drag := InputEventScreenDrag.new()
	drag.position = at
	return drag


func _check_column(window: Vector2i, expected_visible: Vector2, label: String) -> void:
	root.size = window
	await process_frame
	var visible := _game.visible_rect()
	var column := _game.column_rect()
	_check(visible.size.is_equal_approx(expected_visible), label + " visible size", str(visible))
	_check(is_equal_approx(column.size.x, GameState.COLUMN_WIDTH), label + " column width", str(column))
	_check(is_equal_approx(column.get_center().x, visible.get_center().x), label + " column centred", "%s in %s" % [column, visible])
	_check(visible.encloses(column) and is_equal_approx(column.size.y, visible.size.y), label + " column fills height", str(column))
	root.size = BASE_WINDOW
	await process_frame


func _check(condition: bool, test_name: String, detail: String) -> void:
	if condition:
		_passed += 1
		print("test_gameplay: pass " + test_name)
	else:
		_failures.append("%s: %s" % [test_name, detail])
