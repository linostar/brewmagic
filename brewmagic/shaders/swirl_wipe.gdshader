// The potion swirl wipe of every screen change (Game.goto): the screen fills with a
// potion from the edges inwards, through a wobbling liquid circle, and drains back out.
// progress 0 clears the screen, 1 covers it. Drawn on a ColorRect over the whole
// visible rect; rect_size is that rect in base units, so the liquid's swirl bands and
// its rim snap to whole base units (pixel-art edges at any stretch scale).
// Plain canvas_item code (no screen texture), so it runs on the Compatibility renderer.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 liquid : source_color = vec4(0.565, 0.345, 0.753, 1.0);
uniform vec4 deep : source_color = vec4(0.165, 0.102, 0.282, 1.0);
uniform vec4 rim : source_color = vec4(0.816, 0.627, 0.91, 1.0);
uniform vec2 rect_size = vec2(270.0, 480.0);

const float RIM_WIDTH = 3.0;
const float SHADOW_WIDTH = 5.0;

void fragment() {
	// Base-unit pixel centres, relative to the screen centre.
	vec2 p = floor(UV * rect_size) + 0.5 - rect_size * 0.5;
	float d = length(p);
	float angle = atan(p.y, p.x);
	float reach = length(rect_size) * 0.5 + 12.0;
	// The wobble fades out at both ends, so 0 and 1 are exactly clear and covered.
	float wobble_amount = sin(progress * 3.14159265);
	float wobble = (5.0 * sin(angle * 6.0 + TIME * 5.0) + 3.0 * sin(angle * 11.0 - TIME * 7.0)) * wobble_amount;
	float edge = (1.0 - progress) * reach + wobble;
	if (progress <= 0.0 || d < edge) {
		COLOR = vec4(0.0);
	} else if (d < edge + RIM_WIDTH) {
		COLOR = rim;
	} else {
		// Swirling bands in the liquid, a darker band under the rim.
		float band = sin(angle * 3.0 + d * 0.05 - TIME * 4.0);
		vec4 body = mix(liquid, deep, step(0.55, band) * 0.5);
		COLOR = d < edge + RIM_WIDTH + SHADOW_WIDTH ? mix(body, deep, 0.6) : body;
	}
}
