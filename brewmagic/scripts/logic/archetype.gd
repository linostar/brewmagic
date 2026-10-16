class_name Archetype
extends Resource
## One customer personality from data/archetypes.json (fields as in data/SCHEMA.md). Built by Content.

## The reaction grades every archetype has lines for, in data order.
const GRADES: Array[String] = ["perfect", "good", "meh", "misbrew", "stormed_off"]

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
## Grade (one of GRADES) -> bubble lines.
var reactions: Dictionary[String, PackedStringArray] = {}
