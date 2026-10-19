class_name Station
extends Control
## Base of every gesture station (CLAUDE.md "Gesture stations").
## A Control, not a Node2D: the GUI routes a touch and its drags to the Control it
## started on (in local coordinates, even when the finger leaves it), mouse_filter
## keeps them from the shelf behind, anchors place the station in the thumb zone,
## and the Assist prompt is a child Button that gets focus and ui_accept for free.
##
## Flow: the caller sets `assist` and `tolerance_scale`, calls begin(params), and
## waits for `finished(quality)` (0..1, emitted once per begin()). Touches reach the
## station through _gui_input -> feed(); tests call feed() with synthetic
## InputEventScreenTouch/Drag in station-local coordinates and advance(delta) to
## move time deterministically. Only touch index 0 is used (one thumb).
##
## Subclasses override _station_begin, _station_input, _station_advance and
## _station_finished, call _finish(quality) once, and contain no Assist code:
## with `assist` on, begin() lays out the station's visuals and shows one big
## Button captioned by _assist_caption() ("Auto Stir", "Auto Pour"); a tap, click
## or ui_accept on it finishes with ASSIST_QUALITY.

## Emitted once per begin() with the gesture quality, 0..1.
signal finished(quality: float)
## An immediate feedback cue (a rotation done, pouring started, a spill...). The
## shop routes these to sound effects; the station already shows the visual part.
## The base emits "station_success" (quality >= ASSIST_QUALITY) or "station_sloppy"
## right before `finished`, including for the Assist press.
signal feedback(kind: StringName)

const PERFECT_QUALITY := Brew.PERFECT_QUALITY
## The Good threshold: Assist mode gives exactly this, never Perfect.
const ASSIST_QUALITY := Brew.GOOD_QUALITY
## A score falls from 1 at the edge of its window to 0 at FALLOFF windows beyond it.
const FALLOFF := 2.0
## Assist button rect, anchored to the bottom centre of the station.
const ASSIST_BUTTON_SIZE := Vector2(160, 56)
const ASSIST_BUTTON_BOTTOM_MARGIN := 48.0
## Result pips (one per stir rotation or grind turn). The shape carries the result
## too (never colour alone): a four-point star for perfect, a round dot for good,
## a cross for sloppy, an empty ring while pending.
const PIP_RADIUS := 5.0
const PIP_STAR_INNER := 1.5
const PIP_CROSS_WIDTH := 2.0
const PIP_PERFECT := Color("#ffc95c")
const PIP_GOOD := Color("#fbedcd")
const PIP_SLOPPY := Color("#c43c2c")
const PIP_EMPTY := Color("#5c5668")

## Assist mode (setting): set by the caller before begin().
var assist := false
## Multiplies every tolerance window: upgrades times Gentle mode (> 1 is easier).
## Set by the caller before begin().
var tolerance_scale := 1.0

var _running := false
var _assist_button: Button


## Starts the station with the brew's `params` (documented per station).
## A running station restarts.
func begin(params: Dictionary) -> void:
	_running = true
	print("[Station] %s begin %s (assist %s, tolerance x%.2f)" % [name, params, assist, tolerance_scale])
	_station_begin(params)
	# The gesture's instruction ("Follow the ghost ladle...") does not apply to the Assist button.
	var prompt := get_node_or_null("Prompt") as CanvasItem
	if prompt != null:
		prompt.visible = not assist
	if assist:
		_show_assist_prompt()
	elif _assist_button != null:
		# Assist was switched off since the last begin(): back to the gesture.
		_assist_button.queue_free()
		_assist_button = null


## Hands one input event to the station. Ignored unless it is a touch or drag
## of index 0 while the gesture runs (Assist mode has no gesture).
func feed(event: InputEvent) -> void:
	if not _running or assist:
		return
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	if (touch != null and touch.index == 0) or (drag != null and drag.index == 0):
		_station_input(event)


## Moves the station's clock by `delta` seconds (called every frame).
func advance(delta: float) -> void:
	if _running and not assist:
		_station_advance(delta)


func is_running() -> bool:
	return _running


## The Assist button while the Assist prompt shows, else null.
func assist_button() -> Button:
	return _assist_button


## 1.0 while `error` is within `window` (times tolerance_scale), falling linearly
## to 0.0 at FALLOFF scaled windows beyond it.
func window_score(error: float, window: float) -> float:
	var scaled := window * tolerance_scale
	if error <= scaled:
		return 1.0
	return clampf(1.0 - (error - scaled) / (scaled * FALLOFF), 0.0, 1.0)


## The colour of a result pip for `score`.
static func pip_color(score: float) -> Color:
	if score >= PERFECT_QUALITY:
		return PIP_PERFECT
	if score >= ASSIST_QUALITY:
		return PIP_GOOD
	return PIP_SLOPPY


## Draws a row of `count` result pips centred on `centre` into `canvas` (during its
## draw signal): one per entry of `scores`, then empty rings.
static func draw_pips(canvas: CanvasItem, centre: Vector2, spacing: float, count: int, scores: Array[float]) -> void:
	var first_x := centre.x - spacing * (count - 1) / 2.0
	for i in count:
		var at := Vector2(first_x + spacing * i, centre.y)
		if i >= scores.size():
			canvas.draw_circle(at, PIP_RADIUS, PIP_EMPTY, false, 1.0)
			continue
		var score := scores[i]
		var color := pip_color(score)
		if score >= PERFECT_QUALITY:
			var star := PackedVector2Array()
			for corner: int in 8:
				var radius := PIP_RADIUS + 1.0 if corner % 2 == 0 else PIP_STAR_INNER
				star.append(at + Vector2.from_angle(-PI / 2.0 + corner * PI / 4.0) * radius)
			canvas.draw_colored_polygon(star, color)
		elif score >= ASSIST_QUALITY:
			canvas.draw_circle(at, PIP_RADIUS, color)
		else:
			var arm := PIP_RADIUS * 0.8
			canvas.draw_line(at + Vector2(-arm, -arm), at + Vector2(arm, arm), color, PIP_CROSS_WIDTH)
			canvas.draw_line(at + Vector2(-arm, arm), at + Vector2(arm, -arm), color, PIP_CROSS_WIDTH)


## params["color"], the potion's liquid colour. Reports an error and shows white
## when it is missing or not a Color.
func _color_param(params: Dictionary) -> Color:
	var color: Variant = params.get("color")
	if color is Color:
		return color
	push_error("[Station] %s params need a Color 'color', got %s" % [name, params])
	return Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		feed(event)
		accept_event()


func _process(delta: float) -> void:
	advance(delta)


## Ends the gesture with `quality` (clamped to 0..1). Only the first call per begin() counts.
func _finish(quality: float) -> void:
	if not _running:
		return
	_running = false
	var result := clampf(quality, 0.0, 1.0)
	print("[Station] %s finished, quality %.3f" % [name, result])
	if _assist_button != null:
		_assist_button.queue_free()
		_assist_button = null
	_station_finished(result)
	feedback.emit(&"station_success" if result >= ASSIST_QUALITY else &"station_sloppy")
	finished.emit(result)


func _show_assist_prompt() -> void:
	if _assist_button != null:
		_assist_button.queue_free()
	_assist_button = Button.new()
	_assist_button.name = "AssistButton"
	_assist_button.text = _assist_caption()
	_assist_button.accessibility_name = _assist_button.text
	_assist_button.focus_mode = Control.FOCUS_ALL
	# Its press finishes the station, whose success cue plays the sound (no generic tap).
	_assist_button.add_to_group(GameState.OWN_SOUND_GROUP)
	_assist_button.anchor_left = 0.5
	_assist_button.anchor_right = 0.5
	_assist_button.anchor_top = 1.0
	_assist_button.anchor_bottom = 1.0
	_assist_button.offset_left = -ASSIST_BUTTON_SIZE.x / 2.0
	_assist_button.offset_right = ASSIST_BUTTON_SIZE.x / 2.0
	_assist_button.offset_top = -ASSIST_BUTTON_BOTTOM_MARGIN - ASSIST_BUTTON_SIZE.y
	_assist_button.offset_bottom = -ASSIST_BUTTON_BOTTOM_MARGIN
	_assist_button.pressed.connect(_finish.bind(ASSIST_QUALITY))
	add_child(_assist_button)
	# Keyboard users can press Enter straight away; the focus ring shows once they navigate.
	# A paused station (restarted from the pause panel) leaves focus in the panel;
	# whoever unpauses hands focus to assist_button().
	if can_process():
		_assist_button.grab_focus(true)


## The Assist button's caption and accessibility name, naming what it does for the player.
func _assist_caption() -> String:
	return "Auto Brew"


## Lays out the visuals and resets the gesture for `params`.
func _station_begin(_params: Dictionary) -> void:
	pass


## A touch or drag of index 0, in station-local coordinates.
func _station_input(_event: InputEvent) -> void:
	pass


## Time passes while the gesture runs.
func _station_advance(_delta: float) -> void:
	pass


## The gesture ended with `quality`: show the result.
func _station_finished(_quality: float) -> void:
	pass
