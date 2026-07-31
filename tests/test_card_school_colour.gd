extends TestCase

## A card's painted face must use the card's OWN school. The fallback can derive a
## school by hashing the art key, which is stable but wrong — and wrong is a gameplay
## bug here, because the ink is the player's only at-a-glance cue for the weakness
## mechanic. Asserting ArtFactory paints five distinct schools does NOT cover this:
## the break is at the integration point, where CardView asks ArtLibrary for a face.


func suite_name() -> String:
	return "cardcolour"


func _mid_pixel(t: Texture2D) -> Color:
	var img := t.get_image()
	return img.get_pixel(int(img.get_width() * 0.5), int(img.get_height() * 0.45))


func run() -> void:
	var library: ContentLibrary = load("res://resources/content_library.tres")
	var size := Vector2i(64, 96)

	# Each school's face must match what ArtFactory paints for that school directly.
	for school in Schools.ALL:
		var direct := ArtFactory.card_face(school, size)
		var via_library := ArtLibrary.texture("cards/probe_%d" % school, size, school)
		eq(
			_mid_pixel(via_library),
			_mid_pixel(direct),
			"library honours the school it is given (%s)" % Schools.display_name(school)
		)

	# Real cards: a Cinder card and a Frost card must not paint the same, and each must
	# match its own school. Spark is Cinder, Frost Lance is Frost.
	var spark: CardData = library.card_named("Spark")
	var lance: CardData = library.card_named("Frost Lance")
	check(spark != null and lance != null, "found both probe cards")
	if spark == null or lance == null:
		return
	eq(spark.school, Schools.School.CINDER, "spark is cinder")
	eq(lance.school, Schools.School.FROST, "frost lance is frost")

	var spark_face := ArtLibrary.texture(spark.art_id, size, spark.school)
	var lance_face := ArtLibrary.texture(lance.art_id, size, lance.school)
	eq(
		_mid_pixel(spark_face),
		_mid_pixel(ArtFactory.card_face(Schools.School.CINDER, size)),
		"spark paints cinder"
	)
	eq(
		_mid_pixel(lance_face),
		_mid_pixel(ArtFactory.card_face(Schools.School.FROST, size)),
		"frost lance paints frost"
	)
	neq(_mid_pixel(spark_face), _mid_pixel(lance_face), "two schools do not paint alike")

	# And the view actually passes the card's school through rather than dropping it.
	var view := CardView.new()
	view.setup(CardInstance.new(spark))
	var painted: Color = Color(0, 0, 0, 0)
	for child in view.get_children():
		if child is TextureRect and child.texture != null:
			painted = _mid_pixel(child.texture)
			break
	eq(
		painted,
		_mid_pixel(ArtFactory.card_face(Schools.School.CINDER, size)),
		"CardView paints Spark in cinder, not a hashed school"
	)
	# Ink is #000000, so an Ink card's name must be light or it is invisible.
	var blot: CardData = library.card_named("Ink Blot")
	eq(blot.school, Schools.School.INK, "ink blot is ink")
	var blot_view := CardView.new()
	blot_view.setup(CardInstance.new(blot))
	var blot_text := _label_colour(blot_view, "Ink Blot")
	check(blot_text.get_luminance() > 0.5, "an ink card's name is light against black")
	blot_view.free()

	# A light school keeps dark text.
	var guard: CardData = library.card_named("Guard")
	var guard_view := CardView.new()
	guard_view.setup(CardInstance.new(guard))
	var guard_text := _label_colour(guard_view, "Guard")
	check(guard_text.get_luminance() < 0.5, "a ward card's name stays dark against saffron")
	guard_view.free()

	view.free()


## A dark school ink must not swallow the card's own text.
func _label_colour(view: CardView, want_text: String) -> Color:
	for child in view.get_children():
		if child is Label and child.text == want_text:
			return child.get_theme_color("font_color")
	return Color(0, 0, 0, 0)
