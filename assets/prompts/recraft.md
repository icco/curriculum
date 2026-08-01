## Known cross-branch conflict: two cards held back

`tests/test_card_school_colour.gd` (owned by another branch, not this one) samples
the exact painted pixel of `cards/spark` and `cards/frost_lance` and asserts it
equals `ArtFactory.card_face()`'s procedural output -- true only while those two
cards have no real sprite. Real art for either breaks that test.

Every other card the test touches (`Ink Blot`, `Guard`) only checks label text
colour, not the illustration, so real art for those is fine -- verified by
generating both and running `./tools/check.sh`.

Until that test is updated (it hardcodes two arbitrary probe cards; any other pair
would do), `cards/spark` and `cards/frost_lance` are generated -- variants exist
under `assets/source/cards/{spark,frost_lance}/` -- but deliberately not `--accept`ed,
so `assets/sprites/` has no file for them and they keep rendering procedurally.
Accepting is one command once the conflict is resolved.

# Art direction

Mid-century modern screenprint, in the lineage of Alexander Girard and Charley
Harper. Completely flat shapes — no outlines, no shading, no gradients, no
rendering. Form is carried entirely by silhouette. A tiny palette of flat inks on a
warm cream ground, with visible risograph halftone grain inside each ink and along
its edges. Compositions sit on a large organic field shape rather than bleeding to
the edge, leaving a cream margin like a printed plate. Small stippled celestial
glyphs — a circle, a crescent, a five-pointed star — float as texture against the
flat inks.

The game's UI is light, not dark. An earlier draft of the design brief said "dark
fantasy parchment"; this project deliberately inverts the value while keeping the
tone. This art must never render dark.

**What this borrows and what it does not.** The register comes from Helvetica
Blanc's *Catch (Feelings) And Release* — screenprint flatness, the limited ink
palette, riso grain, the ruled title box. It does **not** borrow that artist's
invented alphabet or any specific composition. No decorative mark in this set may
stand in for text a player has to read, and none is a constructed script.

## Exact palette

Sampled from the reference artwork's own PNG palette chunk. Nothing outside this
list:

| Name | Hex |
|---|---|
| Paper | `#F7EADD` |
| Black | `#000000` |
| Pale slate | `#A3B0AC` |
| Grain grey A | `#999189` |
| Grain grey B | `#6C6661` |
| Cinder (school ink) | `#D45C3C` |
| Frost (school ink) | `#498BAD` |
| Ink (school ink) | `#000000` |
| Rot (school ink) | `#6E7B3F` |
| Ward (school ink) | `#E0A51F` |

These match `ArtLibrary` and `Schools.colour()` exactly (`scripts/view/ArtLibrary.gd`,
`scripts/Schools.gd`) so generated art and the procedural fallback it replaces read
as the same palette.

## Why the manifest is structured the way it is

`assets/prompts/manifest.json` has one `style` string, shared by every subject, and
a `prompt` per subject. That split exists because of two hard constraints on
Recraft's V4 models (`recraftv4` / `recraftv4_1`, in every variant including `_pro`
and `_vector`):

- **`negative_prompt` is unsupported on V4.** It's accepted by V2/V3 models only.
  Say what a thing *is*; a V4 prompt that says what it is *not* just re-describes
  the excluded thing and gets it back.
- **`style_id` is unsupported on V4 too**, so there is no way to lock a reusable
  style reference server-side. Cohesion across ~140 independent generations rests
  entirely on the one shared `style` clause in the manifest. If the set drifts,
  tighten that clause and regenerate the outliers — don't patch individual subject
  prompts to compensate, or the set drifts again next time someone edits `style`.
- **Colour belongs in the subject line, not `style`.** `style` is concatenated in
  front of every subject's prompt, so a colour named there would override every
  subject's own colour — a Frost card and a Cinder card would come back the same
  ink. Each subject prompt names its own colour instead.

## Judge at card size, not at 1024px

A card is ~200px wide in a five-card fan (`CardView.CARD_SIZE` is `200x300`). An
examiner portrait is `360x520`. Something gorgeous at full generated resolution is
often mush at those sizes. Use only three or four large shapes per subject and no
fine detail — this is why the manifest's per-level card prompts escalate by
silhouette *count and scale* (`LEVEL_AXIS` in the generator) rather than by adding
detail: detail is exactly what disappears first when a card shrinks.

Always look at a downloaded variant scaled to its real on-screen size before
accepting it.

## Two simplifications versus the previous art pipeline

Art is generated directly onto the cream ground, and the flat style has no
perspective. That means this pipeline has:

- **no background-removal step** — there is no background to remove; the cream
  ground *is* the ground.
- **no projection step** — nothing here is drawn as if wrapped onto a 3D surface.

## Sizes

Recraft's `size` parameter only accepts a fixed list of `WxH` strings per model —
it is not free-form. `manifest.json`'s `sizes` map names three that were confirmed
against `recraftv4` directly (an invalid size returns an `invalid_request_parameter`
error naming the size that was rejected, so this isn't guessed from documentation
alone):

- `card` / `portrait` — `1024x1536`, a 2:3 portrait matching `CardView.CARD_SIZE`
  and the examiner figure's silhouette.
- `square` — `1024x1024`, for sigils, backdrops-as-badges, and ornaments.

## File naming

Recraft serves WebP regardless of what the request or response URL implies. Godot
picks its image loader from the file extension, so a mis-named file silently fails
to import or imports garbage. Both `tools/recraft.py` (on download) and
`tools/import_assets.gd` (on conversion) sniff magic bytes rather than trust an
extension anywhere in the pipeline.
