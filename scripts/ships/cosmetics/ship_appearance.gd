class_name ShipAppearance
extends RefCounted
## Versioned cosmetic data only; never reads or writes ship movement or equipment.

const DEFAULT_SHIP_NAME := "Your Ship"
const SHIP_NAME_LIMIT := 24
const SAVE_PATH := "user://ship_appearance.json"
const SHAPES := ["square", "swallowtail", "pointed", "streamer"]
const PATTERNS := ["plain", "border", "stripes", "quarters", "chevron", "diamonds", "hem", "split"]
const EMBLEMS := ["none", "skull", "compass", "kraken", "gull", "sun", "waves", "moon"]
const FIGURES := ["none", "gull", "serpent", "lion", "nautilus"]
const LAMPS := ["none", "lanterns", "cobalt_lamps", "paper_lamps"]
const TROPHIES := ["none", "leviathan", "kraken", "compass_crest", "sun_crest"]
const PROPS := ["none", "chest", "crates", "rope_coil", "flowers", "bottles", "books", "barrel", "cushions"]
const SLOTS := ["fore_port", "fore_starboard", "aft_port", "aft_starboard"]
const REGIONS := ["hull", "trim", "deck", "masts"]
const PALETTES := {
	"natural": ["#aa6344", "#713e2e", "#dca574", "#89533a"],
	"crimson": ["#642c2d", "#c39b50", "#cfa77b", "#49362d"],
	"teal": ["#25585b", "#d3bd83", "#bb966d", "#534235"],
	"navy": ["#263d59", "#e1d0a5", "#b8946a", "#553e30"],
	"ivory": ["#ddd3b4", "#52736b", "#ba9066", "#72513a"],
	"black": ["#282f34", "#b49651", "#8b7052", "#3e332c"]
}

static func sail() -> Dictionary:
	return {"enabled": true, "shape": "square", "cloth": "#d8c7a0", "ink": "#273d48", "pattern": "border", "emblem": "compass"}

static func defaults() -> Dictionary:
	var flag := {"shape": "swallowtail", "cloth": "#78332d", "ink": "#ecd8a7", "pattern": "border", "emblem": "none", "length": 1.0, "height": 1.0}
	return {"version": 1, "ship_name": DEFAULT_SHIP_NAME, "paint": false, "hull": "#aa6344", "trim": "#713e2e", "deck": "#dca574", "masts": "#89533a", "main": sail(), "secondary": sail(), "match_sails": true, "pennants": true, "match_pennants": true, "main_flag": flag.duplicate(true), "fore_flag": flag.duplicate(true), "aft_flag": flag.duplicate(true), "figurehead": "gull", "lamps": "lanterns", "trophy": "leviathan", "banners": true, "bunting": false, "tassels": false, "decoration_color": "crimson", "banners_color": "crimson", "bunting_color": "crimson", "tassels_color": "crimson", "fore_port": "chest", "fore_starboard": "none", "aft_port": "none", "aft_starboard": "books"}

static func validate_name(value: Variant) -> String:
	if not value is String: return DEFAULT_SHIP_NAME
	var cleaned := ""
	for glyph in value:
		if glyph.unicode_at(0) >= 32 and glyph.unicode_at(0) != 127: cleaned += glyph
	cleaned = cleaned.strip_edges().left(SHIP_NAME_LIMIT)
	return DEFAULT_SHIP_NAME if cleaned.is_empty() else cleaned

static func choose_palette(data: Dictionary, palette: String) -> void:
	if not PALETTES.has(palette): return
	data.paint = palette != "natural"
	for i in REGIONS.size(): data[REGIONS[i]] = PALETTES[palette][i]

static func preset(id: String) -> Dictionary:
	var data := defaults()
	if id == "tidebound":
		data.figurehead = "serpent"
		data.trophy = "kraken"
		data.lamps = "cobalt_lamps"
		data.banners = false
		data.tassels = true
		data.decoration_color = "teal"
		data.main.cloth = "#256561"
		data.main.ink = "#ecd8a7"
		data.main.emblem = "kraken"
		data.main_flag.cloth = "#256561"
		data.fore_port = "rope_coil"
		data.aft_starboard = "bottles"
		choose_palette(data, "teal")
	elif id == "festival":
		data.trophy = "none"
		data.lamps = "paper_lamps"
		data.bunting = true
		data.decoration_color = "ivory"
		data.main.pattern = "hem"
		data.main.emblem = "gull"
		data.main_flag.cloth = "#d8c7a0"
		data.main_flag.ink = "#273d48"
		data.fore_port = "flowers"
		data.aft_starboard = "cushions"
		choose_palette(data, "ivory")
	return data

static func _enum(value: Variant, allowed: Array, fallback: String) -> String:
	return value if value is String and value in allowed else fallback

static func _color(value: Variant, fallback: String) -> String:
	return "#" + Color.from_string(value, Color(fallback)).to_html(false) if value is String else fallback

static func _cloth(value: Variant, fallback: Dictionary, flag: bool) -> Dictionary:
	var out := fallback.duplicate(true)
	if not value is Dictionary: return out
	out.shape = _enum(value.get("shape"), SHAPES + (["none"] if flag else []), out.shape)
	out.pattern = _enum(value.get("pattern"), PATTERNS, out.pattern)
	out.emblem = _enum(value.get("emblem"), EMBLEMS, out.emblem)
	for key in ["cloth", "ink"]: out[key] = _color(value.get(key), out[key])
	if flag:
		for key in ["length", "height"]:
			var v: Variant = value.get(key)
			if (v is float or v is int) and is_finite(float(v)):
				out[key] = clampf(float(v), 0.75, 1.35 if key == "length" else 1.2)
	elif value.get("enabled") is bool: out.enabled = value.enabled
	return out

static func validate(value: Variant) -> Dictionary:
	var out := defaults()
	if not value is Dictionary or value.get("version", 1) != 1: return out
	out.ship_name = validate_name(value.get("ship_name"))
	for key in ["paint", "pennants", "banners", "bunting", "tassels"]:
		if value.get(key) is bool: out[key] = value[key]
	for key in REGIONS: out[key] = _color(value.get(key), out[key])
	for key in ["main", "main_flag"]:
		out[key] = _cloth(value.get(key), out[key], key.ends_with("flag"))
	# Keep legacy save fields synchronized; both sails always use the main design.
	out.match_sails = true
	out.secondary = out.main.duplicate(true)
	out.match_pennants = true
	out.fore_flag = out.main_flag.duplicate(true)
	out.aft_flag = out.main_flag.duplicate(true)
	for pair in [["figurehead", FIGURES], ["lamps", LAMPS], ["trophy", TROPHIES], ["decoration_color", ["crimson", "teal", "ivory"]]]:
		out[pair[0]] = _enum(value.get(pair[0]), pair[1], out[pair[0]])
	for id in ["banners", "bunting", "tassels"]:
		out[id + "_color"] = _enum(value.get(id + "_color"), ["crimson", "teal", "ivory"], out.decoration_color)
	for key in SLOTS: out[key] = _enum(value.get(key), PROPS, out[key])
	return out

static func read_saved(path := SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return defaults()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK: return defaults()
	return validate(json.data)

static func save(data: Dictionary, path := SAVE_PATH) -> Error:
	# Atomic replacement leaves the previous complete loadout intact on write failure.
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(validate(data), "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(path + ".tmp", path)
