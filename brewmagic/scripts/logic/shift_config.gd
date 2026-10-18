class_name ShiftConfig
extends Resource
## Everything one shop shift runs on. Built by Shift: a story day from data/days.json
## (STORY), or a Rush Hour run (RUSH: endless customers from Rush, unlimited stock,
## the run's own reputation). The shop scene reads only this, so story and endless
## share every line of shop code.

enum Mode { STORY, RUSH }

## Seconds between arrivals on a story day while the line has room.
const STORY_ARRIVAL_GAP := 8.0

var mode := Mode.STORY
## Story day number (1..7); 0 in a Rush Hour run.
var day := 1
var title := ""
## The scheduled customers on this story path, in arrival order (empty in RUSH:
## customers come from Rush.customer).
var customers: Array[DayCustomer] = []
## The potions customers may ask for this shift (unlock_day <= day), in file order;
## in RUSH every potion a run reaches (each wave allows a part, Rush.potions_of_wave).
var allowed_potions: Array[PotionType] = []
## The ingredients on the shelf this shift (unlock_day <= day), in file order.
var ingredients: Array[Ingredient] = []
## Multiplies every customer's patience (in RUSH its start; Rush.patience_scale after).
var patience_scale := 1.0
## RUSH: seeds the shop's RandomNumberGenerator, so a run's customers and looks repeat.
var run_seed := 0


func is_rush() -> bool:
	return mode == Mode.RUSH


## True while customer number `index` (0-based) is still to come: within a story
## day's list, always in an endless run.
func has_customer(index: int) -> bool:
	return is_rush() or index < customers.size()


## Customer number `index` (0-based) after `served` were served: the story day's
## scheduled one, or the run's next from `rng` (Rush.customer, seeded by the run).
func customer_at(index: int, served: int, rng: RandomNumberGenerator) -> DayCustomer:
	return Rush.customer(rng, served) if is_rush() else customers[index]


## Seconds between arrivals after `served` were served (Rush Hour's shrinks).
func arrival_gap(served: int) -> float:
	return Rush.arrival_gap(served) if is_rush() else STORY_ARRIVAL_GAP


## The patience scale of a customer arriving after `served` were served.
func patience_at(served: int) -> float:
	return Rush.patience_scale(served) if is_rush() else patience_scale
