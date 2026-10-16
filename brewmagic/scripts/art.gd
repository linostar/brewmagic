class_name Art
## Sprites from the compiled atlases in res://art/ (tools/pixelart.py writes
## <atlas>.png plus its <atlas>.json sidecar with every sprite's rect).
## texture() returns a shared, cached AtlasTexture: duplicate it before changing
## its region. Unknown atlases or sprites are reported with push_error and give null.

const ART_DIR := "res://art/"

## atlas name -> {"texture": Texture2D, "sprites": Dictionary of name -> Rect2}
static var _atlases: Dictionary[String, Dictionary] = {}
static var _textures: Dictionary[String, AtlasTexture] = {}


## The sprite `sprite` of atlas `atlas` ("brewing", "ui", ...).
static func texture(atlas: String, sprite: String) -> AtlasTexture:
	var key := atlas + "/" + sprite
	if _textures.has(key):
		return _textures[key]
	var sheet := _atlas(atlas)
	if sheet.is_empty():
		return null
	var sprites: Dictionary = sheet["sprites"]
	if not sprites.has(sprite):
		push_error("[Art] Unknown sprite '%s' in atlas '%s'" % [sprite, atlas])
		return null
	var result := AtlasTexture.new()
	result.atlas = sheet["texture"]
	result.region = sprites[sprite]
	_textures[key] = result
	return result


static func _atlas(atlas: String) -> Dictionary:
	if _atlases.has(atlas):
		return _atlases[atlas]
	var json_path := ART_DIR + atlas + ".json"
	var text := FileAccess.get_file_as_string(json_path)
	if text.is_empty():
		push_error("[Art] Cannot read atlas '%s' (%s): %s" % [atlas, json_path, error_string(FileAccess.get_open_error())])
		return {}
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary and data.get("texture") is String and data.get("sprites") is Dictionary):
		push_error("[Art] Atlas sidecar %s is not {texture, sprites}" % json_path)
		return {}
	var texture_path: String = ART_DIR + str(data["texture"])
	var atlas_texture := load(texture_path) as Texture2D
	if atlas_texture == null:
		push_error("[Art] Cannot load atlas texture %s" % texture_path)
		return {}
	var rects := {}
	for sprite_name: String in data["sprites"]:
		var rect: Dictionary = data["sprites"][sprite_name]
		rects[sprite_name] = Rect2(rect["x"], rect["y"], rect["w"], rect["h"])
	var sheet := {"texture": atlas_texture, "sprites": rects}
	_atlases[atlas] = sheet
	return sheet
