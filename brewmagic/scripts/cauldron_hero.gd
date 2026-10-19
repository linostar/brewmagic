class_name CauldronHero
extends Control
## The big animated cauldron of the splash and the title (scenes/cauldron_hero.tscn,
## art from art_src/title.px): logs and flames flicker under the pot, the liquid bubbles
## and swirls, bubbles and steam rise from it. The liquid, the bubbles and the steam
## cycle through the four essence colours (Shop.ESSENCE_COLORS: ember, frost, bloom,
## gloom), TINT_TIME seconds from one to the next. The pot canvas is SIZE; the flames
## hang below it. Nothing here takes input.

const SIZE := Vector2(112, 86)
## Seconds the tint takes from one essence colour to the next.
const TINT_TIME := 1.4
const FIRE_FRAME_TIME := 0.12
const LIQUID_FRAME_TIME := 0.28
const FIRE_FRAMES := 3
const LIQUID_FRAMES := 3
## The liquid surface's centre on the pot canvas (where bubbles and steam start).
const SURFACE := Vector2(56, 15)

## Seconds of animation so far (the tint and the frames follow it).
var elapsed := 0.0

@onready var _fire: TextureRect = $Fire
@onready var _liquid: TextureRect = $Liquid
@onready var _bubbles: CPUParticles2D = $Bubbles
@onready var _big_bubbles: CPUParticles2D = $BigBubbles
@onready var _steam: CPUParticles2D = $Steam


func _ready() -> void:
	($Pot as TextureRect).texture = Art.texture("title", "title_cauldron")
	_bubbles.texture = Art.texture("title", "bubble_small")
	_big_bubbles.texture = Art.texture("title", "bubble_big")
	_steam.texture = Art.texture("title", "steam_puff")
	_show(0.0)


func _process(delta: float) -> void:
	elapsed += delta
	_show(elapsed)


## The essence colour mix shown at `time` seconds: each colour of Shop.ESSENCE_COLORS in
## turn, blended smoothly into the next.
static func tint_at(time: float) -> Color:
	var colors := Shop.ESSENCE_COLORS
	var step := time / TINT_TIME
	var index := floori(step) % colors.size()
	var blend := smoothstep(0.0, 1.0, step - floorf(step))
	return colors[index].lerp(colors[(index + 1) % colors.size()], blend)


## The tint now (the liquid's colour; the steam and bubbles are lighter shades of it).
func tint() -> Color:
	return tint_at(elapsed)


## A puff of bubbles out of the pot (the splash's logo rising).
func burst() -> void:
	Juice.burst(self, SURFACE, tint().lightened(0.4), 18, Vector2(0, 60))


func _show(time: float) -> void:
	var color := tint_at(time)
	_liquid.modulate = color
	_bubbles.color = color.lightened(0.45)
	_big_bubbles.color = color.lightened(0.3)
	_steam.color = color.lightened(0.6)
	_fire.texture = Art.texture("title", "title_fire_%d" % (floori(time / FIRE_FRAME_TIME) % FIRE_FRAMES))
	_liquid.texture = Art.texture("title", "title_liquid_%d" % (floori(time / LIQUID_FRAME_TIME) % LIQUID_FRAMES))
