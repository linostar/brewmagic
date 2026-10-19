class_name Tally
extends RefCounted
## The results screens' reveal (Summary, Results): after START_DELAY (the scene's
## fade-in) the stat tiles pop in one after another, TILE_GAP apart, each counting its
## number up (StatTile.pop), then the rows under them fade in. duration() is at most
## MAX_TIME. complete() jumps to the end at once (a tap or Enter on the screen); the
## final numbers are the same either way.

signal finished

const START_DELAY := 0.2
const TILE_GAP := 0.25
const ROWS_FADE := 0.3
## The reveal never takes longer than this.
const MAX_TIME := 2.0

var _tiles: Array[StatTile] = []
var _rows: Array[CanvasItem] = []
var _tween: Tween
var _running := false


func _init(tiles: Array[StatTile], rows: Array[CanvasItem]) -> void:
	_tiles = tiles
	_rows = rows


## How long the whole reveal takes, in seconds.
func duration() -> float:
	return START_DELAY + (_tiles.size() - 1) * TILE_GAP + StatTile.COUNT_TIME + ROWS_FADE


## Hides the tiles and rows and starts the reveal on `host`'s tween.
func start(host: Node) -> void:
	assert(duration() <= MAX_TIME)
	for tile in _tiles:
		tile.modulate.a = 0.0
	for row in _rows:
		row.modulate.a = 0.0
	_running = true
	_tween = host.create_tween()
	_tween.tween_interval(START_DELAY)
	for i in _tiles.size():
		if i > 0:
			_tween.tween_interval(TILE_GAP)
		_tween.tween_callback(_tiles[i].pop)
	_tween.tween_interval(StatTile.COUNT_TIME)
	for i in _rows.size():
		if i > 0:
			_tween.parallel()
		_tween.tween_property(_rows[i], "modulate:a", 1.0, ROWS_FADE)
	_tween.tween_callback(_done)


## True from start() until the reveal ends or is completed.
func is_running() -> bool:
	return _running


## Ends the reveal at once: every tile shows its final number, every row is shown.
func complete() -> void:
	if not _running:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for tile in _tiles:
		tile.finish()
	for row in _rows:
		row.modulate.a = 1.0
	_done()


func _done() -> void:
	if not _running:
		return
	_running = false
	print("[Tally] Reveal done")
	finished.emit()
