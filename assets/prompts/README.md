# Prompts

The generative prompts behind this project, kept in the repo so the intent
behind the code and the art stays readable.

| File | What it is |
| --- | --- |
| [`init-prompt.md`](init-prompt.md) | The original design specification the game was built from. Unedited, including its truncation mid-JSON in section 4 — the enemy, spell, loot and skill schemas in `resources/` were filled in by analogy to the player schema it does define. Describes the game as a high school; it was rethemed to an arcane academy afterwards, so read the names as historical. |
| [`manifest.json`](manifest.json) | Every asset's subject line plus the shared style and framing clauses. The single source of truth: `tools/recraft.py` reads it, so a prompt cannot drift from what was generated. Edit this when the art direction changes. |
| [`recraft.md`](recraft.md) | How the pipeline works end to end, what each stage is for, and how to judge a render. |

Neither ships in an exported build — `export_presets.cfg` excludes this
directory.
