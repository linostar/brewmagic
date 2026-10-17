class_name GameState
extends Node
## Autoload "Game" (scenes/game.tscn): the app flow state machine and its
## scene transitions, the player's progress and settings with their save in
## user://, plus ScreenFit (the visible and safe-area rects in base units and the
## centred 270-wide gameplay column).
## Story flow: title -> morning -> shop -> summary -> market -> morning (next day) ...
## -> the last day's summary -> ending (finish_story) -> title.
## The shop commits a finished day with finish_day(); quitting mid-shift keeps the
## progress from before that day.
## Every flow change goes through goto(), which fades out, swaps the scene,
## fades in and logs the transition. A flow state whose scene is missing is
## reported with push_error and a visible error label instead of crashing; a
## scene that cannot start redirects with abort_to().
##
## Sound: play_sfx() plays on the SFX bus (default_bus_layout.tres). Browsers
## refuse audio before the player's first input, so nothing plays until the
## AudioUnlock child (scripts/ui/audio_unlock.gd) reports that input (unlock_audio).

signal transition_finished(state: Flow)
## Emitted when the visible rect or the safe area changes (resize, rotation).
signal screen_fit_changed

enum Flow { TITLE, MORNING, SHOP, SUMMARY, MARKET, ENDING }

## Where the autoload lives. Scripts fetch it through this path instead of the
## global "Game" name, which does not exist yet when test scripts compile.
const AUTOLOAD_PATH := ^"/root/Game"
const SCENE_PATHS: Dictionary[Flow, String] = {
	Flow.TITLE: "res://scenes/title.tscn",
	Flow.MORNING: "res://scenes/morning.tscn",
	Flow.SHOP: "res://scenes/shop.tscn",
	Flow.SUMMARY: "res://scenes/summary.tscn",
	Flow.MARKET: "res://scenes/market.tscn",
	Flow.ENDING: "res://scenes/ending_screen.tscn",
}
## Seconds for each half of a transition (fade out, then fade in).
const FADE_TIME := 0.18
## Width of the gameplay column in base units (the base viewport width).
const COLUMN_WIDTH := 270.0
## Station tolerance multiplier while Gentle mode is on.
const GENTLE_TOLERANCE_SCALE := 1.5
const SFX_BUS := &"SFX"
## Sound effects that may overlap (voice blips, later the rest of the SFX).
const SFX_VOICES := 4
## The audio driver of headless runs (no device, never mixes).
const SILENT_AUDIO_DRIVER := "Dummy"
const SAVE_PATH := "user://save.json"
## The save of tool runs (see _ready); tests delete it when they finish.
const TOOL_SAVE_PATH := "user://tool_save.json"
## The save format's version. Every change to the format bumps it and appends one
## step to save_migrations(), so saves of older versions are upgraded, not discarded.
const SAVE_VERSION := 2
## Upper bounds a save's numbers must respect (anything else marks it corrupt);
## SAVE_SCORE_MAX bounds reputation (either sign) and rush_best.
const SAVE_COINS_MAX := 999999
const SAVE_STOCK_MAX := 9999
const SAVE_SCORE_MAX := 999999
## The largest whole number a JSON (double) number holds exactly: 2^53.
const SAVE_EXACT_MAX := 9007199254740992.0
## The keys of a save, each with the type its value must have.
const SAVE_KEYS: Dictionary[String, Variant.Type] = {
	"version": TYPE_INT, "day": TYPE_INT, "at_market": TYPE_BOOL, "coins": TYPE_INT, "reputation": TYPE_INT,
	"stock": TYPE_DICTIONARY, "upgrades": TYPE_DICTIONARY, "codex": TYPE_DICTIONARY, "flags": TYPE_DICTIONARY,
	"endings": TYPE_ARRAY, "rush_hour_unlocked": TYPE_BOOL, "rush_best": TYPE_INT, "settings": TYPE_DICTIONARY,
}
## Version 1 kept these in flags (moved out by the version 2 step of save_migrations).
const V1_ENDING_FLAG := "ending"
const V1_RUSH_HOUR_FLAG := "rush_hour_unlocked"
## A version 1 save from the two-day build at this day (market closed, no flags) had
## finished that build's story; the version 2 step reopens the market before it.
const V1_STORY_OVER_DAY := 3
const SETTINGS_KEYS: Array[String] = ["assist", "gentle"]
const CODEX_WORDS := "words"
const CODEX_RECIPES := "recipes"

## Settings, persisted in the save. Stations read them through the shop when they begin.
var assist_mode := false
var gentle_mode := false

## Progress, persisted in the save. `day` is the story day the next morning shows
## (past the last day once the story is done); `at_market` means the evening market
## before `day` is still open (Continue resumes there).
var day := Content.FIRST_DAY
var at_market := false
var coins := 0
var reputation := 0
## Ingredient id -> count in the shop's stock (carried over between days).
var stock: Dictionary[String, int] = {}
## Station step id -> owned upgrade level (absent means 0).
var upgrades: Dictionary[String, int] = {}
## The Codex: what the player has learned, as saved (kept by new_game: the player's
## knowledge outlives a story). CODEX_WORDS: the hint word ids served so far
## (learn_words); CODEX_RECIPES: potion id -> the ingredient ids of a brew of it at
## Good or better (learn_recipe). Read it through codex_words() and codex_recipes();
## an empty dictionary is an empty Codex.
var codex: Dictionary = {}
## This story's flags (Story): each beat's outcome under "<character>.<beat>".
var flags: Dictionary = {}
## The endings reached in any story (Story.ENDINGS ids, each once, in the order first
## reached) and the Rush Hour unlock; like the Codex, new_game keeps them.
var endings: Array[String] = []
var rush_hour_unlocked := false
## Filled in plan step 8.
var rush_best := 0
## Where the save lives: SAVE_PATH, or TOOL_SAVE_PATH in tool runs.
var save_path := SAVE_PATH

## Tests replace entries to point a state at their own (or a missing) scene.
var scene_paths: Dictionary[Flow, String] = SCENE_PATHS.duplicate()
## Tests set quiet_errors to assert on expected errors without failing the log check.
var quiet_errors := false
var reported_errors: Array[String] = []
## Every transition, as logged, oldest first.
var transition_log: Array[String] = []

var state := Flow.TITLE
## The args of the latest goto(); the new scene reads them in its _ready().
var flow_args: Dictionary = {}
## True once the player has touched, clicked or pressed a key (sound may play).
var audio_unlocked := false
## How many play_sfx() calls played (tests count voice blips with it).
var sfx_played := 0

var _transitioning := false
var _visible_rect := Rect2()
var _safe_rect := Rect2()
var _sfx: AudioStreamPlayer
var _told_audio_locked := false

@onready var _curtain: ColorRect = $Fade/Curtain
@onready var _error_label: Label = $Fade/ErrorLabel


func _ready() -> void:
	if AudioServer.get_bus_index(SFX_BUS) < 0:
		push_error("[Game] Audio bus '%s' is missing from default_bus_layout.tres; sound effects play on Master" % SFX_BUS)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "Sfx"
	_sfx.bus = SFX_BUS
	_sfx.max_polyphony = SFX_VOICES
	add_child(_sfx)
	# Tool runs (the tests, the project check, the headless main-scene run) drive the
	# tree from a SceneTree script; they must never read or overwrite the player's save.
	if get_tree().get_script() != null:
		save_path = TOOL_SAVE_PATH
	load_game()
	_fit_window()
	get_viewport().size_changed.connect(_update_screen_fit)
	_update_screen_fit()


## Desktop windows are sized in physical pixels, so on a high-density screen
## (a 2x Retina display) the project's window size would show at half size,
## and on a small screen it may not fit. Applies `fit_window_rect()`. The web
## build fills its page and a game embedded in the editor is sized by the
## editor, so both are left alone.
func _fit_window() -> void:
	var window := get_window()
	if OS.has_feature("web") or Engine.is_embedded_in_editor() or window.mode != Window.MODE_WINDOWED:
		return
	var density := DisplayServer.screen_get_scale(window.current_screen)
	var fitted := fit_window_rect(window.size, density, DisplayServer.screen_get_usable_rect(window.current_screen),
		window.get_size_with_decorations() - window.size, window.position - window.get_position_with_decorations())
	if fitted.size == window.size:
		return
	window.size = fitted.size
	window.position = fitted.position
	print("[Game] Fitted the window to a %.1fx screen: %s" % [density, fitted])


## The client rect for a window of `base` screen points on a screen of
## `density`: scaled to pixels, shrunk (keeping its aspect) until it fits the
## `usable` screen rect together with its frame (`frame_size` = framed minus
## client size, `client_offset` = client position inside the frame), and placed
## so the framed window is centred in the usable rect.
static func fit_window_rect(base: Vector2i, density: float, usable: Rect2i, frame_size: Vector2i, client_offset: Vector2i) -> Rect2i:
	var room := Vector2(usable.size - frame_size)
	var wanted := Vector2(base) * density
	wanted *= minf(1.0, minf(room.x / wanted.x, room.y / wanted.y))
	var client := Vector2i(wanted)
	var framed_position := usable.position + Vector2i(Vector2(usable.size - client - frame_size) / 2.0)
	return Rect2i(framed_position + client_offset, client)


## Fades to the scene of `new_state`, passing `args` through flow_args.
## Ignored (with a log line) while a transition is running.
func goto(new_state: Flow, args: Dictionary = {}) -> void:
	var path: String = scene_paths[new_state]
	var from_name: String = Flow.keys()[state]
	var to_name: String = Flow.keys()[new_state]
	if _transitioning:
		print("[Game] Ignored goto %s while a transition is running" % to_name)
		return
	if not ResourceLoader.exists(path):
		_report_error("Cannot go to %s: scene '%s' does not exist" % [to_name, path])
		return
	_transitioning = true
	_log_transition("%s -> %s (%s) args=%s" % [from_name, to_name, path, args])
	_error_label.hide()
	await _fade(1.0)
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_report_error("Failed to load scene '%s' for %s: %s" % [path, to_name, error_string(error)])
		await _fade(0.0)
		_transitioning = false
		return
	state = new_state
	flow_args = args
	await _fade(0.0)
	_transitioning = false
	print("[Game] Arrived at %s" % to_name)
	transition_finished.emit(new_state)


## For a scene that cannot start (it calls this from its _ready, during the
## transition into it): goes to `fallback` once that transition has finished,
## then reports `message` (log and the visible error label) on the fallback screen.
func abort_to(fallback: Flow, message: String) -> void:
	if _transitioning:
		await transition_finished
	await goto(fallback)
	_report_error(message)


## Called on the player's first input; from then on play_sfx() plays.
func unlock_audio() -> void:
	if audio_unlocked:
		return
	audio_unlocked = true
	print("[Game] Audio unlocked by the first input")


## Plays `stream` on the SFX bus at `pitch`. Before the first input (audio_unlocked)
## it plays nothing (logged once), so browsers never see an autoplay attempt.
## Without an audio device (the Dummy driver of headless runs) it only counts: that
## driver never mixes, so its playbacks would never finish and leak at exit.
func play_sfx(stream: AudioStream, pitch := 1.0) -> void:
	if not audio_unlocked:
		if not _told_audio_locked:
			print("[Game] Sound skipped until the first input unlocks audio")
			_told_audio_locked = true
		return
	sfx_played += 1
	if AudioServer.get_driver_name() == SILENT_AUDIO_DRIVER:
		return
	if _sfx.stream != stream:
		_sfx.stream = stream
	_sfx.pitch_scale = pitch
	_sfx.play()


func is_transitioning() -> bool:
	return _transitioning


## The Station tolerance_scale for station step `step` ("stir", ...): its owned
## upgrade's multiplier, times GENTLE_TOLERANCE_SCALE while Gentle mode is on.
func tolerance_scale(step: String) -> float:
	var gentle := GENTLE_TOLERANCE_SCALE if gentle_mode else 1.0
	var upgrade := Content.upgrade_for(step)
	if upgrade == null:
		return gentle
	return Economy.upgrade_tolerance(upgrade, upgrades.get(step, 0)) * gentle


## Starts a new story from day 1's starting coins and stock and saves it. What
## outlives a story stays: the settings, the Codex, the endings reached, the Rush Hour
## unlock and its best.
func new_game() -> void:
	var best := rush_best
	var kept_codex := codex
	var kept_endings := endings
	var unlocked := rush_hour_unlocked
	_reset_progress()
	rush_best = best
	codex = kept_codex
	endings = kept_endings
	rush_hour_unlocked = unlocked
	var first := Content.day(Content.FIRST_DAY)
	if first != null:
		coins = first.starting_coins
		stock = first.starting_stock.duplicate()
	print("[Game] New game: day %d, %d coins, stock %s" % [day, coins, stock])
	save_game()


## True when a saved story can be resumed: past day 1 and not past the last day.
func can_continue() -> bool:
	return day > Content.FIRST_DAY and day <= Content.days().size()


## Resumes the saved story: the open market, else the morning of `day`.
func continue_game() -> void:
	goto(Flow.MARKET if at_market else Flow.MORNING)


## The shop's end of day: commits the day's coins, stock, reputation change and story
## beat outcomes (flag -> Story outcome, into flags), moves on to the next day (its
## market opens when that day exists), saves, and shows the summary with `result`
## (Shop.day_result()).
func finish_day(result: Dictionary, coins_now: int, stock_now: Dictionary[String, int], reputation_change: int, story_outcomes: Dictionary[String, String] = {}) -> void:
	coins = coins_now
	for id in stock_now:
		stock[id] = stock_now[id]
	reputation += reputation_change
	for flag in story_outcomes:
		flags[flag] = story_outcomes[flag]
	if not story_outcomes.is_empty():
		print("[Game] Story beats of day %d: %s" % [int(result["day"]), story_outcomes])
	day = int(result["day"]) + 1
	at_market = day <= Content.days().size()
	print("[Game] Day %d finished: %d coins, reputation %d, next day %d%s" % [day - 1, coins, reputation, day, " (market open)" if at_market else " (story over)"])
	if story_over():
		# Recorded now, so quitting on the last summary still keeps the ending and the unlock.
		finish_story()
	else:
		save_game()
	goto(Flow.SUMMARY, result)


## The hint word ids in the Codex, in the order they were learned.
func codex_words() -> PackedStringArray:
	return PackedStringArray(codex.get(CODEX_WORDS, []))


## Potion id -> the ingredient ids the Codex holds for it.
func codex_recipes() -> Dictionary[String, PackedStringArray]:
	var recipes: Dictionary[String, PackedStringArray] = {}
	var saved: Dictionary = codex.get(CODEX_RECIPES, {})
	for id: String in saved:
		recipes[id] = PackedStringArray(saved[id])
	return recipes


## Adds the hint words of `ids` the Codex does not hold yet; saves when any is new.
## Returns how many were new.
func learn_words(ids: PackedStringArray) -> int:
	var words: Array = codex.get(CODEX_WORDS, [])
	var learned := PackedStringArray()
	for id in ids:
		if not id in words:
			words.append(id)
			learned.append(id)
	if learned.is_empty():
		return 0
	codex[CODEX_WORDS] = words
	print("[Game] Codex: learned hint words %s" % learned)
	save_game()
	return learned.size()


## Records `ingredients` (ids, 2-3) as the Codex recipe of `potion`, brewed at Good or
## better: kept when it is the first, or exact (Perfect match) where the one held is not.
## Saves and returns true when the Codex changed.
func learn_recipe(potion: PotionType, ingredients: PackedStringArray) -> bool:
	var recipes: Dictionary = codex.get(CODEX_RECIPES, {})
	if recipes.has(potion.id) and (_is_exact(potion, PackedStringArray(recipes[potion.id])) or not _is_exact(potion, ingredients)):
		return false
	recipes[potion.id] = Array(ingredients)
	codex[CODEX_RECIPES] = recipes
	print("[Game] Codex: recipe for %s is %s" % [potion.id, ingredients])
	save_game()
	return true


func _is_exact(potion: PotionType, ingredients: PackedStringArray) -> bool:
	var essences: Array[Vector4i] = []
	for id in ingredients:
		var item := Content.ingredient(id)
		if item == null:
			return false
		essences.append(item.essence)
	return Brew.combine(essences) == potion.target


## What is wrong with a saved Codex, or "": only the keys CODEX_WORDS (unique known
## hint word ids) and CODEX_RECIPES (known potion id -> 2..3 known ingredient ids).
static func codex_problem_of(data: Dictionary) -> String:
	for key: Variant in data:
		if key != CODEX_WORDS and key != CODEX_RECIPES:
			return "codex has unknown key '%s'" % key
	var words: Variant = data.get(CODEX_WORDS, [])
	if typeof(words) != TYPE_ARRAY:
		return "codex.%s is not a list" % CODEX_WORDS
	var seen := {}
	for id: Variant in words:
		if typeof(id) != TYPE_STRING or Content.hint_words().all(func(word: HintWord) -> bool: return word.id != id) or seen.has(id):
			return "codex.%s has an unknown or repeated hint word %s" % [CODEX_WORDS, id]
		seen[id] = true
	var recipes: Variant = data.get(CODEX_RECIPES, {})
	if typeof(recipes) != TYPE_DICTIONARY:
		return "codex.%s is not an object" % CODEX_RECIPES
	for potion: Variant in recipes:
		if Content.potions().all(func(item: PotionType) -> bool: return item.id != str(potion)):
			return "codex.%s has unknown potion '%s'" % [CODEX_RECIPES, potion]
		var used: Variant = recipes[potion]
		if typeof(used) != TYPE_ARRAY or (used as Array).size() < Brew.MIN_INGREDIENTS or (used as Array).size() > Brew.MAX_INGREDIENTS:
			return "codex.%s.%s is not a list of %d..%d ingredients" % [CODEX_RECIPES, potion, Brew.MIN_INGREDIENTS, Brew.MAX_INGREDIENTS]
		for id: Variant in used:
			if Content.ingredients().all(func(item: Ingredient) -> bool: return item.id != str(id)):
				return "codex.%s.%s has unknown ingredient '%s'" % [CODEX_RECIPES, potion, id]
	return ""


## True once the last story day is done (its summary leads to the ending).
func story_over() -> bool:
	return day > Content.days().size()


## Ends the story: picks the ending from the flags and reputation (Story.ending),
## records it in endings (once) with the Rush Hour unlock, saves, and returns its id.
func finish_story() -> String:
	var ending := Story.ending(flags, reputation)
	if not ending in endings:
		endings.append(ending)
	rush_hour_unlocked = true
	print("[Game] Story finished: ending %s (reputation %d, flags %s); endings reached %s; Rush Hour unlocked" % [ending, reputation, flags, endings])
	save_game()
	return ending


## True when finish_story() has recorded `ending` (endings reached and the unlock).
func has_recorded(ending: String) -> bool:
	return rush_hour_unlocked and ending in endings


## Closes the market and goes to the next morning.
func leave_market() -> void:
	at_market = false
	save_game()
	goto(Flow.MORNING)


## Buys one `item` for `price` coins. False (nothing changes) when coins fall short.
func buy_stock(item: Ingredient, price: int) -> bool:
	if price > coins:
		print("[Game] Cannot buy %s for %d: %d coins" % [item.id, price, coins])
		return false
	coins -= price
	stock[item.id] = stock.get(item.id, 0) + 1
	print("[Game] Bought %s for %d: %d in stock, %d coins" % [item.id, price, stock[item.id], coins])
	save_game()
	return true


## Buys the next level of `upgrade`. False (nothing changes) when it is maxed or coins fall short.
func buy_upgrade(upgrade: Upgrade) -> bool:
	var level: int = upgrades.get(upgrade.station, 0)
	var cost := Economy.upgrade_cost(upgrade, level)
	if cost == Economy.MAXED or cost > coins:
		print("[Game] Cannot buy %s level %d (cost %d): %d coins" % [upgrade.id, level + 1, cost, coins])
		return false
	coins -= cost
	upgrades[upgrade.station] = level + 1
	print("[Game] Bought %s level %d for %d: tolerance x%.2f, %d coins" % [upgrade.id, level + 1, cost, Economy.upgrade_tolerance(upgrade, level + 1), coins])
	save_game()
	return true


## Writes progress and settings to save_path; a failure is reported, never silent.
## The data goes to a temporary file first, which then replaces the save, so a
## failed write leaves the last good save in place.
func save_game() -> void:
	var data := {
		"version": SAVE_VERSION, "day": day, "at_market": at_market, "coins": coins, "reputation": reputation,
		"stock": stock, "upgrades": upgrades, "codex": codex, "flags": flags, "endings": endings,
		"rush_hour_unlocked": rush_hour_unlocked, "rush_best": rush_best, "settings": {"assist": assist_mode, "gentle": gentle_mode},
	}
	var temp := save_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		_report_error("Could not open '%s' for writing the save: %s; '%s' is unchanged" % [temp, error_string(FileAccess.get_open_error()), save_path])
		return
	var written := file.store_string(JSON.stringify(data, "  "))
	file.close()
	if not written:
		DirAccess.remove_absolute(temp)
		_report_error("Could not write the save to '%s'; '%s' is unchanged" % [temp, save_path])
		return
	var replaced := DirAccess.rename_absolute(temp, save_path)
	if replaced != OK:
		DirAccess.remove_absolute(temp)
		_report_error("Could not replace save '%s' with '%s': %s; the save is unchanged" % [save_path, temp, error_string(replaced)])
		return
	print("[Game] Saved to %s: day %d%s, %d coins, reputation %d, upgrades %s, flags %s, endings %s, Rush Hour %s, assist %s, gentle %s" % [
		save_path, day, " (market)" if at_market else "", coins, reputation, upgrades, flags, endings, rush_hour_unlocked, assist_mode, gentle_mode])


## Loads save_path into progress and settings. A missing save starts fresh silently
## (a log line only); an unreadable or corrupt one is reported (push_error and the
## error label), moved to backup_path() and replaced by defaults. A JSON instance
## reports parse errors as return values, so each problem is reported once, by us.
func load_game() -> void:
	_reset_progress()
	assist_mode = false
	gentle_mode = false
	if not FileAccess.file_exists(save_path):
		print("[Game] No save at %s; starting fresh" % save_path)
		return
	if not Content.errors().is_empty():
		# The save is checked against the content; with broken content a valid save would
		# look corrupt. The title keeps the shop closed, so the save is left untouched.
		print("[Game] Content has problems; the save at %s is left unread and untouched" % save_path)
		return
	var text := FileAccess.get_file_as_string(save_path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		_discard_save("unreadable (%s)" % error_string(FileAccess.get_open_error()))
		return
	var json := JSON.new()
	if json.parse(text) != OK:
		_discard_save("corrupt (line %d: %s)" % [json.get_error_line(), json.get_error_message()])
		return
	var problem := _apply_save(json.data)
	if problem != "":
		_reset_progress()
		assist_mode = false
		gentle_mode = false
		_discard_save("corrupt (%s)" % problem)
		return
	print("[Game] Loaded save from %s: day %d%s, %d coins, reputation %d, stock %s, upgrades %s, flags %s, endings %s, Rush Hour %s, assist %s, gentle %s" % [
		save_path, day, " (market)" if at_market else "", coins, reputation, stock, upgrades, flags, endings, rush_hour_unlocked, assist_mode, gentle_mode])


## Where a corrupt save is moved: save.json -> save.corrupt.json.
func backup_path() -> String:
	return save_path.get_basename() + ".corrupt.json"


## The visible area in base units: 270x480 or larger on one axis (aspect expand).
func visible_rect() -> Rect2:
	return _visible_rect


## The part of the visible area clear of notches and rounded corners, in base units.
func safe_rect() -> Rect2:
	return _safe_rect


## The 270-wide gameplay column, centred in the safe area and as tall as it.
func column_rect() -> Rect2:
	return column_in(_safe_rect)


## The column for a given safe rect: COLUMN_WIDTH wide (narrower only if the
## safe rect is), horizontally centred in it, spanning its full height.
static func column_in(safe: Rect2) -> Rect2:
	var width := minf(COLUMN_WIDTH, safe.size.x)
	return Rect2(safe.get_center().x - width / 2.0, safe.position.y, width, safe.size.y)


## Converts the screen-pixel safe area to base units and clips it to `visible`.
## An empty safe area (headless, some web browsers) means the whole visible rect.
static func safe_rect_in(visible: Rect2, safe_pixels: Rect2i, window_position: Vector2i, stretch: Transform2D) -> Rect2:
	if safe_pixels.size.x <= 0 or safe_pixels.size.y <= 0:
		return visible
	var local := Rect2(Vector2(safe_pixels.position - window_position), Vector2(safe_pixels.size))
	var base := stretch.affine_inverse() * local
	var clipped := base.intersection(visible)
	return clipped if clipped.has_area() else visible


func _update_screen_fit() -> void:
	var window := get_window()
	var visible := get_viewport().get_visible_rect()
	var safe := safe_rect_in(visible, DisplayServer.get_display_safe_area(), window.position, window.get_final_transform())
	if visible == _visible_rect and safe == _safe_rect:
		return
	_visible_rect = visible
	_safe_rect = safe
	print("[Game] ScreenFit: visible %s, safe %s, column %s" % [visible, safe, column_rect()])
	screen_fit_changed.emit()


func _reset_progress() -> void:
	day = Content.FIRST_DAY
	at_market = false
	coins = 0
	reputation = 0
	stock = {}
	upgrades = {}
	codex = {}
	flags = {}
	endings = []
	rush_hour_unlocked = false
	rush_best = 0


## Applies a parsed save; returns "" or what is wrong with it (the caller then
## resets the progress it may have half applied).
func _apply_save(data: Variant) -> String:
	if not data is Dictionary:
		return "not an object"
	var saved: Dictionary = data
	var outdated := migrate_save(saved, save_migrations(), SAVE_VERSION)
	if outdated != "":
		return outdated
	for key: Variant in saved:
		if not SAVE_KEYS.has(str(key)):
			return "unknown key '%s'" % key
	for key in SAVE_KEYS:
		if not saved.has(key):
			return "missing key '%s'" % key
		var value: Variant = saved[key]
		var ok := _is_whole(value) if SAVE_KEYS[key] == TYPE_INT else typeof(value) == SAVE_KEYS[key]
		if not ok:
			return "'%s' is not %s" % [key, "a whole number" if SAVE_KEYS[key] == TYPE_INT else type_string(SAVE_KEYS[key])]
	day = int(saved["day"])
	if day < Content.FIRST_DAY or day > Content.LAST_DAY + 1:
		return "day %d is outside %d..%d" % [day, Content.FIRST_DAY, Content.LAST_DAY + 1]
	at_market = saved["at_market"]
	coins = int(saved["coins"])
	if coins < 0 or coins > SAVE_COINS_MAX:
		return "coins %d is outside 0..%d" % [coins, SAVE_COINS_MAX]
	reputation = int(saved["reputation"])
	if absi(reputation) > SAVE_SCORE_MAX:
		return "reputation %d is outside -%d..%d" % [reputation, SAVE_SCORE_MAX, SAVE_SCORE_MAX]
	rush_best = int(saved["rush_best"])
	if rush_best < 0 or rush_best > SAVE_SCORE_MAX:
		return "rush_best %d is outside 0..%d" % [rush_best, SAVE_SCORE_MAX]
	var saved_stock: Dictionary = saved["stock"]
	for id: Variant in saved_stock:
		if Content.ingredients().all(func(item: Ingredient) -> bool: return item.id != str(id)):
			return "stock has unknown ingredient '%s'" % id
		var count: Variant = saved_stock[id]
		if not _is_whole(count) or int(count) < 0 or int(count) > SAVE_STOCK_MAX:
			return "stock of '%s' is not a count 0..%d" % [id, SAVE_STOCK_MAX]
		stock[str(id)] = int(count)
	var saved_upgrades: Dictionary = saved["upgrades"]
	for station: Variant in saved_upgrades:
		var matching := Content.upgrades().filter(func(item: Upgrade) -> bool: return item.station == str(station))
		if matching.is_empty():
			return "upgrades has unknown station '%s'" % station
		var top: int = (matching[0] as Upgrade).max_level()
		var level: Variant = saved_upgrades[station]
		if not _is_whole(level) or int(level) < 0 or int(level) > top:
			return "upgrade level of '%s' is not 0..%d" % [station, top]
		upgrades[str(station)] = int(level)
	var codex_problem := codex_problem_of(saved["codex"])
	if codex_problem != "":
		return codex_problem
	codex = saved["codex"]
	var flags_problem := Story.flags_problem(saved["flags"])
	if flags_problem != "":
		return flags_problem
	flags = saved["flags"]
	for ending: Variant in saved["endings"]:
		if typeof(ending) != TYPE_STRING or not ending in Story.ENDINGS:
			return "endings has an unknown ending %s, not one of %s" % [ending, Story.ENDINGS]
		if ending in endings:
			return "endings has '%s' twice" % ending
		endings.append(ending)
	rush_hour_unlocked = saved["rush_hour_unlocked"]
	var settings: Dictionary = saved["settings"]
	if settings.size() != SETTINGS_KEYS.size() or not SETTINGS_KEYS.all(func(key: String) -> bool: return typeof(settings.get(key)) == TYPE_BOOL):
		return "settings must be exactly %s, each true or false" % [SETTINGS_KEYS]
	assist_mode = settings["assist"]
	gentle_mode = settings["gentle"]
	return ""


## Upgrades `saved` (a parsed save, changed in place) to version `target`:
## migrations[i] turns a version i + 1 save into version i + 2. Returns "" or why
## it cannot (no whole version >= 1, or a version newer than `target`).
static func migrate_save(saved: Dictionary, migrations: Array[Callable], target: int) -> String:
	if not _is_whole(saved.get("version")) or int(saved["version"]) < 1:
		return "'version' is not a whole number >= 1"
	if migrations.size() != target - 1:
		push_error("[Game] %d save upgrade steps for save version %d (expected %d)" % [migrations.size(), target, target - 1])
		return "this game cannot upgrade saves (%d steps for version %d)" % [migrations.size(), target]
	var version := int(saved["version"])
	if version > target:
		return "version %d is newer than this game's %d" % [version, target]
	while version < target:
		migrations[version - 1].call(saved)
		version += 1
		saved["version"] = version
		print("[Game] Upgraded the save to version %d" % version)
	return ""


## The save format's upgrade steps: entry i turns a version i + 1 save into
## version i + 2. Steps run before the save is validated, so they must read keys
## with get() and leave anything malformed for the validation to report.
static func save_migrations() -> Array[Callable]:
	return [_save_v1_to_v2]


## Version 1 -> 2: the ending reached and the Rush Hour unlock move out of the story's
## flags into `endings` and `rush_hour_unlocked` (kept by new_game). A save of the
## two-day build that had finished its story (V1_STORY_OVER_DAY, market closed, no
## flags) reopens the market before that day, which now exists.
static func _save_v1_to_v2(saved: Dictionary) -> void:
	var old_flags: Variant = saved.get("flags")
	var story_flags: Dictionary = old_flags if old_flags is Dictionary else {}
	if story_flags.is_empty() and _is_whole(saved.get("day")) and int(saved["day"]) == V1_STORY_OVER_DAY and typeof(saved.get("at_market")) == TYPE_BOOL and not saved["at_market"]:
		saved["at_market"] = true
		print("[Game] Save upgrade: the two-day story's finished save reopens the market before day %d" % V1_STORY_OVER_DAY)
	saved["endings"] = [story_flags[V1_ENDING_FLAG]] if story_flags.has(V1_ENDING_FLAG) else []
	saved["rush_hour_unlocked"] = story_flags.get(V1_RUSH_HOUR_FLAG, false)
	story_flags.erase(V1_ENDING_FLAG)
	story_flags.erase(V1_RUSH_HOUR_FLAG)


## Reports `problem`, moves the bad save to backup_path() and writes defaults in
## its place. When the move fails the bad save stays where it is (reported), and
## the next save write replaces it.
func _discard_save(problem: String) -> void:
	var cleared := OK
	if FileAccess.file_exists(backup_path()):
		cleared = DirAccess.remove_absolute(backup_path())
	var moved := DirAccess.rename_absolute(save_path, backup_path()) if cleared == OK else cleared
	if moved != OK:
		_report_error("Save '%s' is %s and could not be moved to '%s' (%s); the game starts fresh and the next save replaces it" % [save_path, problem, backup_path(), error_string(moved)])
		return
	_report_error("Save '%s' is %s; it was moved to '%s' and replaced with fresh progress" % [save_path, problem, backup_path()])
	save_game()


## JSON numbers load as floats; accept whole numbers only, and only those a float
## holds exactly (|n| <= 2^53): int() of a larger float is CPU dependent (arm64
## saturates, x86-64 gives INT64_MIN), so range checks after it could be fooled.
static func _is_whole(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floorf(value) and absf(value) <= SAVE_EXACT_MAX)


func _fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_curtain, "color:a", alpha, FADE_TIME)
	await tween.finished


func _log_transition(entry: String) -> void:
	transition_log.append(entry)
	print("[Game] goto " + entry)


func _report_error(message: String) -> void:
	reported_errors.append(message)
	_error_label.text = message
	_error_label.show()
	if not quiet_errors:
		push_error("[Game] " + message)
