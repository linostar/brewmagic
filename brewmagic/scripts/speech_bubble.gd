class_name SpeechBubble
extends Control
## The customer's speech bubble: a 9-slice box from the ui atlas (margins 4) with
## a tail pointing down at the speaker, text laid out line by line from
## Content.wrap_bubble() (never Godot autowrap: the font is not monospace, and the
## data's "fits a bubble" rule is defined by wrap_bubble), revealed by a typewriter.
## Lives in the reading zone and takes no input itself: the shop calls skip() when
## the player taps the workspace, which first completes the line and then advances it.
##
## say(text, speaker_x, hold): hold < 0 keeps the line up until skip() or the next
## say(); hold >= 0 emits `advanced` that many seconds after the line is complete.

signal advanced

const CHARS_PER_SECOND := 40.0
const PADDING := Vector2(7, 5)
const LINE_SPACING := 2.0
## The box's bottom edge (the tail hangs below it, its tip just above the tallest hat at y 96).
const BOTTOM_Y := 88.0
const SIDE_MARGIN := 4.0
const TAIL_SIZE := Vector2(8, 6)
const POP_TIME := 0.16

var text := ""
var _shown := 0.0
var _hold := -1.0
var _hold_left := 0.0

@onready var _box: NinePatchRect = $Box
@onready var _label: Label = $Box/Text
@onready var _tail: TextureRect = $Tail


func _ready() -> void:
	var bubble := Art.texture("ui", "bubble")
	_box.texture = bubble.atlas
	_box.region_rect = bubble.region
	_tail.texture = Art.texture("ui", "bubble_tail")
	hide()


## Shows `line` above the speaker whose centre is at x = `speaker_x` (this
## Control's space) and starts typing it.
func say(line: String, speaker_x: float, hold := -1.0) -> void:
	text = line
	var lines := Content.wrap_bubble(line)
	var problem := Content.bubble_problem(line)
	if problem != "":
		push_error("[SpeechBubble] '%s': %s" % [line, problem])
	_label.text = "\n".join(lines)
	_label.visible_characters = 0
	_shown = 0.0
	_hold = hold
	_hold_left = hold
	var font := _label.get_theme_font(&"font")
	var font_size := _label.get_theme_font_size(&"font_size")
	var width := 0.0
	for each in lines:
		width = maxf(width, font.get_string_size(each, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var line_height := font.get_height(font_size) + LINE_SPACING
	_label.add_theme_constant_override(&"line_spacing", int(LINE_SPACING))
	var box_size := Vector2(ceilf(width), ceilf(line_height * lines.size() - LINE_SPACING)) + PADDING * 2.0
	var x := clampf(roundf(speaker_x - box_size.x / 2.0), SIDE_MARGIN, size.x - SIDE_MARGIN - box_size.x)
	_box.position = Vector2(x, BOTTOM_Y - box_size.y)
	_box.size = box_size
	_label.position = PADDING
	_label.size = box_size - PADDING * 2.0
	var tail_x := clampf(roundf(speaker_x - TAIL_SIZE.x / 2.0), x + 4.0, x + box_size.x - 4.0 - TAIL_SIZE.x)
	# The tail's top row overlaps the box's bottom outline (art_src/ui.px).
	_tail.position = Vector2(tail_x, BOTTOM_Y - 1.0)
	pivot_offset = Vector2(tail_x + TAIL_SIZE.x / 2.0, BOTTOM_Y)
	show()
	scale = Vector2(0.7, 0.7)
	create_tween().tween_property(self, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_typing() -> bool:
	return visible and _label.visible_characters >= 0 and _label.visible_characters < _label.get_total_character_count()


## Completes a line that is still typing; otherwise advances a line that has a hold.
func skip() -> void:
	if not visible:
		return
	if is_typing():
		_label.visible_characters = -1
	elif _hold >= 0.0:
		_advance()


func close() -> void:
	_hold = -1.0
	hide()


func _process(delta: float) -> void:
	if not visible:
		return
	if is_typing():
		_shown += delta * CHARS_PER_SECOND
		_label.visible_characters = mini(int(_shown), _label.get_total_character_count())
		return
	if _hold >= 0.0:
		_hold_left -= delta
		if _hold_left <= 0.0:
			_advance()


func _advance() -> void:
	_hold = -1.0
	advanced.emit()
