extends SceneTree
## Headless run of the game's main scene for validate.sh: loads it the way the
## engine would, runs RUN_FRAMES frames (env, default 300), then frees it and quits cleanly.
## Prints "run_main: OK" on success.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	var error := change_scene_to_file(path)
	if error != OK:
		printerr("run_main: FAILED to load main scene '%s': %s" % [path, error_string(error)])
		quit(1)
		return
	var frames := int(OS.get_environment("RUN_FRAMES")) if OS.get_environment("RUN_FRAMES") != "" else 300
	for i in frames:
		await process_frame
	# The main scene (the splash) moves on by itself; say where the flow got to.
	var game := root.get_node_or_null("Game") as GameState
	var at := str(GameState.Flow.keys()[game.state]) if game != null else "no Game autoload"
	current_scene.queue_free()
	await process_frame
	print("run_main: OK (%s, %d frames, flow at %s)" % [path, frames, at])
	quit(0)
