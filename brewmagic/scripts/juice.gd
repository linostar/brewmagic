class_name Juice
## Static feedback helpers (CLAUDE.md "Juice"). Every helper starts its effect
## on the call frame, so feedback lands well under 100 ms.


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
