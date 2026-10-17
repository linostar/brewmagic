class_name ShelfItem
extends Button
## One ingredient on the shop shelf: its stock count above, its sprite standing on
## the plank, and under it one essence icon per point of its essence (the pips).
## A focusable Button, so a tap, a click or Enter emits `chosen`; dragging it (a
## touch that moves more than DRAG_THRESHOLD) shows a ghost under the finger and
## emits `dropped` with the release point instead. A drag that starts clearly
## sideways scrolls the shelf instead (`swiped`, when the shelf is wider than the
## screen), so a long shelf scrolls with the same thumb.
## Touch handling lives here (scripts/ui/) per the project's input rule.

signal chosen(item: ShelfItem)
## A drag ended at `canvas_point` (canvas coordinates); the shop decides whether it hit the cauldron.
signal dropped(item: ShelfItem, canvas_point: Vector2)
## A sideways drag moved `dx` (canvas units) since the last one; the shop scrolls the shelf.
signal swiped(dx: float)

const ITEM_SIZE := Vector2(40, 52)
## Where the 24x24 sprite sits so its baseline row (22) stands on the plank.
const ICON_POSITION := Vector2(8, 15)
const DRAG_THRESHOLD := 10.0
## A drag scrolls the shelf only when it starts this many times more sideways than
## up or down, so a diagonal drag towards the cauldron still carries the ingredient.
const SWIPE_RATIO := 2.0

var ingredient: Ingredient
var stock := 0

## True while the shelf is wider than its row (set by the shop); only then does a
## sideways drag scroll instead of carrying the ingredient.
var scrollable := false

var _press_point := Vector2.ZERO
var _dragging := false
var _swiping := false
var _last_x := 0.0
## Set when a drag ends so the Button's own release does not also count as a tap.
var _suppress_press := false

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count
@onready var _essences: HBoxContainer = $Essences
@onready var _ghost: TextureRect = $Ghost


func setup(item: Ingredient, count: int) -> void:
	ingredient = item
	stock = count


func _ready() -> void:
	_ghost.hide()
	# The shop calls setup() before adding the item; a bare instance (the project check) shows nothing.
	if ingredient == null:
		return
	_icon.texture = Art.texture("ingredients", ingredient.id)
	_ghost.texture = _icon.texture
	# One essence icon per point of essence, in Content.ESSENCES order (ember_pepper: two flames).
	for k in Content.ESSENCES.size():
		for i in ingredient.essence[k]:
			var pip := TextureRect.new()
			pip.texture = Art.texture("ui", "essence_" + Content.ESSENCES[k])
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_essences.add_child(pip)
	set_stock(stock)


func set_stock(count: int) -> void:
	stock = count
	_count.text = "x%d" % count
	disabled = count <= 0
	_icon.modulate.a = 1.0 if count > 0 else 0.35
	_essences.modulate.a = _icon.modulate.a
	accessibility_name = "%s (%s), %d left" % [ingredient.name, essence_text(), count]


## The ingredient's essences in words, e.g. "2 ember" or "1 frost, 1 bloom".
func essence_text() -> String:
	var parts := PackedStringArray()
	for k in Content.ESSENCES.size():
		if ingredient.essence[k] > 0:
			parts.append("%d %s" % [ingredient.essence[k], Content.ESSENCES[k]])
	return ", ".join(parts)


## Centre of the sprite in canvas coordinates (where a flying copy starts).
func icon_canvas_center() -> Vector2:
	return _icon.get_global_rect().get_center()


func _pressed() -> void:
	if _suppress_press:
		_suppress_press = false
		return
	chosen.emit(self)


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.index == 0:
		if touch.pressed:
			_press_point = touch.position
			_dragging = false
			_swiping = false
			_suppress_press = false
		elif _swiping:
			_swiping = false
			_suppress_press = true
		elif _dragging:
			_dragging = false
			_suppress_press = true
			_ghost.hide()
			dropped.emit(self, get_global_transform() * touch.position)
		return
	var drag := event as InputEventScreenDrag
	if drag == null or drag.index != 0:
		return
	var canvas_x := (get_global_transform() * drag.position).x
	if _swiping:
		swiped.emit(canvas_x - _last_x)
		_last_x = canvas_x
		return
	var moved := drag.position - _press_point
	if not _dragging and moved.length() > DRAG_THRESHOLD:
		if scrollable and absf(moved.x) > SWIPE_RATIO * absf(moved.y):
			_swiping = true
			_last_x = canvas_x
			swiped.emit(moved.x)
			return
		if disabled:
			return
		_dragging = true
		_ghost.show()
		Juice.squash(_ghost, 0.2)
	if _dragging:
		_ghost.global_position = (get_global_transform() * drag.position - _ghost.size / 2.0).round()
