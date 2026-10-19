class_name Grimoire
extends Control
## The Grimoire of Making (scenes/grimoire.tscn): a paged book over the title showing how
## Claude made the game. Pages: Cover (what was made and how), Pixel Art (showcase
## sprites, each beside the .px letter grid it was typed as, from the atlas sidecars),
## Sound (play every synthesised sound effect, voice and music loop), Words (how many
## lines of each kind the data holds, and a random one) and Tools (the scripts, the tests
## and CI behind it all). Every number is computed at runtime from the shipped data
## (counts()): sprites from art/*.json, sounds from GameState.SFX_IDS, the voices and
## the music tracks, lines from Content. Prev/Next turn the pages, Close (or ui_cancel)
## closes it; every control sits in the thumb zone. Opened by the title (open()).

signal closed

enum Page { COVER, PIXEL_ART, SOUND, WORDS, TOOLS }

const SCENE_PATH := "res://scenes/grimoire.tscn"
const PAGE_TITLES: Array[String] = ["Cover", "Pixel art", "Sound", "Words", "Tools"]
## Sprites the Pixel Art page shows, as [atlas, sprite]; any missing one is skipped.
const SHOWCASE: Array[Array] = [
	["ingredients", "ember_pepper"], ["ingredients", "frost_mint"], ["ingredients", "sunpetal"],
	["ingredients", "nightshade_cap"], ["ingredients", "moonmoss"], ["ingredients", "starlight_dew"],
	["brewing", "bottle_round"], ["brewing", "bottle_teardrop"], ["brewing", "cork"], ["brewing", "fire_0"],
	["ui", "essence_ember"], ["ui", "essence_frost"], ["ui", "essence_bloom"], ["ui", "essence_gloom"],
	["ui", "coin_0"], ["ui", "heart_full"], ["ui", "grade_perfect"], ["ui", "hourglass"],
	["title", "bubble_big"], ["title", "steam_puff"],
]
## The voices' files (tools/sfx.py), one per archetype.
const VOICE_PATH := "res://audio/sfx/voice_%s.wav"
## The Pixel Art page's grid: room for the letters beside the sprite, and the cell size range.
const GRID_ROOM := Vector2(176, 150)
const CELL_MIN := 4
const CELL_MAX := 9
## Potion names and tool names on the parchment (wood mid, as in the Codex).
const ACCENT := Color("#8a5a3c")
const SELECTOR_BUTTON := Vector2(36, 36)

var page := Page.COVER
## The Pixel Art page's sprite and the Sound page's sound (indices into showcase() and sounds()).
var sprite_index := 0
var sound_index := 0
## The sound last played from the Sound page ("effect tap", "voice quill", "music rush").
var played := ""
## The Words page's sample line (an index into lines()).
var line_index := 0

var _game: GameState
var _rng := RandomNumberGenerator.new()
var _lines: Array[Dictionary] = []

@onready var _column: Control = $Column
@onready var _heading: Label = $Column/Panel/List/Heading
@onready var _body: VBoxContainer = $Column/Panel/List/Body
@onready var _prev_button: Button = $Column/Panel/List/Footer/PrevButton
@onready var _page_label: Label = $Column/Panel/List/Footer/Page
@onready var _next_button: Button = $Column/Panel/List/Footer/NextButton
@onready var _close_button: Button = $Column/Panel/List/Footer/CloseButton


## Opens a Grimoire on top of `host` (added as its last child) and returns it. `behind`
## (the host's own controls) takes no keyboard focus while it is open.
static func open(host: Node, behind: Control) -> Grimoire:
	var book := (load(SCENE_PATH) as PackedScene).instantiate() as Grimoire
	behind.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	book.closed.connect(func() -> void: behind.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED)
	host.add_child(book)
	return book


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	_rng.randomize()
	_lines = lines()
	line_index = _rng.randi_range(0, maxi(0, _lines.size() - 1))
	_prev_button.pressed.connect(turn.bind(-1))
	_next_button.pressed.connect(turn.bind(1))
	_close_button.pressed.connect(close)
	_render()
	Juice.squash($Column/Panel, 0.08)
	_game.sfx(&"codex_open")
	_next_button.grab_focus(true)
	print("[Grimoire] Opened: %s" % counts())


## Turns `step` pages (no wrap).
func turn(step: int) -> void:
	var to := clampi(page + step, 0, PAGE_TITLES.size() - 1)
	if to == page:
		return
	page = to as Page
	_render()
	Juice.squash(_body, 0.06)
	_game.sfx(&"page_flip")
	print("[Grimoire] Page %d/%d: %s" % [page + 1, PAGE_TITLES.size(), PAGE_TITLES[page]])


func close() -> void:
	# A loop played from the Sound page gives way to the screen's own music.
	_game.play_music(GameState.track_for(_game.state, _game.flow_args))
	print("[Grimoire] Closed")
	closed.emit()
	queue_free()


## The numbers the pages show, all counted from the shipped data: sprites and atlases
## (art/*.json sidecars), palette colours, sound effects (GameState.SFX_IDS with a file),
## voices (one file per archetype), music loops (the flow's tracks with a file) and lines
## of text per kind (lines(); "lines" is their total).
static func counts() -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	var atlases := Art.atlases()
	var sprites := 0
	for atlas in atlases:
		sprites += Art.sprite_names(atlas).size()
	result["atlases"] = atlases.size()
	result["sprites"] = sprites
	result["palette"] = Art.palette(atlases[0]).size() if not atlases.is_empty() else 0
	for kind: String in ["effect", "voice", "music"]:
		result[kind] = 0
	for sound in sounds():
		result[sound["kind"]] += 1
	result["lines"] = 0
	for line in lines():
		var kind: String = line["kind"]
		result[kind] = result.get(kind, 0) + 1
		result["lines"] += 1
	result["hint words"] = Content.hint_words().size()
	return result


## Every sound the Sound page can play, in order: the sound effects (GameState.SFX_IDS),
## the voices (one per archetype) and the music loops (GameState.MUSIC_TRACKS, each
## once); only those whose file ships. Each {"kind": "effect" | "voice" | "music", "id"}.
static func sounds() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for id in GameState.SFX_IDS:
		if ResourceLoader.exists(GameState.SFX_PATH % id):
			list.append({"kind": "effect", "id": str(id)})
	for who in Content.archetypes():
		if ResourceLoader.exists(VOICE_PATH % who.id):
			list.append({"kind": "voice", "id": who.id})
	var tracks: Array[StringName] = []
	for state: GameState.Flow in GameState.MUSIC_TRACKS:
		var track: StringName = GameState.MUSIC_TRACKS[state]
		if not track in tracks:
			tracks.append(track)
	if not &"rush" in tracks:
		tracks.append(&"rush")
	for track in tracks:
		if ResourceLoader.exists(GameState.MUSIC_PATH % track):
			list.append({"kind": "music", "id": str(track)})
	return list


## Every line of text the game says, from Content, each {"kind", "text"}: customer
## requests, reactions, misbrew mishaps, story beat lines, morning cards and ending pages.
static func lines() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for request in Content.requests():
		list.append({"kind": "requests", "text": request.text})
	for who in Content.archetypes():
		for grade in who.reactions:
			for text in who.reactions[grade]:
				list.append({"kind": "reactions", "text": text})
	for misbrew in Content.misbrews():
		list.append({"kind": "misbrews", "text": misbrew.text})
	for day in Content.days():
		if day.morning_note != "":
			list.append({"kind": "mornings", "text": day.morning_note})
		for note in day.morning_notes:
			list.append({"kind": "mornings", "text": str(note["text"])})
		for visit in day.customers:
			for outcome in visit.lines:
				list.append({"kind": "beats", "text": visit.lines[outcome]})
	for ending in Content.endings():
		for text in ending.pages:
			list.append({"kind": "endings", "text": text})
	return list


## The Pixel Art page's sprites: SHOWCASE entries whose atlas and sprite ship.
static func showcase() -> Array[PackedStringArray]:
	var list: Array[PackedStringArray] = []
	var atlases := Art.atlases()
	for entry in SHOWCASE:
		var atlas: String = entry[0]
		if atlas in atlases and Art.sprite_names(atlas).has(entry[1]):
			list.append(PackedStringArray(entry))
	return list


## Selects showcase sprite `index` (wrapping) on the Pixel Art page.
func show_sprite(index: int) -> void:
	var list := showcase()
	sprite_index = posmod(index, maxi(1, list.size()))
	_render()


## Selects sound `index` (wrapping) on the Sound page and plays it.
func pick_sound(index: int) -> void:
	sound_index = posmod(index, maxi(1, sounds().size()))
	_render()
	play_sound()


## Plays the Sound page's sound on its usual bus: an effect or a voice on SFX, a loop as
## the music (until the Grimoire closes).
func play_sound() -> void:
	var list := sounds()
	if list.is_empty():
		return
	var sound := list[sound_index]
	var id: String = sound["id"]
	match sound["kind"]:
		"effect":
			_game.sfx(StringName(id))
		"voice":
			_game.play_sfx(load(VOICE_PATH % id) as AudioStream)
		"music":
			_game.play_music(StringName(id))
	played = "%s %s" % [sound["kind"], id]
	print("[Grimoire] Played %s" % played)


## Shows another random line on the Words page.
func another_line() -> void:
	if _lines.size() > 1:
		line_index = (line_index + _rng.randi_range(1, _lines.size() - 1)) % _lines.size()
	_render()


## The texts on the open page (tests read them).
func page_texts() -> PackedStringArray:
	var texts := PackedStringArray([_heading.text])
	for label in _body.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return texts


func _render() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_heading.text = PAGE_TITLES[page]
	match page:
		Page.COVER:
			_render_cover()
		Page.PIXEL_ART:
			_render_pixel_art()
		Page.SOUND:
			_render_sound()
		Page.WORDS:
			_render_words()
		Page.TOOLS:
			_render_tools()
	_page_label.text = "Page %d/%d" % [page + 1, PAGE_TITLES.size()]
	_page_label.accessibility_name = "%s, page %d of %d" % [PAGE_TITLES[page], page + 1, PAGE_TITLES.size()]
	_prev_button.disabled = page == 0
	_next_button.disabled = page == PAGE_TITLES.size() - 1
	# A page button that just ran out of pages hands the focus to the other one.
	var focused := get_viewport().gui_get_focus_owner() as BaseButton
	if focused != null and focused.disabled:
		(_prev_button if focused == _next_button else _next_button).grab_focus(true)


func _render_cover() -> void:
	var numbers := counts()
	var logo := TextureRect.new()
	logo.texture = Art.texture("title", "logo")
	logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(logo)
	_body.add_child(_label("Claude, an AI, made BrewMagic as code and text: every sprite, sound, tune and line. A person set the goals, reviewed every step and played it."))
	for fact: String in [
		"%d sprites in %d atlases, typed as letter grids" % [numbers["sprites"], numbers["atlases"]],
		"%d sound effects and %d voices, synthesised" % [numbers["effect"], numbers["voice"]],
		"%d music loops, composed note by note in code" % numbers["music"],
		"%d lines of shop talk, written as data" % numbers["lines"],
	]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_icon(Art.texture("ui", "grade_perfect"), Vector2(9, 9)))
		var text := _label(fact)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		_body.add_child(row)
	_body.add_child(_label("Turn the page to see how."))


func _render_pixel_art() -> void:
	var numbers := counts()
	_body.add_child(_label("%d sprites in %d atlases, one palette of %d colours. Each is typed as letters, one per colour (\".\" is clear), for tools/pixelart.py to compile." % [numbers["sprites"], numbers["atlases"], numbers["palette"]]))
	var list := showcase()
	if list.is_empty():
		_body.add_child(_label("No sprites ship with this build."))
		return
	var entry := list[sprite_index]
	var source := Art.rows(entry[0], entry[1])
	var texture := Art.texture(entry[0], entry[1])
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, GRID_ROOM.y)
	var view := TextureRect.new()
	view.texture = texture
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size = texture.get_size() * (3.0 if texture.get_size().x <= 12.0 else 2.0)
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(view)
	var grid := SourceGrid.new()
	var width := source[0].length() if not source.is_empty() else 1
	var cell := clampi(mini(floori(GRID_ROOM.x / width), floori(GRID_ROOM.y / maxi(1, source.size()))), CELL_MIN, CELL_MAX)
	grid.show_rows(source, Art.palette(entry[0]), cell)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(grid)
	_body.add_child(row)
	var colours := Art.colors(entry[0], entry[1]).size()
	var caption := _label("%s, %dx%d, %d colours" % [entry[1], int(texture.get_size().x), int(texture.get_size().y), colours], HORIZONTAL_ALIGNMENT_CENTER)
	caption.accessibility_name = "%s from %s.png, %d by %d pixels, %d colours" % [entry[1], entry[0], int(texture.get_size().x), int(texture.get_size().y), colours]
	_body.add_child(caption)
	_body.add_child(_spacer())
	_body.add_child(_selector("Sprite %d of %d" % [sprite_index + 1, list.size()], "sprite",
		show_sprite.bind(sprite_index - 1), show_sprite.bind(sprite_index + 1)))


func _render_sound() -> void:
	var numbers := counts()
	_body.add_child(_label("%d sound effects, %d customer voices and %d music loops. No recordings: tools/sfx.py and tools/music.py build every one from plain waves and noise, the same bytes every run." % [numbers["effect"], numbers["voice"], numbers["music"]]))
	var list := sounds()
	if list.is_empty():
		_body.add_child(_label("No sounds ship with this build."))
		return
	var sound := list[sound_index]
	var kind: String = sound["kind"]
	var of_kind := list.filter(func(entry: Dictionary) -> bool: return entry["kind"] == kind)
	var place := of_kind.find(sound) + 1
	var title := _label({"effect": "Sound effect", "voice": "Voice", "music": "Music loop"}[kind] + " %d of %d" % [place, of_kind.size()], HORIZONTAL_ALIGNMENT_CENTER)
	_body.add_child(title)
	var name_label := _label(str(sound["id"]).replace("_", " "), HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_color_override(&"font_color", ACCENT)
	name_label.add_theme_font_size_override(&"font_size", 25)
	_body.add_child(name_label)
	_body.add_child(_label(_sound_note(kind, str(sound["id"])), HORIZONTAL_ALIGNMENT_CENTER))
	var silent := _game.music_silent() if kind == "music" else _game.sfx_silent()
	if silent:
		_body.add_child(_label("(%s muted in Settings)" % ("Music is" if kind == "music" else "Sounds are"), HORIZONTAL_ALIGNMENT_CENTER))
	_body.add_child(_spacer())
	var row := _selector("", "sound", pick_sound.bind(sound_index - 1), pick_sound.bind(sound_index + 1))
	var play := _button("PlayButton", "Play", Vector2(96, 36), "Play %s" % str(sound["id"]).replace("_", " "))
	play.pressed.connect(play_sound)
	row.add_child(play)
	row.move_child(play, 1)
	# These buttons play the sound they pick, never the generic tap over it.
	for button in row.get_children():
		button.add_to_group(GameState.OWN_SOUND_GROUP)
	_body.add_child(row)


func _render_words() -> void:
	var numbers := counts()
	_body.add_child(_label("All written by Claude into data/*.json; a test checks each line fits its bubble."))
	var table := GridContainer.new()
	table.columns = 2
	table.add_theme_constant_override(&"h_separation", 12)
	table.add_theme_constant_override(&"v_separation", 0)
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry: Array in [["Customer requests", "requests"], ["Reactions", "reactions"], ["Misbrew mishaps", "misbrews"],
			["Story beat lines", "beats"], ["Morning cards", "mornings"], ["Ending pages", "endings"], ["Hint words", "hint words"]]:
		var what := _label(entry[0])
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table.add_child(what)
		table.add_child(_number(str(numbers.get(entry[1], 0))))
	var total := _label("All told")
	total.add_theme_color_override(&"font_color", ACCENT)
	table.add_child(total)
	var total_count := _number("%d lines" % numbers["lines"])
	total_count.add_theme_color_override(&"font_color", ACCENT)
	table.add_child(total_count)
	_body.add_child(table)
	if not _lines.is_empty():
		var line := _lines[clampi(line_index, 0, _lines.size() - 1)]
		var sample := _label("\"%s\"" % line["text"])
		sample.add_theme_color_override(&"font_color", ACCENT)
		_body.add_child(sample)
		_body.add_child(_label("(one of the %s)" % _kind_name(line["kind"]), HORIZONTAL_ALIGNMENT_RIGHT))
	_body.add_child(_spacer())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var another := _button("AnotherButton", "Another", Vector2(130, 36), "Show another line")
	another.pressed.connect(another_line)
	row.add_child(another)
	_body.add_child(row)


func _render_tools() -> void:
	var numbers := counts()
	for entry: Array in [
		["tools/pixelart.py", "Letters to pixels: compiles the grids into %d atlases, refusing any colour off the palette." % numbers["atlases"]],
		["tools/sfx.py", "A tiny synth: each sound and voice from sine, square and noise, the same bytes every run."],
		["tools/music.py", "Music-box folk: %d loops on one motif, each checked to loop without a seam." % numbers["music"]],
		["Tests", "Headless Godot plays it with synthetic taps and keys, and checks the one-thumb rules."],
		["CI", "Every push runs the checks, the web export and a browser test on desktop and phone."],
	]:
		var name_label := _label(entry[0])
		name_label.add_theme_color_override(&"font_color", ACCENT)
		_body.add_child(name_label)
		_body.add_child(_label(entry[1]))


## A row of a "<" button, an optional middle label and a ">" button (SELECTOR_BUTTON
## each), named "<what>Prev" / "<what>Next" in PascalCase.
func _selector(middle: String, what: String, on_prev: Callable, on_next: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	var prefix := what.to_pascal_case()
	var prev := _button(prefix + "Prev", "<", SELECTOR_BUTTON, "Previous %s" % what)
	prev.pressed.connect(on_prev)
	row.add_child(prev)
	if middle != "":
		var label := _label(middle, HORIZONTAL_ALIGNMENT_CENTER)
		label.custom_minimum_size = Vector2(110, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(label)
	var next := _button(prefix + "Next", ">", SELECTOR_BUTTON, "Next %s" % what)
	next.pressed.connect(on_next)
	row.add_child(next)
	return row


func _button(node_name: String, text: String, min_size: Vector2, accessible: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = min_size
	button.accessibility_name = accessible
	return button


## Pushes what follows to the bottom of the page (the thumb zone).
func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _label(text: String, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"DarkLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1, 0)
	return label


## A right-aligned count that never wraps.
func _number(text: String) -> Label:
	var label := _label(text, HORIZONTAL_ALIGNMENT_RIGHT)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _icon(texture: Texture2D, icon_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## What a sound is: an effect's file, whose voice a blip is, where a loop plays.
static func _sound_note(kind: String, id: String) -> String:
	match kind:
		"voice":
			var who := Content.archetype(id)
			return "The voice blip of %s, typed out letter by letter" % (who.name if who != null else id)
		"music":
			var places := PackedStringArray()
			for state: GameState.Flow in GameState.MUSIC_TRACKS:
				if GameState.MUSIC_TRACKS[state] == StringName(id):
					places.append(str(GameState.Flow.keys()[state]).to_lower())
			if id == "rush":
				places.append("rush hour")
			return "Plays on: %s" % ", ".join(places)
	return "audio/sfx/%s.wav" % id


static func _kind_name(kind: String) -> String:
	return str({"requests": "customer requests", "reactions": "reactions", "misbrews": "misbrew mishaps",
		"beats": "story beat lines", "mornings": "morning cards", "endings": "ending pages"}.get(kind, kind))


func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size


## A sprite's .px source drawn as a chart: each letter on a cell of its palette colour
## (light letters on dark colours and the reverse), "." on the bare parchment.
class SourceGrid extends Control:
	const CHARS := "0123456789abcdefghijklmnopqrstuv"
	const INK := Color("#1c1420")
	const CREAM := Color("#fbedcd")
	const FAINT := Color(0.11, 0.078, 0.125, 0.35)

	var rows := PackedStringArray()
	var palette := PackedStringArray()
	var cell := 6

	func show_rows(source: PackedStringArray, colours: PackedStringArray, cell_size: int) -> void:
		rows = source
		palette = colours
		cell = cell_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2((rows[0].length() if not rows.is_empty() else 0) * cell, rows.size() * cell)
		queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		var font_size := cell + 2
		for y in rows.size():
			for x in rows[y].length():
				var letter := rows[y][x]
				var box := Rect2(Vector2(x, y) * cell, Vector2(cell, cell))
				var index := CHARS.find(letter)
				var ink := FAINT
				if index >= 0 and index < palette.size():
					var colour := Color(palette[index])
					draw_rect(box, colour)
					ink = INK if colour.get_luminance() > 0.5 else CREAM
				draw_string(font, Vector2(box.position.x, box.end.y - 1), letter, HORIZONTAL_ALIGNMENT_CENTER, cell, font_size, ink)
