class_name Bellows
extends Station
## Bellows station: tap anywhere on the station to pump the bellows. Each pump
## raises the fire's heat by PUMP; the heat cools by COOL_RATE per second. A heat
## gauge shows the needle and the target band (bracketed by ticks, so the band is
## not shown by colour alone); the flames grow with the heat.
##
## params: "color" (Color, the mix's colour in the cauldron).
##
## The heat starts at HEAT_START, below the band. The timer starts when the needle
## first enters the band and runs for DURATION seconds (a bar under the cauldron
## fills with it); then quality = window_score(time out of band / DURATION,
## OUT_WINDOW). Idle: before the needle first reaches the band the station never
## finishes (the customer's patience is the only clock). Feedback: "bellows_pump"
## on every pump, "bellows_out" whenever the needle leaves the band while the timer runs.

const HEAT_START := 0.3
const BAND_LOW := 0.5
const BAND_HIGH := 0.8
const PUMP := 0.1
const COOL_RATE := 0.15
const DURATION := 5.0
## Fraction of DURATION out of the band that still scores 1.
const OUT_WINDOW := 0.1
const SQUEEZE_TIME := 0.12
const FIRE_FRAME_TIME := 0.12
## Flame height scale at heat 0 and at heat 1 (times the 2x art scale).
const FLAME_MIN := 0.5
const FLAME_MAX := 1.5
## Station-space points: the bellows' nozzle tip (bellows_0 canvas (42, 13) at 2x
## from the Bellows node) and the gauge, a vertical bar from heat 0 (bottom) to 1.
const NOZZLE := Vector2(88, 176)
const GAUGE_RECT := Rect2(222, 56, 12, 144)
const NEEDLE_SIZE := 6.0
const BAND_TICK := 4.0
const TIMER_RECT := Rect2(55, 222, 160, 6)
const GAUGE_BACK := Color("#3a2830")
const GAUGE_BAND := Color("#7cc44c")
const GAUGE_HEAT := Color("#f07c2c")
const NEEDLE_COLOR := Color("#fbedcd")
const TIMER_FILL := Color("#ffc95c")
const PUFF_COLOR := Color("#fbedcd")

## The fire's heat, 0..1.
var heat := HEAT_START
var _clock := 0.0
var _started := false
var _elapsed := 0.0
var _out_time := 0.0
var _was_in_band := false
var _squeeze := 0.0

@onready var _rig: Node2D = $Rig
@onready var _liquid: Sprite2D = $Rig/Liquid
@onready var _fire: Sprite2D = $Rig/Fire
@onready var _bellows: Sprite2D = $Bellows
@onready var _guide: Node2D = $Guide


func _ready() -> void:
	($Rig/Pot as Sprite2D).texture = Art.texture("brewing", "cauldron")
	_liquid.texture = Art.texture("brewing", "cauldron_liquid_0")
	_fire.texture = Art.texture("brewing", "fire_0")
	_bellows.texture = Art.texture("brewing", "bellows_0")
	_guide.draw.connect(_draw_guide)


## True once the needle has reached the band and the timer runs.
func is_timing() -> bool:
	return _started


## Seconds the needle spent out of the band since the timer started.
func out_time() -> float:
	return _out_time


func _station_begin(params: Dictionary) -> void:
	_liquid.modulate = _color_param(params)
	heat = HEAT_START
	_clock = 0.0
	_started = false
	_elapsed = 0.0
	_out_time = 0.0
	_was_in_band = false
	_squeeze = 0.0
	_bellows.texture = Art.texture("brewing", "bellows_0")
	_show_heat()


func _assist_caption() -> String:
	return "Auto Pump"


func _station_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	heat = minf(1.0, heat + PUMP)
	_squeeze = SQUEEZE_TIME
	_bellows.texture = Art.texture("brewing", "bellows_1")
	feedback.emit(&"bellows_pump")
	Juice.burst(self, NOZZLE, PUFF_COLOR, 5, Vector2(0, -40))
	_show_heat()


func _station_advance(delta: float) -> void:
	_clock += delta
	_fire.texture = Art.texture("brewing", "fire_%d" % (int(_clock / FIRE_FRAME_TIME) % 3))
	if _squeeze > 0.0:
		_squeeze -= delta
		if _squeeze <= 0.0:
			_bellows.texture = Art.texture("brewing", "bellows_0")
	heat = maxf(0.0, heat - COOL_RATE * delta)
	_show_heat()
	var inside := in_band()
	if not _started:
		if not inside:
			return
		_started = true
		print("[Bellows] needle in the band, timing %.1fs" % DURATION)
	elif _was_in_band and not inside:
		feedback.emit(&"bellows_out")
	_was_in_band = inside
	_elapsed += delta
	if not inside:
		_out_time += delta
	if _elapsed >= DURATION:
		var out_fraction := _out_time / _elapsed
		print("[Bellows] out of the band %.2fs of %.2fs" % [_out_time, _elapsed])
		_finish(window_score(out_fraction, OUT_WINDOW))


## True while the heat is inside the target band.
func in_band() -> bool:
	return heat >= BAND_LOW and heat <= BAND_HIGH


func _station_finished(quality: float) -> void:
	_guide.queue_redraw()
	if quality >= ASSIST_QUALITY:
		Juice.squash(_rig, 0.2)
		Juice.burst(self, _rig.position, _liquid.modulate.lightened(0.3), 20)


func _show_heat() -> void:
	_fire.scale.y = 2.0 * lerpf(FLAME_MIN, FLAME_MAX, heat)
	_guide.queue_redraw()


func _draw_guide() -> void:
	_guide.draw_rect(GAUGE_RECT, GAUGE_BACK)
	var low := _gauge_y(BAND_LOW)
	var high := _gauge_y(BAND_HIGH)
	_guide.draw_rect(Rect2(GAUGE_RECT.position.x, high, GAUGE_RECT.size.x, low - high), GAUGE_BAND)
	var level := _gauge_y(heat)
	_guide.draw_rect(Rect2(GAUGE_RECT.position.x + 3.0, level, GAUGE_RECT.size.x - 6.0, GAUGE_RECT.end.y - level), GAUGE_HEAT)
	for y: float in [low, high]:
		_guide.draw_line(Vector2(GAUGE_RECT.position.x - BAND_TICK, y), Vector2(GAUGE_RECT.end.x + BAND_TICK, y), NEEDLE_COLOR, 1.0)
	var left := GAUGE_RECT.position.x - 2.0
	_guide.draw_colored_polygon(PackedVector2Array([Vector2(left, level), Vector2(left - NEEDLE_SIZE, level - NEEDLE_SIZE), Vector2(left - NEEDLE_SIZE, level + NEEDLE_SIZE)]), NEEDLE_COLOR)
	_guide.draw_rect(TIMER_RECT, GAUGE_BACK)
	var done := clampf(_elapsed / DURATION, 0.0, 1.0)
	_guide.draw_rect(Rect2(TIMER_RECT.position, Vector2(TIMER_RECT.size.x * done, TIMER_RECT.size.y)), TIMER_FILL)
	_guide.draw_rect(TIMER_RECT, NEEDLE_COLOR, false, 1.0)


## The gauge's y for `value` 0..1 (0 at the bottom).
func _gauge_y(value: float) -> float:
	return GAUGE_RECT.end.y - clampf(value, 0.0, 1.0) * GAUGE_RECT.size.y
