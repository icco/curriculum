# Midjourney prompts for Curriculum

Drop generated images into `assets/source/<category>/<name>.png`, run

```sh
godot --headless --path . --script tools/import_assets.gd
```

and the art appears in game. Anything missing keeps drawing procedurally, so a
partial set works — check what is still outstanding with:

```sh
godot --headless --path . --script tools/import_assets.gd -- --status
```

## Three things that decide whether the output is usable

1. **Midjourney cannot output transparency.** Every prompt asks for a flat
   magenta `#FF00FF` background; the importer keys it out. Do not accept an
   image where magenta bleeds into the subject's edges — regenerate instead.
2. **The projection must be 2:1 dimetric**, not the 30° "true isometric"
   Midjourney reaches for by default. Tiles are 64×32: a diamond twice as wide
   as it is tall. The prompts say so explicitly; reject images where the
   diamond looks square-ish.
3. **Scale must be consistent.** Every prompt names the same reference — a
   1.7m apprentice who stands 48px tall — and props are generated as one sheet
   so their sizes agree with each other. Generating props one at a time is how
   you end up with a lectern taller than a person.

## Workflow

1. **Style anchor first.** Generate the one image below, upscale the best
   variation, copy its URL, and pass it as `--sref <url>` on *every* later
   prompt. Without it the set will not look like one game.
2. Generate the protagonist, upscale, and use `--cref <url> --cw 60` for any
   other apprentice-like figure.
3. Generate sheets, split them, name the pieces per the tables below.
4. Run the importer. Screenshot with `tools/shot.sh` and check the result in
   context, not in isolation.

### Style anchor

```
arcane academy interior, 2:1 dimetric isometric game art, muted candlelit stone
and dark timber, cool blue rim light, restrained saturated accents of gold and
arcane cyan, clean readable silhouettes, hand-painted not photoreal, flat solid
magenta #FF00FF background --style raw --ar 1:1 --v 7
```

## Floor tiles — `assets/source/tiles/`

64×32 diamonds, seen from a fixed camera, no props on them, no perspective
distortion, edges meeting the diamond exactly.

Shared suffix (append to each):

```
single isometric floor tile, 2:1 diamond shape twice as wide as tall, top-down
45 degree view, tileable, no objects, no shadows cast outside the diamond, flat
solid magenta #FF00FF background --style raw --ar 2:1 --v 7 --sref <anchor>
```

| File | Prompt prefix |
| --- | --- |
| `floor_hall.png` | worn grey flagstone corridor floor, faint chalk ward lines |
| `floor_lecture_hall.png` | dark polished oak floorboards of a lecture hall |
| `floor_alchemy.png` | stained slate laboratory floor, faint acid burns, drainage channel |
| `floor_scriptorium.png` | deep red patterned carpet of a scriptorium, gold thread border |
| `floor_refectory.png` | scrubbed pale stone refectory floor, faint spill stains |
| `floor_training_yard.png` | packed sand and dirt training yard, painted practice circle |
| `floor_reliquary.png` | cold grey granite floor, brass inlay strip |
| `floor_study.png` | dark green study carpet, worn path |
| `floor_stairs.png` | descending spiral stone stair opening, blue arcane glow from below |

## Wall and door blocks — `assets/source/tiles/`

64×64. The bottom half is the diamond footprint; the block rises into the top
half. Get this wrong and walls sink into the floor.

| File | Prompt |
| --- | --- |
| `block_wall.png` | `isometric stone academy wall block, 2:1 dimetric cube, carved granite with mortar lines, top face visible, flat solid magenta #FF00FF background --style raw --ar 1:1 --v 7 --sref <anchor>` |
| `block_door_closed.png` | `isometric closed arched oak door in a stone frame, iron banding, 2:1 dimetric cube, flat solid magenta #FF00FF background --style raw --ar 1:1 --v 7 --sref <anchor>` |
| `block_door_open.png` | `isometric open arched doorway, stone frame with the door swung inward, dark passage visible through it, 2:1 dimetric, flat solid magenta #FF00FF background --style raw --ar 1:1 --v 7 --sref <anchor>` |

## Props — `assets/source/props/`

Generate as **one sheet** so the scale agrees, then split. Each is scaled to
56px tall on import and stands on the tile centre.

```
sprite sheet, 3x3 grid, evenly spaced, isometric 2:1 dimetric arcane academy
furniture seen from the same fixed camera: a study lectern, a wooden stool, a
lit iron brazier on a tripod, a warded oak reliquary chest with iron bands, a
tall bookshelf crammed with grimoires, a dark slate board covered in glowing
blue runes, a reading podium, an empty opened reliquary, a plain writing desk.
All at consistent scale where a 1.7m person would be 48 pixels tall. Flat solid
magenta #FF00FF background between and behind every object --style raw --ar 1:1
--v 7 --sref <anchor>
```

Split into: `desk.png`, `chair.png`, `brazier.png`, `reliquary.png`,
`reliquary_looted.png`, `bookshelf.png`, `rune_slate.png`, `podium.png`.

`reliquary_looted.png` is optional; without it a looted chest reuses
`reliquary.png` and only loses its glowing seal.

## Characters — `assets/source/entities/`

Scaled to 48px tall, standing on the tile centre, facing the camera at
three-quarters. Names match the enemy ids, so the importer wires them up
automatically.

Shared suffix:

```
full body, standing, facing three-quarters toward the viewer, isometric game
sprite at 2:1 dimetric camera angle, readable silhouette, 1.7m tall reference,
flat solid magenta #FF00FF background --style raw --ar 1:2 --v 7 --sref <anchor>
```

| File | Prompt prefix |
| --- | --- |
| `player.png` | young apprentice in a patched blue-grey robe, satchel of scrolls, determined, chalk-dusted hands |
| `novice.png` | nervous first-year novice clutching an oversized grimoire, plain undyed robe |
| `battle_chanter.png` | broad-shouldered chanter in reinforced crimson robes, shield strapped to one arm |
| `disputation_adept.png` | thin debate adept in violet scholar robes, hovering quill and open ledger |
| `illusionist.png` | theatrical illusionist in teal robes, mirrored mask, faint duplicate afterimage |
| `proctor.png` | corridor proctor in amber uniform robes, brass badge, ledger and spike |
| `senior_warden.png` | senior warden in ornate orange-gold robes, warding horn at the belt |
| `visiting_lecturer.png` | severe visiting lecturer in purple academic robes holding a red quill |
| `alchemy_master.png` | alchemy master in stained deep purple robes, bandolier of flasks, goggles |
| `drillmaster.png` | scarred yard drillmaster in dark red training leathers, bound stones on a rope |
| `vice_chancellor.png` | imposing vice-chancellor in heavy violet ceremonial robes holding a great ledger |
| `rector.png` | the Rector, towering figure in deep indigo and gold, crown of floating runes, radiating authority |

## If the output fights you

- **Magenta fringing on edges** — the importer feathers a narrow band, but a
  bad key is better fixed by regenerating with `--style raw` and a plainer
  background than by widening `TOLERANCE` in `tools/import_assets.gd`.
- **Wrong projection** — add `flat 2:1 dimetric projection, NOT 30 degree
  isometric, twice as wide as tall` and drop `--v` to a version that follows
  geometry more literally.
- **Inconsistent scale** — regenerate as a sheet rather than individually, and
  keep the 1.7m/48px reference clause verbatim.
- **Too busy at 48px** — Midjourney over-detailises. Ask for `simple shapes,
  strong silhouette, minimal detail, readable at 48 pixels tall`.
