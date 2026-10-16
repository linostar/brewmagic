class_name Customer
extends Node2D
## One shop visitor (CLAUDE.md "Customers"): assembled from the archetype's part
## sprites (art_src/customer.px: 48x72 canvases, layer order body, head, hair,
## face, accessory, idle-bob frames _0/_1), walking in from the door to stand
## behind the counter. The node's origin is the canvas top-left; the shop places
## it at y = CANVAS_Y so the counter row (52) meets the counter top. The face
## part follows the mood (happy, neutral, annoyed; storming looks annoyed).
##
## States: ENTER -> (QUEUED ->) WAIT_ORDER -> WAIT_BREW -> RECEIVE -> REACT -> LEAVE -> GONE.
## The shop's line has SLOT_X.size() places: slot 0 is the counter, the others
## queue up to its left (in front of the window). enter(slot) walks in from the
## door, walk_to(slot) steps forward; arriving at the counter means WAIT_ORDER
## (and `arrived`), anywhere else QUEUED.
## Patience (seconds, set by setup()) drains in WAIT_ORDER and WAIT_BREW, and at
## QUEUE_PATIENCE_RATE while QUEUED (also while stepping forward); the patience row
## (an hourglass, then the hearts) shows what is left at the counter (in the queue
## it would cover the next customer), the queue meter (3 pips over the head,
## each full, half or empty by shape) shows it at a queue place, and the face
## always shows the mood.
## At zero the customer turns STORMING (it takes no order or brew any more), emits
## patience_ran_out once and waits for the shop to make it leave. The patience row
## hides once the potion arrives or the customer storms off.
##
## Colours: every part sprite but the face draws through shaders/palette_swap.gdshader
## with the swaps of the visitor's Look (setup), so the same parts make many visitors.

signal arrived
signal patience_ran_out
signal left

enum State { ENTER, WAIT_ORDER, WAIT_BREW, STORMING, RECEIVE, REACT, LEAVE, GONE, QUEUED }
enum Mood { HAPPY, NEUTRAL, ANNOYED, STORMING }

## The counter's top surface in the shop (art_src/shop.px) and the canvas
## top-left y that puts the canvas' counter row (52) on it.
const COUNTER_TOP := 148.0
const CANVAS_Y := COUNTER_TOP - 52.0
## The canvas column the head is centred on.
const CENTER_X := 24.0
## Canvas left x in the door opening (x 216..262) and at the counter (head on the stage centre, x 135).
const DOOR_X := 215.0
const COUNTER_X := 111.0
## Canvas left x of each place in line: the counter, then the queue in front of the window.
const SLOT_X: Array[float] = [COUNTER_X, 63.0, 15.0]
## How fast patience drains while queued, relative to waiting at the counter.
const QUEUE_PATIENCE_RATE := 0.5
const SWAP_SHADER := preload("res://shaders/palette_swap.gdshader")
## The shader's uniform array length (MAX_SWAPS in palette_swap.gdshader).
const MAX_SWAPS := 12
## The Body node's rest position: the canvas' feet centre, so squash and flip pivot there.
const BODY_REST := Vector2(24, 72)
## Canvas points the shop aims at: the hands on the counter (bottles), the chest (coins).
const HANDS := Vector2(24, 48)
const CHEST := Vector2(24, 42)
## Seconds to walk from the door to the counter; other walks keep that speed.
const WALK_TIME := 1.1
const WALK_HOP := 2.0
## Hops per WALK_TIME of walking.
const WALK_STEPS := 4.0
const MIN_WALK_TIME := 0.25
const BOB_TIME := 0.45
## Patience fractions at or above which the mood is HAPPY, then NEUTRAL; above 0 ANNOYED.
const HAPPY_PATIENCE := 0.66
const NEUTRAL_PATIENCE := 0.33
## Mood -> face part (art_src/customer.px has three expressions).
const FACES: Array[String] = ["face_happy", "face_neutral", "face_annoyed", "face_annoyed"]
## Index of the face in the part layers.
const FACE_LAYER := 3
## Misbrew effect -> tint of the whole customer.
const EFFECT_TINTS: Dictionary[String, Color] = {
	"singed": Color("#b8804c"), "frosted": Color("#c8f0f0"), "sprouting": Color("#cce878"), "gloomy": Color("#9058c0"),
}

var state := State.ENTER
var archetype: Archetype
var potion: PotionType
var request: RequestLine
var patience_total := 1.0
var patience_left := 1.0
## The misbrew effect shown on the customer, or "".
var effect := ""
## The visitor's colours (palette swap).
var look: Look
## The visitor's number in the shift (1-based), for logs.
var number := 0
## The place in line it stands at or walks to (0 = counter).
var slot := 0

var _bob_clock := 0.0
var _frame := 0
var _part_names: Array[String] = []
var _walk_tween: Tween

@onready var _body: Node2D = $Body
@onready var _parts: Array[Sprite2D] = [$Body/BodyPart, $Body/Head, $Body/Hair, $Body/Face, $Body/Accessory]
@onready var _patience_row: Node2D = $Patience
@onready var _hearts: Array[Sprite2D] = [$Patience/Heart0, $Patience/Heart1, $Patience/Heart2, $Patience/Heart3]
@onready var _queue_meter: Node2D = $QueueMeter
@onready var _pips: Array[Sprite2D] = [$QueueMeter/Pip0, $QueueMeter/Pip1, $QueueMeter/Pip2]
@onready var _effect_root: Node2D = $Effect


## The swappable parts (no face) `who` is drawn with, in layer order: body, head,
## hair and the accessory unless it is "none".
static func parts_of(who: Archetype) -> Array[String]:
	var parts: Array[String] = ["body_" + who.part_body, "head_" + who.part_head, "hair_" + who.part_hair]
	if who.part_accessory != "none":
		parts.append("acc_" + who.part_accessory)
	return parts


## Configures the visitor before it enters the tree's _ready runs (call before add_child).
func setup(who: Archetype, wants: PotionType, says: RequestLine, patience_seconds: float, colors: Look) -> void:
	archetype = who
	potion = wants
	request = says
	look = colors
	patience_total = maxf(patience_seconds, 0.01)
	patience_left = patience_total
	var accessory := "" if who.part_accessory == "none" else "acc_" + who.part_accessory
	_part_names = ["body_" + who.part_body, "head_" + who.part_head, "hair_" + who.part_hair, FACES[Mood.HAPPY], accessory]


func _ready() -> void:
	($Patience/Hourglass as Sprite2D).texture = Art.texture("ui", "hourglass")
	_patience_row.hide()
	_queue_meter.hide()
	_apply_look()
	_show_frame(0)
	_update_patience()
	position = Vector2(DOOR_X, CANVAS_Y)
	modulate.a = 0.0


## Walks in from the door to place `to_slot` in line.
func enter(to_slot: int) -> void:
	state = State.ENTER
	walk_to(to_slot)
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


## Walks to place `to_slot` in line (from wherever it is). Arriving at the counter
## turns it WAIT_ORDER and emits `arrived`; anywhere else it is QUEUED.
func walk_to(to_slot: int) -> void:
	slot = to_slot
	_queue_meter.visible = slot > 0
	if _walk_tween != null:
		_walk_tween.kill()
	_walk_tween = _walk(SLOT_X[to_slot])
	_walk_tween.tween_callback(func() -> void:
		if state != State.ENTER and state != State.QUEUED:
			return
		Juice.squash(_body, 0.12)
		if slot == 0:
			state = State.WAIT_ORDER
			_patience_row.show()
			arrived.emit()
		else:
			state = State.QUEUED)


func start_brew() -> void:
	if state == State.WAIT_ORDER:
		state = State.WAIT_BREW


## The bottle reached the customer: patience stops and its row hides.
func receive() -> void:
	state = State.RECEIVE
	_patience_row.hide()


## Reacts to a finished brew: a happy hop for Perfect and Good, a slump for Meh,
## the misbrew effect for a Misbrew (`misbrew_effect` from Content.MISBREW_EFFECTS).
func react(grade: Brew.Grade, misbrew_effect := "") -> void:
	state = State.REACT
	match grade:
		Brew.Grade.PERFECT, Brew.Grade.GOOD:
			_show_mood(Mood.HAPPY)
			var hop := create_tween()
			hop.tween_property(_body, "position:y", BODY_REST.y - 6.0, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			hop.tween_property(_body, "position:y", BODY_REST.y, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
			if grade == Brew.Grade.PERFECT:
				hop.tween_property(_body, "position:y", BODY_REST.y - 4.0, 0.1).set_ease(Tween.EASE_OUT)
				hop.tween_property(_body, "position:y", BODY_REST.y, 0.14).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
			Juice.squash(_body, 0.15)
		Brew.Grade.MEH:
			_show_mood(Mood.NEUTRAL)
			Juice.squash(_body, -0.1, 0.4)
		Brew.Grade.MISBREW:
			_show_mood(Mood.ANNOYED)
			if misbrew_effect != "":
				show_effect(misbrew_effect)


## Tints the customer and starts the effect's particles (singed, frosted, sprouting, gloomy).
func show_effect(name_of_effect: String) -> void:
	if not EFFECT_TINTS.has(name_of_effect):
		push_error("[Customer] Unknown misbrew effect '%s' (known: %s)" % [name_of_effect, EFFECT_TINTS.keys()])
		return
	effect = name_of_effect
	_body.modulate = EFFECT_TINTS[name_of_effect]
	Juice.squash(_body, 0.3, 0.4)
	Juice.burst(self, Vector2(24, 24), EFFECT_TINTS[name_of_effect], 20)
	var particles := CPUParticles2D.new()
	particles.amount = 14
	particles.lifetime = 1.2
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(13, 3)
	particles.position = Vector2(24, 16)
	match name_of_effect:
		"singed":
			particles.color = Color("#c8c0c8")
			particles.amount = 18
			particles.scale_amount_max = 3.0
			particles.direction = Vector2.UP
			particles.spread = 20.0
			particles.gravity = Vector2(0, -20)
			particles.initial_velocity_min = 6.0
			particles.initial_velocity_max = 14.0
		"frosted":
			particles.color = Color("#c8f0f0")
			particles.position = Vector2(24, 4)
			particles.emission_rect_extents = Vector2(22, 2)
			particles.gravity = Vector2(0, 18)
			particles.spread = 180.0
			particles.initial_velocity_max = 4.0
		"sprouting":
			particles.color = Color("#7cc44c")
			particles.direction = Vector2.UP
			particles.spread = 50.0
			particles.gravity = Vector2(0, 30)
			particles.initial_velocity_min = 20.0
			particles.initial_velocity_max = 30.0
		"gloomy":
			particles.color = Color("#583088")
			particles.position = Vector2(24, 6)
			particles.emission_rect_extents = Vector2(16, 2)
			particles.gravity = Vector2.ZERO
			particles.spread = 180.0
			particles.initial_velocity_max = 3.0
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 4.0
	_effect_root.add_child(particles)
	particles.emitting = true


## Walks back out through the door, then emits `left`.
func leave() -> void:
	state = State.LEAVE
	_patience_row.hide()
	_queue_meter.hide()
	if _walk_tween != null:
		_walk_tween.kill()
	var tween := _walk(DOOR_X)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3).set_delay(maxf(_walk_time(DOOR_X) - 0.3, 0.0))
	_walk_tween = tween
	tween.tween_callback(func() -> void:
		state = State.GONE
		left.emit())


func is_waiting() -> bool:
	return state == State.WAIT_ORDER or state == State.WAIT_BREW


func mood() -> Mood:
	var fraction := patience_left / patience_total
	if fraction >= HAPPY_PATIENCE:
		return Mood.HAPPY
	if fraction >= NEUTRAL_PATIENCE:
		return Mood.NEUTRAL
	if fraction > 0.0:
		return Mood.ANNOYED
	return Mood.STORMING


func _process(delta: float) -> void:
	_bob_clock += delta
	if _bob_clock >= BOB_TIME:
		_bob_clock -= BOB_TIME
		_show_frame(1 - _frame)
	var rate := 1.0 if is_waiting() else (QUEUE_PATIENCE_RATE if state == State.QUEUED else 0.0)
	if rate == 0.0:
		return
	patience_left = maxf(patience_left - delta * rate, 0.0)
	_update_patience()
	if patience_left <= 0.0:
		state = State.STORMING
		_patience_row.hide()
		_queue_meter.hide()
		print("[Customer] %s ran out of patience%s" % [archetype.id, " in the queue" if slot > 0 else ""])
		Juice.shake(_body, 2.0, 0.3)
		patience_ran_out.emit()


func _walk(to_x: float) -> Tween:
	var from_x := position.x
	var time := _walk_time(to_x)
	var steps := roundf(WALK_STEPS * time / WALK_TIME)
	_body.scale.x = -1.0 if to_x > from_x else 1.0
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		position.x = roundf(lerpf(from_x, to_x, t))
		_body.position.y = BODY_REST.y - roundf(absf(sin(t * PI * steps)) * WALK_HOP), 0.0, 1.0, time)
	return tween


## Seconds to walk from here to x `to_x` at the door-to-counter pace.
func _walk_time(to_x: float) -> float:
	return maxf(absf(to_x - position.x) / (DOOR_X - COUNTER_X) * WALK_TIME, MIN_WALK_TIME)


## Gives every part but the face (no swappable colours) the palette swap of `look`.
func _apply_look() -> void:
	# Before setup() (a bare scene) there are no part names and no look.
	for i in mini(_parts.size(), _part_names.size()):
		var part := _part_names[i]
		if i == FACE_LAYER or part == "" or look == null:
			continue
		var swaps := look.swaps(part)
		if swaps.size() > MAX_SWAPS:
			push_error("[Customer] %s needs %d colour swaps, the shader holds %d" % [part, swaps.size(), MAX_SWAPS])
			continue
		if swaps.is_empty():
			continue
		var from := PackedColorArray()
		var to := PackedColorArray()
		for art_color: String in swaps:
			from.append(Color(art_color))
			to.append(Color(swaps[art_color]))
		from.resize(MAX_SWAPS)
		to.resize(MAX_SWAPS)
		var swap := ShaderMaterial.new()
		swap.shader = SWAP_SHADER
		swap.set_shader_parameter(&"count", swaps.size())
		swap.set_shader_parameter(&"from_colors", from)
		swap.set_shader_parameter(&"to_colors", to)
		_parts[i].material = swap


func _show_frame(frame: int) -> void:
	_frame = frame
	for i in _parts.size():
		if i < _part_names.size() and _part_names[i] != "":
			_parts[i].texture = Art.texture("customer", "%s_%d" % [_part_names[i], frame])
			_parts[i].show()
		else:
			_parts[i].hide()


func _update_patience() -> void:
	_fill(_hearts, "heart")
	_fill(_pips, "pip")
	_show_mood(mood())


## Shows the patience left on `sprites` in half steps: <kind>_full, _half or _empty.
func _fill(sprites: Array[Sprite2D], kind: String) -> void:
	var halves := ceili(patience_left / patience_total * sprites.size() * 2.0)
	for i in sprites.size():
		var left_halves := halves - i * 2
		var sprite := "_full" if left_halves >= 2 else ("_half" if left_halves == 1 else "_empty")
		sprites[i].texture = Art.texture("ui", kind + sprite)


func _show_mood(value: Mood) -> void:
	if _part_names.size() > FACE_LAYER and _part_names[FACE_LAYER] != FACES[value]:
		_part_names[FACE_LAYER] = FACES[value]
		_show_frame(_frame)
