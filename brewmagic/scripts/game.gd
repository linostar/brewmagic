class_name GameState
extends Node
## Autoload "Game" (scenes/game.tscn): the app flow state machine and its
## scene transitions, plus ScreenFit (the visible and safe-area rects in base
## units and the centred 270-wide gameplay column).
## Every flow change goes through goto(), which fades out, swaps the scene,
## fades in and logs the transition. A flow state whose scene is missing is
## reported with push_error and a visible error label instead of crashing; a
## scene that cannot start redirects with abort_to().

signal transition_finished(state: Flow)
## Emitted when the visible rect or the safe area changes (resize, rotation).
signal screen_fit_changed

enum Flow { TITLE, SHOP }

## Where the autoload lives. Scripts fetch it through this path instead of the
## global "Game" name, which does not exist yet when test scripts compile.
const AUTOLOAD_PATH := ^"/root/Game"
const SCENE_PATHS: Dictionary[Flow, String] = {
	Flow.TITLE: "res://scenes/title.tscn",
	Flow.SHOP: "res://scenes/shop.tscn",
}
## Seconds for each half of a transition (fade out, then fade in).
const FADE_TIME := 0.18
## Width of the gameplay column in base units (the base viewport width).
const COLUMN_WIDTH := 270.0
## Station tolerance multiplier while Gentle mode is on.
const GENTLE_TOLERANCE_SCALE := 1.5

## Settings for this session (persisted with the save in plan step 6). Stations
## read them through the shop when they begin.
var assist_mode := false
var gentle_mode := false

## Tests replace entries to point a state at their own (or a missing) scene.
var scene_paths: Dictionary[Flow, String] = SCENE_PATHS.duplicate()
## Tests set quiet_errors to assert on expected errors without failing the log check.
var quiet_errors := false
var reported_errors: Array[String] = []
## Every transition, as logged, oldest first.
var transition_log: Array[String] = []

var state := Flow.TITLE
## The args of the latest goto(); the new scene reads them in its _ready().
var flow_args: Dictionary = {}

var _transitioning := false
var _visible_rect := Rect2()
var _safe_rect := Rect2()

@onready var _curtain: ColorRect = $Fade/Curtain
@onready var _error_label: Label = $Fade/ErrorLabel


func _ready() -> void:
	get_viewport().size_changed.connect(_update_screen_fit)
	_update_screen_fit()


## Fades to the scene of `new_state`, passing `args` through flow_args.
## Ignored (with a log line) while a transition is running.
func goto(new_state: Flow, args: Dictionary = {}) -> void:
	var path: String = scene_paths[new_state]
	var from_name: String = Flow.keys()[state]
	var to_name: String = Flow.keys()[new_state]
	if _transitioning:
		print("[Game] Ignored goto %s while a transition is running" % to_name)
		return
	if not ResourceLoader.exists(path):
		_report_error("Cannot go to %s: scene '%s' does not exist" % [to_name, path])
		return
	_transitioning = true
	_log_transition("%s -> %s (%s) args=%s" % [from_name, to_name, path, args])
	_error_label.hide()
	await _fade(1.0)
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_report_error("Failed to load scene '%s' for %s: %s" % [path, to_name, error_string(error)])
		await _fade(0.0)
		_transitioning = false
		return
	state = new_state
	flow_args = args
	await _fade(0.0)
	_transitioning = false
	transition_finished.emit(new_state)


## For a scene that cannot start (it calls this from its _ready, during the
## transition into it): goes to `fallback` once that transition has finished,
## then reports `message` (log and the visible error label) on the fallback screen.
func abort_to(fallback: Flow, message: String) -> void:
	if _transitioning:
		await transition_finished
	await goto(fallback)
	_report_error(message)


func is_transitioning() -> bool:
	return _transitioning


## The Station tolerance_scale the settings ask for (upgrades multiply in later).
func tolerance_scale() -> float:
	return GENTLE_TOLERANCE_SCALE if gentle_mode else 1.0


## The visible area in base units: 270x480 or larger on one axis (aspect expand).
func visible_rect() -> Rect2:
	return _visible_rect


## The part of the visible area clear of notches and rounded corners, in base units.
func safe_rect() -> Rect2:
	return _safe_rect


## The 270-wide gameplay column, centred in the safe area and as tall as it.
func column_rect() -> Rect2:
	return column_in(_safe_rect)


## The column for a given safe rect: COLUMN_WIDTH wide (narrower only if the
## safe rect is), horizontally centred in it, spanning its full height.
static func column_in(safe: Rect2) -> Rect2:
	var width := minf(COLUMN_WIDTH, safe.size.x)
	return Rect2(safe.get_center().x - width / 2.0, safe.position.y, width, safe.size.y)


## Converts the screen-pixel safe area to base units and clips it to `visible`.
## An empty safe area (headless, some web browsers) means the whole visible rect.
static func safe_rect_in(visible: Rect2, safe_pixels: Rect2i, window_position: Vector2i, stretch: Transform2D) -> Rect2:
	if safe_pixels.size.x <= 0 or safe_pixels.size.y <= 0:
		return visible
	var local := Rect2(Vector2(safe_pixels.position - window_position), Vector2(safe_pixels.size))
	var base := stretch.affine_inverse() * local
	var clipped := base.intersection(visible)
	return clipped if clipped.has_area() else visible


func _update_screen_fit() -> void:
	var window := get_window()
	var visible := get_viewport().get_visible_rect()
	var safe := safe_rect_in(visible, DisplayServer.get_display_safe_area(), window.position, window.get_final_transform())
	if visible == _visible_rect and safe == _safe_rect:
		return
	_visible_rect = visible
	_safe_rect = safe
	print("[Game] ScreenFit: visible %s, safe %s, column %s" % [visible, safe, column_rect()])
	screen_fit_changed.emit()


func _fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_curtain, "color:a", alpha, FADE_TIME)
	await tween.finished


func _log_transition(entry: String) -> void:
	transition_log.append(entry)
	print("[Game] goto " + entry)


func _report_error(message: String) -> void:
	reported_errors.append(message)
	_error_label.text = message
	_error_label.show()
	if not quiet_errors:
		push_error("[Game] " + message)
