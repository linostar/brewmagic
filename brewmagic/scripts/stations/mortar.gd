class_name Mortar
extends Station
## Mortar station: scrub the pestle side to side across the bowl to grind the brew's
## hard ingredients (those flagged `grind`) to powder, turning at the marks.
## The finger's x drives the pestle (anywhere on the station; only x counts): a rail
## under the bowl (RAIL_Y) shows the two marks at CENTRE.x +- MARK_X, each a target
## box MARK_WINDOW x tolerance_scale wide either side, bracketed by ticks, the next
## one also marked by an arrowhead (so neither the marks nor the next one are colour
## alone), and a dot where the finger is. A ghost pestle (washed pale blue by its
## material in mortar.tscn) and a ghost dot on the rail demonstrate the scrub: one
## stroke per GHOST_STROKE_TIME from mark to mark, GHOST_ALPHA for the first two
## strokes, then GHOST_FAINT_ALPHA, fading out on the first touch.
##
## params: "color" (Color, the powder's colour: the mix), "ingredients" (optional
## Array of ingredient ids drawn in the bowl, shrinking as they are ground).
##
## A stroke runs from one turn-around to the next: it ends when the finger comes
## back REVERSE_DISTANCE from the furthest point it reached (or lifts), and counts
## only if it covered MIN_STROKE (shorter back-and-forth is wiggling). A counted
## stroke scores where it turned: window_score(|turn x - that side's mark|,
## MARK_WINDOW), short of the mark is coarse, past it is over the rim. STROKES
## strokes finish the station with their mean; each grinds 1 / STROKES of the
## fineness. There is no speed target. Idle: without touches the station never
## finishes (the customer's patience is the only clock). Feedback: "mortar_stroke"
## on every counted stroke.

const STROKES := 6
## Distance from the bowl's centre line to each mark, in station x.
const MARK_X := 48.0
## Distance (station x) from the mark a turn-around still scores 1 at.
const MARK_WINDOW := 6.0
## A stroke shorter than this is wiggling and does not count.
const MIN_STROKE := 40.0
## How far the finger must come back from its furthest point to turn around.
const REVERSE_DISTANCE := 6.0
## The bowl's opening centre (mortar canvas (24, 5) at 3x), in station coordinates.
const CENTRE := Vector2(135, 118)
## The pestle's head stays on this ellipse in the opening; a mark puts it at the rim.
const SURFACE_RADII := Vector2(36, 6)
## The head may go this much past the rim (a stroke past the mark).
const HEAD_OVERREACH := 1.2
const PESTLE_LEAN := 0.35
const PESTLE_FOLLOW_RATE := 20.0
## The rail: its y, how far it runs past each mark, its thickness and the boxes' height.
const RAIL_Y := 214.0
const RAIL_EXTRA := 24.0
const RAIL_WIDTH := 4.0
const BOX_HEIGHT := 12.0
const TICK := 6.0
const ARROW_HEAD := 5.0
const DOT_RADIUS := 4.0
const PIP_Y := 250.0
const PIP_SPACING := 20.0
## Ingredient pieces sit on the powder, shrink to PIECE_MIN_SCALE as they are ground.
const PIECE_SPACING := 22.0
const PIECE_Y := -10.0
const PIECE_MIN_SCALE := 0.2
const POWDER_MIN_ALPHA := 0.25
const GHOST_STROKE_TIME := 0.6
const GHOST_ALPHA := 0.7
const GHOST_FAINT_ALPHA := 0.35
const GHOST_FADE_TIME := 0.3
const GUIDE_COLOR := Color("#ffc95c")
## The rail: the cream of the dots, faint, so it reads on the dark station dim.
const RAIL_COLOR := Color("#fbedcd", 0.35)
const BOX_COLOR := Color("#7cc44c")
const DOT_COLOR := Color("#fbedcd")

## How finely the brew is ground so far, 0..1.
var fineness := 0.0
var _clock := 0.0
## The finger: touching, its x; the stroke: direction (-1, +1, 0 before it moves),
## furthest x reached, and where it started (the last counted turn-around).
var _touching := false
var _finger_x := CENTRE.x
var _dir := 0
var _extreme := CENTRE.x
var _origin := CENTRE.x
var _stroke_scores: Array[float] = []
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


## The scores of the strokes counted so far, oldest first.
func stroke_scores() -> Array[float]:
	return _stroke_scores.duplicate()


## The ghost pestle (tests check its demonstration).
func ghost() -> Sprite2D:
	return _ghost


func _station_begin(params: Dictionary) -> void:
	_powder.modulate = _color_param(params)
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
	_touching = false
	_finger_x = CENTRE.x
	_dir = 0
	_extreme = CENTRE.x
	_origin = CENTRE.x
	_stroke_scores.clear()
	_pestle_target = CENTRE + Vector2(SURFACE_RADII.x, 0)
	_place_pestle(_pestle, _pestle_target)
	_touched = false
	_ghost.visible = not assist
	_ghost.modulate.a = GHOST_ALPHA
	_place_pestle(_ghost, _head_at(_ghost_x()))
	_show_fineness()
	_guide.queue_redraw()


func _assist_caption() -> String:
	return "Auto Grind"


func _station_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_touched = true
			_touching = true
			_finger_x = touch.position.x
			_pestle_target = _head_at(_finger_x)
			_dir = 0
			_extreme = _finger_x
			_origin = _finger_x
		else:
			# Lifting the finger ends the stroke where it turned.
			if _dir != 0:
				_end_stroke()
			_dir = 0
			_touching = false
		_guide.queue_redraw()
		return
	_scrub((event as InputEventScreenDrag).position.x)


func _station_advance(delta: float) -> void:
	_clock += delta
	_place_pestle(_pestle, _pestle.position.lerp(_pestle_target, minf(1.0, PESTLE_FOLLOW_RATE * delta)))
	_place_pestle(_ghost, _head_at(_ghost_x()))
	if _touched:
		_ghost.modulate.a = move_toward(_ghost.modulate.a, 0.0, delta * GHOST_ALPHA / GHOST_FADE_TIME)
	else:
		_ghost.modulate.a = GHOST_ALPHA if _clock < 2.0 * GHOST_STROKE_TIME else GHOST_FAINT_ALPHA
	_guide.queue_redraw()


func _station_finished(quality: float) -> void:
	_guide.queue_redraw()
	if quality >= ASSIST_QUALITY:
		fineness = 1.0
		_show_fineness()
		Juice.squash(_bowl, 0.2)
		Juice.burst(self, CENTRE, _powder.modulate.lightened(0.3), 20)


## The finger moved to `x`: it pushes the stroke on, or turns it around.
func _scrub(x: float) -> void:
	_finger_x = x
	_pestle_target = _head_at(x)
	if _dir == 0:
		if absf(x - _extreme) >= REVERSE_DISTANCE:
			_dir = 1 if x > _extreme else -1
			_extreme = x
		return
	if (x - _extreme) * _dir > 0.0:
		_extreme = x
	elif (_extreme - x) * _dir >= REVERSE_DISTANCE:
		_end_stroke()
		_dir = -_dir
		_extreme = x


## The stroke turned at _extreme: scores it against that side's mark when it was
## long enough (else it was wiggling and the last turn-around stays the origin).
func _end_stroke() -> void:
	if not _running or absf(_extreme - _origin) < MIN_STROKE:
		return
	var mark := CENTRE.x + _dir * MARK_X
	var score := window_score(absf(_extreme - mark), MARK_WINDOW)
	_stroke_scores.append(score)
	_origin = _extreme
	fineness = float(_stroke_scores.size()) / STROKES
	_show_fineness()
	print("[Mortar] stroke %d: turned at %.0f (mark %.0f), score %.2f" % [_stroke_scores.size(), _extreme, mark, score])
	feedback.emit(&"mortar_stroke")
	Juice.squash(_bowl, 0.06, 0.18)
	Juice.burst(self, _pestle.position, pip_color(score), 6)
	_guide.queue_redraw()
	if _stroke_scores.size() >= STROKES:
		var total := 0.0
		for value in _stroke_scores:
			total += value
		_finish(total / STROKES)


## The ghost's x: mark to mark and back, one stroke per GHOST_STROKE_TIME, starting
## at the left mark.
func _ghost_x() -> float:
	var phase := fmod(_clock / GHOST_STROKE_TIME, 2.0)
	return CENTRE.x + MARK_X * (1.0 - absf(phase - 1.0) * 2.0)


## Where the pestle's head goes for a finger at x: a mark puts it at the rim.
func _head_at(x: float) -> Vector2:
	var reach := clampf((x - CENTRE.x) / MARK_X, -HEAD_OVERREACH, HEAD_OVERREACH)
	return CENTRE + Vector2(reach * SURFACE_RADII.x, 0)


## Puts a pestle's head at `at` and leans it with the head's side of the bowl.
func _place_pestle(pestle: Sprite2D, at: Vector2) -> void:
	pestle.position = at
	pestle.rotation = (at.x - CENTRE.x) / SURFACE_RADII.x * PESTLE_LEAN


## The pieces shrink and the powder thickens as the fineness grows.
func _show_fineness() -> void:
	var piece_scale := lerpf(1.0, PIECE_MIN_SCALE, fineness)
	for piece: Sprite2D in _pieces.get_children():
		piece.scale = Vector2(piece_scale, piece_scale)
	_powder.modulate.a = lerpf(POWDER_MIN_ALPHA, 1.0, fineness)


## The rail with both marks' target boxes (ticks at their edges; an arrowhead over
## the mark the stroke heads for), the finger's dot, the ghost's dot and the pips.
func _draw_guide() -> void:
	_guide.draw_line(Vector2(CENTRE.x - MARK_X - RAIL_EXTRA, RAIL_Y), Vector2(CENTRE.x + MARK_X + RAIL_EXTRA, RAIL_Y), RAIL_COLOR, RAIL_WIDTH)
	var half := MARK_WINDOW * tolerance_scale
	for side: int in [-1, 1]:
		var mark := CENTRE.x + side * MARK_X
		_guide.draw_rect(Rect2(mark - half, RAIL_Y - BOX_HEIGHT / 2.0, half * 2.0, BOX_HEIGHT), BOX_COLOR)
		for x: float in [mark - half, mark + half]:
			_guide.draw_line(Vector2(x, RAIL_Y - BOX_HEIGHT / 2.0 - TICK), Vector2(x, RAIL_Y + BOX_HEIGHT / 2.0 + TICK), DOT_COLOR, 1.0)
		if _running and side == _dir:
			var top := RAIL_Y - BOX_HEIGHT / 2.0 - TICK - 2.0
			_guide.draw_colored_polygon(PackedVector2Array([Vector2(mark, top), Vector2(mark - ARROW_HEAD, top - ARROW_HEAD), Vector2(mark + ARROW_HEAD, top - ARROW_HEAD)]), GUIDE_COLOR)
	if _running and _ghost.visible and _ghost.modulate.a > 0.0:
		_guide.draw_circle(Vector2(_ghost_x(), RAIL_Y), DOT_RADIUS, Color(GUIDE_COLOR, _ghost.modulate.a / GHOST_ALPHA))
	if _running and _touching:
		_guide.draw_circle(Vector2(_finger_x, RAIL_Y), DOT_RADIUS, DOT_COLOR)
	draw_pips(_guide, Vector2(CENTRE.x, PIP_Y), PIP_SPACING, STROKES, _stroke_scores)
