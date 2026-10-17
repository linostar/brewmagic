class_name Shift
## Builds the ShiftConfig a shop shift runs (static, no nodes).


## The shift of story day `number` from data/days.json on the story path `flags` (beat
## outcomes, Game.flags): the day's customers whose `when` matches them (Story.customers_of).
## Null when there is no such day (Content.day reports it).
static func story(number: int, flags: Dictionary = {}) -> ShiftConfig:
	var spec := Content.day(number)
	if spec == null:
		return null
	var config := ShiftConfig.new()
	config.mode = ShiftConfig.Mode.STORY
	config.day = spec.day
	config.title = spec.title
	config.customers = Story.customers_of(spec, flags)
	config.allowed_potions = Content.potions_unlocked_by(spec.day)
	config.ingredients = Content.ingredients_unlocked_by(spec.day)
	config.patience_scale = spec.patience_scale
	return config
