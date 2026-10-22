class_name Rush
## Rush Hour's rules (static, no nodes): the spawn curve, the potion waves, the
## run's starting reputation and the endless customer source. Everything follows
## the run's served count, so the pressure grows with the player's pace.

## The run's reputation at the start; the run ends when it reaches 0.
const START_REPUTATION := 5
## Seconds between arrivals while the line has room: GAP_START at first, GAP_STEP
## less per customer served, never under GAP_FLOOR.
const GAP_START := 8.0
const GAP_STEP := 0.25
const GAP_FLOOR := 3.0
## Every customer's patience scale: PATIENCE_START at first, PATIENCE_STEP less per
## customer served, never under PATIENCE_FLOOR.
const PATIENCE_START := 1.2
const PATIENCE_STEP := 0.02
const PATIENCE_FLOOR := 0.8
## Customers served per wave; wave i allows the potions unlocked by story day
## WAVE_DAYS[i] (Stir and Pour, + Mortar, + Bellows, everything); the last wave lasts.
const WAVE_SIZE := 5
const WAVE_DAYS: Array[int] = [1, 4, 7, 13]
## Each wave's banner: its number in words (the banner's Silkscreen draws no digits)
## and what it adds. It names the stations, never the potions (requests never do).
const WAVE_NAMES: Array[String] = ["WAVE ONE", "WAVE TWO", "WAVE THREE", "WAVE FOUR"]
const WAVE_NOTES: Array[String] = ["Stir and pour potions", "New: potions for the mortar", "New: potions for the bellows", "New: the rare potions"]


## The run's reputation change for a delivered `grade`: only the story's losses
## (Economy.reputation_delta below 0, a Misbrew); a good serve never raises it, so
## every run heads for its end however well it goes.
static func reputation_delta(grade: Brew.Grade) -> int:
	return mini(Economy.reputation_delta(grade), 0)


static func arrival_gap(served: int) -> float:
	return maxf(GAP_START - GAP_STEP * served, GAP_FLOOR)


static func patience_scale(served: int) -> float:
	return maxf(PATIENCE_START - PATIENCE_STEP * served, PATIENCE_FLOOR)


## The wave (0-based) a run is in after `served` customers.
static func wave(served: int) -> int:
	return mini(floori(served / float(WAVE_SIZE)), WAVE_DAYS.size() - 1)


## The potions customers of wave `index` may ask for: those unlocked by WAVE_DAYS[index]
## that some ordinary archetype has a request for (story characters never visit).
static func potions_of_wave(index: int) -> Array[PotionType]:
	var potions: Array[PotionType] = []
	potions.assign(Content.potions_unlocked_by(WAVE_DAYS[clampi(index, 0, WAVE_DAYS.size() - 1)]).filter(
		func(potion: PotionType) -> bool: return not voices_for(potion).is_empty()))
	return potions


## The ordinary archetypes (never a story character) with a request for `potion`.
static func voices_for(potion: PotionType) -> Array[Archetype]:
	var voices: Array[Archetype] = []
	voices.assign(Content.archetypes().filter(
		func(who: Archetype) -> bool: return not who.is_story() and not Content.requests_for(potion.id, who.id).is_empty()))
	return voices


## The next customer of a run after `served` customers, drawn from `rng`: a potion of
## the current wave, an ordinary archetype with a request for it, and one of those
## requests (pinned). Deterministic for a given rng state.
static func customer(rng: RandomNumberGenerator, served: int) -> DayCustomer:
	var potions := potions_of_wave(wave(served))
	return visit(potions[rng.randi_range(0, potions.size() - 1)], rng)


## An ordinary visitor who wants `potion`: an ordinary archetype with a request for it
## and one of those requests (pinned), drawn from `rng`. Also the story's ordinary
## visitors (Shift.story).
static func visit(potion: PotionType, rng: RandomNumberGenerator) -> DayCustomer:
	var voices := voices_for(potion)
	var visitor := DayCustomer.new()
	visitor.potion = potion.id
	visitor.archetype = voices[rng.randi_range(0, voices.size() - 1)].id
	var lines := Content.requests_for(potion.id, visitor.archetype)
	visitor.request = lines[rng.randi_range(0, lines.size() - 1)].id
	return visitor
