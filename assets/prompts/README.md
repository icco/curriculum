# Prompts

The generative prompts behind this project, kept in the repo so the intent
behind the code and the art stays readable.

| File | What it is |
| --- | --- |
| [`init-prompt.md`](init-prompt.md) | The original design specification the game was built from. Unedited, including its truncation mid-JSON in section 4 — the enemy, spell, loot and skill schemas in `resources/` were filled in by analogy to the player schema it does define. Describes the game as a high school; it was rethemed to an arcane academy afterwards, so read the names as historical. |
| [`midjourney.md`](midjourney.md) | The working prompt set for game art, with the geometry, scale and background-key constraints the importer depends on. This one is live: edit it when the art direction changes. |
| [`anchor.png`](anchor.png) | The style anchor every prompt references with `--sref`. Kept here so the art direction survives Midjourney's CDN. |

Neither ships in an exported build — `export_presets.cfg` excludes this
directory.
