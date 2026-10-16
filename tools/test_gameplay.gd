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
const MORTAR_SCENE := preload("res://scenes/stations/mortar.tscn")
const BELLOWS_SCENE := preload("res://scenes/stations/bellows.tscn")
const STATION_SCENES: Array[PackedScene] = [STIR_SCENE, POUR_SCENE, MORTAR_SCENE, BELLOWS_SCENE]
## Bellows test policy: pump whenever the heat is below this (keeps it in the band).
const BELLOWS_KEEP := 0.58
const SPEECH_BUBBLE_SCENE := preload("res://scenes/speech_bubble.tscn")
const POTION_COLOR := Color("#f07c2c")
## One synthetic input frame for the station streams.
const FRAME := 1.0 / 60.0
## A station-local point low in the station, where a thumb holds to pour.
const POUR_HOLD_POINT := Vector2(135, 250)
const BASE_WINDOW := Vector2i(270, 480)
## Window sizes in pixels for the aspect ratios the game must fit: 9:16, 9:19.5 and 16:9.
const PHONE_9_16 := Vector2i(1080, 1920)
const PHONE_9_19_5 := Vector2i(1080, 2340)
const PHONE_9_21 := Vector2i(1080, 2520)
const DESKTOP_16_9 := Vector2i(1920, 1080)
const MIN_TARGET := 32.0
const THUMB_ZONE_TOP := 0.4
## Real-time limit for the whole run; a test stuck on an await fails instead of hanging.
const WATCHDOG_MSEC := 120000
## Frames a shop test waits for one step of the flow (a walk, a line, a station) before failing.
const FLOW_FRAMES := 900

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
		_test_fit_window_rect,
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
		_test_pour_liquid_rows_match_mask,
		_test_pour_tolerance_scale,
		_test_mortar_perfect,
		_test_mortar_sloppy,
		_test_mortar_idle_and_wiggle,
		_test_mortar_gentle,
		_test_mortar_ghost_demo,
		_test_bellows_perfect,
		_test_bellows_sloppy,
		_test_bellows_idle,
		_test_bellows_gentle,
		_test_stations_assist_tap,
		_test_stations_assist_ui_accept,
		_test_economy_rules,
		_test_shop_day1_assist,
		_test_shop_wrong_recipe_misbrews,
		_test_shop_patience_timeout,
		_test_shop_storm_off_locks_brew,
		_test_shop_missing_day_returns_to_title,
		_test_shop_pot_add_remove,
		_test_shop_pause_toggles,
		_test_shop_pause_focus,
		_test_shop_controls_size_and_zone,
		_test_shop_ceiling_covers_extra_height,
		_test_shop_customer_canvas,
		_test_shop_shelf_down_reaches_brew,
		_test_shop_perfect_serve_reaction,
		_test_shop_keyboard_day1_assist,
		_test_shop_menu_and_mode_info,
		_test_stations_assist_caption,
		_test_stir_ghost_demo,
		_test_shop_pour_line_random,
		_test_bubble_marks_hint_words,
		_test_shop_shelf_essence_pips,
		_test_shop_pot_preview_needs,
		_test_shop_stir_real_touch,
		_test_shop_grade_stamps,
		_test_shop_patience_row,
		_test_shop_mortar_and_bellows,
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


## The 405x720 desktop window is in screen points: scaled by the screen density,
## shrunk to fit the usable screen with its frame, centred.
func _test_fit_window_rect() -> void:
	var base := Vector2i(405, 720)
	# 2x Retina with room to spare (macOS: 64 px title bar, menu bar above y 78).
	var roomy := GameState.fit_window_rect(base, 2.0, Rect2i(0, 78, 3600, 2070), Vector2i(0, 64), Vector2i(0, 64))
	# 1x 1366x768 laptop with a 40 px taskbar (Windows-style frame: borders and a 31 px title).
	var small_usable := Rect2i(0, 0, 1366, 728)
	var small := GameState.fit_window_rect(base, 1.0, small_usable, Vector2i(16, 39), Vector2i(8, 31))
	var small_framed := Rect2i(small.position - Vector2i(8, 31), small.size + Vector2i(16, 39))
	# 2x screen too short for the window: the framed top sits at the usable top.
	var tight := GameState.fit_window_rect(base, 2.0, Rect2i(0, 74, 2560, 1400), Vector2i(0, 64), Vector2i(0, 64))
	# 1x full-HD screen: unchanged.
	var full_hd := GameState.fit_window_rect(base, 1.0, Rect2i(0, 0, 1920, 1040), Vector2i(16, 39), Vector2i(8, 31))
	_check(roomy == Rect2i(1395, 425, 810, 1440), "fit_window_rect doubles on a roomy 2x screen", str(roomy))
	_check(small_usable.encloses(small_framed) and small_framed.size.y == small_usable.size.y
		and absf(float(small.size.x) / small.size.y - 9.0 / 16.0) < 0.01,
		"fit_window_rect shrinks to a short 1x screen keeping 9:16", "%s (framed %s)" % [small, small_framed])
	_check(tight.position.y - 64 == 74 and tight.size.y + 64 <= 1400, "fit_window_rect fits a short 2x screen", str(tight))
	_check(full_hd.size == base, "fit_window_rect leaves a roomy 1x screen unchanged", str(full_hd))


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


## A clean circle at RING_RADIUS (the ghost's arrows) at exactly the asked tempo scores Perfect.
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


## Each bottle's fill spans exactly its liquid mask's opaque rows (art: rows 5..25,
## teardrop 5..26), and the line snaps to a whole row of that bottle.
func _test_pour_liquid_rows_match_mask() -> void:
	for shape in Pour.BOTTLES:
		var pour := _add_station(POUR_SCENE) as Pour
		pour.begin({"color": Color.WHITE, "bottle": shape})
		var rows := pour.liquid_rows()
		_check(rows == (Vector2i(5, 27) if shape == "teardrop" else Vector2i(5, 26)), "pour %s liquid rows match its mask" % shape, str(rows))
		var line_rows := pour.target_line() * (rows.y - rows.x)
		_check(is_equal_approx(line_rows, roundf(line_rows)), "pour %s line is a whole liquid row" % shape, "%.3f rows" % line_rows)
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


## Steady circles at exactly the target speed grind to full fineness and score
## Perfect; feedback every turn; the brew's grind ingredients sit in the bowl.
func _test_mortar_perfect() -> void:
	var mortar := _add_station(MORTAR_SCENE) as Mortar
	var results := _collect_finished(mortar)
	var cues: Array[StringName] = []
	mortar.feedback.connect(func(kind: StringName) -> void: cues.append(kind))
	mortar.begin({"color": POTION_COLOR, "ingredients": ["moonmoss"]})
	_check(mortar.get_node("Bowl/Pieces").get_child_count() == 1, "mortar shows its ingredient in the bowl", str(mortar.get_node("Bowl/Pieces").get_child_count()))
	_circles(mortar, Mortar.CENTRE, Mortar.RING_RADIUS, Mortar.DEFAULT_SPEED, Mortar.TURNS, 0.0)
	_check(results.size() == 1, "mortar perfect finishes once", str(results))
	_check(not results.is_empty() and results[0] >= Station.PERFECT_QUALITY, "mortar perfect quality", str(results))
	_check(cues.count(&"mortar_turn") == Mortar.TURNS and cues.back() == &"station_success", "mortar feedback every turn", str(cues))
	_check(is_equal_approx(mortar.fineness, 1.0) and mortar.turn_scores().size() == Mortar.TURNS, "mortar ground to full fineness", "%.2f %s" % [mortar.fineness, mortar.turn_scores()])
	_check(not mortar.is_running(), "mortar stops after finishing", "still running")
	mortar.free()


## Grinding at 2.5x the speed scores below Good.
func _test_mortar_sloppy() -> void:
	var mortar := _add_station(MORTAR_SCENE) as Mortar
	var results := _collect_finished(mortar)
	mortar.begin({"color": POTION_COLOR})
	_circles(mortar, Mortar.CENTRE, Mortar.RING_RADIUS, Mortar.DEFAULT_SPEED * 2.5, Mortar.TURNS, 0.0)
	_check(results.size() == 1 and results[0] < Station.ASSIST_QUALITY, "mortar too fast scores below Good", str(results))
	mortar.free()


## No touches never finish; wiggling back and forth grinds nothing.
func _test_mortar_idle_and_wiggle() -> void:
	var mortar := _add_station(MORTAR_SCENE) as Mortar
	var results := _collect_finished(mortar)
	mortar.begin({"color": POTION_COLOR})
	for i in 1800:
		mortar.advance(FRAME)
	_check(results.is_empty() and mortar.is_running(), "mortar idle does not finish", str(results))
	mortar.feed(_touch(Mortar.CENTRE + Vector2(Mortar.RING_RADIUS, 0), true))
	for i in 600:
		mortar.advance(FRAME)
		mortar.feed(_drag(Mortar.CENTRE + Vector2.from_angle(sin(i * 0.1) * 2.5) * Mortar.RING_RADIUS))
	_check(results.is_empty() and mortar.turn_scores().is_empty() and mortar.fineness < 0.25, "mortar wiggle completes no turn", "%s %.2f" % [mortar.turn_scores(), mortar.fineness])
	mortar.free()


## Grinding 35% too fast: not Perfect normally, Perfect with Gentle mode's wider window.
func _test_mortar_gentle() -> void:
	var qualities: Array[float] = []
	for scale: float in [1.0, GameState.GENTLE_TOLERANCE_SCALE]:
		var mortar := _add_station(MORTAR_SCENE) as Mortar
		var results := _collect_finished(mortar)
		mortar.tolerance_scale = scale
		mortar.begin({"color": POTION_COLOR})
		_circles(mortar, Mortar.CENTRE, Mortar.RING_RADIUS, Mortar.DEFAULT_SPEED * 1.35, Mortar.TURNS, 0.0)
		qualities.append(results[0] if results.size() == 1 else -1.0)
		mortar.free()
	_check(qualities[0] >= 0.0 and qualities[0] < Station.PERFECT_QUALITY, "mortar 35% fast is not Perfect", str(qualities))
	_check(qualities[1] > qualities[0] and qualities[1] >= Station.PERFECT_QUALITY, "mortar Gentle widens the band", str(qualities))


## The ghost pestle circles the opening at the target speed, fades after the first
## touch; Assist shows no ghost.
func _test_mortar_ghost_demo() -> void:
	var mortar := _add_station(MORTAR_SCENE) as Mortar
	mortar.begin({"color": POTION_COLOR})
	var ghost := mortar.ghost()
	var start := ghost.position
	for i in roundi(0.5 / Mortar.DEFAULT_SPEED / FRAME):
		mortar.advance(FRAME)
	_check(ghost.visible and is_equal_approx(ghost.modulate.a, Mortar.GHOST_ALPHA), "mortar ghost demonstrates", str(ghost.modulate.a))
	_check(ghost.position.distance_to(start) > Mortar.SURFACE_RADII.y, "mortar ghost moves half a turn", "%s -> %s" % [start, ghost.position])
	mortar.feed(_touch(Mortar.CENTRE + Vector2(Mortar.RING_RADIUS, 0), true))
	for i in 30:
		mortar.advance(FRAME)
	_check(is_zero_approx(ghost.modulate.a), "mortar ghost fades after the first touch", str(ghost.modulate.a))
	mortar.assist = true
	mortar.begin({"color": POTION_COLOR})
	_check(not ghost.visible, "mortar Assist shows no ghost", "ghost visible")
	mortar.free()


## Pumping whenever the heat drops below BELLOWS_KEEP keeps the needle in the band:
## Perfect after DURATION, with a pump cue per tap.
func _test_bellows_perfect() -> void:
	var bellows := _add_station(BELLOWS_SCENE) as Bellows
	var results := _collect_finished(bellows)
	var cues: Array[StringName] = []
	bellows.feedback.connect(func(kind: StringName) -> void: cues.append(kind))
	bellows.begin({"color": POTION_COLOR})
	var frames := _pump_bellows(bellows, func(_frame: int) -> bool: return bellows.heat < BELLOWS_KEEP)
	_check(results.size() == 1 and results[0] >= Station.PERFECT_QUALITY, "bellows in the band is Perfect", str(results))
	_check(is_zero_approx(bellows.out_time()), "bellows never left the band", str(bellows.out_time()))
	_check(frames * FRAME < Bellows.DURATION + 1.0, "bellows finishes about DURATION after reaching the band", "%.2fs" % (frames * FRAME))
	_check(cues.count(&"bellows_pump") > 0 and not (&"bellows_out" in cues) and cues.back() == &"station_success", "bellows feedback", str(cues))
	bellows.free()


## Pumping every few frames overheats: the needle sits above the band, below Good.
func _test_bellows_sloppy() -> void:
	var bellows := _add_station(BELLOWS_SCENE) as Bellows
	var results := _collect_finished(bellows)
	var cues: Array[StringName] = []
	bellows.feedback.connect(func(kind: StringName) -> void: cues.append(kind))
	bellows.begin({"color": POTION_COLOR})
	_pump_bellows(bellows, func(frame: int) -> bool: return frame % 4 == 0)
	_check(results.size() == 1 and results[0] < Station.ASSIST_QUALITY, "bellows overheating scores below Good", str(results))
	_check(&"bellows_out" in cues, "bellows cue when the needle leaves the band", str(cues))
	bellows.free()


## Without a tap the heat only cools: the timer never starts and nothing finishes.
func _test_bellows_idle() -> void:
	var bellows := _add_station(BELLOWS_SCENE) as Bellows
	var results := _collect_finished(bellows)
	bellows.begin({"color": POTION_COLOR})
	for i in 1800:
		bellows.advance(FRAME)
	_check(results.is_empty() and bellows.is_running() and not bellows.is_timing() and is_zero_approx(bellows.heat), "bellows idle does not finish", "%s heat %.2f" % [results, bellows.heat])
	bellows.free()


## About 15% of the time below the band: not Perfect normally, Perfect with Gentle mode.
func _test_bellows_gentle() -> void:
	var qualities: Array[float] = []
	for scale: float in [1.0, GameState.GENTLE_TOLERANCE_SCALE]:
		var bellows := _add_station(BELLOWS_SCENE) as Bellows
		var results := _collect_finished(bellows)
		bellows.tolerance_scale = scale
		bellows.begin({"color": POTION_COLOR})
		var dropped := [-1]
		_pump_bellows(bellows, func(frame: int) -> bool:
			# From 1 s into the timer, stop pumping until the needle has been below the band for 0.75 s.
			if bellows.is_timing() and frame >= 60 and dropped[0] < 0:
				if bellows.heat < Bellows.BAND_LOW:
					dropped[0] = frame
				return false
			if dropped[0] >= 0 and frame - dropped[0] < 44:
				return false
			return bellows.heat < BELLOWS_KEEP)
		qualities.append(results[0] if results.size() == 1 else -1.0)
		print("test_gameplay: bellows gentle x%.1f out %.2fs" % [scale, bellows.out_time()])
		bellows.free()
	_check(qualities[0] >= 0.0 and qualities[0] < Station.PERFECT_QUALITY, "bellows 15% out is not Perfect", str(qualities))
	_check(qualities[1] > qualities[0] and qualities[1] >= Station.PERFECT_QUALITY, "bellows Gentle widens the window", str(qualities))


## Assist: one focused "Brew!" button in the thumb zone; gestures do nothing;
## a real tap on it finishes with exactly ASSIST_QUALITY.
func _test_stations_assist_tap() -> void:
	for scene in STATION_SCENES:
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
	for scene in STATION_SCENES:
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


func _test_economy_rules() -> void:
	_check(Economy.pay(12, Brew.Grade.PERFECT) == 12, "pay perfect is the full price", str(Economy.pay(12, Brew.Grade.PERFECT)))
	_check(Economy.pay(12, Brew.Grade.GOOD) == 9, "pay good is 75%", str(Economy.pay(12, Brew.Grade.GOOD)))
	_check(Economy.pay(12, Brew.Grade.MEH) == 5, "pay meh is 40% rounded", str(Economy.pay(12, Brew.Grade.MEH)))
	_check(Economy.pay(12, Brew.Grade.MISBREW) == 0, "pay misbrew is nothing", str(Economy.pay(12, Brew.Grade.MISBREW)))
	_check(Economy.reputation_delta(Brew.Grade.PERFECT) == 2 and Economy.reputation_delta(Brew.Grade.MISBREW) == -1, "reputation per grade", "%d %d" % [Economy.reputation_delta(Brew.Grade.PERFECT), Economy.reputation_delta(Brew.Grade.MISBREW)])
	_check(Economy.STORMED_OFF_REPUTATION < Economy.reputation_delta(Brew.Grade.MISBREW), "storming off costs more than a misbrew", str(Economy.STORMED_OFF_REPUTATION))


## Day 1 from the real content bank, Assist on: every customer gets the exact
## recipe through real taps on the shelf, Brew and each station's Assist button;
## all are Good (the Assist cap) and pay Economy.pay(price, GOOD).
func _test_shop_day1_assist() -> void:
	_game.assist_mode = true
	var shop := await _open_shop()
	var day := Content.day(1)
	var expected_coins := day.starting_coins
	_check(shop.coins == day.starting_coins and shop.stock == day.starting_stock, "shop starts with the day's coins and stock", "%d %s" % [shop.coins, shop.stock])
	for n in day.customers.size():
		var label := "day 1 customer %d" % (n + 1)
		var wants := Content.potion(day.customers[n].potion)
		if not await _serve(shop, _exact_recipe(wants, shop.stock), label):
			break
		expected_coins += Economy.pay(wants.price, Brew.Grade.GOOD)
		var bubble_text := (shop.get_node("Column/Stage/Bubble") as SpeechBubble).text
		_check(bubble_text in shop.customer.archetype.reactions["good"], label + ": says a good reaction line", bubble_text)
		await _skip_lines(shop)
	var summary := shop.get_node("Modal/SummaryPanel") as Control
	_check(await _until(func() -> bool: return summary.visible, FLOW_FRAMES), "day 1 ends with the summary", "summary hidden")
	_check(shop.grades == ([Brew.Grade.GOOD, Brew.Grade.GOOD, Brew.Grade.GOOD] as Array[Brew.Grade]), "day 1 assist grades are all Good", str(shop.grades))
	_check(shop.served == 3 and shop.perfect == 0 and shop.stormed_off == 0, "day 1 counts", "%d %d %d" % [shop.served, shop.perfect, shop.stormed_off])
	_check(shop.coins == expected_coins and shop.coins == 47, "day 1 coins follow Economy.pay", "%d, expected %d" % [shop.coins, expected_coins])
	var stats := (shop.get_node("Modal/SummaryPanel/List/Stats") as Label).text
	_check("Served 3 of 3" in stats and "+27" in stats, "summary shows the day", stats)
	await _tap(shop.get_node("Modal/SummaryPanel/List/BackButton") as Button)
	if _game.is_transitioning():
		await _game.transition_finished
	_check(_game.state == GameState.Flow.TITLE, "summary back button goes to the title", str(_game.state))
	_game.assist_mode = false


## A brew far from the target is a Misbrew: no pay, the overshooting essence's
## effect on the customer and a misbrew line for that essence in the bubble.
func _test_shop_wrong_recipe_misbrews() -> void:
	_game.assist_mode = true
	var shop := await _open_shop()
	if await _wait_for_order(shop, "misbrew"):
		var wants := shop.customer.potion
		var recipe := _recipe_between(wants, shop.stock, 3)
		var essences: Array[Vector4i] = []
		for id in recipe:
			essences.append(Content.ingredient(id).essence)
		var essence := Brew.misbrew_essence(Brew.combine(essences), wants.target)
		var coins := shop.coins
		await _serve(shop, recipe, "misbrew")
		var bubble := shop.get_node("Column/Stage/Bubble") as SpeechBubble
		var lines := PackedStringArray()
		for line in Content.misbrews_for(essence):
			lines.append(line.text)
		_check(shop.grades == ([Brew.Grade.MISBREW] as Array[Brew.Grade]), "wrong recipe is a Misbrew", str(shop.grades))
		_check(shop.coins == coins and shop.reputation == Economy.reputation_delta(Brew.Grade.MISBREW), "misbrew pays nothing", "%d %d" % [shop.coins, shop.reputation])
		var effect := shop.customer.effect if shop.customer != null else "-"
		_check(effect == Content.MISBREW_EFFECTS[essence], "misbrew effect follows the overshoot", "%s for %s" % [effect, Content.ESSENCES[essence]])
		_check(bubble.text in lines, "misbrew line for the essence", bubble.text)
	await _close_shop()


## Patience running out while waiting, then mid-brew: the customer storms off with
## a stormed_off line, costs reputation, pays nothing; mid-brew the station is
## dropped and the ingredients are lost. The next customer still comes in.
func _test_shop_patience_timeout() -> void:
	var shop := await _open_shop()
	if await _wait_for_order(shop, "timeout"):
		var who := shop.customer.archetype
		shop.customer.patience_left = 0.2
		_check(await _until(func() -> bool: return shop.stormed_off == 1, FLOW_FRAMES), "patience timeout storms off", str(shop.stormed_off))
		var bubble := shop.get_node("Column/Stage/Bubble") as SpeechBubble
		_check(bubble.text in who.reactions["stormed_off"], "storming off says a stormed_off line", bubble.text)
		_check(shop.reputation == Economy.STORMED_OFF_REPUTATION and shop.coins == Content.day(1).starting_coins and shop.served == 0, "storming off costs reputation only", "%d %d" % [shop.reputation, shop.coins])
		_check(not (shop.get_node("Column/Stage/Stamp") as Control).visible and _pay_texts(shop).is_empty(), "storming off shows no grade stamp and no coins", str(_pay_texts(shop)))
		await _skip_lines(shop)
	if await _wait_for_order(shop, "timeout mid-brew"):
		var recipe := _exact_recipe(shop.customer.potion, shop.stock)
		var before := shop.stock.duplicate()
		for id in recipe:
			await _tap(shop.shelf_item(id))
		await _tap(shop.brew_button())
		_check(await _until(func() -> bool: return shop.station != null and shop.station.is_running(), FLOW_FRAMES), "brew starts a station", "no station")
		shop.customer.patience_left = 0.2
		_check(await _until(func() -> bool: return shop.stormed_off == 2, FLOW_FRAMES), "patience runs out mid-brew", str(shop.stormed_off))
		await process_frame
		_check(shop.station == null and not shop.is_brewing(), "storming off drops the station", str(shop.station))
		var lost := 0
		for id: String in before:
			lost += before[id] - shop.stock[id]
		_check(lost == recipe.size() and shop.pot.is_empty(), "mid-brew ingredients are lost", "lost %d" % lost)
		var third := Content.day(1).customers[2].potion
		_check(await _until(func() -> bool: return shop.customer != null and shop.customer.potion.id == third, FLOW_FRAMES), "the next customer comes in", "no third customer")
	await _close_shop()


## Tap adds one (stock -1), a pot slot tap takes it back (stock +1), the pot holds
## at most 3, Brew needs 2, and a drag released over the cauldron adds one too.
func _test_shop_pot_add_remove() -> void:
	var shop := await _open_shop()
	if await _wait_for_order(shop, "pot"):
		var ids: Array[String] = []
		ids.assign(shop.stock.keys())
		var first := ids[0]
		var count := shop.stock[first]
		await _tap(shop.shelf_item(first))
		_check(shop.pot.size() == 1 and shop.stock[first] == count - 1 and shop.shelf_item(first).stock == count - 1, "tap adds to the pot", "%d %d" % [shop.pot.size(), shop.stock[first]])
		_check(shop.brew_button().disabled and not shop.slot_button(0).disabled, "one ingredient: slot filled, Brew disabled", "brew disabled %s" % shop.brew_button().disabled)
		await _check_preview(shop, Content.ingredient(first).essence, "preview after adding")
		await _tap(shop.slot_button(0))
		_check(shop.pot.is_empty() and shop.stock[first] == count, "slot tap restores the stock", "%d %d" % [shop.pot.size(), shop.stock[first]])
		await _check_preview(shop, Vector4i.ZERO, "preview after removing")
		for i in 4:
			await _tap(shop.shelf_item(ids[i]))
		_check(shop.pot.size() == Shop.POT_CAPACITY and shop.stock[ids[3]] == shop.shelf_item(ids[3]).stock and shop.stock[ids[3]] == Content.day(1).starting_stock[ids[3]], "pot holds at most 3", "%d" % shop.pot.size())
		_check(not shop.brew_button().disabled, "Brew enabled with 3", "disabled")
		for i in Shop.POT_CAPACITY:
			await _tap(shop.slot_button(0))
		_check(shop.stock == Content.day(1).starting_stock, "emptying the pot restores every stock", str(shop.stock))
		var from := shop.shelf_item(first).get_global_rect().get_center()
		var cauldron := (shop.get_node("Column/Stage") as Control).get_global_transform() * Shop.POT_MOUTH
		await _drag_touch(from, from + Vector2(0, -40))
		_check(shop.pot.is_empty(), "drag released off the cauldron adds nothing", str(shop.pot.size()))
		await _drag_touch(from, cauldron)
		_check(shop.pot.size() == 1 and shop.stock[first] == count - 1, "drag into the cauldron adds one", "%d %d" % [shop.pot.size(), shop.stock[first]])
	await _close_shop()


## The pause panel's toggles set the session settings, the next station picks
## them up, and switching Assist off restarts a running station as a gesture.
func _test_shop_pause_toggles() -> void:
	var shop := await _open_shop()
	if await _wait_for_order(shop, "pause"):
		var pause := shop.get_node("Column/Hud/PauseButton") as Button
		await _tap(pause)
		_check(paused and (shop.get_node("Modal/PausePanel") as Control).visible, "pause button pauses", "paused %s" % paused)
		var patience := shop.customer.patience_left
		for i in 30:
			await process_frame
		_check(is_equal_approx(shop.customer.patience_left, patience), "patience stops while paused", "%f -> %f" % [patience, shop.customer.patience_left])
		await _tap(shop.get_node("Modal/PausePanel/List/AssistRow/AssistButton") as Button)
		await _tap(shop.get_node("Modal/PausePanel/List/GentleRow/GentleButton") as Button)
		_check(_game.assist_mode and _game.gentle_mode, "pause toggles set the settings", "%s %s" % [_game.assist_mode, _game.gentle_mode])
		_check((shop.get_node("Column/Hud/AssistTag") as Control).visible, "HUD shows the Assist tag", "hidden")
		await _tap(shop.get_node("Modal/PausePanel/List/ResumeButton") as Button)
		_check(not paused, "resume unpauses", "still paused")
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			await _tap(shop.shelf_item(id))
		await _tap(shop.brew_button())
		_check(await _until(func() -> bool: return shop.station != null and shop.station.is_running(), FLOW_FRAMES), "brew starts a station", "no station")
		_check(shop.station.assist and is_equal_approx(shop.station.tolerance_scale, GameState.GENTLE_TOLERANCE_SCALE), "station gets the toggled settings", "%s %f" % [shop.station.assist, shop.station.tolerance_scale])
		await _tap(pause)
		await _tap(shop.get_node("Modal/PausePanel/List/AssistRow/AssistButton") as Button)
		await process_frame
		_check(not _game.assist_mode and not shop.station.assist and shop.station.get_node_or_null("AssistButton") == null and shop.station.is_running(), "assist off restarts the station as a gesture", "assist %s" % shop.station.assist)
		await _tap(shop.get_node("Modal/PausePanel/List/ResumeButton") as Button)
	await _close_shop()


## Patience running out with 2 ingredients in the pot: the customer is STORMING,
## Brew is disabled and a tap on it starts nothing; the next customer comes in
## untouched (no brew, no grade, full patience). Then the same mid-station with
## Assist on: the station is dropped, the shelf takes focus again, Brew stays
## locked, and the third customer comes in untouched.
func _test_shop_storm_off_locks_brew() -> void:
	_game.assist_mode = true
	var shop := await _open_shop()
	var day := Content.day(1)
	if await _wait_for_order(shop, "storm-off"):
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			await _tap(shop.shelf_item(id))
		_check(not shop.brew_button().disabled, "storm-off: Brew enabled with 2", "disabled")
		var leaving := shop.customer
		var leaving_id := leaving.get_instance_id()
		leaving.patience_left = 0.2
		_check(await _until(func() -> bool: return shop.stormed_off == 1, FLOW_FRAMES), "storm-off: patience runs out", str(shop.stormed_off))
		_check(leaving.state == Customer.State.STORMING and shop.brew_button().disabled, "storm-off: customer STORMING, Brew disabled", "state %s disabled %s" % [Customer.State.keys()[leaving.state], shop.brew_button().disabled])
		await _tap(shop.brew_button())
		await process_frame
		_check(not shop.is_brewing() and shop.station == null and shop.pot.size() == 2, "storm-off: Brew tap starts nothing", "brewing %s pot %d" % [shop.is_brewing(), shop.pot.size()])
		_check(await _until(func() -> bool: return shop.customer != null and shop.customer.get_instance_id() != leaving_id and shop.customer.state == Customer.State.WAIT_ORDER, FLOW_FRAMES), "storm-off: next customer waits for an order", "no next customer")
		_check(shop.customer.potion.id == day.customers[1].potion and shop.served == 0 and shop.grades.is_empty() and not shop.is_brewing(), "storm-off: next customer unaffected", "served %d grades %s" % [shop.served, shop.grades])
		# Patience drains from the moment the order is up; allow a second of it.
		_check(shop.customer.patience_left >= shop.customer.patience_total - 1.0, "storm-off: next customer has fresh patience", "%f of %f" % [shop.customer.patience_left, shop.customer.patience_total])
		for i in shop.pot.size():
			await _tap(shop.slot_button(0))
	if await _wait_for_order(shop, "storm-off mid-station"):
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			await _tap(shop.shelf_item(id))
		await _tap(shop.brew_button())
		_check(await _until(func() -> bool: return shop.station != null and shop.station.assist_button() != null, FLOW_FRAMES), "storm-off mid-station: station runs", "no station")
		var leaving := shop.customer
		var leaving_id := leaving.get_instance_id()
		leaving.patience_left = 0.2
		_check(await _until(func() -> bool: return shop.stormed_off == 2, FLOW_FRAMES), "storm-off mid-station: patience runs out", str(shop.stormed_off))
		await process_frame
		_check(shop.station == null and not shop.is_brewing() and shop.brew_button().disabled, "storm-off mid-station: station dropped, Brew locked", "station %s" % shop.station)
		_check(root.gui_get_focus_owner() is ShelfItem, "storm-off mid-station: focus back on the shelf", str(root.gui_get_focus_owner()))
		await _tap(shop.brew_button())
		_check(not shop.is_brewing() and shop.station == null, "storm-off mid-station: Brew tap starts nothing", "brewing %s" % shop.is_brewing())
		_check(await _until(func() -> bool: return shop.customer != null and shop.customer.get_instance_id() != leaving_id and shop.customer.state == Customer.State.WAIT_ORDER, FLOW_FRAMES), "storm-off mid-station: third customer waits", "no third customer")
		_check(shop.customer.potion.id == day.customers[2].potion and shop.served == 0 and shop.station == null, "storm-off mid-station: third customer unaffected", "served %d" % shop.served)
	await _close_shop()


## A day missing from the content: the player lands back on the title with the
## error label saying why, and the error is reported once.
func _test_shop_missing_day_returns_to_title() -> void:
	_game.quiet_errors = true
	Content.quiet_errors = true
	var errors := _game.reported_errors.size()
	_game.goto(GameState.Flow.SHOP, {"day": 99})
	var back := await _until(func() -> bool: return _game.state == GameState.Flow.TITLE and not _game.is_transitioning() and _game.reported_errors.size() > errors, FLOW_FRAMES)
	_game.quiet_errors = false
	Content.quiet_errors = false
	var error_label := _game.get_node("Fade/ErrorLabel") as Label
	_check(back and current_scene is Title, "missing day returns to the title", "state %s scene %s" % [GameState.Flow.keys()[_game.state], current_scene])
	_check(_game.reported_errors.size() == errors + 1 and "Day 99" in _game.reported_errors.back(), "missing day is reported once", str(_game.reported_errors.slice(errors)))
	_check(error_label.visible and "Day 99" in error_label.text, "missing day shows the error label", error_label.text)
	error_label.hide()


## Resume puts focus back where it was (a shelf item), and focus cannot leave the
## pause panel while it is open. While a station runs, the shelf and Brew under
## its dim take no focus; toggling Assist in the pause panel keeps focus in the
## panel, and Resume hands it to the station's Assist button.
func _test_shop_pause_focus() -> void:
	_game.assist_mode = true
	var shop := await _open_shop()
	if await _wait_for_order(shop, "pause focus"):
		var panel := shop.get_node("Modal/PausePanel") as Control
		var resume := shop.get_node("Modal/PausePanel/List/ResumeButton") as Button
		var ids: Array[String] = []
		ids.assign(shop.stock.keys())
		var item := shop.shelf_item(ids[1])
		item.grab_focus()
		shop.open_pause()
		await process_frame
		_check(root.gui_get_focus_owner() == resume, "pause focuses Resume", str(root.gui_get_focus_owner()))
		_check(await _focus_stays_in(panel), "focus stays in the pause panel", str(root.gui_get_focus_owner()))
		resume.grab_focus()
		await _action(&"ui_accept")
		_check(not paused and root.gui_get_focus_owner() == item, "resume restores the focused shelf item", str(root.gui_get_focus_owner()))
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			await _tap(shop.shelf_item(id))
		await _tap(shop.brew_button())
		_check(await _until(func() -> bool: return shop.station != null and shop.station.assist_button() != null, FLOW_FRAMES), "pause focus: station runs", "no station")
		var under_dim: Array[Control] = [shop.brew_button()]
		for id in ids:
			under_dim.append(shop.shelf_item(id))
		var focusable := under_dim.filter(func(control: Control) -> bool: return control.get_focus_mode_with_override() != Control.FOCUS_NONE)
		_check(focusable.is_empty(), "shelf and Brew take no focus under the station dim", str(focusable))
		var reached: Array[Control] = []
		for i in 6:
			await _action(&"ui_focus_next")
			reached.append(root.gui_get_focus_owner())
		_check(reached.all(func(control: Control) -> bool: return control not in under_dim), "Tab never reaches controls under the dim", str(reached))
		await _tap(shop.get_node("Column/Hud/PauseButton") as Button)
		var assist_toggle := shop.get_node("Modal/PausePanel/List/AssistRow/AssistButton") as Button
		await _tap(assist_toggle)
		await _tap(assist_toggle)
		await process_frame
		_check(_game.assist_mode and shop.station.assist_button() != null, "assist toggled back on restarts the station with Assist", "assist %s" % _game.assist_mode)
		var owner := root.gui_get_focus_owner()
		_check(owner != null and panel.is_ancestor_of(owner), "assist restart keeps focus in the pause panel", str(owner))
		await _tap(resume)
		_check(not paused and root.gui_get_focus_owner() == shop.station.assist_button(), "resume focuses the station's Assist button", str(root.gui_get_focus_owner()))
	await _close_shop()


## Every interactive control of the shop (shelf items, Brew, pot slots, the
## workspace skip area, Pause, the pause and summary panel buttons, a station's
## Assist button) is at least 32x32, inside the safe area and, except Pause, in
## the thumb zone (lower 60%) at 9:16, 9:19.5 and 16:9.
func _test_shop_controls_size_and_zone() -> void:
	_game.assist_mode = true
	var shop := await _open_shop()
	if await _wait_for_order(shop, "layout"):
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			await _tap(shop.shelf_item(id))
		var pause := shop.get_node("Column/Hud/PauseButton") as Button
		var play: Array[Control] = [shop.brew_button(), shop.slot_button(0), shop.slot_button(1), shop.slot_button(2), shop.get_node("Column/Stage/SkipButton") as Control, pause]
		for item in shop.get_node("Column/Stage/ShelfItems").get_children():
			play.append(item as Control)
		var pause_buttons: Array[Control] = []
		for button in shop.get_node("Modal/PausePanel/List").find_children("*", "Button", true, false):
			pause_buttons.append(button as Control)
		_check(pause_buttons.size() == 6, "layout: pause panel has Resume, two toggles with their \"?\" and Quit", str(pause_buttons))
		var summary := shop.get_node("Modal/SummaryPanel") as Control
		var back: Array[Control] = [shop.get_node("Modal/SummaryPanel/List/BackButton") as Control]
		for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
			root.size = window
			await _frames(30)
			_check_targets(play, pause, "shop at %s" % window)
			shop.open_pause()
			await _frames(30)
			_check_targets(pause_buttons, pause, "pause panel at %s" % window)
			shop.close_pause()
			summary.show()
			await _frames(30)
			_check_targets(back, pause, "summary panel at %s" % window)
			summary.hide()
		root.size = BASE_WINDOW
		await _tap(shop.brew_button())
		if await _until(func() -> bool: return shop.station != null and shop.station.assist_button() != null, FLOW_FRAMES):
			for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
				root.size = window
				await _frames(10)
				_check_targets([shop.station.assist_button()] as Array[Control], pause, "station Assist at %s" % window)
		else:
			_check(false, "layout: station shows Assist", "no station")
		root.size = BASE_WINDOW
		await process_frame
	await _close_shop()


## Tall phones show more shop, never a blank band: shop_ceiling copies stack up
## from the stage's top edge, as wide as the stage, until they pass the screen top
## (9:19.5 and 9:21); 9:16 and 16:9 have no room above the stage and show none.
func _test_shop_ceiling_covers_extra_height() -> void:
	var shop := await _open_shop()
	var stage := shop.get_node("Column/Stage") as Control
	var ceiling := Art.texture("shop", "shop_ceiling")
	for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, PHONE_9_21, DESKTOP_16_9]:
		root.size = window
		await _frames(3)
		var label := "ceiling at %s" % window
		var screen_top := _game.visible_rect().position.y
		var stage_rect := stage.get_global_rect()
		var covered := stage_rect.position.y
		var problems := PackedStringArray()
		for rect: TextureRect in shop._ceilings:
			if not rect.visible:
				continue
			var at := rect.get_global_rect()
			if (rect.texture as AtlasTexture).region != ceiling.region:
				problems.append("%s is not shop_ceiling" % rect)
			if not at.size.is_equal_approx(ceiling.get_size()) or not is_equal_approx(at.position.x, stage_rect.position.x) or not is_equal_approx(at.end.y, covered):
				problems.append("copy at %s (expected bottom %.0f, x %.0f)" % [at, covered, stage_rect.position.x])
			covered = at.position.y
		var expect_copies := stage_rect.position.y > screen_top
		_check(problems.is_empty(), label + ": copies are stacked on the stage top", ", ".join(problems))
		_check(covered <= screen_top and (covered < stage_rect.position.y) == expect_copies, label + ": no blank band above the stage", "covered from %.0f, screen top %.0f, stage top %.0f" % [covered, screen_top, stage_rect.position.y])
	root.size = BASE_WINDOW
	await process_frame
	await _close_shop()


## The waiting customer: a 48x72 canvas in every layer, head centred on the stage,
## the whole head above the counter top and at least 48 rows showing above it; the
## face layer follows the mood.
func _test_shop_customer_canvas() -> void:
	var shop := await _open_shop()
	if await _wait_for_order(shop, "customer canvas"):
		var visitor := shop.customer
		var parts: Array[Sprite2D] = []
		for node in visitor.get_node("Body").get_children():
			if node is Sprite2D and (node as Sprite2D).visible:
				parts.append(node as Sprite2D)
		var sizes := parts.map(func(part: Sprite2D) -> Vector2: return part.texture.get_size())
		_check(parts.size() >= 4 and sizes.all(func(size: Vector2) -> bool: return size == Vector2(48, 72)), "customer parts are 48x72 canvases", str(sizes))
		_check(is_equal_approx(visitor.position.x + Customer.CENTER_X, Shop.STAGE_SIZE.x / 2.0), "customer head on the stage centre", str(visitor.position))
		var counter_row := int(Customer.COUNTER_TOP - visitor.position.y)
		var head := _opaque_rows((visitor.get_node("Body/Head") as Sprite2D).texture as AtlasTexture)
		var top := 72
		for part in parts:
			top = mini(top, _opaque_rows(part.texture as AtlasTexture).x)
		_check(head.y < counter_row and counter_row - top >= 48, "customer: head above the counter, %d rows show" % (counter_row - top), "head rows %s, counter row %d" % [head, counter_row])
		visitor.patience_left = visitor.patience_total * 0.2
		await _frames(2)
		var face := (visitor.get_node("Body/Face") as Sprite2D).texture as AtlasTexture
		var expected := [Art.texture("customer", "face_annoyed_0").region, Art.texture("customer", "face_annoyed_1").region]
		_check(face.region in expected, "annoyed customer shows the annoyed face", str(face.region))
	await _close_shop()


## Keyboard: ui_down from every shelf item lands on Brew (the items share a row,
## so Godot's nearest-neighbour search would pick another item), ui_up from Brew
## goes back to the shelf.
func _test_shop_shelf_down_reaches_brew() -> void:
	var shop := await _open_shop()
	if await _wait_for_order(shop, "shelf focus"):
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			await _tap(shop.shelf_item(id))
		var brew := shop.brew_button()
		_check(not brew.disabled, "shelf focus: Brew enabled", "pot %d" % shop.pot.size())
		for item: ShelfItem in shop.get_node("Column/Stage/ShelfItems").get_children():
			item.grab_focus()
			await _action(&"ui_down")
			_check(root.gui_get_focus_owner() == brew, "ui_down from %s focuses Brew" % item.ingredient.id, str(root.gui_get_focus_owner()))
		brew.grab_focus()
		await _action(&"ui_up")
		_check(root.gui_get_focus_owner() is ShelfItem, "ui_up from Brew focuses the shelf", str(root.gui_get_focus_owner()))
	await _close_shop()


## (first, last) rows of `texture`'s region with an opaque pixel, (72, -1) if none.
func _opaque_rows(texture: AtlasTexture) -> Vector2i:
	var image := texture.atlas.get_image().get_region(Rect2i(texture.region))
	var rows := Vector2i(image.get_height(), -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				rows = Vector2i(mini(rows.x, y), maxi(rows.y, y))
				break
	return rows


## Gestures driven straight into the shop's stations (perfect stir circles, a
## pour released on the line) on the exact recipe: Perfect, and the customer
## says one of the archetype's "perfect" reaction lines.
func _test_shop_perfect_serve_reaction() -> void:
	var shop := await _open_shop()
	if await _wait_for_order(shop, "perfect"):
		var who := shop.customer.archetype
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			await _tap(shop.shelf_item(id))
		await _tap(shop.brew_button())
		for step in shop.customer.potion.steps:
			if not await _until(func() -> bool: return shop.station != null and shop.station.is_running(), FLOW_FRAMES):
				_check(false, "perfect: %s station runs" % step, "no station")
				break
			var running := shop.station
			var running_id := running.get_instance_id()
			if running is Stir:
				_stir_circles(running as Stir, Stir.DEFAULT_TEMPO, Stir.ROTATIONS, 0.0)
			elif running is Pour:
				_pour_to(running as Pour, (running as Pour).target_line())
			await _until(func() -> bool: return shop.station == null or shop.station.get_instance_id() != running_id, FLOW_FRAMES)
		_check(await _until(func() -> bool: return shop.served == 1, FLOW_FRAMES), "perfect: served", "served %d" % shop.served)
		var bubble_text := (shop.get_node("Column/Stage/Bubble") as SpeechBubble).text
		_check(shop.grades == ([Brew.Grade.PERFECT] as Array[Brew.Grade]), "perfect gestures on the exact recipe are Perfect", str(shop.grades))
		_check(bubble_text in who.reactions["perfect"], "perfect: says a perfect reaction line", bubble_text)
		await _check_stamp(shop, Brew.Grade.PERFECT, Economy.pay(shop.customer.potion.price, Brew.Grade.PERFECT), "perfect")
	await _close_shop()


## Day 1 with Assist on, by keyboard alone (ui_* actions): arrows move focus
## between shelf items and Brew, ui_accept adds an ingredient, brews, presses
## each station's Assist button and leaves through the summary's Back button.
func _test_shop_keyboard_day1_assist() -> void:
	_game.assist_mode = true
	var shop := await _open_shop()
	var day := Content.day(1)
	for n in day.customers.size():
		var label := "keyboard customer %d" % (n + 1)
		if not await _wait_for_order(shop, label):
			break
		_check(root.gui_get_focus_owner() is ShelfItem, label + ": a shelf item has focus", str(root.gui_get_focus_owner()))
		var served := shop.served
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			var before := shop.pot.size()
			var focused := await _focus_by_keys(shop.shelf_item(id))
			await _action(&"ui_accept")
			_check(focused and shop.pot.size() == before + 1, "%s: ui_accept adds %s" % [label, id], "focus %s pot %d" % [root.gui_get_focus_owner(), shop.pot.size()])
		var on_brew := await _focus_by_keys(shop.brew_button())
		await _action(&"ui_accept")
		_check(on_brew and shop.is_brewing(), label + ": ui_accept on Brew brews", "focus %s" % root.gui_get_focus_owner())
		for step in shop.customer.potion.steps:
			var ready := await _until(func() -> bool: return shop.station != null and shop.station.is_running() and shop.station.assist_button() != null and shop.station.assist_button().has_focus(), FLOW_FRAMES)
			_check(ready, "%s: %s Assist button has focus" % [label, step], str(root.gui_get_focus_owner()))
			if not ready:
				break
			await _action(&"ui_accept")
		_check(await _until(func() -> bool: return shop.served == served + 1, FLOW_FRAMES), label + ": served", "served %d" % shop.served)
	var back := shop.get_node("Modal/SummaryPanel/List/BackButton") as Button
	_check(await _until(func() -> bool: return back.is_visible_in_tree() and back.has_focus(), FLOW_FRAMES), "keyboard day 1 ends on the focused Back button", str(root.gui_get_focus_owner()))
	_check(shop.served == day.customers.size() and shop.stormed_off == 0, "keyboard day 1 serves everyone", "%d %d" % [shop.served, shop.stormed_off])
	await _action(&"ui_accept")
	if _game.is_transitioning():
		await _game.transition_finished
	_check(_game.state == GameState.Flow.TITLE, "keyboard Back goes to the title", str(_game.state))
	_game.assist_mode = false


## Criterion 3: the pause button reads "Menu", is at least 32x32 in the top-right
## corner of the safe area and has an accessibility name. Mode help (no hover,
## no always-visible text): each toggle keeps its description as an instant
## tooltip, and the "?" right after it (32x32+, focusable, named) opens the same
## text in a callout inside the pause panel and the safe area at 9:16, 9:19.5 and
## 16:9. A tap on the callout, a tap on the dim, Enter and Escape each close it,
## Tab cannot leave it, and focus goes back to the "?".
func _test_shop_menu_and_mode_info() -> void:
	var shop := await _open_shop()
	var safe := _game.safe_rect()
	var menu := shop.get_node("Column/Hud/PauseButton") as Button
	var rect := menu.get_global_rect()
	_check(menu.text == "Menu" and menu.accessibility_name != "", "pause button reads Menu and is named", "%s / %s" % [menu.text, menu.accessibility_name])
	_check(rect.size.x >= MIN_TARGET and rect.size.y >= MIN_TARGET and rect.end.x >= safe.end.x - 8.0 and rect.position.y <= safe.position.y + 8.0, "Menu button is 32x32+ in the top right", "%s in %s" % [rect, safe])
	var tag := shop.get_node("Column/Hud/AssistTag") as Label
	var tag_text := Rect2(tag.get_global_rect().end.x - tag.get_minimum_size().x, tag.get_global_rect().position.y, tag.get_minimum_size().x, tag.size.y)
	_check(not rect.intersects(tag_text), "Menu button clears the ASSIST tag", "%s vs %s" % [rect, tag_text])
	shop.open_pause()
	await _frames(5)
	var list := shop.get_node("Modal/PausePanel/List")
	var panel := shop.get_node("Modal/PausePanel") as Control
	var help := shop.get_node("Modal/ModeHelp") as Button
	var callout := shop.get_node("Modal/ModeHelp/Callout") as Control
	var text := shop.get_node("Modal/ModeHelp/Callout/Text") as Label
	var dim := shop.get_node("Modal/Dim") as Control
	_check(list.find_children("*Info", "", true, false).is_empty(), "no always-visible mode descriptions remain", str(list.find_children("*Info", "", true, false)))
	for mode: Array in [["Assist", Shop.ASSIST_INFO], ["Gentle", Shop.GENTLE_INFO]]:
		var toggle := list.get_node("%sRow/%sButton" % [mode[0], mode[0]]) as Button
		var question := list.get_node("%sRow/%sHelp" % [mode[0], mode[0]]) as Button
		var label := "%s \"?\"" % mode[0]
		_check(toggle.tooltip_text == mode[1], "%s tooltip is its description" % toggle.name, toggle.tooltip_text)
		_check(question.text == "?" and question.get_index() == toggle.get_index() + 1 and question.focus_mode == Control.FOCUS_ALL and question.accessibility_name == "What does %s mode do?" % mode[0], label + " sits right after its toggle, focusable and named", "index %d/%d '%s'" % [question.get_index(), toggle.get_index(), question.accessibility_name])
		await _tap(question)
		_check(help.visible and text.text.replace("\n", " ") == mode[1] and root.gui_get_focus_owner() == help, label + " tap shows its description", "visible %s '%s' focus %s" % [help.visible, text.text, root.gui_get_focus_owner()])
		_check(help.get_global_rect().is_equal_approx(panel.get_global_rect()), label + " help covers exactly the pause panel", "%s vs %s" % [help.get_global_rect(), panel.get_global_rect()])
		var tail := (shop.get_node("Modal/ModeHelp/Tail") as Control).get_global_rect()
		_check(absf(tail.end.x - question.get_global_rect().get_center().x) <= tail.size.x and tail.end.y <= question.get_global_rect().position.y + 1.0, label + " callout points at its \"?\"", "tail %s, ? %s" % [tail, question.get_global_rect()])
		for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
			root.size = window
			await _frames(10)
			var at := callout.get_global_rect()
			_check(panel.get_global_rect().encloses(at) and _game.safe_rect().encloses(at), "%s callout inside the panel and safe area at %s" % [label, window], "%s in %s" % [at, panel.get_global_rect()])
			_check_targets([question] as Array[Control], menu, "%s at %s" % [label, window])
		root.size = BASE_WINDOW
		await _frames(5)
		await _tap(callout)
		_check(not help.visible and root.gui_get_focus_owner() == question, label + " callout tap closes it, focus back on the \"?\"", "visible %s focus %s" % [help.visible, root.gui_get_focus_owner()])
		await _tap(question)
		await _tap_at(dim.get_global_rect().position + Vector2(dim.size.x / 2.0, 20.0))
		_check(not help.visible and paused, label + " a tap on the dim closes it, still paused", "visible %s" % help.visible)
		question.grab_focus()
		await _action(&"ui_accept")
		_check(help.visible and root.gui_get_focus_owner() == help, label + " Enter opens it", "visible %s focus %s" % [help.visible, root.gui_get_focus_owner()])
		await _action(&"ui_focus_next")
		await _action(&"ui_focus_prev")
		_check(root.gui_get_focus_owner() == help, label + " Tab stays on the open help", str(root.gui_get_focus_owner()))
		await _action(&"ui_accept")
		_check(not help.visible and root.gui_get_focus_owner() == question, label + " Enter again closes it, focus back on the \"?\"", "visible %s focus %s" % [help.visible, root.gui_get_focus_owner()])
		await _action(&"ui_accept")
		await _key(KEY_ESCAPE)
		_check(not help.visible and root.gui_get_focus_owner() == question and paused, label + " Escape closes it, focus back on the \"?\"", "visible %s focus %s" % [help.visible, root.gui_get_focus_owner()])
	_check("Good" in Shop.ASSIST_INFO and "never Perfect" in Shop.ASSIST_INFO, "Assist info says Good, never Perfect", Shop.ASSIST_INFO)
	_check(("%sx" % GameState.GENTLE_TOLERANCE_SCALE) in Shop.GENTLE_INFO, "Gentle info names the tolerance scale", Shop.GENTLE_INFO)
	_check(is_zero_approx(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", -1.0))), "tooltips appear without delay", str(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")))
	shop.close_pause()
	await _close_shop()


## Criterion 4: with Assist on, the station's single button reads "Auto Stir",
## "Auto Pour", "Auto Grind" or "Auto Pump" (accessibility name the same); with
## Assist off there is none.
func _test_stations_assist_caption() -> void:
	for entry: Array in [[STIR_SCENE, "Auto Stir"], [POUR_SCENE, "Auto Pour"], [MORTAR_SCENE, "Auto Grind"], [BELLOWS_SCENE, "Auto Pump"]]:
		var station := _add_station(entry[0] as PackedScene)
		station.begin({"color": POTION_COLOR, "bottle": "round"})
		_check(station.assist_button() == null and station.get_node_or_null("AssistButton") == null, "%s without Assist has no button" % station.name, str(station.assist_button()))
		station.assist = true
		station.begin({"color": POTION_COLOR, "bottle": "round"})
		var button := station.assist_button()
		_check(button != null and button.text == entry[1] and button.accessibility_name == entry[1], "%s Assist button reads %s" % [station.name, entry[1]], "%s / %s" % [button.text, button.accessibility_name] if button != null else "no button")
		_check(not (station.get_node("Prompt") as Control).visible, "%s hides its gesture prompt in Assist" % station.name, "prompt visible")
		station.free()


## Criterion 7: the ghost ladle circles the surface at the asked tempo, plays one
## loop at GHOST_ALPHA, keeps looping faintly and fades out after the first touch.
## Assist shows no ghost.
func _test_stir_ghost_demo() -> void:
	var stir := _add_station(STIR_SCENE) as Stir
	var tempo := 0.8
	stir.begin({"color": POTION_COLOR, "tempo": tempo})
	var ghost := stir.ghost()
	_check(ghost.visible and is_equal_approx(ghost.modulate.a, Stir.GHOST_ALPHA), "ghost ladle shows at once", "visible %s alpha %.2f" % [ghost.visible, ghost.modulate.a])
	var loop_frames := roundi(1.0 / tempo / FRAME)
	var path_ok := true
	for i in floori(loop_frames / 2.0):
		stir.advance(FRAME)
		var expected := Stir.CENTRE + Vector2.from_angle(Stir.GHOST_START_ANGLE + (i + 1) * FRAME * tempo * TAU) * Stir.SURFACE_RADII
		path_ok = path_ok and ghost.position.distance_to(expected) < 0.01
	_check(path_ok and is_equal_approx(ghost.modulate.a, Stir.GHOST_ALPHA), "ghost circles the surface at the tempo during its first loop", "at %s alpha %.2f" % [ghost.position, ghost.modulate.a])
	for i in loop_frames:
		stir.advance(FRAME)
	_check(is_equal_approx(ghost.modulate.a, Stir.GHOST_FAINT_ALPHA), "ghost keeps looping faintly after one loop", "alpha %.2f" % ghost.modulate.a)
	for i in 600:
		stir.advance(FRAME)
	_check(ghost.visible and is_equal_approx(ghost.modulate.a, Stir.GHOST_FAINT_ALPHA), "ghost still loops without a touch", "alpha %.2f" % ghost.modulate.a)
	stir.feed(_touch(Stir.CENTRE + Vector2(Stir.RING_RADIUS, 0), true))
	for i in ceili(Stir.GHOST_FADE_TIME / FRAME) + 1:
		stir.advance(FRAME)
	_check(is_zero_approx(ghost.modulate.a) and stir.rotation_scores().is_empty(), "ghost fades out after the first touch", "alpha %.2f" % ghost.modulate.a)
	stir.free()
	var assisted := _add_station(STIR_SCENE) as Stir
	assisted.assist = true
	assisted.begin({"color": POTION_COLOR})
	_check(not assisted.ghost().visible, "Assist shows no ghost ladle", "visible")
	assisted.free()


## Criterion 8: the shop picks each pour's line with its own RNG: over many brews
## every line is 45%..85% of the bottle's liquid height on a whole mask row, the
## lines vary, a seed repeats them, and Pour keeps an explicit line exactly.
func _test_shop_pour_line_random() -> void:
	var shop := await _open_shop()
	for shape in Pour.BOTTLES:
		var rows := Pour.bottle_rows(shape)
		var height := rows.y - rows.x
		shop._rng.seed = 7
		var lines: Array[float] = []
		var problems := PackedStringArray()
		for i in 300:
			var line := shop.pour_line(shape)
			lines.append(line)
			if line < 0.45 or line > 0.85 or not is_equal_approx(line * height, roundf(line * height)):
				problems.append("%.4f" % line)
		var distinct := {}
		for line in lines:
			distinct[line] = true
		_check(problems.is_empty(), "pour %s lines are in range on whole rows" % shape, ", ".join(problems))
		_check(distinct.size() >= 5, "pour %s lines vary" % shape, "%d distinct" % distinct.size())
		shop._rng.seed = 7
		_check(is_equal_approx(shop.pour_line(shape), lines[0]), "pour %s lines repeat for a seed" % shape, "")
		var pour := _add_station(POUR_SCENE) as Pour
		pour.begin({"color": POTION_COLOR, "bottle": shape, "line": lines[1]})
		_check(is_equal_approx(pour.target_line(), lines[1]) and pour.liquid_rows() == rows, "pour %s keeps the shop's line" % shape, "%.4f vs %.4f" % [pour.target_line(), lines[1]])
		pour.free()
	if await _wait_for_order(shop, "pour line"):
		var params := shop._station_params("pour")
		var line := float(params.get("line", -1.0))
		_check(line >= 0.45 and line <= 0.85, "the shop passes its pour line to the station", str(params))
	await _close_shop()


## Criterion 9: in every request, each hint word (SCHEMA form rule, case-insensitive
## word prefix) gets its essence's icon and colour, nothing else is marked, and the
## bubble with its icons stays inside the stage. Lines without hints mark nothing.
func _test_bubble_marks_hint_words() -> void:
	var bubble := SPEECH_BUBBLE_SCENE.instantiate() as SpeechBubble
	root.add_child(bubble)
	var box := bubble.get_node("Box") as Control
	var text := bubble.get_node("Box/Text") as RichTextLabel
	var problems := PackedStringArray()
	for request in Content.requests():
		bubble.say(request.text, Customer.COUNTER_X + Customer.CENTER_X, -1.0, request.hints)
		var expected: Array[Dictionary] = []
		for id in request.hints:
			var word := Content.hint_word(id)
			for form in word.forms:
				for hit in RegEx.create_from_string("(?i)\\b%s[a-z]*" % form).search_all(request.text):
					expected.append({"at": hit.get_start(), "word": hit.get_string(), "essence": word.essence})
		expected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
		var marks := bubble.marks()
		var got := marks.map(func(mark: Dictionary) -> String: return "%s:%d" % [mark["word"], mark["essence"]])
		var want := expected.map(func(mark: Dictionary) -> String: return "%s:%d" % [mark["word"], mark["essence"]])
		if got != want or expected.is_empty():
			problems.append("%s marks %s, expected %s" % [request.id, got, want])
		# Each mark's icon is an inline image, one character of its own besides the text.
		var plain := "\n".join(Content.wrap_bubble(request.text)).length()
		if text.get_total_character_count() != plain + marks.size():
			problems.append("%s: %d characters, expected %d text + %d icons" % [request.id, text.get_total_character_count(), plain, marks.size()])
		var rect := Rect2(box.position, box.size)
		if rect.position.x < 0.0 or rect.end.x > Shop.STAGE_SIZE.x or rect.position.y < 0.0:
			problems.append("%s: box %s leaves the stage" % [request.id, rect])
		for line in Content.wrap_bubble(request.text):
			if bubble.line_width(line, request.hints) > box.size.x - 2.0 * SpeechBubble.PADDING.x:
				problems.append("%s: '%s' is wider than its box" % [request.id, line])
	_check(problems.is_empty(), "every request marks its hint words with icon and colour and fits", "\n".join(problems))
	var reaction: String = Content.archetypes()[0].reactions["perfect"][0]
	bubble.say(reaction, 135.0)
	_check(bubble.marks().is_empty(), "lines said without hints mark nothing", str(bubble.marks()))
	bubble.free()


## Criterion 10: every shelf item shows one essence icon per point of its essence,
## in essence order, 9x9 at 1x, under its sprite and inside the item, with the
## stock count readable above the sprite.
func _test_shop_shelf_essence_pips() -> void:
	var shop := await _open_shop()
	for id: String in shop.stock:
		var item := shop.shelf_item(id)
		var icon := (item.get_node("Icon") as Control).get_global_rect()
		var count := item.get_node("Count") as Label
		var expected := PackedStringArray()
		for k in Content.ESSENCES.size():
			for i in item.ingredient.essence[k]:
				expected.append("essence_" + Content.ESSENCES[k])
		var got := PackedStringArray()
		var placed := true
		for pip: TextureRect in item.get_node("Essences").get_children():
			var region := (pip.texture as AtlasTexture).region
			for k in Content.ESSENCES.size():
				if region == Art.texture("ui", "essence_" + Content.ESSENCES[k]).region:
					got.append("essence_" + Content.ESSENCES[k])
			var at := pip.get_global_rect()
			placed = placed and at.size == Vector2(9, 9) and at.position.y >= icon.end.y - 1.0 and item.get_global_rect().encloses(at)
		_check(got == expected and placed, "%s shows its essence pips under its sprite" % id, "%s, expected %s, placed %s" % [got, expected, placed])
		var count_rect := count.get_global_rect()
		_check(count.visible and count.text == "x%d" % shop.stock[id] and count_rect.end.y <= icon.position.y + 1.0 and item.get_global_rect().encloses(count_rect), "%s stock count shows above its sprite" % id, "%s at %s" % [count.text, count_rect])
		_check(item.essence_text() in item.accessibility_name, "%s names its essences" % id, item.accessibility_name)
	await _close_shop()


## Criterion 11: the pot preview shows the pot's amounts alone with no order, then
## "in pot/needed" per essence with a matched/missing/over mark, updated on every
## add and remove; each mark has its own shape (pixels), not just its own colour.
func _test_shop_pot_preview_needs() -> void:
	var shop := await _open_shop()
	await _check_preview(shop, Vector4i.ZERO, "preview without an order")
	if await _wait_for_order(shop, "preview"):
		await _check_preview(shop, Vector4i.ZERO, "preview of an empty pot")
		var recipe := _exact_recipe(shop.customer.potion, shop.stock)
		var mix := Vector4i.ZERO
		for id in recipe:
			await _tap(shop.shelf_item(id))
			mix += Content.ingredient(id).essence
			await _check_preview(shop, mix, "preview after adding %s" % id)
		var extra: String = shop.stock.keys().filter(func(id: String) -> bool: return shop.stock[id] > 0)[0]
		await _tap(shop.shelf_item(extra))
		await _check_preview(shop, mix + Content.ingredient(extra).essence, "preview over the order")
		await _tap(shop.slot_button(2))
		await _check_preview(shop, mix, "preview after removing")
	var shapes := {}
	for need: Shop.Need in [Shop.Need.MATCHED, Shop.Need.MISSING, Shop.Need.OVER]:
		shapes["".join(Shop.NEED_PIXELS[need])] = need
	_check(shapes.size() == 3, "matched, missing and over marks differ in shape", str(shapes))
	await _close_shop()


## Stirring in the shop with real touches through the viewport (Input.parse_input_event,
## as a phone delivers them) on a 390x844 phone at 3x: the first touch lands while the
## ghost demo still plays its first loop, and the circles must count 3 rotations; then
## again on a restarted stir once the demo has dropped to its faint loop.
func _test_shop_stir_real_touch() -> void:
	for wait_loops: float in [0.0, 1.5]:
		var label := "stir by touch after %.1f demo loops" % wait_loops
		var shop := await _open_shop()
		root.size = Vector2i(1170, 2532)
		await _frames(5)
		if await _wait_for_order(shop, label):
			for id in _exact_recipe(shop.customer.potion, shop.stock):
				await _tap(shop.shelf_item(id))
			await _tap(shop.brew_button())
			if await _until(func() -> bool: return shop.station is Stir and shop.station.is_running(), FLOW_FRAMES):
				var stir := shop.station as Stir
				await _frames(ceili(wait_loops / Stir.DEFAULT_TEMPO / FRAME))
				var centre := stir.get_global_transform() * Stir.CENTRE
				var screen := root.get_final_transform()
				var touch := InputEventScreenTouch.new()
				touch.position = screen * (centre + Vector2(Stir.RING_RADIUS, 0))
				touch.pressed = true
				Input.parse_input_event(touch)
				await process_frame
				for i in range(1, ceili((Stir.ROTATIONS + 0.3) / Stir.DEFAULT_TEMPO / FRAME) + 1):
					if not stir.is_running():
						break
					var drag := InputEventScreenDrag.new()
					drag.position = screen * (centre + Vector2.from_angle(i * FRAME * Stir.DEFAULT_TEMPO * TAU) * Stir.RING_RADIUS)
					Input.parse_input_event(drag)
					await process_frame
				var release := InputEventScreenTouch.new()
				release.position = touch.position
				Input.parse_input_event(release)
				await process_frame
				_check(stir.rotation_scores().size() == Stir.ROTATIONS, label + ": 3 rotations recognised", str(stir.rotation_scores()))
			else:
				_check(false, label + ": stir runs", "no stir")
		root.size = BASE_WINDOW
		await process_frame
		await _close_shop()


## Day 1 with Assist on: the exact recipe (Good), a recipe 2 away (Meh) and one
## 3+ away (Misbrew) each get their stamp (words, colour, icon) in the reading
## zone clear of the bubble, with "+pay" (Economy.pay) flying to the coins; the
## Misbrew pays nothing and shows no "+". (Perfect: _test_shop_perfect_serve_reaction;
## storming off shows none: _test_shop_patience_timeout.)
func _test_shop_grade_stamps() -> void:
	_game.assist_mode = true
	var shop := await _open_shop()
	for case: Array in [[Brew.Grade.GOOD, 0, 0], [Brew.Grade.MEH, 2, 2], [Brew.Grade.MISBREW, 3, 99]]:
		var grade: Brew.Grade = case[0]
		var label := "stamp %s" % Brew.Grade.keys()[grade]
		if not await _wait_for_order(shop, label):
			break
		var wants := shop.customer.potion
		if not await _serve(shop, _recipe_between(wants, shop.stock, case[1], case[2]), label):
			break
		_check(shop.grades.back() == grade, label + ": served at that grade", str(shop.grades))
		await _check_stamp(shop, grade, Economy.pay(wants.price, grade), label)
		await _skip_lines(shop)
	await _close_shop()


## The waiting customer's patience row: the hourglass first, then the 4 hearts;
## hidden once the potion arrives and when the customer storms off. The mood
## shows on the face only (no emote node).
func _test_shop_patience_row() -> void:
	_game.assist_mode = true
	var shop := await _open_shop()
	if await _wait_for_order(shop, "patience row"):
		var visitor := shop.customer
		var row := visitor.get_node("Patience") as Node2D
		var parts := row.get_children()
		var hourglass := parts[0] as Sprite2D
		var hearts_after := parts.slice(1).all(func(heart: Node) -> bool: return heart.name.begins_with("Heart") and (heart as Sprite2D).position.x > hourglass.position.x + 8.0)
		_check(row.is_visible_in_tree() and hourglass.name == "Hourglass" and (hourglass.texture as AtlasTexture).region == Art.texture("ui", "hourglass").region and parts.size() == 5 and hearts_after, "patience row: hourglass, then 4 hearts, while waiting", str(parts))
		var stray := visitor.find_children("*", "Sprite2D", true, false).filter(func(sprite: Node) -> bool: return sprite.get_parent() != row and sprite.get_parent().name != "Body")
		_check(visitor.get_node_or_null("Emote") == null and stray.is_empty(), "no mood emote on the customer (only body parts and the patience row)", str(stray))
		await _serve(shop, _exact_recipe(visitor.potion, shop.stock), "patience row")
		_check(not row.is_visible_in_tree(), "patience row hides once the potion arrives", "visible")
		await _skip_lines(shop)
	if await _wait_for_order(shop, "patience row storm"):
		var row := shop.customer.get_node("Patience") as Node2D
		_check(row.is_visible_in_tree(), "patience row shows for the next customer", "hidden")
		shop.customer.patience_left = 0.2
		_check(await _until(func() -> bool: return shop.stormed_off == 1, FLOW_FRAMES), "patience row storm: storms off", str(shop.stormed_off))
		_check(not row.is_visible_in_tree(), "patience row hides when the customer storms off", "visible")
	await _close_shop()


## Day 2's first customer wants a Mortar potion (shipped content); the test adds a
## Bellows step to it (Bellows ships in step 7). The shop runs Mortar (with the
## brew's grind ingredient in the bowl), Bellows, Stir and Pour in order, each
## driven by touches at the right speed, and the customer gets a Perfect potion.
func _test_shop_mortar_and_bellows() -> void:
	_game.goto(GameState.Flow.SHOP, {"day": 2})
	await _game.transition_finished
	var shop := current_scene as Shop
	if await _wait_for_order(shop, "day 2 mortar"):
		var wants := shop.customer.potion
		_check("mortar" in wants.steps, "day 2 customer 1 needs the mortar", str(wants.steps))
		var shipped := wants.steps
		wants.steps = PackedStringArray(["mortar", "bellows", "stir", "pour"])
		shop.customer.patience_left = 999.0
		for item in Content.ingredients_unlocked_by(2):
			shop.stock[item.id] = 2
			shop.shelf_item(item.id).set_stock(2)
		var recipe := _exact_recipe(wants, shop.stock)
		for id in recipe:
			await _tap(shop.shelf_item(id))
		await _tap(shop.brew_button())
		var order: Array[String] = []
		for step in wants.steps:
			if not await _until(func() -> bool: return shop.station != null and shop.station.is_running() and not (str(shop.station.name) in order), FLOW_FRAMES):
				_check(false, "day 2 %s station runs" % step, "no station")
				break
			var station := shop.station
			order.append(str(station.name))
			if station is Mortar:
				var pieces := station.get_node("Bowl/Pieces").get_children()
				_check(pieces.size() == recipe.filter(func(id: String) -> bool: return Content.ingredient(id).grind).size() and pieces.size() > 0, "mortar shows the brew's grind ingredients", str(pieces.size()))
				await _drive_circles(station, Mortar.CENTRE, Mortar.RING_RADIUS, Mortar.DEFAULT_SPEED)
			elif station is Bellows:
				var bellows := station as Bellows
				while bellows.is_running():
					if bellows.heat < BELLOWS_KEEP:
						bellows.feed(_touch(POUR_HOLD_POINT, true))
						bellows.feed(_touch(POUR_HOLD_POINT, false))
					await process_frame
			elif station is Stir:
				await _drive_circles(station, Stir.CENTRE, Stir.RING_RADIUS, Stir.DEFAULT_TEMPO)
			elif station is Pour:
				var pour := station as Pour
				pour.feed(_touch(POUR_HOLD_POINT, true))
				while pour.is_running() and pour.fill + FRAME / Pour.FILL_TIME / 2.0 < pour.target_line():
					await process_frame
				pour.feed(_touch(POUR_HOLD_POINT, false))
		_check(order == ["Mortar", "Bellows", "Stir", "Pour"], "day 2 runs the potion's steps in order", str(order))
		_check(await _until(func() -> bool: return shop.served == 1, FLOW_FRAMES), "day 2 customer served", str(shop.served))
		_check(shop.grades == ([Brew.Grade.PERFECT] as Array[Brew.Grade]), "mortar and bellows by touch give a Perfect potion", str(shop.grades))
		wants.steps = shipped
	await _close_shop()


## The grade stamp right after a serve: `grade`'s words, colour and icon; "+pay"
## flying in Fx (none when `pay` is 0); once landed, in the stage's reading zone
## (above the workspace) and clear of the speech bubble.
func _check_stamp(shop: Shop, grade: Brew.Grade, pay: int, label: String) -> void:
	var stamp := shop.get_node("Column/Stage/Stamp") as Control
	var text := shop.get_node("Column/Stage/Stamp/Row/Text") as Label
	var icon := (shop.get_node("Column/Stage/Stamp/Row/Icon") as TextureRect).texture as AtlasTexture
	var expected_icon := Art.texture("ui", Shop.STAMP_ICONS[grade])
	_check(stamp.visible and text.text == Shop.STAMP_TEXTS[grade] and icon != null and icon.region == expected_icon.region and text.get_theme_color(&"font_color") == Shop.STAMP_COLORS[grade], label + ": stamp reads %s with its icon and colour" % Shop.STAMP_TEXTS[grade], "visible %s '%s' %s" % [stamp.visible, text.text, icon.region if icon != null else Rect2()])
	var expected_pay := PackedStringArray(["+%d" % pay]) if pay > 0 else PackedStringArray()
	_check(_pay_texts(shop) == expected_pay, label + ": coins fly as %s" % expected_pay, str(_pay_texts(shop)))
	await _frames(25)
	var rect := stamp.get_global_rect()
	var bubble := (shop.get_node("Column/Stage/Bubble/Box") as Control).get_global_rect()
	var workspace_top := (shop.get_node("Column/Stage") as Control).get_global_rect().position.y + 192.0
	_check(stamp.visible and rect.end.y <= workspace_top and not rect.intersects(bubble), label + ": stamp held in the reading zone, clear of the bubble", "%s, bubble %s, workspace at %.0f" % [rect, bubble, workspace_top])


## Texts of the "+pay" labels flying in the shop's Fx layer.
func _pay_texts(shop: Shop) -> PackedStringArray:
	var texts := PackedStringArray()
	for node in shop.get_node("Fx").get_children():
		if node is Label and (node as Label).text.begins_with("+"):
			texts.append((node as Label).text)
	return texts


func _open_shop() -> Shop:
	_game.goto(GameState.Flow.SHOP)
	await _game.transition_finished
	return current_scene as Shop


func _close_shop() -> void:
	paused = false
	_game.assist_mode = false
	_game.gentle_mode = false
	_game.goto(GameState.Flow.TITLE)
	await _game.transition_finished


func _wait_for_order(shop: Shop, label: String) -> bool:
	var waiting := await _until(func() -> bool: return shop.customer != null and shop.customer.state == Customer.State.WAIT_ORDER, FLOW_FRAMES)
	_check(waiting, label + ": a customer waits for an order", "no customer waiting")
	return waiting


## Serves the waiting customer `recipe` with Assist on: taps each ingredient,
## Brew, then each station's Assist button, and waits until the customer is served.
func _serve(shop: Shop, recipe: Array[String], label: String) -> bool:
	if not await _wait_for_order(shop, label):
		return false
	for id in recipe:
		await _tap(shop.shelf_item(id))
	_check(shop.pot.size() == recipe.size() and not shop.brew_button().disabled, label + ": Brew enabled", "pot %d" % shop.pot.size())
	var served := shop.served
	var steps := shop.customer.potion.steps
	await _tap(shop.brew_button())
	for step in steps:
		var ready := await _until(func() -> bool: return shop.station != null and shop.station.is_running() and shop.station.get_node_or_null("AssistButton") != null, FLOW_FRAMES)
		_check(ready, "%s: %s station shows Assist" % [label, step], "no station")
		if not ready:
			return false
		await _tap(shop.station.get_node("AssistButton") as Button)
	var done := await _until(func() -> bool: return shop.served == served + 1, FLOW_FRAMES)
	_check(done, label + ": served", "served %d" % shop.served)
	return done


## Taps the workspace until the current customer leaves (skipping the reaction lines).
func _skip_lines(shop: Shop) -> void:
	var skip := shop.get_node("Column/Stage/SkipButton") as Button
	var leaving := shop.customer
	for i in 12:
		if leaving == null or leaving.state == Customer.State.LEAVE or leaving.state == Customer.State.GONE:
			return
		await _tap(skip)
		for frame in 10:
			await process_frame


## Two ingredient ids from `stock` whose brew hits `potion` exactly.
func _exact_recipe(potion: PotionType, stock: Dictionary[String, int]) -> Array[String]:
	return _recipe_between(potion, stock, 0, 0)


## Two ingredient ids from `stock` whose brew is `low`..`high` away from `potion`,
## else three.
func _recipe_between(potion: PotionType, stock: Dictionary[String, int], low: int, high := 99) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(stock.keys())
	for a in ids:
		for b in ids:
			if stock[a] < 1 or stock[b] < 1 or (a == b and stock[a] < 2):
				continue
			var distance := Brew.distance(Content.ingredient(a).essence + Content.ingredient(b).essence, potion.target)
			if distance >= low and distance <= high:
				return [a, b] as Array[String]
	for a in ids:
		for b in ids:
			for c in ids:
				var recipe: Array[String] = [a, b, c]
				if recipe.any(func(id: String) -> bool: return recipe.count(id) > stock[id]):
					continue
				var distance := Brew.distance(Content.ingredient(a).essence + Content.ingredient(b).essence + Content.ingredient(c).essence, potion.target)
				if distance >= low and distance <= high:
					return recipe
	_check(false, "recipe for %s at distance %d..%d" % [potion.id, low, high], "none in %s" % stock)
	return [] as Array[String]


func _until(condition: Callable, frames: int) -> bool:
	for i in frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()


## A real touch (press and release) at the centre of `control`.
func _tap(control: Control) -> void:
	await _tap_at(control.get_global_rect().get_center())


## A real touch (press and release) at canvas point `point`.
func _tap_at(point: Vector2) -> void:
	var at := root.get_final_transform() * point
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame


## Presses and releases key `keycode`, as a keyboard would.
func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


## Presses and releases input action `action`, as a key bound to it would.
func _action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


## Moves keyboard focus to `target` with ui_left/right/up/down, heading for it
## from the current focus owner. True when it got there.
func _focus_by_keys(target: Control) -> bool:
	for i in 12:
		var owner := root.gui_get_focus_owner()
		if owner == target:
			return true
		if owner == null:
			return false
		var to := target.get_global_rect().get_center() - owner.get_global_rect().get_center()
		if absf(to.y) > absf(to.x):
			await _action(&"ui_down" if to.y > 0.0 else &"ui_up")
		else:
			await _action(&"ui_right" if to.x > 0.0 else &"ui_left")
	return root.gui_get_focus_owner() == target


## Tabs forwards and back a few times; true if focus never leaves `container`.
func _focus_stays_in(container: Control) -> bool:
	for action: StringName in [&"ui_focus_next", &"ui_focus_next", &"ui_focus_next", &"ui_focus_next", &"ui_focus_next", &"ui_focus_prev", &"ui_focus_prev"]:
		await _action(action)
		var owner := root.gui_get_focus_owner()
		if owner == null or not container.is_ancestor_of(owner):
			return false
	return true


func _frames(count: int) -> void:
	for i in count:
		await process_frame


## The cauldron preview shows `mix`: each essence's "in pot/needed" against the
## waiting customer's order with its need mark (only the pot amounts and no mark
## without an order) at once, and the liquid tint after its tween.
func _check_preview(shop: Shop, mix: Vector4i, label: String) -> void:
	var ordered := shop.customer != null and shop.customer.state == Customer.State.WAIT_ORDER
	var counts := PackedStringArray()
	var expected := PackedStringArray()
	var expected_needs: Array[Shop.Need] = []
	var marks_shown: Array[bool] = []
	var expected_shown: Array[bool] = []
	for k in Content.ESSENCES.size():
		var group := shop.get_node("Column/Stage/Essences").get_child(k)
		counts.append((group.get_child(1) as Label).text)
		marks_shown.append((group.get_child(2) as Control).visible)
		if ordered:
			var needed := shop.customer.potion.target[k]
			expected.append("%d/%d" % [mix[k], needed])
			expected_needs.append(Shop.Need.MATCHED if mix[k] == needed else (Shop.Need.MISSING if mix[k] < needed else Shop.Need.OVER))
		else:
			expected.append(str(mix[k]))
			expected_needs.append(Shop.Need.NONE)
		expected_shown.append(expected_needs[k] != Shop.Need.NONE)
	_check(counts == expected, label + ": essence counts", "%s, expected %s" % [counts, expected])
	_check(shop.essence_needs == expected_needs and marks_shown == expected_shown, label + ": need marks", "%s shown %s, expected %s" % [shop.essence_needs, marks_shown, expected_needs])
	await _frames(30)
	var liquid := (shop.get_node("Column/Stage/Cauldron/Liquid") as Sprite2D).modulate
	var color := shop._mix_color(mix)
	_check(liquid.is_equal_approx(color), label + ": liquid colour", "%s, expected %s" % [liquid, color])


## Each of `controls` is at least MIN_TARGET square, inside the safe area and,
## except `top_exception`, in the thumb zone.
func _check_targets(controls: Array[Control], top_exception: Control, label: String) -> void:
	var visible := _game.visible_rect()
	var safe := _game.safe_rect()
	for control in controls:
		var rect := control.get_global_rect()
		var which := "%s %s" % [label, control.name]
		_check(rect.size.x >= MIN_TARGET and rect.size.y >= MIN_TARGET, which + " size", str(rect.size))
		_check(safe.encloses(rect), which + " inside safe area", "%s not in %s" % [rect, safe])
		if control != top_exception:
			_check(rect.position.y >= visible.position.y + visible.size.y * THUMB_ZONE_TOP, which + " in thumb zone", "%s in %s" % [rect, visible])


## A real touch dragged from `from` to `to` (canvas coordinates) in 8 steps.
func _drag_touch(from: Vector2, to: Vector2) -> void:
	var screen := root.get_final_transform()
	var touch := InputEventScreenTouch.new()
	touch.position = screen * from
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	for i in range(1, 9):
		var drag := InputEventScreenDrag.new()
		drag.position = screen * from.lerp(to, i / 8.0)
		Input.parse_input_event(drag)
		await process_frame
	var release := InputEventScreenTouch.new()
	release.position = screen * to
	Input.parse_input_event(release)
	await process_frame


func _add_station(scene: PackedScene) -> Station:
	var station := scene.instantiate() as Station
	root.add_child(station)
	return station


func _collect_finished(station: Station) -> Array[float]:
	var results: Array[float] = []
	station.finished.connect(func(quality: float) -> void: results.append(quality))
	return results


## Drags `rotations` clockwise circles around the stir centre at `rps`, one event
## per FRAME, the radius wobbling by up to `wobble` around RING_RADIUS.
func _stir_circles(stir: Stir, rps: float, rotations: int, wobble: float) -> void:
	var start := Stir.CENTRE + Vector2(Stir.RING_RADIUS, 0)
	stir.feed(_touch(start, true))
	var frames := ceili(rotations / rps / FRAME) + 2
	for i in range(1, frames + 1):
		stir.advance(FRAME)
		var radius := Stir.RING_RADIUS + wobble * sin(i * 0.9)
		stir.feed(_drag(Stir.CENTRE + Vector2.from_angle(i * FRAME * rps * TAU) * radius))
	stir.feed(_touch(start, false))


## Drags `turns` clockwise circles around `centre` at `tps` turns per second, one
## event per FRAME, the radius wobbling by up to `wobble` around `radius`.
func _circles(station: Station, centre: Vector2, radius: float, tps: float, turns: int, wobble: float) -> void:
	var start := centre + Vector2(radius, 0)
	station.feed(_touch(start, true))
	var frames := ceili(turns / tps / FRAME) + 2
	for i in range(1, frames + 1):
		station.advance(FRAME)
		station.feed(_drag(centre + Vector2.from_angle(i * FRAME * tps * TAU) * (radius + wobble * sin(i * 0.9))))
	station.feed(_touch(start, false))


## Drags circles around `centre` at `tps` through the running game loop (one drag
## per rendered frame; the station's _process moves its clock) until it finishes.
func _drive_circles(station: Station, centre: Vector2, radius: float, tps: float) -> void:
	var start := centre + Vector2(radius, 0)
	station.feed(_touch(start, true))
	var i := 0
	while station.is_running() and i < FLOW_FRAMES:
		await process_frame
		i += 1
		station.feed(_drag(centre + Vector2.from_angle(i * FRAME * tps * TAU) * radius))
	station.feed(_touch(start, false))


## Runs `bellows` frame by frame, tapping whenever `pump(frame)` says so, until it
## finishes (or 20 s pass). Returns the frames run.
func _pump_bellows(bellows: Bellows, pump: Callable) -> int:
	var frame := 0
	while bellows.is_running() and frame < 1200:
		if pump.call(frame):
			bellows.feed(_touch(POUR_HOLD_POINT, true))
			bellows.feed(_touch(POUR_HOLD_POINT, false))
		bellows.advance(FRAME)
		frame += 1
	return frame


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
