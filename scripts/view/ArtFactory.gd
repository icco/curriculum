class_name ArtFactory
extends RefCounted

## Paints the procedural fallbacks. Flat shapes and stipple grain, never gradients:
## the art direction is 1950s screenprint, and flat shapes read at card size.


static func _grain(image: Image, rng: RandomNumberGenerator, density := 0.06) -> void:
	var count := int(float(image.get_width() * image.get_height()) * density)
	for _i in count:
		var x := rng.randi_range(0, image.get_width() - 1)
		var y := rng.randi_range(0, image.get_height() - 1)
		var grey := ArtLibrary.GRAIN_A if rng.randf() < 0.5 else ArtLibrary.GRAIN_B
		image.set_pixel(x, y, image.get_pixel(x, y).lerp(grey, 0.35))


static func _rng_for(text: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	return rng


## A card's illustration area: the school's ink as a large organic field on paper.
static func card_face(school, size: Vector2i) -> ImageTexture:
	var image := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	image.fill(ArtLibrary.PAPER)
	var ink: Color = Schools.colour(school)
	var rng := _rng_for(Schools.display_name(school))

	# One big flat field, inset like a printed plate rather than bleeding to the
	# edge. The inset is w/8, so at 32x48 the plate starts exactly at (4,4) — the
	# pixel test_art samples — and the paper ground still frames every card.
	var inset := maxi(1, size.x / 8)
	for y in range(inset, size.y - inset):
		for x in range(inset, size.x - inset):
			image.set_pixel(x, y, ink)

	# A single stippled celestial glyph, as in the reference.
	var glyph := Vector2(float(size.x) * 0.72, float(size.y) * 0.22)
	var glyph_r := maxf(1.0, float(size.x) * 0.09)
	for y in size.y:
		for x in size.x:
			if Vector2(x, y).distance_to(glyph) <= glyph_r:
				image.set_pixel(x, y, ArtLibrary.GRAIN_A)

	_grain(image, rng)
	return ImageTexture.create_from_image(image)


## The school's mark: a small flat shape, distinct per school by silhouette as well as
## by colour, so it survives a colourblind player.
static func sigil(school, size: Vector2i) -> ImageTexture:
	var image := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ink: Color = Schools.colour(school)
	var w := size.x
	var h := size.y
	match school:
		Schools.School.CINDER:  # upward triangle
			for y in h:
				var half := int(float(y) / float(h) * float(w) * 0.5)
				for x in range(w / 2 - half, w / 2 + half + 1):
					if x >= 0 and x < w:
						image.set_pixel(x, h - 1 - y, ink)
		Schools.School.FROST:  # diamond
			for y in h:
				var d := absi(y - h / 2)
				var half := (h / 2 - d) * w / maxi(1, h)
				for x in range(w / 2 - half, w / 2 + half + 1):
					if x >= 0 and x < w:
						image.set_pixel(x, y, ink)
		Schools.School.INK:  # filled circle
			var r := float(mini(w, h)) * 0.45
			for y in h:
				for x in w:
					if Vector2(x, y).distance_to(Vector2(w, h) * 0.5) <= r:
						image.set_pixel(x, y, ink)
		Schools.School.ROT:  # downward triangle
			for y in h:
				var half := int(float(h - y) / float(h) * float(w) * 0.5)
				for x in range(w / 2 - half, w / 2 + half + 1):
					if x >= 0 and x < w:
						image.set_pixel(x, h - 1 - y, ink)
		Schools.School.WARD:  # square
			for y in range(h / 6, h - h / 6):
				for x in range(w / 6, w - w / 6):
					image.set_pixel(x, y, ink)
	return ImageTexture.create_from_image(image)


## A figure: a flat silhouette whose proportions come from the name, so an examiner
## looks the same in every battle.
static func figure(seed_text: String, size: Vector2i) -> ImageTexture:
	var image := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng := _rng_for(seed_text)
	var robe: Color = [
		Color("#D45C3C"), Color("#E0A51F"), Color("#498BAD"), Color("#6E7B3F"), Color("#A3B0AC")
	][rng.randi_range(0, 4)]
	var w := size.x
	var h := size.y

	# Robe: a trapezium widening to the hem.
	var shoulder := int(float(w) * rng.randf_range(0.34, 0.46))
	for y in range(int(float(h) * 0.28), h):
		var t := float(y - int(float(h) * 0.28)) / maxf(1.0, float(h) * 0.72)
		var half := int(lerpf(float(shoulder), float(w) * 0.5, t))
		for x in range(w / 2 - half, w / 2 + half):
			if x >= 0 and x < w:
				image.set_pixel(x, y, robe)

	# Head: a black circle, the reference's flat-black treatment.
	var head_r := float(w) * 0.18
	var head_c := Vector2(float(w) * 0.5, float(h) * 0.18)
	for y in h:
		for x in w:
			if Vector2(x, y).distance_to(head_c) <= head_r:
				image.set_pixel(x, y, ArtLibrary.INK)

	_grain(image, rng, 0.05)
	return ImageTexture.create_from_image(image)


## A course medallion, one flat colour per tier.
static func medallion(tier: int, size: Vector2i) -> ImageTexture:
	var image := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ink: Color = [Color("#498BAD"), Color("#E0A51F"), Color("#D45C3C")][clampi(tier - 1, 0, 2)]
	var r := float(mini(size.x, size.y)) * 0.46
	var c := Vector2(size.x, size.y) * 0.5
	for y in size.y:
		for x in size.x:
			var d := Vector2(x, y).distance_to(c)
			if d <= r:
				image.set_pixel(x, y, ink if d > r * 0.72 else ArtLibrary.PAPER)
	_grain(image, _rng_for("tier%d" % tier), 0.04)
	return ImageTexture.create_from_image(image)
