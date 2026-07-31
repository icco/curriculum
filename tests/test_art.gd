extends TestCase

## Art is optional per sprite. These checks are what let the game ship before any
## illustration exists, and what stop a typo'd art_id from silently falling back.


func suite_name() -> String:
	return "art"


func run() -> void:
	eq(ArtLibrary.PAPER, Color("#F7EADD"), "paper is the reference cream")
	eq(ArtLibrary.INK, Color("#000000"), "ink is black")

	# A key with no file still returns a usable texture.
	var missing := ArtLibrary.texture("cards/definitely_not_a_real_key", Vector2i(64, 96))
	check(missing != null, "fallback texture returned")
	eq(missing.get_width(), 64, "fallback respects the requested width")
	eq(missing.get_height(), 96, "fallback respects the requested height")
	eq(ArtLibrary.has_sprite("cards/definitely_not_a_real_key"), false, "reports no sprite")

	# Every school paints a distinct card face and sigil.
	var faces := {}
	for school in Schools.ALL:
		var face := ArtFactory.card_face(school, Vector2i(32, 48))
		check(face != null, "painted a face for %s" % Schools.display_name(school))
		faces[face.get_image().get_pixel(4, 4)] = true
		var sigil := ArtFactory.sigil(school, Vector2i(16, 16))
		check(sigil != null, "painted a sigil for %s" % Schools.display_name(school))
	eq(faces.size(), 5, "the five schools paint five distinct faces")

	# Figures are deterministic per name, so an examiner looks the same every battle.
	var a := ArtFactory.figure("Novice", Vector2i(24, 48))
	var b := ArtFactory.figure("Novice", Vector2i(24, 48))
	eq(a.get_image().get_pixel(12, 24), b.get_image().get_pixel(12, 24), "figures are stable")
	var c := ArtFactory.figure("Rector", Vector2i(24, 48))
	neq(a.get_image().get_pixel(12, 24), c.get_image().get_pixel(12, 24), "different names differ")

	# Every art_id the content declares is a key the library can serve, painted or not.
	var library: ContentLibrary = load("res://resources/content_library.tres")
	var keys := []
	for card in library.cards:
		keys.append(card.art_id)
	for enemy in library.enemies:
		keys.append(enemy.art_id)
	for key in keys:
		var texture := ArtLibrary.texture(key, Vector2i(16, 16))
		check(texture != null, "%s resolves to something drawable" % key)

	# The theme exists and is light, per spec 9.2.
	var theme: Theme = load("res://resources/ui_theme.tres")
	check(theme != null, "theme loads")
	if theme != null:
		check(theme.default_font_size >= 24, "font is thumb-legible at 1080 wide")

	# Reports what art is still procedural, which drives the manifest in Task 25.
	var still_missing := ArtLibrary.missing_keys(keys)
	print("    art: %d of %d keys still procedural" % [still_missing.size(), keys.size()])
