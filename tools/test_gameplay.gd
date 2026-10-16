extends SceneTree
## Headless gameplay tests. Run with --fixed-fps 60 so one frame = one physics tick:
##   "$GODOT" --headless --path brewmagic --fixed-fps 60 --script "$PWD/tools/test_gameplay.gd"
## Prints "test_gameplay: OK" when every test passes; exits 1 otherwise.
## To add a test: write a `_test_*` func (it may await) that reports through _check(),
## and append it to the list in _tests(). Tests run in that order on one SceneTree, so
## each one restores whatever it changes (window size, Game.scene_paths, quiet_errors).

const TITLE_SCENE := preload("res://scenes/title.tscn")
const TITLE_PATH := "res://scenes/title.tscn"
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
