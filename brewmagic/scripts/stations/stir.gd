class_name Stir
extends Station
## Stir station: drag circles around the cauldron at the tempo the brew asks for.
## A translucent ghost ladle (washed pale blue by its material in stir.tscn)
## demonstrates the motion: it circles the pot surface at the target tempo, with
## arrows on the finger's circle (RING_RADIUS) chasing it.
## It plays one full loop at GHOST_ALPHA, keeps looping at GHOST_FAINT_ALPHA, and
## fades out on the first touch. Either direction counts; wiggling does not.
##
## params: "color" (Color, the potion's liquid colour), "tempo" (optional float,
## rotations per second, default DEFAULT_TEMPO).
##
## Each full rotation scores TEMPO_WEIGHT * tempo accuracy + the rest * roundness
## (how constant the finger's distance to the centre stays), both through
## window_score(); the station finishes after ROTATIONS rotations with their mean.
## A rotation's time runs from the end of the previous one (the first from the
## first touch), so pauses with the finger lifted count as slow stirring.
## Idle: without touches the station never finishes (the customer's patience is
## the only clock). Feedback: "stir_rotation" on every completed rotation.

const DEFAULT_TEMPO := 0.8
const ROTATIONS := 3
## Relative tempo error |rps - tempo| / tempo that still scores 1.
const TEMPO_WINDOW := 0.12
## Coefficient of variation of the finger's radius within a rotation that still scores 1.
const ROUND_WINDOW := 0.12
const TEMPO_WEIGHT := 0.7
## Touches closer than this to the centre give no direction and are skipped.
const MIN_RADIUS := 12.0
## The stirring centre (the liquid surface) and the radius of the finger's circle
## that the ghost's arrows trace, in station coordinates.
const CENTRE := Vector2(135, 121)
const RING_RADIUS := 52.0
## The ladle bowl stays on this ellipse over the liquid surface.
const SURFACE_RADII := Vector2(40, 7)
const LADLE_LEAN := 0.4
const LADLE_FOLLOW_RATE := 20.0
const SWIRL_STEP := PI / 3.0
const FIRE_FRAME_TIME := 0.12
const PIP_Y := 236.0
const PIP_SPACING := 20.0
## The ghost ladle starts at the front of the surface (the real ladle rests on the right).
const GHOST_START_ANGLE := PI / 2.0
const GHOST_ALPHA := 0.7
const GHOST_FAINT_ALPHA := 0.35
const GHOST_FADE_TIME := 0.3
## Arrows on the finger's circle: how many, each one's arc length and arrowhead size.
const ARROWS := 3
const ARROW_ARC := PI / 4.0
const ARROW_HEAD := 5.0
const ARROW_WIDTH := 2.0
const ARROW_COLOR := Color("#ffc95c")

var _tempo := DEFAULT_TEMPO
var _clock := 0.0
var _has_angle := false
var _last_angle := 0.0
var _swept := 0.0
var _swirl := 0.0
var _rotation_start := -1.0
var _radii: Array[float] = []
var _scores: Array[float] = []
var _ladle_target := CENTRE
var _touched := false

@onready var _rig: Node2D = $Rig
@onready var _liquid: Sprite2D = $Rig/Liquid
@onready var _fire: Sprite2D = $Rig/Fire
@onready var _ladle: Sprite2D = $Ladle
@onready var _ghost: Sprite2D = $Ghost
@onready var _guide: Node2D = $Guide


func _ready() -> void:
	($Rig/Pot as Sprite2D).texture =Art.texture("brewing", "cauldron")
	_liquid.texture = Art.texture("brewing", "cauldron_liquid_0")
	_fire.texture = Art.texture("brewing", "fire_0")
	_ladle.texture = Art.texture("brewing", "ladle")
	_ghost.texture = _ladle.texture
	_guide.draw.connect(_draw_guide)


## The scores of the rotations completed so far, oldest first.
func rotation_scores() -> Array[float]:
	return _scores.duplicate()


func _station_begin(params: Dictionary) -> void:
	_liquid.modulate = _color_param(params)
	_tempo = float(params.get("tempo", DEFAULT_TEMPO))
	if _tempo <= 0.0:
		push_error("[Stir] tempo must be > 0, got %s; using %s" % [_tempo, DEFAULT_TEMPO])
		_tempo = DEFAULT_TEMPO
	_clock = 0.0
	_has_angle = false
	_swept = 0.0
	_swirl = 0.0
	_rotation_start = -1.0
	_radii.clear()
	_scores.clear()
	_ladle_target = CENTRE + Vector2(SURFACE_RADII.x, 0)
	_ladle.position = _ladle_target
	_touched = false
	_ghost.visible = not assist
	_ghost.modulate.a = GHOST_ALPHA
	_place_ladle(_ghost, _surface_point(GHOST_START_ANGLE))
	_guide.queue_redraw()


func _assist_caption() -> String:
	return "Auto Stir"


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
	_fire.texture = Art.texture("brewing", "fire_%d" % (int(_clock / FIRE_FRAME_TIME) % 3))
	_place_ladle(_ladle, _ladle.position.lerp(_ladle_target, minf(1.0, LADLE_FOLLOW_RATE * delta)))
	_place_ladle(_ghost, _surface_point(_ghost_angle()))
	if _touched:
		_ghost.modulate.a = move_toward(_ghost.modulate.a, 0.0, delta * GHOST_ALPHA / GHOST_FADE_TIME)
	else:
		_ghost.modulate.a = GHOST_ALPHA if _clock * _tempo < 1.0 else GHOST_FAINT_ALPHA
	_guide.queue_redraw()


## The ghost ladle (tests check its demonstration).
func ghost() -> Sprite2D:
	return _ghost


## The ghost's angle on the surface: one turn per 1 / tempo seconds, clockwise on screen.
func _ghost_angle() -> float:
	return GHOST_START_ANGLE + _clock * _tempo * TAU


func _surface_point(angle: float) -> Vector2:
	return CENTRE + Vector2.from_angle(angle) * SURFACE_RADII


## Puts a ladle's bowl at `at` and leans its handle with the bowl's side of the pot.
func _place_ladle(ladle: Sprite2D, at: Vector2) -> void:
	ladle.position = at
	ladle.rotation = (at.x - CENTRE.x) / SURFACE_RADII.x * LADLE_LEAN


func _station_finished(quality: float) -> void:
	_guide.queue_redraw()
	if quality >= ASSIST_QUALITY:
		Juice.squash(_rig, 0.2)
		Juice.burst(self, CENTRE, _liquid.modulate.lightened(0.3), 20)


func _sample(at: Vector2) -> void:
	var offset := at - CENTRE
	var radius := offset.length()
	if radius < MIN_RADIUS:
		_has_angle = false
		return
	var angle := offset.angle()
	_ladle_target = CENTRE + offset / radius * SURFACE_RADII
	if _rotation_start < 0.0:
		_rotation_start = _clock
	if _has_angle:
		var step := wrapf(angle - _last_angle, -PI, PI)
		_swept += step
		_swirl += absf(step)
		_liquid.texture = Art.texture("brewing", "cauldron_liquid_%d" % (int(_swirl / SWIRL_STEP) % 3))
	_last_angle = angle
	_has_angle = true
	_radii.append(radius)
	while _running and absf(_swept) >= TAU * (_scores.size() + 1):
		_complete_rotation()


func _complete_rotation() -> void:
	var duration := maxf(_clock - _rotation_start, 0.001)
	var tempo_error := absf(1.0 / duration - _tempo) / _tempo
	var score := TEMPO_WEIGHT * window_score(tempo_error, TEMPO_WINDOW) + (1.0 - TEMPO_WEIGHT) * window_score(_roundness_error(), ROUND_WINDOW)
	_scores.append(score)
	print("[Stir] rotation %d: %.2fs (tempo error %.2f), score %.2f" % [_scores.size(), duration, tempo_error, score])
	_rotation_start = _clock
	_radii.clear()
	feedback.emit(&"stir_rotation")
	Juice.squash(_rig, 0.06, 0.18)
	Juice.burst(self, _ladle_target, pip_color(score), 6)
	_guide.queue_redraw()
	if _scores.size() >= ROTATIONS:
		var total := 0.0
		for rotation_score in _scores:
			total += rotation_score
		_finish(total / _scores.size())


## Coefficient of variation (std / mean) of the radius samples of this rotation.
func _roundness_error() -> float:
	if _radii.size() < 2:
		return 0.0
	var mean := 0.0
	for radius in _radii:
		mean += radius
	mean /= _radii.size()
	var variance := 0.0
	for radius in _radii:
		variance += (radius - mean) * (radius - mean)
	variance /= _radii.size()
	return sqrt(variance) / mean


func _draw_guide() -> void:
	if _running and _ghost.visible and _ghost.modulate.a > 0.0:
		_draw_arrows(_ghost.modulate.a / GHOST_ALPHA)
	draw_pips(_guide, Vector2(CENTRE.x, PIP_Y), PIP_SPACING, ROTATIONS, _scores)


## ARROWS arcs on the finger's circle, evenly spaced, the first one's head at the
## ghost's angle, all turning with it; `strength` 0..1 scales their opacity.
func _draw_arrows(strength: float) -> void:
	var color := Color(ARROW_COLOR, strength)
	for i in ARROWS:
		var head := _ghost_angle() + i * TAU / ARROWS
		_guide.draw_arc(CENTRE, RING_RADIUS, head - ARROW_ARC, head, 8, color, ARROW_WIDTH)
		var tip := CENTRE + Vector2.from_angle(head) * RING_RADIUS
		var along := Vector2.from_angle(head + PI / 2.0)
		var out := Vector2.from_angle(head)
		_guide.draw_colored_polygon(PackedVector2Array([tip + along * ARROW_HEAD, tip - along + out * ARROW_HEAD, tip - along - out * ARROW_HEAD]), color)
