class_name HintWord
extends Resource
## One hint word from data/vocabulary.json (fields as in data/SCHEMA.md). Built by Content.

var id := ""
## What the Codex shows ("warmth").
var word := ""
## Index into Content.ESSENCES.
var essence := 0
## Prefixes that count as this word at the start of a word in request text.
var forms := PackedStringArray()
## The requests whose hints contain this word, in requests.json order.
var request_ids := PackedStringArray()
