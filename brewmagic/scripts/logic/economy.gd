class_name Economy
## Money and reputation rules (static, no nodes):
##   pay = round(potion price * PAY_SCALE[grade]).
##   tip = round(potion price * TIP_SCALE[grade] * archetype tip_tendency) on top of the pay.
##   reputation: REPUTATION_DELTA[grade] per served customer, STORMED_OFF_REPUTATION
##   (and no pay) when a customer's patience runs out, REFUSED_REPUTATION (no pay) when
##   the shop refuses one.
##   market price of an ingredient: the day's `market` price, else its base_price (SCHEMA.md).
##   upgrade cost: the cost of the next level; tolerance: the owned level's multiplier.

## Fraction of the potion price paid per grade, indexed by Brew.Grade.
const PAY_SCALE: Array[float] = [1.0, 0.75, 0.4, 0.0]
## Fraction of the potion price a fully generous customer (tip_tendency 1) tips per grade.
const TIP_SCALE: Array[float] = [0.5, 0.25, 0.0, 0.0]
## Reputation change per grade, indexed by Brew.Grade.
const REPUTATION_DELTA: Array[int] = [2, 1, 0, -1]
const STORMED_OFF_REPUTATION := -2
## Reputation change when the shop refuses a customer (Shop.refuse_customer), no pay.
const REFUSED_REPUTATION := -1
## upgrade_cost() of an upgrade at its last level.
const MAXED := -1


## Coins a customer pays for a potion of `price` brewed at `grade`.
static func pay(price: int, grade: Brew.Grade) -> int:
	return roundi(price * PAY_SCALE[grade])


## Coins a customer with `tip_tendency` (0..1) tips on top of the pay.
static func tip(price: int, grade: Brew.Grade, tip_tendency: float) -> int:
	return roundi(price * TIP_SCALE[grade] * tip_tendency)


static func reputation_delta(grade: Brew.Grade) -> int:
	return REPUTATION_DELTA[grade]


## The price of one `item` in the market held the evening before `spec`'s day.
static func market_price(spec: DaySpec, item: Ingredient) -> int:
	return spec.market.get(item.id, item.base_price)


## The cost of the level after `level` (owned, 0 = none), or MAXED.
static func upgrade_cost(upgrade: Upgrade, level: int) -> int:
	return upgrade.costs[level] if level < upgrade.max_level() else MAXED


## The station tolerance multiplier at owned `level` (1 with none).
static func upgrade_tolerance(upgrade: Upgrade, level: int) -> float:
	return upgrade.tolerances[level - 1] if level > 0 else 1.0
