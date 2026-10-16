class_name Economy
## Money and reputation rules (static, no nodes). The vertical-slice rules:
##   pay = round(potion price * PAY_SCALE[grade]); no tips yet.
##   reputation: REPUTATION_DELTA[grade] per served customer, STORMED_OFF_REPUTATION
##   (and no pay) when a customer's patience runs out.
## Tips, market prices and upgrade costs come with the day loop (plan step 6).

## Fraction of the potion price paid per grade, indexed by Brew.Grade.
const PAY_SCALE: Array[float] = [1.0, 0.75, 0.4, 0.0]
## Reputation change per grade, indexed by Brew.Grade.
const REPUTATION_DELTA: Array[int] = [2, 1, 0, -1]
const STORMED_OFF_REPUTATION := -2


## Coins a customer pays for a potion of `price` brewed at `grade`.
static func pay(price: int, grade: Brew.Grade) -> int:
	return roundi(price * PAY_SCALE[grade])


static func reputation_delta(grade: Brew.Grade) -> int:
	return REPUTATION_DELTA[grade]
