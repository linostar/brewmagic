class_name Look
extends RefCounted
## A customer's colours (CLAUDE.md "Customers"): one ramp for each swappable group of
## the customer part art (contract in the art_src/customer.px header): cloth A (bodies,
## the witch hat), cloth B (trim, belts, hat bands), hair, and skin (the head's skin
## pair, and the hands on the body). shaders/palette_swap.gdshader maps a part's own
## colours of a group onto the look's ramp, so the same few parts make hundreds of
## distinct visitors. Every ramp colour is a colour of art_src/palette.hex
## (test_gameplay checks it).
##
## A look comes from a seed (from_seed, deterministic). distinct_for() gives every
## visitor of a shift a look that differs on screen from all the others: two looks
## only count as different when the colours their parts actually show differ
## (signature(), from the colours each sprite uses, Art.colors).

## Ramps dark -> light, 3 colours each, used for cloth A and cloth B.
const CLOTHS: Dictionary[String, Array] = {
	"blue": ["#1e3866", "#3a74b4", "#68bede"],
	"green": ["#1c4632", "#38883e", "#7cc44c"],
	"red": ["#6e2028", "#c43c2c", "#f07c2c"],
	"ochre": ["#8a5a3c", "#b8804c", "#e6b46e"],
	"purple": ["#2a1a48", "#583088", "#9058c0"],
	"lilac": ["#583088", "#9058c0", "#d0a0e8"],
	"grey": ["#5c5668", "#8c8494", "#c8c0c8"],
	"brown": ["#3a2830", "#5c3c30", "#8a5a3c"],
	"sky": ["#3a74b4", "#68bede", "#c8f0f0"],
	"lime": ["#38883e", "#7cc44c", "#cce878"],
}
## Hair ramps dark -> light.
const HAIRS: Dictionary[String, Array] = {
	"brown": ["#3a2830", "#5c3c30", "#8a5a3c"],
	"black": ["#1c1420", "#3a2830", "#4a3440"],
	"blonde": ["#b8804c", "#e6b46e", "#fbedcd"],
	"ginger": ["#6e2028", "#c43c2c", "#f07c2c"],
	"grey": ["#5c5668", "#8c8494", "#c8c0c8"],
	"white": ["#8c8494", "#c8c0c8", "#fbedcd"],
	"violet": ["#583088", "#9058c0", "#d0a0e8"],
	"blue": ["#1e3866", "#3a74b4", "#68bede"],
}
## Skin pairs (main, shade).
const SKINS: Dictionary[String, Array] = {
	"light": ["#f6cca4", "#c88a5c"],
	"medium": ["#c88a5c", "#8a5634"],
	"deep": ["#8a5634", "#5c3c30"],
}
## The art's own colours of each group (palette e f g, i j k, 1 2 3).
const CLOTH_A_ART: Array[String] = ["#1e3866", "#3a74b4", "#68bede"]
const CLOTH_B_ART: Array[String] = ["#1c4632", "#38883e", "#7cc44c"]
const HAIR_ART: Array[String] = ["#3a2830", "#5c3c30", "#8a5a3c"]
## The hands on every body are drawn in the light pair (palette r s).
const HAND_ART := "light"
## Each head's own skin pair (art_src/customer.px header). The dragon snout has none of
## them (scales), so its "light" entry swaps nothing.
const HEAD_SKIN_ART: Dictionary[String, String] = {"round": "light", "long": "medium", "square": "deep", "snout": "light"}
## Rolls distinct_for() tries per visitor before it gives up on a fresh look.
const MAX_TRIES := 200

var cloth_a := "blue"
var cloth_b := "green"
var hair := "brown"
var skin := "light"


## The look picked by `look_seed`: two different cloth ramps, a hair ramp and a skin pair.
static func from_seed(look_seed: int) -> Look:
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	var look := Look.new()
	var cloths := CLOTHS.keys()
	look.cloth_a = cloths[rng.randi_range(0, cloths.size() - 1)]
	cloths.erase(look.cloth_a)
	look.cloth_b = cloths[rng.randi_range(0, cloths.size() - 1)]
	look.hair = HAIRS.keys()[rng.randi_range(0, HAIRS.size() - 1)]
	look.skin = SKINS.keys()[rng.randi_range(0, SKINS.size() - 1)]
	return look


## One look per visitor, `parts[i]` being visitor i's part names (Customer.parts_of),
## no two of them alike on screen (signature). Deterministic for a given `shift_seed`.
## A visitor whose parts have run out of fresh looks is reported and gets a repeat.
static func distinct_for(parts: Array[Array], shift_seed: int) -> Array[Look]:
	var rng := RandomNumberGenerator.new()
	rng.seed = shift_seed
	var taken := {}
	var looks: Array[Look] = []
	for i in parts.size():
		var part_names: Array[String] = []
		part_names.assign(parts[i])
		looks.append(next_distinct(part_names, rng, taken, i))
	return looks


## The next look from `rng` whose signature on `part_names` is not in `taken` (which
## it joins), for visitor number `visitor` of a shift or run; after MAX_TRIES it is
## reported and repeats one. distinct_for and the endless Rush Hour line share it.
static func next_distinct(part_names: Array[String], rng: RandomNumberGenerator, taken: Dictionary, visitor: int) -> Look:
	var look := from_seed(rng.randi())
	var tries := 1
	while taken.has(look.signature(part_names)) and tries < MAX_TRIES:
		look = from_seed(rng.randi())
		tries += 1
	var key := look.signature(part_names)
	if taken.has(key):
		push_error("[Look] Visitor %d (%s) found no unused look in %d tries; it repeats one" % [visitor, part_names, MAX_TRIES])
	taken[key] = true
	return look


## Every look from_seed can pick, for counting and enumerating.
static func all() -> Array[Look]:
	var looks: Array[Look] = []
	for a: String in CLOTHS:
		for b: String in CLOTHS:
			if a == b:
				continue
			for h: String in HAIRS:
				for s: String in SKINS:
					var look := Look.new()
					look.cloth_a = a
					look.cloth_b = b
					look.hair = h
					look.skin = s
					looks.append(look)
	return looks


## art colour -> look colour for part `part` ("body_robe", "head_round", "hair_curly",
## a face or an accessory), limited to the colours its idle frames _0 and _1 use.
func swaps(part: String) -> Dictionary[String, String]:
	var all_swaps: Dictionary[String, String] = {}
	var kind := part.get_slice("_", 0)
	match kind:
		"body":
			_map(all_swaps, CLOTH_A_ART, CLOTHS[cloth_a])
			_map(all_swaps, CLOTH_B_ART, CLOTHS[cloth_b])
			_map(all_swaps, SKINS[HAND_ART], SKINS[skin])
		"head":
			var head := part.trim_prefix("head_")
			if not HEAD_SKIN_ART.has(head):
				push_error("[Look] Head '%s' has no skin pair in Look.HEAD_SKIN_ART" % head)
				return {}
			_map(all_swaps, SKINS[HEAD_SKIN_ART[head]], SKINS[skin])
		"hair":
			_map(all_swaps, CLOTH_A_ART, CLOTHS[cloth_a])
			_map(all_swaps, CLOTH_B_ART, CLOTHS[cloth_b])
			_map(all_swaps, HAIR_ART, HAIRS[hair])
	var used := Art.colors("customer", part + "_0") + Art.colors("customer", part + "_1")
	var result: Dictionary[String, String] = {}
	for from: String in all_swaps:
		if from in used and all_swaps[from] != from:
			result[from] = all_swaps[from]
	return result


## What `part_names` look like in this look: equal signatures draw the same pixels.
func signature(part_names: Array[String]) -> String:
	var out := PackedStringArray()
	for part in part_names:
		var swapped := swaps(part)
		var keys := swapped.keys()
		keys.sort()
		out.append(part + ":" + ",".join(keys.map(func(from: String) -> String: return from + ">" + swapped[from])))
	return " ".join(out)


func describe() -> String:
	return "cloth %s/%s, hair %s, skin %s" % [cloth_a, cloth_b, hair, skin]


static func _map(into: Dictionary[String, String], from: Array, to: Array) -> void:
	for i in from.size():
		into[from[i]] = to[i]
