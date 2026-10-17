class_name DayCustomer
extends Resource
## One scheduled customer of a DaySpec (days.json customers[]). Built by Content.

var archetype := ""
var potion := ""
## Pinned RequestLine id, or "" for a random request of (potion, archetype).
var request := ""
## The story beat this visit plays (data `beat`), or "" for an ordinary customer.
var beat := ""
## A story beat's own reaction per Story.OUTCOMES entry (great, poor, refused, stormed_off).
var lines: Dictionary[String, String] = {}
## Flag -> the outcomes it must have for this customer to come (data `when`); empty: always.
var when: Dictionary[String, PackedStringArray] = {}


## The flag this visit's outcome is stored under ("<archetype>.<beat>"), or "" when it is no beat.
func flag() -> String:
	return "" if beat == "" else "%s.%s" % [archetype, beat]
