// Palette swap for customer parts (CLAUDE.md "Customers", scripts/logic/look.gd):
// every texel whose colour is from_colors[i] (i < count) is drawn as to_colors[i];
// every other texel keeps its colour. The art is palette-indexed and filtered with
// Nearest, so texels hold exact palette colours; MATCH only absorbs float precision
// (palette colours are much further apart). Modulate (fades, misbrew tints) still applies.
shader_type canvas_item;

const int MAX_SWAPS = 12;
const float MATCH = 0.01;

uniform int count = 0;
uniform vec4 from_colors[MAX_SWAPS];
uniform vec4 to_colors[MAX_SWAPS];

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	for (int i = 0; i < MAX_SWAPS; i++) {
		if (i >= count) {
			break;
		}
		if (distance(texel.rgb, from_colors[i].rgb) < MATCH) {
			texel.rgb = to_colors[i].rgb;
			break;
		}
	}
	COLOR = texel * tint;
}
