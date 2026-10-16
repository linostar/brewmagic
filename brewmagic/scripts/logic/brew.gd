class_name Brew
## Pure brewing rules (data/SCHEMA.md "Game rules the data relies on"): combine
## ingredient essences, match against a potion target, pick the misbrew essence,
## and blend the match tier with the gesture quality from the stations into the
## final grade. Static only, no nodes; works on Vector4i essence vectors
## (ember, frost, bloom, gloom) so it does not depend on the Content classes.

## Match tier and final grade, best first.
enum Grade { PERFECT, GOOD, MEH, MISBREW }

## Gesture quality (0..1) a station result needs to keep a Perfect match Perfect.
const PERFECT_QUALITY := 0.9
## Gesture quality a station result needs to keep a Good match Good. Assist mode
## completes every station with exactly this (Station.ASSIST_QUALITY).
const GOOD_QUALITY := 0.6


## Element-wise sum of the ingredients' essence vectors.
static func combine(essences: Array[Vector4i]) -> Vector4i:
	var total := Vector4i.ZERO
	for essence in essences:
		total += essence
	return total


## L1 distance between a brew and a potion target.
static func distance(brew: Vector4i, target: Vector4i) -> int:
	var diff := (brew - target).abs()
	return diff.x + diff.y + diff.z + diff.w


## 0 Perfect, 1 Good, 2 Meh, 3 or more Misbrew.
static func match_tier(match_distance: int) -> Grade:
	if match_distance <= 0:
		return Grade.PERFECT
	if match_distance == 1:
		return Grade.GOOD
	if match_distance == 2:
		return Grade.MEH
	return Grade.MISBREW


## The essence index (0..3) with the largest overshoot brew[k] - target[k] > 0;
## ties go to the lowest index. Returns -1 and reports an error when nothing
## overshoots (the data guarantees every misbrew overshoots, SCHEMA.md I9).
static func misbrew_essence(brew: Vector4i, target: Vector4i) -> int:
	var best := -1
	var best_overshoot := 0
	for k in 4:
		var overshoot := brew[k] - target[k]
		if overshoot > best_overshoot:
			best = k
			best_overshoot = overshoot
	if best < 0:
		push_error("[Brew] No essence overshoots: brew %s, target %s" % [brew, target])
	return best


## Mean of the station qualities of one brew. Reports an error and returns 0.0
## for an empty list (every potion has at least one step).
static func gesture_quality(qualities: Array[float]) -> float:
	if qualities.is_empty():
		push_error("[Brew] gesture_quality called without station results")
		return 0.0
	var total := 0.0
	for quality in qualities:
		total += quality
	return total / qualities.size()


## Final grade from the match tier and the gesture quality:
##   Perfect match: Perfect if quality >= PERFECT_QUALITY, else Good.
##   Good match:    Good if quality >= GOOD_QUALITY, else Meh.
##   Meh, Misbrew:  unchanged.
## Gestures can only cost one grade and never raise one, and never turn a brew
## into a Misbrew (a Meh brew may have no overshooting essence).
static func final_grade(tier: Grade, quality: float) -> Grade:
	match tier:
		Grade.PERFECT:
			return Grade.PERFECT if quality >= PERFECT_QUALITY else Grade.GOOD
		Grade.GOOD:
			return Grade.GOOD if quality >= GOOD_QUALITY else Grade.MEH
		_:
			return tier
