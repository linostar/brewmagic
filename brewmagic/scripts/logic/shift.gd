class_name Shift
## Builds the ShiftConfig a shop shift runs (static, no nodes).


## The shift of story day `number` from data/days.json, or null when there is no such day
## (Content.day reports it).
static func story(number: int) -> ShiftConfig:
	var spec := Content.day(number)
	if spec == null:
		return null
	var config := ShiftConfig.new()
	config.mode = ShiftConfig.Mode.STORY
	config.day = spec.day
	config.title = spec.title
	config.customers = spec.customers.duplicate()
	config.allowed_potions = Content.potions_unlocked_by(spec.day)
	config.ingredients = Content.ingredients_unlocked_by(spec.day)
	config.patience_scale = spec.patience_scale
	return config
