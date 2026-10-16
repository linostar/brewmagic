class_name ShelfItem
extends Button
## One ingredient on the shop shelf: its sprite standing on the plank and its
## stock count below. A focusable Button, so a tap, a click or Enter emits
## `chosen`; dragging it (a touch that moves more than DRAG_THRESHOLD) shows a
## ghost under the finger and emits `dropped` with the release point instead.
## Touch handling lives here (scripts/ui/) per the project's input rule.

signal chosen(item: ShelfItem)
## A drag ended at `canvas_point` (canvas coordinates); the shop decides whether it hit the cauldron.
signal dropped(item: ShelfItem, canvas_point: Vector2)

const ITEM_SIZE := Vector2(40, 52)
## Where the 24x24 sprite sits so its baseline row (22) stands on the plank.
const ICON_POSITION := Vector2(8, 15)
const DRAG_THRESHOLD := 10.0

var ingredient: Ingredient
var stock := 0

var _press_point := Vector2.ZERO
var _dragging := false
## Set when a drag ends so the Button's own release does not also count as a tap.
var _suppress_press := false

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count
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
	set_stock(stock)


func set_stock(count: int) -> void:
	stock = count
	_count.text = "x%d" % count
	disabled = count <= 0
	_icon.modulate.a = 1.0 if count > 0 else 0.35
	accessibility_name = "%s, %d left" % [ingredient.name, count]


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
			_suppress_press = false
		elif _dragging:
			_dragging = false
			_suppress_press = true
			_ghost.hide()
			dropped.emit(self, get_global_transform() * touch.position)
		return
	var drag := event as InputEventScreenDrag
	if drag == null or drag.index != 0 or disabled:
		return
	if not _dragging and drag.position.distance_to(_press_point) > DRAG_THRESHOLD:
		_dragging = true
		_ghost.show()
		Juice.squash(_ghost, 0.2)
	if _dragging:
		_ghost.global_position = (get_global_transform() * drag.position - _ghost.size / 2.0).round()
