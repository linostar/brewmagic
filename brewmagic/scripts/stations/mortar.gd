class_name Mortar
extends Station
## Mortar station: drag circles around the mortar to grind the brew's hard
## ingredients (those flagged `grind`) to powder, at a steady speed.
## A ghost pestle (washed pale blue by its material in mortar.tscn) demonstrates the
## motion: it circles the bowl at the target speed, with the finger's circle
## (RING_RADIUS) and an arrowhead chasing it. It plays one full turn at GHOST_ALPHA,
## keeps turning at GHOST_FAINT_ALPHA, and fades out on the first touch. A speed
## meter under the bowl shows the current grinding speed against the steady band.
## Either direction counts; wiggling does not.
##
## params: "color" (Color, the powder's colour: the mix), "ingredients" (optional
## Array of ingredient ids drawn in the bowl, shrinking as they are ground),
## "speed" (optional float, turns per second, default DEFAULT_SPEED).
##
## The fineness grows with the angle ground, reaching 1 after TURNS full turns.
## Every quarter turn scores its speed: window_score(|speed - target| / target,
## SPEED_WINDOW), so the band is target x (1 +- SPEED_WINDOW x tolerance_scale)
## and the meter draws exactly that band. Quality = mean of all quarter-turn scores.
## A quarter's time runs from the end of the previous one (the first from the first
## touch), so pauses with the finger lifted count as slow grinding.
## Idle: without touches the station never finishes (the customer's patience is the
## only clock). Feedback: "mortar_turn" on every completed full turn.

const DEFAULT_SPEED := 1.0
const TURNS := 4
const SEGMENTS_PER_TURN := 4
## Relative speed error |tps - speed| / speed that still scores 1.
const SPEED_WINDOW := 0.25
## Touches closer than this to the centre give no direction and are skipped.
const MIN_RADIUS := 12.0
## The grinding centre (the bowl's opening, mortar canvas (24, 5) at 3x) and the
## radius of the finger's circle the ghost's guide traces, in station coordinates.
const CENTRE := Vector2(135, 118)
const RING_RADIUS := 52.0
## The pestle's head stays on this ellipse in the opening.
const SURFACE_RADII := Vector2(36, 6)
const PESTLE_LEAN := 0.35
const PESTLE_FOLLOW_RATE := 20.0
## The meter's needle follows the measured speed at this rate (per second).
const METER_SMOOTHING := 8.0
## Speed meter: a bar from 0 to METER_MAX x the target speed.
const METER_RECT := Rect2(55, 214, 160, 8)
const METER_MAX := 2.0
const BAND_TICK := 6.0
const NEEDLE_SIZE := 5.0
const PIP_Y := 250.0
const PIP_SPACING := 20.0
## Ingredient pieces sit on the powder, shrink to PIECE_MIN_SCALE as they are ground.
const PIECE_SPACING := 22.0
const PIECE_Y := -10.0
const PIECE_MIN_SCALE := 0.2
const POWDER_MIN_ALPHA := 0.25
const GHOST_START_ANGLE := PI / 2.0
const GHOST_ALPHA := 0.7
const GHOST_FAINT_ALPHA := 0.35
const GHOST_FADE_TIME := 0.3
const GUIDE_WIDTH := 2.0
const ARROW_HEAD := 5.0
const GUIDE_COLOR := Color("#ffc95c")
const METER_BACK := Color("#3a2830")
const METER_BAND := Color("#7cc44c")
const NEEDLE_COLOR := Color("#fbedcd")

## How finely the brew is ground so far, 0..1.
var fineness := 0.0
var _speed := DEFAULT_SPEED
var _clock := 0.0
var _has_angle := false
var _last_angle := 0.0
var _swept := 0.0
var _swept_shown := 0.0
var _meter_speed := 0.0
var _segment_start := -1.0
var _segments: Array[float] = []
var _turn_scores: Array[float] = []
var _pestle_target := CENTRE
var _touched := false

@onready var _bowl: Node2D = $Bowl
@onready var _powder: Sprite2D = $Bowl/Powder
@onready var _pieces: Node2D = $Bowl/Pieces
@onready var _pestle: Sprite2D = $Pestle
@onready var _ghost: Sprite2D = $Ghost
@onready var _guide: Node2D = $Guide


func _ready() -> void:
	($Bowl/Mortar as Sprite2D).texture = Art.texture("brewing", "mortar")
	_powder.texture = Art.texture("brewing", "mortar_powder")
	_pestle.texture = Art.texture("brewing", "pestle")
	_ghost.texture = _pestle.texture
	_guide.draw.connect(_draw_guide)


## The scores of the full turns completed so far, oldest first.
func turn_scores() -> Array[float]:
	return _turn_scores.duplicate()


## The ghost pestle (tests check its demonstration).
func ghost() -> Sprite2D:
	return _ghost


func _station_begin(params: Dictionary) -> void:
	_powder.modulate = _color_param(params)
	_speed = float(params.get("speed", DEFAULT_SPEED))
	if _speed <= 0.0:
		push_error("[Mortar] speed must be > 0, got %s; using %s" % [_speed, DEFAULT_SPEED])
		_speed = DEFAULT_SPEED
	var ingredients: Variant = params.get("ingredients", [])
	if not ingredients is Array:
		push_error("[Mortar] 'ingredients' must be an Array of ingredient ids, got %s" % [ingredients])
		ingredients = []
	for piece in _pieces.get_children():
		_pieces.remove_child(piece)
		piece.queue_free()
	var ids: Array = ingredients
	for i in ids.size():
		var piece := Sprite2D.new()
		piece.texture = Art.texture("ingredients", str(ids[i]))
		piece.position = Vector2((i - (ids.size() - 1) / 2.0) * PIECE_SPACING, PIECE_Y)
		_pieces.add_child(piece)
	fineness = 0.0
	_clock = 0.0
	_has_angle = false
	_swept = 0.0
	_swept_shown = 0.0
	_meter_speed = 0.0
	_segment_start = -1.0
	_segments.clear()
	_turn_scores.clear()
	_pestle_target = CENTRE + Vector2(SURFACE_RADII.x, 0)
	_place_pestle(_pestle, _pestle_target)
	_touched = false
	_ghost.visible = not assist
	_ghost.modulate.a = GHOST_ALPHA
	_place_pestle(_ghost, _surface_point(GHOST_START_ANGLE))
	_show_fineness()
	_guide.queue_redraw()


func _assist_caption() -> String:
	return "Auto Grind"


func _station_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_touched = true
			_sample(touch.position)
		else:
			_has_angle = false
		return
	_sample((event as InputEventScreenDrag).position)


func _station_advance(delta: float) -> void:
	_clock += delta
	if delta > 0.0:
		var measured := absf(_swept - _swept_shown) / TAU / delta
		_meter_speed = lerpf(_meter_speed, measured, minf(1.0, METER_SMOOTHING * delta))
	_swept_shown = _swept
	_place_pestle(_pestle, _pestle.position.lerp(_pestle_target, minf(1.0, PESTLE_FOLLOW_RATE * delta)))
	_place_pestle(_ghost, _surface_point(_ghost_angle()))
	if _touched:
		_ghost.modulate.a = move_toward(_ghost.modulate.a, 0.0, delta * GHOST_ALPHA / GHOST_FADE_TIME)
	else:
		_ghost.modulate.a = GHOST_ALPHA if _clock * _speed < 1.0 else GHOST_FAINT_ALPHA
	_guide.queue_redraw()


func _station_finished(quality: float) -> void:
	_guide.queue_redraw()
	if quality >= ASSIST_QUALITY:
		fineness = 1.0
		_show_fineness()
		Juice.squash(_bowl, 0.2)
		Juice.burst(self, CENTRE, _powder.modulate.lightened(0.3), 20)


## The ghost's angle in the opening: one turn per 1 / speed seconds, clockwise on screen.
func _ghost_angle() -> float:
	return GHOST_START_ANGLE + _clock * _speed * TAU


func _surface_point(angle: float) -> Vector2:
	return CENTRE + Vector2.from_angle(angle) * SURFACE_RADII


## Puts a pestle's head at `at` and leans it with the head's side of the bowl.
func _place_pestle(pestle: Sprite2D, at: Vector2) -> void:
	pestle.position = at
	pestle.rotation = (at.x - CENTRE.x) / SURFACE_RADII.x * PESTLE_LEAN


func _sample(at: Vector2) -> void:
	var offset := at - CENTRE
	var radius := offset.length()
	if radius < MIN_RADIUS:
		_has_angle = false
		return
	var angle := offset.angle()
	_pestle_target = CENTRE + offset / radius * SURFACE_RADII
	if _segment_start < 0.0:
		_segment_start = _clock
	if _has_angle:
		_swept += wrapf(angle - _last_angle, -PI, PI)
		fineness = clampf(absf(_swept) / (TAU * TURNS), 0.0, 1.0)
		_show_fineness()
	_last_angle = angle
	_has_angle = true
	while _running and absf(_swept) >= TAU / SEGMENTS_PER_TURN * (_segments.size() + 1):
		_complete_segment()


func _complete_segment() -> void:
	var duration := maxf(_clock - _segment_start, 0.001)
	var turns_per_second := 1.0 / (SEGMENTS_PER_TURN * duration)
	_segments.append(window_score(absf(turns_per_second - _speed) / _speed, SPEED_WINDOW))
	_segment_start = _clock
	if _segments.size() % SEGMENTS_PER_TURN != 0:
		return
	var score := _mean(_segments.slice(-SEGMENTS_PER_TURN))
	_turn_scores.append(score)
	print("[Mortar] turn %d: score %.2f, fineness %.2f" % [_turn_scores.size(), score, fineness])
	feedback.emit(&"mortar_turn")
	Juice.squash(_bowl, 0.06, 0.18)
	Juice.burst(self, _pestle_target, pip_color(score), 6)
	_guide.queue_redraw()
	if _turn_scores.size() >= TURNS:
		_finish(_mean(_segments))


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxi(values.size(), 1)


## The pieces shrink and the powder thickens as the fineness grows.
func _show_fineness() -> void:
	var piece_scale := lerpf(1.0, PIECE_MIN_SCALE, fineness)
	for piece: Sprite2D in _pieces.get_children():
		piece.scale = Vector2(piece_scale, piece_scale)
	_powder.modulate.a = lerpf(POWDER_MIN_ALPHA, 1.0, fineness)


func _draw_guide() -> void:
	if _running and _ghost.visible and _ghost.modulate.a > 0.0:
		var color := Color(GUIDE_COLOR, _ghost.modulate.a / GHOST_ALPHA)
		_guide.draw_arc(CENTRE, RING_RADIUS, 0.0, TAU, 48, Color(color, color.a * 0.5), GUIDE_WIDTH)
		var head := _ghost_angle()
		var tip := CENTRE + Vector2.from_angle(head) * RING_RADIUS
		var along := Vector2.from_angle(head + PI / 2.0)
		var out := Vector2.from_angle(head)
		_guide.draw_colored_polygon(PackedVector2Array([tip + along * ARROW_HEAD * 1.5, tip - along + out * ARROW_HEAD, tip - along - out * ARROW_HEAD]), color)
	_draw_meter()
	draw_pips(_guide, Vector2(CENTRE.x, PIP_Y), PIP_SPACING, TURNS, _turn_scores)


## The speed bar: the steady band (bracketed by ticks, so its edges are not colour
## alone) and a needle at the current speed.
func _draw_meter() -> void:
	_guide.draw_rect(METER_RECT, METER_BACK)
	var band := SPEED_WINDOW * tolerance_scale
	var low := _meter_x(1.0 - band)
	var high := _meter_x(1.0 + band)
	_guide.draw_rect(Rect2(low, METER_RECT.position.y, high - low, METER_RECT.size.y), METER_BAND)
	for x: float in [low, high]:
		_guide.draw_line(Vector2(x, METER_RECT.position.y - BAND_TICK), Vector2(x, METER_RECT.end.y + BAND_TICK), NEEDLE_COLOR, 1.0)
	var needle := _meter_x(_meter_speed / _speed)
	var top := METER_RECT.position.y - 1.0
	_guide.draw_colored_polygon(PackedVector2Array([Vector2(needle, top), Vector2(needle - NEEDLE_SIZE, top - NEEDLE_SIZE), Vector2(needle + NEEDLE_SIZE, top - NEEDLE_SIZE)]), NEEDLE_COLOR)
	_guide.draw_line(Vector2(needle, top), Vector2(needle, METER_RECT.end.y), NEEDLE_COLOR, 1.0)


## The meter's x for a speed of `ratio` x the target, clamped to the bar.
func _meter_x(ratio: float) -> float:
	return METER_RECT.position.x + clampf(ratio / METER_MAX, 0.0, 1.0) * METER_RECT.size.x
