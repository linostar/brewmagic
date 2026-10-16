class_name ShiftConfig
extends Resource
## Everything one shop shift runs on. Built by Shift (story days from data/days.json;
## Rush Hour adds its own mode and spawn rules in plan step 8). The shop scene reads
## only this, so story and endless share every line of shop code.

enum Mode { STORY }

var mode := Mode.STORY
## Story day number (1..7).
var day := 1
var title := ""
## The scheduled customers, in arrival order.
var customers: Array[DayCustomer] = []
## The potions customers may ask for this shift (unlock_day <= day), in file order.
var allowed_potions: Array[PotionType] = []
## The ingredients on the shelf this shift (unlock_day <= day), in file order.
var ingredients: Array[Ingredient] = []
## Multiplies every customer's patience.
var patience_scale := 1.0
