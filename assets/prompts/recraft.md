# Generating art for Curriculum

Art comes from the [Recraft API](https://www.recraft.ai/docs). Every subject, plus
the shared style and framing clauses, lives in [`manifest.json`](manifest.json);
`tools/recraft.py` reads it, so there is no prompt text to copy by hand.

Needs `RECRAFT_API_KEY`. A generation is ~35 credits (about $0.035) and a cutout
adds 10, so four variants cost well under a dollar — generate four and pick.

```sh
python3 tools/recraft.py list
python3 tools/recraft.py texture floor_hall --n 4    # flat tile textures
python3 tools/recraft.py cutout props desk --n 4     # objects, backgrounds removed
```

## Two shapes of asset

**Floor tiles are textures.** Recraft generates a flat, top-down, seamless square
of the material; `tools/make_tile.gd` projects it onto the diamond — rotate 45°,
halve the vertical scale, mask, darken the rim.

```sh
godot --headless --path . --script tools/make_tile.gd -- assets/source/textures/floor_hall-3.webp floor_hall
./tools/import-assets.sh
```

Deriving the geometry is the point. No generator reliably draws a diamond exactly
twice as wide as it is tall; a square texture has nothing to get wrong, so the
projection is exact and the model only has to paint.

**Blocks are constructed too.** `tools/make_block.gd` shears the same flat texture
onto the three visible faces of a cube and shades them differently, which is the
standard isometric technique and keeps the footprint on the grid. An optional
second texture covers the front-left face; that is how a door gets into a wall.

```sh
godot --headless --path . --script tools/make_block.gd -- textures/wall_stone-3.webp block_door_closed textures/door_closed_face-2.webp
```

**Props and figures are cutouts** — one object on a plain backdrop, run through
`removeBackground` for real alpha, trimmed and scaled to the `HEIGHTS` table.

## Judging output

A tile is 64×32 on screen. That is the only size that matters: a texture that is
gorgeous at 1024px is often mush at 64.

- **Coarse features.** Fine detail becomes noise, hence "roughly six repeats
  across the frame" in the manifest.
- **Say what the material is, not what it is not.** Negations get you the thing you
  excluded, and `negative_prompt` is unsupported on V4 models.
- **Avoid the word "features".** It is read as *draw some objects*.
- **Colour belongs to the subject line,** not the shared style clause, which
  otherwise overrides every material's own colour.
- **Ask for the camera.** Cutouts came back at mixed angles, some straight-on and
  some from above, which reads as unrelated objects on one floor. `cutout_rules`
  names the three-quarter overhead view.
- **Check contrast against the floor it will sit on.** Dark props on the dark
  alchemy tile disappear. Keep the rejected variants until the sprite has been seen
  in-game, not just in the atlas.
- **A special tile is recognised by its colour, not by what it depicts.** There is
  no room to draw a staircase at 64×32 — a spiral reads as a circle, grey steps as a
  drain grate. `floor_stairs` is glowing cyan because nothing else is.

## Cohesion

There is no style-reference image: **Recraft styles are unsupported on V4 models**,
and `style_id` requires `recraftv3`, which misread these prompts badly. Cohesion
rests on the shared `style` clause applied to every asset. If the set drifts,
tighten that clause and regenerate rather than patching subjects.

## What is committed

Raw WebP output in `assets/source/textures/` is gitignored, rejected variants
included. Committed: the accepted texture that `make_tile.gd` keeps there as a
512px `.png`, the projected tile in `assets/source/tiles/`, and the sprite in
`assets/sprites/`. Generation is not deterministic, so the accepted texture is the
only way to redo the projection — changing `RIM_DARKEN`, say — without changing the
art.

## Model

`recraftv4_1`. Sizes come from a published per-model list, not free-form:
`1024x1024` for textures and cutouts, `768x1536` for figures. `--n` is 1–6.
