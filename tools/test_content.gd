extends SceneTree
## Headless content tests: loads brewmagic/data/*.json through Content and checks every
## invariant of brewmagic/data/SCHEMA.md (the story ones on every flag path), the bubble
## wrap, the lookup API, that malformed data produces exactly the expected errors, and the
## title's content-error banner.
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
## The day the Bellows first appears (SCHEMA.md I10).
const BELLOWS_DAY := 6
## The day the Mortar first appears (SCHEMA.md I10).
const MORTAR_DAY := 3
## Beats each story character has at least (SCHEMA.md I13).
const MIN_BEATS := 3
## Seconds of patience every customer has left at the counter at least (SCHEMA.md I15).
const MIN_PATIENCE := 33.0
## Seconds a customer waits in line for the one brew ahead of it (a later-day multi-station brew,
## from the order to the send-off); patience drains at Customer.QUEUE_PATIENCE_RATE meanwhile (I15).
# ponytail: one brew is the typical wait; the third in line waits two and can still storm off from the line.
const QUEUE_WAIT := 25.0

## The difficulty levels every story check runs at: the kindest, the authored and the
## hardest (Difficulty; the level picks the ordinary visitors and scales patience).
const LEVELS: Array[float] = [Difficulty.LEVEL_MIN, Difficulty.START_LEVEL, Difficulty.LEVEL_MAX]
## Constant skill ratings (struggling, middling, strong) whose day-by-day level
## trajectories I8 also runs (_level_trajectory: the level moves as in Game.finish_day).
const RATINGS: Array[float] = [0.2, 0.5, 1.0]

## _customers' memo: "<DaySpec instance id>|<flags>|<level>" -> the shift's customers.
var _shifts: Dictionary[String, Array] = {}
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
		_test_i11_mortar_consistency,
		_test_i12_bellows_consistency,
		_test_i13_story_paths,
		_test_flag_paths_enumerate_conditions,
		_test_i14_endings,
		_test_i15_patience,
		_test_i16_rush_voices,
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
	for station in Content.STEPS:
		var upgrade := Content.upgrade_for(station)
		_check(upgrade != null and upgrade.station == station and upgrade.max_level() > 0 and upgrade.costs.size() == upgrade.max_level(), "upgrade_for(%s)" % station, str(upgrade))
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
		for note in spec.morning_notes:
			_collect_bubble_problem(problems, spec.id + " morning_notes", note["text"])
		for customer in spec.customers:
			for outcome in customer.lines:
				_collect_bubble_problem(problems, "%s %s.%s" % [spec.id, customer.flag(), outcome], customer.lines[outcome])
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
	for spec in Content.days():
		for customer in spec.customers:
			for outcome in customer.lines:
				texts["%s %s.%s" % [spec.id, customer.flag(), outcome]] = customer.lines[outcome]
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
	# Every day customer on any path, at every level (the ordinary visitors depend on it).
	for path in _flag_paths():
		for level in LEVELS:
			for spec in Content.days():
				var pool := Content.ingredients_unlocked_by(spec.day)
				for customer in _customers(spec, path, level):
					if _exact_recipes(Content.potion(customer.potion).target, pool).is_empty():
						problems.append("%s at level %.2f: %s is not solvable" % [spec.id, level, customer.potion])
	var targets: Dictionary[Vector4i, String] = {}
	for item in Content.potions():
		if targets.has(item.target):
			problems.append("%s and %s share the target %s" % [targets[item.target], item.id, item.target])
		targets[item.target] = item.id
	_check(problems.is_empty(), "I7 every potion and day customer is exactly solvable, targets unique", "\n".join(problems))


func _test_i8_day1_stock_serves_day1() -> void:
	var day1 := Content.day(1)
	var options: Array = []
	for customer in Shift.story(1).customers:
		options.append(_exact_recipes(Content.potion(customer.potion).target, Content.ingredients_unlocked_by(1)))
	var stock: Dictionary[String, int] = day1.starting_stock.duplicate()
	_check(_can_serve_all(options, 0, stock), "I8 day-1 starting stock brews every day-1 customer Perfect", str(day1.starting_stock))


## I8 for days >= 2 on the real data; a day-2 market too dear for the day-1 pay must
## fail it, and stock carried over from day 1 must count (dear frost mint and
## nightshade caps are covered by the ones day 1 leaves).
func _test_i8_market_serves_later_days() -> void:
	var problems: Array[String] = []
	var paths := _flag_paths()
	var trajectories: Dictionary[String, Array] = {}
	for level in LEVELS:
		var constant: Array[float] = []
		constant.resize(Content.days().size())
		constant.fill(level)
		trajectories["level %.2f every day" % level] = constant
	for rating in RATINGS:
		trajectories["rating %.2f every day" % rating] = _level_trajectory(func(level: float) -> float: return snappedf(Difficulty.next_level(level, rating), 1.0 / GameState.SAVE_HUNDREDTHS))
	for path in paths:
		for name: String in trajectories:
			for problem in _market_shortfalls(path, trajectories[name]):
				problems.append("path %s, %s: %s" % [path, name, problem])
	_check(problems.is_empty(), "I8 on all %d flag paths at a constant level (%s) and along the level the next_level steps reach at a constant rating (%s), day N-1 Perfect pay (beats unpaid) plus the carried-over stock buys every day-N customer at day N's market" % [paths.size(), LEVELS, RATINGS], "\n".join(problems))
	var texts := _real_texts()
	var data: Array = JSON.parse_string(texts["days.json"])
	data[1]["market"]["sunpetal"] = 60
	texts["days.json"] = JSON.stringify(data)
	var errors := _load_quietly(texts)
	var expensive := _market_shortfalls()
	# Day 2 fails; every later day then has no Perfect day before it to carry stock from.
	var cascade := expensive.slice(1).all(func(problem: String) -> bool: return "no Perfect day" in problem)
	_check(errors.is_empty() and not expensive.is_empty() and expensive[0].begins_with("day_2:") and cascade, "I8 rejects a day-2 market the day-1 pay cannot cover", "%s / %s" % [errors, expensive])
	texts = _real_texts()
	data = JSON.parse_string(texts["days.json"])
	data[1]["market"]["frost_mint"] = 12
	data[1]["market"]["nightshade_cap"] = 12
	texts["days.json"] = JSON.stringify(data)
	errors = _load_quietly(texts)
	var carried := _market_shortfalls()
	Content.reload()
	_check(errors.is_empty() and carried.is_empty(), "I8 counts the stock carried over from day 1", "%s / %s" % [errors, carried])


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
	for spec in Content.days():
		for customer in spec.customers:
			# Pinned and generated visitors (Shift.story pins their request) need no three lines.
			if customer.request != "" or customer.is_generated():
				continue
			var count := Content.requests_for(customer.potion, customer.archetype).size()
			if count < MIN_REQUESTS_PER_PAIR:
				problems.append("%s: %s/%s has %d requests" % [spec.id, customer.potion, customer.archetype, count])
	for item in Content.potions():
		if item.unlock_day == 1 and item.steps != PackedStringArray(["stir", "pour"]):
			problems.append("%s steps %s (day 1 uses stir, pour)" % [item.id, item.steps])
		if item.unlock_day < BELLOWS_DAY and "bellows" in item.steps:
			problems.append("%s (day %d) uses the bellows before day %d" % [item.id, item.unlock_day, BELLOWS_DAY])
	if not Content.potions().any(func(item: PotionType) -> bool: return item.unlock_day == MORTAR_DAY and "mortar" in item.steps):
		problems.append("no day-%d potion uses the mortar" % MORTAR_DAY)
	if not Content.potions().any(func(item: PotionType) -> bool: return item.unlock_day == BELLOWS_DAY and "bellows" in item.steps):
		problems.append("no day-%d potion uses the bellows" % BELLOWS_DAY)
	for item in Content.ingredients():
		if item.unlock_day < BELLOWS_DAY and item.heat:
			problems.append("%s needs heat before day %d" % [item.id, BELLOWS_DAY])
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
		if item.unlock_day == 1 and item.grind:
			problems.append("%s needs grinding on day 1" % item.id)
	_check(problems.is_empty(), "I10 coverage", "\n".join(problems))


## I11: a potion lists "mortar" exactly when every exact recipe of it needs a grind ingredient.
func _test_i11_mortar_consistency() -> void:
	var problems := _station_mismatches("mortar", func(item: Ingredient) -> bool: return item.grind)
	_check(problems.is_empty(), "I11 mortar steps match the grind ingredients", "\n".join(problems))


## I12: a potion lists "bellows" exactly when every exact recipe of it needs a heat ingredient.
func _test_i12_bellows_consistency() -> void:
	var problems := _station_mismatches("bellows", func(item: Ingredient) -> bool: return item.heat)
	_check(problems.is_empty(), "I12 bellows steps match the heat ingredients", "\n".join(problems))


## The potions whose `steps` list `station` while not every exact recipe has an ingredient
## that `needs` it, or the other way round.
func _station_mismatches(station: String, needs: Callable) -> Array[String]:
	var problems: Array[String] = []
	for item in Content.potions():
		var recipes := _exact_recipes(item.target, Content.ingredients_unlocked_by(item.unlock_day))
		var all_need := not recipes.is_empty() and recipes.all(func(brew: PackedStringArray) -> bool:
			return Array(brew).any(func(id: String) -> bool: return needs.call(Content.ingredient(id))))
		if (station in item.steps) != all_need:
			problems.append("%s steps %s but recipes %s" % [item.id, item.steps, recipes])
	return problems


## I13 on the real data: every story character has its beats (the last on the last day),
## and on every flag path every day has customers, each beat of the day comes exactly
## once, and every customer is exactly solvable (I8 per path is in its own test).
func _test_i13_story_paths() -> void:
	var problems: Array[String] = []
	var days := Content.days()
	var beat_day: Dictionary[String, int] = {}
	for spec in days:
		for customer in spec.customers:
			if customer.beat != "":
				beat_day[customer.flag()] = spec.day
	for who in Content.archetypes():
		if not who.is_story():
			continue
		var own := beat_day.keys().filter(func(flag: String) -> bool: return flag.begins_with(who.id + "."))
		if own.size() < MIN_BEATS:
			problems.append("%s has %d beats (min %d)" % [who.id, own.size(), MIN_BEATS])
		elif own.map(func(flag: String) -> int: return beat_day[flag]).max() != days[-1].day:
			problems.append("%s has no beat on day %d" % [who.id, days[-1].day])
	var paths := _flag_paths()
	for path in paths:
		for spec in days:
			var customers := _customers(spec, path, Difficulty.START_LEVEL)
			if customers.is_empty():
				problems.append("path %s: %s has no customers" % [path, spec.id])
			var pool := Content.ingredients_unlocked_by(spec.day)
			for flag: String in beat_day:
				if beat_day[flag] != spec.day:
					continue
				var visits := customers.filter(func(c: DayCustomer) -> bool: return c.flag() == flag).size()
				if visits != 1:
					problems.append("path %s: %s has beat %s %d times" % [path, spec.id, flag, visits])
			for customer in customers:
				if _exact_recipes(Content.potion(customer.potion).target, pool).is_empty():
					problems.append("path %s: %s %s is not solvable" % [path, spec.id, customer.potion])
	_check(problems.is_empty(), "I13 every story path (%d) has each beat once, customers every day, all solvable" % paths.size(), "\n".join(problems))


## I14: exactly the three endings of Story.ENDINGS, each with 2..5 pages that fit a page
## and casts of known archetypes; the licence beat is one of the final beats.
func _test_i14_endings() -> void:
	var problems: Array[String] = []
	var ids: Array[String] = []
	for ending in Content.endings():
		ids.append(ending.id)
		if ending.pages.size() < Content.MIN_PAGES or ending.pages.size() > Content.MAX_PAGES or ending.casts.size() != ending.pages.size():
			problems.append("%s has %d pages" % [ending.id, ending.pages.size()])
		for i in ending.pages.size():
			if Content.page_problem(ending.pages[i]) != "":
				problems.append("%s page %d: %s" % [ending.id, i, Content.page_problem(ending.pages[i])])
			for id in ending.casts[i]:
				if Content.archetypes().all(func(a: Archetype) -> bool: return a.id != id):
					problems.append("%s page %d: unknown cast %s" % [ending.id, i, id])
	ids.sort()
	var expected := Story.ENDINGS.duplicate()
	expected.sort()
	if ids != expected:
		problems.append("endings %s, expected %s" % [ids, expected])
	if not Story.LICENCE_FLAG in Story.final_flags():
		problems.append("the licence beat %s is not a final beat %s" % [Story.LICENCE_FLAG, Story.final_flags()])
	_check(problems.is_empty(), "I14 three endings whose pages fit; the licence is decided on the last day", "\n".join(problems))


## I15: on every flag path, every customer of a day still has MIN_PATIENCE seconds at the counter
## (patience_seconds x the day's patience_scale) after waiting QUEUE_WAIT in line, enough for a multi-station brew.
func _test_i15_patience() -> void:
	var problems: Array[String] = []
	for path in _flag_paths():
		for level in LEVELS:
			for spec in Content.days():
				var scale := spec.patience_scale * Difficulty.patience_scale(level)
				for customer in _customers(spec, path, level):
					var patience := Content.archetype(customer.archetype).patience_seconds * scale - QUEUE_WAIT * Customer.QUEUE_PATIENCE_RATE
					var problem := "%s at level %.2f, %s: %.2f s at the counter" % [spec.id, level, customer.archetype, patience]
					if patience < MIN_PATIENCE and not problem in problems:
						problems.append(problem)
	_check(problems.is_empty(), "I15 at every level every customer has at least %.0f s of patience at the counter after %.0f s in line" % [MIN_PATIENCE, QUEUE_WAIT], "\n".join(problems))


## I16: Rush Hour can ask for every potion: each has a request in the voice of at least
## one ordinary archetype (story characters never visit a run; Rush.voices_for).
func _test_i16_rush_voices() -> void:
	var silent: Array[String] = []
	for potion in Content.potions():
		if Rush.voices_for(potion).is_empty():
			silent.append(potion.id)
	_check(silent.is_empty(), "I16 every potion has a request in an ordinary archetype's voice", ", ".join(silent))


## The path enumerator covers each outcome class a condition can tell apart: two
## conditions on one flag naming {great} and {great, poor} split its outcomes into
## three classes (great; poor; refused or stormed_off), so 3 paths.
func _test_flag_paths_enumerate_conditions() -> void:
	var real_paths := _flag_paths().size()
	var texts := _real_texts()
	var archetypes: Array = JSON.parse_string(texts["archetypes.json"])
	var hero: Dictionary = (archetypes[0] as Dictionary).duplicate(true)
	hero["id"] = "test_hero"
	hero["look"] = {"cloth_a": "red", "cloth_b": "blue", "hair": "black", "skin": "light"}
	archetypes.append(hero)
	texts["archetypes.json"] = JSON.stringify(archetypes)
	var requests: Array = JSON.parse_string(texts["requests.json"])
	var line: Dictionary = (requests[0] as Dictionary).duplicate(true)
	line["id"] = "hearthglow_test_hero_1"
	line["archetype"] = "test_hero"
	requests.append(line)
	texts["requests.json"] = JSON.stringify(requests)
	var lines := {"great": "Yay.", "poor": "Hm.", "refused": "Oh.", "stormed_off": "Bye."}
	var data: Array = JSON.parse_string(texts["days.json"])
	(data[0]["customers"] as Array).append({"archetype": "test_hero", "potion": "hearthglow_tonic", "request": "hearthglow_test_hero_1", "beat": "start", "lines": lines})
	(data[1]["customers"] as Array).append({"archetype": "goat_farmer", "potion": "hearthglow_tonic", "when": {"test_hero.start": ["great"]}})
	(data[1]["customers"] as Array).append({"archetype": "dramatic_bard", "potion": "hearthglow_tonic", "when": {"test_hero.start": ["great", "poor"]}})
	texts["days.json"] = JSON.stringify(data)
	var errors := _load_quietly(texts)
	var paths := _flag_paths()
	# Day 2 only depends on the new flag: each of its 3 classes once per real path.
	var sizes: Dictionary[int, int] = {}
	for path in paths:
		var size := Story.customers_of(Content.day(2), path).size()
		sizes[size] = sizes.get(size, 0) + 1
	Content.reload()
	var base := Content.day(2).customers.size()
	var expected: Dictionary[int, int] = {base + 2: real_paths, base + 1: real_paths, base: real_paths}
	_check(errors.is_empty() and paths.size() == 3 * real_paths and sizes == expected, "flag paths split outcomes into the classes conditions tell apart", "%s / %d paths / %s" % [errors, paths.size(), sizes])


## One flag path per combination of the outcome classes the data's `when` conditions
## tell apart: for each flag some `when` names, its outcomes grouped by which named
## lists contain them, one outcome per group. Flags no condition names are left out
## (Story treats them as Story.UNRECORDED, and they cannot change a day).
func _flag_paths() -> Array[Dictionary]:
	var lists: Dictionary[String, Array] = {}
	for spec in Content.days():
		var conditions: Array = spec.customers.map(func(c: DayCustomer) -> Dictionary: return c.when)
		conditions.append_array(spec.morning_notes.map(func(note: Dictionary) -> Dictionary: return note["when"]))
		for when: Dictionary in conditions:
			for flag: String in when:
				if not lists.has(flag):
					lists[flag] = []
				lists[flag].append(when[flag])
	var paths: Array[Dictionary] = [{}]
	for flag in lists:
		var classes: Dictionary[String, String] = {}
		for outcome in Story.OUTCOMES:
			var signature := ""
			for named: PackedStringArray in lists[flag]:
				signature += "1" if outcome in named else "0"
			if not classes.has(signature):
				classes[signature] = outcome
		var grown: Array[Dictionary] = []
		for path in paths:
			for outcome: String in classes.values():
				var next := path.duplicate()
				next[flag] = outcome
				grown.append(next)
		paths = grown
	return paths


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
		["bad cross-reference", "days.json", func(data: Array) -> void: data[0]["customers"][1]["archetype"] = "nobody",
			"data/days.json [day_1] customers[1].archetype: unknown archetype id 'nobody'"],
		["visitor slot with an archetype only", "days.json", func(data: Array) -> void: data[1]["customers"][0]["archetype"] = "goat_farmer",
			"data/days.json [day_2] customers[0].potion: missing key"],
		["duplicate id", "misbrews.json", func(data: Array) -> void: data.append((data[0] as Dictionary).duplicate()),
			"data/misbrews.json [misbrew_ember_1] id: duplicate id 'misbrew_ember_1'"],
		["upgrade level not stronger", "upgrades.json", func(data: Array) -> void: data[0]["levels"][1]["tolerance"] = 1.1,
			"data/upgrades.json [balanced_ladle] levels[1].tolerance: 1.1 must be greater than 1.25 (the level below)"],
		["upgrade tolerance too high", "upgrades.json", func(data: Array) -> void: data[0]["levels"][1]["tolerance"] = 9.0,
			["data/upgrades.json [balanced_ladle] levels[1].tolerance: 9.0 is outside 1.0..3.0",
			"data/upgrades.json [balanced_ladle] levels[1].tolerance: 1.0 must be greater than 1.25 (the level below)"]],
		["upgrade levels empty", "upgrades.json", func(data: Array) -> void: data[0]["levels"] = [],
			"data/upgrades.json [balanced_ladle] levels: is empty"],
		["upgrade levels not a list", "upgrades.json", func(data: Array) -> void: data[0]["levels"] = "lots",
			"data/upgrades.json [balanced_ladle] levels: expected Array, got String"],
		["two upgrades for one station", "upgrades.json", func(data: Array) -> void: data[1]["station"] = "stir",
			["data/upgrades.json [wide_neck_funnel] station: 'stir' already has upgrade 'balanced_ladle'",
			"data/upgrades.json [-] station: station 'pour' has no upgrade"]],
		["overlong line", "archetypes.json", func(data: Array) -> void: data[0]["reactions"]["perfect"][0] = "word ".repeat(16).strip_edges(),
			"data/archetypes.json [goat_farmer] reactions.perfect[0]: bubble text is 79 characters (max 78)"],
		["heat not a bool", "ingredients.json", func(data: Array) -> void: data[0]["heat"] = "no",
			"data/ingredients.json [ember_pepper] heat: expected bool, got String"],
		["when names an unknown beat", "days.json", func(data: Array) -> void: data[1]["customers"][0]["when"] = {"nobody.waves": ["great"]},
			"data/days.json [day_2] customers[0].when.nobody.waves: unknown story beat flag 'nobody.waves'"],
		["beat on two days", "days.json", func(data: Array) -> void: data[3]["customers"].append(data[2]["customers"][2].duplicate(true)),
			"data/days.json [day_4] customers[6].beat: 'quill.inspection' is already a beat of day 3"],
		["when names a beat of the same day", "days.json", func(data: Array) -> void: data[5]["customers"][0]["when"] = {"vexley.opening": ["great"]},
			"data/days.json [day_6] customers[0].when.vexley.opening: 'vexley.opening' is a beat of day 6, not an earlier day"],
		["when names a beat of a later day", "days.json", func(data: Array) -> void: data[1]["morning_notes"] = [{"when": {"quill.fair": ["great"]}, "text": "A note from the future."}],
			"data/days.json [day_2] morning_notes[0].when.quill.fair: 'quill.fair' is a beat of day 20, not an earlier day"],
		["beat follows another character", "days.json", func(data: Array) -> void: data[7]["customers"][2]["when"] = {"stranger.first_sneeze": ["great"]},
			"data/days.json [day_8] customers[2].when.stranger.first_sneeze: a beat of quill may only depend on quill's beats"],
		["when is empty", "days.json", func(data: Array) -> void: data[1]["customers"][0]["when"] = {},
			"data/days.json [day_2] customers[0].when: is empty"],
		["beat on an ordinary visitor", "days.json", func(data: Array) -> void: data[0]["customers"][0]["beat"] = "chat",
			["data/days.json [day_1] customers[0].beat: only story characters have beats; 'gossip_granny' has no look",
			"data/days.json [day_1] customers[0].lines: missing key (required on a story beat)"]],
		["lines without a beat", "days.json", func(data: Array) -> void: data[0]["customers"][0]["lines"] = {},
			"data/days.json [day_1] customers[0].lines: only story beats have lines"],
		["morning notes empty", "days.json", func(data: Array) -> void: data[1]["morning_notes"] = [],
			"data/days.json [day_2] morning_notes: is empty"],
		["look with one cloth twice", "archetypes.json", func(data: Array) -> void: data[0]["look"] = {"cloth_a": "red", "cloth_b": "red", "hair": "black", "skin": "light"},
			"data/archetypes.json [goat_farmer] look.cloth_b: 'red' is also cloth_a; the two cloths must differ"],
		["ending missing", "endings.json", func(data: Array) -> void: data.pop_back(),
			"data/endings.json [-] id: ending 'charming_chaos' is missing"],
		["ending page too long", "endings.json", func(data: Array) -> void: data[0]["pages"][0]["text"] = "word ".repeat(32).strip_edges(),
			"data/endings.json [guild_master] pages[0].text: page text wraps to 7 lines (max 6)"],
		["ending cast unknown", "endings.json", func(data: Array) -> void: data[0]["pages"][0]["cast"] = ["nobody"],
			"data/endings.json [guild_master] pages[0].cast[0]: unknown archetype id 'nobody'"],
		["look with an unknown ramp", "archetypes.json", func(data: Array) -> void: data[0]["look"] = {"cloth_a": "red", "cloth_b": "blue", "hair": "black", "skin": "teal"},
			"data/archetypes.json [goat_farmer] look.skin: 'teal' is not one of [\"light\", \"medium\", \"deep\"]"],
	]
	for case: Array in cases:
		var texts := _real_texts()
		var file: String = case[1]
		var data: Array = JSON.parse_string(texts[file])
		var mutate: Callable = case[2]
		mutate.call(data)
		texts[file] = JSON.stringify(data)
		var errors := _load_quietly(texts)
		# The expected error, or the expected errors in order when one mistake causes several.
		var expected: Array = case[3] if case[3] is Array else [case[3]]
		_check(errors == expected, "malformed data: " + case[0], "\n".join(errors))
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
## and Rush Hour buttons; with clean content the banner is hidden and both are enabled.
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
	_check((title.get_node("Column/RushButton") as Button).disabled, "title disables Rush Hour on content errors", "Rush Hour enabled")
	title.free()
	Content.reload()
	title = TITLE_SCENE.instantiate() as Title
	root.add_child(title)
	await process_frame
	banner = title.get_node("Column/ContentErrorBanner") as Label
	button = title.get_node("Column/OpenShopButton") as Button
	_check(not banner.visible and not button.disabled and not (title.get_node("Column/RushButton") as Button).disabled, "title with clean content has no banner, the shop and Rush Hour enabled", banner.text)
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


## SCHEMA.md I8 for days >= 2 on the loaded content and the story path `flags` (each
## day's customers are those whose `when` matches it), simulated from day 1's starting
## stock. A day starts with the stock any Perfect run of the day before can leave
## (every leftover is tried: the worst one counts). One problem per day N where, for
## some carried-over stock, the cheapest Perfect plan (an exact recipe per customer)
## buys more at day N's market (Economy.market_price) than day N-1's Perfect pay
## (Economy.pay, no tips, no other coins; story beats pay nothing, since they may be
## refused, but their ingredients count as used) covers. `levels[i]` is the level of
## day i + 1 (Difficulty.START_LEVEL past its end).
func _market_shortfalls(flags: Dictionary = {}, levels: Array = []) -> Array[String]:
	var problems: Array[String] = []
	var days := Content.days()
	var level := func(n: int) -> float: return levels[n] if n < levels.size() else Difficulty.START_LEVEL
	var carried: Array[Dictionary] = []
	for plan in _plans(days[0], flags, level.call(0)):
		if plan.keys().all(func(id: String) -> bool: return plan[id] <= days[0].starting_stock.get(id, 0)):
			_add_unique(carried, _leftover(days[0].starting_stock, plan))
	for n in range(1, days.size()):
		var spec := days[n]
		var budget := 0
		for customer in _customers(days[n - 1], flags, level.call(n - 1)):
			if customer.beat == "":
				budget += Economy.pay(Content.potion(customer.potion).price, Brew.Grade.PERFECT)
		var plans := _plans(spec, flags, level.call(n))
		if plans.is_empty() or carried.is_empty():
			problems.append("%s: %s" % [spec.id, "a customer has no exact recipe" if plans.is_empty() else "no Perfect day %d to carry stock over from" % days[n - 1].day])
			carried = []
			continue
		var next: Array[Dictionary] = []
		var worst := 0
		var worst_stock: Dictionary = {}
		for stock: Dictionary in carried:
			var cheapest := -1
			for plan in plans:
				var cost := 0
				for id: String in plan:
					cost += maxi(plan[id] - int(stock.get(id, 0)), 0) * Economy.market_price(spec, Content.ingredient(id))
				if cheapest < 0 or cost < cheapest:
					cheapest = cost
				if cost <= budget:
					_add_unique(next, _leftover(stock, plan))
			if cheapest > worst:
				worst = cheapest
				worst_stock = stock
		if worst > budget:
			problems.append("%s: with stock %s left from day %d, the cheapest exact recipes cost %d at its market, day %d Perfect pay is %d" % [spec.id, worst_stock, days[n - 1].day, worst, days[n - 1].day, budget])
		carried = next
	return problems


## The level of each story day: day 1 at Difficulty.START_LEVEL, each next one
## `step`(the level before).
func _level_trajectory(step: Callable) -> Array[float]:
	var levels: Array[float] = [Difficulty.START_LEVEL]
	while levels.size() < Content.days().size():
		levels.append(step.call(levels.back()))
	return levels


## Every distinct Perfect plan of `spec` on the story path `flags`: one exact recipe
## (ingredients unlocked by its day) per customer, as ingredient id -> count used.
func _plans(spec: DaySpec, flags: Dictionary = {}, level := Difficulty.START_LEVEL) -> Array[Dictionary]:
	var plans: Array[Dictionary] = [{}]
	var pool := Content.ingredients_unlocked_by(spec.day)
	for customer in _customers(spec, flags, level):
		var grown: Array[Dictionary] = []
		for plan in plans:
			for recipe in _exact_recipes(Content.potion(customer.potion).target, pool):
				var used := plan.duplicate()
				for id in recipe:
					used[id] = int(used.get(id, 0)) + 1
				_add_unique(grown, used)
		plans = grown
	return plans


## The customers of `spec` on the story path `flags` at difficulty `level`, as the shop
## runs them (Shift.story: the ordinary visitor slots filled).
## Memoized per DaySpec instance (a reload of the content makes new ones), path and level:
## the story checks ask for the same lists thousands of times.
func _customers(spec: DaySpec, flags: Dictionary, level: float) -> Array[DayCustomer]:
	var key := "%d|%s|%.2f" % [spec.get_instance_id(), flags, level]
	if not _shifts.has(key):
		_shifts[key] = Shift.story(spec.day, flags, level).customers
	return _shifts[key]


## What is left of `stock` after a plan using `used`, buying exactly what is missing.
func _leftover(stock: Dictionary, used: Dictionary) -> Dictionary:
	var left := stock.duplicate()
	for id: String in used:
		left[id] = maxi(int(stock.get(id, 0)), used[id]) - used[id]
	return left


func _add_unique(list: Array[Dictionary], item: Dictionary) -> void:
	for existing in list:
		if existing.recursive_equal(item, 1):
			return
	list.append(item)


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
