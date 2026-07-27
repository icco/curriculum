# Midjourney prompts for Curriculum

Written for **midjourney.com** (the web imagine bar), verified against the
July 2026 model line-up. Drop generated images into
`assets/source/<category>/<name>.png`, run

```sh
godot --headless --path . --script tools/import_assets.gd
```

and the art appears in game. Anything missing keeps drawing procedurally, so a
partial set works — check what is still outstanding with:

```sh
godot --headless --path . --script tools/import_assets.gd -- --status
```

## Fix your settings panel first

The prompts below cannot fight your account defaults, and two of them wreck a
game asset set. Open the settings button in the imagine bar and set:

| Setting | Value | Why |
| --- | --- | --- |
| **Variety** (chaos) | **0** | The default is 0, but a cranked-up value is the single most destructive setting here: Midjourney's own docs say high chaos means the images "may not stick as closely to your prompt". At 100 you get four unrelated pictures. Every prompt below carries `--c 0` to override it, but fix the default too. |
| **Personalization** | **off** | A profile applies your personal aesthetic on top of the prompt and silently competes with the style anchor. There is no documented per-prompt override, so it must be off in settings. |
| **Draft mode** | off | Faster, but lower fidelity, and it is incompatible with `--oref`. |
| **Model** | anything | Each prompt pins `--v 7` itself. |

**Verify by reading the chips.** Every finished job lists the parameters it
actually ran with underneath it. If you see `chaos 100` or `profile …` there,
the settings won, not the prompt.

## Read this before you paste anything

1. **Every prompt below is one unbroken line.** The imagine bar is a
   single-line input; a prompt pasted with newlines in it gets flattened or
   truncated. Copy the whole line, including the parameters at the end.
2. **`PASTE_ANCHOR` is a placeholder.** Replace it with your moodboard code (see
   *Style anchor*) before pressing enter. Left in, Midjourney rejects the job —
   that is deliberate, a loud failure beats a silently unmatched art set.
3. **Midjourney ignores hex codes.** `#FF00FF` in a prompt does nothing; it only
   understands colour *names*. So the prompts ask in prose for "a flat, solid,
   uniform bright magenta chroma-key background" and the importer keys out
   whatever magenta actually comes back.
4. **Parameters are version-specific.** These prompts are pinned to `--v 7`,
   which supports everything used here. If you drop the `--v 7` and let the
   current default (8.2) run, see *Running on 8.2* at the bottom — `--style raw`
   is not a valid parameter there and the job will fail.
5. **Midjourney still cannot output transparency**, in any version. The magenta
   key is not a workaround for a missing feature, it is the only route.

## Workflow

1. **Style anchor first.** Run the anchor prompt, upscale the best variation,
   then on the website add that image to a **moodboard** and copy its code
   (`--p m1234…`). That code is what `PASTE_ANCHOR` stands for in every later
   prompt. Without it the set will not look like one game. Copy the code once
   and leave the moodboard alone until the set is finished — editing it mints a
   new code, and half your art would then be anchored to a different style.
   - No moodboard? Use `--sref <image-url>` with the upscaled anchor's URL
     instead. Same job, but you are pasting a URL 30 times.
2. Generate tiles, then blocks, then props, then characters. One asset per job.
3. Name each download per the tables below and drop it in `assets/source/`.
4. Run the importer. Screenshot with `tools/shot.sh` and check the result in
   context, not in isolation.

### Style anchor

```
A small isometric diorama of one arcane academy room seen from a fixed overhead 45 degree game camera, 2:1 dimetric projection, candlelit stone walls and dark timber, cool blue rim light, restrained gold and arcane-cyan accents, clean readable silhouettes, hand-painted game art rather than photoreal, the room floating alone on a plain dark background --ar 1:1 --style raw --s 50 --c 0 --no photograph, realistic lighting, characters, people, text, watermark, frame, border --v 7
```

## Floor tiles — `assets/source/tiles/`

Imported to 64×32: a diamond twice as wide as it is tall. Reject anything where
the diamond looks square-ish — that is Midjourney reaching for 30° "true
isometric" instead of the 2:1 dimetric the game uses.

| File | Subject | Line |
| --- | --- | --- |
| `floor_hall.png` | flagstone corridor | 1 |
| `floor_lecture_hall.png` | oak floorboards | 2 |
| `floor_alchemy.png` | stained slate | 3 |
| `floor_scriptorium.png` | red carpet | 4 |
| `floor_refectory.png` | pale scrubbed stone | 5 |
| `floor_training_yard.png` | packed sand | 6 |
| `floor_reliquary.png` | grey granite | 7 |
| `floor_study.png` | green carpet | 8 |
| `floor_stairs.png` | spiral stair opening | 9 |

```
A single isometric game floor tile of worn grey flagstone marked with faint chalk ward lines, shaped as a 2:1 dimetric diamond exactly twice as wide as it is tall, seen from a fixed 45 degree overhead game camera, tileable, the diamond filling the frame against a flat solid uniform bright magenta chroma-key background --ar 2:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, cast shadow, objects, text, watermark, frame, border, perspective distortion --v 7 --p PASTE_ANCHOR
A single isometric game floor tile of dark polished oak lecture-hall floorboards, shaped as a 2:1 dimetric diamond exactly twice as wide as it is tall, seen from a fixed 45 degree overhead game camera, tileable, the diamond filling the frame against a flat solid uniform bright magenta chroma-key background --ar 2:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, cast shadow, objects, text, watermark, frame, border, perspective distortion --v 7 --p PASTE_ANCHOR
A single isometric game floor tile of stained slate laboratory flooring with faint acid burns and a narrow drainage channel, shaped as a 2:1 dimetric diamond exactly twice as wide as it is tall, seen from a fixed 45 degree overhead game camera, tileable, the diamond filling the frame against a flat solid uniform bright magenta chroma-key background --ar 2:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, cast shadow, objects, text, watermark, frame, border, perspective distortion --v 7 --p PASTE_ANCHOR
A single isometric game floor tile of deep red patterned scriptorium carpet with a gold thread border, shaped as a 2:1 dimetric diamond exactly twice as wide as it is tall, seen from a fixed 45 degree overhead game camera, tileable, the diamond filling the frame against a flat solid uniform bright magenta chroma-key background --ar 2:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, cast shadow, objects, text, watermark, frame, border, perspective distortion --v 7 --p PASTE_ANCHOR
A single isometric game floor tile of scrubbed pale refectory stone with faint spill stains, shaped as a 2:1 dimetric diamond exactly twice as wide as it is tall, seen from a fixed 45 degree overhead game camera, tileable, the diamond filling the frame against a flat solid uniform bright magenta chroma-key background --ar 2:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, cast shadow, objects, text, watermark, frame, border, perspective distortion --v 7 --p PASTE_ANCHOR
A single isometric game floor tile of packed sand and dirt from a training yard with a painted practice circle, shaped as a 2:1 dimetric diamond exactly twice as wide as it is tall, seen from a fixed 45 degree overhead game camera, tileable, the diamond filling the frame against a flat solid uniform bright magenta chroma-key background --ar 2:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, cast shadow, objects, text, watermark, frame, border, perspective distortion --v 7 --p PASTE_ANCHOR
A single isometric game floor tile of cold grey granite inlaid with a brass strip, shaped as a 2:1 dimetric diamond exactly twice as wide as it is tall, seen from a fixed 45 degree overhead game camera, tileable, the diamond filling the frame against a flat solid uniform bright magenta chroma-key background --ar 2:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, cast shadow, objects, text, watermark, frame, border, perspective distortion --v 7 --p PASTE_ANCHOR
A single isometric game floor tile of dark green study carpet worn pale along one path, shaped as a 2:1 dimetric diamond exactly twice as wide as it is tall, seen from a fixed 45 degree overhead game camera, tileable, the diamond filling the frame against a flat solid uniform bright magenta chroma-key background --ar 2:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, cast shadow, objects, text, watermark, frame, border, perspective distortion --v 7 --p PASTE_ANCHOR
A single isometric game floor tile containing the opening of a descending spiral stone stair, blue arcane light glowing up from below, shaped as a 2:1 dimetric diamond exactly twice as wide as it is tall, seen from a fixed 45 degree overhead game camera, the diamond filling the frame against a flat solid uniform bright magenta chroma-key background --ar 2:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, cast shadow, text, watermark, frame, border, perspective distortion --v 7 --p PASTE_ANCHOR
```

## Wall and door blocks — `assets/source/tiles/`

Imported to 64×64. The bottom half is the diamond footprint and the block rises
into the top half — the prompts say so, and a block that ignores it sinks into
the floor.

| File | Subject | Line |
| --- | --- | --- |
| `block_wall.png` | stone wall | 1 |
| `block_door_closed.png` | closed oak door | 2 |
| `block_door_open.png` | open doorway | 3 |

```
An isometric stone academy wall block drawn as a 2:1 dimetric cube, carved granite with mortar lines, its top face visible and its base sitting on a 2:1 diamond footprint twice as wide as tall, seen from a fixed 45 degree game camera, the block filling the frame against a flat solid uniform bright magenta chroma-key background --ar 1:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, ground, floor, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
An isometric closed arched oak door with iron banding set in a carved stone frame, drawn as a 2:1 dimetric cube whose base sits on a 2:1 diamond footprint twice as wide as tall, seen from a fixed 45 degree game camera, filling the frame against a flat solid uniform bright magenta chroma-key background --ar 1:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, ground, floor, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
An isometric open arched stone doorway with the oak door swung inward and a dark passage visible through it, drawn as a 2:1 dimetric cube whose base sits on a 2:1 diamond footprint twice as wide as tall, seen from a fixed 45 degree game camera, filling the frame against a flat solid uniform bright magenta chroma-key background --ar 1:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, ground, floor, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
```

## Props — `assets/source/props/`

**One prop per job.** An earlier version of this file asked for a 3×3 sheet so
the scale would agree; that was wrong on both counts. The importer scales every
prop to its own target height from the `HEIGHTS` table in
`tools/import_assets.gd` — a stool comes out 26px and a bookshelf 62px whatever
the source images looked like — so a sheet buys no scale consistency, and nine
distinct named objects in one frame is Midjourney's least reliable composition:
it blends, duplicates and quietly drops objects. Adjust `HEIGHTS` rather than
resizing by hand.

The "1.7m person is 48 pixels" clause stays in each prompt, but it is about
internal proportion — a lectern reaching a person's chest — not about
cross-image scale.

| File | Subject | Line |
| --- | --- | --- |
| `desk.png` | writing desk | 1 |
| `chair.png` | wooden stool | 2 |
| `brazier.png` | lit brazier | 3 |
| `podium.png` | reading podium | 4 |
| `rune_slate.png` | rune slate board | 5 |
| `reliquary.png` | sealed reliquary chest | 6 |
| `reliquary_looted.png` | opened reliquary (optional) | 7 |
| `bookshelf.png` | grimoire bookshelf | 8 |

```
A plain wooden writing desk of an arcane academy, a single object drawn as isometric 2:1 dimetric game art from a fixed 45 degree camera, proportioned so a 1.7m person standing beside it would be 48 pixels tall, simple shapes and a strong silhouette that stays readable when shrunk to 30 pixels, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, room, other furniture, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A simple wooden stool of an arcane academy, a single object drawn as isometric 2:1 dimetric game art from a fixed 45 degree camera, proportioned so a 1.7m person standing beside it would be 48 pixels tall, simple shapes and a strong silhouette that stays readable when shrunk to 26 pixels, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, room, other furniture, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A lit iron brazier on a tripod, its coals glowing warm against the surrounding cool light, a single object drawn as isometric 2:1 dimetric game art from a fixed 45 degree camera, proportioned so a 1.7m person standing beside it would be 48 pixels tall, simple shapes and a strong silhouette that stays readable when shrunk to 40 pixels, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, room, other furniture, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A carved wooden reading podium with an open book resting on it, a single object drawn as isometric 2:1 dimetric game art from a fixed 45 degree camera, proportioned so a 1.7m person standing beside it would be 48 pixels tall, simple shapes and a strong silhouette that stays readable when shrunk to 34 pixels, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, room, other furniture, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A dark slate lecture board on a stand, its surface covered in glowing blue runes, a single object drawn as isometric 2:1 dimetric game art from a fixed 45 degree camera, proportioned so a 1.7m person standing beside it would be 48 pixels tall, simple shapes and a strong silhouette that stays readable when shrunk to 48 pixels, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, room, other furniture, legible writing, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A closed warded oak reliquary chest bound in iron with a glowing arcane seal across the lid, a single object drawn as isometric 2:1 dimetric game art from a fixed 45 degree camera, proportioned so a 1.7m person standing beside it would be 48 pixels tall, simple shapes and a strong silhouette that stays readable when shrunk to 52 pixels, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, room, other furniture, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
The same warded oak reliquary chest bound in iron, now standing open and empty with its arcane seal dark and broken, a single object drawn as isometric 2:1 dimetric game art from a fixed 45 degree camera, proportioned so a 1.7m person standing beside it would be 48 pixels tall, simple shapes and a strong silhouette that stays readable when shrunk to 52 pixels, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, room, other furniture, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A tall bookshelf crammed with grimoires and rolled scrolls, a single object drawn as isometric 2:1 dimetric game art from a fixed 45 degree camera, proportioned so a 1.7m person standing beside it would be 48 pixels tall, simple shapes and a strong silhouette that stays readable when shrunk to 62 pixels, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:1 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, room, other furniture, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
```

`reliquary_looted.png` is optional; without it a looted chest reuses
`reliquary.png` and only loses its glowing seal. Generate it from the upscaled
`reliquary.png` with `--oref <that image's url> --ow 300` appended so the two
chests match.

## Characters — `assets/source/entities/`

Standing on the tile centre, facing the camera at three-quarters. File names
match the enemy ids, so the importer wires them up automatically. Heights come
from `HEIGHTS` — a person is 48px, a novice 44, the Rector 66 — so rank reads
through size; do not pre-scale them yourself.

| File | Subject | Line |
| --- | --- | --- |
| `player.png` | apprentice protagonist | 1 |
| `novice.png` | first-year novice | 2 |
| `battle_chanter.png` | battle chanter | 3 |
| `disputation_adept.png` | disputation adept | 4 |
| `illusionist.png` | illusionist | 5 |
| `proctor.png` | corridor proctor | 6 |
| `senior_warden.png` | senior warden | 7 |
| `visiting_lecturer.png` | visiting lecturer | 8 |
| `alchemy_master.png` | alchemy master | 9 |
| `drillmaster.png` | yard drillmaster | 10 |
| `vice_chancellor.png` | vice-chancellor | 11 |
| `rector.png` | the Rector | 12 |

Generate `player.png` first, upscale it, and append `--oref <player image url>
--ow 100` to `novice.png` if you want the two to read as the same year group.
(`--cref` no longer exists in v7 — omni reference replaced it. Omni reference
costs double GPU time and is incompatible with draft mode.)

```
A young apprentice in a patched blue-grey robe with a satchel of scrolls and chalk-dusted hands, determined expression, shown full body standing and facing three-quarters toward the viewer, drawn as an isometric game sprite at a 2:1 dimetric camera angle, simple shapes and a strong readable silhouette at 48 pixels tall, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:2 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, scenery, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A nervous first-year novice clutching an oversized grimoire, wearing a plain undyed robe, shown full body standing and facing three-quarters toward the viewer, drawn as an isometric game sprite at a 2:1 dimetric camera angle, simple shapes and a strong readable silhouette at 44 pixels tall, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:2 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, scenery, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A broad-shouldered battle chanter in reinforced crimson robes with a shield strapped to one arm, shown full body standing and facing three-quarters toward the viewer, drawn as an isometric game sprite at a 2:1 dimetric camera angle, simple shapes and a strong readable silhouette at 50 pixels tall, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:2 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, scenery, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A thin disputation adept in violet scholar robes with a hovering quill and an open ledger, shown full body standing and facing three-quarters toward the viewer, drawn as an isometric game sprite at a 2:1 dimetric camera angle, simple shapes and a strong readable silhouette at 46 pixels tall, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:2 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, scenery, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A theatrical illusionist in teal robes wearing a mirrored mask, a faint duplicate afterimage trailing behind, shown full body standing and facing three-quarters toward the viewer, drawn as an isometric game sprite at a 2:1 dimetric camera angle, simple shapes and a strong readable silhouette at 47 pixels tall, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:2 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, scenery, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A corridor proctor in amber uniform robes with a brass badge, carrying a ledger and a spike, shown full body standing and facing three-quarters toward the viewer, drawn as an isometric game sprite at a 2:1 dimetric camera angle, simple shapes and a strong readable silhouette at 50 pixels tall, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:2 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, scenery, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A senior warden in ornate orange and gold robes with a warding horn at the belt, shown full body standing and facing three-quarters toward the viewer, drawn as an isometric game sprite at a 2:1 dimetric camera angle, simple shapes and a strong readable silhouette at 52 pixels tall, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:2 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, scenery, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A severe visiting lecturer in purple academic robes holding a red quill, shown full body standing and facing three-quarters toward the viewer, drawn as an isometric game sprite at a 2:1 dimetric camera angle, simple shapes and a strong readable silhouette at 50 pixels tall, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:2 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, scenery, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
An alchemy master in stained deep purple robes with a bandolier of flasks and goggles pushed up on the forehead, shown full body standing and facing three-quarters toward the viewer, drawn as an isometric game sprite at a 2:1 dimetric camera angle, simple shapes and a strong readable silhouette at 52 pixels tall, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:2 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, scenery, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
A scarred yard drillmaster in dark red training leathers swinging bound stones on a rope, shown full body standing and facing three-quarters toward the viewer, drawn as an isometric game sprite at a 2:1 dimetric camera angle, simple shapes and a strong readable silhouette at 56 pixels tall, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:2 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, scenery, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
An imposing vice-chancellor in heavy violet ceremonial robes carrying a great ledger, shown full body standing and facing three-quarters toward the viewer, drawn as an isometric game sprite at a 2:1 dimetric camera angle, simple shapes and a strong readable silhouette at 58 pixels tall, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:2 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, scenery, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
The Rector, a towering figure in deep indigo and gold robes beneath a crown of floating runes, radiating authority, shown full body standing and facing three-quarters toward the viewer, drawn as an isometric game sprite at a 2:1 dimetric camera angle, simple shapes and a strong readable silhouette at 66 pixels tall, isolated against a flat solid uniform bright magenta chroma-key background --ar 1:2 --style raw --s 50 --c 0 --no gradient, vignette, drop shadow, floor, ground, scenery, text, watermark, frame, border --v 7 --p PASTE_ANCHOR
```

## Running on 8.2 instead of 7

The prompts pin `--v 7` because every parameter used here works there. As of
July 2026 the site default is 8.2, where the parameter set differs — if you
strip `--v 7`, also:

- swap `--style raw` for `--raw`,
- drop `--oref` / `--ow` (v7 only), and with it the two matching-object tricks
  above,
- drop `--q` if you add it, and expect `--tile` and `--cref` to be rejected too.

`--ar`, `--s`, `--no` and `--sref` behave the same in both. `--p` should too,
but run one job to confirm before committing the whole set to 8.2.

## If the output fights you

- **Four wildly different images that barely resemble the prompt.** Read the
  parameter chips under the job. `chaos 100` or an active `profile` means your
  settings panel overrode the prompt — see *Fix your settings panel first*.
  This looks like a bad prompt and is not one.
- **Background survives the key, or leaves a halo.** Midjourney's "magenta"
  will not land exactly on `#FF00FF`, and `TOLERANCE` in
  `tools/import_assets.gd` is 0.28 with a 0.12 feather, and the cut actually
  reaches `TOLERANCE + FEATHER` — 0.40 today, 0.47 if you raise `TOLERANCE` to
  0.35. Violet robes are the nearest thing in the palette to magenta, so after
  any bump check `disputation_adept`, `alchemy_master` and `vice_chancellor`
  for chewed edges before trusting the new value.
- **Magenta bleeds into the subject's edges.** Regenerate rather than widening
  the tolerance further. Adding `chroma-key screen, evenly lit, no rim light
  from behind` to the background clause usually fixes it.
- **Wrong projection.** Say it harder and earlier: `flat 2:1 dimetric
  projection, twice as wide as tall, NOT 30 degree true isometric` near the
  front of the prompt, where terms carry more weight.
- **Too busy at 48px.** Midjourney over-detailises. Lower `--s` to 0 and keep
  the `simple shapes and a strong readable silhouette` clause verbatim.
- **A prompt is rejected outright.** Check for an unsubstituted `PASTE_ANCHOR`,
  a newline in the pasted text, or a parameter that does not exist in the
  version you are on.
