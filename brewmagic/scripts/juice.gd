class_name Juice
## Static feedback helpers (CLAUDE.md "Juice"). Every helper starts its effect
## on the call frame, so feedback lands well under 100 ms.

## The longest hit-stop, in seconds.
const HIT_STOP_MAX := 0.1

## How many hit-stops have started (tests read it).
static var hit_stops := 0
## The real-time length of the latest hit-stop, in seconds.
static var last_hit_stop := 0.0
## Hit-stops still running (overlapping ones extend the freeze) and the time scale to
## restore when the last ends (the story playthrough tests run the game at 4x).
static var _stops_running := 0
static var _scale_before := 1.0


## Freezes game motion for `duration` seconds of real time (at most HIT_STOP_MAX): the
## engine's time scale drops to 0, so tweens, timers, particles and stations stand still,
## while input keeps arriving (events are never time-scaled). A timer that ignores the
## time scale ends it and restores the scale it found.
static func hit_stop(tree: SceneTree, duration := 0.08) -> void:
	var length := clampf(duration, 0.0, HIT_STOP_MAX)
	if length <= 0.0:
		return
	if _stops_running == 0:
		_scale_before = Engine.time_scale
	_stops_running += 1
	hit_stops += 1
	last_hit_stop = length
	Engine.time_scale = 0.0
	tree.create_timer(length, true, false, true).timeout.connect(_end_hit_stop)


## True while a hit-stop freezes the game.
static func is_hit_stopped() -> bool:
	return _stops_running > 0


static func _end_hit_stop() -> void:
	_stops_running -= 1
	if _stops_running == 0:
		Engine.time_scale = _scale_before


## Squash then stretch `target` (a Node2D or Control) back to its rest scale: the
## scale it had at its first squash. A new squash replaces a running one, so
## rapid calls never drift the scale. `strength` is the peak squash fraction.
static func squash(target: CanvasItem, strength := 0.2, duration := 0.24) -> Tween:
	var rest: Vector2 = target.get_meta(&"juice_rest_scale", target.get("scale"))
	target.set_meta(&"juice_rest_scale", rest)
	if target.has_meta(&"juice_squash"):
		(target.get_meta(&"juice_squash") as Tween).kill()
	var tween := target.create_tween()
	target.set_meta(&"juice_squash", tween)
	tween.tween_property(target, "scale", rest * Vector2(1.0 + strength, 1.0 - strength), duration * 0.25)
	tween.tween_property(target, "scale", rest * Vector2(1.0 - strength * 0.5, 1.0 + strength * 0.5), duration * 0.25)
	tween.tween_property(target, "scale", rest, duration * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


## The press squash of a Control (every Button press, Game._on_node_added): squash then
## stretch about its centre like squash(), but drawn only: the Control's canvas item is
## given the squashed transform while its own scale stays 1, so its rect, its touch
## area and keyboard focus navigation (which reads the node's transform) never move
## while it plays. The visual scale is kept in the meta "juice_press_scale" (tests).
static func press(target: Control, strength := 0.12, duration := 0.24) -> Tween:
	if target.has_meta(&"juice_press"):
		(target.get_meta(&"juice_press") as Tween).kill()
	var tween := target.create_tween()
	target.set_meta(&"juice_press", tween)
	var wide := Vector2(1.0 + strength, 1.0 - strength)
	var tall := Vector2(1.0 - strength * 0.5, 1.0 + strength * 0.5)
	tween.tween_method(_draw_scaled.bind(target), Vector2.ONE, wide, duration * 0.25)
	tween.tween_method(_draw_scaled.bind(target), wide, tall, duration * 0.25)
	tween.tween_method(_draw_scaled.bind(target), tall, Vector2.ONE, duration * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


## Draws `target` scaled by `drawn` about its centre, on top of its own transform.
static func _draw_scaled(drawn: Vector2, target: Control) -> void:
	var centre := target.size / 2.0
	var local := Transform2D(0.0, drawn, 0.0, centre - centre * drawn)
	RenderingServer.canvas_item_set_transform(target.get_canvas_item(), target.get_transform() * local)
	target.set_meta(&"juice_press_scale", drawn)


## A one-shot particle burst of `amount` square pixels at `at` (in `parent`'s
## space), flying outwards and pulled by `gravity`. Frees itself when done.
static func burst(parent: Node, at: Vector2, color: Color, amount := 12, gravity := Vector2.ZERO) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.5
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 70.0
	particles.gravity = gravity
	particles.damping_min = 20.0
	particles.damping_max = 40.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = color
	particles.finished.connect(particles.queue_free)
	parent.add_child(particles)
	particles.emitting = true
	return particles


## Shakes `target` (a Node2D or Control) around its rest position: the position
## it had at its first shake. A new shake replaces a running one. `strength` is
## the peak offset in base units, decaying to 0 over `duration`.
static func shake(target: CanvasItem, strength := 3.0, duration := 0.25) -> Tween:
	var rest: Vector2 = target.get_meta(&"juice_rest_position", target.get("position"))
	target.set_meta(&"juice_rest_position", rest)
	if target.has_meta(&"juice_shake"):
		(target.get_meta(&"juice_shake") as Tween).kill()
	var tween := target.create_tween()
	target.set_meta(&"juice_shake", tween)
	tween.tween_method(func(left: float) -> void:
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * left
		target.set("position", rest + offset.round()), 1.0, 0.0, duration)
	tween.tween_callback(func() -> void: target.set("position", rest))
	return tween


## Forgets the rest position shake() remembered, for a target that was moved on purpose.
static func reset_shake(target: CanvasItem) -> void:
	if target.has_meta(&"juice_shake"):
		(target.get_meta(&"juice_shake") as Tween).kill()
		target.remove_meta(&"juice_shake")
	target.remove_meta(&"juice_rest_position")


## Flies `node` (a Node2D) from `from` to `to` (its parent's space) on a parabola
## peaking `height` above the straight line. The tween's `finished` marks the landing.
static func arc(node: Node2D, from: Vector2, to: Vector2, height: float, duration: float) -> Tween:
	node.position = from
	var tween := node.create_tween()
	tween.tween_method(func(t: float) -> void:
		node.position = from.lerp(to, t) - Vector2(0, height * 4.0 * t * (1.0 - t)), 0.0, 1.0, duration)
	return tween


## A short text that pops at `at` (in `parent`'s space, centred), floats up and
## fades. Frees itself when done.
static func pop_text(parent: Node, at: Vector2, text: String, color: Color, font_size := 25) -> Label:
	var label := _popped_label(parent, at, text, color, font_size)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 14.0, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.35)
	tween.tween_callback(label.queue_free)
	return label


## A short text that pops at `from` (in `parent`'s space, centred), waits `hold`
## seconds, then flies to `to` shrinking and fades as it lands. Frees itself when done.
static func fly_text(parent: Node, from: Vector2, to: Vector2, text: String, color: Color, hold: float, font_size := 25) -> Label:
	var label := _popped_label(parent, from, text, color, font_size)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(hold)
	tween.tween_property(label, "position", (to - label.size / 2.0).round(), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "scale", Vector2(0.5, 0.5), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.15).set_delay(0.3)
	tween.tween_callback(label.queue_free)
	return label


## An outlined label centred on `at`, starting at 0.4 scale for a pop-in.
static func _popped_label(parent: Node, at: Vector2, text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color("#1c1420"))
	label.add_theme_constant_override(&"outline_size", 4)
	label.add_theme_font_size_override(&"font_size", font_size)
	parent.add_child(label)
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size / 2.0
	label.position = (at - label.size / 2.0).round()
	label.scale = Vector2(0.4, 0.4)
	return label
