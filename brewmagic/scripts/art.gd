class_name Art
## Sprites from the compiled atlases in res://art/ (tools/pixelart.py writes
## <atlas>.png plus its <atlas>.json sidecar with every sprite's rect, the palette
## colours it uses and its .px source rows, and the palette in index order).
## texture() returns a shared, cached AtlasTexture: duplicate it before changing
## its region. Unknown atlases or sprites are reported with push_error and give null.

const ART_DIR := "res://art/"

## atlas name -> {"texture": Texture2D, "sprites": Dictionary of name -> Rect2,
## "colors": Dictionary of name -> PackedStringArray of "#rrggbb", "rows": Dictionary of
## name -> PackedStringArray (the .px source rows), "palette": PackedStringArray of "#rrggbb"}
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


## The palette colours ("#rrggbb", sorted) sprite `sprite` of atlas `atlas` uses;
## empty (and reported) for an unknown atlas or sprite.
static func colors(atlas: String, sprite: String) -> PackedStringArray:
	var sheet := _atlas(atlas)
	if sheet.is_empty():
		return PackedStringArray()
	var by_sprite: Dictionary = sheet["colors"]
	if not by_sprite.has(sprite):
		push_error("[Art] Unknown sprite '%s' in atlas '%s'" % [sprite, atlas])
		return PackedStringArray()
	return by_sprite[sprite]


## The .px source rows of sprite `sprite` of atlas `atlas`: one character per pixel,
## "." transparent, else the palette index as one of 0-9 a-v (tools/pixelart.py CHARS);
## empty (and reported) for an unknown atlas or sprite.
static func rows(atlas: String, sprite: String) -> PackedStringArray:
	var sheet := _atlas(atlas)
	if sheet.is_empty():
		return PackedStringArray()
	var by_sprite: Dictionary = sheet["rows"]
	if not by_sprite.has(sprite):
		push_error("[Art] Unknown sprite '%s' in atlas '%s'" % [sprite, atlas])
		return PackedStringArray()
	return by_sprite[sprite]


## The locked palette ("#rrggbb" in index order) atlas `atlas` was compiled with;
## empty (and reported) for an unknown atlas.
static func palette(atlas: String) -> PackedStringArray:
	var sheet := _atlas(atlas)
	return PackedStringArray() if sheet.is_empty() else sheet["palette"]


## The sprite names of atlas `atlas`, in source order; empty (and reported) for an unknown atlas.
static func sprite_names(atlas: String) -> PackedStringArray:
	var sheet := _atlas(atlas)
	return PackedStringArray() if sheet.is_empty() else PackedStringArray((sheet["rows"] as Dictionary).keys())


## The atlases shipped in res://art/ (one per <atlas>.json sidecar), sorted; none is reported.
static func atlases() -> PackedStringArray:
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(ART_DIR):
		if file.get_extension() == "json":
			names.append(file.get_basename())
	names.sort()
	if names.is_empty():
		push_error("[Art] No atlas sidecars in %s: %s" % [ART_DIR, error_string(DirAccess.get_open_error())])
	return names


static func _atlas(atlas: String) -> Dictionary:
	if _atlases.has(atlas):
		return _atlases[atlas]
	var json_path := ART_DIR + atlas + ".json"
	var text := FileAccess.get_file_as_string(json_path)
	if text.is_empty():
		push_error("[Art] Cannot read atlas '%s' (%s): %s" % [atlas, json_path, error_string(FileAccess.get_open_error())])
		return {}
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary and data.get("texture") is String and data.get("sprites") is Dictionary and data.get("palette") is Array):
		push_error("[Art] Atlas sidecar %s is not {texture, palette, sprites}; rebuild with tools/pixelart.py" % json_path)
		return {}
	var texture_path: String = ART_DIR + str(data["texture"])
	var atlas_texture := load(texture_path) as Texture2D
	if atlas_texture == null:
		push_error("[Art] Cannot load atlas texture %s" % texture_path)
		return {}
	var rects := {}
	var used := {}
	var sources := {}
	for sprite_name: String in data["sprites"]:
		var rect: Dictionary = data["sprites"][sprite_name]
		if not rect.get("colors") is Array or not rect.get("rows") is Array:
			push_error("[Art] Sprite '%s' in %s has no colors or rows list; rebuild with tools/pixelart.py" % [sprite_name, json_path])
			return {}
		rects[sprite_name] = Rect2(rect["x"], rect["y"], rect["w"], rect["h"])
		used[sprite_name] = PackedStringArray(rect["colors"])
		sources[sprite_name] = PackedStringArray(rect["rows"])
	var sheet := {"texture": atlas_texture, "sprites": rects, "colors": used, "rows": sources, "palette": PackedStringArray(data["palette"])}
	_atlases[atlas] = sheet
	return sheet
