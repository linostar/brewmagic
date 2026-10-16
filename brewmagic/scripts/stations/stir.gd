class_name Stir
extends Station
## Stir station: drag circles around the cauldron at the tempo the brew asks for.
## A glowing spark orbits the guide ring at the target tempo and the ring pulses
## on its beat. Either direction counts; back-and-forth wiggling does not.
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
## The stirring centre (the liquid surface) and the guide ring, in station coordinates.
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
const PIP_RADIUS := 5.0
## The pip's shape carries its result too (never colour alone): a four-point star
## for perfect, a round dot for good, a cross for sloppy.
const PIP_STAR_INNER := 1.5
const PIP_CROSS_WIDTH := 2.0
const RING_COLOR := Color("#fbedcd")
const GHOST_COLOR := Color("#ffc95c")
const PIP_PERFECT := Color("#ffc95c")
const PIP_GOOD := Color("#fbedcd")
const PIP_SLOPPY := Color("#c43c2c")
const PIP_EMPTY := Color("#5c5668")

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

@onready var _rig: Node2D = $Rig
@onready var _liquid: Sprite2D = $Rig/Liquid
@onready var _fire: Sprite2D = $Rig/Fire
@onready var _ladle: Sprite2D = $Ladle
@onready var _guide: Node2D = $Guide


func _ready() -> void:
	($Rig/Pot as Sprite2D).texture =Art.texture("brewing", "cauldron")
	_liquid.texture = Art.texture("brewing", "cauldron_liquid_0")
	_fire.texture = Art.texture("brewing", "fire_0")
	_ladle.texture = Art.texture("brewing", "ladle")
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
	_guide.queue_redraw()


func _station_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_sample(touch.position)
		else:
			_has_angle = false
		return
	_sample((event as InputEventScreenDrag).position)


func _station_advance(delta: float) -> void:
	_clock += delta
	_fire.texture = Art.texture("brewing", "fire_%d" % (int(_clock / FIRE_FRAME_TIME) % 3))
	_ladle.position = _ladle.position.lerp(_ladle_target, minf(1.0, LADLE_FOLLOW_RATE * delta))
	_ladle.rotation = (_ladle.position.x - CENTRE.x) / SURFACE_RADII.x * LADLE_LEAN
	_guide.queue_redraw()


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
	Juice.burst(self, _ladle_target, _pip_color(score), 6)
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


func _pip_color(score: float) -> Color:
	if score >= PERFECT_QUALITY:
		return PIP_PERFECT
	if score >= ASSIST_QUALITY:
		return PIP_GOOD
	return PIP_SLOPPY


func _draw_guide() -> void:
	var beat := 1.0 - fposmod(_clock * _tempo, 1.0)
	var ring := RING_COLOR
	ring.a = 0.25 + 0.35 * beat
	_guide.draw_arc(CENTRE, RING_RADIUS, 0.0, TAU, 48, ring, 1.0 + 2.0 * beat)
	if _running and not assist:
		var ghost_angle := -PI / 2.0 + _clock * _tempo * TAU
		_guide.draw_circle(CENTRE + Vector2.from_angle(ghost_angle) * RING_RADIUS, 4.0, GHOST_COLOR)
	var first_x := CENTRE.x - PIP_SPACING * (ROTATIONS - 1) / 2.0
	for i in ROTATIONS:
		var pip := Vector2(first_x + PIP_SPACING * i, PIP_Y)
		if i < _scores.size():
			_draw_pip(pip, _scores[i])
		else:
			_guide.draw_circle(pip, PIP_RADIUS, PIP_EMPTY, false, 1.0)


func _draw_pip(at: Vector2, score: float) -> void:
	var color := _pip_color(score)
	if score >= PERFECT_QUALITY:
		var star := PackedVector2Array()
		for corner: int in 8:
			var radius := PIP_RADIUS + 1.0 if corner % 2 == 0 else PIP_STAR_INNER
			star.append(at + Vector2.from_angle(-PI / 2.0 + corner * PI / 4.0) * radius)
		_guide.draw_colored_polygon(star, color)
	elif score >= ASSIST_QUALITY:
		_guide.draw_circle(at, PIP_RADIUS, color)
	else:
		var arm := PIP_RADIUS * 0.8
		_guide.draw_line(at + Vector2(-arm, -arm), at + Vector2(arm, arm), color, PIP_CROSS_WIDTH)
		_guide.draw_line(at + Vector2(-arm, arm), at + Vector2(arm, -arm), color, PIP_CROSS_WIDTH)
