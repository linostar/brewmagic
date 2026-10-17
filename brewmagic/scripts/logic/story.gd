class_name Story
## The Guild Fair story rules (data/SCHEMA.md "Story"), static, no nodes: the outcome of a
## story beat, flag conditions on later customers and morning notes, and the ending.
## A beat's outcome is stored in Game.flags under its flag "<character>.<beat>"
## (DayCustomer.flag()); the story also keeps ENDING_FLAG and RUSH_HOUR_FLAG there.

## Every outcome a beat can have, in data order.
const OUTCOMES: Array[String] = ["great", "poor", "refused", "stormed_off"]
## The outcome of a beat with no recorded flag (a save from before the story existed,
## or a day opened out of order): the shop never served it.
const UNRECORDED := "refused"
## The beat whose great outcome grants the Guild licence.
const LICENCE_FLAG := "quill.fair"
## Reputation the Guild Master ending needs.
const GUILD_MASTER_REPUTATION := 30
const GUILD_MASTER := "guild_master"
const COSY_CORNER := "cosy_corner"
const CHARMING_CHAOS := "charming_chaos"
const ENDINGS: Array[String] = [GUILD_MASTER, COSY_CORNER, CHARMING_CHAOS]
## Flags the story keeps besides beat outcomes: the ending reached and the Rush Hour unlock.
const ENDING_FLAG := "ending"
const RUSH_HOUR_FLAG := "rush_hour_unlocked"


## The outcome a served brew of `grade` gives a beat: great for Perfect and Good, poor for Meh and Misbrew.
static func outcome_for(grade: Brew.Grade) -> String:
	return OUTCOMES[0] if grade == Brew.Grade.PERFECT or grade == Brew.Grade.GOOD else OUTCOMES[1]


## The recorded outcome of `flag` in `flags`, or UNRECORDED.
static func outcome(flags: Dictionary, flag: String) -> String:
	return str(flags.get(flag, UNRECORDED))


## True when every flag of `when` (flag -> allowed outcomes) has one of its outcomes in `flags`.
static func matches(when: Dictionary[String, PackedStringArray], flags: Dictionary) -> bool:
	for flag in when:
		if not outcome(flags, flag) in when[flag]:
			return false
	return true


## The customers of `spec` who come on the path `flags`, in arrival order.
static func customers_of(spec: DaySpec, flags: Dictionary) -> Array[DayCustomer]:
	var result: Array[DayCustomer] = []
	for customer in spec.customers:
		if matches(customer.when, flags):
			result.append(customer)
	return result


## The morning card of `spec` on the path `flags`: its first matching conditioned note, else morning_note.
static func morning_note(spec: DaySpec, flags: Dictionary) -> String:
	for note in spec.morning_notes:
		if matches(note["when"], flags):
			return note["text"]
	return spec.morning_note


## Every beat flag of the story, in day and arrival order, each once.
static func beat_flags() -> PackedStringArray:
	var flags := PackedStringArray()
	for spec in Content.days():
		for customer in spec.customers:
			if customer.beat != "" and not customer.flag() in flags:
				flags.append(customer.flag())
	return flags


## The flags of the last story day's beats: each story character's final beat.
static func final_flags() -> PackedStringArray:
	var flags := PackedStringArray()
	var days := Content.days()
	if days.is_empty():
		return flags
	for customer in days[-1].customers:
		if customer.beat != "" and not customer.flag() in flags:
			flags.append(customer.flag())
	return flags


## The ending the story reaches (one of ENDINGS): the licence is granted when LICENCE_FLAG
## is great; an arc is resolved when its character's final beat (final_flags) is great.
##   GUILD_MASTER: licence, every arc resolved, reputation >= GUILD_MASTER_REPUTATION.
##   COSY_CORNER: licence and at least two arcs resolved.
##   CHARMING_CHAOS: anything else.
static func ending(flags: Dictionary, reputation: int) -> String:
	var finals := final_flags()
	var resolved := 0
	for flag in finals:
		if outcome(flags, flag) == OUTCOMES[0]:
			resolved += 1
	var licence := outcome(flags, LICENCE_FLAG) == OUTCOMES[0]
	if licence and resolved == finals.size() and reputation >= GUILD_MASTER_REPUTATION:
		return GUILD_MASTER
	if licence and resolved >= 2:
		return COSY_CORNER
	return CHARMING_CHAOS
