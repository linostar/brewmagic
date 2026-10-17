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

A string marked **page** (ending pages) follows the same rules with up to **6** wrapped lines (156 characters):
`Content.page_problem()`.

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
| `grind` | bool | | `true` means the ingredient is ground in the Mortar: potions whose recipes need it list `"mortar"` (I11), and the Mortar shows the brew's `grind` ingredients in its bowl. All day-1 ingredients are `false` (I10). |
| `heat` | bool | | `true` means the ingredient only gives up its essence over a roaring fire: potions whose recipes need it list `"bellows"` (I12). All ingredients unlocked before day 4 are `false` (I10). |
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
| `steps` | array of string | non-empty, unique, each `"stir" \| "pour" \| "mortar" \| "bellows"` | Station order for brewing; the shop runs them in this order (mortar, bellows, stir, pour). Potions with `unlock_day == 1` use exactly `["stir", "pour"]` (I10); `"mortar"` follows I11, `"bellows"` follows I12. |
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
| `voice` | object | keys exactly `pitch`, `timbre` | `tools/sfx.py` synthesises `audio/sfx/voice_<id>.wav` from it (rerun it after adding or changing an archetype; `sfx.py --check` in `validate.sh` fails on a stale or missing file). |
| `voice.pitch` | float | 0.5..2.0 | Voice-blip pitch multiplier (1.0 = 240 Hz). |
| `voice.timbre` | string | `"reed" \| "bell" \| "growl" \| "chirp"` | Voice-blip synth: nasal pulse, bell with an inharmonic partial, buzzy saw, upward sine sweep. |
| `speech_style` | string | 1..200 chars | Writer's note, not shown in game. |
| `parts` | object | keys exactly `body`, `head`, `hair`, `accessory` | A part value `<v>` is drawn from the customer atlas (`art/customer.json`) frames `<prefix>_<v>_0` and `<prefix>_<v>_1` (idle bob), with prefix `body`, `head`, `hair`, `acc` for `body`, `head`, `hair`, `accessory`. Accessory `"none"` draws nothing. Both frames must exist (checked by `tools/test_content.gd`). The parts are the archetype's silhouette; each visitor's colours come from a palette swap (`Look`, CLAUDE.md "Customers"). |
| `parts.body` | string | `"robe" \| "apron" \| "armour" \| "cloak"` | |
| `parts.head` | string | `"round" \| "long" \| "square" \| "snout"` | |
| `parts.hair` | string | `"witch_hat" \| "straw_hat" \| "curly" \| "bald_beard" \| "beehive" \| "top_hat" \| "hood"` | |
| `parts.accessory` | string | `"none" \| "goat" \| "lantern" \| "flask" \| "scroll" \| "smoke"` | |
| `look` | object | *optional*, keys exactly `cloth_a`, `cloth_b`, `hair`, `skin` | Present only on a **story character**: its one fixed look (no palette shuffle, the same on every visit). Each value names a ramp of `scripts/logic/look.gd` (`Look.CLOTHS` for both cloths, which must differ, `Look.HAIRS`, `Look.SKINS`). A story character visits only as a story beat (`days.customers[].beat`, I13), never as a random visitor. |
| `reactions` | object | keys exactly `perfect`, `good`, `meh`, `misbrew`, `stormed_off`, `refused` | |
| `reactions.<grade>` | array of string | >= 3 entries, each **bubble** | One line is picked at random, avoiding the one used last for that archetype and grade. `misbrew` is the customer's own reaction; the absurd effect line comes from `misbrews.json`. `stormed_off` is said when patience runs out; `refused` when the shop refuses the customer (the Refuse button). |

## requests.json
| field | type | range / enum | notes |
|---|---|---|---|
| `id` | string | `<potion short>_<archetype>_<n>` | |
| `potion` | string | potion id | The potion this hint asks for. |
| `archetype` | string | archetype id | The voice it is written in. Only this archetype says it. |
| `hints` | array of string | non-empty, unique, vocabulary ids | Every hint word in `text` (see I4). |
| `text` | string | **bubble** | Never names a potion (I6). |

Selection: a random customer with archetype A who wants potion P says a random request with
`(potion, archetype) == (P, A)`, avoiding recent repeats. A day can pin one with `customers[].request`;
a story beat always pins its request (I13), so a story character's requests need not come in threes.

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
| `customers[].request` | string | *optional*, request id | Pins the line. Its `potion` and `archetype` must equal the customer's. Absent: random, as above. Required on a story beat. |
| `customers[].beat` | string | *optional*, snake_case | Makes this visit a **story beat** of its archetype, which must be a story character (one with a `look`); a story character's visits must all have one. The beat's flag is `<archetype id>.<beat>` (I13). |
| `customers[].lines` | object | keys exactly `great`, `poor`, `refused`, `stormed_off`, each **bubble** | Required on a story beat, an error elsewhere. The beat's own reaction: `great` (served Perfect or Good), `poor` (Meh or Misbrew; a Misbrew still shows its misbrew narration first), `refused` (the Refuse button), `stormed_off` (patience ran out). It replaces the archetype's reaction line for that visit. |
| `customers[].when` | object `{flag: array of outcome}` | *optional* | The customer only comes when every listed flag's recorded outcome is one of its listed outcomes (outcomes: `great`, `poor`, `refused`, `stormed_off`; each list non-empty and without repeats). A flag is `<story character>.<beat>` of a beat on an earlier day. Absent: always comes. |
| `morning_notes` | array of object | *optional*, each keys exactly `when`, `text` | Conditioned morning cards, tried in order: the first whose `when` (as for customers, non-empty) matches replaces `morning_note`. `text` is **bubble**. |

Stock carries over between days. The stock on day N >= 2 is what is left from day N-1 plus what the player bought.

**Flag paths.** A *flag path* is one recorded outcome for every beat. The customers of day N on a path are the
customers whose `when` matches it; the shop runs exactly that list (`Shift.story(n, flags)`). Only the beats some
`when` names, and only whether each outcome is in the named lists, can change a day, so the tests enumerate one path
per combination of those outcome classes.

## endings.json
The three endings of the story, chosen by `Story.ending(flags, reputation)` (rule under "Story" below). Exactly the
ids `guild_master`, `cosy_corner` and `charming_chaos`, once each.
| field | type | range / enum | notes |
|---|---|---|---|
| `id` | string | `guild_master \| cosy_corner \| charming_chaos` | |
| `title` | string | 1..26 chars | Heading of every page. |
| `pages` | array of object | 2..5 entries, each keys exactly `text`, `cast` | Shown in order; tap or Enter turns the page. |
| `pages[].text` | string | **page** | The page's text: like a bubble, but up to 6 wrapped lines (156 characters). |
| `pages[].cast` | array of string | 0..3 archetype ids, unique | Who stands in the page's picture, left to right (their fixed look for story characters). |

## upgrades.json
One upgrade per station: exactly one entry for each of `"stir"`, `"pour"`, `"mortar"`, `"bellows"`.
| field | type | range / enum | notes |
|---|---|---|---|
| `id` | string | snake_case | |
| `station` | string | `"stir" \| "pour" \| "mortar" \| "bellows"` | The station step it improves; unique across the file. |
| `name` | string | 1..26 chars | Market card title. |
| `description` | string | 1..120 chars | Market info line. |
| `unlock_day` | int | 1..7 | On sale in every market held the evening before a day `>= unlock_day`. |
| `levels` | array of object | non-empty | Level 1, 2, ... in order. Owning none is level 0 (tolerance x1). |
| `levels[].tolerance` | float | (1.0, 3.0], strictly increasing | The station's tolerance multiplier at this level (`Station.tolerance_scale`, times 1.5 in Gentle mode). |
| `levels[].cost` | int | 1..9999 | Coins for this level, bought after the level before it. |

---

## Invariants (`tools/test_content.gd` must check all of these)
- **I1** Every file parses, is a non-empty array of objects, ids are snake_case and unique per file, and no entry has a missing or unknown key.
- **I2** Every field is in its type, range and enum above, every bubble string fits, every length limit holds.
- **I3** Cross-references resolve: `requests.potion/archetype`, `requests.hints[]`, `vocabulary.request_ids[]`,
  `days.customers[].archetype/potion/request/when`, `days.morning_notes[].when`, the keys of `days.starting_stock` and
  `days.market`, and `endings.pages[].cast`.
- **I4** Hint tagging is exact. The set of vocabulary ids whose `forms` match a request's `text` (rule above) equals its `hints`.
  `vocabulary.request_ids` equals the derived list.
- **I5** Hints are fair. The set of essences of a request's `hints` equals the set of essences where its potion's
  `target > 0`. Every needed essence is hinted, and no essence is hinted that the potion does not need.
- **I6** No request text contains any potion's `name`, or the first word of a name as a whole word (case-insensitive).
- **I7** Every potion has at least one exact (distance 0) brew of 2-3 ingredients with `unlock_day <= potion.unlock_day`.
  Every customer on day N is exactly solvable with ingredients unlocked by day N (on every flag path, I13).
- **I8** Day 1: `starting_stock` alone can brew every day-1 customer Perfect, all on the same day.
  Day N >= 2 (economy-aware, simulated from day 1's `starting_stock`): a day starts with the stock that any Perfect
  run of the day before can leave (every exact recipe per customer is a possible run; the worst leftover counts), and
  the Perfect pay of day N-1's customers alone (`Economy.pay(price, PERFECT)` summed; no tips, no other coins, since
  the player may spend those on upgrades) buys, at day N's market prices (`Economy.market_price`), whatever that
  stock lacks for an exact recipe for every day-N customer, all on the same day.
- **I9** For every potion and every 2-3 ingredient brew (all ingredients), distance >= 3 implies some essence overshoots.
  (With the current data, all brews total >= 4 and all targets total <= 6. A brew without an overshoot would be at most 2 away.)
- **I10** Coverage. Every (potion, archetype) pair that a day customer without a pinned `request` can ask for has
  >= 3 requests, and every potion has requests in >= 2 voices. Every essence has >= 5 misbrews, each with its fixed effect.
  Every archetype has >= 3 lines for every grade. Potions with `unlock_day == 1` have `steps == ["stir", "pour"]`
  and day-1 ingredients have `grind == false` (day 1 teaches only Stir and Pour). At least one potion with
  `unlock_day == 2` lists `"mortar"` (the Mortar is introduced on day 2). The Bellows first appears on day 4: at least
  one potion with `unlock_day == 4` lists `"bellows"`, none unlocked earlier does, and no ingredient unlocked before
  day 4 has `heat == true`.
- **I11** Mortar consistency. A potion lists `"mortar"` in `steps` exactly when every exact recipe of it (2-3
  ingredients with `unlock_day <= potion.unlock_day`, as in I7) contains an ingredient with `grind == true`. So a
  potion that needs a hard ingredient always grinds it, and no potion asks for the Mortar when there is nothing to grind.
- **I12** Bellows consistency, as I11 with `heat`: a potion lists `"bellows"` in `steps` exactly when every exact recipe of it
  contains an ingredient with `heat == true`.
- **I13** Story. Every story character (an archetype with a `look`) has >= 3 beats, its last one on day 7, and no
  potions-and-archetype pair rule (I10) applies to it. Every beat's visits (variants) are on one day; every `when` names only
  beats of earlier days; on every flag path every beat comes exactly once on its day, every day has at least one
  customer, and I7 and I8 hold for that path's customers (in I8, story beats count with no pay, since they can be
  refused, but their ingredients are used). Every beat has its `lines`, every beat visit pins a `request`, and no two
  potions share a `target`.
- **I14** Endings: exactly the three ids above, every page fits, every `cast` id is a known archetype.

## Current content (days 1-7)
| ingredient | essence | day | flags | price |
|---|---|---|---|---|
| ember_pepper | 2,0,0,0 | 1 | | 2 |
| frost_mint | 0,2,0,0 | 1 | | 2 |
| sunpetal | 0,0,2,0 | 1 | | 2 |
| nightshade_cap | 0,0,0,2 | 1 | | 3 |
| honeycomb | 1,0,2,0 | 2 | | 4 |
| moonmoss | 0,1,0,2 | 2 | grind | 4 |
| cinderroot | 3,0,0,0 | 4 | heat | 5 |
| snowfire_pearl | 1,1,0,0 | 6 | | 5 |
| twilight_bloom | 0,0,1,1 | 6 | | 5 |
| starlight_dew | 0,1,1,1 | 6 | grind | 6 |

| potion | target | day | steps | exact recipe (its only one) |
|---|---|---|---|---|
| hearthglow_tonic | 2,0,2,0 | 1 | stir, pour | ember_pepper + sunpetal |
| slumber_syrup | 0,2,0,2 | 1 | stir, pour | frost_mint + nightshade_cap |
| valour_cordial | 2,1,0,2 | 2 | mortar, stir, pour | ember_pepper + moonmoss |
| moonbloom_draught | 0,1,2,2 | 2 | mortar, stir, pour | sunpetal + moonmoss |
| stillwater_draught | 0,4,0,0 | 3 | stir, pour | frost_mint + frost_mint |
| dewdrop_balm | 0,2,2,0 | 3 | stir, pour | frost_mint + sunpetal |
| nightfire_punch | 2,0,0,2 | 3 | stir, pour | ember_pepper + nightshade_cap |
| greenthumb_syrup | 0,0,4,0 | 3 | stir, pour | sunpetal + sunpetal |
| nocturne_syrup | 0,0,0,4 | 3 | stir, pour | nightshade_cap + nightshade_cap |
| steamwhistle_tonic | 3,2,0,0 | 4 | bellows, stir, pour | cinderroot + frost_mint |
| bonfire_tonic | 5,0,0,0 | 4 | bellows, stir, pour | cinderroot + ember_pepper |
| smoulder_syrup | 3,0,0,2 | 4 | bellows, stir, pour | cinderroot + nightshade_cap |
| embermoss_elixir | 3,1,0,2 | 4 | mortar, bellows, stir, pour | cinderroot + moonmoss |
| panacea | 1,1,1,1 | 6 | stir, pour | snowfire_pearl + twilight_bloom |
| hushfire_tonic | 1,3,0,0 | 6 | stir, pour | snowfire_pearl + frost_mint |
| duskbloom_syrup | 0,0,1,3 | 6 | stir, pour | twilight_bloom + nightshade_cap |
| starfire_elixir | 2,1,1,1 | 6 | mortar, stir, pour | starlight_dew + ember_pepper |

Every potion has exactly one exact recipe from the ingredients of its unlock day, so its `steps` follow from that
recipe: moonmoss and starlight dew are the `grind` ingredients (I11), cinderroot the only `heat` one (I12). Day-6
ingredients can make further exact brews of older potions on later days (moonbloom: twilight bloom + starlight dew);
the steps stay those of the potion. The day-1 ingredients each sum to 2, so on day 1 every distance is even: a wrong
pick gives Meh or Misbrew, never Good. Later ingredients sum to 2 or 3, so near misses become possible (for Valour
Cordial, ember_pepper + nightshade_cap is Good).

## Story: the Guild Fair
The shop has one week before the Alchemists' Guild Fair, where the Guild decides whether it gets a licence. Days
3-7 each add one element: day 3 the Guild (Inspector Quill's first visit and five new potions), day 4 the Bellows,
cinderroot and Madame Vexley's rival shop across the street, day 5 a rush (more customers, `patience_scale` 0.75),
day 6 three rare ingredients and four rare potions, day 7 the Guild Fair finale.

Three story characters (archetypes with a fixed `look`), each with 3 beats. A beat's outcome is stored as the flag
`<character>.<beat>` = `great` (Perfect or Good), `poor` (Meh or Misbrew), `refused` or `stormed_off`
(`Game.flags`, saved). Below, "great" and "not great" are the two outcome classes the `when` conditions use.

| character | day 3 | day 4 | day 5 | day 6 | day 7 (Guild Fair) |
|---|---|---|---|---|---|
| `quill` Inspector Quill, the Guild's inspector | `inspection`: stillwater draught | | `audit`: great inspection -> steamwhistle tonic (a harder test); else stillwater draught again (a retest) | | `fair`: great audit -> panacea (the grand test); else starfire elixir. Great here grants the licence |
| `vexley` Madame Vexley, the rival alchemist | | `opening`: steamwhistle tonic, testing the new shop on her opening day | | `truce`: great opening -> panacea (her cauldron exploded; she asks for help); else embermoss elixir (a gloating challenge) | `fair`: great truce -> starfire elixir for the stall you share; else duskbloom syrup for her rival stall |
| `stranger` the Hooded Stranger, a shy dragon who sneezes fire | `first_sneeze`: dewdrop balm for a sore throat | | | `confession`: great first sneeze -> hushfire tonic (it trusts the shop and owns up to being a dragon); else dewdrop balm again (still hiding) | `fair`: great confession -> panacea, to light the Fair lanterns without burning the tent; else hushfire tonic, in a panic |

Flag effects beyond lines: a great `stranger.first_sneeze` sends an extra customer on day 4 (the stranger told the
goat farmer about the shop); a great `vexley.opening` sends
Vexley's overflow customer on day 5. Morning notes change with the flags on days 4-7.

**Endings** (`Story.ending(flags, reputation)`, `scripts/logic/story.gd`): the licence is granted when `quill.fair` is
`great`; an arc is resolved when the character's day-7 beat is `great` (so Quill's counts with the licence).
- `guild_master`: licence, all three arcs resolved and reputation >= `Story.GUILD_MASTER_REPUTATION` (30).
- `cosy_corner`: licence and at least two arcs resolved (otherwise).
- `charming_chaos`: everything else (no licence, or only Quill's arc resolved): the village loves the shop anyway.

The ending scene records the ending as `flags.ending` and sets `flags.rush_hour_unlocked` (both saved).
