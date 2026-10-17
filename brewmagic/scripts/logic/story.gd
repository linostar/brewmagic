class_name Story
## The Guild Fair story rules (data/SCHEMA.md "Story"), static, no nodes: the outcome of a
## story beat, flag conditions on later customers and morning notes, and the ending.
## A beat's outcome is stored in Game.flags under its flag "<character>.<beat>"
## (DayCustomer.flag()); nothing else is kept there (the endings reached and the Rush
## Hour unlock outlive a story, in Game.endings and Game.rush_hour_unlocked).

## A beat's outcomes: served Perfect or Good, served Meh or Misbrew, refused, stormed off.
const GREAT := "great"
const POOR := "poor"
const REFUSED := "refused"
const STORMED_OFF := "stormed_off"
## Every outcome a beat can have, in data order.
const OUTCOMES: Array[String] = [GREAT, POOR, REFUSED, STORMED_OFF]
## The outcome of a beat with no recorded flag (a save from before the story existed,
## or a day opened out of order): the shop never served it.
const UNRECORDED := REFUSED
## The beat whose great outcome grants the Guild licence.
const LICENCE_FLAG := "quill.fair"
## Reputation the Guild Master ending needs.
const GUILD_MASTER_REPUTATION := 30
const GUILD_MASTER := "guild_master"
const COSY_CORNER := "cosy_corner"
const CHARMING_CHAOS := "charming_chaos"
const ENDINGS: Array[String] = [GUILD_MASTER, COSY_CORNER, CHARMING_CHAOS]


## The outcome a served brew of `grade` gives a beat: great for Perfect and Good, poor for Meh and Misbrew.
static func outcome_for(grade: Brew.Grade) -> String:
	return GREAT if grade == Brew.Grade.PERFECT or grade == Brew.Grade.GOOD else POOR


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


## What is wrong with a saved `flags` dictionary, or "": every key must be a beat flag of
## the story (beat_flags) with an outcome of OUTCOMES.
static func flags_problem(flags: Dictionary) -> String:
	var beats := beat_flags()
	for key: Variant in flags:
		var value: Variant = flags[key]
		if typeof(key) != TYPE_STRING:
			return "flags has a key that is not a string: %s" % key
		if key in beats:
			if typeof(value) != TYPE_STRING or not value in OUTCOMES:
				return "flags.%s is %s, not one of %s" % [key, value, OUTCOMES]
		else:
			return "flags has unknown flag '%s'" % key
	return ""


## The ending the story reaches (one of ENDINGS): the licence is granted when LICENCE_FLAG
## is great; an arc is resolved when its character's final beat (final_flags) is great.
##   GUILD_MASTER: licence, every arc resolved, reputation >= GUILD_MASTER_REPUTATION.
##   COSY_CORNER: any other granted licence.
##   CHARMING_CHAOS: the licence refused (its pages say so).
static func ending(flags: Dictionary, reputation: int) -> String:
	if outcome(flags, LICENCE_FLAG) != GREAT:
		return CHARMING_CHAOS
	for flag in final_flags():
		if outcome(flags, flag) != GREAT:
			return COSY_CORNER
	return GUILD_MASTER if reputation >= GUILD_MASTER_REPUTATION else COSY_CORNER
