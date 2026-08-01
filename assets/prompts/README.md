# Art pipeline

Generates the game's illustrations through the Recraft API and lands them as real
`.png` sprites `ArtLibrary` can load. See `recraft.md` for the art direction and the
reasoning behind the manifest's shape; this file is just the mechanics of running
it.

Every prompt lives in `manifest.json`. `tools/recraft.py` reads it; there is no
prompt text anywhere else, so a generated image can't drift from what's on record.

## Requirements

- `RECRAFT_API_KEY` in the environment.
- `godot` on `PATH` (or set `$GODOT`), for the conversion + import step. This
  project's Python tooling is stdlib-only — the conversion from whatever Recraft
  actually served to a real `.png` happens in Godot, not Python (see `recraft.md`).

## Workflow

Generation and acceptance are separate steps on purpose: a bad generation costs
exactly one API call, never more, and accepting doesn't call the API at all.

```sh
# 1. Spend money: generate variants for one subject, one card line, one category,
#    or everything still missing.
python3 tools/recraft.py --subject cards/spark
python3 tools/recraft.py --line spark            # all 5 levels of one card
python3 tools/recraft.py --category examiner     # all 9 portraits
python3 tools/recraft.py --all                   # every subject in the manifest

# See what a run would send without spending anything:
python3 tools/recraft.py --subject cards/spark --dry-run

# 2. Look at the variants under assets/source/<id>/v1.*, v2.*, ... at the size the
#    subject actually renders at (card ~200px wide, examiner ~360x520) -- not at
#    the ~1MP Recraft returns them at. Something gorgeous at full size can be mush
#    at card size.

# 3. Accept one. Free -- it's a local file copy, no API call.
python3 tools/recraft.py --subject cards/spark --accept 1

# 4. Convert every accepted source to a sprite and import it.
./tools/import-assets.sh

# 5. Confirm it's actually loadable (a .png on disk is not enough -- Godot has to
#    import it first):
godot --headless --path . --script tools/import_assets.gd    # reports missing ones
```

`python3 tools/recraft.py --list` shows accept status and the running spend total
for every subject in the manifest (logged locally to `assets/source/.spend.log`,
which is not committed).

## Layout

```
assets/prompts/manifest.json    # style clause, per-model sizes, every subject's prompt
assets/prompts/recraft.md       # art direction and the "why" behind the manifest
assets/source/<id>/v1.webp ...  # raw generator output, gitignored
assets/source/<id>/accepted.*   # the chosen variant, committed
assets/sprites/<id>.png         # the imported sprite ArtLibrary actually loads
```

`<id>` is the same string as the card/enemy resource's `art_id` (e.g.
`cards/spark`, `entities/novice`) or, for non-card art, the manifest subject's own
id (`schools/cinder_sigil`, `backdrops/tier_1`, `ornaments/card_back`).

## Nothing to regenerate if a sprite is missing

`ArtLibrary.texture()` falls back to painted procedural art for any key with no
`.png`, so the game is fully playable with the manifest only partially generated.
`tests/test_art.gd` checks that every `art_id` the content declares — and every one
of the 120 card ids the current five-level evolution scheme implies — has a
matching subject in the manifest, so a typo can't silently fall back forever
without at least failing a test.
