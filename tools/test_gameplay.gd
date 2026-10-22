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
## Every synthetic touch uses this index: a web build's index is the browser's
## Touch.identifier, which iOS Safari makes large and never 0 (playtest 2026-10-19).
const TOUCH_INDEX := 7
## Frames per Mortar scrub stroke in the tests (0.3 s).
const SCRUB_FRAMES := 18
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
const WATCHDOG_MSEC := 240000
## Game time runs this much faster during the story playthroughs (timers, tweens and
## walks; Assist stations do not depend on it), so seven days fit the watchdog.
const PLAYTHROUGH_TIME_SCALE := 4.0
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
		_test_finger_follows_pressing_touch,
		_test_stir_perfect,
		_test_stir_hold_then_stir,
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
		_test_mortar_lift_ends_stroke,
		_test_mortar_ghost_demo,
		_test_bellows_perfect,
		_test_bellows_sloppy,
		_test_bellows_idle,
		_test_bellows_gentle,
		_test_stations_assist_tap,
		_test_stations_assist_ui_accept,
		_test_economy_rules,
		_test_economy_day_loop_rules,
		_test_shift_configs,
		_test_save_round_trip,
		_test_save_missing_and_corrupt,
		_test_save_migrations,
		_test_save_failed_write_keeps_save,
		_test_upgrade_tolerance,
		_test_shop_passes_station_tolerance,
		_test_difficulty_rules,
		_test_difficulty_shift,
		_test_finish_day_moves_difficulty,
		_test_market_purchases,
		_test_title_continue_and_new_game,
		_test_morning_missing_day_returns_to_title,
		_test_loop_screens_size_and_zone,
		_test_morning_menu,
		_test_shop_day1_assist,
		_test_shop_last_day_storm_off,
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
		_test_look_palette_and_count,
		_test_look_distinct_per_shift,
		_test_shop_customer_look,
		_test_shop_queue,
		_test_shop_queue_double_storm,
		_test_shop_difficulty_inputs,
		_test_shop_refuse,
		_test_shop_refuse_ends_day,
		_test_bubble_blips,
		_test_audio_and_voices,
		_test_sfx_catalog_and_throttle,
		_test_music_tracks,
		_test_shop_sounds,
		_test_volume_settings,
		_test_settings_panels_layout,
		_test_sound_toggles,
		_test_shop_mortar_and_bellows,
		_test_shop_shelf_fits_without_pages,
		_test_shop_shelf_pages,
		_test_shop_shelf_pages_keyboard,
		_test_story_rules,
		_test_shop_story_beats,
		_test_codex_records,
		_test_codex_panel,
		_test_save_v1_without_story_loads,
		_test_story_ending_rule,
		_test_ending_scene,
		_test_story_playthrough_helpful,
		_test_story_playthrough_refusing,
		_test_rush_rules,
		_test_shop_rush_run,
		_test_rush_screens,
		_test_rush_keyboard_assist,
		_test_stat_tile_fits,
		_test_summary_tally,
		_test_results_tally,
		_test_results_screens_layout,
		_test_splash_auto_advance,
		_test_splash_skips,
		_test_title_hero_layout,
		_test_title_credits,
		_test_transition_wipe,
		_test_hit_stop,
		_test_button_press_squash,
		_test_pour_sound_pause,
	]


func _run() -> void:
	root.size = BASE_WINDOW
	_check(_game.save_path == GameState.TOOL_SAVE_PATH, "tool runs use the tool save, never the player's", _game.save_path)
	_delete_saves()
	_game.load_game()
	await process_frame
	for test in _tests():
		await test.call()
	_delete_saves()
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
	var wipe := _game.get_node("Fade/Wipe") as ColorRect
	_check(is_zero_approx(_game.wipe_progress()) and not wipe.visible and wipe.mouse_filter == Control.MOUSE_FILTER_IGNORE, "goto's swirl wipe reopens and lets touches through", "progress %.2f, visible %s" % [_game.wipe_progress(), wipe.visible])


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


## A real touch (as the web build delivers it) on the title button (no saved story:
## "Open the shop") starts a new game and runs goto(MORNING). MORNING points at the
## title scene here so the test does not depend on the morning scene.
func _test_title_button_tap_goes_to_shop() -> void:
	var real_path: String = _game.scene_paths[GameState.Flow.MORNING]
	_game.scene_paths[GameState.Flow.MORNING] = TITLE_PATH
	var title := current_scene as Title
	var button := title.get_node("Column/OpenShopButton") as Button
	var screen_point := root.get_final_transform() * button.get_global_rect().get_center()
	var logged := _game.transition_log.size()
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = TOUCH_INDEX
		touch.position = screen_point
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame
	if _game.is_transitioning():
		await _game.transition_finished
	_game.scene_paths[GameState.Flow.MORNING] = real_path
	_check(_game.transition_log.size() == logged + 1 and _game.transition_log.back().begins_with("TITLE -> MORNING"), "title tap goes to the morning", str(_game.transition_log.slice(logged)))
	_check(_game.state == GameState.Flow.MORNING and _game.day == 1 and _game.coins == Content.day(1).starting_coins, "title tap starts a new game on day 1", "%s day %d coins %d" % [_game.state, _game.day, _game.coins])
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


## Finger follows whichever touch pressed (iOS indices are never 0): its drags and
## release count, a second finger's do not, and a new press takes over (a lost
## release never locks a control).
func _test_finger_follows_pressing_touch() -> void:
	var finger := Finger.new()
	var other := InputEventScreenDrag.new()
	other.index = 3
	var first := _touch(Vector2.ZERO, true)
	_check(finger.follows(first) and finger.follows(_drag(Vector2.ONE)), "finger follows its own press and drag", "ignored index %d" % TOUCH_INDEX)
	_check(not finger.follows(other), "finger ignores another finger's drag", "followed index 3")
	var takeover := InputEventScreenTouch.new()
	takeover.index = 3
	takeover.pressed = true
	_check(finger.follows(takeover) and finger.follows(other), "a new press takes over", "kept index %d" % TOUCH_INDEX)
	_check(not finger.follows(_touch(Vector2.ZERO, false)) and not finger.follows(_drag(Vector2.ONE)), "the old finger's release and drag are ignored", "followed index %d" % TOUCH_INDEX)
	takeover.pressed = false
	_check(finger.follows(takeover) and not finger.follows(other), "release ends the follow", "still following index 3")


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


## Touching down and resting 1 s (with touch jitter) before stirring at the tempo
## does not slow the first rotation: every rotation scores Perfect.
func _test_stir_hold_then_stir() -> void:
	var stir := _add_station(STIR_SCENE) as Stir
	var results := _collect_finished(stir)
	stir.begin({"color": POTION_COLOR, "tempo": 0.8})
	stir.feed(_touch(Stir.CENTRE + Vector2(Stir.RING_RADIUS, 0), true))
	for i in 60:
		stir.advance(FRAME)
		stir.feed(_drag(Stir.CENTRE + Vector2.from_angle(0.02 * sin(i * 1.3)) * Stir.RING_RADIUS))
	var frames := ceili(Stir.ROTATIONS / 0.8 / FRAME) + 2
	for i in range(1, frames + 1):
		stir.advance(FRAME)
		stir.feed(_drag(Stir.CENTRE + Vector2.from_angle(i * FRAME * 0.8 * TAU) * Stir.RING_RADIUS))
	var scores := stir.rotation_scores()
	_check(results.size() == 1 and scores.size() == Stir.ROTATIONS and scores.all(func(score: float) -> bool: return score >= Station.PERFECT_QUALITY), "stir: resting before the first circle does not count against it", str(scores))
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


## Scrubbing mark to mark grinds to full fineness and scores Perfect; a cue per
## stroke; the brew's grind ingredients sit in the bowl.
func _test_mortar_perfect() -> void:
	var mortar := _add_station(MORTAR_SCENE) as Mortar
	var results := _collect_finished(mortar)
	var cues: Array[StringName] = []
	mortar.feedback.connect(func(kind: StringName) -> void: cues.append(kind))
	mortar.begin({"color": POTION_COLOR, "ingredients": ["moonmoss"]})
	_check(mortar.get_node("Bowl/Pieces").get_child_count() == 1, "mortar shows its ingredient in the bowl", str(mortar.get_node("Bowl/Pieces").get_child_count()))
	_scrub(mortar, Mortar.MARK_X, Mortar.STROKES)
	_check(results.size() == 1, "mortar perfect finishes once", str(results))
	_check(not results.is_empty() and results[0] >= Station.PERFECT_QUALITY, "mortar perfect quality", str(results))
	_check(cues.count(&"mortar_stroke") == Mortar.STROKES and cues.back() == &"station_success", "mortar feedback every stroke", str(cues))
	_check(is_equal_approx(mortar.fineness, 1.0) and mortar.stroke_scores().size() == Mortar.STROKES, "mortar ground to full fineness", "%.2f %s" % [mortar.fineness, mortar.stroke_scores()])
	_check(not mortar.is_running(), "mortar stops after finishing", "still running")
	mortar.free()


## Turning well short of the marks, or well past them, scores below Good.
func _test_mortar_sloppy() -> void:
	for reach: float in [Mortar.MARK_X - 20.0, Mortar.MARK_X + 20.0]:
		var mortar := _add_station(MORTAR_SCENE) as Mortar
		var results := _collect_finished(mortar)
		mortar.begin({"color": POTION_COLOR})
		_scrub(mortar, reach, Mortar.STROKES)
		_check(results.size() == 1 and results[0] < Station.ASSIST_QUALITY, "mortar turning %+.0f from the marks scores below Good" % (reach - Mortar.MARK_X), str(results))
		mortar.free()


## No touches never finish; small back-and-forth wiggles (shorter than MIN_STROKE)
## grind nothing.
func _test_mortar_idle_and_wiggle() -> void:
	var mortar := _add_station(MORTAR_SCENE) as Mortar
	var results := _collect_finished(mortar)
	mortar.begin({"color": POTION_COLOR})
	for i in 1800:
		mortar.advance(FRAME)
	_check(results.is_empty() and mortar.is_running(), "mortar idle does not finish", str(results))
	mortar.feed(_touch(Vector2(Mortar.CENTRE.x, Mortar.RAIL_Y), true))
	for i in 600:
		mortar.advance(FRAME)
		mortar.feed(_drag(Vector2(Mortar.CENTRE.x + sin(i * 0.2) * Mortar.MIN_STROKE * 0.4, Mortar.RAIL_Y)))
	mortar.feed(_touch(Vector2(Mortar.CENTRE.x, Mortar.RAIL_Y), false))
	_check(results.is_empty() and mortar.stroke_scores().is_empty() and is_zero_approx(mortar.fineness), "mortar wiggle counts no stroke", "%s %.2f" % [mortar.stroke_scores(), mortar.fineness])
	mortar.free()


## Lifting the finger ends the stroke where it turned: one mark-to-mark drag and
## a lift count one Perfect stroke.
func _test_mortar_lift_ends_stroke() -> void:
	var mortar := _add_station(MORTAR_SCENE) as Mortar
	mortar.begin({"color": POTION_COLOR})
	var left := Mortar.CENTRE.x - Mortar.MARK_X
	var right := Mortar.CENTRE.x + Mortar.MARK_X
	mortar.feed(_touch(Vector2(left, Mortar.RAIL_Y), true))
	for frame in range(1, SCRUB_FRAMES + 1):
		mortar.advance(FRAME)
		mortar.feed(_drag(Vector2(lerpf(left, right, float(frame) / SCRUB_FRAMES), Mortar.RAIL_Y)))
	_check(mortar.stroke_scores().is_empty(), "mortar: a stroke still under way has no score", str(mortar.stroke_scores()))
	mortar.feed(_touch(Vector2(right, Mortar.RAIL_Y), false))
	_check(mortar.stroke_scores() == ([1.0] as Array[float]), "mortar: lifting the finger ends the stroke at the mark", str(mortar.stroke_scores()))
	mortar.free()


## Turning 8 past the marks: not Perfect normally, Perfect with Gentle mode's wider window.
func _test_mortar_gentle() -> void:
	var qualities: Array[float] = []
	for scale: float in [1.0, GameState.GENTLE_TOLERANCE_SCALE]:
		var mortar := _add_station(MORTAR_SCENE) as Mortar
		var results := _collect_finished(mortar)
		mortar.tolerance_scale = scale
		mortar.begin({"color": POTION_COLOR})
		_scrub(mortar, Mortar.MARK_X + 8.0, Mortar.STROKES)
		qualities.append(results[0] if results.size() == 1 else -1.0)
		mortar.free()
	_check(qualities[0] >= 0.0 and qualities[0] < Station.PERFECT_QUALITY, "mortar 8 past the marks is not Perfect", str(qualities))
	_check(qualities[1] > qualities[0] and qualities[1] >= Station.PERFECT_QUALITY, "mortar Gentle widens the marks", str(qualities))


## The ghost pestle scrubs from mark to mark, fades after the first touch; Assist
## shows no ghost.
func _test_mortar_ghost_demo() -> void:
	var mortar := _add_station(MORTAR_SCENE) as Mortar
	mortar.begin({"color": POTION_COLOR})
	var ghost := mortar.ghost()
	var start := ghost.position
	for i in roundi(Mortar.GHOST_STROKE_TIME / FRAME):
		mortar.advance(FRAME)
	_check(ghost.visible and is_equal_approx(ghost.modulate.a, Mortar.GHOST_ALPHA), "mortar ghost demonstrates", str(ghost.modulate.a))
	_check(ghost.position.x - start.x > Mortar.SURFACE_RADII.x, "mortar ghost scrubs from one rim to the other", "%s -> %s" % [start, ghost.position])
	mortar.feed(_touch(Vector2(Mortar.CENTRE.x, Mortar.RAIL_Y), true))
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
			touch.index = TOUCH_INDEX
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


## The whole day loop by real taps, Assist on: the title's "Story mode" (new
## game) -> the morning of day 1 -> its "Open the shop" -> every day-1 customer gets
## the exact recipe (all Good, the Assist cap, paying Economy.pay plus Economy.tip)
## -> the summary scene with the day's numbers -> "To the market" -> a purchase
## -> "Next day" -> the morning of day 2 -> the day-2 shift starts with the stock
## carried over plus the purchase. The save holds each step.
func _test_shop_day1_assist() -> void:
	_game.assist_mode = true
	_game.goto(GameState.Flow.TITLE)
	await _game.transition_finished
	await _tap(current_scene.get_node("Column/OpenShopButton") as Button)
	await _until(func() -> bool: return _game.state == GameState.Flow.MORNING and not _game.is_transitioning(), FLOW_FRAMES)
	_check(current_scene is Morning and _game.day == 1, "loop: the title opens the morning of day 1", "%s day %d" % [current_scene, _game.day])
	var morning_text := (current_scene.get_node("Column/DayLabel") as Label).text + " " + (current_scene.get_node("Column/Card/Note") as Label).text
	_check(morning_text.begins_with("Day 1 of %d" % Content.days().size()) and Content.day(1).morning_note.get_slice(" ", 0) in morning_text, "loop: the morning shows day 1 and its note", morning_text)
	await _tap(current_scene.get_node("Column/OpenShopButton") as Button)
	await _until(func() -> bool: return _game.state == GameState.Flow.SHOP and not _game.is_transitioning(), FLOW_FRAMES)
	var shop := current_scene as Shop
	if shop == null:
		_check(false, "loop: the morning opens the shop", str(current_scene))
		return
	var day := Content.day(1)
	var expected_coins := day.starting_coins
	var expected_tips := 0
	_check(shop.coins == day.starting_coins and shop.stock == day.starting_stock and shop.shift.day == 1, "shop starts with the saved coins and stock", "%d %s" % [shop.coins, shop.stock])
	for n in day.customers.size():
		var label := "day 1 customer %d" % (n + 1)
		var wants := Content.potion(day.customers[n].potion)
		var tip := Economy.tip(wants.price, Brew.Grade.GOOD, Content.archetype(day.customers[n].archetype).tip_tendency)
		if not await _serve(shop, _exact_recipe(wants, shop.stock), label):
			break
		expected_coins += Economy.pay(wants.price, Brew.Grade.GOOD) + tip
		expected_tips += tip
		var bubble_text := (shop.get_node("Column/Stage/Bubble") as SpeechBubble).text
		_check(bubble_text in shop.customer.archetype.reactions["good"], label + ": says a good reaction line", bubble_text)
		await _skip_lines(shop)
	_check(shop.grades == ([Brew.Grade.GOOD, Brew.Grade.GOOD, Brew.Grade.GOOD] as Array[Brew.Grade]), "day 1 assist grades are all Good", str(shop.grades))
	_check(shop.served == 3 and shop.perfect == 0 and shop.stormed_off == 0, "day 1 counts", "%d %d %d" % [shop.served, shop.perfect, shop.stormed_off])
	_check(shop.coins == expected_coins and shop.tips == expected_tips and expected_tips > 0, "day 1 coins follow Economy.pay plus Economy.tip", "%d, expected %d (tips %d of %d)" % [shop.coins, expected_coins, shop.tips, expected_tips])
	var left := shop.stock.duplicate()
	_check(await _until(func() -> bool: return _game.state == GameState.Flow.SUMMARY and not _game.is_transitioning(), FLOW_FRAMES), "day 1 ends with the summary scene", str(_game.state))
	var result := _game.flow_args
	_check(result.get("served") == 3 and result.get("customers") == 3 and str(result.get("grades")) == "[0, 3, 0, 0]" and result.get("earned") == 27 and result.get("tips") == expected_tips and result.get("reputation") == 3 and result.get("stormed_off") == 0, "summary numbers", str(result))
	_check(_game.day == 2 and _game.at_market and _game.coins == expected_coins and _game.stock == left and _game.reputation == 3, "finish_day commits the day and opens the day-2 market", "day %d market %s coins %d rep %d stock %s" % [_game.day, _game.at_market, _game.coins, _game.reputation, _game.stock])
	var summary := current_scene as Summary
	await _until(func() -> bool: return not summary.is_tallying(), FLOW_FRAMES)
	var shown := _tile_texts(summary)
	_check(shown == ["3/3", "+27", "+%d" % expected_tips, "+3 now 3"] and _row_text(summary, "Counts/StormedOff") == "Stormed off: 0", "summary shows the day on its tiles", str(shown))
	_check(_grade_texts(summary) == PackedStringArray(["Perfect 0", "Good 3", "Meh 0", "Misbrew 0"]), "summary counts each grade with its icon", str(_grade_texts(summary)))
	var saved := _read_save()
	_check(saved.get("day") == 2.0 and saved.get("at_market") == true and saved.get("coins") == float(expected_coins), "the finished day is saved", str(saved))
	await _tap(summary.get_node("Column/Layout/ContinueButton") as Button)
	await _until(func() -> bool: return _game.state == GameState.Flow.MARKET and not _game.is_transitioning(), FLOW_FRAMES)
	var market := current_scene as Market
	if market == null:
		_check(false, "loop: the summary opens the market", str(current_scene))
		return
	var moonmoss := Content.ingredient("moonmoss")
	var price := Economy.market_price(Content.day(2), moonmoss)
	await _tap(market.stock_card("moonmoss"))
	_check(_game.stock["moonmoss"] == 1 and _game.coins == expected_coins - price, "loop: a market tap buys one moonmoss", "%s %d" % [_game.stock, _game.coins])
	await _tap(market.get_node("Column/Shop/NextDayButton") as Button)
	await _until(func() -> bool: return _game.state == GameState.Flow.MORNING and not _game.is_transitioning(), FLOW_FRAMES)
	_check(current_scene is Morning and (current_scene.get_node("Column/DayLabel") as Label).text == "Day 2 of %d" % Content.days().size() and not _game.at_market, "loop: next day opens the morning of day 2", str(current_scene))
	await _tap(current_scene.get_node("Column/OpenShopButton") as Button)
	await _until(func() -> bool: return _game.state == GameState.Flow.SHOP and not _game.is_transitioning(), FLOW_FRAMES)
	shop = current_scene as Shop
	var expected_stock := left.duplicate()
	expected_stock["honeycomb"] = 0
	expected_stock["moonmoss"] = 1
	_check(shop != null and shop.shift.day == 2 and shop.coins == expected_coins - price and shop.stock == expected_stock, "day 2 starts with the carried-over stock and the purchase", "%s %s" % [shop.stock if shop != null else {}, expected_stock])
	await _close_shop()


## The last story day, played with Assist: every customer but the last is served;
## the last one storms off with an exact recipe already in the pot. The day ends
## with those ingredients back in stock, the summary counts the storm-off and the
## day's reputation (below zero when it outweighs the serves), the story is over
## (no market, nothing to continue) and the summary leads to the ending.
func _test_shop_last_day_storm_off() -> void:
	var last := Content.days().size()
	_game.new_game()
	_game.endings = []
	_game.rush_hour_unlocked = false
	_game.assist_mode = true
	_game.day = last
	for item in Content.ingredients_unlocked_by(last):
		_game.stock[item.id] = 9
	_game.goto(GameState.Flow.SHOP, {"day": last})
	await _game.transition_finished
	var shop := current_scene as Shop
	if shop == null:
		_check(false, "last day: the shop opens", str(current_scene))
		return
	var count := shop.shift.customers.size()
	var expected_stock := shop.stock.duplicate()
	for n in count - 1:
		var label := "last day customer %d" % (n + 1)
		if not await _wait_for_order(shop, label):
			await _close_shop()
			return
		_refill_patience(shop)
		var recipe := _exact_recipe(shop.customer.potion, shop.stock)
		if not await _serve(shop, recipe, label):
			await _close_shop()
			return
		for id in recipe:
			expected_stock[id] -= 1
		await _skip_lines(shop)
	if not await _wait_for_order(shop, "last day last customer"):
		await _close_shop()
		return
	for id in _exact_recipe(shop.customer.potion, shop.stock):
		await _tap_item(shop, id)
	_check(shop.pot.size() == 2, "last day: the last order's ingredients are in the pot", str(shop.pot.size()))
	shop.customer.patience_left = 0.1
	_check(await _until(func() -> bool: return _game.state == GameState.Flow.SUMMARY and not _game.is_transitioning(), FLOW_FRAMES * 2), "last day: the day ends with the summary", str(_game.state))
	var result := _game.flow_args
	var reputation := (count - 1) * Economy.reputation_delta(Brew.Grade.GOOD) + Economy.STORMED_OFF_REPUTATION
	_check(result.get("served") == count - 1 and result.get("stormed_off") == 1 and result.get("reputation") == reputation, "last day: summary numbers count the storm-off", str(result))
	_check(_game.stock == expected_stock, "last day: the ingredients left in the pot are back in stock", "%s, expected %s" % [_game.stock, expected_stock])
	_check(_game.day == last + 1 and not _game.at_market and not _game.can_continue(), "last day: the story is over (no market, nothing to continue)", "day %d market %s" % [_game.day, _game.at_market])
	var summary := current_scene as Summary
	await _until(func() -> bool: return not summary.is_tallying(), FLOW_FRAMES)
	var money := "%s / %s" % [summary.tile("Reputation").number_text(), _row_text(summary, "Counts/StormedOff")]
	_check(money == "%+d / Stormed off: 1" % reputation, "last day: the summary shows the storm-off and the reputation change", money)
	var button := summary.get_node("Column/Layout/ContinueButton") as Button
	_check(button.text == "The ending", "last day: the summary leads to the ending", button.text)
	var recorded := _read_save()
	var reached := Story.ending(_game.flags, _game.reputation)
	_check(recorded.get("endings") == [reached] and recorded.get("rush_hour_unlocked") == true, "last day: the ending and the Rush Hour unlock are saved before the ending scene", str(recorded))
	await _tap(button)
	_check(await _until(func() -> bool: return _game.state == GameState.Flow.ENDING and not _game.is_transitioning(), FLOW_FRAMES), "last day: The ending opens the ending", str(_game.state))
	_check(_game.endings == ([reached] as Array[String]) and _game.rush_hour_unlocked, "last day: the ending is recorded once and Rush Hour unlocked", "%s %s" % [_game.endings, _game.rush_hour_unlocked])
	_game.assist_mode = false
	_game.new_game()


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
		_game.sfx_log.clear()
		await _serve(shop, recipe, "misbrew")
		_check(_heard(&"misbrew") and _heard(&"stamp_misbrew") and not _heard(&"coins"), "misbrew: the poof and the misbrew stamp sound, no coins", str(_game.sfx_log))
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
		_game.sfx_log.clear()
		shop.customer.patience_left = 0.2
		_check(await _until(func() -> bool: return shop.stormed_off == 1, FLOW_FRAMES), "patience timeout storms off", str(shop.stormed_off))
		_check(_heard(&"storm_off"), "storming off plays its sound", str(_game.sfx_log))
		var bubble := shop.get_node("Column/Stage/Bubble") as SpeechBubble
		_check(bubble.text in who.reactions["stormed_off"], "storming off says a stormed_off line", bubble.text)
		_check(shop.reputation == Economy.STORMED_OFF_REPUTATION and shop.coins == Content.day(1).starting_coins and shop.served == 0, "storming off costs reputation only", "%d %d" % [shop.reputation, shop.coins])
		_check(not (shop.get_node("Column/Stage/Stamp") as Control).visible and _pay_texts(shop).is_empty(), "storming off shows no grade stamp and no coins", str(_pay_texts(shop)))
		await _skip_lines(shop)
	if await _wait_for_order(shop, "timeout mid-brew"):
		var recipe := _exact_recipe(shop.customer.potion, shop.stock)
		var before := shop.stock.duplicate()
		for id in recipe:
			await _tap_item(shop, id)
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
		await _tap_item(shop, first)
		_check(shop.pot.size() == 1 and shop.stock[first] == count - 1 and shop.shelf_item(first).stock == count - 1, "tap adds to the pot", "%d %d" % [shop.pot.size(), shop.stock[first]])
		_check(shop.brew_button().disabled and not shop.slot_button(0).disabled, "one ingredient: slot filled, Brew disabled", "brew disabled %s" % shop.brew_button().disabled)
		await _check_preview(shop, Content.ingredient(first).essence, "preview after adding")
		await _tap(shop.slot_button(0))
		_check(shop.pot.is_empty() and shop.stock[first] == count, "slot tap restores the stock", "%d %d" % [shop.pot.size(), shop.stock[first]])
		await _check_preview(shop, Vector4i.ZERO, "preview after removing")
		for i in 4:
			await _tap_item(shop, ids[i])
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
		_check(paused and (shop.get_node("Modal/Panel") as Control).visible, "pause button pauses", "paused %s" % paused)
		var patience := shop.customer.patience_left
		for i in 30:
			await process_frame
		_check(is_equal_approx(shop.customer.patience_left, patience), "patience stops while paused", "%f -> %f" % [patience, shop.customer.patience_left])
		await _tap(shop.get_node("Modal/Panel/List/AssistRow/AssistButton") as Button)
		await _tap(shop.get_node("Modal/Panel/List/GentleRow/GentleButton") as Button)
		_check(_game.assist_mode and _game.gentle_mode, "pause toggles set the settings", "%s %s" % [_game.assist_mode, _game.gentle_mode])
		_check((shop.get_node("Column/Hud/AssistTag") as Control).visible, "HUD shows the Assist tag", "hidden")
		await _tap(shop.get_node("Modal/Panel/List/ResumeButton") as Button)
		_check(not paused, "resume unpauses", "still paused")
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			await _tap_item(shop, id)
		await _tap(shop.brew_button())
		_check(await _until(func() -> bool: return shop.station != null and shop.station.is_running(), FLOW_FRAMES), "brew starts a station", "no station")
		_check(shop.station.assist and is_equal_approx(shop.station.tolerance_scale, GameState.GENTLE_TOLERANCE_SCALE), "station gets the toggled settings", "%s %f" % [shop.station.assist, shop.station.tolerance_scale])
		await _tap(pause)
		await _tap(shop.get_node("Modal/Panel/List/AssistRow/AssistButton") as Button)
		await process_frame
		_check(not _game.assist_mode and not shop.station.assist and shop.station.get_node_or_null("AssistButton") == null and shop.station.is_running(), "assist off restarts the station as a gesture", "assist %s" % shop.station.assist)
		await _tap(shop.get_node("Modal/Panel/List/ResumeButton") as Button)
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
			await _tap_item(shop, id)
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
			await _tap_item(shop, id)
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
		var panel := shop.get_node("Modal/Panel") as Control
		var resume := shop.get_node("Modal/Panel/List/ResumeButton") as Button
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
			await _tap_item(shop, id)
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
		var assist_toggle := shop.get_node("Modal/Panel/List/AssistRow/AssistButton") as Button
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
## workspace skip area, Pause, the pause panel buttons, a station's
## Assist button) is at least 32x32, inside the safe area and, except Pause, in
## the thumb zone (lower 60%) at 9:16, 9:19.5 and 16:9.
func _test_shop_controls_size_and_zone() -> void:
	_game.assist_mode = true
	var shop := await _open_shop()
	if await _wait_for_order(shop, "layout"):
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			await _tap_item(shop, id)
		var pause := shop.get_node("Column/Hud/PauseButton") as Button
		var play: Array[Control] = [shop.brew_button(), shop.get_node("Column/Stage/RefuseButton") as Control, shop.get_node("Column/Stage/CodexButton") as Control, shop.slot_button(0), shop.slot_button(1), shop.slot_button(2), shop.get_node("Column/Stage/SkipButton") as Control, pause]
		for item in shop.get_node("Column/Stage/ShelfItems").get_children():
			play.append(item as Control)
		var pause_buttons: Array[Control] = []
		for button in shop.get_node("Modal/Panel/List").find_children("*", "Button", true, false):
			pause_buttons.append(button as Control)
		_check(pause_buttons.size() == 6, "layout: pause panel has Resume, two toggles with their \"?\" and Quit", str(pause_buttons))
		for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
			root.size = window
			await _frames(30)
			_check_targets(play, pause, "shop at %s" % window)
			shop.open_pause()
			await _frames(30)
			_check_targets(pause_buttons, pause, "pause panel at %s" % window)
			shop.close_pause()
			shop.open_codex()
			await _frames(30)
			var codex_buttons: Array[Control] = []
			for button in shop.codex.find_children("*", "Button", true, false):
				codex_buttons.append(button as Control)
			_check(codex_buttons.size() == 5, "layout: the Codex has two tabs, two page buttons and Close", str(codex_buttons.size()))
			_check_targets(codex_buttons, pause, "codex at %s" % window)
			shop.codex.close()
			await process_frame
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
			await _tap_item(shop, id)
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
			await _tap_item(shop, id)
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
		var price := shop.customer.potion.price
		await _check_stamp(shop, Brew.Grade.PERFECT, Economy.pay(price, Brew.Grade.PERFECT), Economy.tip(price, Brew.Grade.PERFECT, who.tip_tendency), "perfect")
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
	_check(shop.served == day.customers.size() and shop.stormed_off == 0, "keyboard day 1 serves everyone", "%d %d" % [shop.served, shop.stormed_off])
	var on_summary := await _until(func() -> bool: return current_scene is Summary and not _game.is_transitioning() and root.gui_get_focus_owner() == current_scene.get_node("Column/Layout/ContinueButton"), FLOW_FRAMES)
	_check(on_summary, "keyboard day 1 ends on the summary's focused To the market button", str(root.gui_get_focus_owner()))
	if on_summary:
		# The first Enter completes the tally (the numbers final, still on the summary), the second continues.
		var summary := current_scene as Summary
		var tallying := summary.is_tallying()
		await _action(&"ui_accept")
		_check(tallying and current_scene == summary and not summary.is_tallying() and not _game.is_transitioning() and _tile_texts(summary)[0] == "3/3" and _tile_texts(summary)[1] == "+%d" % summary.tile("Coins earned").value, "keyboard: the first Enter completes the summary's tally", "%s %s" % [tallying, _tile_texts(summary)])
	await _action(&"ui_accept")
	await _until(func() -> bool: return current_scene is Market and not _game.is_transitioning(), FLOW_FRAMES)
	var market := current_scene as Market
	_check(market != null and root.gui_get_focus_owner() is Button and market.is_ancestor_of(root.gui_get_focus_owner()), "keyboard: the market opens with a card focused", str(root.gui_get_focus_owner()))
	if market != null:
		var coins := _game.coins
		await _action(&"ui_accept")
		_check(_game.coins < coins, "keyboard: ui_accept on a market card buys it", "%d -> %d" % [coins, _game.coins])
		# Down from the cards reaches the Codex button, right of it is Next day.
		var on_codex := await _focus_by_keys(market.get_node("Column/Shop/CodexButton") as Button)
		var on_next := on_codex and await _focus_by_keys(market.get_node("Column/Shop/NextDayButton") as Button)
		await _action(&"ui_accept")
		_check(on_next and await _until(func() -> bool: return current_scene is Morning and not _game.is_transitioning(), FLOW_FRAMES), "keyboard: Next day opens the morning", str(current_scene))
	_game.assist_mode = false
	_game.goto(GameState.Flow.TITLE)
	await _game.transition_finished


## Criterion 3: the pause button shows the menu icon, is at least 32x32 in the top-right
## corner of the safe area and has an accessibility name. Mode help (no hover,
## no always-visible text, no tooltip): the "?" right after each toggle (32x32+,
## focusable, named) opens its description in a callout inside the pause panel and the safe area at 9:16, 9:19.5 and
## 16:9. A tap on the callout, a tap on the dim, Enter and Escape each close it,
## Tab cannot leave it, and focus goes back to the "?".
func _test_shop_menu_and_mode_info() -> void:
	var shop := await _open_shop()
	var safe := _game.safe_rect()
	var menu := shop.get_node("Column/Hud/PauseButton") as Button
	var rect := menu.get_global_rect()
	var menu_icon := (menu.get_node("Icon") as TextureRect).texture as AtlasTexture
	_check(menu_icon != null and menu_icon.region == Art.texture("ui", "icon_menu").region and menu.accessibility_name == "Pause menu", "pause button shows the menu icon and is named", "%s / %s" % [menu_icon, menu.accessibility_name])
	_check(rect.size.x >= MIN_TARGET and rect.size.y >= MIN_TARGET and rect.end.x >= safe.end.x - 8.0 and rect.position.y <= safe.position.y + 8.0, "Menu button is 32x32+ in the top right", "%s in %s" % [rect, safe])
	var tag := shop.get_node("Column/Hud/AssistTag") as Label
	var tag_text := Rect2(tag.get_global_rect().end.x - tag.get_minimum_size().x, tag.get_global_rect().position.y, tag.get_minimum_size().x, tag.size.y)
	_check(not rect.intersects(tag_text), "Menu button clears the ASSIST tag", "%s vs %s" % [rect, tag_text])
	shop.open_pause()
	await _frames(5)
	var list := shop.get_node("Modal/Panel/List")
	var panel := shop.get_node("Modal/Panel") as Control
	var help := shop.get_node("Modal/ModeHelp") as Button
	var callout := shop.get_node("Modal/ModeHelp/Callout") as Control
	var text := shop.get_node("Modal/ModeHelp/Callout/Text") as Label
	var dim := shop.get_node("Modal/Dim") as Control
	_check(list.find_children("*Info", "", true, false).is_empty(), "no always-visible mode descriptions remain", str(list.find_children("*Info", "", true, false)))
	for mode: Array in [["Assist", Shop.ASSIST_INFO], ["Gentle", Shop.GENTLE_INFO]]:
		var toggle := list.get_node("%sRow/%sButton" % [mode[0], mode[0]]) as Button
		var question := list.get_node("%sRow/%sHelp" % [mode[0], mode[0]]) as Button
		var label := "%s \"?\"" % mode[0]
		_check(toggle.tooltip_text == "", "%s has no tooltip (its \"?\" explains it)" % toggle.name, toggle.tooltip_text)
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
			await _tap_item(shop, id)
			mix += Content.ingredient(id).essence
			await _check_preview(shop, mix, "preview after adding %s" % id)
		var extra: String = shop.stock.keys().filter(func(id: String) -> bool: return shop.stock[id] > 0)[0]
		await _tap_item(shop, extra)
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
				await _tap_item(shop, id)
			await _tap(shop.brew_button())
			if await _until(func() -> bool: return shop.station is Stir and shop.station.is_running(), FLOW_FRAMES):
				var stir := shop.station as Stir
				await _frames(ceili(wait_loops / Stir.DEFAULT_TEMPO / FRAME))
				var centre := stir.get_global_transform() * Stir.CENTRE
				var screen := root.get_final_transform()
				var touch := InputEventScreenTouch.new()
				touch.index = TOUCH_INDEX
				touch.position = screen * (centre + Vector2(Stir.RING_RADIUS, 0))
				touch.pressed = true
				Input.parse_input_event(touch)
				await process_frame
				for i in range(1, ceili((Stir.ROTATIONS + 0.3) / Stir.DEFAULT_TEMPO / FRAME) + 1):
					if not stir.is_running():
						break
					var drag := InputEventScreenDrag.new()
					drag.index = TOUCH_INDEX
					drag.position = screen * (centre + Vector2.from_angle(i * FRAME * Stir.DEFAULT_TEMPO * TAU) * Stir.RING_RADIUS)
					Input.parse_input_event(drag)
					await process_frame
				var release := InputEventScreenTouch.new()
				release.index = TOUCH_INDEX
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
		var who := shop.customer.archetype
		var stops := Juice.hit_stops
		if not await _serve(shop, _recipe_between(wants, shop.stock, case[1], case[2]), label):
			break
		_check(shop.grades.back() == grade, label + ": served at that grade", str(shop.grades))
		await _check_stamp(shop, grade, Economy.pay(wants.price, grade), Economy.tip(wants.price, grade, who.tip_tendency), label)
		var expected_stops := 1 if grade == Brew.Grade.MISBREW else 0
		_check(Juice.hit_stops - stops == expected_stops and not Juice.is_hit_stopped(), label + ": %d hit-stop as the stamp lands, over by now" % expected_stops, str(Juice.hit_stops - stops))
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
		var meter := visitor.get_node("QueueMeter") as Node2D
		var stray := visitor.find_children("*", "Sprite2D", true, false).filter(func(sprite: Node) -> bool: return sprite.get_parent() != row and sprite.get_parent() != meter and sprite.get_parent().name != "Body")
		_check(visitor.get_node_or_null("Emote") == null and stray.is_empty() and not meter.visible, "no mood emote on the customer (only body parts, the patience row and the hidden queue meter)", str(stray))
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


## Palette swap: every look colour is a palette.hex colour, the atlas sidecar's
## colour lists match the customer sprites' pixels, no part needs more swaps than
## the shader holds, looks are deterministic by seed, and the archetypes' parts
## times the looks give at least 200 distinct visitors (counted by what they show).
func _test_look_palette_and_count() -> void:
	var palette := {}
	var palette_path := ProjectSettings.globalize_path("res://").path_join("../art_src/palette.hex")
	for raw in FileAccess.get_file_as_string(palette_path).split("\n"):
		var line := raw.get_slice(";", 0).strip_edges()
		if line != "":
			palette[line.to_lower()] = true
	_check(palette.size() == 32, "palette.hex read (%d colours)" % palette.size(), palette_path)
	var outside := PackedStringArray()
	for ramps: Dictionary in [Look.CLOTHS, Look.HAIRS, Look.SKINS]:
		for ramp_name: String in ramps:
			for color: String in ramps[ramp_name]:
				if not palette.has(color):
					outside.append("%s %s" % [ramp_name, color])
	_check(outside.is_empty(), "every look colour is in palette.hex", str(outside))
	var atlas := Art.texture("customer", "body_robe_0").atlas.get_image()
	var mismatched := PackedStringArray()
	var too_many := PackedStringArray()
	var all_looks := Look.all()
	for archetype in Content.archetypes():
		for part in Customer.parts_of(archetype):
			for frame in 2:
				var sprite := "%s_%d" % [part, frame]
				var used := {}
				var image := atlas.get_region(Rect2i(Art.texture("customer", sprite).region))
				for y in image.get_height():
					for x in image.get_width():
						var pixel := image.get_pixel(x, y)
						if pixel.a > 0.0:
							used["#" + pixel.to_html(false)] = true
				var listed := Array(Art.colors("customer", sprite))
				var found := used.keys()
				found.sort()
				if found != listed:
					mismatched.append("%s: pixels %s, sidecar %s" % [sprite, found, listed])
			for look in all_looks:
				if look.swaps(part).size() > Customer.MAX_SWAPS:
					too_many.append(part)
					break
	_check(mismatched.is_empty(), "sidecar colour lists match the customer sprites", "\n".join(mismatched))
	_check(too_many.is_empty(), "no part needs more swaps than the shader holds", str(too_many))
	_check(Look.from_seed(42).describe() == Look.from_seed(42).describe() and Look.from_seed(42).cloth_a != Look.from_seed(42).cloth_b, "a look is deterministic by seed, two different cloths", Look.from_seed(42).describe())
	var distinct := {}
	for archetype in Content.archetypes():
		var parts := Customer.parts_of(archetype)
		for look in all_looks:
			distinct[" ".join(parts) + "|" + look.signature(parts)] = true
	_check(Content.archetypes().size() >= 8, "at least 8 archetypes", str(Content.archetypes().size()))
	_check(distinct.size() >= 200, "at least 200 distinct customer looks (%d)" % distinct.size(), str(distinct.size()))


## No two customers of a shift look alike: every story day in days.json, and a
## generated 60-customer run cycling the archetypes in random order.
func _test_look_distinct_per_shift() -> void:
	var problems := PackedStringArray()
	var shifts: Dictionary[String, Array] = {}
	for day in Content.days():
		var archetypes: Array[Archetype] = []
		for spec in Shift.story(day.day).customers:
			archetypes.append(Content.archetype(spec.archetype))
		shifts["day %d" % day.day] = archetypes
	var rng := RandomNumberGenerator.new()
	rng.seed = 60
	var run: Array[Archetype] = []
	for i in 60:
		run.append(Content.archetypes()[rng.randi_range(0, Content.archetypes().size() - 1)])
	shifts["60-customer run"] = run
	for shift_name in shifts:
		for shift_seed: int in [1, 2, 3]:
			var parts: Array[Array] = []
			for archetype: Archetype in shifts[shift_name]:
				parts.append(Customer.parts_of(archetype))
			var looks := Look.distinct_for(parts, shift_seed)
			var seen := {}
			for i in looks.size():
				var part_names: Array[String] = []
				part_names.assign(parts[i])
				seen[" ".join(part_names) + "|" + looks[i].signature(part_names)] = true
			if seen.size() != looks.size():
				problems.append("%s seed %d: %d distinct of %d" % [shift_name, shift_seed, seen.size(), looks.size()])
			var again := Look.distinct_for(parts, shift_seed)
			if looks.map(func(look: Look) -> String: return look.describe()) != again.map(func(look: Look) -> String: return look.describe()):
				problems.append("%s seed %d: not deterministic" % [shift_name, shift_seed])
	_check(problems.is_empty(), "no two customers of a shift look alike (every day, a 60-customer run)", "\n".join(problems))


## Shop customers draw through the palette swap: every part with swappable colours
## has the shader with exactly its look's swaps; the face has none.
## The first visitor's look is pinned: the day's looks are rolled at random, and about 1
## roll in 270 is the art's own colours (cloth A blue, cloth B green, light skin), which
## rightly swaps nothing; asserting on a random look made this test fail intermittently
## with no problem listed. The art-colour look itself is checked to draw unswapped.
func _test_shop_customer_look() -> void:
	var art_colours := Look.new()
	var robe: Array[String] = ["body_robe", "head_round", "hair_witch_hat"]
	_check(robe.all(func(part: String) -> bool: return art_colours.swaps(part).is_empty()), "the art's own colours swap nothing", art_colours.signature(robe))
	var shop := await _open_shop()
	# The day's looks are rolled in the shop's _ready; the first visitor enters later.
	shop._looks[0] = Look.from_seed(42)
	if await _wait_for_order(shop, "customer look"):
		var visitor := shop.customer
		var problems := PackedStringArray()
		var layers := {"body": "BodyPart", "head": "Head", "hair": "Hair", "acc": "Accessory"}
		var parts := Customer.parts_of(visitor.archetype)
		for part in parts:
			var sprite := visitor.get_node("Body/" + str(layers[part.get_slice("_", 0)])) as Sprite2D
			var swaps := visitor.look.swaps(part)
			var swap := sprite.material as ShaderMaterial
			if swaps.is_empty():
				if swap != null:
					problems.append("%s has a swap without colours to swap" % part)
			elif swap == null or swap.shader.resource_path != "res://shaders/palette_swap.gdshader" or int(swap.get_shader_parameter(&"count")) != swaps.size():
				problems.append("%s: material %s, expected %d swaps" % [part, swap, swaps.size()])
			else:
				# The shader gets exactly the look's pairs, in order: art colour -> visitor colour.
				var from: PackedColorArray = swap.get_shader_parameter(&"from_colors")
				var to: PackedColorArray = swap.get_shader_parameter(&"to_colors")
				var art_colors := swaps.keys()
				for i in swaps.size():
					if not from[i].is_equal_approx(Color(art_colors[i])) or not to[i].is_equal_approx(Color(swaps[art_colors[i]])):
						problems.append("%s swap %d: %s -> %s, expected %s -> %s" % [part, i, from[i], to[i], art_colors[i], swaps[art_colors[i]]])
				if swaps.keys().all(func(art: String) -> bool: return art == swaps[art]):
					problems.append("%s: every swap keeps its colour" % part)
		_check(problems.is_empty() and visitor.look != null and not visitor.look.swaps(parts[0]).is_empty(), "customer parts draw with their look's palette swap (each art colour to the look's colour)", "\n".join(problems))
		_check((visitor.get_node("Body/Face") as Sprite2D).material == null, "the face keeps its colours", "face has a material")
	await _close_shop()


## The line: up to 2 customers queue in front of the window (reading zone, not
## interactive, no patience row) while the counter one is served; queued patience
## drains at Customer.QUEUE_PATIENCE_RATE; a queued customer whose patience runs out
## storms off from the queue (reputation -2, its stormed_off line, no stamp, no pay)
## and the counter's request comes back; the queue steps forward when the served
## customer leaves.
func _test_shop_queue() -> void:
	_game.assist_mode = true
	var shop := await _open_shop()
	var full := await _until(func() -> bool: return shop.queue.size() == 2 and shop.queue.all(func(c: Customer) -> bool: return c.state == Customer.State.QUEUED), FLOW_FRAMES * 3)
	_check(full and shop.customer != null and shop.customer.state == Customer.State.WAIT_ORDER, "queue: the counter customer plus 2 queued", "queue %d" % shop.queue.size())
	if full:
		var reading_zone := Shop.STAGE_SIZE.y * THUMB_ZONE_TOP
		var stage := shop.get_node("Column/Stage") as Control
		var placed := PackedStringArray()
		for i in shop.queue.size():
			var visitor := shop.queue[i]
			# Where the visitor's sprites (parts and queue meter) are drawn, in stage coordinates.
			var drawn := Rect2()
			for sprite: Sprite2D in visitor.find_children("*", "Sprite2D", true, false):
				if sprite.is_visible_in_tree() and sprite.texture != null:
					var rect := stage.get_global_transform().affine_inverse() * sprite.get_global_transform() * sprite.get_rect()
					drawn = rect if drawn.size == Vector2.ZERO else drawn.merge(rect)
			var meter := visitor.get_node("QueueMeter") as Node2D
			var meter_top := (stage.get_global_transform().affine_inverse() * meter.get_global_transform()).origin.y
			if not is_equal_approx(visitor.position.x, Customer.SLOT_X[i + 1]) or drawn.end.y > reading_zone or drawn.position.y < SpeechBubble.BOTTOM_Y:
				placed.append("queued %d drawn at %s (x %.0f)" % [i, drawn, visitor.position.x])
			if (visitor.get_node("Patience") as Node2D).visible or not meter.visible or meter_top <= SpeechBubble.BOTTOM_Y:
				placed.append("queued %d: patience row %s, queue meter %s at y %.0f" % [i, (visitor.get_node("Patience") as Node2D).visible, meter.visible, meter_top])
		_check(placed.is_empty(), "queue: queued customers are drawn in their places in the reading zone under the bubble, with the queue meter, no patience row", "\n".join(placed))
		var pips_full := shop.queue[0].get_node("QueueMeter").get_children().map(func(pip: Sprite2D) -> Texture2D: return pip.texture)
		_check(pips_full.all(func(texture: Texture2D) -> bool: return texture == Art.texture("ui", "pip_full")), "queue: a fresh queued customer's meter is full", str(pips_full))
		_check(shop.get_node("Column/Stage/Customers").find_children("*", "Control", true, false).is_empty(), "queue: customers are not interactive", "a Control in Customers")
		var counter := shop.customer
		var queued := shop.queue[0]
		var counter_before := counter.patience_left
		var queued_before := queued.patience_left
		await _frames(60)
		var counter_drain := counter_before - counter.patience_left
		var queued_drain := queued_before - queued.patience_left
		_check(counter_drain > 0.5 and is_equal_approx(snappedf(queued_drain / counter_drain, 0.01), Customer.QUEUE_PATIENCE_RATE), "queue: queued patience drains at %.2fx" % Customer.QUEUE_PATIENCE_RATE, "counter %.3f queued %.3f" % [counter_drain, queued_drain])
		# Half the patience left: 3 halves of 6 show as full, half, empty.
		queued.patience_left = queued.patience_total * 0.5
		await process_frame
		var pips_half := queued.get_node("QueueMeter").get_children().map(func(pip: Sprite2D) -> Texture2D: return pip.texture)
		_check(pips_half == [Art.texture("ui", "pip_full"), Art.texture("ui", "pip_half"), Art.texture("ui", "pip_empty")], "queue: the meter shows half the patience as full, half, empty pips", str(pips_half))
		var storming := shop.queue[1]
		var request := counter.request.text
		var coins := shop.coins
		storming.patience_left = 0.1
		_check(await _until(func() -> bool: return shop.stormed_off == 1, FLOW_FRAMES), "queue: a queued customer storms off", str(shop.stormed_off))
		var bubble := shop.get_node("Column/Stage/Bubble") as SpeechBubble
		_check(bubble.text in storming.archetype.reactions["stormed_off"] and storming.state == Customer.State.LEAVE, "queue: it says a stormed_off line and leaves", "'%s' %s" % [bubble.text, Customer.State.keys()[storming.state]])
		_check(shop.reputation == Economy.STORMED_OFF_REPUTATION and shop.coins == coins and shop.served == 0 and not (shop.get_node("Column/Stage/Stamp") as Control).visible, "queue: storming off costs reputation only, no stamp", "rep %d coins %d" % [shop.reputation, shop.coins])
		_check(shop.queue == ([queued] as Array[Customer]) and shop.customer == counter, "queue: the line closes up", str(shop.queue))
		_check(await _until(func() -> bool: return bubble.text == request, FLOW_FRAMES), "queue: the counter's request comes back after the aside", bubble.text)
		await _serve(shop, _exact_recipe(counter.potion, shop.stock), "queue serve")
		await _skip_lines(shop)
		_check(await _until(func() -> bool: return shop.customer == queued and queued.state == Customer.State.WAIT_ORDER, FLOW_FRAMES), "queue: the next one steps up to the counter", "customer %s" % shop.customer)
		_check(is_equal_approx(queued.position.x, Customer.COUNTER_X) and (queued.get_node("Patience") as Node2D).visible and not (queued.get_node("QueueMeter") as Node2D).visible, "queue: at the counter with its patience row, no queue meter", str(queued.position))
	await _close_shop()


## Refuse: disabled with no customer at the counter and while brewing; a tap sends
## the waiting customer away (the pot's ingredients back to stock, -1 reputation,
## no pay, no stamp, a refused line) and the queue steps forward; Enter on the
## focused button refuses too; the summary counts the refusals.
func _test_shop_refuse() -> void:
	var shop := await _open_shop()
	var refuse := shop.get_node("Column/Stage/RefuseButton") as Button
	_check(shop.customer == null and refuse.disabled, "refuse: disabled with no customer at the counter", "customer %s, disabled %s" % [shop.customer, refuse.disabled])
	var full := await _until(func() -> bool: return shop.queue.size() == 2 and shop.customer != null and shop.customer.state == Customer.State.WAIT_ORDER, FLOW_FRAMES * 3)
	_check(full and not refuse.disabled, "refuse: enabled while the counter customer waits for an order", "queue %d, disabled %s" % [shop.queue.size(), refuse.disabled])
	if not full:
		await _close_shop()
		return
	_refill_patience(shop)
	shop.open_pause()
	var paused_off := refuse.disabled
	shop.close_pause()
	_check(paused_off and not refuse.disabled, "refuse: disabled while paused, enabled again on resume", "paused %s, resumed disabled %s" % [paused_off, refuse.disabled])
	var counter := shop.customer
	var next := shop.queue[0]
	var stock := shop.stock.duplicate()
	var coins := shop.coins
	await _tap_item(shop, _exact_recipe(counter.potion, shop.stock)[0])
	await _tap(refuse)
	var bubble := shop.get_node("Column/Stage/Bubble") as SpeechBubble
	_check(shop.refused == 1 and shop.reputation == Economy.REFUSED_REPUTATION and shop.coins == coins and shop.served == 0, "refuse: -1 reputation, no pay", "refused %d rep %d coins %d" % [shop.refused, shop.reputation, shop.coins])
	_check(shop.pot.is_empty() and shop.stock == stock, "refuse: the pot's ingredients go back to stock", "%s %s" % [shop.pot, shop.stock])
	_check(bubble.text in counter.archetype.reactions["refused"] and not (shop.get_node("Column/Stage/Stamp") as Control).visible and refuse.disabled, "refuse: a refused line, no stamp, the button disabled", "'%s'" % bubble.text)
	await _skip_lines(shop)
	_check(await _until(func() -> bool: return shop.customer == next and next.state == Customer.State.WAIT_ORDER, FLOW_FRAMES), "refuse: the next customer steps up", "customer %s" % shop.customer)
	_refill_patience(shop)
	refuse.grab_focus()
	await _action(&"ui_accept")
	_check(shop.refused == 2 and shop.reputation == 2 * Economy.REFUSED_REPUTATION, "refuse: Enter on the focused button refuses", "refused %d" % shop.refused)
	await _skip_lines(shop)
	var third := await _until(func() -> bool: return shop.customer != null and shop.customer.state == Customer.State.WAIT_ORDER, FLOW_FRAMES * 3)
	_check(third, "refuse: the third customer comes to the counter", "customer %s" % shop.customer)
	if third:
		_game.assist_mode = true
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			await _tap_item(shop, id)
		await _tap(shop.brew_button())
		await _until(func() -> bool: return shop.station != null and shop.station.is_running(), FLOW_FRAMES)
		_check(refuse.disabled, "refuse: disabled while brewing", "enabled")
	var result := shop.day_result()
	_check(result.get("refused") == 2, "refuse: the day's result counts refusals", str(result))
	_game.goto(GameState.Flow.SUMMARY, result)
	await _game.transition_finished
	var money := _row_text(current_scene, "Counts/Refused")
	_check(money == "Refused: 2", "refuse: the summary shows the refusals", money)
	await _close_shop()


## Refuse is disabled while the counter customer storms off; refusing every other
## customer ends the day with the summary counting the storm-off and the refusals.
func _test_shop_refuse_ends_day() -> void:
	var shop := await _open_shop()
	var refuse := shop.get_node("Column/Stage/RefuseButton") as Button
	var count := shop.shift.customers.size()
	if not await _wait_for_order(shop, "refuse day"):
		await _close_shop()
		return
	shop.customer.patience_left = 0.1
	var storming := await _until(func() -> bool: return shop.customer != null and shop.customer.state == Customer.State.STORMING, FLOW_FRAMES)
	_check(storming and refuse.disabled, "refuse: disabled while the customer storms off", "storming %s disabled %s" % [storming, refuse.disabled])
	for n in count - 1:
		if not await _wait_for_order(shop, "refuse day customer %d" % (n + 2)):
			await _close_shop()
			return
		_refill_patience(shop)
		await _tap(refuse)
	_check(await _until(func() -> bool: return _game.state == GameState.Flow.SUMMARY and not _game.is_transitioning(), FLOW_FRAMES * 2), "refuse: refusing the last customer ends the day", str(_game.state))
	var result := _game.flow_args
	_check(result.get("refused") == count - 1 and result.get("stormed_off") == 1 and result.get("served") == 0 and result.get("reputation") == Economy.STORMED_OFF_REPUTATION + (count - 1) * Economy.REFUSED_REPUTATION, "refuse: the day's summary counts the storm-off and every refusal", str(result))
	await _close_shop()


## Both queued customers storming off within one aside hold: the second aside
## still puts the counter customer's request back afterwards.
func _test_shop_queue_double_storm() -> void:
	var shop := await _open_shop()
	var full := await _until(func() -> bool: return shop.queue.size() == 2 and shop.queue.all(func(c: Customer) -> bool: return c.state == Customer.State.QUEUED), FLOW_FRAMES * 3)
	_check(full and shop.customer != null and shop.customer.state == Customer.State.WAIT_ORDER, "double storm: the line is full", "queue %d" % shop.queue.size())
	if full:
		var request := shop.customer.request.text
		shop.queue[1].patience_left = 0.1
		shop.queue[0].patience_left = 0.6
		_check(await _until(func() -> bool: return shop.stormed_off == 2, FLOW_FRAMES), "double storm: both queued customers storm off", str(shop.stormed_off))
		var bubble := shop.get_node("Column/Stage/Bubble") as SpeechBubble
		_check(await _until(func() -> bool: return bubble.visible and bubble.text == request, FLOW_FRAMES), "double storm: the counter's request comes back", "'%s' visible %s" % [bubble.text, bubble.visible])
		_check(shop.queue.is_empty() and shop.reputation == 2 * Economy.STORMED_OFF_REPUTATION, "double storm: queue empty, reputation for both", "rep %d" % shop.reputation)
	await _close_shop()


## The bubble blips on the 1st typed character and every BLIP_EVERY after (one per
## frame at most), not after skip() completes the line.
## The day's skill measures (Difficulty.day_score's inputs) as the shop records them on
## day 1: a queued customer storming off adds 0 to patience_left; a delivery adds the
## fraction of patience left and each station finished by gesture its quality to
## gestures; an Assist press adds none, and the counter customer storming off adds 0;
## day_result() carries both lists.
func _test_shop_difficulty_inputs() -> void:
	var shop := await _open_shop()
	var full := await _until(func() -> bool: return shop.queue.size() == 2 and shop.queue.all(func(c: Customer) -> bool: return c.state == Customer.State.QUEUED), FLOW_FRAMES * 3)
	_check(full, "skill measures: the line is full", "queue %d" % shop.queue.size())
	if not full:
		await _close_shop()
		return
	shop.queue[1].patience_left = 0.1
	_check(await _until(func() -> bool: return shop.stormed_off == 1, FLOW_FRAMES) and shop.patience_left == [0.0], "skill measures: a queue storm-off adds 0 patience left", str(shop.patience_left))
	if await _wait_for_order(shop, "skill measures by gesture"):
		_refill_patience(shop)
		var who := shop.customer
		for id in _exact_recipe(who.potion, shop.stock):
			await _tap_item(shop, id)
		await _tap(shop.brew_button())
		for step in who.potion.steps:
			if not await _until(func() -> bool: return shop.station != null and shop.station.is_running(), FLOW_FRAMES):
				_check(false, "skill measures: %s runs" % step, "no station")
				break
			if shop.station is Stir:
				_stir_circles(shop.station as Stir, Stir.DEFAULT_TEMPO, Stir.ROTATIONS, 0.0)
			else:
				_pour_to(shop.station as Pour, (shop.station as Pour).target_line())
			await _until(func() -> bool: return shop.station == null or not shop.station.is_running(), FLOW_FRAMES)
		_check(await _until(func() -> bool: return shop.served == 1, FLOW_FRAMES), "skill measures: served by gesture", "served %d" % shop.served)
		_check(shop.gestures.size() == who.potion.steps.size() and shop.patience_left.size() == 2 and shop.patience_left[1] > 0.0 and is_equal_approx(shop.patience_left[1], who.patience_left / who.patience_total), "skill measures: a delivery adds its patience left, each gesture its quality", "gestures %s patience %s" % [shop.gestures, shop.patience_left])
	await _skip_lines(shop)
	_game.assist_mode = true
	if await _wait_for_order(shop, "skill measures by Assist"):
		_refill_patience(shop)
		var gestures := shop.gestures.duplicate()
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			await _tap_item(shop, id)
		await _tap(shop.brew_button())
		if await _until(func() -> bool: return shop.station != null and shop.station.assist_button() != null, FLOW_FRAMES):
			await _tap(shop.station.assist_button())
			_check(shop.gestures == gestures, "skill measures: an Assist press adds no gesture", str(shop.gestures))
		else:
			_check(false, "skill measures: Assist station runs", "no station")
		shop.customer.patience_left = 0.2
		_check(await _until(func() -> bool: return shop.stormed_off == 2, FLOW_FRAMES) and shop.patience_left.size() == 3 and shop.patience_left[2] == 0.0, "skill measures: a counter storm-off adds 0 patience left", str(shop.patience_left))
	var result := shop.day_result()
	_check(result.get("patience_left") == shop.patience_left and result.get("gestures") == shop.gestures and not shop.gestures.is_empty(), "skill measures: day_result carries patience_left and gestures", str(result))
	await _close_shop()


func _test_bubble_blips() -> void:
	var bubble := SPEECH_BUBBLE_SCENE.instantiate() as SpeechBubble
	root.add_child(bubble)
	var blips := [0]
	bubble.blip.connect(func() -> void: blips[0] += 1)
	var line: String = Content.archetypes()[0].reactions["perfect"][0]
	bubble.say(line, 135.0)
	var total := (bubble.get_node("Box/Text") as RichTextLabel).get_total_character_count()
	await _until(func() -> bool: return not bubble.is_typing(), FLOW_FRAMES)
	_check(blips[0] == ceili(total / float(SpeechBubble.BLIP_EVERY)), "bubble blips every %d characters" % SpeechBubble.BLIP_EVERY, "%d blips for %d characters" % [blips[0], total])
	blips[0] = 0
	bubble.say(line, 135.0)
	await _frames(6)
	var before_skip: int = blips[0]
	bubble.skip()
	await _frames(30)
	_check(before_skip > 0 and blips[0] == before_skip, "no blips once the line is skipped", "%d then %d" % [before_skip, blips[0]])
	bubble.free()


## Sound needs no input first (a browser that blocks it resumes on the first touch);
## a customer's request plays voice blips through Game.play_sfx, and every archetype
## has its voice file.
func _test_audio_and_voices() -> void:
	_check(_game.get_node_or_null("AudioUnlock") == null, "no audio lock waits for the first input", "AudioUnlock node present")
	var played := _game.sfx_played
	_game.play_sfx(load(Shop.VOICE_PATH % Content.archetypes()[0].id) as AudioStream)
	_check(_game.sfx_played == played + 1, "a sound plays without any input first", str(_game.sfx_played - played))
	var missing := PackedStringArray()
	for archetype in Content.archetypes():
		if not ResourceLoader.exists(Shop.VOICE_PATH % archetype.id):
			missing.append(archetype.id)
	_check(missing.is_empty(), "every archetype has a voice blip", str(missing))
	var shop := await _open_shop()
	played = _game.sfx_played
	if await _wait_for_order(shop, "voices"):
		var bubble := shop.get_node("Column/Stage/Bubble") as SpeechBubble
		await _until(func() -> bool: return not bubble.is_typing(), FLOW_FRAMES)
		var total := (bubble.get_node("Box/Text") as RichTextLabel).get_total_character_count()
		_check(_game.sfx_played - played >= ceili(total / float(SpeechBubble.BLIP_EVERY)), "the request plays voice blips while typing", "%d for %d characters" % [_game.sfx_played - played, total])
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
			await _tap_item(shop, id)
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
				await _drive_scrub(station as Mortar)
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
		var stops := Juice.hit_stops
		_check(await _until(func() -> bool: return shop.served == 1, FLOW_FRAMES), "day 2 customer served", str(shop.served))
		_check(shop.grades == ([Brew.Grade.PERFECT] as Array[Brew.Grade]), "mortar and bellows by touch give a Perfect potion", str(shop.grades))
		_check(_heard(&"stamp_perfect") and (shop.get_node("Column/Stage/Stamp") as Control).visible, "the Perfect stamp and its sound land on the delivery frame", str(_game.sfx_log.slice(-6)))
		_check(await _until(func() -> bool: return Juice.hit_stops == stops + 1, 30) and is_equal_approx(Juice.last_hit_stop, Shop.STAMP_HIT_STOPS[Brew.Grade.PERFECT]), "the Perfect stamp lands with a hit-stop", "%d stops, last %.2f s" % [Juice.hit_stops - stops, Juice.last_hit_stop])
		wants.steps = shipped
	await _close_shop()


## The grade stamp right after a serve: `grade`'s words, colour and icon; "+pay"
## and "tip +tip" flying in Fx (none when 0); once landed, in the stage's reading zone
## (above the workspace) and clear of the speech bubble.
func _check_stamp(shop: Shop, grade: Brew.Grade, pay: int, tip: int, label: String) -> void:
	var stamp := shop.get_node("Column/Stage/Stamp") as Control
	var text := shop.get_node("Column/Stage/Stamp/Row/Text") as Label
	var icon := (shop.get_node("Column/Stage/Stamp/Row/Icon") as TextureRect).texture as AtlasTexture
	var expected_icon := Art.texture("ui", Shop.STAMP_ICONS[grade])
	_check(stamp.visible and text.text == Shop.STAMP_TEXTS[grade] and icon != null and icon.region == expected_icon.region and text.get_theme_color(&"font_color") == Shop.STAMP_COLORS[grade], label + ": stamp reads %s with its icon and colour" % Shop.STAMP_TEXTS[grade], "visible %s '%s' %s" % [stamp.visible, text.text, icon.region if icon != null else Rect2()])
	_check(_heard(Shop.STAMP_SOUNDS[grade]), label + ": the stamp's sound plays with the delivery", str(_game.sfx_log.slice(-6)))
	var expected_pay := PackedStringArray(["+%d" % pay]) if pay > 0 else PackedStringArray()
	_check(_pay_texts(shop) == expected_pay, label + ": coins fly as %s" % expected_pay, str(_pay_texts(shop)))
	var expected_tip := PackedStringArray(["tip +%d" % tip]) if tip > 0 else PackedStringArray()
	var tip_texts := PackedStringArray()
	for node in shop.get_node("Fx").get_children():
		if node is Label and (node as Label).text.begins_with("tip"):
			tip_texts.append((node as Label).text)
	_check(tip_texts == expected_tip, label + ": tip flies as %s" % expected_tip, str(tip_texts))
	await _frames(25)
	var rect := stamp.get_global_rect()
	var bubble := (shop.get_node("Column/Stage/Bubble/Box") as Control).get_global_rect()
	var workspace_top := (shop.get_node("Column/Stage") as Control).get_global_rect().position.y + 192.0
	_check(stamp.visible and rect.end.y <= workspace_top and not rect.intersects(bubble), label + ": stamp held in the reading zone, clear of the bubble", "%s, bubble %s, workspace at %.0f" % [rect, bubble, workspace_top])


func _test_economy_day_loop_rules() -> void:
	_check(Economy.tip(12, Brew.Grade.PERFECT, 1.0) == 6 and Economy.tip(12, Brew.Grade.GOOD, 0.5) == 2 and Economy.tip(12, Brew.Grade.GOOD, 0.0) == 0, "tip = price x grade rate x tip tendency, rounded", "%d %d" % [Economy.tip(12, Brew.Grade.PERFECT, 1.0), Economy.tip(12, Brew.Grade.GOOD, 0.5)])
	_check(Economy.tip(12, Brew.Grade.MEH, 1.0) == 0 and Economy.tip(12, Brew.Grade.MISBREW, 1.0) == 0, "no tip for Meh or Misbrew", "%d %d" % [Economy.tip(12, Brew.Grade.MEH, 1.0), Economy.tip(12, Brew.Grade.MISBREW, 1.0)])
	var moonmoss := Content.ingredient("moonmoss")
	var pepper := Content.ingredient("ember_pepper")
	_check(Economy.market_price(Content.day(2), moonmoss) == Content.day(2).market["moonmoss"], "market price is the day's market price", str(Economy.market_price(Content.day(2), moonmoss)))
	_check(Economy.market_price(Content.day(1), pepper) == pepper.base_price, "a day without a market price uses the base price", str(Economy.market_price(Content.day(1), pepper)))
	var upgrade := Upgrade.new()
	upgrade.tolerances = [1.2, 1.4]
	upgrade.costs = [10, 30]
	_check(Economy.upgrade_cost(upgrade, 0) == 10 and Economy.upgrade_cost(upgrade, 1) == 30 and Economy.upgrade_cost(upgrade, 2) == Economy.MAXED, "upgrade cost is the next level's, MAXED at the top", "%d %d %d" % [Economy.upgrade_cost(upgrade, 0), Economy.upgrade_cost(upgrade, 1), Economy.upgrade_cost(upgrade, 2)])
	_check(is_equal_approx(Economy.upgrade_tolerance(upgrade, 0), 1.0) and is_equal_approx(Economy.upgrade_tolerance(upgrade, 2), 1.4), "upgrade tolerance is x1 without a level, else the level's", "%f %f" % [Economy.upgrade_tolerance(upgrade, 0), Economy.upgrade_tolerance(upgrade, 2)])


func _test_shift_configs() -> void:
	for number in range(1, Content.days().size() + 1):
		var spec := Content.day(number)
		var config := Shift.story(number)
		var label := "Shift.story(%d)" % number
		_check(config != null and config.mode == ShiftConfig.Mode.STORY and config.day == number and config.title == spec.title and is_equal_approx(config.patience_scale, spec.patience_scale * Difficulty.patience_scale(Difficulty.START_LEVEL)), label + " day, title, patience (times the level's)", str(config))
		var expected := Story.customers_of(spec, {})
		var same_customers := config.customers.size() == expected.size()
		for i in mini(config.customers.size(), expected.size()):
			same_customers = same_customers and Story.matches(config.customers[i].when, {}) and (expected[i].is_generated() or config.customers[i] == expected[i])
		_check(same_customers, label + " customers in order (visitor slots filled)", str(config.customers.size()))
		_check(config.allowed_potions == Content.potions_unlocked_by(number) and config.ingredients == Content.ingredients_unlocked_by(number), label + " allowed potions and ingredients", "%d %d" % [config.allowed_potions.size(), config.ingredients.size()])
	Content.quiet_errors = true
	_check(Shift.story(99) == null, "Shift.story of a missing day is null", "a config")
	Content.quiet_errors = false


func _test_save_round_trip() -> void:
	_game.new_game()
	_game.day = 2
	_game.at_market = true
	_game.coins = 33
	_game.reputation = -4
	_game.stock = {"ember_pepper": 2, "moonmoss": 0}
	_game.upgrades = {"stir": 1, "pour": 2}
	_game.flags = {"quill.inspection": "great", "vexley.opening": "refused"}
	_game.codex = {"words": ["hint_warm", "hint_calm"], "recipes": {"hearthglow_tonic": ["ember_pepper", "sunpetal"]}}
	_game.endings = ["cosy_corner", "guild_master"]
	_game.rush_hour_unlocked = true
	_game.rush_best = 7
	_game.assist_mode = true
	_game.gentle_mode = true
	_game.music_volume = 30
	_game.sfx_volume = 0
	_game.music_muted = true
	_game.save_game()
	_game.day = 1
	_game.coins = 0
	_game.assist_mode = false
	_game.music_volume = 90
	_game.music_muted = false
	var errors := _game.reported_errors.size()
	_game.load_game()
	_check(_game.day == 2 and _game.at_market and _game.coins == 33 and _game.reputation == -4 and _game.rush_best == 7, "save round trip: day, market, coins, reputation, Rush best", "%d %s %d %d %d" % [_game.day, _game.at_market, _game.coins, _game.reputation, _game.rush_best])
	_check(_game.stock == ({"ember_pepper": 2, "moonmoss": 0} as Dictionary[String, int]) and _game.upgrades == ({"stir": 1, "pour": 2} as Dictionary[String, int]), "save round trip: stock and upgrades", "%s %s" % [_game.stock, _game.upgrades])
	_check(_game.flags.recursive_equal({"quill.inspection": "great", "vexley.opening": "refused"}, 1), "save round trip: story flags", str(_game.flags))
	_check(_game.endings == (["cosy_corner", "guild_master"] as Array[String]) and _game.rush_hour_unlocked, "save round trip: endings reached and the Rush Hour unlock", "%s %s" % [_game.endings, _game.rush_hour_unlocked])
	_check(_game.codex_words() == PackedStringArray(["hint_warm", "hint_calm"]) and _game.codex_recipes() == ({"hearthglow_tonic": PackedStringArray(["ember_pepper", "sunpetal"])} as Dictionary[String, PackedStringArray]), "save round trip: codex", str(_game.codex))
	_check(_game.assist_mode and _game.gentle_mode and _game.music_volume == 30 and _game.sfx_volume == 0 and _game.music_muted and not _game.sfx_muted and _game.reported_errors.size() == errors, "save round trip: settings, no errors", "%s %s %d %d %s %s" % [_game.assist_mode, _game.gentle_mode, _game.music_volume, _game.sfx_volume, _game.music_muted, _game.sfx_muted])
	_game.rush_best = 7
	_game.rush_best_assisted = true
	_game.new_game()
	_check(_game.rush_best == 7 and _game.rush_best_assisted and _read_save().get("rush_best_assisted") == true and _game.assist_mode and _game.day == 1 and _game.upgrades.is_empty() and _game.flags.is_empty() and _game.coins == Content.day(1).starting_coins, "a new game restarts the story but keeps the settings and the Rush best", "%d %s %d %s %s" % [_game.rush_best, _game.assist_mode, _game.day, _game.upgrades, _game.flags])
	var saved_after := _read_save()
	_check(_game.rush_hour_unlocked and _game.endings == (["cosy_corner", "guild_master"] as Array[String]) and saved_after.get("rush_hour_unlocked") == true and saved_after.get("endings") == ["cosy_corner", "guild_master"], "a new game keeps the Rush Hour unlock and the endings reached (saved)", str(saved_after))
	_check(_game.codex_words() == PackedStringArray(["hint_warm", "hint_calm"]) and _game.codex_recipes().has("hearthglow_tonic"), "a new game keeps the Codex", str(_game.codex))
	_game.assist_mode = false
	_game.gentle_mode = false
	_game.music_volume = GameState.DEFAULT_MUSIC_VOLUME
	_game.sfx_volume = GameState.DEFAULT_SFX_VOLUME
	_game.music_muted = false
	_game.sfx_muted = false
	_game.rush_best = 0
	_game.rush_best_assisted = false
	_game.codex = {}
	_game.endings = []
	_game.rush_hour_unlocked = false
	_game.new_game()


## A missing save starts fresh with no error; each corrupt save is reported once
## (push_error, the error label), moved to save.corrupt.json unchanged and replaced
## by defaults that load cleanly.
func _test_save_missing_and_corrupt() -> void:
	_delete_saves()
	var errors := _game.reported_errors.size()
	_game.load_game()
	_check(_game.reported_errors.size() == errors and _game.day == 1 and _game.coins == 0 and not FileAccess.file_exists(_game.save_path), "missing save starts fresh silently", str(_game.reported_errors.slice(errors)))
	_game.new_game()
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_game.save_path))
	var cases: Dictionary[String, String] = {
		"not JSON": "{{{ not json",
		"not an object": "[1, 2]",
		"missing key": JSON.stringify(_without(good, "coins")),
		"wrong type": JSON.stringify(_with(good, "coins", "lots")),
		"fractional coins": JSON.stringify(_with(good, "coins", 1.5)),
		"negative coins": JSON.stringify(_with(good, "coins", -1)),
		"unknown key": JSON.stringify(_with(good, "cheat", true)),
		"unknown ingredient": JSON.stringify(_with(good, "stock", {"dragon_tooth": 1})),
		"upgrade level too high": JSON.stringify(_with(good, "upgrades", {"stir": 9})),
		"day out of range": JSON.stringify(_with(good, "day", 0)),
		"bad settings": JSON.stringify(_with(good, "settings", {"assist": true})),
		"music volume above 100": JSON.stringify(_with(good, "settings", {"assist": false, "gentle": false, "music": 110, "sfx": 80, "music_muted": false, "sfx_muted": false})),
		"negative sfx volume": JSON.stringify(_with(good, "settings", {"assist": false, "gentle": false, "music": 70, "sfx": -10, "music_muted": false, "sfx_muted": false})),
		"fractional sfx volume": JSON.stringify(_with(good, "settings", {"assist": false, "gentle": false, "music": 70, "sfx": 55.5, "music_muted": false, "sfx_muted": false})),
		"music volume not a number": JSON.stringify(_with(good, "settings", {"assist": false, "gentle": false, "music": "loud", "sfx": 80, "music_muted": false, "sfx_muted": false})),
		"music_muted not a bool": JSON.stringify(_with(good, "settings", {"assist": false, "gentle": false, "music": 70, "sfx": 80, "music_muted": "yes", "sfx_muted": false})),
		"sfx_muted missing": JSON.stringify(_with(good, "settings", {"assist": false, "gentle": false, "music": 70, "sfx": 80, "music_muted": false})),
		"assist not a bool": JSON.stringify(_with(good, "settings", {"assist": 1, "gentle": false, "music": 70, "sfx": 80, "music_muted": false, "sfx_muted": false})),
		"newer version": JSON.stringify(_with(good, "version", 99)),
		"version 0": JSON.stringify(_with(good, "version", 0)),
		"huge reputation": JSON.stringify(_with(good, "reputation", 1e300)),
		"huge rush_best": JSON.stringify(_with(good, "rush_best", GameState.SAVE_SCORE_MAX + 1)),
		"rush_best_assisted not a bool": JSON.stringify(_with(good, "rush_best_assisted", "yes")),
		"skill above 100": JSON.stringify(_with(good, "skill", 101)),
		"negative skill": JSON.stringify(_with(good, "skill", -1)),
		"skill not a number": JSON.stringify(_with(good, "skill", "high")),
		"skill missing": JSON.stringify(_without(good, "skill")),
		"difficulty above the hardest level": JSON.stringify(_with(good, "difficulty", roundi(Difficulty.LEVEL_MAX * GameState.SAVE_HUNDREDTHS) + 1)),
		"difficulty below the kindest level": JSON.stringify(_with(good, "difficulty", roundi(Difficulty.LEVEL_MIN * GameState.SAVE_HUNDREDTHS) - 1)),
		"fractional difficulty": JSON.stringify(_with(good, "difficulty", 0.5)),
		"difficulty missing": JSON.stringify(_without(good, "difficulty")),
		"unknown story flag": JSON.stringify(_with(good, "flags", {"goat_trusts_you": true})),
		"bad beat outcome": JSON.stringify(_with(good, "flags", {"quill.inspection": "splendid"})),
		"ending left in flags": JSON.stringify(_with(good, "flags", {"ending": "cosy_corner"})),
		"unknown ending": JSON.stringify(_with(good, "endings", ["happily_ever_after"])),
		"repeated ending": JSON.stringify(_with(good, "endings", ["cosy_corner", "cosy_corner"])),
		"endings not a list": JSON.stringify(_with(good, "endings", "cosy_corner")),
		"ending that is a list": JSON.stringify(_with(good, "endings", [["cosy_corner", "guild_master"]])),
		"ending that is an empty list": JSON.stringify(_with(good, "endings", [[]])),
		"rush unlock not a bool": JSON.stringify(_with(good, "rush_hour_unlocked", "yes")),
		"unknown codex key": JSON.stringify(_with(good, "codex", {"spells": []})),
		"unknown codex word": JSON.stringify(_with(good, "codex", {"words": ["hint_banana"]})),
		"repeated codex word": JSON.stringify(_with(good, "codex", {"words": ["hint_warm", "hint_warm"]})),
		"codex recipe of an unknown potion": JSON.stringify(_with(good, "codex", {"recipes": {"elixir_of_life": ["ember_pepper", "sunpetal"]}})),
		"codex recipe of one ingredient": JSON.stringify(_with(good, "codex", {"recipes": {"hearthglow_tonic": ["ember_pepper"]}})),
		"codex words not a list": JSON.stringify(_with(good, "codex", {"words": "hint_warm"})),
		"codex recipes not an object": JSON.stringify(_with(good, "codex", {"recipes": ["hearthglow_tonic"]})),
		"codex recipe with an unknown ingredient": JSON.stringify(_with(good, "codex", {"recipes": {"hearthglow_tonic": ["ember_pepper", "dragon_tooth"]}})),
	}
	var error_label := _game.get_node("Fade/ErrorLabel") as Label
	for case in cases:
		var label := "corrupt save (%s)" % case
		_write_save(cases[case])
		_game.coins = 555
		_game.quiet_errors = true
		errors = _game.reported_errors.size()
		_game.load_game()
		_game.quiet_errors = false
		var reported := _game.reported_errors.slice(errors)
		_check(reported.size() == 1 and "corrupt" in reported[0] and "save.corrupt.json" in reported[0] and error_label.visible, label + ": reported once and shown", str(reported))
		_check(FileAccess.get_file_as_string(_game.backup_path()) == cases[case], label + ": backed up unchanged", _game.backup_path())
		_check(_game.coins == 0 and _game.day == 1 and _game.stock.is_empty() and not _game.assist_mode and _game.music_volume == GameState.DEFAULT_MUSIC_VOLUME and _game.sfx_volume == GameState.DEFAULT_SFX_VOLUME, label + ": replaced by defaults", "%d %d" % [_game.coins, _game.day])
		errors = _game.reported_errors.size()
		_game.load_game()
		_check(_game.reported_errors.size() == errors, label + ": the replacement loads cleanly", str(_game.reported_errors.slice(errors)))
	error_label.hide()
	_delete_saves()
	_game.load_game()


## Save versions: the game has one upgrade step per version after the first;
## migrate_save runs the steps from the save's version up, in order, and stamps
## the new version; a save from a newer game is refused.
func _test_save_migrations() -> void:
	_check(GameState.save_migrations().size() == GameState.SAVE_VERSION - 1, "one save upgrade step per version after 1", "%d steps, version %d" % [GameState.save_migrations().size(), GameState.SAVE_VERSION])
	var to_v2 := func(saved: Dictionary) -> void:
		saved["coins"] = saved.get("gold", 0)
		saved.erase("gold")
	var to_v3 := func(saved: Dictionary) -> void:
		saved["coins"] = saved.get("coins", 0) * 2
	var steps: Array[Callable] = [to_v2, to_v3]
	var old := {"version": 1, "gold": 5}
	var problem := GameState.migrate_save(old, steps, 3)
	_check(problem == "" and old == {"version": 3, "coins": 10}, "a version 1 save runs both upgrade steps in order", "%s %s" % [problem, old])
	var middle := {"version": 2, "coins": 5}
	_check(GameState.migrate_save(middle, steps, 3) == "" and middle == {"version": 3, "coins": 10}, "a version 2 save runs only the last step", str(middle))
	var newer := {"version": 4}
	_check("newer" in GameState.migrate_save(newer, steps, 3) and newer == {"version": 4}, "a save from a newer game is refused unchanged", str(newer))
	var v1 := {"version": 1, "day": 8, "at_market": false, "flags": {"quill.fair": "great", "ending": "cosy_corner", "rush_hour_unlocked": true}}
	var upgraded := GameState.migrate_save(v1, GameState.save_migrations().slice(0, 1), 2)
	_check(upgraded == "" and v1 == {"version": 2, "day": 8, "at_market": false, "flags": {"quill.fair": "great"}, "endings": ["cosy_corner"], "rush_hour_unlocked": true}, "version 1 -> 2: the ending and the Rush Hour unlock move out of the flags", "%s %s" % [upgraded, v1])
	var v1_plain := {"version": 1, "day": 2, "at_market": false, "flags": {}}
	GameState.migrate_save(v1_plain, GameState.save_migrations().slice(0, 1), 2)
	_check(v1_plain == {"version": 2, "day": 2, "at_market": false, "flags": {}, "endings": [], "rush_hour_unlocked": false}, "version 1 -> 2: a save without an ending gets none and no unlock", str(v1_plain))
	var v2 := {"version": 2, "rush_best": 40}
	_check(GameState.migrate_save(v2, GameState.save_migrations().slice(0, 2), 3) == "" and v2 == {"version": 3, "rush_best": 40, "rush_best_assisted": false}, "version 2 -> 3: the Rush Hour best gains an assisted marker, false", str(v2))
	var v3 := {"version": 3, "settings": {"assist": true, "gentle": false}}
	_check(GameState.migrate_save(v3, GameState.save_migrations().slice(0, 3), 4) == "" and v3 == {"version": 4, "settings": {"assist": true, "gentle": false, "music": GameState.DEFAULT_MUSIC_VOLUME, "sfx": GameState.DEFAULT_SFX_VOLUME}}, "version 3 -> 4: the settings gain the default music and SFX volumes", str(v3))
	var v4 := {"version": 4, "settings": {"assist": false, "gentle": true, "music": 30, "sfx": 0}}
	_check(GameState.migrate_save(v4, GameState.save_migrations().slice(0, 4), 5) == "" and v4 == {"version": 5, "settings": {"assist": false, "gentle": true, "music": 30, "sfx": 0, "music_muted": false, "sfx_muted": false}}, "version 4 -> 5: the settings gain the music and sound mutes, off, volumes kept", str(v4))
	# Version 5 -> 6: the skill rating and level start at their defaults; a finished 7-day
	# story starts the 20-day story afresh, keeping what outlives a story; a story in
	# progress keeps only the flags of beats that still come before its day.
	var finished := {"version": 5, "day": GameState.V5_LAST_DAY + 1, "at_market": false, "coins": 300, "reputation": 25, "stock": {"cinderroot": 4}, "upgrades": {"stir": 2}, "flags": {"quill.fair": "great"}, "codex": {"words": ["hint_warmth"]}, "endings": ["cosy_corner"], "rush_hour_unlocked": true}
	var first := Content.day(Content.FIRST_DAY)
	_check(GameState.migrate_save(finished, GameState.save_migrations(), GameState.SAVE_VERSION) == "" and finished == {"version": 6, "day": Content.FIRST_DAY, "at_market": false, "coins": first.starting_coins, "reputation": 0, "stock": first.starting_stock, "upgrades": {}, "flags": {}, "codex": {"words": ["hint_warmth"]}, "endings": ["cosy_corner"], "rush_hour_unlocked": true, "skill": 50, "difficulty": 0}, "version 5 -> 6: a finished 7-day story starts the 20-day story afresh, keeping the Codex and the endings", str(finished))
	var beat_days := {}
	for spec in Content.days():
		for customer in spec.customers:
			if customer.beat != "":
				beat_days[customer.flag()] = spec.day
	var all_flags := {}
	var before := {}
	for flag: String in beat_days:
		all_flags[flag] = "great"
		if beat_days[flag] < 5:
			before[flag] = "great"
	var in_progress := {"version": 5, "day": 5, "at_market": true, "flags": all_flags.duplicate()}
	_check(GameState.migrate_save(in_progress, GameState.save_migrations(), GameState.SAVE_VERSION) == "" and in_progress == {"version": 6, "day": 5, "at_market": true, "flags": before, "skill": 50, "difficulty": 0} and not before.is_empty() and before.size() < all_flags.size(), "version 5 -> 6: a story in progress keeps the flags of beats before its day", str(in_progress))
	var unknown := {"version": 5, "day": 5, "at_market": false, "flags": {"goat_trusts_you": true}}
	_check(GameState.migrate_save(unknown, GameState.save_migrations(), GameState.SAVE_VERSION) == "" and unknown["flags"] == {"goat_trusts_you": true}, "version 5 -> 6: a flag key that names no beat is left for validation", str(unknown))
	# A whole version 2 save file (the format before Rush Hour) loads, best kept and not assisted.
	_game.new_game()
	_game.rush_hour_unlocked = true
	_game.rush_best = 40
	_game.save_game()
	var v2_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_game.save_path))
	v2_file["version"] = 2
	v2_file.erase("rush_best_assisted")
	_write_save(JSON.stringify(v2_file))
	_game.rush_best = 0
	var errors := _game.reported_errors.size()
	_game.load_game()
	_check(_game.reported_errors.size() == errors and _game.rush_best == 40 and not _game.rush_best_assisted and _game.rush_hour_unlocked, "a version 2 save file loads with its best, not assisted", "best %d assisted %s, errors %s" % [_game.rush_best, _game.rush_best_assisted, _game.reported_errors.slice(errors)])
	# A whole version 3 save file (before the volume settings) loads with the default volumes.
	_game.save_game()
	var v3_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_game.save_path))
	v3_file["version"] = 3
	(v3_file["settings"] as Dictionary).erase("music")
	(v3_file["settings"] as Dictionary).erase("sfx")
	(v3_file["settings"] as Dictionary).erase("music_muted")
	(v3_file["settings"] as Dictionary).erase("sfx_muted")
	_write_save(JSON.stringify(v3_file))
	_game.music_volume = 10
	_game.sfx_volume = 20
	errors = _game.reported_errors.size()
	_game.load_game()
	_check(_game.reported_errors.size() == errors and _game.music_volume == GameState.DEFAULT_MUSIC_VOLUME and _game.sfx_volume == GameState.DEFAULT_SFX_VOLUME and _game.rush_best == 40, "a version 3 save file loads with the default volumes", "music %d sfx %d, errors %s" % [_game.music_volume, _game.sfx_volume, _game.reported_errors.slice(errors)])
	# A whole version 5 save file with a flag key that names no beat loads as corrupt.
	_game.save_game()
	var v5_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_game.save_path))
	v5_file["version"] = 5
	v5_file.erase("skill")
	v5_file.erase("difficulty")
	v5_file["flags"] = {"goat_trusts_you": true}
	_write_save(JSON.stringify(v5_file))
	_game.quiet_errors = true
	errors = _game.reported_errors.size()
	_game.load_game()
	_game.quiet_errors = false
	var reported := _game.reported_errors.slice(errors)
	_check(reported.size() == 1 and "corrupt" in reported[0] and _game.flags.is_empty() and FileAccess.file_exists(_game.backup_path()), "a version 5 save file with an unknown flag key loads as corrupt and is backed up", str(reported))
	(_game.get_node("Fade/ErrorLabel") as Label).hide()
	_delete_saves()
	_game.load_game()
	var v1_two_day_end := {"version": 1, "day": 3.0, "at_market": false, "flags": {}}
	GameState.migrate_save(v1_two_day_end, GameState.save_migrations().slice(0, 1), 2)
	_check(v1_two_day_end.get("at_market") == true, "version 1 -> 2: the two-day build's finished save reopens the market before day 3", str(v1_two_day_end))
	var v1_story_day_3 := {"version": 1, "day": 3, "at_market": false, "flags": {"quill.inspection": "great"}}
	GameState.migrate_save(v1_story_day_3, GameState.save_migrations().slice(0, 1), 2)
	_check(v1_story_day_3.get("at_market") == false, "version 1 -> 2: a day-3 save with story flags keeps its morning", str(v1_story_day_3))


## Save files that cannot be written: a temporary file that cannot be created (the
## last good save stays), one that cannot replace the save (cleaned up), and a corrupt
## save that cannot be backed up (left in place); each reported once.
func _test_save_failed_write_keeps_save() -> void:
	_game.new_game()
	_game.coins = 41
	_game.save_game()
	var good := FileAccess.get_file_as_string(_game.save_path)
	var temp := _game.save_path + ".tmp"
	DirAccess.make_dir_absolute(temp)
	_game.coins = 99
	_game.quiet_errors = true
	var errors := _game.reported_errors.size()
	_game.save_game()
	_game.quiet_errors = false
	var reported := _game.reported_errors.slice(errors)
	DirAccess.remove_absolute(temp)
	(_game.get_node("Fade/ErrorLabel") as Label).hide()
	_check(reported.size() == 1 and "unchanged" in reported[0], "a failed save write is reported once", str(reported))
	_check(FileAccess.get_file_as_string(_game.save_path) == good, "a failed save write keeps the last good save", FileAccess.get_file_as_string(_game.save_path))
	# The temporary file cannot replace the save (a non-empty directory is in its place):
	# reported, and the temporary file is cleaned up.
	_delete_saves()
	DirAccess.make_dir_recursive_absolute(_game.save_path.path_join("keep"))
	_game.quiet_errors = true
	errors = _game.reported_errors.size()
	_game.save_game()
	_game.quiet_errors = false
	reported = _game.reported_errors.slice(errors)
	_check(reported.size() == 1 and "Could not replace" in reported[0] and not FileAccess.file_exists(temp), "a save that cannot replace the old one is reported and its temporary file removed", str(reported))
	# A corrupt save whose backup cannot be made (a non-empty directory is at the
	# backup path): one accurate report, the bad save stays, nothing is overwritten.
	DirAccess.remove_absolute(_game.save_path.path_join("keep"))
	DirAccess.remove_absolute(_game.save_path)
	_write_save("{{{ not json")
	DirAccess.make_dir_recursive_absolute(_game.backup_path().path_join("keep"))
	_game.quiet_errors = true
	errors = _game.reported_errors.size()
	_game.load_game()
	_game.quiet_errors = false
	reported = _game.reported_errors.slice(errors)
	_check(reported.size() == 1 and "could not be moved" in reported[0] and FileAccess.get_file_as_string(_game.save_path) == "{{{ not json", "a corrupt save that cannot be backed up is reported once and left in place", str(reported))
	DirAccess.remove_absolute(_game.backup_path().path_join("keep"))
	DirAccess.remove_absolute(_game.backup_path())
	(_game.get_node("Fade/ErrorLabel") as Label).hide()
	_delete_saves()
	_game.new_game()


## Game.tolerance_scale(step): the owned upgrade level's multiplier, times 1.5 in Gentle mode.
func _test_upgrade_tolerance() -> void:
	_game.new_game()
	var stir := Content.upgrade_for("stir")
	_check(is_equal_approx(_game.tolerance_scale("stir"), 1.0) and is_equal_approx(_game.tolerance_scale("mortar"), 1.0), "no upgrade: tolerance x1", str(_game.tolerance_scale("stir")))
	_game.upgrades["stir"] = 1
	_check(is_equal_approx(_game.tolerance_scale("stir"), stir.tolerances[0]) and is_equal_approx(_game.tolerance_scale("pour"), 1.0), "stir level 1 widens stir only", "%f %f" % [_game.tolerance_scale("stir"), _game.tolerance_scale("pour")])
	_game.gentle_mode = true
	_check(is_equal_approx(_game.tolerance_scale("stir"), stir.tolerances[0] * GameState.GENTLE_TOLERANCE_SCALE) and is_equal_approx(_game.tolerance_scale("bellows"), GameState.GENTLE_TOLERANCE_SCALE), "Gentle multiplies the upgrade", "%f %f" % [_game.tolerance_scale("stir"), _game.tolerance_scale("bellows")])
	_game.gentle_mode = false
	_game.upgrades["stir"] = stir.max_level()
	_check(is_equal_approx(_game.tolerance_scale("stir"), stir.tolerances[-1]), "top stir level", str(_game.tolerance_scale("stir")))
	_game.new_game()


## The shop hands each station its own tolerance: a stir level-1 upgrade and a pour
## level-2 upgrade reach the Stir and Pour stations, times the difficulty's multiplier
## (level 0.5 here; Assist on to finish them).
func _test_shop_passes_station_tolerance() -> void:
	_game.assist_mode = true
	_game.new_game()
	_game.upgrades = {"stir": 1, "pour": 2}
	_game.difficulty = 0.5
	_game.goto(GameState.Flow.SHOP)
	await _game.transition_finished
	var shop := current_scene as Shop
	if await _wait_for_order(shop, "station tolerance"):
		for id in _exact_recipe(shop.customer.potion, shop.stock):
			await _tap_item(shop, id)
		await _tap(shop.brew_button())
		for step in shop.customer.potion.steps:
			var ready := await _until(func() -> bool: return shop.station != null and shop.station.is_running() and shop.station.assist_button() != null, FLOW_FRAMES)
			if not ready:
				_check(false, "station tolerance: %s runs" % step, "no station")
				break
			var upgrade := Economy.upgrade_tolerance(Content.upgrade_for(step), _game.upgrades[step])
			var expected := upgrade * Difficulty.tolerance_scale(0.5)
			_check(is_equal_approx(shop.station.tolerance_scale, expected) and upgrade > 1.0 and expected < upgrade, "station tolerance: %s gets the upgrade's x%.2f times the difficulty's, x%.2f" % [step, upgrade, expected], str(shop.station.tolerance_scale))
			var pause := shop.get_node("Column/Hud/PauseButton") as Button
			var gentle := shop.get_node("Modal/Panel/List/GentleRow/GentleButton") as Button
			await _tap(pause)
			await _tap(gentle)
			var gentle_scale := shop.station.tolerance_scale
			await _tap(gentle)
			await _tap(shop.get_node("Modal/Panel/List/ResumeButton") as Button)
			_check(is_equal_approx(gentle_scale, expected * GameState.GENTLE_TOLERANCE_SCALE) and is_equal_approx(shop.station.tolerance_scale, expected), "station tolerance: Gentle toggled on the running %s gives upgrade x Gentle x the difficulty's, and back" % step, "%f then %f" % [gentle_scale, shop.station.tolerance_scale])
			await _tap(shop.station.assist_button())
	await _close_shop()
	_game.new_game()


## Difficulty's rules: the day score's parts and weights (Assist presses left out,
## their weight shared out), the rating's moving average, the level's slopes (a
## struggling player still rises, more slowly than a strong one; a very low rating
## falls), its clamps, and each knob at the level's ends, clamped and monotonic.
func _test_difficulty_rules() -> void:
	var perfect := Difficulty.day_score([3, 0, 0, 0] as Array[int], 0, 0, [1.0, 1.0, 1.0] as Array[float], [1.0, 1.0] as Array[float])
	var nothing := Difficulty.day_score([0, 0, 0, 0] as Array[int], 2, 1, [0.0, 0.0] as Array[float], [] as Array[float])
	_check(is_equal_approx(perfect, 1.0) and is_equal_approx(nothing, 0.0), "difficulty: a flawless day scores 1, a day of storm-offs and refusals 0", "%f %f" % [perfect, nothing])
	var mixed := Difficulty.day_score([1, 1, 0, 0] as Array[int], 1, 1, [0.8, 0.4, 0.0] as Array[float], [0.9, 0.5] as Array[float])
	var grade := (1.0 + 0.67) / 4.0
	var expected := grade * Difficulty.WEIGHT_GRADE + 0.4 * Difficulty.WEIGHT_SPEED + 0.7 * Difficulty.WEIGHT_GESTURE
	_check(is_equal_approx(mixed, expected), "difficulty: the score blends mean grade, speed and gesture by their weights", "%f vs %f" % [mixed, expected])
	var assisted := Difficulty.day_score([2, 0, 0, 0] as Array[int], 0, 0, [0.5, 0.5] as Array[float], [] as Array[float])
	var renormalised := (1.0 * Difficulty.WEIGHT_GRADE + 0.5 * Difficulty.WEIGHT_SPEED) / (Difficulty.WEIGHT_GRADE + Difficulty.WEIGHT_SPEED)
	_check(is_equal_approx(assisted, renormalised), "difficulty: with no gesture played (all Assist) the gesture weight is shared out", "%f vs %f" % [assisted, renormalised])
	_check(is_equal_approx(Difficulty.next_rating(0.5, 1.0), 0.5 + 0.5 * Difficulty.RATING_SMOOTHING) and is_equal_approx(Difficulty.next_rating(0.5, 0.5), 0.5), "difficulty: the rating moves part of the way to the day's score", str(Difficulty.next_rating(0.5, 1.0)))
	var strong := Difficulty.next_level(0.0, 0.9)
	var struggling := Difficulty.next_level(0.0, 0.4)
	_check(struggling > 0.0 and strong > struggling, "difficulty: a struggling player's level still rises, slower than a strong player's", "%f vs %f" % [struggling, strong])
	_check(is_equal_approx(Difficulty.next_level(0.0, Difficulty.LOW_RATING), Difficulty.SLOPE_MIN) and is_equal_approx(Difficulty.next_level(0.0, 1.0), Difficulty.SLOPE_MAX), "difficulty: the slope runs from SLOPE_MIN at LOW_RATING to SLOPE_MAX at 1", "")
	_check(is_equal_approx(Difficulty.next_level(0.2, 0.1), 0.2 - Difficulty.FALL_STEP), "difficulty: under LOW_RATING the level falls", str(Difficulty.next_level(0.2, 0.1)))
	_check(is_equal_approx(Difficulty.next_level(Difficulty.LEVEL_MAX, 1.0), Difficulty.LEVEL_MAX) and is_equal_approx(Difficulty.next_level(Difficulty.LEVEL_MIN, 0.0), Difficulty.LEVEL_MIN), "difficulty: the level stays in LEVEL_MIN..LEVEL_MAX", "")
	var easy := Difficulty.LEVEL_MIN
	var hard := Difficulty.LEVEL_MAX
	_check(Difficulty.patience_scale(easy) > Difficulty.patience_scale(0.0) and Difficulty.patience_scale(0.0) > Difficulty.patience_scale(hard) and is_equal_approx(Difficulty.patience_scale(hard), Difficulty.PATIENCE_FLOOR) and Difficulty.patience_scale(easy) <= Difficulty.PATIENCE_CEILING and is_equal_approx(Difficulty.patience_scale(5.0), Difficulty.PATIENCE_FLOOR), "difficulty: patience shrinks with the level down to its floor", "%f %f" % [Difficulty.patience_scale(easy), Difficulty.patience_scale(hard)])
	_check(Difficulty.arrival_gap(easy) > Difficulty.arrival_gap(hard) and is_equal_approx(Difficulty.arrival_gap(hard), Difficulty.GAP_FLOOR) and is_equal_approx(Difficulty.arrival_gap(-5.0), Difficulty.GAP_CEILING), "difficulty: arrivals come closer with the level, clamped", "%f %f" % [Difficulty.arrival_gap(easy), Difficulty.arrival_gap(hard)])
	_check(Difficulty.tolerance_scale(easy) > 1.0 and is_equal_approx(Difficulty.tolerance_scale(0.0), 1.0) and is_equal_approx(Difficulty.tolerance_scale(hard), Difficulty.TOLERANCE_FLOOR) and is_equal_approx(Difficulty.tolerance_scale(5.0), Difficulty.TOLERANCE_FLOOR), "difficulty: tolerance tightens with the level, never under its floor", "%f %f" % [Difficulty.tolerance_scale(easy), Difficulty.tolerance_scale(hard)])
	var simple := Content.potion("stillwater_draught")
	var tough := Content.potion("embermoss_elixir")
	_check(is_equal_approx(Difficulty.hardness(simple), 0.0) and Difficulty.hardness(tough) > 0.5, "difficulty: hardness counts extra stations and ingredients", "%f %f" % [Difficulty.hardness(simple), Difficulty.hardness(tough)])
	var day := maxi(simple.unlock_day, tough.unlock_day) + 1
	_check(is_equal_approx(Difficulty.potion_weight(simple, 0.0, day), Difficulty.potion_weight(tough, 0.0, day)) and Difficulty.potion_weight(tough, hard, day) > Difficulty.potion_weight(simple, hard, day) and Difficulty.potion_weight(tough, easy, day) < Difficulty.potion_weight(simple, easy, day), "difficulty: level 0 picks evenly, harder levels lean to hard recipes, easier to easy ones", "")
	_check(is_equal_approx(Difficulty.potion_weight(tough, 0.0, tough.unlock_day), Difficulty.NEW_POTION_WEIGHT), "difficulty: a potion new that day weighs more", str(Difficulty.potion_weight(tough, 0.0, tough.unlock_day)))


## Shift.story at the kindest and the hardest level: patience, arrival gap and tolerance
## follow the level; every ordinary visitor slot is filled with a pinned request of an
## ordinary voice for a potion of the day (the day's new potions first); beats and
## authored customers are kept; the same day and level give the same customers.
func _test_difficulty_shift() -> void:
	var problems: Array[String] = []
	for spec in Content.days():
		var easy := Shift.story(spec.day, {}, Difficulty.LEVEL_MIN)
		var hard := Shift.story(spec.day, {}, Difficulty.LEVEL_MAX)
		if not (easy.patience_scale > hard.patience_scale and easy.arrival_gap(0) > hard.arrival_gap(0) and easy.tolerance_scale > hard.tolerance_scale):
			problems.append("day %d: knobs %s/%s %s/%s %s/%s" % [spec.day, easy.patience_scale, hard.patience_scale, easy.arrival_gap(0), hard.arrival_gap(0), easy.tolerance_scale, hard.tolerance_scale])
		var authored := Story.customers_of(spec, {})
		var again := Shift.story(spec.day, {}, Difficulty.LEVEL_MAX)
		var fresh := hard.allowed_potions.filter(func(potion: PotionType) -> bool: return potion.unlock_day == spec.day and not Rush.voices_for(potion).is_empty())
		var generated := 0
		for i in hard.customers.size():
			var visit := hard.customers[i]
			var slot := authored[i]
			if not slot.is_generated():
				if visit != slot:
					problems.append("day %d customer %d: the authored customer was replaced" % [spec.day, i])
				continue
			var line := Content.request(visit.request)
			if line == null or line.potion != visit.potion or line.archetype != visit.archetype or Content.archetype(visit.archetype).is_story() or not hard.allowed_potions.has(Content.potion(visit.potion)):
				problems.append("day %d visitor %d: %s/%s/%s" % [spec.day, i, visit.archetype, visit.potion, visit.request])
			if generated < fresh.size() and visit.potion != (fresh[generated] as PotionType).id:
				problems.append("day %d visitor %d: asks for %s before the new %s" % [spec.day, i, visit.potion, (fresh[generated] as PotionType).id])
			generated += 1
			if again.customers[i].request != visit.request:
				problems.append("day %d visitor %d: not the same on a second build" % [spec.day, i])
	_check(problems.is_empty(), "difficulty: every story day's shift follows its level, fills its visitor slots and replays alike", "\n".join(problems))


## Game.finish_day scores the day and moves the skill rating and the level (saved in
## hundredths, reloaded exactly); a new game starts them over; a Rush Hour run leaves them.
func _test_finish_day_moves_difficulty() -> void:
	_game.new_game()
	_check(is_equal_approx(_game.skill_rating, Difficulty.START_RATING) and is_equal_approx(_game.difficulty, Difficulty.START_LEVEL), "difficulty: a new game starts at the default rating and level", "%f %f" % [_game.skill_rating, _game.difficulty])
	var result := {"day": 1, "title": "t", "customers": 3, "served": 3, "stormed_off": 0, "refused": 0, "grades": [3, 0, 0, 0], "earned": 0, "tips": 0, "reputation": 0, "coins": _game.coins, "patience_left": [0.9, 0.9, 0.9], "gestures": [1.0, 1.0]}
	_game.finish_day(result, _game.coins, _game.stock, 0)
	await _game.transition_finished
	var rating := Difficulty.next_rating(Difficulty.START_RATING, Difficulty.day_score([3, 0, 0, 0] as Array[int], 0, 0, [0.9, 0.9, 0.9] as Array[float], [1.0, 1.0] as Array[float]))
	_check(is_equal_approx(_game.skill_rating, snappedf(rating, 0.01)) and _game.difficulty > Difficulty.START_LEVEL, "difficulty: a strong day raises the rating and the level", "%f %f" % [_game.skill_rating, _game.difficulty])
	var saved := _read_save()
	_check(saved.get("skill") == roundi(_game.skill_rating * 100) and saved.get("difficulty") == roundi(_game.difficulty * 100), "difficulty: rating and level are saved in hundredths", str(saved))
	var kept := [_game.skill_rating, _game.difficulty]
	_game.load_game()
	_check(is_equal_approx(_game.skill_rating, kept[0]) and is_equal_approx(_game.difficulty, kept[1]), "difficulty: a reload gives the same rating and level", "%f %f" % [_game.skill_rating, _game.difficulty])
	_game.finish_rush({"score": 5, "served": 1, "stormed_off": 4, "refused": 0, "grades": [0, 0, 0, 1], "tips": 0, "wave": 1, "assisted": false})
	await _game.transition_finished
	_check(is_equal_approx(_game.skill_rating, kept[0]) and is_equal_approx(_game.difficulty, kept[1]), "difficulty: a Rush Hour run leaves the rating and the level", "%f %f" % [_game.skill_rating, _game.difficulty])
	_game.new_game()
	_check(is_equal_approx(_game.skill_rating, Difficulty.START_RATING) and is_equal_approx(_game.difficulty, Difficulty.START_LEVEL), "difficulty: a new game starts them over", "%f %f" % [_game.skill_rating, _game.difficulty])
	_game.rush_best = 0
	_game.rush_best_assisted = false
	await _goto_scene(GameState.Flow.TITLE)


## The market before day 2: day-2 prices, unaffordable cards faded but tappable (a
## tap buys nothing and the info card says why), a tap buys one and saves, the
## Upgrades tab sells the next level until the top level, which is disabled.
func _test_market_purchases() -> void:
	var market := await _open_market(10)
	if market == null:
		return
	var spec := Content.day(2)
	var moonmoss := Content.ingredient("moonmoss")
	var price := Economy.market_price(spec, moonmoss)
	var on_sale := Content.ingredients_unlocked_by(2).all(func(item: Ingredient) -> bool: return market.stock_card(item.id) != null)
	var upgrades_match := Content.upgrades().all(func(u: Upgrade) -> bool: return (market.upgrade_card(u.id) != null) == (u.unlock_day <= 2))
	_check(on_sale and upgrades_match, "market sells day-2 ingredients and the upgrades unlocked by day 2", "upgrades %s" % str(Content.upgrades().map(func(u: Upgrade) -> bool: return market.upgrade_card(u.id) != null)))
	var ladle := Content.upgrade_for("stir")
	var ladle_card := market.upgrade_card(ladle.id)
	_check(ladle_card.modulate == Market.UNAFFORDABLE_TINT and not ladle_card.disabled and market.stock_card("moonmoss").modulate == Color.WHITE, "10 coins: the ladle (%d) is faded but tappable, moonmoss (%d) is not faded" % [ladle.costs[0], price], "%s %s %s" % [ladle_card.modulate, ladle_card.disabled, market.stock_card("moonmoss").modulate])
	await _tap(market.get_node("Column/Shop/Tabs/UpgradesTab") as Button)
	_game.sfx_log.clear()
	await _tap(ladle_card)
	_check(_game.sfx_log == ([&"nope"] as Array[StringName]), "a refused buy plays only its own sound", str(_game.sfx_log))
	var refusal := (market.get_node("Column/Info/Text") as Label).text
	_check(_game.coins == 10 and _game.upgrades.is_empty() and "Not enough coins" in refusal and ladle.name in refusal, "a tap on a faded card buys nothing and says why", "%d %s '%s'" % [_game.coins, _game.upgrades, refusal])
	await _tap(market.get_node("Column/Shop/Tabs/StockTab") as Button)
	_game.sfx_log.clear()
	await _tap(market.stock_card("moonmoss"))
	_check(_game.sfx_log == ([&"buy"] as Array[StringName]), "a buy plays only its own sound", str(_game.sfx_log))
	_check(_game.coins == 10 - price and _game.stock.get("moonmoss") == 1 and _read_save().get("coins") == float(10 - price), "a tap buys one moonmoss and saves", "%d %s" % [_game.coins, _game.stock])
	_check((market.get_node("Column/Coins/Amount") as Label).text == str(10 - price) and "Moonmoss" in (market.get_node("Column/Info/Text") as Label).text, "the coins and the info card update", (market.get_node("Column/Info/Text") as Label).text)
	await _tap(market.stock_card("moonmoss"))
	var left := 10 - 2 * price
	_check(_game.coins == left and (market.stock_card("moonmoss").modulate == Market.UNAFFORDABLE_TINT) == (left < price), "stock the coins no longer cover is faded", "%d %s" % [_game.coins, market.stock_card("moonmoss").modulate])
	market = await _open_market(ladle.costs[0] + ladle.costs[1])
	await _tap(market.get_node("Column/Shop/Tabs/UpgradesTab") as Button)
	_check((market.get_node("Column/Shop/UpgradeList") as Control).visible and not (market.get_node("Column/Shop/StockGrid") as Control).visible, "the Upgrades tab shows the upgrades", "hidden")
	var card := market.upgrade_card(ladle.id)
	_check((card.get_node("Text") as Label).text == "Balanced Ladle\nStir +25% easier", "an upgrade card shows its name and what the next level does", (card.get_node("Text") as Label).text)
	for level in ladle.max_level():
		await _tap(card)
		_check(_game.upgrades.get("stir") == level + 1, "a tap buys stir level %d" % (level + 1), str(_game.upgrades))
	_check(_game.coins == 0 and card.disabled and (card.get_node("Text") as Label).text == "Balanced Ladle\nStir +50% easier (max)" and _read_save().get("upgrades") == {"stir": 2.0}, "the top level is disabled and saved", "%d %s %s" % [_game.coins, card.disabled, _read_save().get("upgrades")])
	_game.goto(GameState.Flow.TITLE)
	await _game.transition_finished
	_game.new_game()


## A saved story past day 1: the title offers Continue (to the saved screen) and
## New game, which needs a second press; with the story over only "Story mode".
func _test_title_continue_and_new_game() -> void:
	_game.new_game()
	_game.day = 2
	_game.at_market = true
	_game.save_game()
	_game.load_game()
	var title: Title = await _goto_scene(GameState.Flow.TITLE)
	var open := title.get_node("Column/OpenShopButton") as Button
	var new_game := title.get_node("Column/NewGameButton") as Button
	_check(open.text == "Continue story" and new_game.visible and "day 2" in open.accessibility_name, "a saved day-2 story offers Continue and New game", "%s %s" % [open.text, new_game.visible])
	await _tap(open)
	_check(await _until(func() -> bool: return current_scene is Market and not _game.is_transitioning(), FLOW_FRAMES), "Continue resumes at the open market", str(current_scene))
	title = await _goto_scene(GameState.Flow.TITLE)
	new_game = title.get_node("Column/NewGameButton") as Button
	await _tap(new_game)
	await _frames(5)
	_check(_game.state == GameState.Flow.TITLE and _game.day == 2 and new_game.text == Title.NEW_GAME_CONFIRM_TEXT, "the first New game press only asks to confirm", "%s day %d '%s'" % [_game.state, _game.day, new_game.text])
	_check(new_game.size.x == 190.0 and new_game.get_theme_font_size(&"font_size") == Title.NEW_GAME_CONFIRM_FONT_SIZE, "the confirm text keeps the button 190 wide in a smaller font", "%s at size %d" % [new_game.size, new_game.get_theme_font_size(&"font_size")])
	await _tap(new_game)
	_check(await _until(func() -> bool: return current_scene is Morning and not _game.is_transitioning(), FLOW_FRAMES) and _game.day == 1 and _game.coins == Content.day(1).starting_coins, "the second press starts a new game at the morning of day 1", "%s day %d" % [current_scene, _game.day])
	_game.day = Content.days().size() + 1
	_game.at_market = false
	title = await _goto_scene(GameState.Flow.TITLE)
	_check((title.get_node("Column/OpenShopButton") as Button).text == "Story mode" and not (title.get_node("Column/NewGameButton") as Button).visible, "after the last story day the title starts a new game", (title.get_node("Column/OpenShopButton") as Button).text)
	_game.new_game()
	await _goto_scene(GameState.Flow.TITLE)


func _test_morning_missing_day_returns_to_title() -> void:
	_game.new_game()
	_game.day = Content.days().size() + 1
	_game.quiet_errors = true
	Content.quiet_errors = true
	var errors := _game.reported_errors.size()
	_game.goto(GameState.Flow.MORNING)
	var back := await _until(func() -> bool: return _game.state == GameState.Flow.TITLE and not _game.is_transitioning() and _game.reported_errors.size() > errors, FLOW_FRAMES)
	_game.quiet_errors = false
	Content.quiet_errors = false
	_check(back and _game.reported_errors.size() == errors + 1 and ("Day %d" % _game.day) in _game.reported_errors.back(), "a morning for a missing day returns to the title with the reason", str(_game.reported_errors.slice(errors)))
	(_game.get_node("Fade/ErrorLabel") as Label).hide()
	_game.new_game()


## The morning, summary and market buttons (both tabs) and the title's Continue
## and New game: each at least 32x32, inside the safe area, in the thumb zone and
## focusable with an accessibility name, at 9:16, 9:19.5 and 16:9.
func _test_loop_screens_size_and_zone() -> void:
	var screens: Array[Array] = [
		[GameState.Flow.MORNING, {}, ["Column/OpenShopButton", "Column/CodexButton"]],
		[GameState.Flow.SUMMARY, {"day": 1, "title": "Test", "customers": 3, "served": 2, "stormed_off": 1, "refused": 1, "grades": [1, 1, 0, 0], "earned": 20, "tips": 2, "reputation": 1, "coins": 42}, ["Column/Layout/ContinueButton"]],
		[GameState.Flow.MARKET, {}, ["Column/Shop/Tabs/StockTab", "Column/Shop/Tabs/UpgradesTab", "Column/Shop/CodexButton", "Column/Shop/NextDayButton"]],
		[GameState.Flow.TITLE, {}, ["Column/OpenShopButton", "Column/NewGameButton"]],
	]
	for screen in screens:
		_game.new_game()
		_game.day = 2
		_game.at_market = true
		_game.coins = 500
		var scene := await _goto_scene(screen[0], screen[1])
		var controls: Array[Control] = []
		for path: String in screen[2]:
			controls.append(scene.get_node(path) as Control)
		if scene is Market:
			for item in Content.ingredients_unlocked_by(2):
				controls.append((scene as Market).stock_card(item.id))
		# The morning's menu icon sits in the top-right corner like the shop's.
		var top_right := scene.get_node_or_null("Column/PauseButton") as Control if scene is Morning else null
		if top_right != null:
			controls.append(top_right)
		var name: String = GameState.Flow.keys()[screen[0]]
		for control in controls:
			_check(control.focus_mode == Control.FOCUS_ALL and control.accessibility_name != "", "%s %s focusable and named" % [name, control.name], control.accessibility_name)
		for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
			root.size = window
			await _frames(10)
			_check_targets(controls, top_right, "%s at %s" % [name, window])
			if top_right != null:
				var rect := top_right.get_global_rect()
				var column := _game.column_rect()
				_check(rect.end.x <= column.end.x and rect.position.x >= column.end.x - 118.0 and rect.end.y <= column.position.y + 48.0, "%s menu icon in the column's top-right corner at %s" % [name, window], "%s in %s" % [rect, column])
			if scene is Market:
				await _tap(scene.get_node("Column/Shop/Tabs/UpgradesTab") as Button)
				var upgrades: Array[Control] = []
				for upgrade in Content.upgrades():
					if (scene as Market).upgrade_card(upgrade.id) != null:
						upgrades.append((scene as Market).upgrade_card(upgrade.id))
				_check_targets(upgrades, null, "%s upgrades at %s" % [name, window])
				await _tap(scene.get_node("Column/Shop/Tabs/StockTab") as Button)
		root.size = BASE_WINDOW
		await process_frame
	_game.new_game()
	await _goto_scene(GameState.Flow.TITLE)


## The morning's menu icon (playtest 2026-10-19): a tap opens the settings panel titled
## "Menu" with Close focused, Escape closes it and focus returns to the icon, and Quit
## to title goes to the title.
func _test_morning_menu() -> void:
	_game.new_game()
	var morning := await _goto_scene(GameState.Flow.MORNING) as Morning
	var icon := morning.get_node("Column/PauseButton") as Button
	var menu := morning.get_node("Menu") as SettingsPanel
	_check(icon.accessibility_name == "Menu" and (icon.get_node("Icon") as TextureRect).texture != null, "morning menu icon drawn and named", icon.accessibility_name)
	await _tap(icon)
	_check(menu.is_open() and (morning.get_node("Menu/Panel/List/Title") as Label).text == "Menu", "a tap on the morning's menu icon opens the Menu panel", str(menu.is_open()))
	_check(root.gui_get_focus_owner() == morning.get_node("Menu/Panel/List/CloseButton"), "the morning menu focuses Close", str(root.gui_get_focus_owner()))
	await _key(KEY_ESCAPE)
	_check(not menu.is_open() and root.gui_get_focus_owner() == icon, "Escape closes the morning menu and focus returns to the icon", "%s %s" % [menu.is_open(), root.gui_get_focus_owner()])
	await _tap(icon)
	await _tap(morning.get_node("Menu/Panel/List/QuitButton") as Button)
	_check(await _until(func() -> bool: return current_scene is Title and not _game.is_transitioning(), FLOW_FRAMES), "Quit to title from the morning menu goes to the title", str(current_scene))


## Opens the market before day 2 with `coins` coins and no stock.
func _open_market(coins: int) -> Market:
	_game.new_game()
	_game.day = 2
	_game.at_market = true
	_game.coins = coins
	_game.stock = {}
	var market: Market = await _goto_scene(GameState.Flow.MARKET)
	_check(market != null, "the market opens", str(current_scene))
	return market


func _goto_scene(state: GameState.Flow, args: Dictionary = {}) -> Node:
	_game.goto(state, args)
	await _game.transition_finished
	return current_scene


func _read_save() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_game.save_path))
	return data if data is Dictionary else {}


func _write_save(text: String) -> void:
	var file := FileAccess.open(_game.save_path, FileAccess.WRITE)
	if file == null:
		_check(false, "write the test save", error_string(FileAccess.get_open_error()))
		return
	file.store_string(text)
	file.close()


func _with(data: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy := data.duplicate(true)
	copy[key] = value
	return copy


func _without(data: Dictionary, key: String) -> Dictionary:
	var copy := data.duplicate(true)
	copy.erase(key)
	return copy


## Texts of the "+pay" labels flying in the shop's Fx layer.
func _pay_texts(shop: Shop) -> PackedStringArray:
	var texts := PackedStringArray()
	for node in shop.get_node("Fx").get_children():
		if node is Label and (node as Label).text.begins_with("+"):
			texts.append((node as Label).text)
	return texts


## Opens the shop on a fresh day 1 (a new game in the tool save).
func _open_shop() -> Shop:
	_game.new_game()
	_game.goto(GameState.Flow.SHOP)
	await _game.transition_finished
	return current_scene as Shop


## Removes the tool save and its corrupt-save backup.
func _delete_saves() -> void:
	for path: String in [_game.save_path, _game.backup_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


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
		await _tap_item(shop, id)
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


## Fills the patience of everyone in line, so slow test steps make no one storm off.
func _refill_patience(shop: Shop) -> void:
	for visitor: Customer in [shop.customer] + shop.queue:
		if visitor != null:
			visitor.patience_left = visitor.patience_total


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


## Rush Hour rules (Rush, Shift.rush): the spawn curve's ends and floors, the waves
## and their potions (Stir and Pour first, then Mortar, Bellows, all 17), ordinary
## voices only, a seed's customers repeating, and 60 customers of a run in distinct looks.
func _test_rush_rules() -> void:
	_check(is_equal_approx(Rush.arrival_gap(0), Rush.GAP_START) and is_equal_approx(Rush.arrival_gap(1000), Rush.GAP_FLOOR) and Rush.arrival_gap(10) < Rush.arrival_gap(9), "rush: the arrival gap shrinks from its start to its floor", "%s %s" % [Rush.arrival_gap(0), Rush.arrival_gap(1000)])
	_check(is_equal_approx(Rush.patience_scale(0), Rush.PATIENCE_START) and is_equal_approx(Rush.patience_scale(1000), Rush.PATIENCE_FLOOR) and Rush.patience_scale(10) < Rush.patience_scale(9), "rush: patience shrinks from its start to its floor", "%s %s" % [Rush.patience_scale(0), Rush.patience_scale(1000)])
	_check([Rush.wave(0), Rush.wave(Rush.WAVE_SIZE - 1), Rush.wave(Rush.WAVE_SIZE), Rush.wave(Rush.WAVE_SIZE * 3), Rush.wave(1000)] == [0, 0, 1, 3, 3], "rush: a wave every WAVE_SIZE served, the last one lasts", str([Rush.wave(0), Rush.wave(Rush.WAVE_SIZE), Rush.wave(1000)]))
	var stations: Array[Array] = [["stir", "pour"], ["stir", "pour", "mortar"], ["stir", "pour", "mortar", "bellows"], ["stir", "pour", "mortar", "bellows"]]
	var previous := 0
	for index in Rush.WAVE_DAYS.size():
		var potions := Rush.potions_of_wave(index)
		var steps := {}
		for potion in potions:
			for step in potion.steps:
				steps[step] = true
		var newest: String = stations[index].back()
		_check(potions.size() > previous and steps.keys().all(func(step: String) -> bool: return step in stations[index]) and steps.has(newest), "rush: wave %d adds potions, stations %s" % [index + 1, stations[index]], "%d potions, steps %s" % [potions.size(), steps.keys()])
		previous = potions.size()
	_check(Rush.potions_of_wave(Rush.WAVE_DAYS.size() - 1).size() == Content.potions().size(), "rush: the last wave allows all %d potions" % Content.potions().size(), str(Rush.potions_of_wave(3).size()))
	var config := Shift.rush(11)
	_check(config.is_rush() and config.run_seed == 11 and config.customers.is_empty() and config.ingredients.size() == Content.ingredients().size() and is_equal_approx(config.patience_scale, Rush.PATIENCE_START), "rush: Shift.rush puts every ingredient on the shelf, no fixed customers", str(config.ingredients.size()))
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = 11
	second.seed = 11
	var taken := {}
	var taken_again := {}
	var problems: Array[String] = []
	for n in 60:
		var served := n
		var visit := Rush.customer(first, served)
		var again := Rush.customer(second, served)
		var who := Content.archetype(visit.archetype)
		var potion := Content.potion(visit.potion)
		if visit.archetype != again.archetype or visit.potion != again.potion or visit.request != again.request:
			problems.append("customer %d differs for the same seed" % n)
		if who == null or who.is_story() or not potion in Rush.potions_of_wave(Rush.wave(served)) or not Content.requests_for(visit.potion, visit.archetype).has(Content.request(visit.request)):
			problems.append("customer %d: %s wants %s (request %s)" % [n, visit.archetype, visit.potion, visit.request])
		var part_names: Array[String] = []
		part_names.assign(Customer.parts_of(who))
		var look := Look.next_distinct(part_names, first, taken, n)
		var look_again := Look.next_distinct(part_names, second, taken_again, n)
		if taken.size() != n + 1:
			problems.append("customer %d repeats a look %s" % [n, look.describe()])
		if look.describe() != look_again.describe():
			problems.append("customer %d looks different for the same seed" % n)
	_check(problems.is_empty(), "rush: 60 customers (voice, potion, request line, look) repeat for a seed, are ordinary voices of their wave's potions, in distinct looks", "\n".join(problems))
	_check([Rush.reputation_delta(Brew.Grade.PERFECT), Rush.reputation_delta(Brew.Grade.GOOD), Rush.reputation_delta(Brew.Grade.MEH), Rush.reputation_delta(Brew.Grade.MISBREW)] == [0, 0, 0, Economy.reputation_delta(Brew.Grade.MISBREW)] and Economy.reputation_delta(Brew.Grade.MISBREW) < 0, "rush: serves never raise the run's reputation, a Misbrew still costs", "")
	_check(Rush.WAVE_NAMES.size() == Rush.WAVE_DAYS.size() and Rush.WAVE_NOTES.size() == Rush.WAVE_DAYS.size() and Rush.WAVE_NAMES.all(func(name: String) -> bool: return RegEx.create_from_string("[0-9]").search(name) == null and name == name.to_upper()), "rush: every wave has a banner name (capitals, no digits: Silkscreen) and a note", str(Rush.WAVE_NAMES))


## Every ingredient, three of each (recipes for an unlimited Rush Hour shelf).
func _rush_stock() -> Dictionary[String, int]:
	var stock: Dictionary[String, int] = {}
	for item in Content.ingredients():
		stock[item.id] = 3
	return stock


## A Rush Hour run in the shop: the run's reputation and score on the HUD, an unlimited
## shelf (paged, no counts), a served customer starting wave 2, then a storm-off mid-brew
## taking the reputation to 0: the station is dropped, the line walks out, the results
## show the score as the new best (assisted), saved; the story's coins, stock and
## reputation are untouched.
func _test_shop_rush_run() -> void:
	_game.new_game()
	_game.rush_hour_unlocked = true
	_game.rush_best = 0
	_game.rush_best_assisted = false
	_game.assist_mode = true
	var story := [_game.coins, _game.stock.duplicate(), _game.reputation, _game.day]
	var shop := await _goto_scene(GameState.Flow.SHOP, {"rush": 7}) as Shop
	var reputation_label := shop.get_node("Column/Hud/Reputation") as Label
	var served_label := shop.get_node("Column/Hud/Served") as Label
	_check(shop.shift.is_rush() and shop.reputation == Rush.START_REPUTATION and shop.coins == 0, "rush run: starts at reputation %d and 0 coins" % Rush.START_REPUTATION, "%d %d" % [shop.reputation, shop.coins])
	_check(reputation_label.visible and reputation_label.text == str(Rush.START_REPUTATION) and (shop.get_node("Column/Hud/ReputationIcon") as TextureRect).visible and "Reputation" in reputation_label.accessibility_name, "rush run: the HUD shows the run's reputation with a heart", reputation_label.text)
	var unlimited := Content.ingredients().all(func(item: Ingredient) -> bool:
		var shelf := shop.shelf_item(item.id)
		return shelf != null and shelf.stock == ShelfItem.UNLIMITED and not shelf.disabled and not (shelf.get_node("Count") as Label).visible and "unlimited" in shelf.accessibility_name)
	_check(unlimited and (shop.get_node("Column/Stage/ShelfNext") as Button).visible, "rush run: every ingredient on a paged shelf, unlimited, no counts", str(shop.stock))
	var banner := shop.get_node_or_null("Column/Stage/WaveBanner") as PanelContainer
	_check(banner != null and banner.visible and (banner.get_node("List/Name") as Label).text == Rush.WAVE_NAMES[0] and (banner.get_node("List/Note") as Label).text == Rush.WAVE_NOTES[0] and banner.mouse_filter == Control.MOUSE_FILTER_IGNORE, "rush run: the run opens with the wave one banner (takes no input)", str(banner))
	if await _wait_for_order(shop, "rush run"):
		_check(not shop.customer.archetype.is_story() and shop.customer.potion in Rush.potions_of_wave(0), "rush run: the first customer is an ordinary voice asking for a wave-1 potion", "%s %s" % [shop.customer.archetype.id, shop.customer.potion.id])
		shop.served = Rush.WAVE_SIZE - 1
		var recipe := _exact_recipe(shop.customer.potion, _rush_stock())
		_game.sfx_log.clear()
		# An empty Codex, so this serve teaches it something and "Codex +N" pops.
		_game.codex = {}
		await _serve(shop, recipe, "rush run")
		var pops := shop.get_node("Fx").get_children().filter(func(node: Node) -> bool: return node is Label and (node as Label).text.begins_with("Codex +"))
		var page_label := shop.get_node("Column/Stage/ShelfPage") as Control
		_check(pops.size() == 1 and page_label.visible, "rush run: Codex +N pops with the shelf page label showing", "%d pops" % pops.size())
		if pops.size() == 1:
			var pop := pops[0] as Label
			# The pop's whole path: its full-size rect and the 14 units it rises (Juice.pop_text).
			var path := Rect2(pop.position, pop.size).grow_side(SIDE_TOP, 14.0)
			var next_arrow := shop.get_node("Column/Stage/ShelfNext") as Control
			_check(not path.intersects(page_label.get_global_rect()) and not path.intersects(next_arrow.get_global_rect()), "rush run: Codex +N clears the shelf page label and the Next arrow", "%s vs %s, %s" % [path, page_label.get_global_rect(), next_arrow.get_global_rect()])
		_check(_heard(&"wave"), "rush run: a new wave plays its stinger", str(_game.sfx_log))
		_check(shop.coins > 0 and "wave 2" in served_label.text, "rush run: a serve pays into the score and starts wave 2", "%d coins, %s" % [shop.coins, served_label.text])
		_check(shop.reputation == Rush.START_REPUTATION and reputation_label.text == str(Rush.START_REPUTATION), "rush run: a good serve leaves the run's reputation where it was", "%d" % shop.reputation)
		var stamp := shop.get_node("Column/Stage/Stamp") as Control
		# Both have settled from their pop-in scale (the banner holds WAVE_BANNER_HOLD).
		await _frames(30)
		_check(banner.visible and (banner.get_node("List/Name") as Label).text == Rush.WAVE_NAMES[1] and (banner.get_node("List/Note") as Label).text == Rush.WAVE_NOTES[1], "rush run: wave two is announced on the banner with what it adds", (banner.get_node("List/Name") as Label).text)
		_check(not banner.get_global_rect().intersects(stamp.get_global_rect()) and not banner.get_global_rect().intersects(shop.slot_button(0).get_global_rect()), "rush run: the wave banner clears the grade stamp and the pot slots", "%s vs %s" % [banner.get_global_rect(), stamp.get_global_rect()])
		_check(shop.stock.values().all(func(count: int) -> bool: return count == ShelfItem.UNLIMITED), "rush run: brewing never uses up the shelf", str(shop.stock))
		_refill_patience(shop)
	await _skip_lines(shop)
	if await _wait_for_order(shop, "rush run, second customer"):
		var score := shop.coins
		for id in _recipe_between(shop.customer.potion, _rush_stock(), 0):
			await _tap_item(shop, id)
		await _tap(shop.brew_button())
		var brewing := await _until(func() -> bool: return shop.station != null and shop.station.is_running(), FLOW_FRAMES)
		_check(brewing, "rush run: the second brew starts a station", str(shop.station))
		shop.reputation = 1
		shop.customer.patience_left = 0.01
		_game.sfx_log.clear()
		var over := await _until(func() -> bool: return shop.station == null and shop.reputation <= 0, FLOW_FRAMES)
		_check(_heard(&"rush_over") and _heard(&"storm_off"), "rush run: the run's end plays the storm-off and the run-over sting", str(_game.sfx_log))
		var walking := ([shop.customer] + shop.queue).all(func(visitor: Customer) -> bool: return visitor == null or visitor.state == Customer.State.LEAVE or visitor.state == Customer.State.GONE)
		_check(over and walking and shop.brew_button().disabled, "rush run: reputation 0 mid-brew drops the station and the line walks out", "station %s, reputation %d" % [shop.station, shop.reputation])
		var results := await _until(func() -> bool: return current_scene is Results and not _game.is_transitioning(), FLOW_FRAMES)
		var args := _game.flow_args
		_check(results and int(args.get("score", -1)) == score and args.get("new_best") == true and int(args.get("best", -1)) == score and args.get("assisted") == true, "rush run: the results show the score as the new best, assisted", str(args))
		_check(_game.rush_best == score and _game.rush_best_assisted and int(_read_save().get("rush_best", -1)) == score and _read_save().get("rush_best_assisted") == true, "rush run: the best and its assisted marker are saved", "%d %s" % [_game.rush_best, _game.rush_best_assisted])
		_check(results and (current_scene.get_node("Column/Layout/Header/NewBest") as Label).visible and root.gui_get_focus_owner() == current_scene.get_node("Column/Layout/AgainButton"), "rush run: New best! shows and Again has focus", str(root.gui_get_focus_owner()))
	_check([_game.coins, _game.stock, _game.reputation, _game.day] == story, "rush run: the story's coins, stock, reputation and day are untouched", "%s vs %s" % [[_game.coins, _game.stock, _game.reputation, _game.day], story])
	_game.assist_mode = false
	await _goto_scene(GameState.Flow.TITLE)


## The Rush Hour entry and results screens: the Rush Hour button shows from the first
## launch (no story needed) with no best line until a run has set one; then the best
## line (assisted marked) shows too, 32x32+ in
## the thumb zone at 9:16, 9:19.5 and 16:9, and start a run; quitting a run records
## nothing; the results' Again and Title buttons fit the same rules and work; a lower
## score keeps the best.
func _test_rush_screens() -> void:
	_game.new_game()
	_game.rush_hour_unlocked = false
	var title := await _goto_scene(GameState.Flow.TITLE)
	_game.rush_best = 0
	var new_title := await _goto_scene(GameState.Flow.TITLE)
	_check((new_title.get_node("Column/RushButton") as Button).visible and not (new_title.get_node("Column/RushButton") as Button).disabled and not (new_title.get_node("Column/RushBest") as Label).visible, "rush screens: Rush Hour on the title from the first launch, no best line before a run", "")
	var story := new_title.get_node("Column/OpenShopButton") as Control
	_check(story.get_global_rect().end.y <= (new_title.get_node("Column/RushButton") as Control).get_global_rect().position.y, "rush screens: the story button sits above Rush Hour", "%s / %s" % [story.get_global_rect(), (new_title.get_node("Column/RushButton") as Control).get_global_rect()])
	_game.rush_best = 40
	_game.rush_best_assisted = true
	title = await _goto_scene(GameState.Flow.TITLE)
	var rush := title.get_node("Column/RushButton") as Button
	var best := title.get_node("Column/RushBest") as Label
	_check(rush.visible and best.visible and best.text == "Best: 40 coins (assisted)" and rush.focus_mode == Control.FOCUS_ALL and rush.accessibility_name != "", "rush screens: the title shows Rush Hour and the best, assisted marked", best.text)
	var results := {"score": 25, "served": 3, "stormed_off": 2, "refused": 1, "grades": [1, 2, 0, 0], "tips": 4, "wave": 1, "assisted": false}
	for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
		root.size = window
		await _frames(10)
		_check_targets([rush, title.get_node("Column/OpenShopButton") as Control], null, "rush screens: title at %s" % window)
		_check(not rush.get_global_rect().intersects((title.get_node("Column/OpenShopButton") as Control).get_global_rect()) and not best.get_global_rect().intersects((title.get_node("Column/OpenShopButton") as Control).get_global_rect()), "rush screens: Rush Hour and its best clear Open the shop at %s" % window, "")
	root.size = BASE_WINDOW
	await _frames(5)
	await _tap(rush)
	var shop := await _until(func() -> bool: return current_scene is Shop and not _game.is_transitioning(), FLOW_FRAMES)
	_check(shop and (current_scene as Shop).shift.is_rush(), "rush screens: the Rush Hour button starts a run", str(current_scene))
	if shop:
		(current_scene as Shop).open_pause()
		await _frames(3)
		await _tap(current_scene.get_node("Modal/Panel/List/QuitButton") as Button)
		await _until(func() -> bool: return current_scene is Title and not _game.is_transitioning(), FLOW_FRAMES)
		_check(current_scene is Title and _game.rush_best == 40 and _game.rush_best_assisted, "rush screens: quitting a run goes to the title and records nothing", "best %d" % _game.rush_best)
	_game.finish_rush(results)
	await _game.transition_finished
	var screen := current_scene as Results
	_check(screen != null and _game.rush_best == 40 and _game.rush_best_assisted and not (screen.get_node("Column/Layout/Header/NewBest") as Label).visible and (screen.get_node("Column/Layout/Best") as Label).text == "Best: 40 coins (assisted)", "rush screens: a lower score keeps the best (and its marker)", str(_game.flow_args))
	if screen != null:
		var buttons: Array[Control] = [screen.get_node("Column/Layout/AgainButton") as Control, screen.get_node("Column/Layout/TitleButton") as Control]
		for control in buttons:
			_check(control.focus_mode == Control.FOCUS_ALL and (control as Button).accessibility_name != "", "rush screens: results %s focusable and named" % control.name, "")
		for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
			root.size = window
			await _frames(10)
			_check_targets(buttons, null, "rush screens: results at %s" % window)
		root.size = BASE_WINDOW
		await _frames(5)
		await _until(func() -> bool: return not screen.is_tallying(), FLOW_FRAMES)
		await _tap(buttons[0])
		var again := await _until(func() -> bool: return current_scene is Shop and not _game.is_transitioning(), FLOW_FRAMES)
		_check(again and (current_scene as Shop).shift.is_rush(), "rush screens: Again starts a new run", str(current_scene))
		_game.finish_rush(results)
		await _game.transition_finished
		(current_scene as Results).complete_tally()
		await _tap(current_scene.get_node("Column/Layout/TitleButton") as Button)
		_check(await _until(func() -> bool: return current_scene is Title and not _game.is_transitioning(), FLOW_FRAMES), "rush screens: Title goes back to the title", str(current_scene))
	_game.new_game()


## Keyboard only: from the title, Up and Enter start Rush Hour with Assist off; Assist
## is switched on mid-run from the pause menu (so the run counts as assisted); a
## customer is served by keys (shelf items, Brew, each station's Assist button); with
## the run's reputation at 1 the Refuse button ends it; the results' Again has focus,
## the run is marked assisted, and Title is reachable by keys.
func _test_rush_keyboard_assist() -> void:
	_game.new_game()
	_game.rush_hour_unlocked = true
	_game.assist_mode = false
	var title := await _goto_scene(GameState.Flow.TITLE)
	var on_rush := await _focus_by_keys(title.get_node("Column/RushButton") as Button)
	await _action(&"ui_accept")
	var in_shop := on_rush and await _until(func() -> bool: return current_scene is Shop and not _game.is_transitioning(), FLOW_FRAMES)
	_check(in_shop and (current_scene as Shop).shift.is_rush(), "rush keys: Up and Enter on the title start Rush Hour", str(root.gui_get_focus_owner()))
	if not in_shop:
		_game.assist_mode = false
		return
	var shop := current_scene as Shop
	if await _wait_for_order(shop, "rush keys"):
		var assist_row := shop.get_node("Modal/Panel/List/AssistRow/AssistButton") as Button
		var menu := shop.get_node("Column/Hud/PauseButton") as Button
		for i in 20:
			if root.gui_get_focus_owner() == menu:
				break
			await _action(&"ui_focus_prev")
		var on_menu := root.gui_get_focus_owner() == menu
		await _action(&"ui_accept")
		var on_assist := await _focus_by_keys(assist_row)
		await _action(&"ui_accept")
		var on_resume := await _focus_by_keys(shop.get_node("Modal/Panel/List/ResumeButton") as Button)
		await _action(&"ui_accept")
		_check(on_menu and on_assist and on_resume and _game.assist_mode and not paused, "rush keys: Assist switched on mid-run from the pause menu", "%s %s %s assist %s" % [on_menu, on_assist, on_resume, _game.assist_mode])
		_refill_patience(shop)
		var served := shop.served
		for id in _exact_recipe(shop.customer.potion, _rush_stock()):
			shop.show_shelf_item(shop.shelf_item(id))
			var focused := await _focus_by_keys(shop.shelf_item(id))
			await _action(&"ui_accept")
			_check(focused, "rush keys: ui_accept adds %s" % id, str(root.gui_get_focus_owner()))
		var on_brew := await _focus_by_keys(shop.brew_button())
		await _action(&"ui_accept")
		_check(on_brew and shop.is_brewing(), "rush keys: Enter on Brew brews", str(root.gui_get_focus_owner()))
		for step in shop.customer.potion.steps:
			var ready := await _until(func() -> bool: return shop.station != null and shop.station.is_running() and shop.station.assist_button() != null and shop.station.assist_button().has_focus(), FLOW_FRAMES)
			if not ready:
				break
			await _action(&"ui_accept")
		_check(await _until(func() -> bool: return shop.served == served + 1, FLOW_FRAMES), "rush keys: served by keys with Assist", "served %d" % shop.served)
	_refill_patience(shop)
	await _skip_lines(shop)
	if await _wait_for_order(shop, "rush keys, second customer"):
		shop.reputation = 1
		var refuse := shop.get_node("Column/Stage/RefuseButton") as Button
		var on_refuse := await _focus_by_keys(refuse)
		await _action(&"ui_accept")
		var results := on_refuse and await _until(func() -> bool: return current_scene is Results and not _game.is_transitioning(), FLOW_FRAMES)
		_check(results and root.gui_get_focus_owner() == current_scene.get_node("Column/Layout/AgainButton") and _game.flow_args.get("assisted") == true, "rush keys: refusing at reputation 1 ends the run on the results, Again focused", str(root.gui_get_focus_owner()))
		if results:
			# Enter on Again during the tally completes it rather than starting a run.
			await _action(&"ui_accept")
			_check(current_scene is Results and not (current_scene as Results).is_tallying() and not _game.is_transitioning(), "rush keys: the first Enter completes the results' tally", str(current_scene))
			var on_title := await _focus_by_keys(current_scene.get_node("Column/Layout/TitleButton") as Button)
			await _action(&"ui_accept")
			_check(on_title and await _until(func() -> bool: return current_scene is Title and not _game.is_transitioning(), FLOW_FRAMES), "rush keys: Down and Enter on Title go back to the title", str(current_scene))
	_game.assist_mode = false
	await _goto_scene(GameState.Flow.TITLE)


## A sample day result for the summary tests (Shop.day_result() keys).
const SAMPLE_DAY := {"day": 3, "title": "The Guild Comes Calling", "customers": 6, "served": 4, "stormed_off": 1, "refused": 1, "grades": [1, 2, 1, 0], "earned": 63, "tips": 7, "reputation": -2, "coins": 142}
## A sample run result for the results tests (Shop.rush_result() plus Game.finish_rush).
const SAMPLE_RUN := {"score": 238, "served": 14, "stormed_off": 2, "refused": 1, "grades": [3, 8, 2, 1], "tips": 19, "wave": 3, "assisted": true, "best": 238, "best_assisted": true, "new_best": true}


## A stat tile stays TILE_WIDTH wide and shows its number whole up to 6 digits plus a
## sign; count_up() ends on the exact value.
func _test_stat_tile_fits() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	root.add_child(grid)
	var tiles := Summary.add_tiles(grid, [["coin_0", "Coins earned", -999999, "%+d", "now -999999"], ["icon_tips", "Tips", 999999, "%+d", ""]])
	await _frames(2)
	for stat in tiles:
		var number := stat.get_node("List/Number") as Label
		var whole := number.get_minimum_size().x <= number.size.x and number.size.x <= stat.size.x and number.get_line_count() == 1
		_check(is_equal_approx(stat.size.x, StatTile.TILE_WIDTH) and whole, "stat tile %s: %s fits in %d" % [stat.name, stat.number_text(), int(StatTile.TILE_WIDTH)], "tile %s, number %s needs %s" % [stat.size, number.size, number.get_minimum_size()])
	_check(tiles[0].number_text() == "-999999" and tiles[1].number_text() == "+999999" and tiles[0].sub_text() == "now -999999", "stat tile: final texts", "%s %s" % [tiles[0].number_text(), tiles[1].number_text()])
	tiles[0].count_up(0.2)
	await _frames(3)
	var counting := tiles[0].is_counting() and tiles[0].number_text() != tiles[0].final_text()
	await _until(func() -> bool: return not tiles[0].is_counting(), 60)
	_check(counting and tiles[0].number_text() == "-999999", "stat tile: count_up counts and ends on the exact value", tiles[0].number_text())
	grid.queue_free()
	await process_frame


## The summary: tiles, grade row, counts and till for a sample day; the reveal hides
## them, runs by itself within Tally.MAX_TIME and ends on the exact numbers; a tap
## outside the button completes it at once (staying on the summary); Enter on the
## focused button completes it first, a second Enter goes to the market.
func _test_summary_tally() -> void:
	_game.new_game()
	_game.day = 4
	_game.at_market = true
	_game.reputation = 12
	_game.goto(GameState.Flow.SUMMARY, SAMPLE_DAY)
	var frames := 0
	while current_scene is not Summary and frames < FLOW_FRAMES:
		await process_frame
		frames += 1
	var summary := current_scene as Summary
	if summary == null:
		_check(false, "summary: opens", str(current_scene))
		return
	# Timed from the scene's arrival (its _ready starts the tally).
	await process_frame
	_game.sfx_log.clear()
	frames = 1
	var hidden := summary.is_tallying() and summary.tile("Served").modulate.a == 0.0 and (summary.get_node("Column/Layout/Grades") as CanvasItem).modulate.a == 0.0
	while summary.is_tallying() and frames < FLOW_FRAMES:
		await process_frame
		frames += 1
	_check(hidden and frames <= ceili(Tally.MAX_TIME * 60.0), "summary: the tally starts hidden and finishes by itself within %.1f s" % Tally.MAX_TIME, "%d frames, hidden at start %s" % [frames, hidden])
	_check(_tile_texts(summary) == ["4/6", "+63", "+7", "-2 now 12"], "summary: each tile's final text", str(_tile_texts(summary)))
	var ticks := _game.sfx_log.count(&"coin_tick")
	_check(ticks >= 4 and ticks <= ceili(Tally.MAX_TIME / GameState.SFX_MIN_GAP) and _heard(&"coins"), "summary: the tally ticks as it counts (throttled) and the coins tile jingles", "%d ticks, %s" % [ticks, _game.sfx_log])
	_check(_grade_texts(summary) == PackedStringArray(["Perfect 1", "Good 2", "Meh 1", "Misbrew 0"]), "summary: the grade row", str(_grade_texts(summary)))
	var icons_ok := true
	for grade in Summary.GRADE_WORDS.size():
		icons_ok = icons_ok and (summary.get_node("Column/Layout/Grades/Row/%s/Icon" % Summary.GRADE_WORDS[grade]) as TextureRect).texture == Art.texture("ui", Shop.STAMP_ICONS[grade])
	_check(icons_ok, "summary: each grade shows its stamp icon", "")
	var rows := [_row_text(summary, "Counts/StormedOff"), _row_text(summary, "Counts/Refused"), _row_text(summary, "Till")]
	var row_icons := (summary.get_node("Column/Layout/Counts/StormedOff/Icon") as TextureRect).texture == Art.texture("ui", "icon_stormed") and (summary.get_node("Column/Layout/Counts/Refused/Icon") as TextureRect).texture == Art.texture("ui", "icon_refused") and (summary.get_node("Column/Layout/Till/Icon") as TextureRect).texture == Art.texture("ui", "coin_0")
	_check(rows == ["Stormed off: 1", "Refused: 1", "In the till: 142"] and row_icons, "summary: the counts and the till with their icons", str(rows))
	_check((summary.get_node("Column/Layout/Header/DayLabel") as Label).text == "Day 3 done!" and (summary.get_node("Column/Layout/Header/TitleLabel") as Label).text == "The Guild Comes Calling", "summary: the header", "")
	# A tap outside the button completes the tally at once.
	summary = await _goto_scene(GameState.Flow.SUMMARY, SAMPLE_DAY) as Summary
	var tallying := summary.is_tallying()
	await _tap(summary.get_node("Column/Layout/Grades") as Control)
	_check(tallying and not summary.is_tallying() and current_scene == summary and _tile_texts(summary) == ["4/6", "+63", "+7", "-2 now 12"] and summary.tile("Tips").modulate.a == 1.0 and (summary.get_node("Column/Layout/Till") as CanvasItem).modulate.a == 1.0, "summary: a tap completes the tally with the exact numbers", str(_tile_texts(summary)))
	# Enter twice: the first completes the tally, the second continues.
	summary = await _goto_scene(GameState.Flow.SUMMARY, SAMPLE_DAY) as Summary
	var button := summary.get_node("Column/Layout/ContinueButton") as Button
	var focused := root.gui_get_focus_owner() == button and summary.is_tallying()
	await _action(&"ui_accept")
	_check(focused and current_scene == summary and not summary.is_tallying() and not _game.is_transitioning() and _tile_texts(summary)[1] == "+63", "summary: the focused button's first Enter completes the tally", "focused %s" % focused)
	await _action(&"ui_accept")
	_check(await _until(func() -> bool: return current_scene is Market and not _game.is_transitioning(), FLOW_FRAMES), "summary: a second Enter goes to the market", str(current_scene))
	_game.new_game()
	await _goto_scene(GameState.Flow.TITLE)


## The Rush Hour results: tiles (Score with "with Assist", Served, Wave reached, Tips),
## grade row, counts and the best line for a sample run; the reveal finishes by itself
## within Tally.MAX_TIME and a tap completes it.
func _test_results_tally() -> void:
	_game.new_game()
	var screen := await _goto_scene(GameState.Flow.RESULTS, SAMPLE_RUN) as Results
	var started := screen.is_tallying()
	var waited := await _until(func() -> bool: return not screen.is_tallying(), ceili(Tally.MAX_TIME * 60.0))
	_check(started and waited, "results: the tally finishes by itself within %.1f s" % Tally.MAX_TIME, "")
	_check(_tile_texts(screen) == ["238 with Assist", "14", "3", "+19"], "results: each tile's final text", str(_tile_texts(screen)))
	_check(_grade_texts(screen) == PackedStringArray(["Perfect 3", "Good 8", "Meh 2", "Misbrew 1"]) and _row_text(screen, "Counts/StormedOff") == "Stormed off: 2" and _row_text(screen, "Counts/Refused") == "Refused: 1", "results: the grade row and counts", str(_grade_texts(screen)))
	_check((screen.get_node("Column/Layout/Best") as Label).text == "Best: 238 coins (assisted)" and (screen.get_node("Column/Layout/Header/NewBest") as Label).visible and root.gui_get_focus_owner() == screen.get_node("Column/Layout/AgainButton"), "results: the best line, New best! and Again focused", (screen.get_node("Column/Layout/Best") as Label).text)
	screen = await _goto_scene(GameState.Flow.RESULTS, SAMPLE_RUN) as Results
	var tallying := screen.is_tallying()
	await _tap(screen.get_node("Column/Layout/Tiles") as Control)
	_check(tallying and current_scene == screen and not screen.is_tallying() and _tile_texts(screen)[0] == "238 with Assist", "results: a tap completes the tally", str(_tile_texts(screen)))
	# Enter twice on the focused Again: the first completes the tally, the second starts a run.
	screen = await _goto_scene(GameState.Flow.RESULTS, SAMPLE_RUN) as Results
	tallying = screen.is_tallying() and root.gui_get_focus_owner() == screen.get_node("Column/Layout/AgainButton")
	await _action(&"ui_accept")
	_check(tallying and current_scene == screen and not screen.is_tallying() and not _game.is_transitioning(), "results: the first Enter on Again completes the tally", "")
	await _action(&"ui_accept")
	_check(await _until(func() -> bool: return current_scene is Shop and (current_scene as Shop).shift.is_rush() and not _game.is_transitioning(), FLOW_FRAMES), "results: a second Enter on Again starts a run", str(current_scene))
	await _close_shop()


## Both results screens at 9:16, 9:19.5 and 16:9: header, tiles, rows and buttons do
## not overlap and sit in the safe area and the column, the buttons in the thumb zone;
## the column is filled (no gap between blocks taller than a tile); a 26-character
## day title wraps whole inside the column.
func _test_results_screens_layout() -> void:
	_game.new_game()
	_game.day = 4
	_game.at_market = true
	var long_day := SAMPLE_DAY.duplicate()
	long_day["title"] = "The Grandest Guild Fair Ye"
	var screens: Array[Array] = [
		[GameState.Flow.SUMMARY, long_day, ["Header", "Tiles", "Grades", "Counts", "Till", "ContinueButton"], ["ContinueButton"]],
		[GameState.Flow.RESULTS, SAMPLE_RUN, ["Header", "Tiles", "Grades", "Counts", "Best", "AgainButton", "TitleButton"], ["AgainButton", "TitleButton"]],
	]
	for screen in screens:
		var scene := await _goto_scene(screen[0], screen[1])
		var name: String = GameState.Flow.keys()[screen[0]]
		scene.call(&"complete_tally")
		for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
			root.size = window
			await _frames(10)
			var blocks: Array[Control] = []
			for path: String in screen[2]:
				blocks.append(scene.get_node("Column/Layout/" + path) as Control)
			var safe := _game.safe_rect()
			var column := _game.column_rect()
			var tile_height := ((scene.get_node("Column/Layout/Tiles") as Control).get_child(0) as Control).size.y
			for i in blocks.size():
				var rect := blocks[i].get_global_rect()
				_check(safe.encloses(rect) and column.encloses(rect), "%s %s inside the safe area and column at %s" % [name, blocks[i].name, window], "%s not in %s" % [rect, column])
				if i + 1 < blocks.size():
					var below := blocks[i + 1].get_global_rect()
					_check(not rect.intersects(below) and below.position.y - rect.end.y <= tile_height, "%s %s and %s do not overlap, no wide gap, at %s" % [name, blocks[i].name, blocks[i + 1].name, window], "%s / %s" % [rect, below])
			var buttons: Array[Control] = []
			for path: String in screen[3]:
				buttons.append(scene.get_node("Column/Layout/" + path) as Control)
			_check_targets(buttons, null, "%s at %s" % [name, window])
			if scene is Summary:
				var title := scene.get_node("Column/Layout/Header/TitleLabel") as Label
				_check(title.get_line_count() == title.get_visible_line_count() and title.get_line_count() <= 2 and column.encloses(title.get_global_rect()), "summary: a 26-character title wraps whole in the column at %s" % window, "%d lines, %d visible" % [title.get_line_count(), title.get_visible_line_count()])
	root.size = BASE_WINDOW
	await _frames(5)
	_game.new_game()
	await _goto_scene(GameState.Flow.TITLE)


## Each stat tile's number with its small line ("-2 now 12"), in grid order.
func _tile_texts(screen: Node) -> Array[String]:
	var texts: Array[String] = []
	for stat: StatTile in screen.get_node("Column/Layout/Tiles").get_children():
		texts.append(" ".join(PackedStringArray([stat.number_text(), stat.sub_text()])).strip_edges())
	return texts


## "<Grade> <count>" per cell of a results screen's grade row.
func _grade_texts(screen: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	for cell in screen.get_node("Column/Layout/Grades/Row").get_children():
		texts.append("%s %s" % [(cell.get_node("Word") as Label).text, (cell.get_node("Count") as Label).text])
	return texts


## The text of a results screen's icon row ("Counts/Refused", "Till").
func _row_text(screen: Node, row: String) -> String:
	return (screen.get_node("Column/Layout/%s/Text" % row) as Label).text


## Story rules (Story): outcomes per grade, flag conditions (an unrecorded flag counts
## as refused), conditioned customers and morning notes, the beat and final flags, and
## the saved-flags validation.
func _test_story_rules() -> void:
	var outcomes: Array[String] = []
	for grade: Brew.Grade in [Brew.Grade.PERFECT, Brew.Grade.GOOD, Brew.Grade.MEH, Brew.Grade.MISBREW]:
		outcomes.append(Story.outcome_for(grade))
	_check(outcomes == (["great", "great", "poor", "poor"] as Array[String]), "story: Perfect and Good are great, Meh and Misbrew poor", str(outcomes))
	var when: Dictionary[String, PackedStringArray] = {"quill.inspection": PackedStringArray(["great"])}
	_check(Story.matches(when, {"quill.inspection": "great"}) and not Story.matches(when, {"quill.inspection": "poor"}) and not Story.matches(when, {}), "story: a condition matches its outcomes only; unrecorded is refused", "")
	_check(Story.matches({} as Dictionary[String, PackedStringArray], {}), "story: no condition always matches", "")
	var day4 := Content.day(4)
	var helped := Story.customers_of(day4, {"stranger.first_sneeze": "great"})
	var not_helped := Story.customers_of(day4, {"stranger.first_sneeze": "poor"})
	_check(helped.size() == not_helped.size() + 1 and helped[-1].archetype == "goat_farmer", "story: a great first sneeze sends the goat farmer on day 4", "%d vs %d" % [helped.size(), not_helped.size()])
	var day8 := Content.day(8)
	var audit_great := Story.customers_of(day8, {"quill.inspection": "great"}).filter(func(c: DayCustomer) -> bool: return c.flag() == "quill.audit")
	var audit_retest := Story.customers_of(day8, {"quill.inspection": "stormed_off"}).filter(func(c: DayCustomer) -> bool: return c.flag() == "quill.audit")
	_check(audit_great.size() == 1 and audit_retest.size() == 1 and audit_great[0].potion != audit_retest[0].potion, "story: Quill's audit asks for a different potion after a poor inspection", "%s / %s" % [audit_great.map(func(c: DayCustomer) -> String: return c.potion), audit_retest.map(func(c: DayCustomer) -> String: return c.potion)])
	_check(Story.morning_note(day8, {"quill.inspection": "great"}) != Story.morning_note(day8, {"quill.inspection": "poor"}) and Story.morning_note(Content.day(3), {}) == Content.day(3).morning_note, "story: morning notes follow the flags, else the day's note", Story.morning_note(day8, {}))
	_check(Story.beat_flags().size() == 18 and Story.final_flags() == PackedStringArray(["vexley.fair", "stranger.fair", "quill.fair"]), "story: eighteen beats, six per character, three final ones on day %d" % Content.LAST_DAY, "%s / %s" % [Story.beat_flags(), Story.final_flags()])
	var problems := PackedStringArray()
	for bad: Dictionary in [{"nobody.waves": "great"}, {"quill.inspection": "splendid"}, {"ending": "guild_master"}, {"rush_hour_unlocked": true}, {"quill.inspection": 3}]:
		if Story.flags_problem(bad) == "":
			problems.append(str(bad))
	_check(problems.is_empty() and Story.flags_problem({"quill.inspection": "great", "quill.fair": "refused"}) == "", "story: saved flags are validated (beat outcomes only)", str(problems))


## Story beats in the shop (day 3, Assist): a story character wears its fixed look;
## Quill's inspection served Meh records quill.inspection = poor and he says the beat's
## poor line; the Stranger storming off records stranger.first_sneeze = stormed_off with
## the beat's line; the day's end commits both to Game.flags and the save.
func _test_shop_story_beats() -> void:
	_game.new_game()
	_game.assist_mode = true
	for item in Content.ingredients_unlocked_by(3):
		_game.stock[item.id] = 9
	_game.day = 3
	var shop: Shop = await _goto_scene(GameState.Flow.SHOP, {"day": 3})
	var bubble := shop.get_node("Column/Stage/Bubble") as SpeechBubble
	var count := shop.shift.customers.size()
	for n in count:
		var label := "story day 3 customer %d" % (n + 1)
		if not await _wait_for_order(shop, label):
			break
		_refill_patience(shop)
		var visitor := shop.customer
		var flag := visitor.visit.flag()
		if flag == "quill.inspection":
			_check(visitor.look == visitor.archetype.fixed_look and visitor.archetype.is_story(), "story: Quill wears his fixed look", visitor.look.describe())
			_check(visitor.request.id == visitor.visit.request, "story: a beat says its pinned request", visitor.request.id)
			if not await _serve(shop, _recipe_between(visitor.potion, shop.stock, 2, 2), label):
				break
			_check(shop.story_outcomes.get(flag) == "poor" and bubble.text == visitor.visit.lines["poor"], "story: a Meh brew records quill.inspection poor with the beat's line", "%s '%s'" % [shop.story_outcomes, bubble.text])
		elif flag == "stranger.first_sneeze":
			visitor.patience_left = 0.05
			await _until(func() -> bool: return visitor.state == Customer.State.STORMING, FLOW_FRAMES)
			await process_frame
			_check(shop.story_outcomes.get(flag) == "stormed_off" and bubble.text == visitor.visit.lines["stormed_off"], "story: storming off records stranger.first_sneeze stormed_off with the beat's line", "%s '%s'" % [shop.story_outcomes, bubble.text])
		elif not await _serve(shop, _exact_recipe(visitor.potion, shop.stock), label):
			break
		await _skip_lines(shop)
	var ended := await _until(func() -> bool: return _game.state == GameState.Flow.SUMMARY and not _game.is_transitioning(), FLOW_FRAMES * 2)
	var expected := {"quill.inspection": "poor", "stranger.first_sneeze": "stormed_off"}
	_check(ended and _game.flags.recursive_equal(expected, 1) and expected.recursive_equal(_read_save().get("flags", {}), 1), "story: the day's beats are committed to Game.flags and saved", "%s %s" % [_game.flags, _read_save().get("flags")])
	_game.assist_mode = false
	_game.day = 8
	_game.at_market = false
	var morning: Morning = await _goto_scene(GameState.Flow.MORNING)
	var note := (morning.get_node("Column/Card/Note") as Label).text.replace("\n", " ")
	_check(note == Story.morning_note(Content.day(8), expected) and note != Content.day(8).morning_note, "story: the morning shows the note for the flags", note)
	await _close_shop()
	_game.new_game()


## The Codex records as the player earns: a delivery notes the request's hint words
## (any grade), a Good or better brew its recipe (a Meh one does not); an exact recipe
## replaces an inexact one but not the other way round; everything is saved at once.
func _test_codex_records() -> void:
	_game.codex = {}
	_game.new_game()
	_check(_game.codex_words().is_empty() and _game.codex_recipes().is_empty(), "codex: an empty Codex stays empty in a new game", str(_game.codex))
	_game.assist_mode = true
	var shop := await _open_shop()
	if not await _wait_for_order(shop, "codex"):
		await _close_shop()
		return
	var first := shop.customer
	if await _serve(shop, _recipe_between(first.potion, shop.stock, 2, 2), "codex Meh"):
		_check(_game.codex_words() == first.request.hints and _game.codex_recipes().is_empty(), "codex: a Meh delivery notes its hint words but no recipe", str(_game.codex))
		await _skip_lines(shop)
	if await _wait_for_order(shop, "codex 2"):
		var second := shop.customer
		var recipe := _exact_recipe(second.potion, shop.stock)
		if await _serve(shop, recipe, "codex Good"):
			var held: PackedStringArray = _game.codex_recipes().get(second.potion.id, PackedStringArray())
			var words := _game.codex_words()
			var hints_noted := not second.request.hints.is_empty() and Array(second.request.hints).all(func(id: String) -> bool: return id in words)
			_check(held == PackedStringArray(recipe) and hints_noted, "codex: a Good brew notes its recipe and its request's hint words", "%s hints %s" % [_game.codex, second.request.hints])
			var saved: Dictionary = _read_save().get("codex", {})
			_check(saved.get("recipes", {}).has(second.potion.id), "codex: the Codex is saved as it is earned", str(saved))
			_check(not _game.learn_recipe(second.potion, PackedStringArray([recipe[0], recipe[0], recipe[1]])), "codex: an inexact recipe does not replace an exact one", str(_game.codex_recipes()))
	await _close_shop()
	_game.codex = {}
	var tonic := Content.potion("hearthglow_tonic")
	var near := PackedStringArray(["ember_pepper", "honeycomb"])
	var exact := PackedStringArray(["ember_pepper", "sunpetal"])
	var first_noted := _game.learn_recipe(tonic, near)
	var replaced := _game.learn_recipe(tonic, exact)
	var kept := not _game.learn_recipe(tonic, near)
	_check(first_noted and replaced and kept and _game.codex_recipes()["hearthglow_tonic"] == exact, "codex: the first Good recipe is noted, an exact one replaces it, an inexact one never replaces an exact one", str(_game.codex_recipes()))
	_game.codex = {}
	_game.new_game()


## The Codex panel: the shop's Codex button pauses the shift and opens the Words tab
## (each word with its essence's name and icon); Recipes lists the potion, its stations
## and ingredients (a page of three-ingredient recipes with the longest names still fits
## the column, its controls in the thumb zone, at 9:16, 9:19.5 and 16:9); pages turn;
## keyboard focus stays inside, and Escape (ui_cancel) closes it, resumes the shift and
## gives focus back. The morning and the market open it too.
func _test_codex_panel() -> void:
	var shop := await _open_shop()
	var recipes := {}
	for potion in Content.potions():
		var pool := Content.ingredients()
		for a in pool:
			for b in pool:
				if not recipes.has(potion.id) and a.essence + b.essence == potion.target:
					recipes[potion.id] = [a.id, b.id]
	# The rest of the first page: the three longest ingredient names, the widest row there is.
	var longest := Content.ingredients().map(func(item: Ingredient) -> Ingredient: return item)
	longest.sort_custom(func(a: Ingredient, b: Ingredient) -> bool: return a.name.length() > b.name.length())
	var long_recipe := longest.slice(0, 3).map(func(item: Ingredient) -> String: return item.id)
	var long_names := " + ".join(PackedStringArray(longest.slice(0, 3).map(func(item: Ingredient) -> String: return item.name)))
	for potion: PotionType in Content.potions().slice(1, Codex.RECIPES_PER_PAGE):
		recipes[potion.id] = long_recipe
	_game.codex = {"words": ["hint_calm", "hint_warm"], "recipes": recipes}
	var button := shop.get_node("Column/Stage/CodexButton") as Button
	_check(button.accessibility_name == "Codex" and button.focus_mode == Control.FOCUS_ALL, "codex: the shop's Codex button is focusable and named", button.accessibility_name)
	await _tap(button)
	var codex := shop.codex
	if codex == null:
		_check(false, "codex: the Codex button opens the Codex", "not open")
		await _close_shop()
		return
	_check(paused and codex.tab == Codex.Tab.WORDS, "codex: opening it pauses the shift on the Words tab", "paused %s tab %d" % [paused, codex.tab])
	var words := codex.entry_texts()
	_check(words.size() == 1 and "warmth: ember" in words[0] and "calm: frost" in words[0], "codex: words show their essence by name, in vocabulary order", str(words))
	var icons := codex.find_children("*", "TextureRect", true, false).filter(func(icon: TextureRect) -> bool: return icon.texture == Art.texture("ui", "essence_ember"))
	_check(icons.size() == 1, "codex: each word shows its essence icon too", str(icons.size()))
	await _tap(codex.get_node("Column/Panel/List/Tabs/RecipesTab") as Button)
	var first_page := codex.entry_texts()
	_check(codex.tab == Codex.Tab.RECIPES and first_page.size() == Codex.RECIPES_PER_PAGE and "Hearthglow Tonic stir, pour Ember Pepper + Sunpetal" in first_page, "codex: recipes show name, stations and ingredients", str(first_page))
	_check(first_page.size() == Codex.RECIPES_PER_PAGE and Array(first_page).slice(1).all(func(text: String) -> bool: return long_names in text), "codex: three-ingredient recipes list every ingredient name", str(first_page))
	var panel := codex.get_node("Column/Panel") as Control
	var controls: Array[Control] = []
	for path: String in ["Tabs/WordsTab", "Tabs/RecipesTab", "Footer/PrevButton", "Footer/NextButton", "Footer/CloseButton"]:
		controls.append(codex.get_node("Column/Panel/List/" + path) as Control)
	for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
		root.size = window
		await _frames(10)
		var column := _game.column_rect()
		var rows := codex.get_node("Column/Panel/List/Entries").get_children().all(func(row: Control) -> bool: return panel.get_global_rect().encloses(row.get_global_rect()))
		_check(column.encloses(panel.get_global_rect()) and rows, "codex at %s: the panel of three-ingredient recipes stays inside the column" % window, "panel %s column %s" % [panel.get_global_rect(), column])
		_check_targets(controls, null, "codex at %s" % window)
	root.size = BASE_WINDOW
	await _frames(10)
	var pages := codex.page_count()
	_game.sfx_log.clear()
	await _tap(codex.get_node("Column/Panel/List/Footer/NextButton") as Button)
	_check(_game.sfx_log == ([&"page_flip"] as Array[StringName]), "codex: a page turn plays only the page flip", str(_game.sfx_log))
	_check(pages == ceili(recipes.size() / float(Codex.RECIPES_PER_PAGE)) and codex.page == 1 and codex.entry_texts() != first_page, "codex: Next turns the page", "%d pages, page %d" % [pages, codex.page])
	(codex.get_node("Column/Panel/List/Tabs/WordsTab") as Button).grab_focus()
	_check(await _focus_stays_in(codex), "codex: keyboard focus stays in the Codex", str(root.gui_get_focus_owner()))
	await _key(KEY_ESCAPE)
	await process_frame
	_check(shop.codex == null and not paused and root.gui_get_focus_owner() == button, "codex: Escape closes it, resumes the shift and refocuses its button", "codex %s paused %s focus %s" % [shop.codex, paused, root.gui_get_focus_owner()])
	await _close_shop()
	for flow: GameState.Flow in [GameState.Flow.MORNING, GameState.Flow.MARKET]:
		_game.day = 2
		_game.at_market = flow == GameState.Flow.MARKET
		var scene := await _goto_scene(flow)
		var opener := scene.get_node("Column/CodexButton" if flow == GameState.Flow.MORNING else "Column/Shop/CodexButton") as Button
		await _tap(opener)
		var opened := scene.get_children().filter(func(child: Node) -> bool: return child is Codex)
		_check(opened.size() == 1, "codex: the %s opens the Codex" % GameState.Flow.keys()[flow], str(opened))
		if opened.size() == 1:
			await _tap((opened[0] as Codex).get_node("Column/Panel/List/Footer/CloseButton") as Button)
			await process_frame
			_check(scene.get_children().all(func(child: Node) -> bool: return not (child is Codex) or child.is_queued_for_deletion()) and root.gui_get_focus_owner() == opener, "codex: Close returns to the %s" % GameState.Flow.keys()[flow], str(root.gui_get_focus_owner()))
	_game.new_game()
	await _goto_scene(GameState.Flow.TITLE)


## Story.ending on every path of the three final beats (4^3 outcomes) at reputations
## just under and at the Guild Master threshold, against the rule written out here:
## licence = quill.fair great; Guild Master needs the licence, all three arcs and the
## reputation; any other granted licence is Cosy Corner; a refused one Charming Chaos.
func _test_story_ending_rule() -> void:
	var finals := Story.final_flags()
	var wrong := PackedStringArray()
	var reached := {}
	var paths := 0
	for a in Story.OUTCOMES:
		for b in Story.OUTCOMES:
			for c in Story.OUTCOMES:
				var flags := {finals[0]: a, finals[1]: b, finals[2]: c}
				var resolved := [a, b, c].count(Story.GREAT)
				var licence: bool = flags[Story.LICENCE_FLAG] == Story.GREAT
				for reputation: int in [Story.GUILD_MASTER_REPUTATION - 1, Story.GUILD_MASTER_REPUTATION]:
					paths += 1
					var expected := Story.CHARMING_CHAOS
					if licence and resolved == 3 and reputation >= Story.GUILD_MASTER_REPUTATION:
						expected = Story.GUILD_MASTER
					elif licence:
						expected = Story.COSY_CORNER
					var got := Story.ending(flags, reputation)
					reached[got] = true
					if got != expected:
						wrong.append("%s rep %d: %s, expected %s" % [flags, reputation, got, expected])
	_check(paths == 128 and wrong.is_empty() and reached.size() == 3, "story: the ending rule on all 128 final paths reaches all three endings", "\n".join(wrong))
	_check(Story.ending({}, 99) == Story.CHARMING_CHAOS and Story.LICENCE_FLAG in finals, "story: no recorded final beats is Charming Chaos; the licence is a final beat", str(finals))
	var licence_only := {finals[0]: Story.REFUSED, finals[1]: Story.POOR, Story.LICENCE_FLAG: Story.GREAT}
	_check(Story.ending(licence_only, 0) == Story.COSY_CORNER, "story: a granted licence with no other arc resolved is Cosy Corner, never Charming Chaos", str(licence_only))
	var chaos_refuses := "declines your licence" in Content.ending(Story.CHARMING_CHAOS).pages[0]
	var others_grant := [Story.GUILD_MASTER, Story.COSY_CORNER].all(func(id: String) -> bool: return Array(Content.ending(id).pages).all(func(text: String) -> bool: return not "declines" in text))
	_check(chaos_refuses and others_grant, "story: only Charming Chaos's pages refuse the licence", "")


## The ending scene after the story: it records the ending and the Rush Hour unlock
## (saved), shows each page's title, text and cast in the shop, turns pages by tap and
## by Enter (focused Next, in the thumb zone), and "The end" goes back to the title.
func _test_ending_scene() -> void:
	_game.new_game()
	_game.endings = []
	_game.rush_hour_unlocked = false
	_game.day = Content.days().size() + 1
	_game.reputation = Story.GUILD_MASTER_REPUTATION
	for flag in Story.final_flags():
		_game.flags[flag] = Story.GREAT
	var screen: EndingScreen = await _goto_scene(GameState.Flow.ENDING)
	var ending := Content.ending(Story.GUILD_MASTER)
	_check(screen != null and screen.ending == ending and (screen.get_node("Column/Title") as Label).text == ending.title, "ending: the Guild Master ending shows its title", str(screen))
	if screen == null:
		return
	var saved := _read_save()
	_check(_game.endings == ([Story.GUILD_MASTER] as Array[String]) and _game.rush_hour_unlocked and saved.get("endings") == [Story.GUILD_MASTER] and saved.get("rush_hour_unlocked") == true, "ending: the ending and the Rush Hour unlock are saved", str(saved))
	var next := screen.get_node("Column/NextButton") as Button
	_check(root.gui_get_focus_owner() == next and next.accessibility_name != "", "ending: Next has focus and a name", str(root.gui_get_focus_owner()))
	for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
		root.size = window
		await _frames(10)
		_check_targets([next] as Array[Control], null, "ending at %s" % window)
	root.size = BASE_WINDOW
	await process_frame
	for i in ending.pages.size():
		var text := (screen.get_node("Column/Body/Card/Text") as Label).text
		var cast := screen.get_node("Column/Picture/Cast").get_children().filter(func(child: Node) -> bool: return not child.is_queued_for_deletion())
		var names := cast.map(func(figure: Customer) -> String: return figure.archetype.id)
		_check(screen.page == i and text == "\n".join(Content.wrap_bubble(ending.pages[i])) and names == Array(ending.casts[i]), "ending: page %d shows its text and cast" % (i + 1), "%s %s" % [text, names])
		var story_looks := cast.all(func(figure: Customer) -> bool: return not figure.archetype.is_story() or figure.look == figure.archetype.fixed_look)
		_check(story_looks, "ending: story characters wear their fixed look", str(names))
		if i == ending.pages.size() - 1:
			_check(next.text == "The end", "ending: the last page's button reads The end", next.text)
			await _action(&"ui_accept")
		else:
			await _tap(next)
	_check(await _until(func() -> bool: return _game.state == GameState.Flow.TITLE and not _game.is_transitioning(), FLOW_FRAMES), "ending: The end goes back to the title", str(_game.state))
	_game.new_game()
	_check(_game.rush_hour_unlocked and _game.endings == ([Story.GUILD_MASTER] as Array[String]) and _game.flags.is_empty(), "ending: the next new game keeps the unlock and the ending reached", "%s %s" % [_game.rush_hour_unlocked, _game.endings])
	_game.endings = []
	_game.rush_hour_unlocked = false
	_game.new_game()


## The whole story, headless, through the real screens (taps on Open the shop, To the
## market, Next day, The ending, Next) with Assist on, on two paths:
## - "helpful": every customer served (Good), so every beat is great: each day's
##   conditioned customers come, the licence is granted and with reputation >= 30 the
##   ending is Guild Master;
## - "refusing": every story beat refused: the beats' "not great" variants come (Quill's
##   retest, the Stranger still hiding, Vexley's challenge), the conditioned extra
##   customers stay away, no licence: Charming Chaos.
## Ingredients are bought at each market with the coins earned (Game.buy_stock at the
## day's prices), so the run also checks that the pay covers the next day.
## Each day's beats are checked against the request each path must bring (written out
## here from data/SCHEMA.md "Story"), and the conditioned extra customers (the goat
## farmer on day 4, Vexley's overflow on day 7) against whether the path sends them.
## The ordinary visitors are the ones Shift.story picks at the day's difficulty level.
func _test_story_playthrough_helpful() -> void:
	var beats: Dictionary[int, Dictionary] = {
		3: {"quill.inspection": "stillwater_quill_1", "stranger.first_sneeze": "dewdrop_stranger_1"},
		5: {"quill.paperwork": "nocturne_quill_1"},
		6: {"vexley.opening": "steamwhistle_vexley_1"},
		7: {"stranger.hiccups": "smoulder_stranger_1"},
		8: {"quill.audit": "steamwhistle_quill_1"},
		9: {"vexley.spy": "valour_vexley_1"},
		10: {"stranger.flight": "dewdrop_stranger_3"},
		11: {"quill.surprise_visit": "hushfire_quill_1"},
		12: {"vexley.night_garden": "duskbloom_vexley_2"},
		13: {"stranger.confession": "hushfire_stranger_1"},
		14: {"vexley.truce": "panacea_vexley_1"},
		16: {"stranger.lantern_practice": "nightfire_stranger_1"},
		17: {"quill.rehearsal": "embermoss_quill_1"},
		18: {"vexley.recipe_swap": "moonbloom_vexley_1"},
		20: {"vexley.fair": "starfire_vexley_1", "stranger.fair": "panacea_stranger_1", "quill.fair": "panacea_quill_1"},
	}
	await _play_story(false, Story.GUILD_MASTER, beats, {4: 1, 7: 1})


func _test_story_playthrough_refusing() -> void:
	var beats: Dictionary[int, Dictionary] = {
		3: {"quill.inspection": "stillwater_quill_1", "stranger.first_sneeze": "dewdrop_stranger_1"},
		5: {"quill.paperwork": "nocturne_quill_1"},
		6: {"vexley.opening": "steamwhistle_vexley_1"},
		7: {"stranger.hiccups": "smoulder_stranger_1"},
		8: {"quill.audit": "stillwater_quill_2"},
		9: {"vexley.spy": "valour_vexley_1"},
		10: {"stranger.flight": "dewdrop_stranger_3"},
		11: {"quill.surprise_visit": "hushfire_quill_1"},
		12: {"vexley.night_garden": "duskbloom_vexley_2"},
		13: {"stranger.confession": "dewdrop_stranger_2"},
		14: {"vexley.truce": "embermoss_vexley_1"},
		16: {"stranger.lantern_practice": "nightfire_stranger_1"},
		17: {"quill.rehearsal": "embermoss_quill_1"},
		18: {"vexley.recipe_swap": "moonbloom_vexley_1"},
		20: {"vexley.fair": "duskbloom_vexley_1", "stranger.fair": "hushfire_stranger_2", "quill.fair": "starfire_quill_1"},
	}
	await _play_story(true, Story.CHARMING_CHAOS, beats, {4: 0, 7: 0})


## `beats`: day -> {beat flag: the request id its visit must pin} for every beat of that
## day (a day not listed has none); `extras`: day -> how many conditioned customers
## without a beat come (days not listed: none).
func _play_story(refuse_beats: bool, expected_ending: String, beats: Dictionary[int, Dictionary], extras: Dictionary[int, int]) -> void:
	var label := "playthrough (%s)" % ("refusing" if refuse_beats else "helpful")
	_delete_saves()
	_game.load_game()
	_game.assist_mode = true
	Engine.time_scale = PLAYTHROUGH_TIME_SCALE
	_game.goto(GameState.Flow.TITLE)
	await _game.transition_finished
	await _tap(current_scene.get_node("Column/OpenShopButton") as Button)
	var finished := true
	for number in range(1, Content.days().size() + 1):
		if not await _until(func() -> bool: return current_scene is Morning and not _game.is_transitioning(), FLOW_FRAMES):
			_check(false, "%s: day %d morning" % [label, number], str(current_scene))
			finished = false
			break
		var expected := Shift.story(number, _game.flags, _game.difficulty).customers
		await _tap(current_scene.get_node("Column/OpenShopButton") as Button)
		await _until(func() -> bool: return current_scene is Shop and not _game.is_transitioning(), FLOW_FRAMES)
		var shop := current_scene as Shop
		var seen: Array[DayCustomer] = []
		for n in expected.size():
			var who := "%s day %d customer %d" % [label, number, n + 1]
			if not await _wait_for_order(shop, who):
				finished = false
				break
			_refill_patience(shop)
			seen.append(shop.customer.visit)
			if refuse_beats and shop.customer.visit.beat != "":
				await _tap(shop.get_node("Column/Stage/RefuseButton") as Button)
			elif not await _serve(shop, _exact_recipe(shop.customer.potion, shop.stock), who):
				finished = false
				break
			await _skip_lines(shop)
		if not finished:
			break
		var keys := func(visits: Array[DayCustomer]) -> Array: return visits.map(func(visit: DayCustomer) -> String: return "%s/%s/%s" % [visit.archetype, visit.potion, visit.request])
		_check(keys.call(seen) == keys.call(expected), "%s: day %d brings its %d customers for the flags" % [label, number, expected.size()], "%d of %d" % [seen.size(), expected.size()])
		var seen_beats := {}
		for visit in seen:
			if visit.beat != "":
				seen_beats[visit.flag()] = visit.request
		var extra_count := seen.filter(func(visit: DayCustomer) -> bool: return visit.beat == "" and not visit.when.is_empty()).size()
		_check(seen_beats.recursive_equal(beats.get(number, {}), 1) and extra_count == extras.get(number, 0), "%s: day %d brings the path's beat variants and conditioned extras" % [label, number], "beats %s (expected %s), extras %d (expected %d)" % [seen_beats, beats.get(number, {}), extra_count, extras.get(number, 0)])
		if not await _until(func() -> bool: return current_scene is Summary and not _game.is_transitioning(), FLOW_FRAMES * 2):
			_check(false, "%s: day %d summary" % [label, number], str(current_scene))
			finished = false
			break
		var day_summary := current_scene as Summary
		await _until(func() -> bool: return not day_summary.is_tallying(), FLOW_FRAMES)
		await _tap(day_summary.get_node("Column/Layout/ContinueButton") as Button)
		if number == Content.days().size():
			break
		await _until(func() -> bool: return current_scene is Market and not _game.is_transitioning(), FLOW_FRAMES)
		_check(_buy_for_day(number + 1), "%s: day %d pay buys day %d's ingredients" % [label, number, number + 1], "%d coins, stock %s" % [_game.coins, _game.stock])
		await _tap(current_scene.get_node("Column/Shop/NextDayButton") as Button)
	if finished:
		_check(await _until(func() -> bool: return current_scene is EndingScreen and not _game.is_transitioning(), FLOW_FRAMES), "%s: the last summary leads to the ending" % label, str(current_scene))
		var screen := current_scene as EndingScreen
		_check(screen != null and screen.ending.id == expected_ending and _game.endings == ([expected_ending] as Array[String]) and _game.rush_hour_unlocked, "%s: reaches %s (reputation %d)" % [label, expected_ending, _game.reputation], "%s %s" % [screen.ending.id if screen != null else "-", _game.flags])
		var beat_outcome := Story.REFUSED if refuse_beats else Story.GREAT
		var beats_ok := Array(Story.beat_flags()).all(func(flag: String) -> bool: return _game.flags.get(flag) == beat_outcome)
		_check(beats_ok, "%s: every beat recorded %s" % [label, beat_outcome], str(_game.flags))
		if screen != null:
			for i in screen.ending.pages.size():
				await _tap(screen.get_node("Column/NextButton") as Button)
			_check(await _until(func() -> bool: return current_scene is Title and not _game.is_transitioning(), FLOW_FRAMES), "%s: the ending returns to the title" % label, str(current_scene))
	Engine.time_scale = 1.0
	_game.assist_mode = false
	_game.new_game()


## In the market before day `number`: buys, at the day's prices, whatever the stock
## lacks for an exact recipe for each of the day's customers on the current flags.
## False when the coins fall short.
func _buy_for_day(number: int) -> bool:
	var spec := Content.day(number)
	var pool := Content.ingredients_unlocked_by(number)
	var needed: Dictionary[String, int] = {}
	for customer in Shift.story(number, _game.flags, _game.difficulty).customers:
		var target := Content.potion(customer.potion).target
		var recipe: Array[String] = []
		for a in pool:
			for b in pool:
				if recipe.is_empty() and a.essence + b.essence == target:
					recipe = [a.id, b.id]
		for id in recipe:
			needed[id] = needed.get(id, 0) + 1
	for id in needed:
		var item := Content.ingredient(id)
		while _game.stock.get(id, 0) < needed[id]:
			if not _game.buy_stock(item, Economy.market_price(spec, item)):
				return false
	return true


## Version-1 saves load through the version 2 upgrade: one from before the story (empty
## codex and flags) loads unchanged; the two-day build's finished save (day 3, market
## closed, no flags) reopens the day-3 market; a finished story's ending and Rush Hour
## unlock move out of the flags and survive a new game.
func _test_save_v1_without_story_loads() -> void:
	var v1 := {"version": 1, "day": 4, "at_market": true, "coins": 60, "reputation": 9, "stock": {"moonmoss": 2},
		"upgrades": {}, "codex": {}, "flags": {}, "rush_best": 0, "settings": {"assist": false, "gentle": false}}
	_write_save(JSON.stringify(v1))
	var errors := _game.reported_errors.size()
	_game.load_game()
	_check(_game.reported_errors.size() == errors and _game.day == 4 and _game.at_market and _game.coins == 60 and _game.codex.is_empty() and _game.flags.is_empty() and _game.endings.is_empty() and not _game.rush_hour_unlocked, "a v1 save with empty codex and flags loads", "%s day %d" % [_game.reported_errors.slice(errors), _game.day])
	_write_save(JSON.stringify(_with(_with(v1, "day", 3), "at_market", false)))
	_game.load_game()
	_check(_game.reported_errors.size() == errors and _game.day == 3 and _game.at_market and _game.can_continue(), "a v1 save that finished the two-day story reopens the day-3 market", "%s day %d market %s" % [_game.reported_errors.slice(errors), _game.day, _game.at_market])
	_write_save(JSON.stringify(_with(_with(v1, "day", Content.days().size() + 1), "flags", {"quill.fair": "great", "ending": "cosy_corner", "rush_hour_unlocked": true})))
	_game.load_game()
	_check(_game.reported_errors.size() == errors and _game.flags == {"quill.fair": "great"} and _game.endings == (["cosy_corner"] as Array[String]) and _game.rush_hour_unlocked, "a v1 finished story's ending and unlock load outside the flags", "%s %s %s" % [_game.flags, _game.endings, _game.rush_hour_unlocked])
	_game.new_game()
	_check(_game.rush_hour_unlocked and _game.endings == (["cosy_corner"] as Array[String]) and _read_save().get("version") == GameState.SAVE_VERSION, "a v1 save's Rush Hour unlock survives a new game", "%s %s" % [_game.rush_hour_unlocked, _game.endings])
	_delete_saves()
	_game.load_game()


## A shelf that fits the row (day 1, four ingredients) is centred as before and
## shows no page arrows or page label.
func _test_shop_shelf_fits_without_pages() -> void:
	var shop := await _open_shop()
	var ids := shop.stock.keys()
	var xs: Array[float] = []
	for id: String in ids:
		xs.append(shop.shelf_item(id).position.x)
	var left := (Shop.STAGE_SIZE.x - ids.size() * Shop.SHELF_SPACING) / 2.0 + (Shop.SHELF_SPACING - ShelfItem.ITEM_SIZE.x) / 2.0
	var expected: Array[float] = []
	for i in ids.size():
		expected.append(roundf(left + i * Shop.SHELF_SPACING))
	_check(ids.size() == 4 and xs == expected and ids.all(func(id: String) -> bool: return shop.shelf_item(id).visible), "shelf pages: four items centred, all showing", "%s, expected %s" % [xs, expected])
	var hidden := ["ShelfPrev", "ShelfNext", "ShelfPage"].all(func(node: String) -> bool: return not (shop.get_node("Column/Stage/" + node) as Control).visible)
	_check(hidden, "shelf pages: no arrows or page label when the shelf fits", "")
	await _close_shop()


## The shelf items showing in `shop` (the current page), left to right.
func _shown_items(shop: Shop) -> Array[ShelfItem]:
	var shown: Array[ShelfItem] = []
	for item: ShelfItem in shop.get_node("Column/Stage/ShelfItems").get_children():
		if item.visible:
			shown.append(item)
	shown.sort_custom(func(a: ShelfItem, b: ShelfItem) -> bool: return a.position.x < b.position.x)
	return shown


## Opens the day-13 shop (ten ingredients, three of each in stock), or null.
func _open_day6_shop(label: String) -> Shop:
	_game.new_game()
	for item in Content.ingredients_unlocked_by(13):
		_game.stock[item.id] = 3
	var shop := await _goto_scene(GameState.Flow.SHOP, {"day": 13}) as Shop
	_check(shop != null and shop.stock.size() == 10, label + ": the day-13 shop opens with ten ingredients", str(current_scene))
	return shop


## A shelf wider than the row (day 13, ten ingredients) shows one page at a time
## between two arrows: every item is on exactly one page, at least 4 whole items per
## page between the arrows, the arrows and items are big enough and in the thumb zone
## at 9:16, 9:19.5 and 16:9, the ends disable their arrow, a tap and Enter flip a
## page with a squash, the pot keeps the page (an item out of stock keeps its slot),
## and dragging a page-2 item into the cauldron still works.
func _test_shop_shelf_pages() -> void:
	var shop := await _open_day6_shop("shelf pages")
	if shop == null:
		return
	var prev := shop.get_node("Column/Stage/ShelfPrev") as Button
	var next := shop.get_node("Column/Stage/ShelfNext") as Button
	var label := shop.get_node("Column/Stage/ShelfPage") as Label
	var row := shop.get_node("Column/Stage/ShelfItems") as Control
	_check(prev.visible and next.visible and label.visible and prev.accessibility_name == "Previous ingredients" and next.accessibility_name == "Next ingredients", "shelf pages: both arrows and the page label show", "%s %s %s" % [prev.visible, next.visible, label.visible])
	var seen: Array[String] = []
	var pages := 0
	while pages < 10:
		pages += 1
		var shown := _shown_items(shop)
		for item in shown:
			seen.append(item.ingredient.id)
			var rect := Rect2(row.position + item.position, item.size)
			_check(rect.position.x >= prev.position.x + prev.size.x and rect.end.x <= next.position.x, "shelf pages: %s is whole between the arrows on page %d" % [item.ingredient.id, pages], str(rect))
		_check(shown.size() >= 4 or next.disabled, "shelf pages: page %d shows at least 4 items unless it is the last" % pages, str(shown.size()))
		_check(label.text == "%d/3" % pages and prev.disabled == (pages == 1) and next.disabled == (pages == 3), "shelf pages: page %d reads %d/3, arrows disabled only at the ends" % [pages, pages], "%s %s %s" % [label.text, prev.disabled, next.disabled])
		if next.disabled:
			break
		# Turns closer than SFX_MIN_GAP share one flip sound.
		await _frames(ceili(GameState.SFX_MIN_GAP * 60.0) + 1)
		_game.sfx_log.clear()
		await _tap(next)
		_check(_game.sfx_log == ([&"page_flip"] as Array[StringName]), "shelf pages: a page turn plays only the page flip", str(_game.sfx_log))
	seen.sort()
	var all: Array[String] = []
	for id: String in shop.stock:
		all.append(id)
	all.sort()
	_check(pages == 3 and seen == all, "shelf pages: each of the ten items is on exactly one page", "%d pages %s" % [pages, seen])
	await _tap(next)
	_check(shop.shelf_page == 2, "shelf pages: the disabled Next does not wrap", str(shop.shelf_page))
	await _tap(prev)
	_check(shop.shelf_page == 1 and label.text == "2/3", "shelf pages: a tap on Prev turns back a page", label.text)
	await _frames(2)
	_check(not prev.scale.is_equal_approx(Vector2.ONE), "shelf pages: the arrow squashes at once", str(prev.scale))
	prev.grab_focus()
	await _action(&"ui_accept")
	_check(shop.shelf_page == 0 and label.text == "1/3", "shelf pages: Enter on Prev turns back a page", label.text)
	await _tap(next)
	var play: Array[Control] = [prev, next]
	for item in _shown_items(shop):
		play.append(item)
	var pause := shop.get_node("Column/Hud/PauseButton") as Control
	for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
		root.size = window
		await _frames(30)
		_check_targets(play, pause, "shelf pages at %s" % window)
	root.size = BASE_WINDOW
	await _frames(10)
	if await _wait_for_order(shop, "shelf pages"):
		var page_two := _shown_items(shop)
		var last := page_two[-1]
		shop.stock[last.ingredient.id] = 1
		last.set_stock(1)
		var at := last.position
		await _tap(last)
		_check(shop.shelf_page == 1 and shop.pot.size() == 1 and last.disabled and last.visible and last.position == at, "shelf pages: an item tapped to 0 stock keeps its slot and the page stays", "page %d pot %d %s %s" % [shop.shelf_page, shop.pot.size(), last.disabled, last.position])
		await _tap(shop.slot_button(0))
		_check(shop.shelf_page == 1 and shop.pot.is_empty() and not last.disabled, "shelf pages: taking it out of the pot keeps the page", "page %d pot %d" % [shop.shelf_page, shop.pot.size()])
		var from := page_two[0].get_global_rect().get_center()
		await _drag_touch(from, shop.get_node("Column/Stage").get_global_transform() * Shop.POT_MOUTH)
		_check(shop.shelf_page == 1 and shop.pot.size() == 1 and shop.pot[0].id == page_two[0].ingredient.id, "shelf pages: a page-2 item dragged into the cauldron goes in", "page %d pot %d" % [shop.shelf_page, shop.pot.size()])
	await _close_shop()
	_game.new_game()


## Keyboard across shelf pages: Right from a page's last item focuses Next, Right
## again turns the page onto its first item; Left mirrors it through Prev. Down from
## an item is Brew, Up from Brew is the middle item of the page showing, and focus
## never lands on a hidden item.
func _test_shop_shelf_pages_keyboard() -> void:
	var shop := await _open_day6_shop("shelf keys")
	if shop == null:
		return
	var prev := shop.get_node("Column/Stage/ShelfPrev") as Button
	var next := shop.get_node("Column/Stage/ShelfNext") as Button
	var page_one := _shown_items(shop)
	page_one[-1].grab_focus()
	await _action(&"ui_right")
	_check(root.gui_get_focus_owner() == next, "shelf keys: Right from the page's last item focuses Next", str(root.gui_get_focus_owner()))
	await _action(&"ui_right")
	var page_two := _shown_items(shop)
	_check(shop.shelf_page == 1 and root.gui_get_focus_owner() == page_two[0], "shelf keys: Right from Next turns the page onto its first item", "page %d %s" % [shop.shelf_page, root.gui_get_focus_owner()])
	await _action(&"ui_left")
	_check(root.gui_get_focus_owner() == prev and shop.shelf_page == 1, "shelf keys: Left from the page's first item focuses Prev", str(root.gui_get_focus_owner()))
	await _action(&"ui_left")
	_check(shop.shelf_page == 0 and root.gui_get_focus_owner() == page_one[-1], "shelf keys: Left from Prev turns back onto the last item", "page %d %s" % [shop.shelf_page, root.gui_get_focus_owner()])
	var visible_focus := true
	for i in 12:
		await _action(&"ui_right")
		var owner := root.gui_get_focus_owner()
		visible_focus = visible_focus and owner != null and owner.is_visible_in_tree()
	_check(visible_focus and shop.shelf_page == 2, "shelf keys: walking right across every page never focuses a hidden item", "page %d" % shop.shelf_page)
	shop.set_shelf_page(1)
	_shown_items(shop)[1].grab_focus()
	await _action(&"ui_down")
	_check(root.gui_get_focus_owner() == shop.brew_button(), "shelf keys: Down from a page-2 item focuses Brew", str(root.gui_get_focus_owner()))
	await _action(&"ui_up")
	var shown := _shown_items(shop)
	_check(root.gui_get_focus_owner() == shown[floori((shown.size() - 1) / 2.0)], "shelf keys: Up from Brew focuses the middle item of the page showing", str(root.gui_get_focus_owner()))
	await _close_shop()
	_game.new_game()


## A real tap on the shelf item of ingredient `id`, its shelf page turned to first.
func _tap_item(shop: Shop, id: String) -> void:
	shop.show_shelf_item(shop.shelf_item(id))
	await _tap(shop.shelf_item(id))


## A real touch (press and release) at the centre of `control`.
func _tap(control: Control) -> void:
	await _tap_at(control.get_global_rect().get_center())


## A real touch (press and release) at canvas point `point`.
func _tap_at(point: Vector2) -> void:
	var at := root.get_final_transform() * point
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = TOUCH_INDEX
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
	touch.index = TOUCH_INDEX
	touch.position = screen * from
	touch.pressed = true
	Input.parse_input_event(touch)
	await process_frame
	for i in range(1, 9):
		var drag := InputEventScreenDrag.new()
		drag.index = TOUCH_INDEX
		drag.position = screen * from.lerp(to, i / 8.0)
		Input.parse_input_event(drag)
		await process_frame
	var release := InputEventScreenTouch.new()
	release.index = TOUCH_INDEX
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


## The x of each turn-around for `strokes` scrubs `reach` either side of the
## mortar's centre line, starting at the left (where the finger touches down).
func _scrub_points(reach: float, strokes: int) -> Array[float]:
	var points: Array[float] = [Mortar.CENTRE.x - reach]
	for i in strokes:
		points.append(Mortar.CENTRE.x + (reach if i % 2 == 0 else -reach))
	return points


## Scrubs `strokes` strokes turning `reach` either side of the mortar's centre line,
## SCRUB_FRAMES frames per stroke, then lifts the finger.
func _scrub(mortar: Mortar, reach: float, strokes: int) -> void:
	var points := _scrub_points(reach, strokes)
	mortar.feed(_touch(Vector2(points[0], Mortar.RAIL_Y), true))
	for i in range(1, points.size()):
		for frame in range(1, SCRUB_FRAMES + 1):
			mortar.advance(FRAME)
			mortar.feed(_drag(Vector2(lerpf(points[i - 1], points[i], float(frame) / SCRUB_FRAMES), Mortar.RAIL_Y)))
	mortar.feed(_touch(Vector2(points.back(), Mortar.RAIL_Y), false))


## Scrubs mark to mark through the running game loop (one drag per rendered frame)
## until the station finishes.
func _drive_scrub(mortar: Mortar) -> void:
	var points := _scrub_points(Mortar.MARK_X, Mortar.STROKES)
	mortar.feed(_touch(Vector2(points[0], Mortar.RAIL_Y), true))
	for i in range(1, points.size()):
		for frame in range(1, SCRUB_FRAMES + 1):
			await process_frame
			if not mortar.is_running():
				return
			mortar.feed(_drag(Vector2(lerpf(points[i - 1], points[i], float(frame) / SCRUB_FRAMES), Mortar.RAIL_Y)))
	mortar.feed(_touch(Vector2(points.back(), Mortar.RAIL_Y), false))


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
	touch.index = TOUCH_INDEX
	touch.position = at
	touch.pressed = pressed
	return touch


func _drag(at: Vector2) -> InputEventScreenDrag:
	var drag := InputEventScreenDrag.new()
	drag.index = TOUCH_INDEX
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


## True when sound effect `id` is among the latest ones played (Game.sfx_log).
func _heard(id: StringName) -> bool:
	return id in _game.sfx_log


## Every sound effect id has its synthesised file and nothing else sits in
## audio/sfx/ but the voices; repeats of one sound inside SFX_MIN_GAP are dropped,
## later ones play; nothing plays before the first input.
func _test_sfx_catalog_and_throttle() -> void:
	var missing := GameState.SFX_IDS.filter(func(id: StringName) -> bool: return not ResourceLoader.exists(GameState.SFX_PATH % id))
	_check(missing.is_empty(), "every sound effect id has its file", str(missing))
	var stray := PackedStringArray()
	for file in DirAccess.get_files_at("res://audio/sfx"):
		if file.ends_with(".wav") and not file.begins_with("voice_") and not StringName(file.get_basename()) in GameState.SFX_IDS:
			stray.append(file)
	_check(stray.is_empty(), "audio/sfx holds only voices and SFX_IDS sounds", str(stray))
	var cued := Shop.STATION_SOUNDS.values().all(func(id: StringName) -> bool: return id in GameState.SFX_IDS) and Shop.STAMP_SOUNDS.all(func(id: StringName) -> bool: return id in GameState.SFX_IDS)
	_check(cued and Shop.STAMP_SOUNDS.size() == Brew.Grade.size(), "station cues and stamps map to known sounds", str(Shop.STATION_SOUNDS))
	var cues: Array[StringName] = [&"stir_rotation", &"pour_start", &"pour_spill", &"pour_stop", &"mortar_stroke", &"bellows_pump", &"bellows_out", &"station_success", &"station_sloppy"]
	_check(Shop.STATION_SOUNDS.keys() == cues, "every Station.feedback cue has a sound", str(Shop.STATION_SOUNDS.keys()))
	_game.sfx_log.clear()
	_game.sfx(&"stir")
	_game.sfx(&"stir")
	await _frames(1)
	_game.sfx(&"stir")
	_check(_game.sfx_log == ([&"stir"] as Array[StringName]), "a sound repeated inside SFX_MIN_GAP is dropped", str(_game.sfx_log))
	await _frames(ceili(GameState.SFX_MIN_GAP * 60.0) + 1)
	_game.sfx(&"stir")
	_game.sfx(&"coins")
	_check(_game.sfx_log == ([&"stir", &"stir", &"coins"] as Array[StringName]), "after SFX_MIN_GAP it plays again; other sounds are not held back", str(_game.sfx_log))
	_check(GameState.SFX_VOICES >= 4 and GameState.SFX_MIN_GAP > 0.0 and GameState.SFX_JITTER.has(&"stir") and GameState.SFX_JITTER.has(&"coin_tick") and GameState.SFX_JITTER.has(&"bellows_pump"), "repeated sounds are throttled and pitch-jittered", str(GameState.SFX_JITTER))


## Each flow state asks for its track (TITLE title; MORNING, story SHOP, SUMMARY,
## MARKET shop; Rush Hour SHOP and RESULTS rush; ENDING ending); going between two
## screens of one track keeps it playing (no new start); a new track crossfades
## (at most 1 s); a track starts as soon as it is asked for, with no input first.
func _test_music_tracks() -> void:
	var expected: Dictionary[GameState.Flow, StringName] = {
		GameState.Flow.TITLE: &"title", GameState.Flow.MORNING: &"shop", GameState.Flow.SHOP: &"shop", GameState.Flow.SUMMARY: &"shop",
		GameState.Flow.MARKET: &"shop", GameState.Flow.ENDING: &"ending", GameState.Flow.RESULTS: &"rush",
	}
	for state: GameState.Flow in expected:
		_check(GameState.track_for(state, {}) == expected[state], "music: %s plays %s" % [GameState.Flow.keys()[state], expected[state]], str(GameState.track_for(state, {})))
	_check(GameState.track_for(GameState.Flow.SHOP, {"rush": 3}) == &"rush" and GameState.track_for(GameState.Flow.SHOP, {"day": 2}) == &"shop", "music: a Rush Hour shop plays rush, a story day shop", "")
	for track: StringName in [&"title", &"shop", &"rush", &"ending"]:
		var stream := load(GameState.MUSIC_PATH % track) as AudioStreamMP3
		_check(stream != null and stream.loop, "music: %s is a looping MP3" % track, str(stream))
	_check(AudioServer.get_bus_index(GameState.MUSIC_BUS) > 0 and AudioServer.get_bus_index(GameState.SFX_BUS) > 0 and AudioServer.get_bus_index(GameState.MUSIC_BUS) != AudioServer.get_bus_index(GameState.SFX_BUS), "music: Music and SFX are buses of their own", "")
	_check(GameState.CROSSFADE_TIME > 0.0 and GameState.CROSSFADE_TIME <= 1.0, "music: a change of track crossfades within 1 s", str(GameState.CROSSFADE_TIME))
	_game.new_game()
	await _goto_scene(GameState.Flow.TITLE)
	_check(_game.music_track == &"title" and _game.music_started == &"title", "music: the title plays title", "%s %s" % [_game.music_track, _game.music_started])
	var changes := _game.music_changes
	await _goto_scene(GameState.Flow.MORNING)
	_check(_game.music_track == &"shop" and _game.music_changes == changes + 1, "music: the morning crossfades to shop", "%s %d" % [_game.music_track, _game.music_changes - changes])
	await _goto_scene(GameState.Flow.SHOP, {"day": 1})
	_check(_game.music_track == &"shop" and _game.music_changes == changes + 1, "music: the shop keeps the morning's track playing", "%s %d" % [_game.music_track, _game.music_changes - changes])
	await _goto_scene(GameState.Flow.SHOP, {"rush": 11})
	_check(_game.music_track == &"rush" and _game.music_started == &"rush" and _game.music_changes == changes + 2, "music: a Rush Hour shop plays rush", "%s %d" % [_game.music_track, _game.music_changes - changes])
	await _goto_scene(GameState.Flow.TITLE)
	_game.play_music(&"ending")
	_check(_game.music_track == &"ending" and _game.music_started == &"ending", "music: a track starts at once, no input needed", "%s %s" % [_game.music_track, _game.music_started])
	_game.play_music(&"title")


## Every sound of a shop shift plays as it happens: the door bell on arrival, the
## drop and the splash of an ingredient, "nope" on a full pot, the pot-slot removal,
## a button tap, the Codex opening, each station cue's sound (Shop.STATION_SOUNDS),
## the stamp, coins, coin ticks and tip of a serve, "Codex +N", a refusal.
func _test_shop_sounds() -> void:
	_game.assist_mode = true
	var shop := await _open_shop()
	_game.sfx_log.clear()
	if not await _wait_for_order(shop, "sounds"):
		await _close_shop()
		return
	_check(_heard(&"door_bell"), "sounds: a customer walking in rings the door bell", str(_game.sfx_log))
	var recipe := _exact_recipe(shop.customer.potion, shop.stock)
	_game.sfx_log.clear()
	await _tap_item(shop, recipe[0])
	_check(_game.sfx_log == ([&"drop"] as Array[StringName]), "sounds: putting an ingredient in plays the drop at once (no tap)", str(_game.sfx_log))
	await _frames(30)
	_check(_heard(&"splash"), "sounds: the ingredient lands with a splash", str(_game.sfx_log))
	_game.sfx_log.clear()
	await _tap(shop.slot_button(0))
	_check(_game.sfx_log == ([&"slot_remove"] as Array[StringName]), "sounds: taking it out plays the slot removal", str(_game.sfx_log))
	var filler := ""
	for id: String in shop.stock:
		if shop.stock[id] >= 4:
			filler = id
			break
	for i in Shop.POT_CAPACITY:
		await _tap_item(shop, filler)
		await _frames(4)
	_game.sfx_log.clear()
	await _tap_item(shop, filler)
	_check(_game.sfx_log == ([&"nope"] as Array[StringName]), "sounds: a full pot refuses with nope", str(_game.sfx_log))
	while not shop.pot.is_empty():
		await _tap(shop.slot_button(0))
		await _frames(4)
	_game.sfx_log.clear()
	await _tap(shop.get_node("Column/Hud/PauseButton") as Button)
	_check(_game.sfx_log == ([&"tap"] as Array[StringName]), "sounds: a plain button press taps", str(_game.sfx_log))
	shop.close_pause()
	await _frames(4)
	_game.sfx_log.clear()
	await _tap(shop.get_node("Column/Stage/CodexButton") as Button)
	_check(_game.sfx_log == ([&"codex_open"] as Array[StringName]), "sounds: the Codex opens with its own sound", str(_game.sfx_log))
	if shop.codex != null:
		shop.codex.close()
	await _frames(4)
	_refill_patience(shop)
	for id in recipe:
		await _tap_item(shop, id)
	var words_before := _game.codex_words().size() + _game.codex_recipes().size()
	await _tap(shop.brew_button())
	if await _until(func() -> bool: return shop.station != null and shop.station.is_running(), FLOW_FRAMES):
		for cue: StringName in Shop.STATION_SOUNDS:
			_game.sfx_log.clear()
			shop._on_station_feedback(cue)
			_check(_game.sfx_log == ([Shop.STATION_SOUNDS[cue]] as Array[StringName]), "sounds: station cue %s plays %s" % [cue, Shop.STATION_SOUNDS[cue]], str(_game.sfx_log))
			await _frames(4)
	else:
		_check(false, "sounds: the brew starts a station", "no station")
	_game.sfx_log.clear()
	var served := shop.served
	for step in shop.customer.potion.steps.size():
		if not await _until(func() -> bool: return shop.station != null and shop.station.assist_button() != null, FLOW_FRAMES):
			break
		await _tap(shop.station.assist_button())
	_check(await _until(func() -> bool: return shop.served == served + 1, FLOW_FRAMES), "sounds: the customer is served", str(shop.served))
	_check(_heard(&"success") and not _heard(&"tap"), "sounds: each Assist press plays the station's success, no tap", str(_game.sfx_log))
	_check(_heard(&"stamp_good") and _heard(&"coins") and _heard(&"tip") == (shop.tips > 0), "sounds: the Good stamp, the coins and (with a tip) the tip", "tips %d, %s" % [shop.tips, _game.sfx_log])
	_check(_heard(&"codex_new") == (_game.codex_words().size() + _game.codex_recipes().size() > words_before), "sounds: Codex +N chimes when the Codex learns something", str(_game.sfx_log))
	await _frames(40)
	_check(_heard(&"coin_tick"), "sounds: coins landing on the counter tick", str(_game.sfx_log))
	for grade in Brew.Grade.size():
		await _frames(4)
		_game.sfx_log.clear()
		shop._show_stamp(grade)
		_check(_game.sfx_log == ([Shop.STAMP_SOUNDS[grade]] as Array[StringName]), "sounds: the %s stamp plays %s" % [Brew.Grade.keys()[grade], Shop.STAMP_SOUNDS[grade]], str(_game.sfx_log))
	await _skip_lines(shop)
	if await _wait_for_order(shop, "sounds: refuse"):
		_game.sfx_log.clear()
		await _tap(shop.get_node("Column/Stage/RefuseButton") as Button)
		_check(_game.sfx_log == ([&"refuse"] as Array[StringName]), "sounds: refusing plays only the refuse sound", str(_game.sfx_log))
	await _close_shop()


## The volume settings: defaults 70 (music) and 80 (SFX); each set applies to its
## bus at once (linear, 0 mutes it) and saves; the pause panel's sliders follow touch
## (a tap sets the value under the finger) and the keyboard (ui_left/ui_right one
## step), name the setting and its value, and play a sample tap.
func _test_volume_settings() -> void:
	_check(GameState.DEFAULT_MUSIC_VOLUME == 70 and GameState.DEFAULT_SFX_VOLUME == 80 and GameState.VOLUME_STEP == 10 and GameState.VOLUME_MAX == 100, "volumes: defaults 70 and 80, steps of 10 to 100", "")
	var music_bus := AudioServer.get_bus_index(GameState.MUSIC_BUS)
	var sfx_bus := AudioServer.get_bus_index(GameState.SFX_BUS)
	_check(_game.music_volume == 70 and AudioServer.get_bus_volume_db(music_bus) < 0.0, "volumes: the music bus starts below 0 dB", str(AudioServer.get_bus_volume_db(music_bus)))
	_game.set_music_volume(50)
	_game.set_sfx_volume(0)
	_check(is_equal_approx(AudioServer.get_bus_volume_linear(music_bus), 0.5) and not AudioServer.is_bus_mute(music_bus) and AudioServer.is_bus_mute(sfx_bus), "volumes: applied to the buses, 0 mutes", "%f %s" % [AudioServer.get_bus_volume_linear(music_bus), AudioServer.is_bus_mute(sfx_bus)])
	var settings: Dictionary = _read_save().get("settings", {})
	_check(settings.get("music") == 50.0 and settings.get("sfx") == 0.0, "volumes: saved at once", str(settings))
	_game.set_sfx_volume(37)
	_check(_game.sfx_volume == 40 and not AudioServer.is_bus_mute(sfx_bus), "volumes: snapped to the step, unmuted above 0", str(_game.sfx_volume))
	_game.set_music_volume(GameState.DEFAULT_MUSIC_VOLUME)
	_game.set_sfx_volume(GameState.DEFAULT_SFX_VOLUME)
	var shop := await _open_shop()
	shop.open_pause()
	await _frames(5)
	var music := shop.get_node("Modal/Panel/List/MusicRow/Slider") as VolumeSlider
	var sfx := shop.get_node("Modal/Panel/List/SfxRow/Slider") as VolumeSlider
	_check(music.value == 70 and sfx.value == 80 and music.accessibility_name == "Music volume 70 of 100" and sfx.accessibility_name == "Sound effects volume 80 of 100", "volumes: the sliders show the settings and name them", "%s / %s" % [music.accessibility_name, sfx.accessibility_name])
	_check(music.get_theme_stylebox(&"focus") is StyleBoxFlat and (music.get_theme_stylebox(&"focus") as StyleBoxFlat).border_width_top >= 2, "volumes: a slider has a visible focus style", str(music.get_theme_stylebox(&"focus")))
	music.grab_focus()
	_game.sfx_log.clear()
	await _action(&"ui_left")
	_check(_game.music_volume == 60 and music.value == 60 and music.accessibility_name == "Music volume 60 of 100" and _heard(&"tap"), "volumes: Left lowers the music by a step with a sample tap", "%d %s" % [_game.music_volume, _game.sfx_log])
	await _frames(4)
	await _action(&"ui_right")
	await _frames(4)
	await _action(&"ui_right")
	_check(_game.music_volume == 80 and root.gui_get_focus_owner() == music, "volumes: Right raises it a step at a time, focus stays", "%d %s" % [_game.music_volume, root.gui_get_focus_owner()])
	var rect := sfx.get_global_rect()
	await _tap_at(Vector2(rect.position.x + 1.0, rect.get_center().y))
	_check(_game.sfx_volume == 0 and AudioServer.is_bus_mute(sfx_bus) and sfx.accessibility_name == "Sound effects volume 0 of 100 (muted)", "volumes: a tap at the slider's left end mutes the sound effects", "%d %s" % [_game.sfx_volume, sfx.accessibility_name])
	await _drag_touch(Vector2(rect.position.x + 1.0, rect.get_center().y), Vector2(rect.get_center().x, rect.get_center().y))
	_check(_game.sfx_volume == 50 and int(_read_save()["settings"]["sfx"]) == 50, "volumes: a drag to the middle sets 50 and saves it", "%d" % _game.sfx_volume)
	await _tap_at(Vector2(rect.end.x - 1.0, rect.get_center().y))
	_check(_game.sfx_volume == 100, "volumes: a tap at the right end sets 100", str(_game.sfx_volume))
	shop.close_pause()
	_game.set_music_volume(GameState.DEFAULT_MUSIC_VOLUME)
	_game.set_sfx_volume(GameState.DEFAULT_SFX_VOLUME)
	await _close_shop()


## The shop HUD's music and sound toggles, in a story day and in Rush Hour: one top-right
## row (music, sound, the menu icon), 32x32, in the safe area, above the highest speech
## bubble and clear of the HUD labels at 9:16, 9:19.5 and 16:9. A tap or Enter mutes and
## unmutes each bus without touching its volume (icon, name and save follow); unmuting the
## sound effects plays a sample tap, muting them nothing. Left/Right walk the row and Down
## leaves it into the shop. The mutes reload from the save, a volume slider turned up
## unmutes its bus, and the toggles take no tap under the pause panel or the Codex.
func _test_sound_toggles() -> void:
	var music_bus := AudioServer.get_bus_index(GameState.MUSIC_BUS)
	var sfx_bus := AudioServer.get_bus_index(GameState.SFX_BUS)
	for args: Dictionary in [{}, {"rush": 5}]:
		var visited := await _goto_scene(GameState.Flow.SHOP, args) as Shop
		var kind := "Rush Hour" if args.has("rush") else "story"
		_game.assist_mode = true
		visited._sync_setting_buttons()
		if args.has("rush"):
			# The Served label at its widest: a long run, in the last wave.
			visited.served = 99
			visited._update_hud()
			var served_text := (visited.get_node("Column/Hud/Served") as Label).text
			_check(served_text == "Served 99, wave %d" % Rush.WAVE_DAYS.size(), "sound toggles (Rush Hour): measured with the widest Served label", served_text)
		else:
			var served_label := visited.get_node("Column/Hud/Served") as Label
			_check(served_label.text == "Day %d, served 0/%d" % [visited.shift.day, visited.shift.customers.size()], "sound toggles (story): the HUD shows the day", served_label.text)
			# Measured at its widest: the last day number and day 5's ten customers.
			served_label.text = "Day %d, served 10/10" % Content.days().size()
		var row: Array[Control] = []
		for node_name: String in ["MusicToggle", "SfxToggle", "PauseButton"]:
			row.append(visited.get_node("Column/Hud/" + node_name) as Control)
		var bubble := visited.get_node("Column/Stage/Bubble") as SpeechBubble
		var line_height := bubble.text_font().get_height(bubble.text_font_size()) + SpeechBubble.LINE_SPACING
		var bubble_box := line_height * 3.0 - SpeechBubble.LINE_SPACING + SpeechBubble.PADDING.y * 2.0
		for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
			root.size = window
			await _frames(10)
			var label := "sound toggles (%s) at %s" % [kind, window]
			var safe := _game.safe_rect()
			_check(row.all(func(control: Control) -> bool: return safe.encloses(control.get_global_rect())), label + ": inside the safe area", "%s in %s" % [row.map(func(control: Control) -> Rect2: return control.get_global_rect()), safe])
			var bubble_top := (visited.get_node("Column/Stage") as Control).get_global_rect().position.y + SpeechBubble.BOTTOM_Y - bubble_box
			var rects: Array[Rect2] = []
			rects.assign(row.map(func(control: Control) -> Rect2: return control.get_global_rect()))
			_check(rects.all(func(rect: Rect2) -> bool: return rect.size == Vector2(32, 32) and is_equal_approx(rect.position.y, rects[0].position.y) and rect.end.y <= bubble_top), label + ": one row of 32x32 above the speech bubble", "%s, bubble top %.0f" % [rects, bubble_top])
			_check(rects[0].end.x <= rects[1].position.x and rects[1].end.x <= rects[2].position.x, label + ": music, sound, menu left to right, not overlapping", str(rects))
			for hud_label: String in ["Coins", "Served", "Reputation", "AssistTag"]:
				var text := visited.get_node("Column/Hud/" + hud_label) as Label
				if not text.visible:
					continue
				var box := text.get_global_rect()
				var width := text.get_minimum_size().x
				var drawn := Rect2(box.end.x - width if text.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT else box.position.x, box.position.y, width, box.size.y)
				_check(width <= box.size.x, "%s: %s fits its box" % [label, hud_label], "%.0f > %.0f" % [width, box.size.x])
				_check(rects.all(func(rect: Rect2) -> bool: return not rect.intersects(drawn)), "%s: clear of %s" % [label, hud_label], "%s vs %s" % [rects, drawn])
		root.size = BASE_WINDOW
		_game.assist_mode = false
		visited._sync_setting_buttons()
		visited.served = 0
		visited._update_hud()
		await _frames(5)
	var shop := current_scene as Shop
	var music := shop.get_node("Column/Hud/MusicToggle") as Button
	var sfx := shop.get_node("Column/Hud/SfxToggle") as Button
	var pause := shop.get_node("Column/Hud/PauseButton") as Button
	var icon_of := func(toggle: Button) -> Rect2: return ((toggle.get_node("Icon") as TextureRect).texture as AtlasTexture).region
	_check(icon_of.call(music) == Art.texture("ui", "icon_music").region and music.accessibility_name == "Music on, tap to mute" and sfx.accessibility_name == "Sound effects on, tap to mute", "sound toggles: start on, named and showing the plain icons", "%s / %s" % [music.accessibility_name, sfx.accessibility_name])
	# A customer reaching the counter takes keyboard focus; let that happen before the keyboard checks.
	await _wait_for_order(shop, "sound toggles")
	_game.sfx_log.clear()
	await _tap(music)
	_check(_game.music_muted and AudioServer.is_bus_mute(music_bus) and _game.music_volume == GameState.DEFAULT_MUSIC_VOLUME and icon_of.call(music) == Art.texture("ui", "icon_music_off").region and music.accessibility_name == "Music muted, tap to unmute" and _read_save()["settings"]["music_muted"] == true and _heard(&"tap"), "sound toggles: a tap mutes the music, volume kept, slashed icon, saved", "%s %s %d %s" % [_game.music_muted, AudioServer.is_bus_mute(music_bus), _game.music_volume, music.accessibility_name])
	await _frames(4)
	await _tap(music)
	_check(not _game.music_muted and not AudioServer.is_bus_mute(music_bus) and is_equal_approx(AudioServer.get_bus_volume_linear(music_bus), GameState.DEFAULT_MUSIC_VOLUME / 100.0) and music.accessibility_name == "Music on, tap to mute" and _read_save()["settings"]["music_muted"] == false, "sound toggles: a second tap brings the music back at its volume", "%s %f" % [_game.music_muted, AudioServer.get_bus_volume_linear(music_bus)])
	sfx.grab_focus()
	_game.sfx_log.clear()
	await _action(&"ui_accept")
	_check(_game.sfx_muted and AudioServer.is_bus_mute(sfx_bus) and _game.sfx_volume == GameState.DEFAULT_SFX_VOLUME and icon_of.call(sfx) == Art.texture("ui", "icon_sound_off").region and sfx.accessibility_name == "Sound effects muted, tap to unmute" and not _heard(&"tap"), "sound toggles: Enter mutes the sound effects, no tap played", "%s %s %s" % [_game.sfx_muted, sfx.accessibility_name, _game.sfx_log])
	await _frames(4)
	await _action(&"ui_accept")
	_check(not _game.sfx_muted and not AudioServer.is_bus_mute(sfx_bus) and _heard(&"tap") and sfx.accessibility_name == "Sound effects on, tap to mute", "sound toggles: Enter again unmutes them with a sample tap", "%s %s" % [_game.sfx_muted, _game.sfx_log])
	_check(icon_of.call(music) == Art.texture("ui", "icon_music").region and icon_of.call(sfx) == Art.texture("ui", "icon_sound").region, "sound toggles: unmuted, both show the plain icons again", "")
	await _frames(4)
	await _tap(sfx)
	_check(_game.sfx_muted and AudioServer.is_bus_mute(sfx_bus), "sound toggles: a tap mutes the sound effects too", str(_game.sfx_muted))
	await _frames(4)
	await _tap(sfx)
	music.grab_focus()
	await _action(&"ui_accept")
	_check(_game.music_muted and not _game.sfx_muted, "sound toggles: Enter mutes the music too", "%s %s" % [_game.music_muted, _game.sfx_muted])
	await _frames(4)
	await _action(&"ui_accept")
	_game.set_music_volume(0)
	_game.set_sfx_volume(0)
	_check(icon_of.call(music) == Art.texture("ui", "icon_music_off").region and sfx.accessibility_name == "Sound effects muted, tap to unmute", "sound toggles: a slider at 0 shows the toggle muted", sfx.accessibility_name)
	await _frames(4)
	await _tap(music)
	await _frames(4)
	_game.sfx_log.clear()
	await _tap(sfx)
	_check(_game.music_volume == GameState.DEFAULT_MUSIC_VOLUME and _game.sfx_volume == GameState.DEFAULT_SFX_VOLUME and not _game.music_silent() and not _game.sfx_silent() and _heard(&"tap"), "sound toggles: at volume 0 a press brings the default volume back", "%d %d %s" % [_game.music_volume, _game.sfx_volume, _game.sfx_log])
	music.grab_focus()
	await _action(&"ui_right")
	var after_right := root.gui_get_focus_owner()
	await _action(&"ui_right")
	_check(after_right == sfx and root.gui_get_focus_owner() == pause, "sound toggles: Right walks music, sound, menu", "%s %s" % [after_right, root.gui_get_focus_owner()])
	await _action(&"ui_left")
	await _action(&"ui_left")
	_check(root.gui_get_focus_owner() == music, "sound toggles: Left walks back", str(root.gui_get_focus_owner()))
	await _action(&"ui_down")
	var below := root.gui_get_focus_owner()
	_check(below == shop.get_node("Column/Stage/BrewButton"), "sound toggles: Down leaves the row for Brew", str(below))
	_game.set_sfx_muted(true)
	_game.sfx_muted = false
	_game.load_game()
	_check(_game.sfx_muted and AudioServer.is_bus_mute(sfx_bus) and sfx.accessibility_name == "Sound effects muted, tap to unmute", "sound toggles: a mute reloads from the save", "%s %s" % [_game.sfx_muted, sfx.accessibility_name])
	shop.open_pause()
	await _frames(5)
	var slider := shop.get_node("Modal/Panel/List/SfxRow/Slider") as VolumeSlider
	var value := shop.get_node("Modal/Panel/List/SfxRow/Value") as Label
	_check(slider.value == GameState.DEFAULT_SFX_VOLUME and slider.accessibility_name.ends_with("(muted)") and value.text == SettingsPanel.MUTED_TEXT and slider.modulate == SettingsPanel.MUTED_TINT, "sound toggles: the muted slider keeps its level, reads off and fades", "%s %s %s" % [slider.accessibility_name, value.text, slider.modulate])
	var music_value := shop.get_node("Modal/Panel/List/MusicRow/Value") as Label
	_check(music_value.text == str(_game.music_volume) and (shop.get_node("Modal/Panel/List/MusicRow/Slider") as Control).modulate == Color.WHITE, "sound toggles: the unmuted music slider shows its level, not faded", music_value.text)
	await _tap(sfx)
	_check(_game.sfx_muted, "sound toggles: no tap reaches them under the pause panel", str(_game.sfx_muted))
	slider.grab_focus()
	await _action(&"ui_right")
	_check(not _game.sfx_muted and _game.sfx_volume == GameState.DEFAULT_SFX_VOLUME + GameState.VOLUME_STEP and sfx.accessibility_name == "Sound effects on, tap to mute", "sound toggles: turning the slider up unmutes and the toggle follows", "%s %d %s" % [_game.sfx_muted, _game.sfx_volume, sfx.accessibility_name])
	_check(value.text == str(_game.sfx_volume) and slider.modulate == Color.WHITE, "sound toggles: unmuted, the slider shows its level again, not faded", "%s %s" % [value.text, slider.modulate])
	shop.close_pause()
	await _frames(5)
	shop.open_codex()
	await _frames(5)
	await _tap(music)
	_check(not _game.music_muted, "sound toggles: no tap reaches them under the Codex", str(_game.music_muted))
	shop.codex.close()
	await _frames(5)
	_game.set_music_muted(false)
	_game.set_sfx_muted(false)
	_game.set_sfx_volume(GameState.DEFAULT_SFX_VOLUME)
	await _close_shop()


## The settings rows (Assist and Gentle with their "?", the two volume sliders) on the
## title's Settings panel and in the pause panel: every control 32x32 or more, inside
## the safe area and in the thumb zone at 9:16, 9:19.5 and 16:9. The title's panel
## opens from its Settings button, toggles Assist (saved), shows the mode help,
## and closes with Close or Escape (focus back on Settings).
func _test_settings_panels_layout() -> void:
	await _goto_scene(GameState.Flow.TITLE)
	var title := current_scene as Title
	var open := title.get_node("Column/SettingsButton") as Button
	var list := title.get_node("Settings/Panel/List")
	var rows: Array[Control] = [open]
	for path: String in ["AssistRow/AssistButton", "AssistRow/AssistHelp", "GentleRow/GentleButton", "GentleRow/GentleHelp", "MusicRow/Slider", "SfxRow/Slider", "CloseButton"]:
		rows.append(list.get_node(path) as Control)
	_check(list.get_child(list.get_child_count() - 1).name == "CloseButton" and open.accessibility_name != "", "settings: the title's panel ends with Close; Settings is named", str(list.get_children()))
	for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
		root.size = window
		await _frames(10)
		_check_targets([open] as Array[Control], null, "title Settings button at %s" % window)
		await _tap(open)
		await _frames(10)
		_check_targets(rows.slice(1), null, "title settings panel at %s" % window)
		await _key(KEY_ESCAPE)
		await _frames(5)
	root.size = BASE_WINDOW
	await _frames(5)
	await _tap(open)
	var assist := list.get_node("AssistRow/AssistButton") as Button
	_check((title.get_node("Settings/Panel") as Control).visible and root.gui_get_focus_owner() == assist, "settings: the title's Settings opens the panel, focus on Assist", str(root.gui_get_focus_owner()))
	_check(await _focus_stays_in(title.get_node("Settings/Panel") as Control), "settings: focus stays in the title's panel", str(root.gui_get_focus_owner()))
	await _tap(assist)
	_check(_game.assist_mode and _read_save()["settings"]["assist"] == true and assist.text == "Assist mode: On", "settings: Assist toggled on the title is saved", assist.text)
	await _tap(assist)
	var help := list.get_node("GentleRow/GentleHelp") as Button
	await _tap(help)
	var mode_help := title.get_node("Settings/ModeHelp") as Button
	_check(mode_help.visible and mode_help.accessibility_name == SettingsPanel.GENTLE_INFO, "settings: the title's \"?\" opens the mode help", str(mode_help.visible))
	await _key(KEY_ESCAPE)
	_check(not mode_help.visible and (title.get_node("Settings/Panel") as Control).visible and root.gui_get_focus_owner() == help, "settings: Escape closes the help first, the panel stays", str(root.gui_get_focus_owner()))
	await _key(KEY_ESCAPE)
	_check(not (title.get_node("Settings/Panel") as Control).visible and root.gui_get_focus_owner() == open, "settings: Escape then closes the panel, focus back on Settings", str(root.gui_get_focus_owner()))
	await _tap(open)
	await _tap(list.get_node("CloseButton") as Button)
	_check(not (title.get_node("Settings/Panel") as Control).visible, "settings: Close closes the panel", "")
	var shop := await _open_shop()
	var pause := shop.get_node("Column/Hud/PauseButton") as Button
	var pause_list := shop.get_node("Modal/Panel/List")
	var pause_rows: Array[Control] = []
	for path: String in ["ResumeButton", "AssistRow/AssistButton", "AssistRow/AssistHelp", "GentleRow/GentleButton", "GentleRow/GentleHelp", "MusicRow/Slider", "SfxRow/Slider", "QuitButton"]:
		pause_rows.append(pause_list.get_node(path) as Control)
	for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
		root.size = window
		shop.open_pause()
		await _frames(10)
		_check_targets(pause_rows, pause, "pause settings rows at %s" % window)
		shop.close_pause()
	root.size = BASE_WINDOW
	await _frames(5)
	await _close_shop()


## The splash (flow SPLASH, the main scene): the cauldron bubbles the logo up out of
## itself to full size above the pot, then after Splash.SHOW_TIME goes to the
## title by itself. It plays no sound effect of its own; the title track starts with it,
## before any input (on the web, heard at once where the page may play audio).
func _test_splash_auto_advance() -> void:
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
	_check(main_scene == _game.scene_paths[GameState.Flow.SPLASH], "splash: the splash is the main scene", main_scene)
	_game.play_music(&"ending")
	var played := _game.sfx_played
	_game.goto(GameState.Flow.SPLASH)
	await _game.transition_finished
	var splash := current_scene as Splash
	_check(splash != null and _game.state == GameState.Flow.SPLASH, "splash: goto SPLASH shows the splash", str(current_scene))
	if splash != null:
		var logo := splash.get_node("Column/Logo") as TextureRect
		var hero := splash.get_node("Column/Hero") as CauldronHero
		var risen := false
		while not _game.is_transitioning() and splash.elapsed < Splash.SHOW_TIME + 1.0:
			await process_frame
			if not risen and splash.elapsed >= Splash.RISE_DELAY + Splash.RISE_TIME + 0.1:
				risen = true
				_check(logo.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(logo.modulate.a, 1.0) and logo.get_global_rect().end.y < hero.get_global_rect().position.y, "splash: the logo has risen out of the pot to full size above it", "%s scale %s" % [logo.get_global_rect(), logo.scale])
				_check(splash.find_children("*", "Label", true, false).is_empty(), "splash: no text besides the logo art", str(splash.find_children("*", "Label", true, false)))
		_check(risen and splash.finished and absf(splash.elapsed - Splash.SHOW_TIME) <= 3.0 * FRAME and _game.transition_log.back().begins_with("SPLASH -> TITLE"), "splash: goes to the title by itself after %.1f s" % Splash.SHOW_TIME, "%.3f s, %s" % [splash.elapsed, _game.transition_log.back()])
		await _game.transition_finished
		_check(current_scene is Title and _game.state == GameState.Flow.TITLE, "splash: the title follows", str(current_scene))
	_check(_game.sfx_played == played and _game.music_started == &"title" and _game.music_track == &"title", "splash: no sound effect; the title track starts with it, before any input", "%d sounds, started %s, track %s" % [_game.sfx_played - played, _game.music_started, _game.music_track])


## A touch anywhere or any key skips the splash at once.
func _test_splash_skips() -> void:
	for how: String in ["touch", "key"]:
		_game.goto(GameState.Flow.SPLASH)
		await _game.transition_finished
		var splash := current_scene as Splash
		if splash == null:
			_check(false, "splash skip by %s: the splash shows" % how, str(current_scene))
			continue
		await _frames(6)
		if how == "touch":
			await _tap_at(_game.visible_rect().get_center() + Vector2(0, 150))
		else:
			await _key(KEY_SPACE)
		_check(splash.finished and _game.is_transitioning() and _game.transition_log.back().begins_with("SPLASH -> TITLE") and splash.elapsed < Splash.SHOW_TIME / 2.0, "splash: a %s skips to the title at once" % how, "finished %s after %.2f s, %s" % [splash.finished, splash.elapsed, _game.transition_log.back()])
		await _game.transition_finished
		_check(current_scene is Title, "splash skip by %s: the title shows" % how, str(current_scene))


## The title's reading zone: the logo pops in and the big cauldron bubbles and steams in
## the four essence colours, all above the thumb zone and clear of every button, the
## Rush Hour best line and the content-error banner; the buttons keep their sizes,
## thumb zone and focus (the story button first) at 9:16, 9:19.5 and 16:9.
func _test_title_hero_layout() -> void:
	var day := _game.day
	var unlocked := _game.rush_hour_unlocked
	_game.day = 3
	_game.rush_hour_unlocked = true
	for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
		root.size = window
		var title := TITLE_SCENE.instantiate() as Title
		root.add_child(title)
		await _frames(2)
		var label := "title hero at %s" % window
		var logo := title.get_node("Column/Logo") as TextureRect
		_check(logo.scale.x < 1.0, label + ": the logo pops in from small", str(logo.scale))
		title.show_content_error(Title.CONTENT_ERROR_MESSAGE % 3)
		await _frames(ceili(Title.POP_TIME / FRAME) + 2)
		_check(logo.scale.is_equal_approx(Vector2.ONE), label + ": the logo has popped in", str(logo.scale))
		var hero := title.get_node("Column/Hero") as CauldronHero
		var visible := _game.visible_rect()
		var reading_end := visible.position.y + visible.size.y * THUMB_ZONE_TOP
		var column := _game.column_rect()
		var art: Array[Control] = [hero, logo, title.get_node("Column/Tagline") as Control]
		for piece in art:
			var rect := piece.get_global_rect().grow_individual(0, Title.BOB_HEIGHT, 0, Title.BOB_HEIGHT)
			_check(rect.end.y <= reading_end and column.grow(1.0).encloses(rect), "%s: %s in the reading zone, inside the column" % [label, piece.name], "%s, reading zone ends at %.0f" % [rect, reading_end])
		var buttons: Array[Control] = []
		for node: String in ["RushButton", "OpenShopButton", "NewGameButton", "SettingsButton", "CreditsButton"]:
			buttons.append(title.get_node("Column/" + node) as Control)
		_check_targets(buttons, null, label)
		var banner := title.get_node("Column/ContentErrorBanner") as Control
		var others: Array[Control] = buttons + ([title.get_node("Column/RushBest"), banner] as Array[Control])
		var overlaps := PackedStringArray()
		for piece in [hero, logo] as Array[Control]:
			for other in others:
				# The error banner may cover the logo (it is drawn over it); never the cauldron.
				if piece == logo and other == banner:
					continue
				if piece.get_global_rect().intersects(other.get_global_rect()):
					overlaps.append("%s/%s" % [piece.name, other.name])
		_check(overlaps.is_empty() and others.all(func(other: Control) -> bool: return other.visible), label + ": the cauldron clears every button, the best line and the banner; the logo every button and the best line", str(overlaps))
		for i in buttons.size():
			for j in range(i + 1, buttons.size()):
				if buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()):
					overlaps.append("%s/%s" % [buttons[i].name, buttons[j].name])
		_check(overlaps.is_empty(), label + ": no two buttons overlap", str(overlaps))
		_check(buttons.slice(0, 3).all(func(button: Control) -> bool: return button.get_global_rect().size == Vector2(190, 44)) and buttons.slice(3).all(func(button: Control) -> bool: return button.get_global_rect().size == Vector2(112, 44)), label + ": every menu button is 190x44, Settings and Credits 112x44", str(buttons.map(func(button: Control) -> Vector2: return button.get_global_rect().size)))
		var story_rect := (title.get_node("Column/OpenShopButton") as Control).get_global_rect()
		_check(story_rect.end.y <= (title.get_node("Column/RushButton") as Control).get_global_rect().position.y, label + ": the story button sits above Rush Hour", str(story_rect))
		_check(root.gui_get_focus_owner() == title.get_node("Column/OpenShopButton"), label + ": the story button (Continue story) has the focus first", str(root.gui_get_focus_owner()))
		var particles := ["Steam", "Bubbles", "BigBubbles"].all(func(node: String) -> bool: return (hero.get_node(node) as CPUParticles2D).emitting)
		_check(particles and (hero.get_node("Steam") as CPUParticles2D).color.is_equal_approx(hero.tint().lightened(0.6)) and (hero.get_node("Liquid") as TextureRect).modulate.is_equal_approx(hero.tint()), label + ": bubbles and steam rise in the cauldron's tint", str(hero.tint()))
		title.free()
	var cycle := range(Shop.ESSENCE_COLORS.size()).all(func(i: int) -> bool: return CauldronHero.tint_at(i * CauldronHero.TINT_TIME).is_equal_approx(Shop.ESSENCE_COLORS[i]))
	_check(cycle and CauldronHero.tint_at(Shop.ESSENCE_COLORS.size() * CauldronHero.TINT_TIME).is_equal_approx(Shop.ESSENCE_COLORS[0]), "title: the steam cycles through ember, frost, bloom and gloom", str(CauldronHero.tint_at(CauldronHero.TINT_TIME)))
	_game.day = day
	_game.rush_hour_unlocked = unlocked
	root.size = BASE_WINDOW
	await _frames(2)


## The title's Credits: a tap opens the popup over a dim, listing linostar, the fonts
## and their licence and the engine (no text names Claude or AI); Close takes the
## focus, is 32x32+ in the thumb zone and safe area at 9:16, 9:19.5 and 16:9, and a
## tap on it, Enter on it, Escape (ui_cancel) and a tap on the dim each close it with the
## focus back on Credits.
func _test_title_credits() -> void:
	var title: Title = await _goto_scene(GameState.Flow.TITLE)
	var opener := title.get_node("Column/CreditsButton") as Button
	var credits := title.get_node("Credits") as CreditsPanel
	var close := credits.close_button()
	await _tap(opener)
	await _frames(2)
	_check(credits.is_open() and root.gui_get_focus_owner() == close, "credits: a tap on Credits opens the popup with Close focused", str(root.gui_get_focus_owner()))
	var texts := PackedStringArray()
	for label: Node in credits.find_children("*", "Label"):
		texts.append((label as Label).text)
	var all := " ".join(texts)
	var no_ai := RegEx.create_from_string("(?i)\\b(claude|ai)\\b").search(all) == null
	_check("linostar" in all and "Silkscreen" in all and "VT323" in all and "SIL Open Font License" in all and "Godot 4.7" in all and no_ai, "credits: linostar, the fonts and their licence and the engine, nothing names Claude or AI", all)
	for window: Vector2i in [PHONE_9_16, PHONE_9_19_5, DESKTOP_16_9]:
		root.size = window
		await _frames(5)
		_check_targets([close as Control], null, "credits at %s" % window)
		_check(_game.visible_rect().grow(0.5).encloses((credits.get_node("Panel") as Control).get_global_rect()), "credits at %s: the panel fits the screen" % window, str((credits.get_node("Panel") as Control).get_global_rect()))
	root.size = BASE_WINDOW
	await _frames(5)
	await _tap(close)
	await _frames(2)
	_check(not credits.is_open() and root.gui_get_focus_owner() == opener, "credits: a tap on Close closes it, focus back on Credits", str(root.gui_get_focus_owner()))
	for how: String in ["enter", "cancel", "dim"]:
		credits.open(title.get_node("Column") as Control)
		await _frames(2)
		_check(opener.get_focus_mode_with_override() == Control.FOCUS_NONE, "credits (%s): the title's buttons take no focus while open" % how, "")
		match how:
			"enter":
				await _key(KEY_ENTER)
			"cancel":
				await _key(KEY_ESCAPE)
			"dim":
				await _tap_at(_game.visible_rect().position + Vector2(4, 4))
		await _frames(2)
		_check(not credits.is_open() and root.gui_get_focus_owner() == opener, "credits: %s closes it, focus back on Credits" % how, str(root.gui_get_focus_owner()))


## A transition is a potion swirl wipe: it closes in a potion colour (touches under it go
## nowhere), covers the screen, reopens on the new scene while its content slides in,
## all in under 0.5 s; the content is at rest on arrival.
func _test_transition_wipe() -> void:
	_game.goto(GameState.Flow.TITLE)
	await _game.transition_finished
	var old := current_scene as Title
	var open := old.get_node("Column/OpenShopButton") as Button
	var presses: Array[int] = [0]
	open.pressed.connect(func() -> void: presses[0] += 1)
	var start := Engine.get_process_frames()
	_game.goto(GameState.Flow.TITLE)
	await _frames(3)
	var wipe := _game.get_node("Fade/Wipe") as ColorRect
	_check(_game.is_transitioning() and wipe.visible and wipe.mouse_filter == Control.MOUSE_FILTER_STOP and _game.wipe_progress() > 0.0 and _game.wipe_progress() < 1.0, "wipe: the swirl closes over the screen, blocking touches", "progress %.2f" % _game.wipe_progress())
	_check(Content.potions().any(func(potion: PotionType) -> bool: return potion.color.is_equal_approx(_game.wipe_color)), "wipe: in a potion's colour", str(_game.wipe_color))
	await _tap(open)
	_check(presses[0] == 0, "wipe: a touch during the wipe reaches nothing under it", "%d presses" % presses[0])
	var covered := 0.0
	var slid := 0.0
	while _game.is_transitioning():
		covered = maxf(covered, _game.wipe_progress())
		var scene := current_scene as Control
		if scene != null and scene != old and scene.get_node_or_null("Column") != null:
			slid = maxf(slid, (scene.get_node("Column") as Control).position.y - _game.column_rect().position.y)
		await process_frame
	var frames := Engine.get_process_frames() - start
	_check(is_equal_approx(covered, 1.0), "wipe: covers the whole screen at the swap", "max progress %.2f" % covered)
	_check(frames <= ceili(0.5 / FRAME) and frames >= ceili(2.0 * GameState.WIPE_TIME / FRAME), "wipe: the whole transition takes under 0.5 s", "%d frames" % frames)
	var column := (current_scene as Control).get_node("Column") as Control
	_check(slid > 0.0 and column.position.is_equal_approx(_game.column_rect().position) and is_equal_approx(column.modulate.a, 1.0), "wipe: the new screen's content slides in and is at rest on arrival", "slid %.1f, at %s" % [slid, column.position])
	_check(not wipe.visible and wipe.mouse_filter == Control.MOUSE_FILTER_IGNORE and is_zero_approx(_game.wipe_progress()), "wipe: clear and letting touches through after", "progress %.2f" % _game.wipe_progress())


## Juice.hit_stop freezes game time for at most HIT_STOP_MAX, a touch still presses a
## button during it, it ends by itself, and overlapping stops restore the time scale found.
func _test_hit_stop() -> void:
	var button := Button.new()
	button.text = "Hit"
	button.position = Vector2(95, 290)
	button.size = Vector2(80, 40)
	root.add_child(button)
	var presses: Array[int] = [0]
	button.pressed.connect(func() -> void: presses[0] += 1)
	await process_frame
	var stops := Juice.hit_stops
	Juice.hit_stop(self, 1.0)
	_check(Juice.is_hit_stopped() and is_zero_approx(Engine.time_scale) and is_equal_approx(Juice.last_hit_stop, Juice.HIT_STOP_MAX) and Juice.hit_stops == stops + 1 and Juice.HIT_STOP_MAX <= 0.1, "hit-stop: freezes game time, never longer than 100 ms", "scale %.2f, %.2f s" % [Engine.time_scale, Juice.last_hit_stop])
	await _tap(button)
	_check(presses[0] == 1 and Juice.is_hit_stopped(), "hit-stop: a touch during the freeze still presses a button", "%d presses" % presses[0])
	var frames := 2
	while Juice.is_hit_stopped() and frames < 30:
		await process_frame
		frames += 1
	_check(not Juice.is_hit_stopped() and is_equal_approx(Engine.time_scale, 1.0) and frames <= ceili(Juice.HIT_STOP_MAX / FRAME) + 1, "hit-stop: over within 100 ms, time runs again", "%d frames" % frames)
	Engine.time_scale = 2.0
	Juice.hit_stop(self, 0.05)
	Juice.hit_stop(self, 0.08)
	await _frames(ceili(0.08 / FRAME) + 2)
	_check(is_equal_approx(Engine.time_scale, 2.0) and not Juice.is_hit_stopped(), "hit-stop: overlapping stops end together and restore the time scale they found", str(Engine.time_scale))
	Engine.time_scale = 1.0
	button.free()


## Every Button press squashes the button about its centre (one global hook, drawn only:
## the button's own scale and rect never change), by touch and by keyboard, and settles
## back; a button that animates itself is left alone; and keyboard focus moves from a
## squashing button as from a still one (Up from the pause panel's Assist toggle right
## after pressing it reaches Resume, not the "?" beside it).
func _test_button_press_squash() -> void:
	var button := Button.new()
	button.text = "Squash"
	button.position = Vector2(60, 290)
	button.size = Vector2(150, 40)
	root.add_child(button)
	var own := Button.new()
	own.text = "Own"
	own.add_to_group(GameState.OWN_SQUASH_GROUP)
	own.position = Vector2(60, 360)
	own.size = Vector2(150, 40)
	root.add_child(own)
	await process_frame
	var rect := button.get_global_rect()
	# The press lands as the frame starts; its squash has moved by the next one.
	await _tap(button)
	await process_frame
	var drawn: Vector2 = button.get_meta(&"juice_press_scale", Vector2.ONE)
	_check(drawn.x > 1.0 and drawn.y < 1.0 and button.scale.is_equal_approx(Vector2.ONE) and button.get_global_rect().is_equal_approx(rect), "press squash: a tapped Button is drawn squashed, its rect untouched", "drawn %s, scale %s" % [drawn, button.scale])
	await _frames(20)
	_check((button.get_meta(&"juice_press_scale", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.ONE), "press squash: and settles back", str(button.get_meta(&"juice_press_scale", Vector2.ZERO)))
	button.grab_focus()
	await _action(&"ui_accept")
	await process_frame
	_check(not (button.get_meta(&"juice_press_scale", Vector2.ONE) as Vector2).is_equal_approx(Vector2.ONE), "press squash: Enter on a focused Button squashes it too", str(button.get_meta(&"juice_press_scale", Vector2.ONE)))
	await _tap(own)
	await process_frame
	_check(not own.has_meta(&"juice_press_scale"), "press squash: a button in OWN_SQUASH_GROUP (it animates itself) is left alone", "")
	button.free()
	own.free()
	var shop := await _open_shop()
	if await _wait_for_order(shop, "press squash focus"):
		shop.open_pause()
		await process_frame
		(shop.get_node("Modal/Panel/List/ResumeButton") as Button).grab_focus()
		await _action(&"ui_down")
		await _action(&"ui_accept")
		await _action(&"ui_up")
		_check(root.gui_get_focus_owner() == shop.get_node("Modal/Panel/List/ResumeButton"), "press squash: Up right after toggling Assist goes to Resume, not the \"?\"", str(root.gui_get_focus_owner()))
		shop.close_pause()
	await _close_shop()


## Pausing mid-pour (the pause panel or the Codex) holds the pour's fill sound and
## resuming continues it; quitting a paused pour stops it.
func _test_pour_sound_pause() -> void:
	var shop := await _open_shop()
	if not await _wait_for_order(shop, "pour sound"):
		await _close_shop()
		return
	shop.customer.patience_left = 999.0
	var wants := shop.customer.potion
	for id in _exact_recipe(wants, shop.stock):
		await _tap_item(shop, id)
	await _tap(shop.brew_button())
	var order: Array[String] = []
	var pour: Pour = null
	for step in wants.steps:
		if not await _until(func() -> bool: return shop.station != null and shop.station.is_running() and not (str(shop.station.name) in order), FLOW_FRAMES):
			break
		order.append(str(shop.station.name))
		if shop.station is Pour:
			pour = shop.station as Pour
			break
		await _drive_circles(shop.station, Stir.CENTRE, Stir.RING_RADIUS, Stir.DEFAULT_TEMPO)
	_check(pour != null, "pour sound: the pour station runs", str(order))
	if pour == null:
		await _close_shop()
		return
	pour.feed(_touch(POUR_HOLD_POINT, true))
	await _frames(10)
	_check(_heard(&"pour_fill") and _game.sfx_paused.is_empty(), "pour sound: holding the pour plays its fill", str(_game.sfx_log.slice(-4)))
	shop.open_pause()
	var fill := pour.fill
	await _frames(10)
	_check(&"pour_fill" in _game.sfx_paused and is_equal_approx(pour.fill, fill), "pour sound: the pause panel holds the fill sound (and the pour)", "%s, fill %.3f -> %.3f" % [_game.sfx_paused, fill, pour.fill])
	shop.close_pause()
	await _frames(5)
	_check(_game.sfx_paused.is_empty() and pour.fill > fill, "pour sound: resuming continues it", "%s, fill %.3f" % [_game.sfx_paused, pour.fill])
	shop.open_codex()
	await process_frame
	_check(&"pour_fill" in _game.sfx_paused, "pour sound: the Codex holds it too", str(_game.sfx_paused))
	shop.codex.close()
	await process_frame
	_check(_game.sfx_paused.is_empty(), "pour sound: closing the Codex continues it", str(_game.sfx_paused))
	shop.open_pause()
	await process_frame
	await _tap(shop.get_node("Modal/Panel/List/QuitButton") as Button)
	_check(_game.sfx_paused.is_empty(), "pour sound: quitting a paused pour stops its sound", str(_game.sfx_paused))
	await _game.transition_finished
	paused = false
