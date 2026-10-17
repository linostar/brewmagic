class_name Market
extends Control
## Evening market (flow MARKET), held the evening before story day Game.day: buy
## ingredient stock at that day's market prices (Economy.market_price) and the
## next level of station upgrades (Economy.upgrade_cost) on sale by that day, then
## "Next day" goes to its morning. Every buy is saved at once (Game.buy_stock,
## Game.buy_upgrade); a maxed upgrade is disabled; anything the coins do not cover
## is faded (UNAFFORDABLE_TINT) and a tap on it shakes it and says why.
##
## Layout: the reading zone shows the coins and an info card about the last
## focused or bought item (its name, essences or effect, price); the thumb zone
## (Shop panel, bottom of the column) holds the Stock / Upgrades tabs, the cards
## of the open tab and Next day. A card is a Button: tap, click or Enter buys one.

const CARD_SIZE := Vector2(48, 64)
const UPGRADE_SIZE := Vector2(258, 44)
const GOLD := Color("#ffc95c")
const RED := Color("#c43c2c")
## A card the coins do not cover: faded as a whole (lighter, not a different hue);
## it stays tappable, and a tap shakes it and says why in the info panel.
const UNAFFORDABLE_TINT := Color(1, 1, 1, 0.45)

var spec: DaySpec

var _game: GameState
## Ingredient id -> its card.
var _stock_cards: Dictionary[String, Button] = {}
## Upgrade id -> its card.
var _upgrade_cards: Dictionary[String, Button] = {}

@onready var _column: Control = $Column
@onready var _coins_label: Label = $Column/Coins/Amount
@onready var _coin_icon: TextureRect = $Column/Coins/Icon
@onready var _info: Label = $Column/Info/Text
@onready var _stock_tab: Button = $Column/Shop/Tabs/StockTab
@onready var _upgrades_tab: Button = $Column/Shop/Tabs/UpgradesTab
@onready var _stock_grid: GridContainer = $Column/Shop/StockGrid
@onready var _upgrade_list: VBoxContainer = $Column/Shop/UpgradeList
@onready var _next_button: Button = $Column/Shop/NextDayButton


func _ready() -> void:
	_game = get_node(GameState.AUTOLOAD_PATH) as GameState
	_game.screen_fit_changed.connect(_fit_column)
	_fit_column()
	_coin_icon.texture = Art.texture("ui", "coin_0")
	spec = Content.day(_game.day)
	if spec == null:
		_next_button.disabled = true
		_game.abort_to(GameState.Flow.TITLE, "Day %d is missing from data/days.json; the market cannot open." % _game.day)
		return
	($Column/Heading as Label).text = "Stocking up for day %d" % spec.day
	_stock_tab.toggled.connect(_on_tab_toggled)
	_next_button.pressed.connect(_on_next_pressed)
	for item in Content.ingredients_unlocked_by(spec.day):
		var card := _stock_card(item)
		_stock_grid.add_child(card)
		_stock_cards[item.id] = card
	for upgrade in Content.upgrades():
		if upgrade.unlock_day <= spec.day:
			var card := _upgrade_card(upgrade)
			_upgrade_list.add_child(card)
			_upgrade_cards[upgrade.id] = card
	_upgrades_tab.disabled = _upgrade_cards.is_empty()
	_refresh()
	_show_tab(true)
	_info.text = "Tap an item to buy one. Faded items cost more coins than you have. Stock carries over to tomorrow."
	print("[Market] Before day %d: %d coins, stock %s, upgrades %s, %d ingredients and %d upgrades on sale" % [
		spec.day, _game.coins, _game.stock, _game.upgrades, _stock_cards.size(), _upgrade_cards.size()])


## The card of ingredient `id` (tests press it).
func stock_card(id: String) -> Button:
	return _stock_cards.get(id)


## The card of upgrade `id` (tests press it).
func upgrade_card(id: String) -> Button:
	return _upgrade_cards.get(id)


## Shows the Stock tab (`stock`) or the Upgrades tab and focuses its first card.
func _show_tab(stock: bool) -> void:
	_stock_tab.set_pressed_no_signal(stock)
	_upgrades_tab.set_pressed_no_signal(not stock)
	_stock_grid.visible = stock
	_upgrade_list.visible = not stock
	var cards: Array = (_stock_cards if stock else _upgrade_cards).values()
	for card: Button in cards:
		if not card.disabled:
			card.grab_focus(true)
			return
	_next_button.grab_focus(true)


func _on_tab_toggled(stock_on: bool) -> void:
	_show_tab(stock_on)


func _stock_card(item: Ingredient) -> Button:
	var card := _card(CARD_SIZE)
	var icon := _icon(Art.texture("ingredients", item.id))
	icon.position = Vector2((CARD_SIZE.x - 24.0) / 2.0, 3.0)
	card.add_child(icon)
	var owned := _label("", HORIZONTAL_ALIGNMENT_RIGHT)
	owned.name = "Owned"
	owned.position = Vector2(2, 0)
	owned.size = Vector2(CARD_SIZE.x - 5.0, 14.0)
	card.add_child(owned)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override(&"separation", 0)
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.position = Vector2(0, 29)
	pips.size = Vector2(CARD_SIZE.x, 9)
	for k in Content.ESSENCES.size():
		for i in item.essence[k]:
			pips.add_child(_icon(Art.texture("ui", Shop.ESSENCE_ICONS[k])))
	card.add_child(pips)
	var price := _price_row(Economy.market_price(spec, item))
	price.position = Vector2(0, 44)
	price.size = Vector2(CARD_SIZE.x, 16)
	card.add_child(price)
	card.pressed.connect(_on_stock_pressed.bind(item))
	card.focus_entered.connect(_describe_stock.bind(item))
	return card


func _upgrade_card(upgrade: Upgrade) -> Button:
	var card := _card(UPGRADE_SIZE)
	var text := _label("", HORIZONTAL_ALIGNMENT_LEFT)
	text.name = "Text"
	text.position = Vector2(8, 4)
	text.size = Vector2(UPGRADE_SIZE.x - 70.0, UPGRADE_SIZE.y - 8.0)
	card.add_child(text)
	var price := _price_row(0)
	price.name = "Price"
	price.position = Vector2(UPGRADE_SIZE.x - 62.0, 14)
	price.size = Vector2(54, 16)
	price.alignment = BoxContainer.ALIGNMENT_END
	card.add_child(price)
	card.pressed.connect(_on_upgrade_pressed.bind(upgrade))
	card.focus_entered.connect(_describe_upgrade.bind(upgrade))
	return card


func _card(card_size: Vector2) -> Button:
	var card := Button.new()
	card.custom_minimum_size = card_size
	card.size = card_size
	card.focus_mode = Control.FOCUS_ALL
	return card


func _icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _label(text: String, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A coin icon and an amount, centred.
func _price_row(amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := _icon(Art.texture("ui", "coin_0"))
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	var label := _label(str(amount), HORIZONTAL_ALIGNMENT_LEFT)
	label.name = "Amount"
	row.add_child(label)
	return row


## Updates the coins, every card's owned count or level, and which cards the coins cover.
func _refresh() -> void:
	_coins_label.text = str(_game.coins)
	for item in Content.ingredients_unlocked_by(spec.day):
		var card := _stock_cards[item.id]
		var price := Economy.market_price(spec, item)
		var owned: int = _game.stock.get(item.id, 0)
		(card.get_node("Owned") as Label).text = "x%d" % owned
		var short := price > _game.coins
		card.modulate = UNAFFORDABLE_TINT if short else Color.WHITE
		card.accessibility_name = "Buy one %s for %d coins, %d in stock%s" % [item.name, price, owned, " (not enough coins)" if short else ""]
	for upgrade in Content.upgrades():
		if not _upgrade_cards.has(upgrade.id):
			continue
		var card := _upgrade_cards[upgrade.id]
		var level: int = _game.upgrades.get(upgrade.station, 0)
		var cost := Economy.upgrade_cost(upgrade, level)
		var maxed := cost == Economy.MAXED
		var text := card.get_node("Text") as Label
		var price := card.get_node("Price") as HBoxContainer
		price.visible = not maxed
		(price.get_node("Amount") as Label).text = str(cost)
		# Name, then what owning the next level (or the top one) does: "Stir +25% easier".
		var easier := roundi((Economy.upgrade_tolerance(upgrade, level if maxed else level + 1) - 1.0) * 100.0)
		text.text = "%s\n%s +%d%% easier%s" % [upgrade.name, upgrade.station.capitalize(), easier, " (max)" if maxed else ""]
		var short := not maxed and cost > _game.coins
		card.disabled = maxed
		card.modulate = UNAFFORDABLE_TINT if short else Color.WHITE
		card.accessibility_name = ("%s is at its max level" % upgrade.name) if maxed else "Buy %s level %d for %d coins%s" % [upgrade.name, level + 1, cost, " (not enough coins)" if short else ""]


func _on_stock_pressed(item: Ingredient) -> void:
	var card := _stock_cards[item.id]
	var price := Economy.market_price(spec, item)
	if not _game.buy_stock(item, price):
		_refuse(card, item.name, price)
		return
	_bought(card, price)
	_describe_stock(item)


func _on_upgrade_pressed(upgrade: Upgrade) -> void:
	var card := _upgrade_cards[upgrade.id]
	var cost := Economy.upgrade_cost(upgrade, _game.upgrades.get(upgrade.station, 0))
	if not _game.buy_upgrade(upgrade):
		_refuse(card, upgrade.name, cost)
		return
	_bought(card, cost)
	_describe_upgrade(upgrade)


## Feedback for a tap on `card` the coins do not cover: a shake and the reason.
func _refuse(card: Button, what: String, price: int) -> void:
	Juice.shake(card, 2.0, 0.2)
	_info.text = "Not enough coins: %s costs %d, you have %d." % [what, price, _game.coins]


## Feedback for a purchase of `price` from `card`: squash, "-price" popping off the
## coins, every card refreshed (focus moves on when this upgrade reached its max level).
func _bought(card: Button, price: int) -> void:
	Juice.squash(card, 0.25)
	Juice.squash(_coin_icon, 0.3, 0.16)
	Juice.pop_text(self, _coins_label.get_global_rect().get_center() + Vector2(0, 14), "-%d" % price, RED)
	_refresh()
	if card.disabled:
		_show_tab(_stock_grid.visible)


func _describe_stock(item: Ingredient) -> void:
	var essences := PackedStringArray()
	for k in Content.ESSENCES.size():
		if item.essence[k] > 0:
			essences.append("%s %d" % [Content.ESSENCES[k], item.essence[k]])
	_info.text = "%s (%s)\n%d coins each, %d in stock" % [item.name, ", ".join(essences), Economy.market_price(spec, item), _game.stock.get(item.id, 0)]


func _describe_upgrade(upgrade: Upgrade) -> void:
	_info.text = "%s\n%s" % [upgrade.name, upgrade.description]


func _fit_column() -> void:
	var column := _game.column_rect()
	_column.position = column.position
	_column.size = column.size


func _on_next_pressed() -> void:
	Juice.squash(_next_button, 0.2)
	print("[Market] Done: %d coins, stock %s, upgrades %s" % [_game.coins, _game.stock, _game.upgrades])
	_game.leave_market()
