class_name Difficulty
## Adaptive difficulty of the story (static, no nodes). After every story day the
## shop's results become a day score (day_score), which moves a skill rating
## (next_rating, a moving average), which moves the difficulty level (next_level). The
## level sets the next story day's four knobs: patience, the gap between arrivals,
## the stations' tolerance and how often ordinary visitors ask for hard recipes.
## Rush Hour runs never touch the rating or the level (Rush has its own curve).

## Day score parts: the mean grade (GRADE_SCORES per Brew.Grade; a customer who stormed
## off or was refused scores 0), the speed (mean fraction of patience left at delivery;
## a storm-off counts 0) and the mean gesture quality of the stations played by gesture
## (an Assist press is no measure of skill, so those are left out; with none at all the
## gesture weight is shared out over the other two).
const GRADE_SCORES: Array[float] = [1.0, 0.67, 0.33, 0.0]
const WEIGHT_GRADE := 0.5
const WEIGHT_SPEED := 0.25
const WEIGHT_GESTURE := 0.25
## The rating starts in the middle and moves RATING_SMOOTHING of the way to each day's score.
const START_RATING := 0.5
const RATING_SMOOTHING := 0.5
## The level starts at 0 (the authored days), rises each day by a slope from SLOPE_MIN
## (rating LOW_RATING: a struggling player still gets a gently harder shop) to SLOPE_MAX
## (rating 1), falls by FALL_STEP while the rating is under LOW_RATING, and stays in
## LEVEL_MIN..LEVEL_MAX (below 0 is kinder than the authored days).
const START_LEVEL := 0.0
const LOW_RATING := 0.3
const SLOPE_MIN := 0.02
const SLOPE_MAX := 0.1
const FALL_STEP := 0.05
const LEVEL_MIN := -0.3
const LEVEL_MAX := 1.0
## Knobs, each linear in the level and clamped:
## patience scale (times the day's own): PATIENCE_START at level 0, PATIENCE_PER_LEVEL per
## level, never under PATIENCE_FLOOR (data/SCHEMA.md I15 holds at it: 50 s x 1.0 x 0.92 -
## 12.5 s in line = 33.5 s at the counter);
const PATIENCE_START := 1.1
const PATIENCE_PER_LEVEL := -0.18
const PATIENCE_FLOOR := 0.92
const PATIENCE_CEILING := 1.16
## seconds between arrivals while the line has room;
const GAP_START := 8.0
const GAP_PER_LEVEL := -2.0
const GAP_FLOOR := 6.0
const GAP_CEILING := 8.6
## the stations' tolerance multiplier (times upgrades and Gentle mode), never under TOLERANCE_FLOOR;
const TOLERANCE_PER_LEVEL := -0.2
const TOLERANCE_FLOOR := 0.8
const TOLERANCE_CEILING := 1.06
## an ordinary visitor's potion weight exp(HARDNESS_BIAS x level x hardness), hardness 0..1
## (hardness()), so level 0 picks evenly, higher levels lean to hard recipes and negative
## levels to easy ones; a potion new that day weighs NEW_POTION_WEIGHT times more.
const HARDNESS_BIAS := 2.0
const NEW_POTION_WEIGHT := 3.0


## The day's score in 0..1. `grades`: a count per Brew.Grade of the customers served;
## `stormed_off`, `refused`: how many left unserved; `patience_left`: per delivery the
## fraction of patience left (0 per storm-off); `gestures`: the qualities of the stations
## played by gesture (no Assist press).
static func day_score(grades: Array[int], stormed_off: int, refused: int, patience_left: Array[float], gestures: Array[float]) -> float:
	var visits := stormed_off + refused
	var grade_total := 0.0
	for grade in grades.size():
		visits += grades[grade]
		grade_total += grades[grade] * GRADE_SCORES[grade]
	var grade_part := grade_total / visits if visits > 0 else 0.0
	var speed_part := _mean(patience_left)
	if gestures.is_empty():
		return (grade_part * WEIGHT_GRADE + speed_part * WEIGHT_SPEED) / (WEIGHT_GRADE + WEIGHT_SPEED)
	return grade_part * WEIGHT_GRADE + speed_part * WEIGHT_SPEED + _mean(gestures) * WEIGHT_GESTURE


static func next_rating(rating: float, score: float) -> float:
	return clampf(rating + (score - rating) * RATING_SMOOTHING, 0.0, 1.0)


## The level after a day that left the rating at `rating`.
static func next_level(level: float, rating: float) -> float:
	if rating < LOW_RATING:
		return clampf(level - FALL_STEP, LEVEL_MIN, LEVEL_MAX)
	return clampf(level + lerpf(SLOPE_MIN, SLOPE_MAX, inverse_lerp(LOW_RATING, 1.0, rating)), LEVEL_MIN, LEVEL_MAX)


static func patience_scale(level: float) -> float:
	return clampf(PATIENCE_START + PATIENCE_PER_LEVEL * level, PATIENCE_FLOOR, PATIENCE_CEILING)


static func arrival_gap(level: float) -> float:
	return clampf(GAP_START + GAP_PER_LEVEL * level, GAP_FLOOR, GAP_CEILING)


static func tolerance_scale(level: float) -> float:
	return clampf(1.0 + TOLERANCE_PER_LEVEL * level, TOLERANCE_FLOOR, TOLERANCE_CEILING)


## How hard `potion` is to brew, 0..1: its stations beyond Stir and Pour (0..2) plus its
## smallest exact recipe's ingredients beyond 2 (0..1), over 3.
static func hardness(potion: PotionType) -> float:
	return clampf((potion.steps.size() - 2 + recipe_size(potion) - Brew.MIN_INGREDIENTS) / 3.0, 0.0, 1.0)


## The fewest ingredients (2 or 3, those unlocked by the potion's day) that brew `potion`
## exactly (data/SCHEMA.md I7 guarantees one); MAX_INGREDIENTS + 1 when none does.
static func recipe_size(potion: PotionType) -> int:
	var shelf := Content.ingredients_unlocked_by(potion.unlock_day)
	for a in shelf.size():
		for b in range(a, shelf.size()):
			var pair := shelf[a].essence + shelf[b].essence
			if pair == potion.target:
				return 2
			for c in range(b, shelf.size()):
				if pair + shelf[c].essence == potion.target:
					return 3
	return Brew.MAX_INGREDIENTS + 1


## The pick weight of `potion` for an ordinary visitor of story day `day` at `level`.
static func potion_weight(potion: PotionType, level: float, day: int) -> float:
	return exp(HARDNESS_BIAS * level * hardness(potion)) * (NEW_POTION_WEIGHT if potion.unlock_day == day else 1.0)


## One of `potions` drawn from `rng` by `weights` (same order, all > 0).
static func pick(rng: RandomNumberGenerator, potions: Array[PotionType], weights: PackedFloat32Array) -> PotionType:
	return potions[rng.rand_weighted(weights)]


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()
