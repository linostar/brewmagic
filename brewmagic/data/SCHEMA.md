# BrewMagic content schema

Source of truth for every file in `brewmagic/data/`. `Content` (`scripts/logic/content.gd`) loads against this
document and `tools/test_content.gd` checks the invariants at the end. If the code and this file disagree, fix one of them so they match. Do not leave the code working around the difference.

## Conventions (all files)
- UTF-8 JSON. Every file's top level is a **non-empty array of objects**; every object has a unique `"id"`.
- Ids are snake_case: `^[a-z][a-z0-9_]*$`, unique within their file.
- Every field listed below is **required** unless marked *optional*. The loader reports a missing key, a
  wrong type, an out-of-range value, an unknown id **and an unknown key** with `push_error` naming the file,
  the entry id and the field. No silent defaults.
- `int` means a JSON integer. Godot parses all JSON numbers as `float`, so the loader must check that
  `value == floor(value)` and then cast. `float` accepts integers too.
- **Essence vector**: an array of exactly 4 ints in the fixed order `[ember, frost, bloom, gloom]`, loaded as
  `Vector4i`. Essence names are the enum `"ember" | "frost" | "bloom" | "gloom"` (index 0..3 in that order).
- Day numbers are ints `1..7` (story days).
- File order matters only where stated (reaction lines and `request_ids`). Everywhere else, order is for humans only.

### Speech bubble limit
Every string marked **bubble** must fit a speech bubble of **3 lines x 26 characters**:
- no newline characters; at most 78 characters in total; no single word (space-separated token) longer than 26;
- greedy word wrap at 26 characters (words joined by one space, a word moves to the next line if it would
  push the line past 26) produces at most 3 lines.
`Content.wrap_bubble()` implements this wrap and is the only layout: the Godot speech bubble shows exactly the lines it
returns and never uses Label autowrap (the rule is a character count, and the inline hint-word icons would make a
width-based wrap break differently).

Other strings: `name`/`title`/`word` <= 26 chars; `description` <= 120 chars; `speech_style` <= 200 chars
(dev note, never shown).

## Game rules the data relies on
- **Brew** = element-wise sum of the essence vectors of 2 or 3 ingredients (the same ingredient may appear
  more than once if stock allows).
- **Match** = L1 distance `|de|+|df|+|db|+|dg|` between brew and the potion's `target`:
  `0` Perfect, `1` Good, `2` Meh, `>=3` Misbrew.
- **Misbrew essence** = the essence with the largest overshoot `brew[k] - target[k] > 0`; ties go to the
  lowest index (ember, then frost, then bloom, then gloom). The data guarantees that every misbrew has an
  overshoot (invariant I9), so Brew needs no fallback.
- **Customer patience** = `archetype.patience_seconds * day.patience_scale`.
- **Allowed potions on day N** = every potion with `unlock_day <= N`. **Ingredients on sale on day N** = every
  ingredient with `unlock_day <= N`.

---

## ingredients.json
| field | type | range / enum | notes |
|---|---|---|---|
| `id` | string | snake_case | Also the sprite name in the ingredient atlas. |
| `name` | string | 1..26 chars | Display name. |
| `essence` | essence vector | each 0..3, not all 0 | |
| `unlock_day` | int | 1..7 | First day it is on the shelf or in the market. |
| `base_price` | int | 1..999 | Default market price in coins. A day's `market` overrides it. |
| `grind` | bool | | `true` means the brew needs the Mortar station. All day 1-2 ingredients are `false`. |
| `description` | string | 1..120 chars | Codex line. |

## potions.json
| field | type | range / enum | notes |
|---|---|---|---|
| `id` | string | snake_case | |
| `name` | string | 1..26 chars | Display name. Requests must never contain it (I6). |
| `target` | essence vector | each 0..9 | The vector a Perfect brew hits exactly. |
| `color` | string | `^#[0-9a-f]{6}$` | Liquid colour, picked from `art_src/palette.hex`. It tints the neutral liquid sprite in code. |
| `bottle` | string | `"round" \| "tall" \| "flask" \| "teardrop"` | Bottle sprite shape. |
| `unlock_day` | int | 1..7 | |
| `steps` | array of string | non-empty, unique, each `"stir" \| "pour" \| "mortar" \| "bellows"` | Station order for brewing. Potions with `unlock_day <= 2` use exactly `["stir", "pour"]`. |
| `price` | int | 1..999 | Base sale price in coins before grade and tip. |
| `description` | string | 1..120 chars | Codex line. |

## vocabulary.json (hint words)
| field | type | range / enum | notes |
|---|---|---|---|
| `id` | string | `hint_<word>` | |
| `word` | string | 1..26 chars | What the Codex shows ("warmth"). |
| `essence` | string | essence enum | Every hint word maps to exactly one essence, everywhere in the game. |
| `forms` | array of string | non-empty, each `^[a-z]+$` | Prefixes that count as this word in request text. |
| `request_ids` | array of string | request ids | Exactly the requests whose `hints` contain this id, in `requests.json` file order. It is derived data: regenerate it whenever requests change. The Codex uses it to know which hint words a served request taught the player. |

**Form matching**: a form matches when it appears at the **start of a word**, case-insensitive: regex
`\b<form>`. For example, `warm` matches "warm", "warmth", "Warmly" but not "swarm"; `night` matches "night" and
"Night-blooming" but not "knight" or "midnight". The full map:
ember: warmth (`warm`), courage, brave, fire. frost: calm, cold, cooling (`cool`). bloom: growth (`grow`), healing (`heal`),
freshness (`fresh`). gloom: sleep (`sleep`, `slept`), curses (`curse`), spooky (`spook`), night.

## archetypes.json
| field | type | range / enum | notes |
|---|---|---|---|
| `id` | string | snake_case | |
| `name` | string | 1..26 chars | Display name of this recurring visitor. |
| `patience_seconds` | int | 10..300 | Before `patience_scale`. |
| `tip_tendency` | float | 0.0..1.0 | 0 never tips, 1 tips generously. |
| `voice` | object | keys exactly `pitch`, `timbre` | |
| `voice.pitch` | float | 0.5..2.0 | Voice-blip pitch multiplier. |
| `voice.timbre` | string | `"reed" \| "bell" \| "growl" \| "chirp"` | Voice-blip sample set. |
| `speech_style` | string | 1..200 chars | Writer's note, not shown in game. |
| `parts` | object | keys exactly `body`, `head`, `hair`, `accessory` | A part value `<v>` is drawn from the customer atlas (`art/customer.json`) frames `<prefix>_<v>_0` and `<prefix>_<v>_1` (idle bob), with prefix `body`, `head`, `hair`, `acc` for `body`, `head`, `hair`, `accessory`. Accessory `"none"` draws nothing. Both frames must exist (checked by `tools/test_content.gd`). |
| `parts.body` | string | `"robe" \| "apron" \| "armour"` | |
| `parts.head` | string | `"round" \| "long" \| "square"` | |
| `parts.hair` | string | `"witch_hat" \| "straw_hat" \| "curly" \| "bald_beard"` | |
| `parts.accessory` | string | `"none" \| "goat" \| "lantern"` | |
| `reactions` | object | keys exactly `perfect`, `good`, `meh`, `misbrew`, `stormed_off` | |
| `reactions.<grade>` | array of string | >= 3 entries, each **bubble** | One line is picked at random, avoiding the one used last for that archetype and grade. `misbrew` is the customer's own reaction; the absurd effect line comes from `misbrews.json`. `stormed_off` is said when patience runs out. |

## requests.json
| field | type | range / enum | notes |
|---|---|---|---|
| `id` | string | `<potion short>_<archetype>_<n>` | |
| `potion` | string | potion id | The potion this hint asks for. |
| `archetype` | string | archetype id | The voice it is written in. Only this archetype says it. |
| `hints` | array of string | non-empty, unique, vocabulary ids | Every hint word in `text` (see I4). |
| `text` | string | **bubble** | Never names a potion (I6). |

Selection: a random customer with archetype A who wants potion P says a random request with
`(potion, archetype) == (P, A)`, avoiding recent repeats. A day can pin one with `customers[].request`.

## misbrews.json
| field | type | range / enum | notes |
|---|---|---|---|
| `id` | string | `misbrew_<essence>_<n>` | |
| `essence` | string | essence enum | The overshooting essence that selects this line. |
| `effect` | string | `"singed" \| "frosted" \| "sprouting" \| "gloomy"` | Visual on the customer. It is fixed per essence: ember->singed, frost->frosted, bloom->sprouting, gloom->gloomy. |
| `text` | string | **bubble** | Narration, no pronouns, shown over the customer. |

## days.json
| field | type | range / enum | notes |
|---|---|---|---|
| `id` | string | `day_<day>` | |
| `day` | int | 1..7 | The days present are exactly 1..N, each once. |
| `title` | string | 1..26 chars | Morning card title. |
| `morning_note` | string | **bubble** | Morning card tip. |
| `patience_scale` | float | 0.25..3.0 | Multiplies every customer's patience that day. |
| `starting_coins` | int | 0..9999 | **Day 1 only (required there, an error on other days).** |
| `starting_stock` | object `{ingredient id: int 0..99}` | keys ⊆ ingredients unlocked on day 1 | **Day 1 only (required there, an error on other days).** Missing keys mean 0. |
| `market` | object `{ingredient id: int 1..999}` | keys == exactly the ingredients with `unlock_day <= day` | **Days >= 2 only (required there, an error on day 1).** Prices in the market screen held the evening *before* this day, so the player shops for this day. The market sells any quantity. |
| `customers` | array of object | non-empty | In arrival order. |
| `customers[].archetype` | string | archetype id | |
| `customers[].potion` | string | potion id with `unlock_day <= day` | |
| `customers[].request` | string | *optional*, request id | Pins the line. Its `potion` and `archetype` must equal the customer's. Absent: random, as above. |

Stock carries over between days. The stock on day N >= 2 is what is left from day N-1 plus what the player bought.

---

## Invariants (`tools/test_content.gd` must check all of these)
- **I1** Every file parses, is a non-empty array of objects, ids are snake_case and unique per file, and no entry has a missing or unknown key.
- **I2** Every field is in its type, range and enum above, every bubble string fits, every length limit holds.
- **I3** Cross-references resolve: `requests.potion/archetype`, `requests.hints[]`, `vocabulary.request_ids[]`,
  `days.customers[].archetype/potion/request`, and the keys of `days.starting_stock` and `days.market`.
- **I4** Hint tagging is exact. The set of vocabulary ids whose `forms` match a request's `text` (rule above) equals its `hints`.
  `vocabulary.request_ids` equals the derived list.
- **I5** Hints are fair. The set of essences of a request's `hints` equals the set of essences where its potion's
  `target > 0`. Every needed essence is hinted, and no essence is hinted that the potion does not need.
- **I6** No request text contains any potion's `name`, or the first word of a name as a whole word (case-insensitive).
- **I7** Every potion has at least one exact (distance 0) brew of 2-3 ingredients with `unlock_day <= potion.unlock_day`.
  Every customer on day N is exactly solvable with ingredients unlocked by day N.
- **I8** Day 1: `starting_stock` alone can brew every day-1 customer Perfect, all on the same day.
  Day N >= 2: the Perfect pay of day N-1's customers alone (`Economy.pay(price, PERFECT)` summed; no tips, no coins or
  stock carried over) buys, at day N's `market` prices, an exact recipe for every day-N customer, all on the same day.
- **I9** For every potion and every 2-3 ingredient brew (all ingredients), distance >= 3 implies some essence overshoots.
  (With the current data, all brews total >= 4 and all targets total <= 5. A brew without an overshoot would be at most 1 away.)
- **I10** Coverage. Every (potion, archetype) pair has >= 3 requests. Every essence has >= 5 misbrews, each with its fixed effect.
  Every archetype has >= 3 lines for every grade. Potions with `unlock_day <= 2` have `steps == ["stir", "pour"]`.

## Current content (days 1-2)
| ingredient | essence | day | | potion | target | day | exact recipe |
|---|---|---|---|---|---|---|---|
| ember_pepper | 2,0,0,0 | 1 | | hearthglow_tonic | 2,0,2,0 | 1 | ember_pepper + sunpetal |
| frost_mint | 0,2,0,0 | 1 | | slumber_syrup | 0,2,0,2 | 1 | frost_mint + nightshade_cap |
| sunpetal | 0,0,2,0 | 1 | | valour_cordial | 2,1,0,2 | 2 | ember_pepper + moonmoss |
| nightshade_cap | 0,0,0,2 | 1 | | moonbloom_draught | 0,1,2,2 | 2 | sunpetal + moonmoss |
| honeycomb | 1,0,2,0 | 2 | | | | | |
| moonmoss | 0,1,0,2 | 2 | | | | | |

The day-1 ingredients each sum to 2, so on day 1 every distance is even: a wrong pick gives Meh or Misbrew,
never Good. The day-2 ingredients sum to 3, so near misses become possible. For example, for Valour Cordial,
ember_pepper + nightshade_cap or ember_pepper + frost_mint + nightshade_cap are Good. For Hearthglow Tonic,
ember_pepper + honeycomb is Good.
