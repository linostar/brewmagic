extends SceneTree
## Project gate for the jam's mandatory "Playable on Mobile" restriction (CLAUDE.md "Hard rule"):
## - project.godot defines no input actions besides the built-in ui_* ones,
## - no script (standalone or embedded in .tscn/.tres) outside res://scripts/ui/ and
##   res://scripts/stations/station.gd reads mouse or key events, defines _input /
##   _unhandled_input style handlers, polls actions or keys, or relies on hover,
## - every interactive Control in a saved scene is at least MIN_TARGET base units on both
##   axes, and in full-screen scenes sits below the top TOP_ZONE of the screen (excepted:
##   the shop HUD's top-right row, TOP_RIGHT_NAMES, and only inside TOP_RIGHT_CORNER).
## Also compiles every script: project.godot raises GDScript warnings to errors,
## so any warning fails here.
## Usage (from repo root): "$GODOT" --headless --path brewmagic --script "$PWD/tools/check_project.gd"
## Prints "check_project: OK" on success; exits 1 and prints every violation otherwise
## (SCRIPT ERROR lines above them give compile details).
##
## Limits: this is a text and saved-scene scan. It does not see Controls created at
## runtime (Button.new()), input read through indirection (a variable holding an event
## class name), or layouts that only exist after a script moves nodes. Scenes are
## measured in a 270x480 window after two frames, so a Control sized by its script's
## _ready() is measured as the script leaves it. The top-zone rule only applies to scenes
## whose root Control fills the screen; parts (a shelf, a station) are checked for size only.
## A custom action named ui_something is indistinguishable from a built-in one here.

const ALLOWED_INPUT_PATHS: Array[String] = ["res://scripts/ui/", "res://scripts/stations/station.gd"]
## Raw mouse/key reads, input callbacks, action polling and hover signals.
const FORBIDDEN_TOKENS: Array[String] = [
	"InputEventMouse", "InputEventKey", "InputEventJoypad",
	"func _input", "func _unhandled_input", "func _unhandled_key_input", "func _shortcut_input",
	"is_key_pressed", "is_physical_key_pressed", "is_key_label_pressed", "is_mouse_button_pressed",
	"is_action", "get_action_strength", "get_action_raw_strength", "get_axis", "get_vector",
	"is_anything_pressed", "mouse_entered", "mouse_exited", "get_mouse_position",
]
const SOURCE_EXTENSIONS: Array[String] = ["gd", "tscn", "tres"]
const BASE_SIZE := Vector2i(270, 480)
const MIN_TARGET := 32.0
## Fraction of the screen height, from the top, reserved for reading.
const TOP_ZONE := 0.4
## The controls allowed in the reading zone: the shop HUD's music and sound toggles and
## the pause button, one row in the top-right corner (that many base units from the right
## edge and the top). Anywhere else they are held to the rule like any other control.
const TOP_RIGHT_NAMES: Array[StringName] = [&"MusicToggle", &"SfxToggle", &"PauseButton"]
const TOP_RIGHT_CORNER := Vector2(118, 48)

var _violations: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = BASE_SIZE
	_check_actions()
	var files: Array[String] = []
	_collect_files("res://", files)
	for path in files:
		if path.ends_with(".gd"):
			_check_compiles(path)
		if path.get_extension() in SOURCE_EXTENSIONS and not _input_allowed(path):
			_check_source(path)
	for path in files:
		if path.ends_with(".tscn"):
			await _check_scene(path)
	if _violations.is_empty():
		print("check_project: OK (%d files scanned)" % files.size())
		quit(0)
		return
	for violation in _violations:
		printerr("check_project: " + violation)
	printerr("check_project: FAILED with %d violation(s)" % _violations.size())
	quit(1)


## Only the built-in ui_* actions may exist (overriding their events is allowed).
func _check_actions() -> void:
	for property in ProjectSettings.get_property_list():
		var name: String = property["name"]
		if name.begins_with("input/") and not name.begins_with("input/ui_"):
			_violations.append("project.godot defines input action '%s' (only built-in ui_* actions are allowed)" % name.trim_prefix("input/"))


func _check_compiles(path: String) -> void:
	var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
	if script == null or not script.can_instantiate():
		_violations.append("%s: fails to compile (warnings count as errors)" % path)


func _input_allowed(path: String) -> bool:
	for allowed in ALLOWED_INPUT_PATHS:
		if path == allowed or (allowed.ends_with("/") and path.begins_with(allowed)):
			return true
	return false


func _check_source(path: String) -> void:
	var source := _read_text(path)
	for token in FORBIDDEN_TOKENS:
		if token in source:
			_violations.append("%s: uses '%s' (raw mouse/key input, action polling and hover belong in scripts/ui/ or the Station base)" % [path, token])


func _read_text(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		_violations.append("%s: cannot read file (error %d)" % [path, FileAccess.get_open_error()])
	return text


## Instantiates the scene in the base-size window, lets containers and anchors settle,
## then measures every interactive Control.
func _check_scene(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		_violations.append("%s: failed to load scene" % path)
		return
	var scene_root := packed.instantiate()
	if scene_root == null:
		_violations.append("%s: failed to instantiate scene" % path)
		return
	root.add_child(scene_root)
	await process_frame
	await process_frame
	var root_control := scene_root as Control
	var full_screen := root_control != null and root_control.get_global_rect().size.is_equal_approx(root.get_visible_rect().size)
	_check_node(path, scene_root, full_screen)
	scene_root.queue_free()
	await process_frame


func _check_node(path: String, node: Node, full_screen: bool) -> void:
	var control := node as Control
	if control != null and _is_interactive(control):
		var rect := control.get_global_rect()
		if rect.size.x < MIN_TARGET or rect.size.y < MIN_TARGET:
			_violations.append("%s: interactive Control '%s' is %s, smaller than %dx%d" % [path, _scene_path_of(control), rect.size, int(MIN_TARGET), int(MIN_TARGET)])
		var top_limit := root.get_visible_rect().size.y * TOP_ZONE
		if full_screen and not _in_top_right_row(control, rect) and rect.position.y < top_limit:
			_violations.append("%s: interactive Control '%s' starts at y=%.0f, inside the top %d%% reading zone" % [path, _scene_path_of(control), rect.position.y, int(TOP_ZONE * 100.0)])
	for child in node.get_children():
		_check_node(path, child, full_screen)


## True for one of TOP_RIGHT_NAMES lying wholly inside the top-right TOP_RIGHT_CORNER.
func _in_top_right_row(control: Control, rect: Rect2) -> bool:
	var width := root.get_visible_rect().size.x
	return control.name in TOP_RIGHT_NAMES and rect.position.x >= width - TOP_RIGHT_CORNER.x and rect.end.x <= width and rect.end.y <= TOP_RIGHT_CORNER.y


func _is_interactive(control: Control) -> bool:
	if control is BaseButton or control is LineEdit or control is Slider or control is ScrollContainer or control is ItemList:
		return true
	var script := control.get_script() as Script
	if control.mouse_filter != Control.MOUSE_FILTER_STOP or script == null:
		return false
	return script.get_script_method_list().any(func(method: Dictionary) -> bool: return method["name"] == "_gui_input")


func _scene_path_of(node: Node) -> String:
	var owner_node := node.owner if node.owner != null else node
	return str(owner_node.get_path_to(node))


func _collect_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_violations.append("%s: cannot open directory (error %d)" % [dir_path, DirAccess.get_open_error()])
		return
	for file in dir.get_files():
		out.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		# A .gdignore keeps a directory out of the project, as in Godot's import (the Android
		# build template's android/build/ ships one, with test scripts of its own).
		if not sub.begins_with(".") and not FileAccess.file_exists(dir_path.path_join(sub).path_join(".gdignore")):
			_collect_files(dir_path.path_join(sub), out)
