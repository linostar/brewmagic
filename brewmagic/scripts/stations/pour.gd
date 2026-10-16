class_name Pour
extends Station
## Pour station: hold anywhere on the station to pour, let go on the line.
## One attempt: the first release ends the station. The bottle (shape from the
## potion) fills from the bottom with the potion colour; a dashed marker shows
## the target. Past the brim it spills droplets, and at OVERFLOW_LIMIT the pour
## ends by itself.
##
## params: "color" (Color), "bottle" (one of BOTTLES), "line" (optional float,
## target fill 0..1, default DEFAULT_LINE; snapped to a whole pixel row of the
## liquid mask so the marker and a perfect fill line up exactly).
##
## Quality = window_score(|fill - line|, LINE_WINDOW). Idle: without a touch the
## station never finishes. Feedback: "pour_start" on touch, "pour_spill" when the
## bottle first overflows, "pour_stop" on release.

const BOTTLES: Array[String] = ["round", "tall", "flask", "teardrop"]
const DEFAULT_LINE := 0.75
## Seconds of holding to fill an empty bottle to the brim.
const FILL_TIME := 1.5
## Fill error that still scores 1 (fraction of the bottle).
const LINE_WINDOW := 0.04
const OVERFLOW_LIMIT := 1.25
const BOTTLE_SIZE := Vector2(20, 28)
## Matches the Bottle node's scale in pour.tscn.
const BOTTLE_SCALE := 4.0
const CORK_REST := Vector2(6, -3)
const SPILL_INTERVAL := 0.08
const SPILL_GRAVITY := Vector2(0, 260)
const STREAM_WIDTH := 1.5
const STREAM_TOP := -12.0
## Station-space point the bottle is centred on (the Bottle node's position in pour.tscn).
const BOTTLE_CENTRE := Vector2(135, 150)

var fill := 0.0
var _line := DEFAULT_LINE
var _pouring := false
var _spilling := false
var _spill_clock := 0.0
var _liquid_region := Rect2()
## The liquid mask's opaque rows, top and one past the bottom (art_src/brewing.px:
## the depth depends on the bottle shape, so it is read from the mask itself).
var _top_row := 0
var _bottom_row := 0

## Scaled BOTTLE_SCALE and centred on BOTTLE_CENTRE (so it squashes around its
## middle); its Canvas child holds the sprites in art pixels, canvas origin top-left.
@onready var _bottle: Node2D = $Bottle
@onready var _glass: Sprite2D = $Bottle/Canvas/Glass
@onready var _liquid: Sprite2D = $Bottle/Canvas/Liquid
@onready var _line_marker: Sprite2D = $Bottle/Canvas/FillLine
@onready var _cork: Sprite2D = $Bottle/Canvas/Cork
@onready var _stream: Node2D = $Bottle/Canvas/Stream


func _ready() -> void:
	_line_marker.texture = Art.texture("brewing", "fill_line")
	_cork.texture = Art.texture("brewing", "cork")
	_stream.draw.connect(_draw_stream)


## The target fill as used for scoring (after snapping to a pixel row).
func target_line() -> float:
	return _line


## The current bottle's liquid rows on the 20x28 canvas: x = top row, y = one past the bottom row.
func liquid_rows() -> Vector2i:
	return Vector2i(_top_row, _bottom_row)


func _station_begin(params: Dictionary) -> void:
	var color := _color_param(params)
	var shape := str(params.get("bottle", ""))
	if shape not in BOTTLES:
		push_error("[Pour] Unknown bottle '%s' (expected one of %s); using %s" % [shape, BOTTLES, BOTTLES[0]])
		shape = BOTTLES[0]
	_glass.texture = Art.texture("brewing", "bottle_" + shape)
	var liquid := Art.texture("brewing", "bottle_%s_liquid" % shape)
	_liquid.texture = liquid.atlas
	_liquid_region = liquid.region
	var mask_rows := _mask_rows("bottle_%s_liquid" % shape, liquid)
	_top_row = mask_rows.x
	_bottom_row = mask_rows.y
	_liquid.modulate = color
	var rows := _bottom_row - _top_row
	var line := clampf(float(params.get("line", DEFAULT_LINE)), 0.1, 0.95)
	var line_rows := roundi(line * rows)
	_line = float(line_rows) / rows
	_line_marker.position = Vector2(-2, _bottom_row - line_rows - 1)
	print("[Pour] %s bottle, liquid rows %d..%d, line %.3f" % [shape, _top_row, _bottom_row - 1, _line])
	_line_marker.show()
	_cork.hide()
	fill = 0.0
	_pouring = false
	_spilling = false
	_spill_clock = 0.0
	_show_fill()


func _station_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed and not _pouring:
		_pouring = true
		feedback.emit(&"pour_start")
		_stream.queue_redraw()
	elif not touch.pressed and _pouring:
		_stop()


func _station_advance(delta: float) -> void:
	if not _pouring:
		return
	fill += delta / FILL_TIME
	_show_fill()
	if fill > 1.0:
		if not _spilling:
			_spilling = true
			feedback.emit(&"pour_spill")
		_spill_clock -= delta
		if _spill_clock <= 0.0:
			_spill_clock = SPILL_INTERVAL
			var lip := BOTTLE_CENTRE - Vector2(0, BOTTLE_SIZE.y * BOTTLE_SCALE / 2.0)
			Juice.burst(self, lip, _liquid.modulate, 4, SPILL_GRAVITY)
	if fill >= OVERFLOW_LIMIT:
		_stop()


func _station_finished(quality: float) -> void:
	_stream.queue_redraw()
	if quality < ASSIST_QUALITY:
		return
	_line_marker.hide()
	_cork.position = CORK_REST - Vector2(0, 12)
	_cork.modulate.a = 0.0
	_cork.show()
	var tween := _cork.create_tween().set_parallel()
	tween.tween_property(_cork, "position", CORK_REST, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_cork, "modulate:a", 1.0, 0.1)
	Juice.squash(_bottle, 0.15)
	Juice.burst(self, BOTTLE_CENTRE, _liquid.modulate.lightened(0.3), 16)


func _stop() -> void:
	_pouring = false
	feedback.emit(&"pour_stop")
	var error := absf(fill - _line)
	print("[Pour] released at %.3f, line %.3f" % [fill, _line])
	_finish(window_score(error, LINE_WINDOW))


## Reveals the liquid mask from the bottom, one pixel row per 1/rows of fill.
func _show_fill() -> void:
	var rows := _bottom_row - _top_row
	var shown := clampi(roundi(fill * rows), 0, rows)
	_liquid.visible = shown > 0
	_liquid.region_rect = Rect2(_liquid_region.position.x, _liquid_region.position.y + _bottom_row - shown, _liquid_region.size.x, shown)
	_liquid.position = Vector2(0, _bottom_row - shown)
	_stream.queue_redraw()


func _draw_stream() -> void:
	if not _pouring:
		return
	var rows := _bottom_row - _top_row
	var surface := _bottom_row - clampf(fill, 0.0, 1.0) * rows
	var x := BOTTLE_SIZE.x / 2.0 - STREAM_WIDTH / 2.0
	_stream.draw_rect(Rect2(x, STREAM_TOP, STREAM_WIDTH, surface - STREAM_TOP), _liquid.modulate)


## The rows of `mask` (sprite `sprite_name`) that hold liquid pixels: x = top row,
## y = one past the bottom row. An unreadable or empty mask is reported and the
## whole sprite height is used.
static func _mask_rows(sprite_name: String, mask: AtlasTexture) -> Vector2i:
	var full := Vector2i(0, int(mask.region.size.y))
	var image := mask.atlas.get_image()
	if image == null:
		push_error("[Pour] Cannot read the liquid mask %s; filling its whole height" % sprite_name)
		return full
	var used := image.get_region(Rect2i(mask.region)).get_used_rect()
	if used.size.y == 0:
		push_error("[Pour] Liquid mask %s is empty; filling its whole height" % sprite_name)
		return full
	return Vector2i(used.position.y, used.end.y)
