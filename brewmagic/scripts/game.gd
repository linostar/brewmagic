class_name GameState
extends Node
## Autoload "Game" (scenes/game.tscn): the app flow state machine and its
## scene transitions, the player's progress and settings with their save in
## user://, plus ScreenFit (the visible and safe-area rects in base units and the
## centred 270-wide gameplay column).
## Story flow: title -> morning -> shop -> summary -> market -> morning (next day) ...
## -> the last day's summary -> ending (finish_story) -> title.
## Rush Hour (once the story is done): title -> shop (start_rush) -> results
## (finish_rush) -> again or title.
## The shop commits a finished day with finish_day(); quitting mid-shift keeps the
## progress from before that day.
## The game opens on the splash (the main scene), which goes to the title.
## Every flow change goes through goto(), which closes a potion swirl wipe over the
## screen (touches blocked), swaps the scene, reopens the wipe while the new
## screen's content slides in, and logs the transition. A flow state whose scene is
## missing is reported with push_error and a visible error label instead of
## crashing; a scene that cannot start redirects with abort_to().
## Every Button press also squashes the button (unless it is in OWN_SQUASH_GROUP).
##
## Sound: sfx(id) plays a game sound effect (audio/sfx/<id>.wav, tools/sfx.py) and
## play_sfx() any stream (voice blips) on the SFX bus, from a pool of SFX_VOICES
## players; every Button's press plays "tap" unless the button is in OWN_SOUND_GROUP
## (it plays its own sound). Music: one track per flow state (track_for), on the
## Music bus, crossfading over CROSSFADE_TIME when the track changes and left alone
## when it stays. The Music and SFX bus volumes are settings (0..100, 0 mutes),
## and each bus can be muted without losing its volume (the shop's HUD toggles).
## Sound and music play from boot. A browser that refuses audio before the player's
## first input keeps its AudioContext suspended, and Godot's web platform resumes it
## on the first touch or key; where the page may play (a native window, an itch.io
## embed that delegates autoplay after its "Run game" click) the title music starts
## on the splash.

signal transition_finished(state: Flow)
## Emitted when the visible rect or the safe area changes (resize, rotation).
signal screen_fit_changed
## Emitted when a volume or a mute setting changes (the shop's toggles follow it).
signal audio_settings_changed

enum Flow { TITLE, MORNING, SHOP, SUMMARY, MARKET, ENDING, RESULTS, SPLASH }

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
	Flow.RESULTS: "res://scenes/results.tscn",
	Flow.SPLASH: "res://scenes/splash.tscn",
}
## Seconds for each half of a transition (the swirl closing, then reopening); the
## whole transition takes twice this plus the frame the new scene loads in (< 0.5 s).
const WIPE_TIME := 0.2
## How far below its place (base units) a new screen's content starts as it slides in.
const ENTER_OFFSET := 14.0
## Buttons in this group animate their own press; the global squash leaves them alone.
const OWN_SQUASH_GROUP := &"own_squash"
## The global squash's peak (Juice.squash strength) on every other Button press.
const PRESS_SQUASH := 0.12
## Width of the gameplay column in base units (the base viewport width).
const COLUMN_WIDTH := 270.0
## Station tolerance multiplier while Gentle mode is on.
const GENTLE_TOLERANCE_SCALE := 1.5
const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"
## Sound effects that may overlap; a new one beyond this takes the oldest one's player.
const SFX_VOICES := 8
## The game's sound effects (tools/sfx.py EFFECTS makes one file per id).
const SFX_PATH := "res://audio/sfx/%s.wav"
const SFX_IDS: Array[StringName] = [
	&"tap", &"drop", &"splash", &"slot_remove", &"stir", &"pour_fill", &"pour_stop", &"pour_spill", &"mortar",
	&"bellows_pump", &"bellows_out", &"success", &"sloppy", &"stamp_perfect", &"stamp_good", &"stamp_meh",
	&"stamp_misbrew", &"coins", &"tip", &"coin_tick", &"misbrew", &"door_bell", &"storm_off", &"refuse",
	&"page_flip", &"buy", &"nope", &"codex_open", &"codex_new", &"wave", &"rush_over",
]
## A sound repeated within this many seconds of its last start is dropped (bursts of
## stir rotations, pumps, coin ticks never stack into noise).
const SFX_MIN_GAP := 0.05
## Sounds that repeat a lot vary their pitch this much either way, so repeats do not drone.
const SFX_JITTER: Dictionary[StringName, float] = {
	&"tap": 0.05, &"drop": 0.06, &"stir": 0.06, &"mortar": 0.08, &"bellows_pump": 0.08, &"coin_tick": 0.1,
	&"door_bell": 0.03, &"page_flip": 0.08, &"splash": 0.06,
}
## sfx_log keeps the ids of this many latest sound effects (tests read it).
const SFX_LOG_SIZE := 64
## Buttons in this group play their own sound instead of the generic "tap".
const OWN_SOUND_GROUP := &"own_sound"
const MUSIC_PATH := "res://audio/music/%s.mp3"
## The music of each flow state (tools/music.py); a Rush Hour shop plays "rush" (track_for).
const MUSIC_TRACKS: Dictionary[Flow, StringName] = {
	Flow.TITLE: &"title", Flow.MORNING: &"shop", Flow.SHOP: &"shop", Flow.SUMMARY: &"shop",
	Flow.MARKET: &"shop", Flow.ENDING: &"ending", Flow.RESULTS: &"rush", Flow.SPLASH: &"title",
}
## Seconds a change of track takes to crossfade (at most 1 s).
const CROSSFADE_TIME := 0.8
## Frames the window-close quit waits after stopping the audio, so the mixer drops the playbacks.
const QUIT_FRAMES := 3
## Volume settings: 0..VOLUME_MAX in steps of VOLUME_STEP (0 mutes the bus).
const VOLUME_MAX := 100
const VOLUME_STEP := 10
const DEFAULT_MUSIC_VOLUME := 70
const DEFAULT_SFX_VOLUME := 80
## The audio driver of headless runs (no device, never mixes) and of Movie Maker runs
## (--write-movie), where it does mix into the recording: see audio_silent().
const SILENT_AUDIO_DRIVER := "Dummy"
const SAVE_PATH := "user://save.json"
## The save of tool runs (see _ready); tests delete it when they finish.
const TOOL_SAVE_PATH := "user://tool_save.json"
## The save format's version. Every change to the format bumps it and appends one
## step to save_migrations(), so saves of older versions are upgraded, not discarded.
const SAVE_VERSION := 5
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
	"endings": TYPE_ARRAY, "rush_hour_unlocked": TYPE_BOOL, "rush_best": TYPE_INT, "rush_best_assisted": TYPE_BOOL,
	"settings": TYPE_DICTIONARY,
}
## Version 1 kept these in flags (moved out by the version 2 step of save_migrations).
const V1_ENDING_FLAG := "ending"
const V1_RUSH_HOUR_FLAG := "rush_hour_unlocked"
## A version 1 save from the two-day build at this day (market closed, no flags) had
## finished that build's story; the version 2 step reopens the market before it.
const V1_STORY_OVER_DAY := 3
## The saved settings: the modes and the mutes (true or false) and the volumes (whole 0..VOLUME_MAX).
const SETTINGS_KEYS: Array[String] = ["assist", "gentle", "music", "sfx", "music_muted", "sfx_muted"]
const VOLUME_SETTINGS: Array[String] = ["music", "sfx"]
const CODEX_WORDS := "words"
const CODEX_RECIPES := "recipes"

## Settings, persisted in the save. Stations read them through the shop when they begin.
var assist_mode := false
var gentle_mode := false
## Music and SFX bus volumes, 0..VOLUME_MAX (set_music_volume, set_sfx_volume).
var music_volume := DEFAULT_MUSIC_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
## A muted bus is silent but keeps its volume (set_music_muted, set_sfx_muted).
var music_muted := false
var sfx_muted := false

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
## The best Rush Hour score (coins earned in one run) and whether Assist was on
## during that run; like the endings, new_game keeps them.
var rush_best := 0
var rush_best_assisted := false
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
## How many sounds played (sfx() and play_sfx(); tests count voice blips with it).
var sfx_played := 0
## The ids of the latest sfx() sounds that played, oldest first (SFX_LOG_SIZE at most).
var sfx_log: Array[StringName] = []
## The sound ids held by pause_sfx (a pour's fill while the shift is paused), until
## resume_sfx or stop_sfx; tests read it (the Dummy driver of headless runs plays nothing).
var sfx_paused: Array[StringName] = []
## The potion colour of the latest transition's swirl wipe (each picks one at random).
var wipe_color := Color.WHITE
## The music track the flow asks for (MUSIC_TRACKS), "" before the first; it plays
## once audio is unlocked. music_changes counts how often it changed (a crossfade each).
var music_track := &""
var music_changes := 0
## The track last started (audible once audio is unlocked); "" before the first.
## Without an audio device the track is only recorded here, never played.
var music_started := &""

var _transitioning := false
var _visible_rect := Rect2()
var _safe_rect := Rect2()
var _sfx_players: Array[AudioStreamPlayer] = []
## Per pool player: the Game clock when its sound started (the oldest is taken first).
var _sfx_started: Array[float] = []
var _sounds: Dictionary[StringName, AudioStream] = {}
## Sound id -> the Game clock when it last started (SFX_MIN_GAP).
var _sfx_last: Dictionary[StringName, float] = {}
var _sfx_rng := RandomNumberGenerator.new()
var _music_players: Array[AudioStreamPlayer] = []
## The index in _music_players of the one playing (or fading in) the current track.
var _music_current := 0
var _music_fade: Tween
var _tracks: Dictionary[StringName, AudioStream] = {}
## Seconds since start, advanced in _process (also while paused): the SFX clock.
var _clock := 0.0
var _wipe_rng := RandomNumberGenerator.new()

@onready var _wipe: ColorRect = $Fade/Wipe
@onready var _wipe_material: ShaderMaterial = $Fade/Wipe.material
@onready var _error_label: Label = $Fade/ErrorLabel


func _ready() -> void:
	for bus: StringName in [SFX_BUS, MUSIC_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			push_error("[Game] Audio bus '%s' is missing from default_bus_layout.tres; its sounds play on Master" % bus)
	for i in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)
		_sfx_started.append(0.0)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.bus = MUSIC_BUS
		add_child(player)
		_music_players.append(player)
	_sfx_rng.randomize()
	_wipe_rng.randomize()
	# Closing the window quits through _quit_quietly, after the audio has stopped.
	get_tree().set_auto_accept_quit(false)
	get_tree().node_added.connect(_on_node_added)
	# Tool runs (the tests, the project check, the headless main-scene run) drive the
	# tree from a SceneTree script; they must never read or overwrite the player's save.
	if get_tree().get_script() != null:
		save_path = TOOL_SAVE_PATH
	load_game()
	# The first scene (the splash, Splash._ready sets state) was loaded without a goto(); ask for its music.
	play_music(track_for(state, flow_args))
	_fit_window()
	get_viewport().size_changed.connect(_update_screen_fit)
	_update_screen_fit()


## Closing the window: a stream still playing at quit keeps its playback (and the
## stream) referenced by the AudioServer, which reports them leaked at exit. stop()
## only queues the playback's removal for the mixer, so the quit waits QUIT_FRAMES.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_quietly()


func _quit_quietly() -> void:
	print("[Game] Quitting: stopping audio")
	stop_audio()
	for i in QUIT_FRAMES:
		await get_tree().process_frame
	get_tree().quit()


## Stops the music and every sound now (the crossfade too).
func stop_audio() -> void:
	if _music_fade != null:
		_music_fade.kill()
	for player in _sfx_players:
		player.stop()
	for player in _music_players:
		player.stop()


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


## Wipes to the scene of `new_state`, passing `args` through flow_args: the potion
## swirl closes (WIPE_TIME), the scene changes, then the swirl reopens while the new
## screen's content slides in (enter_screen), so it is at rest when transition_finished
## fires. Touches are blocked until then. Ignored (with a log line) while a transition
## is running.
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
	play_music(track_for(new_state, args))
	_error_label.hide()
	_start_wipe()
	await _wipe_to(1.0)
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_report_error("Failed to load scene '%s' for %s: %s" % [path, to_name, error_string(error)])
		await _wipe_to(0.0)
		_end_wipe()
		return
	state = new_state
	flow_args = args
	# The new scene enters the tree (and runs its _ready) at the end of this frame.
	await get_tree().scene_changed
	enter_screen(get_tree().current_scene)
	await _wipe_to(0.0)
	_end_wipe()
	print("[Game] Arrived at %s" % to_name)
	transition_finished.emit(new_state)


## The arrival animation of a flow screen: its content (the scene's "Column", the
## gameplay column every screen lays out in) slides up ENTER_OFFSET into place and
## fades in over WIPE_TIME, with a slight overshoot. A scene without one is left alone.
func enter_screen(scene: Node) -> void:
	var content := scene.get_node_or_null(^"Column") as Control if scene != null else null
	if content == null:
		return
	var rest := content.position
	content.position.y = rest.y + ENTER_OFFSET
	content.modulate.a = 0.0
	var tween := content.create_tween().set_parallel()
	tween.tween_property(content, "position:y", rest.y, WIPE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(content, "modulate:a", 1.0, WIPE_TIME * 0.6)


## Readies the swirl wipe: a potion colour of the content (else gloom), the wipe's size,
## and touches blocked until _end_wipe.
func _start_wipe() -> void:
	var potions := Content.potions()
	wipe_color = potions[_wipe_rng.randi_range(0, potions.size() - 1)].color if not potions.is_empty() else Color("#9058c0")
	_wipe_material.set_shader_parameter(&"liquid", wipe_color)
	_wipe_material.set_shader_parameter(&"deep", wipe_color.darkened(0.45))
	_wipe_material.set_shader_parameter(&"rim", wipe_color.lightened(0.55))
	_wipe_material.set_shader_parameter(&"rect_size", _wipe.size)
	_wipe.mouse_filter = Control.MOUSE_FILTER_STOP
	_wipe.show()


func _end_wipe() -> void:
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.hide()
	_transitioning = false


## Tweens the wipe to `progress` (1 covers the screen, 0 clears it) over WIPE_TIME.
func _wipe_to(progress: float) -> void:
	var tween := create_tween()
	tween.tween_property(_wipe_material, "shader_parameter/progress", progress, WIPE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT if progress > 0.5 else Tween.EASE_OUT)
	await tween.finished


## How far the wipe covers the screen: 0 clear, 1 covered (tests read it).
func wipe_progress() -> float:
	return float(_wipe_material.get_shader_parameter(&"progress"))


## For a scene that cannot start (it calls this from its _ready, during the
## transition into it): goes to `fallback` once that transition has finished,
## then reports `message` (log and the visible error label) on the fallback screen.
func abort_to(fallback: Flow, message: String) -> void:
	if _transitioning:
		await transition_finished
	await goto(fallback)
	_report_error(message)


func _process(delta: float) -> void:
	_clock += delta


## Plays sound effect `id` (one of SFX_IDS) on the SFX bus at `pitch`, varied by its
## SFX_JITTER. Dropped when the same sound started less than SFX_MIN_GAP ago.
func sfx(id: StringName, pitch := 1.0) -> void:
	if not _sounds.has(id):
		var path := SFX_PATH % id
		var stream := load(path) as AudioStream if id in SFX_IDS and ResourceLoader.exists(path) else null
		if stream == null:
			push_error("[Game] No sound effect '%s' at %s (SFX_IDS, run python3 tools/sfx.py)" % [id, path])
		_sounds[id] = stream
	if _sounds[id] == null:
		return
	if _clock - float(_sfx_last.get(id, -INF)) < SFX_MIN_GAP:
		return
	_sfx_last[id] = _clock
	sfx_log.append(id)
	if sfx_log.size() > SFX_LOG_SIZE:
		sfx_log.pop_front()
	var jitter: float = SFX_JITTER.get(id, 0.0)
	play_sfx(_sounds[id], pitch * _sfx_rng.randf_range(1.0 - jitter, 1.0 + jitter))


## Stops sound effect `id` wherever it is still playing or held (a pour's fill when it stops).
func stop_sfx(id: StringName) -> void:
	sfx_paused.erase(id)
	var stream: AudioStream = _sounds.get(id)
	for player in _sfx_players:
		if stream != null and player.stream == stream and (player.playing or player.stream_paused):
			player.stream_paused = false
			player.stop()


## Holds sound effect `id` where it is (a pour's fill while the shift is paused: the
## pool players run while the tree is paused, so they are held by hand); resume_sfx
## continues it, stop_sfx ends it.
func pause_sfx(id: StringName) -> void:
	if id in sfx_paused:
		return
	sfx_paused.append(id)
	print("[Game] Sound %s held" % id)
	_hold_sfx(id, true)


## Continues sound effect `id` held by pause_sfx.
func resume_sfx(id: StringName) -> void:
	if not id in sfx_paused:
		return
	sfx_paused.erase(id)
	print("[Game] Sound %s continues" % id)
	_hold_sfx(id, false)


func _hold_sfx(id: StringName, held: bool) -> void:
	var stream: AudioStream = _sounds.get(id)
	for player in _sfx_players:
		if stream != null and player.stream == stream and (player.playing or player.stream_paused):
			player.stream_paused = held


## Plays `stream` on the SFX bus at `pitch` on a free pool player (else the one that
## started first). Without an audio device (the Dummy driver of headless runs) it only
## counts: that driver never mixes, so its playbacks would never finish and leak at exit.
func play_sfx(stream: AudioStream, pitch := 1.0) -> void:
	sfx_played += 1
	if audio_silent():
		return
	var pick := 0
	for i in _sfx_players.size():
		# A held player (pause_sfx) is not free: its sound continues later.
		if not _sfx_players[i].playing and not _sfx_players[i].stream_paused:
			pick = i
			break
		if _sfx_started[i] < _sfx_started[pick]:
			pick = i
	var player := _sfx_players[pick]
	_sfx_started[pick] = _clock
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


## True without an audio device (the Dummy driver of headless runs), where sounds only
## count and music is only recorded. A Movie Maker run (tools/demo.gd) also uses the
## Dummy driver but mixes into the movie, so it plays.
static func audio_silent() -> bool:
	return AudioServer.get_driver_name() == SILENT_AUDIO_DRIVER and not OS.has_feature("movie")


## The music of flow state `to` entered with `args`: MUSIC_TRACKS, "rush" for a Rush Hour shop.
static func track_for(to: Flow, args: Dictionary) -> StringName:
	if to == Flow.SHOP and args.has("rush"):
		return &"rush"
	return MUSIC_TRACKS[to]


## Asks for music `track` (MUSIC_TRACKS): the same track keeps playing; another one
## crossfades in over CROSSFADE_TIME (once audio is unlocked; until then it waits).
func play_music(track: StringName) -> void:
	if track == music_track:
		return
	music_track = track
	music_changes += 1
	print("[Game] Music: %s" % track)
	_start_track()


## Crossfades from the playing track to music_track (nothing without an audio device).
func _start_track() -> void:
	if music_track == &"":
		return
	music_started = music_track
	if audio_silent():
		return
	if not _tracks.has(music_track):
		var path := MUSIC_PATH % music_track
		_tracks[music_track] = load(path) as AudioStream if ResourceLoader.exists(path) else null
		if _tracks[music_track] == null:
			push_error("[Game] No music '%s' at %s (run python3 tools/music.py)" % [music_track, path])
	var stream := _tracks[music_track]
	if stream == null:
		return
	if _music_fade != null:
		_music_fade.kill()
	var old := _music_players[_music_current]
	_music_current = 1 - _music_current
	var player := _music_players[_music_current]
	player.stream = stream
	player.volume_linear = 0.0
	player.play()
	_music_fade = create_tween().set_parallel()
	_music_fade.tween_property(player, "volume_linear", 1.0, CROSSFADE_TIME)
	if old.playing:
		_music_fade.tween_property(old, "volume_linear", 0.0, CROSSFADE_TIME)
		_music_fade.chain().tween_callback(old.stop)


## Sets the music volume (0..VOLUME_MAX, snapped to VOLUME_STEP), applies it to the Music bus and saves.
## A volume above 0 also unmutes the music (the player turned it up).
func set_music_volume(value: int) -> void:
	music_volume = clampi(snappedi(value, VOLUME_STEP), 0, VOLUME_MAX)
	if music_volume > 0:
		music_muted = false
	_apply_volumes()
	save_game()


## Sets the sound effects volume (0..VOLUME_MAX, snapped to VOLUME_STEP), applies it to the SFX bus and saves.
## A volume above 0 also unmutes the sound effects.
func set_sfx_volume(value: int) -> void:
	sfx_volume = clampi(snappedi(value, VOLUME_STEP), 0, VOLUME_MAX)
	if sfx_volume > 0:
		sfx_muted = false
	_apply_volumes()
	save_game()


## Mutes or unmutes the Music bus, keeping music_volume; saves.
func set_music_muted(on: bool) -> void:
	music_muted = on
	print("[Game] Music %s" % ("muted" if on else "unmuted"))
	_apply_volumes()
	save_game()


## Mutes or unmutes the SFX bus (sound effects and voices), keeping sfx_volume; saves.
func set_sfx_muted(on: bool) -> void:
	sfx_muted = on
	print("[Game] Sound effects %s" % ("muted" if on else "unmuted"))
	_apply_volumes()
	save_game()


## True when the Music bus is silent (muted or at volume 0).
func music_silent() -> bool:
	return music_muted or music_volume == 0


## True when the SFX bus is silent (muted or at volume 0).
func sfx_silent() -> bool:
	return sfx_muted or sfx_volume == 0


## Sets the Music and SFX buses to the volume settings (linear); a bus at 0 or muted is muted.
func _apply_volumes() -> void:
	for entry: Array in [[MUSIC_BUS, music_volume, music_silent()], [SFX_BUS, sfx_volume, sfx_silent()]]:
		var bus := AudioServer.get_bus_index(entry[0])
		if bus < 0:
			continue
		AudioServer.set_bus_volume_linear(bus, entry[1] / float(VOLUME_MAX))
		AudioServer.set_bus_mute(bus, entry[2])
	audio_settings_changed.emit()


## Every Button entering the tree plays "tap" when pressed, unless it plays its own
## sound, and squashes when pressed, unless it animates its own press (checked at the
## press, so a group added after the button entered the tree still counts).
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null:
		return
	if not button.is_in_group(OWN_SOUND_GROUP) and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)
	# A bound callable never compares equal to the plain one, so a meta marks the hook
	# (a button re-entering the tree keeps one connection).
	if not button.has_meta(&"game_press_squash"):
		button.set_meta(&"game_press_squash", true)
		button.pressed.connect(_squash_pressed.bind(button))


func _on_button_pressed() -> void:
	sfx(&"tap")


## The global press squash (PRESS_SQUASH) around the button's centre, drawn only
## (Juice.press), so keyboard focus moves from a squashing button as from a still one.
func _squash_pressed(button: BaseButton) -> void:
	if button.is_in_group(OWN_SQUASH_GROUP) or not button.is_inside_tree():
		return
	Juice.press(button, PRESS_SQUASH)


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
	var best_assisted := rush_best_assisted
	var kept_codex := codex
	var kept_endings := endings
	var unlocked := rush_hour_unlocked
	_reset_progress()
	rush_best = best
	rush_best_assisted = best_assisted
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


## Starts a Rush Hour run in the shop (flow_args {"rush": seed}; a new seed each run).
func start_rush() -> void:
	goto(Flow.SHOP, {"rush": randi()})


## The shop's end of a Rush Hour run: `result` (Shop.rush_result()) becomes the best
## when its score beats rush_best (with its assisted marker), saved; then the results
## screen shows it with "best" (the best now) and "new_best".
func finish_rush(result: Dictionary) -> void:
	var score := int(result["score"])
	var new_best := score > rush_best
	if new_best:
		rush_best = score
		rush_best_assisted = bool(result["assisted"])
		save_game()
	print("[Game] Rush Hour run finished: score %d, served %d%s; best %d%s" % [score, int(result["served"]),
		" (assisted)" if result["assisted"] else "", rush_best, " (new best)" if new_best else ""])
	var shown := result.duplicate()
	shown["best"] = rush_best
	shown["best_assisted"] = rush_best_assisted
	shown["new_best"] = new_best
	goto(Flow.RESULTS, shown)


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
		"rush_hour_unlocked": rush_hour_unlocked, "rush_best": rush_best, "rush_best_assisted": rush_best_assisted,
		"settings": {"assist": assist_mode, "gentle": gentle_mode, "music": music_volume, "sfx": sfx_volume, "music_muted": music_muted, "sfx_muted": sfx_muted},
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
	print("[Game] Saved to %s: day %d%s, %d coins, reputation %d, upgrades %s, flags %s, endings %s, Rush Hour %s (best %d%s), assist %s, gentle %s, music %d%s, sfx %d%s" % [
		save_path, day, " (market)" if at_market else "", coins, reputation, upgrades, flags, endings, rush_hour_unlocked, rush_best, " assisted" if rush_best_assisted else "", assist_mode, gentle_mode, music_volume, " muted" if music_muted else "", sfx_volume, " muted" if sfx_muted else ""])


## Loads save_path into progress and settings. A missing save starts fresh silently
## (a log line only); an unreadable or corrupt one is reported (push_error and the
## error label), moved to backup_path() and replaced by defaults. A JSON instance
## reports parse errors as return values, so each problem is reported once, by us.
## The volume settings then apply to the buses.
func load_game() -> void:
	_load_save()
	_apply_volumes()


func _load_save() -> void:
	_reset_progress()
	_reset_settings()
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
		_reset_settings()
		_discard_save("corrupt (%s)" % problem)
		return
	print("[Game] Loaded save from %s: day %d%s, %d coins, reputation %d, stock %s, upgrades %s, flags %s, endings %s, Rush Hour %s (best %d%s), assist %s, gentle %s, music %d%s, sfx %d%s" % [
		save_path, day, " (market)" if at_market else "", coins, reputation, stock, upgrades, flags, endings, rush_hour_unlocked, rush_best, " assisted" if rush_best_assisted else "", assist_mode, gentle_mode, music_volume, " muted" if music_muted else "", sfx_volume, " muted" if sfx_muted else ""])


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


func _reset_settings() -> void:
	assist_mode = false
	gentle_mode = false
	music_volume = DEFAULT_MUSIC_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	music_muted = false
	sfx_muted = false


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
	rush_best_assisted = false


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
	rush_best_assisted = saved["rush_best_assisted"]
	var settings: Dictionary = saved["settings"]
	if settings.size() != SETTINGS_KEYS.size() or not SETTINGS_KEYS.all(func(key: String) -> bool: return settings.has(key)):
		return "settings must be exactly %s" % [SETTINGS_KEYS]
	for key in SETTINGS_KEYS:
		var setting: Variant = settings[key]
		if key in VOLUME_SETTINGS:
			if not _is_whole(setting) or int(setting) < 0 or int(setting) > VOLUME_MAX:
				return "settings.%s is not a whole number 0..%d" % [key, VOLUME_MAX]
		elif typeof(setting) != TYPE_BOOL:
			return "settings.%s is not true or false" % key
	assist_mode = settings["assist"]
	gentle_mode = settings["gentle"]
	music_volume = int(settings["music"])
	sfx_volume = int(settings["sfx"])
	music_muted = settings["music_muted"]
	sfx_muted = settings["sfx_muted"]
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
	return [_save_v1_to_v2, _save_v2_to_v3, _save_v3_to_v4, _save_v4_to_v5]


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


## Version 2 -> 3: the Rush Hour best gains its assisted marker; no earlier run set a
## best (Rush Hour did not exist), so it is false.
static func _save_v2_to_v3(saved: Dictionary) -> void:
	saved["rush_best_assisted"] = false


## Version 3 -> 4: the settings gain the music and sound effects volumes, at their defaults.
static func _save_v3_to_v4(saved: Dictionary) -> void:
	var settings: Variant = saved.get("settings")
	if settings is Dictionary:
		settings["music"] = DEFAULT_MUSIC_VOLUME
		settings["sfx"] = DEFAULT_SFX_VOLUME


## Version 4 -> 5: the settings gain the music and sound effects mutes, both off.
static func _save_v4_to_v5(saved: Dictionary) -> void:
	var settings: Variant = saved.get("settings")
	if settings is Dictionary:
		settings["music_muted"] = false
		settings["sfx_muted"] = false


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


func _log_transition(entry: String) -> void:
	transition_log.append(entry)
	print("[Game] goto " + entry)


func _report_error(message: String) -> void:
	reported_errors.append(message)
	_error_label.text = message
	_error_label.show()
	if not quiet_errors:
		push_error("[Game] " + message)
