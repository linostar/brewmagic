class_name Shift
## Builds the ShiftConfig a shop shift runs (static, no nodes).


## The shift of story day `number` from data/days.json on the story path `flags` (beat
## outcomes, Game.flags) at difficulty `level` (Game.difficulty): the day's customers whose
## `when` matches them (Story.customers_of), each ordinary visitor slot (DayCustomer
## is_generated) filled from the day's potions (those with an ordinary voice, Rush.voices_for):
## first the potions new that day that no authored customer of the day asks for, in file
## order, then picks (Difficulty.pick_for) that bring the day's mean stations per customer
## to Difficulty.target_stations, each preferring a potion not yet ordered that day nor (with
## `avoid_yesterday`) on the day before at this level, voiced by Rush.visit, all from a generator seeded by the
## day and the level, so a day replays alike. The level also sets the patience (times the day's), the arrival gap and
## the stations' tolerance. Null when there is no such day (Content.day reports it).
static func story(number: int, flags: Dictionary = {}, level := Difficulty.START_LEVEL, avoid_yesterday := true) -> ShiftConfig:
	var spec := Content.day(number)
	if spec == null:
		return null
	var config := ShiftConfig.new()
	config.mode = ShiftConfig.Mode.STORY
	config.day = spec.day
	config.title = spec.title
	config.allowed_potions = Content.potions_unlocked_by(spec.day)
	config.ingredients = Content.ingredients_unlocked_by(spec.day)
	config.patience_scale = spec.patience_scale * Difficulty.patience_scale(level)
	config.story_arrival_gap = Difficulty.arrival_gap(level)
	config.tolerance_scale = Difficulty.tolerance_scale(level)
	var pool: Array[PotionType] = []
	pool.assign(config.allowed_potions.filter(func(potion: PotionType) -> bool: return not Rush.voices_for(potion).is_empty()))
	var visits := Story.customers_of(spec, flags)
	var asked := visits.map(func(customer: DayCustomer) -> String: return customer.potion)
	var fresh := pool.filter(func(potion: PotionType) -> bool: return potion.unlock_day == spec.day and not potion.id in asked)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([spec.day, roundi(level * 100.0)])
	# Stations still owed to reach the day's target, and the visitor slots left to owe them.
	var owed := Difficulty.target_stations(level, spec.day) * visits.size()
	var slots := 0
	for customer in visits:
		if customer.is_generated():
			slots += 1
		else:
			owed -= Content.potion(customer.potion).steps.size()
	# Variety: a slot's pick skips the potions already ordered today and, while others are
	# left, those of the day before (its shift at this level, without its own day before).
	var today := PackedStringArray(asked)
	var yesterday := PackedStringArray()
	var before := story(number - 1, flags, level, false) if avoid_yesterday and number > Content.FIRST_DAY else null
	if before != null:
		for customer in before.customers:
			yesterday.append(customer.potion)
	var generated := 0
	for customer in visits:
		if not customer.is_generated():
			config.customers.append(customer)
			continue
		var potion: PotionType = fresh[generated] if generated < fresh.size() else Difficulty.pick_for(rng, pool, owed / (slots - generated), [today, yesterday])
		today.append(potion.id)
		owed -= potion.steps.size()
		generated += 1
		var visitor := Rush.visit(potion, rng)
		visitor.when = customer.when
		config.customers.append(visitor)
	return config


## A Rush Hour run: endless customers drawn by Rush.customer from the shop's
## RandomNumberGenerator seeded with `run_seed`, every ingredient on the shelf with
## unlimited stock, the potions of each wave (Rush.potions_of_wave) and the curve's
## patience scale (Rush.patience_scale; this field holds its starting value).
static func rush(run_seed: int) -> ShiftConfig:
	var config := ShiftConfig.new()
	config.mode = ShiftConfig.Mode.RUSH
	config.day = 0
	config.title = "Rush Hour"
	config.run_seed = run_seed
	config.allowed_potions = Rush.potions_of_wave(Rush.WAVE_DAYS.size() - 1)
	config.ingredients = Content.ingredients()
	config.patience_scale = Rush.PATIENCE_START
	return config
