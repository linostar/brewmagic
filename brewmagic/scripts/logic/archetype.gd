class_name Archetype
extends Resource
## One customer personality from data/archetypes.json (fields as in data/SCHEMA.md). Built by Content.

## The reaction grades every archetype has lines for, in data order.
const GRADES: Array[String] = ["perfect", "good", "meh", "misbrew", "stormed_off", "refused"]

var id := ""
var name := ""
var patience_seconds := 10
var tip_tendency := 0.0
var voice_pitch := 1.0
## "reed", "bell", "growl" or "chirp".
var voice_timbre := ""
## Writer's note, never shown.
var speech_style := ""
var part_body := ""
var part_head := ""
var part_hair := ""
var part_accessory := ""
## A story character's one fixed look (data `look`), or null for a visitor whose
## colours come from a palette shuffle (Look.distinct_for).
var fixed_look: Look
## Grade (one of GRADES) -> bubble lines.
var reactions: Dictionary[String, PackedStringArray] = {}


## True for a story character: it has a fixed look and visits only as story beats.
func is_story() -> bool:
	return fixed_look != null
