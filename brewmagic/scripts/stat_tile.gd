class_name StatTile
extends PanelContainer
## One stat of a results screen (Summary, Results): a 9x9 ui-atlas icon and a small
## caption over a big number (VT323 25, never Silkscreen: digits) on the theme's panel,
## TILE_WIDTH wide; an optional small line under the number (Sub, e.g. "now 12").
## setup() shows the final number at once; pop() (the Tally reveal) shows the tile
## with a squash and counts the number up from 0; finish() jumps to the final text.
## Add the tile to the tree before setup().

const TILE_WIDTH := 124.0
## Content margin inside the panel frame (the theme's panel has 10, too airy for a tile).
const MARGIN := 6.0
## How long a count-up from 0 to the value takes.
const COUNT_TIME := 0.5
## Coins popping out of the icon when a tile with burst_coins pops in.
const BURST_COINS := 5

## The final number.
var value := 0
## Format for the number, applied to the counted integer ("%d", "%+d", "%d/3").
var number_format := "%d"
## pop() also bursts a few coins from the icon (Coins earned, Score).
var burst_coins := false

var _count: Tween

@onready var _icon: TextureRect = $List/Caption/Icon
@onready var _caption: Label = $List/Caption/Text
@onready var _number: Label = $List/Number
@onready var _sub: Label = $List/Sub


func _ready() -> void:
	var box := get_theme_stylebox(&"panel").duplicate() as StyleBox
	box.content_margin_left = MARGIN
	box.content_margin_right = MARGIN
	box.content_margin_top = MARGIN
	box.content_margin_bottom = MARGIN
	add_theme_stylebox_override(&"panel", box)


## Sets the icon (a ui atlas sprite), caption, final value, its format and the
## optional line under the number, and shows the final number.
func setup(icon_sprite: String, caption: String, final_value: int, format := "%d", sub := "") -> void:
	_icon.texture = Art.texture("ui", icon_sprite)
	_caption.text = caption
	value = final_value
	number_format = format
	_sub.text = sub
	_sub.visible = sub != ""
	name = caption.to_pascal_case()
	finish()


## The number as it ends: the value in its format.
func final_text() -> String:
	return number_format % value


## The number label's current text.
func number_text() -> String:
	return _number.text


## The small line under the number ("" when there is none).
func sub_text() -> String:
	return _sub.text if _sub.visible else ""


## Shows the tile with a squash, counts its number up and (burst_coins) bursts coins.
func pop() -> void:
	modulate.a = 1.0
	pivot_offset = size / 2.0
	Juice.squash(self, 0.15)
	count_up()
	if burst_coins:
		_burst()


## Counts the number from 0 to the value over `duration`; the last step is the exact value.
func count_up(duration := COUNT_TIME) -> Tween:
	_kill_count()
	_show_count(0.0)
	_count = create_tween()
	_count.tween_method(_show_count, 0.0, 1.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_count.tween_callback(finish)
	return _count


## True while the number is counting up.
func is_counting() -> bool:
	return _count != null and _count.is_valid() and _count.is_running()


## Shows the tile with its final number at once.
func finish() -> void:
	_kill_count()
	modulate.a = 1.0
	_number.text = final_text()


func _show_count(t: float) -> void:
	var counted := roundi(value * t)
	# A negative count starts at a plain "0", never "+0".
	_number.text = "0" if counted == 0 and value < 0 else number_format % counted


func _kill_count() -> void:
	if _count != null and _count.is_valid():
		_count.kill()
	_count = null


func _burst() -> void:
	var from := get_global_transform().affine_inverse() * _icon.get_global_rect().get_center()
	for i in BURST_COINS:
		var coin := Sprite2D.new()
		coin.texture = Art.texture("ui", "coin_%d" % (i % 2))
		coin.position = from
		add_child(coin)
		var angle := lerpf(-PI * 0.85, -PI * 0.15, float(i) / (BURST_COINS - 1))
		var tween := coin.create_tween()
		tween.tween_property(coin, "position", from + Vector2.from_angle(angle) * 22.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(coin, "position:y", from.y + 8.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(coin, "modulate:a", 0.0, 0.25)
		tween.tween_callback(coin.queue_free)
