class_name SpeechBubble
extends Control
## The customer's speech bubble: a 9-slice box from the ui atlas (margins 4) with
## a tail pointing down at the speaker, text laid out line by line from
## Content.wrap_bubble() (never Godot autowrap: the data's "fits a bubble" rule is a
## character count defined by wrap_bubble, and hint words carry inline icons that a
## width-based wrap would count differently), revealed by a typewriter.
## Lives in the reading zone and takes no input itself: the shop calls skip() when
## the player taps the workspace, which first completes the line and then advances it.
##
## say(text, speaker_x, hold, hints): hold < 0 keeps the line up until skip() or
## the next say(); hold >= 0 emits `advanced` that many seconds after the line is
## complete. `hints` (a request's HintWord ids) marks every word that starts with
## one of their forms (data/SCHEMA.md "Form matching": regex \b<form>, any case)
## with its essence's icon right before it and the word in the essence's colour,
## darkened to read on the parchment: never colour alone. Each icon adds MARK_WIDTH
## to its line and the box grows to fit (test_gameplay checks that every request
## still fits the stage).
##
## While typing, `blip` fires on the 1st character and then every BLIP_EVERY
## characters (at most once a frame): the shop plays the speaker's voice on it.

signal advanced
signal blip

const CHARS_PER_SECOND := 40.0
## Characters per voice blip while typing.
const BLIP_EVERY := 3
const PADDING := Vector2(7, 5)
const LINE_SPACING := 2.0
## The box's bottom edge (the tail hangs below it, its tip just above the tallest hat at y 96).
const BOTTOM_Y := 88.0
const SIDE_MARGIN := 4.0
const TAIL_SIZE := Vector2(8, 6)
const POP_TIME := 0.16
## An inline essence icon (9x9, ui atlas) padded to this width: a pixel either side.
const MARK_WIDTH := 11
const MARK_HEIGHT := 9
## The hint word's essence colour darkened this much, for contrast on the bubble.
const MARK_DARKEN := 0.4

var text := ""
var _shown := 0.0
var _hold := -1.0
var _hold_left := 0.0
## The words marked in the current line, in order: {"word": String, "essence": int}.
var _marks: Array[Dictionary] = []

@onready var _box: NinePatchRect = $Box
@onready var _label: RichTextLabel = $Box/Text
@onready var _tail: TextureRect = $Tail


func _ready() -> void:
	var bubble := Art.texture("ui", "bubble")
	_box.texture = bubble.atlas
	_box.region_rect = bubble.region
	_tail.texture = Art.texture("ui", "bubble_tail")
	hide()


## Shows `line` above the speaker whose centre is at x = `speaker_x` (this
## Control's space) and starts typing it.
func say(line: String, speaker_x: float, hold := -1.0, hints := PackedStringArray()) -> void:
	text = line
	var lines := Content.wrap_bubble(line)
	var problem := Content.bubble_problem(line)
	if problem != "":
		push_error("[SpeechBubble] '%s': %s" % [line, problem])
	var patterns := _hint_patterns(hints)
	_marks.clear()
	_label.clear()
	var width := 0.0
	for i in lines.size():
		if i > 0:
			_label.newline()
		_add_line(lines[i], patterns)
		width = maxf(width, line_width(lines[i], hints))
	_label.visible_characters = 0
	_shown = 0.0
	_hold = hold
	_hold_left = hold
	var line_height := text_font().get_height(text_font_size()) + LINE_SPACING
	_label.add_theme_constant_override(&"line_separation", int(LINE_SPACING))
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


## The font and size the bubble's text is drawn with.
func text_font() -> Font:
	return _label.get_theme_font(&"normal_font")


func text_font_size() -> int:
	return _label.get_theme_font_size(&"normal_font_size")


## How wide wrapped line `line` draws, including the icon of every hint word of `hints` in it.
func line_width(line: String, hints := PackedStringArray()) -> float:
	var marks_in_line := 0
	for pattern in _hint_patterns(hints):
		marks_in_line += pattern.search_all(line).size()
	return text_font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, text_font_size()).x + marks_in_line * MARK_WIDTH


## The words marked in the current line, in order: {"word": String, "essence": int}.
func marks() -> Array[Dictionary]:
	return _marks.duplicate()


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
		var before := _label.visible_characters
		_shown += delta * CHARS_PER_SECOND
		_label.visible_characters = mini(int(_shown), _label.get_total_character_count())
		if blip_index(_label.visible_characters) > blip_index(before):
			blip.emit()
		return
	if _hold >= 0.0:
		_hold_left -= delta
		if _hold_left <= 0.0:
			_advance()


## Which blip `typed` characters have reached: -1 before the first character,
## then 0, 1, 2 ... every BLIP_EVERY characters.
static func blip_index(typed: int) -> int:
	return -1 if typed <= 0 else floori((typed - 1) / float(BLIP_EVERY))


## One regex per form of each hint word, matching the whole word that starts with
## the form; the word's essence index is stored in the pattern's meta "essence".
func _hint_patterns(hints: PackedStringArray) -> Array[RegEx]:
	var patterns: Array[RegEx] = []
	for id in hints:
		var word := Content.hint_word(id)
		if word == null:
			push_error("[SpeechBubble] Unknown hint word '%s'" % id)
			continue
		for form in word.forms:
			var pattern := RegEx.create_from_string("(?i)\\b%s[a-z]*" % form)
			pattern.set_meta(&"essence", word.essence)
			patterns.append(pattern)
	return patterns


## Appends `line` to the text, each hint word as its essence icon + the word in its colour.
func _add_line(line: String, patterns: Array[RegEx]) -> void:
	var found: Array[Array] = []
	for pattern in patterns:
		for hit in pattern.search_all(line):
			found.append([hit.get_start(), hit.get_end(), int(pattern.get_meta(&"essence"))])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var at := 0
	for hit in found:
		if hit[0] < at:
			continue
		var essence: int = hit[2]
		var word := line.substr(hit[0], hit[1] - hit[0])
		_label.add_text(line.substr(at, hit[0] - at))
		_label.add_image(Art.texture("ui", "essence_" + Content.ESSENCES[essence]), MARK_WIDTH, MARK_HEIGHT, Color.WHITE, INLINE_ALIGNMENT_CENTER, Rect2(), null, true)
		_label.push_color(Shop.ESSENCE_COLORS[essence].darkened(MARK_DARKEN))
		_label.add_text(word)
		_label.pop()
		_marks.append({"word": word, "essence": essence})
		at = hit[1]
	_label.add_text(line.substr(at))


func _advance() -> void:
	_hold = -1.0
	advanced.emit()
