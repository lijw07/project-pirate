class_name SailPainter
extends RefCounted

const TEMPLATES := preload("res://scripts/ships/cosmetics/paint_templates.gd").SVG
static var cache: Dictionary = {}

static func texture(settings: Dictionary, flag := false, aspect := 1.0) -> Texture2D:
	var key := "%s/%s/%s" % ["flag" if flag else "sail", settings.pattern, settings.emblem]
	var stamp: String = key + settings.cloth + settings.ink + str(aspect)
	if cache.has(stamp): return cache[stamp]
	var svg: String = TEMPLATES[key]
	svg = svg.replace("@CLOTH@", settings.cloth).replace("@INK@", settings.ink)
	svg = svg.replace("@EMBLEM_SCALE@", str(0.92 / aspect)).replace("@DISC_LEFT@", str(320 - 290 / aspect)).replace("@DISC_RADIUS@", str(290 / aspect)).replace("@DISC_DIAMETER@", str(580 / aspect))
	var image := Image.new()
	var error := image.load_svg_from_string(svg)
	if error != OK:
		push_error("Cannot render sail design: " + error_string(error))
		return null
	image.generate_mipmaps()
	var result := ImageTexture.create_from_image(image)
	if cache.size() >= 48: cache.erase(cache.keys()[0])
	cache[stamp] = result
	return result
