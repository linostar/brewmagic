class_name Content
extends RefCounted
## All game content: the JSON in res://data/ parsed into typed resources, strictly per
## data/SCHEMA.md. Static only. The data is loaded once, lazily, on the first call of any
## public function (the title screen's errors() call does it at boot); reload() and
## load_texts() replace it (tests).
## Every problem (unreadable file, bad JSON, a file with no entries, missing or unknown key,
## wrong type, non-integer int, out-of-range value, duplicate id, unknown cross-reference) is
## collected in errors() as "data/<file> [<entry id>] <field>: <problem>" and reported with
## push_error, all of them, not just the first. Entries with problems are still loaded as
## far as they parse (bad fields keep their resource defaults), and the title screen keeps the shop closed
## while errors() is non-empty. Cross-file invariants (solvability, hint fairness, coverage)
## are checked by tools/test_content.gd.

const DATA_DIR := "res://data/"
## Load order: each file only references files loaded before it, except
## vocabulary.request_ids, which is checked once requests.json is loaded.
const FILES: Array[String] = [
	"ingredients.json", "potions.json", "vocabulary.json", "archetypes.json",
	"requests.json", "misbrews.json", "days.json", "upgrades.json",
]
## Essence names in Vector4i component order.
const ESSENCES: Array[String] = ["ember", "frost", "bloom", "gloom"]
## The misbrew effect of each essence, same order as ESSENCES.
const MISBREW_EFFECTS: Array[String] = ["singed", "frosted", "sprouting", "gloomy"]
const BOTTLES: Array[String] = ["round", "tall", "flask", "teardrop"]
const STEPS: Array[String] = ["stir", "pour", "mortar", "bellows"]
const TIMBRES: Array[String] = ["reed", "bell", "growl", "chirp"]
const BODIES: Array[String] = ["robe", "apron", "armour"]
const HEADS: Array[String] = ["round", "long", "square"]
const HAIRS: Array[String] = ["witch_hat", "straw_hat", "curly", "bald_beard"]
const ACCESSORIES: Array[String] = ["none", "goat", "lantern"]
const FIRST_DAY := 1
const LAST_DAY := 7
const NAME_MAX := 26
const DESCRIPTION_MAX := 120
const SPEECH_STYLE_MAX := 200
const INGREDIENT_ESSENCE_MAX := 3
const TARGET_ESSENCE_MAX := 9
const PRICE_MAX := 999
const COINS_MAX := 9999
const STOCK_MAX := 99
## Upgrade tolerance multipliers lie in (1, UPGRADE_TOLERANCE_MAX].
const UPGRADE_TOLERANCE_MAX := 3.0
const MIN_REACTION_LINES := 3
## Speech bubble: greedy word wrap at BUBBLE_COLUMNS characters, at most BUBBLE_LINES lines.
const BUBBLE_COLUMNS := 26
const BUBBLE_LINES := 3

## Tests set quiet_errors to assert on expected errors (load errors and unknown-id lookups)
## without failing the log check.
static var quiet_errors := false

static var _loaded := false
static var _errors: Array[String] = []
static var _ingredients: Dictionary[String, Ingredient] = {}
static var _potions: Dictionary[String, PotionType] = {}
static var _hint_words: Dictionary[String, HintWord] = {}
static var _archetypes: Dictionary[String, Archetype] = {}
static var _requests: Dictionary[String, RequestLine] = {}
static var _misbrews: Dictionary[String, MisbrewLine] = {}
static var _days: Dictionary[int, DaySpec] = {}
static var _upgrades: Dictionary[String, Upgrade] = {}
## The file and entry the loader is reading, for error messages.
static var _file := ""
static var _entry := ""
static var _snake_case := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
static var _hex_color := RegEx.create_from_string("^#[0-9a-f]{6}$")
static var _lowercase_word := RegEx.create_from_string("^[a-z]+$")


## Every content problem found by the last load, oldest first. Empty means the data is valid.
static func errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


## Reads every file in FILES from DATA_DIR and replaces the loaded content.
static func reload() -> void:
	_reset()
	var texts: Dictionary[String, String] = {}
	for file in FILES:
		var text := FileAccess.get_file_as_string(DATA_DIR + file)
		var open_error := FileAccess.get_open_error()
		if open_error != OK:
			_begin_file(file)
			_error("(file)", "cannot be read: %s" % error_string(open_error))
			continue
		texts[file] = text
	_load(texts)


## Replaces the loaded content with `texts` (file name in FILES -> JSON text). Tests use it
## to feed malformed data; a file missing from `texts` is reported as missing.
static func load_texts(texts: Dictionary[String, String]) -> void:
	_reset()
	for file in FILES:
		if not texts.has(file):
			_begin_file(file)
			_error("(file)", "missing")
	_load(texts)


static func ingredient(id: String) -> Ingredient:
	_ensure_loaded()
	return _lookup(_ingredients, id, "ingredient") as Ingredient


static func potion(id: String) -> PotionType:
	_ensure_loaded()
	return _lookup(_potions, id, "potion") as PotionType


static func hint_word(id: String) -> HintWord:
	_ensure_loaded()
	return _lookup(_hint_words, id, "hint word") as HintWord


static func archetype(id: String) -> Archetype:
	_ensure_loaded()
	return _lookup(_archetypes, id, "archetype") as Archetype


static func request(id: String) -> RequestLine:
	_ensure_loaded()
	return _lookup(_requests, id, "request") as RequestLine


## The spec of story day `number`, or null (with push_error) if there is none.
static func day(number: int) -> DaySpec:
	_ensure_loaded()
	if not _days.has(number):
		if not quiet_errors:
			push_error("[Content] Unknown day %d" % number)
		return null
	return _days[number]


## Every ingredient, in file order.
static func ingredients() -> Array[Ingredient]:
	_ensure_loaded()
	var result: Array[Ingredient] = []
	result.assign(_ingredients.values())
	return result


## Every potion, in file order.
static func potions() -> Array[PotionType]:
	_ensure_loaded()
	var result: Array[PotionType] = []
	result.assign(_potions.values())
	return result


## Every hint word, in file order.
static func hint_words() -> Array[HintWord]:
	_ensure_loaded()
	var result: Array[HintWord] = []
	result.assign(_hint_words.values())
	return result


## Every archetype, in file order.
static func archetypes() -> Array[Archetype]:
	_ensure_loaded()
	var result: Array[Archetype] = []
	result.assign(_archetypes.values())
	return result


## Every request, in file order.
static func requests() -> Array[RequestLine]:
	_ensure_loaded()
	var result: Array[RequestLine] = []
	result.assign(_requests.values())
	return result


## Every misbrew line, in file order.
static func misbrews() -> Array[MisbrewLine]:
	_ensure_loaded()
	var result: Array[MisbrewLine] = []
	result.assign(_misbrews.values())
	return result


## Every story day, in day order.
static func days() -> Array[DaySpec]:
	_ensure_loaded()
	var numbers := _days.keys()
	numbers.sort()
	var result: Array[DaySpec] = []
	for number: int in numbers:
		result.append(_days[number])
	return result


## Every upgrade, in file order.
static func upgrades() -> Array[Upgrade]:
	_ensure_loaded()
	var result: Array[Upgrade] = []
	result.assign(_upgrades.values())
	return result


## The upgrade of station step `station` ("stir", ...), or null (with push_error) if there is none.
static func upgrade_for(station: String) -> Upgrade:
	_ensure_loaded()
	for item: Upgrade in _upgrades.values():
		if item.station == station:
			return item
	if not quiet_errors:
		push_error("[Content] No upgrade for station '%s'" % station)
	return null


## The requests written for `potion_id` in the voice of `archetype_id`, in file order.
static func requests_for(potion_id: String, archetype_id: String) -> Array[RequestLine]:
	_ensure_loaded()
	var result: Array[RequestLine] = []
	for line: RequestLine in _requests.values():
		if line.potion == potion_id and line.archetype == archetype_id:
			result.append(line)
	return result


## The misbrew lines for the overshooting essence (index into ESSENCES), in file order.
static func misbrews_for(essence: int) -> Array[MisbrewLine]:
	_ensure_loaded()
	var result: Array[MisbrewLine] = []
	for line: MisbrewLine in _misbrews.values():
		if line.essence == essence:
			result.append(line)
	return result


## The ingredients on sale on day `number` (unlock_day <= number), in file order.
static func ingredients_unlocked_by(number: int) -> Array[Ingredient]:
	var result: Array[Ingredient] = []
	for item in ingredients():
		if item.unlock_day <= number:
			result.append(item)
	return result


## The potions customers may ask for on day `number` (unlock_day <= number), in file order.
static func potions_unlocked_by(number: int) -> Array[PotionType]:
	var result: Array[PotionType] = []
	for item in potions():
		if item.unlock_day <= number:
			result.append(item)
	return result


## Greedy word wrap of a speech bubble line: words (split on spaces) are joined by one
## space, and a word that would push a line past BUBBLE_COLUMNS starts the next line.
## A single word longer than BUBBLE_COLUMNS stays whole on its own line.
static func wrap_bubble(text: String) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word: String in text.split(" ", false):
		if line.is_empty():
			line = word
		elif line.length() + 1 + word.length() <= BUBBLE_COLUMNS:
			line += " " + word
		else:
			lines.append(line)
			line = word
	if not line.is_empty():
		lines.append(line)
	return lines


## Why `text` does not fit a speech bubble, or "" if it fits (data/SCHEMA.md "Speech bubble limit").
static func bubble_problem(text: String) -> String:
	if text.strip_edges().is_empty():
		return "bubble text is empty"
	if "\n" in text or "\r" in text:
		return "bubble text contains a newline"
	if text.length() > BUBBLE_COLUMNS * BUBBLE_LINES:
		return "bubble text is %d characters (max %d)" % [text.length(), BUBBLE_COLUMNS * BUBBLE_LINES]
	for word: String in text.split(" ", false):
		if word.length() > BUBBLE_COLUMNS:
			return "bubble word '%s' is %d characters (max %d)" % [word, word.length(), BUBBLE_COLUMNS]
	var line_count := wrap_bubble(text).size()
	if line_count > BUBBLE_LINES:
		return "bubble text wraps to %d lines (max %d)" % [line_count, BUBBLE_LINES]
	return ""


static func _ensure_loaded() -> void:
	if not _loaded:
		reload()


static func _reset() -> void:
	_loaded = true
	_errors.clear()
	_ingredients.clear()
	_potions.clear()
	_hint_words.clear()
	_archetypes.clear()
	_requests.clear()
	_misbrews.clear()
	_days.clear()
	_upgrades.clear()


static func _load(texts: Dictionary[String, String]) -> void:
	for file in FILES:
		# A file absent from `texts` was already reported by reload() or load_texts().
		if not texts.has(file):
			continue
		_begin_file(file)
		var entries := _parse_entries(texts[file])
		match file:
			"ingredients.json":
				_load_ingredients(entries)
			"potions.json":
				_load_potions(entries)
			"vocabulary.json":
				_load_vocabulary(entries)
			"archetypes.json":
				_load_archetypes(entries)
			"requests.json":
				_load_requests(entries)
				_check_vocabulary_request_ids()
			"misbrews.json":
				_load_misbrews(entries)
			"days.json":
				_load_days(entries)
			"upgrades.json":
				_load_upgrades(entries)
	print("[Content] Loaded %d ingredients, %d potions, %d hint words, %d archetypes, %d requests, %d misbrews, %d days, %d upgrades: %d problem(s)" % [
		_ingredients.size(), _potions.size(), _hint_words.size(), _archetypes.size(),
		_requests.size(), _misbrews.size(), _days.size(), _upgrades.size(), _errors.size()])


static func _load_ingredients(entries: Array[Dictionary]) -> void:
	for entry in entries:
		var item := Ingredient.new()
		item.id = _begin_entry(entry, ["id", "name", "essence", "unlock_day", "base_price", "grind", "description"], [], _ingredients)
		item.name = _string(entry, "name", NAME_MAX)
		item.essence = _essence(entry, "essence", INGREDIENT_ESSENCE_MAX)
		if entry.has("essence") and item.essence == Vector4i.ZERO:
			_error("essence", "all essences are 0")
		item.unlock_day = _int(entry, "unlock_day", FIRST_DAY, LAST_DAY)
		item.base_price = _int(entry, "base_price", 1, PRICE_MAX)
		item.grind = _bool(entry, "grind")
		item.description = _string(entry, "description", DESCRIPTION_MAX)
		if item.id != "":
			_ingredients[item.id] = item


static func _load_potions(entries: Array[Dictionary]) -> void:
	for entry in entries:
		var item := PotionType.new()
		item.id = _begin_entry(entry, ["id", "name", "target", "color", "bottle", "unlock_day", "steps", "price", "description"], [], _potions)
		item.name = _string(entry, "name", NAME_MAX)
		item.target = _essence(entry, "target", TARGET_ESSENCE_MAX)
		var color := _string(entry, "color", 7)
		if color != "":
			if _hex_color.search(color) == null:
				_error("color", "'%s' is not #rrggbb in lowercase hex" % color)
			else:
				item.color = Color.html(color)
		item.bottle = _enum(entry, "bottle", BOTTLES)
		item.unlock_day = _int(entry, "unlock_day", FIRST_DAY, LAST_DAY)
		item.steps = _strings(entry, "steps")
		for i in item.steps.size():
			if not item.steps[i] in STEPS:
				_error("steps[%d]" % i, "'%s' is not one of %s" % [item.steps[i], STEPS])
			elif item.steps.find(item.steps[i]) != i:
				_error("steps[%d]" % i, "'%s' is repeated" % item.steps[i])
		item.price = _int(entry, "price", 1, PRICE_MAX)
		item.description = _string(entry, "description", DESCRIPTION_MAX)
		if item.id != "":
			_potions[item.id] = item


static func _load_vocabulary(entries: Array[Dictionary]) -> void:
	for entry in entries:
		var item := HintWord.new()
		item.id = _begin_entry(entry, ["id", "word", "essence", "forms", "request_ids"], [], _hint_words)
		if item.id != "" and not item.id.begins_with("hint_"):
			_error("id", "'%s' does not start with 'hint_'" % item.id)
		item.word = _string(entry, "word", NAME_MAX)
		item.essence = maxi(0, ESSENCES.find(_enum(entry, "essence", ESSENCES)))
		item.forms = _strings(entry, "forms")
		for i in item.forms.size():
			if _lowercase_word.search(item.forms[i]) == null:
				_error("forms[%d]" % i, "'%s' is not lowercase letters only" % item.forms[i])
		# Each id is checked against requests.json once it is loaded.
		item.request_ids = _strings(entry, "request_ids", false)
		if item.id != "":
			_hint_words[item.id] = item


static func _load_archetypes(entries: Array[Dictionary]) -> void:
	for entry in entries:
		var item := Archetype.new()
		item.id = _begin_entry(entry, ["id", "name", "patience_seconds", "tip_tendency", "voice", "speech_style", "parts", "reactions"], [], _archetypes)
		item.name = _string(entry, "name", NAME_MAX)
		item.patience_seconds = _int(entry, "patience_seconds", 10, 300)
		item.tip_tendency = _float(entry, "tip_tendency", 0.0, 1.0)
		var voice := _object(entry, "voice", ["pitch", "timbre"])
		item.voice_pitch = _float(voice, "pitch", 0.5, 2.0, "voice.")
		item.voice_timbre = _enum(voice, "timbre", TIMBRES, "voice.")
		item.speech_style = _string(entry, "speech_style", SPEECH_STYLE_MAX)
		var parts := _object(entry, "parts", ["body", "head", "hair", "accessory"])
		item.part_body = _enum(parts, "body", BODIES, "parts.")
		item.part_head = _enum(parts, "head", HEADS, "parts.")
		item.part_hair = _enum(parts, "hair", HAIRS, "parts.")
		item.part_accessory = _enum(parts, "accessory", ACCESSORIES, "parts.")
		var reactions := _object(entry, "reactions", Archetype.GRADES)
		for grade in Archetype.GRADES:
			if not reactions.has(grade):
				continue
			var lines := _strings(reactions, grade, false, "reactions.")
			if lines.size() < MIN_REACTION_LINES and typeof(reactions[grade]) == TYPE_ARRAY:
				_error("reactions." + grade, "has %d lines (min %d)" % [lines.size(), MIN_REACTION_LINES])
			for i in lines.size():
				_bubble(lines[i], "reactions.%s[%d]" % [grade, i])
			item.reactions[grade] = lines
		if item.id != "":
			_archetypes[item.id] = item


static func _load_requests(entries: Array[Dictionary]) -> void:
	for entry in entries:
		var item := RequestLine.new()
		item.id = _begin_entry(entry, ["id", "potion", "archetype", "hints", "text"], [], _requests)
		item.potion = _reference(entry, "potion", _potions, "potion")
		item.archetype = _reference(entry, "archetype", _archetypes, "archetype")
		if item.id != "" and item.potion != "" and item.archetype != "":
			var prefix := "%s_%s_" % [item.potion.get_slice("_", 0), item.archetype]
			if not (item.id.begins_with(prefix) and item.id.trim_prefix(prefix).is_valid_int()):
				_error("id", "'%s' is not %s<n>" % [item.id, prefix])
		item.hints = _strings(entry, "hints")
		for i in item.hints.size():
			if not _hint_words.has(item.hints[i]):
				_error("hints[%d]" % i, "unknown hint word id '%s'" % item.hints[i])
			elif item.hints.find(item.hints[i]) != i:
				_error("hints[%d]" % i, "'%s' is repeated" % item.hints[i])
		item.text = _string(entry, "text", BUBBLE_COLUMNS * BUBBLE_LINES, "", false)
		_bubble(item.text, "text")
		if item.id != "":
			_requests[item.id] = item


static func _check_vocabulary_request_ids() -> void:
	_begin_file("vocabulary.json")
	for item: HintWord in _hint_words.values():
		_entry = item.id
		for i in item.request_ids.size():
			if not _requests.has(item.request_ids[i]):
				_error("request_ids[%d]" % i, "unknown request id '%s'" % item.request_ids[i])


static func _load_misbrews(entries: Array[Dictionary]) -> void:
	for entry in entries:
		var item := MisbrewLine.new()
		item.id = _begin_entry(entry, ["id", "essence", "effect", "text"], [], _misbrews)
		var essence_name := _enum(entry, "essence", ESSENCES)
		item.essence = maxi(0, ESSENCES.find(essence_name))
		if item.id != "" and essence_name != "":
			var prefix := "misbrew_%s_" % essence_name
			if not (item.id.begins_with(prefix) and item.id.trim_prefix(prefix).is_valid_int()):
				_error("id", "'%s' is not %s<n>" % [item.id, prefix])
		item.effect = _enum(entry, "effect", MISBREW_EFFECTS)
		if item.effect != "" and essence_name != "" and item.effect != MISBREW_EFFECTS[item.essence]:
			_error("effect", "'%s' must be '%s' for essence %s" % [item.effect, MISBREW_EFFECTS[item.essence], essence_name])
		item.text = _string(entry, "text", BUBBLE_COLUMNS * BUBBLE_LINES, "", false)
		_bubble(item.text, "text")
		if item.id != "":
			_misbrews[item.id] = item


static func _load_days(entries: Array[Dictionary]) -> void:
	var seen_ids: Dictionary[String, DaySpec] = {}
	for entry in entries:
		var item := DaySpec.new()
		item.id = _begin_entry(entry, ["id", "day", "title", "morning_note", "patience_scale", "customers"], ["starting_coins", "starting_stock", "market"], seen_ids)
		item.day = _int(entry, "day", FIRST_DAY, LAST_DAY)
		if item.id != "" and entry.has("day") and item.id != "day_%d" % item.day:
			_error("id", "'%s' does not match day %d" % [item.id, item.day])
		item.title = _string(entry, "title", NAME_MAX)
		item.morning_note = _string(entry, "morning_note", BUBBLE_COLUMNS * BUBBLE_LINES, "", false)
		_bubble(item.morning_note, "morning_note")
		item.patience_scale = _float(entry, "patience_scale", 0.25, 3.0)
		var first := item.day == FIRST_DAY
		for key: String in ["starting_coins", "starting_stock", "market"]:
			var allowed := first != (key == "market")
			if allowed and not entry.has(key):
				_error(key, "missing key (required on %s)" % ("day 1" if first else "days >= 2"))
			elif not allowed and entry.has(key):
				_error(key, "only allowed on %s" % ("days >= 2" if first else "day 1"))
		if first:
			item.starting_coins = _int(entry, "starting_coins", 0, COINS_MAX)
			var stock := _object(entry, "starting_stock", [])
			for id: String in stock:
				if _ingredient_unlocked(id, item.day, "starting_stock." + id):
					item.starting_stock[id] = _int(stock, id, 0, STOCK_MAX, "starting_stock.")
		elif entry.has("market"):
			var market := _object(entry, "market", [])
			for id: String in market:
				if _ingredient_unlocked(id, item.day, "market." + id):
					item.market[id] = _int(market, id, 1, PRICE_MAX, "market.")
			for offered: Ingredient in _ingredients.values():
				if offered.unlock_day <= item.day and not market.has(offered.id):
					_error("market", "missing price for '%s' (unlocked on day %d)" % [offered.id, offered.unlock_day])
		_load_customers(entry, item)
		if item.id != "":
			seen_ids[item.id] = item
		if item.id != "" and entry.has("day"):
			if _days.has(item.day):
				_error("day", "day %d appears twice" % item.day)
			else:
				_days[item.day] = item
	_entry = "-"
	for number in range(FIRST_DAY, FIRST_DAY + _days.size()):
		if not _days.has(number):
			_error("day", "days must be exactly %d..%d; day %d is missing" % [FIRST_DAY, _days.size(), number])


static func _load_upgrades(entries: Array[Dictionary]) -> void:
	for entry in entries:
		var item := Upgrade.new()
		item.id = _begin_entry(entry, ["id", "station", "name", "description", "unlock_day", "levels"], [], _upgrades)
		item.station = _enum(entry, "station", STEPS)
		for other: Upgrade in _upgrades.values():
			if item.station != "" and other.station == item.station:
				_error("station", "'%s' already has upgrade '%s'" % [item.station, other.id])
		item.name = _string(entry, "name", NAME_MAX)
		item.description = _string(entry, "description", DESCRIPTION_MAX)
		item.unlock_day = _int(entry, "unlock_day", FIRST_DAY, LAST_DAY)
		_load_levels(entry, item)
		if item.id != "":
			_upgrades[item.id] = item
	_entry = "-"
	for station in STEPS:
		if not _upgrades.values().any(func(item: Upgrade) -> bool: return item.station == station):
			_error("station", "station '%s' has no upgrade" % station)


## An upgrade's `levels`: a non-empty array of {tolerance, cost}, tolerances strictly
## increasing above 1.
static func _load_levels(entry: Dictionary, item: Upgrade) -> void:
	if not entry.has("levels"):
		return
	if typeof(entry["levels"]) != TYPE_ARRAY:
		_error("levels", "expected Array, got %s" % type_string(typeof(entry["levels"])))
		return
	var list: Array = entry["levels"]
	if list.is_empty():
		_error("levels", "is empty")
	var previous := 1.0
	for i in list.size():
		var path := "levels[%d]." % i
		if typeof(list[i]) != TYPE_DICTIONARY:
			_error(path.trim_suffix("."), "expected Dictionary, got %s" % type_string(typeof(list[i])))
			continue
		var level: Dictionary = list[i]
		_check_keys(level, ["tolerance", "cost"], [], path)
		var tolerance := _float(level, "tolerance", 1.0, UPGRADE_TOLERANCE_MAX, path)
		if level.has("tolerance") and tolerance <= previous:
			_error(path + "tolerance", "%s must be greater than %s (the level below)" % [tolerance, previous])
		previous = maxf(previous, tolerance)
		item.tolerances.append(tolerance)
		item.costs.append(_int(level, "cost", 1, COINS_MAX, path))


static func _load_customers(entry: Dictionary, item: DaySpec) -> void:
	if not entry.has("customers"):
		return
	if typeof(entry["customers"]) != TYPE_ARRAY:
		_error("customers", "expected Array, got %s" % type_string(typeof(entry["customers"])))
		return
	var list: Array = entry["customers"]
	if list.is_empty():
		_error("customers", "is empty")
	for i in list.size():
		var path := "customers[%d]." % i
		if typeof(list[i]) != TYPE_DICTIONARY:
			_error(path.trim_suffix("."), "expected Dictionary, got %s" % type_string(typeof(list[i])))
			continue
		var spec: Dictionary = list[i]
		_check_keys(spec, ["archetype", "potion"], ["request"], path)
		var customer := DayCustomer.new()
		customer.archetype = _reference(spec, "archetype", _archetypes, "archetype", path)
		customer.potion = _reference(spec, "potion", _potions, "potion", path)
		if customer.potion != "" and _potions[customer.potion].unlock_day > item.day:
			_error(path + "potion", "'%s' unlocks on day %d" % [customer.potion, _potions[customer.potion].unlock_day])
		customer.request = _reference(spec, "request", _requests, "request", path)
		if customer.request != "":
			var line := _requests[customer.request]
			if (customer.potion != "" and line.potion != customer.potion) or (customer.archetype != "" and line.archetype != customer.archetype):
				_error(path + "request", "'%s' is for %s/%s, not %s/%s" % [line.id, line.potion, line.archetype, customer.potion, customer.archetype])
		item.customers.append(customer)


## Parses a file's text into its entries; reports a parse error or a top level that is not
## a non-empty array of objects.
static func _parse_entries(text: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var json := JSON.new()
	if json.parse(text) != OK:
		_error("(file)", "JSON parse error at line %d: %s" % [json.get_error_line() + 1, json.get_error_message()])
		return entries
	if typeof(json.data) != TYPE_ARRAY:
		_error("(file)", "top level must be an array, got %s" % type_string(typeof(json.data)))
		return entries
	var list: Array = json.data
	if list.is_empty():
		_error("(file)", "has no entries")
	for i in list.size():
		if typeof(list[i]) == TYPE_DICTIONARY:
			entries.append(list[i])
		else:
			_entry = "#%d" % i
			_error("(entry)", "expected Dictionary, got %s" % type_string(typeof(list[i])))
	return entries


## Starts reading `entry`: sets the error context and checks its keys and id. Returns the id
## when it is valid and not yet in `seen`, else "" (the entry is then validated but not stored).
static func _begin_entry(entry: Dictionary, required: Array[String], optional: Array[String], seen: Dictionary) -> String:
	var id := ""
	if typeof(entry.get("id")) == TYPE_STRING:
		id = entry["id"]
	_entry = id if id != "" else "(no id)"
	_check_keys(entry, required, optional)
	if not entry.has("id"):
		return ""
	if typeof(entry["id"]) != TYPE_STRING:
		_error("id", "expected String, got %s" % type_string(typeof(entry["id"])))
		return ""
	if _snake_case.search(id) == null:
		_error("id", "'%s' is not snake_case" % id)
		return ""
	if seen.has(id):
		_error("id", "duplicate id '%s'" % id)
		return ""
	return id


static func _check_keys(object: Dictionary, required: Array[String], optional: Array[String], path := "") -> void:
	for key in required:
		if not object.has(key):
			_error(path + key, "missing key")
	for key: Variant in object:
		if not (key in required or key in optional):
			_error(path + str(key), "unknown key")


static func _string(object: Dictionary, key: String, max_length: int, path := "", check_length := true) -> String:
	if not object.has(key):
		return ""
	var value: Variant = object[key]
	if typeof(value) != TYPE_STRING:
		_error(path + key, "expected String, got %s" % type_string(typeof(value)))
		return ""
	var text: String = value
	if check_length and (text.is_empty() or text.length() > max_length):
		_error(path + key, "length %d is outside 1..%d" % [text.length(), max_length])
	return text


static func _int(object: Dictionary, key: String, low: int, high: int, path := "") -> int:
	if not object.has(key):
		return low
	return _int_value(object[key], path + key, low, high)


static func _int_value(value: Variant, field: String, low: int, high: int) -> int:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		_error(field, "expected int, got %s" % type_string(typeof(value)))
		return low
	var number: float = value
	if number != floorf(number):
		_error(field, "expected int, got %s" % value)
		return low
	if number < low or number > high:
		_error(field, "%d is outside %d..%d" % [int(number), low, high])
		return low
	return int(number)


static func _float(object: Dictionary, key: String, low: float, high: float, path := "") -> float:
	if not object.has(key):
		return low
	var value: Variant = object[key]
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		_error(path + key, "expected float, got %s" % type_string(typeof(value)))
		return low
	var number: float = value
	if number < low or number > high:
		_error(path + key, "%s is outside %s..%s" % [number, low, high])
		return low
	return number


static func _bool(object: Dictionary, key: String) -> bool:
	if not object.has(key):
		return false
	if typeof(object[key]) != TYPE_BOOL:
		_error(key, "expected bool, got %s" % type_string(typeof(object[key])))
		return false
	return object[key]


## A string that must be one of `values`; "" when missing or invalid.
static func _enum(object: Dictionary, key: String, values: Array[String], path := "") -> String:
	var text := _string(object, key, NAME_MAX, path, false)
	if object.has(key) and typeof(object[key]) == TYPE_STRING and not text in values:
		_error(path + key, "'%s' is not one of %s" % [text, values])
		return ""
	return text


## An id that must be a key of `known`; "" when missing or unknown.
static func _reference(object: Dictionary, key: String, known: Dictionary, kind: String, path := "") -> String:
	var id := _string(object, key, NAME_MAX, path, false)
	if object.has(key) and typeof(object[key]) == TYPE_STRING and not known.has(id):
		_error(path + key, "unknown %s id '%s'" % [kind, id])
		return ""
	return id


## An array of 4 ints, each 0..`high`, as Vector4i(ember, frost, bloom, gloom).
static func _essence(object: Dictionary, key: String, high: int) -> Vector4i:
	if not object.has(key):
		return Vector4i.ZERO
	var value: Variant = object[key]
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != ESSENCES.size():
		_error(key, "expected an array of %d ints %s, got %s" % [ESSENCES.size(), ESSENCES, value])
		return Vector4i.ZERO
	var list: Array = value
	var result := Vector4i.ZERO
	for i in ESSENCES.size():
		result[i] = _int_value(list[i], "%s[%d]" % [key, i], 0, high)
	return result


## An array of strings; non-empty when `require_items`. Wrong-typed elements are reported and skipped.
static func _strings(object: Dictionary, key: String, require_items := true, path := "") -> PackedStringArray:
	var result := PackedStringArray()
	if not object.has(key):
		return result
	if typeof(object[key]) != TYPE_ARRAY:
		_error(path + key, "expected Array, got %s" % type_string(typeof(object[key])))
		return result
	var list: Array = object[key]
	if require_items and list.is_empty():
		_error(path + key, "is empty")
	for i in list.size():
		if typeof(list[i]) == TYPE_STRING:
			result.append(list[i])
		else:
			_error("%s%s[%d]" % [path, key, i], "expected String, got %s" % type_string(typeof(list[i])))
	return result


## A nested object whose keys must be exactly `keys` (any keys when `keys` is empty).
static func _object(object: Dictionary, key: String, keys: Array[String]) -> Dictionary:
	if not object.has(key):
		return {}
	if typeof(object[key]) != TYPE_DICTIONARY:
		_error(key, "expected Dictionary, got %s" % type_string(typeof(object[key])))
		return {}
	var nested: Dictionary = object[key]
	if not keys.is_empty():
		_check_keys(nested, keys, [], key + ".")
	return nested


static func _bubble(text: String, field: String) -> void:
	var problem := bubble_problem(text)
	if problem != "":
		_error(field, problem)


## True if `id` is an ingredient unlocked by `day_number`; reports `field` otherwise.
static func _ingredient_unlocked(id: String, day_number: int, field: String) -> bool:
	if not _ingredients.has(id):
		_error(field, "unknown ingredient id '%s'" % id)
		return false
	if _ingredients[id].unlock_day > day_number:
		_error(field, "'%s' unlocks on day %d" % [id, _ingredients[id].unlock_day])
		return false
	return true


static func _lookup(table: Dictionary, id: String, kind: String) -> Resource:
	if not table.has(id):
		if not quiet_errors:
			push_error("[Content] Unknown %s id '%s'" % [kind, id])
		return null
	return table[id]


static func _begin_file(file: String) -> void:
	_file = "data/" + file
	_entry = "-"


static func _error(field: String, problem: String) -> void:
	var message := "%s [%s] %s: %s" % [_file, _entry, field, problem]
	_errors.append(message)
	if not quiet_errors:
		push_error("[Content] " + message)
