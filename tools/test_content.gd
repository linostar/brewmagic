extends SceneTree
## Headless content tests: loads brewmagic/data/*.json through Content and checks every
## invariant I1..I10 of brewmagic/data/SCHEMA.md, the bubble wrap, the lookup API, that
## malformed data produces exactly the expected errors, and the title's content-error banner.
##   "$GODOT" --headless --path brewmagic --script "$PWD/tools/test_content.gd"
## Prints "test_content: OK" when every test passes; exits 1 otherwise.
## To add a test: write a `_test_*` func (it may await) that reports through _check(),
## and append it to the list in _tests(). Every test leaves Content loaded from the real data.

const TITLE_SCENE := preload("res://scenes/title.tscn")
const SPEECH_BUBBLE_SCENE := preload("res://scenes/speech_bubble.tscn")
## Customer part sprites (SCHEMA.md archetypes.parts).
const CUSTOMER_ATLAS := Art.ART_DIR + "customer.json"
const BASE_WINDOW := Vector2i(270, 480)
## Real-time limit for the whole run; a test stuck on an await fails instead of hanging.
const WATCHDOG_MSEC := 60000
## Minimum coverage counts (SCHEMA.md I10).
const MIN_REQUESTS_PER_PAIR := 3
const MIN_MISBREWS_PER_ESSENCE := 5
## Distance from target at which a brew is a Misbrew.
const MISBREW_DISTANCE := 3

var _failures: Array[String] = []
var _passed := 0
var _deadline_msec := 0


func _initialize() -> void:
	_deadline_msec = Time.get_ticks_msec() + WATCHDOG_MSEC
	if root.get_node_or_null("Game") as GameState == null:
		printerr("test_content: FAILED: Game autoload not found")
		quit(1)
		return
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > _deadline_msec:
		printerr("test_content: FAILED watchdog: tests did not finish within %d ms" % WATCHDOG_MSEC)
		quit(1)
	return false


func _tests() -> Array[Callable]:
	return [
		_test_real_data_loads_clean,
		_test_bubble_wrap,
		_test_lookup_api,
		_test_i2_lines_fit_bubble,
		_test_bubble_lines_fit_font,
		_test_i4_hint_tagging,
		_test_i5_hints_fair,
		_test_i6_no_potion_names,
		_test_i7_potions_and_days_solvable,
		_test_i8_day1_stock_serves_day1,
		_test_i8_market_serves_later_days,
		_test_i9_misbrews_overshoot,
		_test_i10_coverage,
		_test_part_values_have_sprites,
		_test_malformed_data_errors,
		_test_title_shows_content_errors,
	]


func _run() -> void:
	root.size = BASE_WINDOW
	await process_frame
	for test in _tests():
		await test.call()
	for failure in _failures:
		printerr("test_content: FAIL " + failure)
	if _failures.is_empty():
		print("test_content: OK (%d checks)" % _passed)
		quit(0)
	else:
		printerr("test_content: FAILED %d of %d checks" % [_failures.size(), _failures.size() + _passed])
		quit(1)


## I1, I2, I3: the loader checks parsing, keys, ids, types, ranges, enums, lengths,
## bubbles and cross-references, so clean real data means no loader errors.
func _test_real_data_loads_clean() -> void:
	Content.reload()
	var errors := Content.errors()
	_check(errors.is_empty(), "I1-I3 real data loads without errors", "\n".join(errors))
	_check(not Content.ingredients().is_empty() and not Content.potions().is_empty() and not Content.days().is_empty(),
		"real data has content", "%d ingredients, %d potions, %d days" % [Content.ingredients().size(), Content.potions().size(), Content.days().size()])


func _test_bubble_wrap() -> void:
	var wrapped := Content.wrap_bubble("Duchess ate a snowman. I need something warm and healing. For me.")
	_check(wrapped == PackedStringArray(["Duchess ate a snowman. I", "need something warm and", "healing. For me."]), "wrap is greedy at 26", str(wrapped))
	var exact := "a".repeat(26)
	_check(Content.wrap_bubble(exact + " b") == PackedStringArray([exact, "b"]), "a 26-char line is full", str(Content.wrap_bubble(exact + " b")))
	_check(Content.bubble_problem(exact) == "", "26-char word fits", Content.bubble_problem(exact))
	_check(Content.bubble_problem(exact + "a") != "", "27-char word does not fit", "accepted")
	_check(Content.bubble_problem("one\ntwo") != "", "newline does not fit", "accepted")
	_check(Content.bubble_problem("") != "", "empty line does not fit", "accepted")
	var four_lines := "%s %s %s %s" % ["a".repeat(20), "b".repeat(20), "c".repeat(20), "d".repeat(15)]
	_check(four_lines.length() == 78 and Content.wrap_bubble(four_lines).size() == 4, "78-char text can still wrap to 4 lines", str(Content.wrap_bubble(four_lines)))
	_check(Content.bubble_problem(four_lines) != "", "4 wrapped lines do not fit", "accepted")


func _test_lookup_api() -> void:
	_check(Content.ingredient("ember_pepper").essence == Vector4i(2, 0, 0, 0), "ingredient() essence is Vector4i", str(Content.ingredient("ember_pepper").essence))
	_check(Content.potion("hearthglow_tonic").target == Vector4i(2, 0, 2, 0), "potion() target", str(Content.potion("hearthglow_tonic").target))
	_check(Content.archetype("goat_farmer").reactions["perfect"].size() >= 3, "archetype() reactions", str(Content.archetype("goat_farmer").reactions))
	var lines := Content.requests_for("hearthglow_tonic", "goat_farmer")
	_check(not lines.is_empty() and lines.all(func(r: RequestLine) -> bool: return r.potion == "hearthglow_tonic" and r.archetype == "goat_farmer"),
		"requests_for() filters by potion and archetype", str(lines.size()))
	var frost := Content.ESSENCES.find("frost")
	_check(Content.misbrews_for(frost).all(func(m: MisbrewLine) -> bool: return m.essence == frost and m.effect == "frosted"), "misbrews_for() filters by essence", str(Content.misbrews_for(frost).size()))
	var day1 := Content.day(1)
	_check(day1 != null and day1.starting_coins > 0 and not day1.starting_stock.is_empty() and day1.market.is_empty(), "day(1) has start values, no market", str(day1))
	_check(Content.day(2) != null and not Content.day(2).market.is_empty() and Content.day(2).starting_stock.is_empty(), "day(2) has a market", str(Content.day(2)))
	for number in range(1, Content.days().size() + 1):
		var on_sale := Content.ingredients_unlocked_by(number)
		_check(on_sale.all(func(i: Ingredient) -> bool: return i.unlock_day <= number) and on_sale.size() == Content.ingredients().filter(func(i: Ingredient) -> bool: return i.unlock_day <= number).size(),
			"ingredients_unlocked_by(%d)" % number, str(on_sale.size()))
		var allowed := Content.potions_unlocked_by(number)
		_check(allowed.all(func(p: PotionType) -> bool: return p.unlock_day <= number) and allowed.size() == Content.potions().filter(func(p: PotionType) -> bool: return p.unlock_day <= number).size(),
			"potions_unlocked_by(%d)" % number, str(allowed.size()))


## Every bubble string, re-checked through the API (the loader checks them too).
func _test_i2_lines_fit_bubble() -> void:
	var problems: Array[String] = []
	for archetype in Content.archetypes():
		for grade in Archetype.GRADES:
			for line: String in archetype.reactions.get(grade, PackedStringArray()):
				_collect_bubble_problem(problems, "%s.%s" % [archetype.id, grade], line)
	for line in Content.requests():
		_collect_bubble_problem(problems, line.id, line.text)
	for line in Content.misbrews():
		_collect_bubble_problem(problems, line.id, line.text)
	for spec in Content.days():
		_collect_bubble_problem(problems, spec.id, spec.morning_note)
	_check(problems.is_empty(), "I2 every line fits its bubble", "\n".join(problems))


## Every request, reaction and misbrew line, wrapped by Content.wrap_bubble and measured
## with the speech bubble's real theme font, fits inside the bubble on screen.
func _test_bubble_lines_fit_font() -> void:
	var bubble: SpeechBubble = SPEECH_BUBBLE_SCENE.instantiate()
	root.add_child(bubble)
	var font := bubble.text_font()
	var font_size := bubble.text_font_size()
	var max_width := bubble.size.x - 2.0 * (SpeechBubble.SIDE_MARGIN + SpeechBubble.PADDING.x)
	var max_lines := int((SpeechBubble.BOTTOM_Y - 2.0 * SpeechBubble.PADDING.y + SpeechBubble.LINE_SPACING) / (font.get_height(font_size) + SpeechBubble.LINE_SPACING))
	var texts: Dictionary[String, String] = {}
	for archetype in Content.archetypes():
		for grade in Archetype.GRADES:
			var reactions: PackedStringArray = archetype.reactions.get(grade, PackedStringArray())
			for i in reactions.size():
				texts["%s.%s[%d]" % [archetype.id, grade, i]] = reactions[i]
	for line in Content.requests():
		texts[line.id] = line.text
	for line in Content.misbrews():
		texts[line.id] = line.text
	var overflows: Array[String] = []
	var widest := 0.0
	for key in texts:
		var lines := Content.wrap_bubble(texts[key])
		if lines.size() > max_lines:
			overflows.append("%s: %d lines, at most %d fit above y %d" % [key, lines.size(), max_lines, SpeechBubble.BOTTOM_Y])
		for each in lines:
			var width := bubble.line_width(each)
			widest = maxf(widest, width)
			if width > max_width:
				overflows.append("%s: '%s' is %.0f px wide, the bubble fits %.0f" % [key, each, width, max_width])
	bubble.free()
	_check(texts.size() > 0 and overflows.is_empty(), "every bubble line fits at font size %d (widest %.0f of %.0f px, %d lines)" % [font_size, widest, max_width, texts.size()], "\n".join(overflows))


func _test_i4_hint_tagging() -> void:
	var patterns: Dictionary[String, Array] = {}
	for word in Content.hint_words():
		var forms: Array[RegEx] = []
		for form in word.forms:
			forms.append(RegEx.create_from_string("(?i)\\b" + form))
		patterns[word.id] = forms
	var derived: Dictionary[String, PackedStringArray] = {}
	var problems: Array[String] = []
	for line in Content.requests():
		var found := PackedStringArray()
		for word in Content.hint_words():
			if patterns[word.id].any(func(r: RegEx) -> bool: return r.search(line.text) != null):
				found.append(word.id)
				if not derived.has(word.id):
					derived[word.id] = PackedStringArray()
				derived[word.id].append(line.id)
		var hints := line.hints.duplicate()
		hints.sort()
		found.sort()
		if hints != found:
			problems.append("%s: hints %s, text matches %s" % [line.id, hints, found])
	for word in Content.hint_words():
		if word.request_ids != derived.get(word.id, PackedStringArray()):
			problems.append("%s.request_ids %s, derived %s" % [word.id, word.request_ids, derived.get(word.id, PackedStringArray())])
	_check(problems.is_empty(), "I4 hint tagging is exact", "\n".join(problems))


func _test_i5_hints_fair() -> void:
	var problems: Array[String] = []
	for line in Content.requests():
		var hinted: Array[int] = []
		for id in line.hints:
			var essence := Content.hint_word(id).essence
			if not essence in hinted:
				hinted.append(essence)
		hinted.sort()
		var needed: Array[int] = []
		var target := Content.potion(line.potion).target
		for k in Content.ESSENCES.size():
			if target[k] > 0:
				needed.append(k)
		if hinted != needed:
			problems.append("%s: hints essences %s, %s needs %s" % [line.id, hinted, line.potion, needed])
	_check(problems.is_empty(), "I5 hints name exactly the needed essences", "\n".join(problems))


func _test_i6_no_potion_names() -> void:
	var problems: Array[String] = []
	for item in Content.potions():
		var first_word := RegEx.create_from_string("(?i)\\b%s\\b" % item.name.get_slice(" ", 0))
		for line in Content.requests():
			if item.name.to_lower() in line.text.to_lower() or first_word.search(line.text) != null:
				problems.append("%s names %s" % [line.id, item.name])
	_check(problems.is_empty(), "I6 no request names a potion", "\n".join(problems))


func _test_i7_potions_and_days_solvable() -> void:
	var problems: Array[String] = []
	for item in Content.potions():
		if _exact_recipes(item.target, Content.ingredients_unlocked_by(item.unlock_day)).is_empty():
			problems.append("%s has no exact recipe by day %d" % [item.id, item.unlock_day])
	for spec in Content.days():
		var pool := Content.ingredients_unlocked_by(spec.day)
		for i in spec.customers.size():
			if _exact_recipes(Content.potion(spec.customers[i].potion).target, pool).is_empty():
				problems.append("%s customer %d (%s) is not solvable" % [spec.id, i, spec.customers[i].potion])
	_check(problems.is_empty(), "I7 every potion and day customer is exactly solvable", "\n".join(problems))


func _test_i8_day1_stock_serves_day1() -> void:
	var day1 := Content.day(1)
	var options: Array = []
	for customer in day1.customers:
		options.append(_exact_recipes(Content.potion(customer.potion).target, Content.ingredients_unlocked_by(1)))
	var stock: Dictionary[String, int] = day1.starting_stock.duplicate()
	_check(_can_serve_all(options, 0, stock), "I8 day-1 starting stock brews every day-1 customer Perfect", str(day1.starting_stock))


## I8 for days >= 2 on the real data, and a day-2 market too dear for the day-1 pay must fail it.
func _test_i8_market_serves_later_days() -> void:
	var problems := _market_shortfalls()
	_check(problems.is_empty(), "I8 day N-1 Perfect pay buys every day-N customer at day N's market", "\n".join(problems))
	var texts := _real_texts()
	var data: Array = JSON.parse_string(texts["days.json"])
	data[1]["market"]["moonmoss"] = 30
	texts["days.json"] = JSON.stringify(data)
	var errors := _load_quietly(texts)
	var expensive := _market_shortfalls()
	Content.reload()
	_check(errors.is_empty() and expensive.size() == 1 and expensive[0].begins_with("day_2:"), "I8 rejects a day-2 market the day-1 pay cannot cover", "%s / %s" % [errors, expensive])


func _test_i9_misbrews_overshoot() -> void:
	var problems: Array[String] = []
	for item in Content.potions():
		for brew in _all_brews(Content.ingredients()):
			var sum := _essence_sum(brew)
			if _distance(sum, item.target) >= MISBREW_DISTANCE and not _overshoots(sum, item.target):
				problems.append("%s with %s has no overshoot" % [item.id, brew])
	_check(problems.is_empty(), "I9 every misbrew overshoots an essence", "\n".join(problems))


func _test_i10_coverage() -> void:
	var problems: Array[String] = []
	for item in Content.potions():
		for archetype in Content.archetypes():
			var count := Content.requests_for(item.id, archetype.id).size()
			if count < MIN_REQUESTS_PER_PAIR:
				problems.append("%s/%s has %d requests" % [item.id, archetype.id, count])
		if item.unlock_day <= 2 and item.steps != PackedStringArray(["stir", "pour"]):
			problems.append("%s steps %s (days 1-2 use stir, pour)" % [item.id, item.steps])
	for k in Content.ESSENCES.size():
		var lines := Content.misbrews_for(k)
		if lines.size() < MIN_MISBREWS_PER_ESSENCE:
			problems.append("%s has %d misbrews" % [Content.ESSENCES[k], lines.size()])
		for line in lines:
			if line.effect != Content.MISBREW_EFFECTS[k]:
				problems.append("%s effect %s" % [line.id, line.effect])
	for archetype in Content.archetypes():
		for grade in Archetype.GRADES:
			var count: int = archetype.reactions.get(grade, PackedStringArray()).size()
			if count < Content.MIN_REACTION_LINES:
				problems.append("%s has %d %s lines" % [archetype.id, count, grade])
	for item in Content.ingredients():
		if item.unlock_day <= 2 and item.grind:
			problems.append("%s needs grinding before day 3" % item.id)
	_check(problems.is_empty(), "I10 coverage", "\n".join(problems))


## Every part value the schema allows has both idle frames in the customer atlas, so the
## data ids and the sprite names cannot drift apart.
func _test_part_values_have_sprites() -> void:
	var atlas: Variant = JSON.parse_string(FileAccess.get_file_as_string(CUSTOMER_ATLAS))
	if not (atlas is Dictionary and (atlas as Dictionary).get("sprites") is Dictionary):
		_check(false, "customer atlas sidecar has sprites", CUSTOMER_ATLAS)
		return
	var sprites: Dictionary = atlas["sprites"]
	var parts: Dictionary[String, Array] = {"body": Content.BODIES, "head": Content.HEADS, "hair": Content.HAIRS, "acc": Content.ACCESSORIES}
	var problems: Array[String] = []
	for prefix: String in parts:
		for value: String in parts[prefix]:
			if prefix == "acc" and value == "none":
				continue
			for frame in 2:
				var sprite := "%s_%s_%d" % [prefix, value, frame]
				if not sprites.has(sprite):
					problems.append("%s missing from %s" % [sprite, CUSTOMER_ATLAS])
	_check(problems.is_empty(), "every archetype part value has its sprite frames", "\n".join(problems))


## Each malformed variant of the real data must produce exactly one error, the expected one.
## Each case: [label, file, mutation (Callable on the parsed Array), expected message].
func _test_malformed_data_errors() -> void:
	var cases: Array = [
		["missing key", "ingredients.json", func(data: Array) -> void: (data[0] as Dictionary).erase("grind"),
			"data/ingredients.json [ember_pepper] grind: missing key"],
		["unknown key", "potions.json", func(data: Array) -> void: data[0]["colour"] = "#ffffff",
			"data/potions.json [hearthglow_tonic] colour: unknown key"],
		["float for int", "ingredients.json", func(data: Array) -> void: data[0]["base_price"] = 2.5,
			"data/ingredients.json [ember_pepper] base_price: expected int, got 2.5"],
		["wrong type", "potions.json", func(data: Array) -> void: data[0]["price"] = "12",
			"data/potions.json [hearthglow_tonic] price: expected int, got String"],
		["out of range", "archetypes.json", func(data: Array) -> void: data[0]["patience_seconds"] = 5,
			"data/archetypes.json [goat_farmer] patience_seconds: 5 is outside 10..300"],
		["bad cross-reference", "days.json", func(data: Array) -> void: data[1]["customers"][1]["archetype"] = "nobody",
			"data/days.json [day_2] customers[1].archetype: unknown archetype id 'nobody'"],
		["duplicate id", "misbrews.json", func(data: Array) -> void: data.append((data[0] as Dictionary).duplicate()),
			"data/misbrews.json [misbrew_ember_1] id: duplicate id 'misbrew_ember_1'"],
		["overlong line", "archetypes.json", func(data: Array) -> void: data[0]["reactions"]["perfect"][0] = "word ".repeat(16).strip_edges(),
			"data/archetypes.json [goat_farmer] reactions.perfect[0]: bubble text is 79 characters (max 78)"],
	]
	for case: Array in cases:
		var texts := _real_texts()
		var file: String = case[1]
		var data: Array = JSON.parse_string(texts[file])
		var mutate: Callable = case[2]
		mutate.call(data)
		texts[file] = JSON.stringify(data)
		var errors := _load_quietly(texts)
		_check(errors == [case[3]], "malformed data: " + case[0], "\n".join(errors))
	var broken := _real_texts()
	broken["misbrews.json"] = "[{"
	var parse_errors := _load_quietly(broken)
	_check(parse_errors.size() == 1 and parse_errors[0].begins_with("data/misbrews.json [-] (file): JSON parse error at line 1"), "malformed data: bad JSON", "\n".join(parse_errors))
	# An empty file is an error; other files' references into it may add more, but an empty
	# days.json has nothing referring to it and must give exactly this one.
	for file in Content.FILES:
		var emptied := _real_texts()
		emptied[file] = "[]"
		var empty_errors := _load_quietly(emptied)
		var expected := "data/%s [-] (file): has no entries" % file
		_check(expected in empty_errors and (file != "days.json" or empty_errors == [expected]), "malformed data: empty " + file, "\n".join(empty_errors))
	Content.reload()
	_check(Content.errors().is_empty(), "real data reloads clean after malformed runs", "\n".join(Content.errors()))


## With content errors the title shows the banner with their count and disables the shop
## button; with clean content the banner is hidden and the button enabled.
func _test_title_shows_content_errors() -> void:
	var texts := _real_texts()
	texts.erase("days.json")
	var errors := _load_quietly(texts)
	var title := TITLE_SCENE.instantiate() as Title
	root.add_child(title)
	await process_frame
	var banner := title.get_node("Column/ContentErrorBanner") as Label
	var button := title.get_node("Column/OpenShopButton") as Button
	_check(errors.size() == 1 and banner.visible and banner.text == Title.CONTENT_ERROR_MESSAGE % errors.size(), "title shows content error banner", "%s / %s" % [banner.text, errors])
	_check(button.disabled, "title disables the shop button on content errors", "button enabled")
	title.free()
	Content.reload()
	title = TITLE_SCENE.instantiate() as Title
	root.add_child(title)
	await process_frame
	banner = title.get_node("Column/ContentErrorBanner") as Label
	button = title.get_node("Column/OpenShopButton") as Button
	_check(not banner.visible and not button.disabled, "title with clean content has no banner", banner.text)
	title.free()


func _real_texts() -> Dictionary[String, String]:
	var texts: Dictionary[String, String] = {}
	for file in Content.FILES:
		texts[file] = FileAccess.get_file_as_string(Content.DATA_DIR + file)
	return texts


func _load_quietly(texts: Dictionary[String, String]) -> Array[String]:
	Content.quiet_errors = true
	Content.load_texts(texts)
	Content.quiet_errors = false
	return Content.errors()


func _collect_bubble_problem(problems: Array[String], label: String, text: String) -> void:
	var problem := Content.bubble_problem(text)
	if problem != "":
		problems.append("%s: %s" % [label, problem])


## Every multiset of 2 or 3 ingredients from `pool` (repeats allowed), as id lists.
func _all_brews(pool: Array[Ingredient]) -> Array[PackedStringArray]:
	var brews: Array[PackedStringArray] = []
	for i in pool.size():
		for j in range(i, pool.size()):
			brews.append(PackedStringArray([pool[i].id, pool[j].id]))
			for k in range(j, pool.size()):
				brews.append(PackedStringArray([pool[i].id, pool[j].id, pool[k].id]))
	return brews


func _exact_recipes(target: Vector4i, pool: Array[Ingredient]) -> Array[PackedStringArray]:
	return _all_brews(pool).filter(func(brew: PackedStringArray) -> bool: return _essence_sum(brew) == target)


func _essence_sum(brew: PackedStringArray) -> Vector4i:
	var sum := Vector4i.ZERO
	for id in brew:
		sum += Content.ingredient(id).essence
	return sum


func _distance(a: Vector4i, b: Vector4i) -> int:
	var d := (a - b).abs()
	return d.x + d.y + d.z + d.w


func _overshoots(brew: Vector4i, target: Vector4i) -> bool:
	for k in Content.ESSENCES.size():
		if brew[k] > target[k]:
			return true
	return false


## SCHEMA.md I8 for days >= 2 on the loaded content: one problem per day N whose customers'
## cheapest exact recipes, at day N's market prices, cost more than day N-1's Perfect pay.
func _market_shortfalls() -> Array[String]:
	var problems: Array[String] = []
	var days := Content.days()
	for n in range(1, days.size()):
		var spec := days[n]
		var budget := 0
		for customer in days[n - 1].customers:
			budget += Economy.pay(Content.potion(customer.potion).price, Brew.Grade.PERFECT)
		var cost := 0
		for customer in spec.customers:
			var cheapest := -1
			for recipe in _exact_recipes(Content.potion(customer.potion).target, Content.ingredients_unlocked_by(spec.day)):
				var price := 0
				for id in recipe:
					price += spec.market[id]
				if cheapest < 0 or price < cheapest:
					cheapest = price
			if cheapest < 0:
				problems.append("%s: %s has no exact recipe" % [spec.id, customer.potion])
			cost += maxi(cheapest, 0)
		if cost > budget:
			problems.append("%s: cheapest exact recipes cost %d at its market, day %d Perfect pay is %d" % [spec.id, cost, days[n - 1].day, budget])
	return problems


## Backtracking: can customers `index..` each get one of their recipes from `stock`?
func _can_serve_all(options: Array, index: int, stock: Dictionary[String, int]) -> bool:
	if index == options.size():
		return true
	for recipe: PackedStringArray in options[index]:
		var left: Dictionary[String, int] = stock.duplicate()
		var enough := true
		for id in recipe:
			left[id] = left.get(id, 0) - 1
			enough = enough and left[id] >= 0
		if enough and _can_serve_all(options, index + 1, left):
			return true
	return false


func _check(condition: bool, test_name: String, detail: String) -> void:
	if condition:
		_passed += 1
		print("test_content: pass " + test_name)
	else:
		_failures.append("%s: %s" % [test_name, detail])
