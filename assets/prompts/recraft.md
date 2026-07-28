# Generating art for Curriculum

Art comes from the [Recraft API](https://www.recraft.ai/docs). Subjects and the
shared style live in [`manifest.json`](manifest.json); `tools/recraft.py` reads
them, so there is no prompt text to copy and nothing that can drift from what was
actually generated.

Needs `RECRAFT_API_KEY` in the environment. A generation is ~35 credits (about
$0.035), so a four-variant call costs about $0.14 — cheap enough to always
generate four and pick, which is the workflow below.

```sh
python3 tools/recraft.py list                        # every asset the manifest defines
python3 tools/recraft.py texture floor_hall --n 4    # four flat textures
python3 tools/recraft.py cutout props desk --n 4     # four objects, backgrounds removed
```

Raw output lands in `assets/source/textures/` as WebP and is gitignored — it
includes every rejected variant, at over a megabyte each. Committed instead:

- the accepted texture, which `make_tile.gd` keeps beside the rejects as a 512px
  `.png`
- the projected diamond in `assets/source/tiles/`, or the cutout in
  `assets/source/props/` and friends
- the imported sprite in `assets/sprites/`

Keeping the accepted texture matters because generation is not deterministic:
regenerating gives *different* art. Without it, anything the projection bakes in —
`RIM_DARKEN` above all — becomes a one-way door.

## Two shapes of asset

The geometry problem differs, so the two paths differ.

**Floor tiles are textures.** Recraft generates a flat, top-down, seamless square
of the bare material. `tools/make_tile.gd` then projects it onto the game's
diamond — rotate 45°, halve the vertical scale, mask, darken the rim:

```sh
godot --headless --path . --script tools/make_tile.gd -- assets/source/textures/floor_hall-3.webp floor_hall
godot --headless --path . --script tools/import_assets.gd
```

Deriving the geometry is the point. No image generator reliably draws a diamond
exactly twice as wide as it is tall — ask for one and you get a slab at whatever
isometric angle it likes, extruded side walls included, which then has to be
measured and corrected. A square texture has no geometry to get wrong, so the
projection is exact every time and the model only has to paint.

**Everything else is a cutout.** Props, figures and blocks are generated as a
single object on a plain backdrop and passed through Recraft's `removeBackground`,
which yields real alpha. Blocks are written to `assets/source/tiles/`, not a
`blocks/` directory: they live in the tile atlas, and `ArtLibrary.block_key()`
looks them up under `tiles/`. `tools/import_assets.gd` trims and scales to the
`HEIGHTS` table. It refuses a source with no transparency, because a baked-in
backdrop looks fine in the atlas and wrong on screen.

## Judging a texture

A tile is 64×32 on screen. That is the only size that matters, and it is why
`tools/make_tile.gd` and the review sheet render at final scale — a texture that
is gorgeous at 1024px is often mush at 64.

- **Feature scale is the usual failure.** Fine detail becomes noise. The manifest
  asks for "roughly six repeats across the frame" for this reason.
- **Say what the material is, not what it is not.** "No stains, no debris" got
  stains and debris. Negations are unreliable, and `negative_prompt` is not
  supported on V4 models at all.
- **Never use the word "features".** "Four or five large features across the
  frame" was read as *draw four or five objects*, and produced floors with random
  dark squiggles painted on them. `texture_rules` now says "one repeating
  surface: no separate objects, props, symbols, letters or drawings".
- **Colour belongs to the subject, not the style clause.** A shared clause that
  named a palette turned oak floorboards blue-grey, and a lighting-based rewrite
  turned them plum. The style clause now covers treatment only — painterly, muted,
  dark, crisp — and each subject names its own colour.

## Cohesion without a style reference

There is no equivalent of a style-reference image here: **Recraft styles are not
supported on V4 models**, and `style_id` requires `recraftv3`. Tested both — v3
with a custom style built from a reference misread prompts badly (a "lecture
hall" texture came back as rows of desks seen from above) and looked washed out,
while plain `recraftv4_1` painted exactly the right thing. So cohesion comes from
the shared `style` clause in the manifest, applied verbatim to every asset.

This is weaker than a real style anchor. If the set starts drifting, the fix is to
tighten that one clause and regenerate everything, not to patch individual
subjects.

## Model and parameters

`recraftv4_1`, sizes `1024x1024` for textures and cutouts, `768x1536` for figures.
Sizes are not free-form; the API accepts a published list per model. `--n` may be
1–6 in a single call.
