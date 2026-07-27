# Working in this repo

Godot 4.7 / GDScript. No image assets — every texture and sprite is generated at
runtime, so the repo stays text-only.

## Commands

| Command | Purpose |
| --- | --- |
| `./tools/check.sh` | The gate. Refreshes the script-class cache, runs the headless suite, fails on engine errors *and* assertions. Run before every commit. |
| `./tools/shot.sh <out.png> [seed] [script] [delay]` | Launches the game windowed, optionally drives it, screenshots, quits. The only way to check anything visual. |
| `godot --headless --path . --script tools/simulate.gd -- 12 6 [aggressive] [verbose]` | Plays N headless runs and reports how deep they got. Use for balance work. |
| `./tools/export-web.sh` | Produces `build/web`, which the Docker image serves. |
| `./tools/import-assets.sh [--status]` | Processes `assets/source` into `assets/sprites` and re-imports. `--status` lists art still drawn procedurally. |
| `godot --headless --path . --script tools/generate_theme.gd` | Regenerates `resources/ui_theme.tres` after changing UI styling. |
| `godot --headless --path . --script tools/generate_input_map.gd` | Rewrites the input actions in `project.godot`. |

## Layout

| Path | Contents |
| --- | --- |
| `scripts/core/` | Rules and simulation. No scene nodes, no rendering. |
| `scripts/view/` | Isometric rendering, sprites, camera. |
| `scripts/ui/` | HUD and screens. |
| `scripts/data/` | Content Resource classes (SpellData, EnemyData, ...). |
| `resources/` | Content `.tres` files, the ContentLibrary index, the UI theme. |
| `assets/` | `source/` raw art in, `sprites/` processed art out, `PROMPTS.md`. |
| `tests/` | Headless suites, one `test_*.gd` per area. |
| `tools/` | Dev and CI scripts. |

Core code returns arrays of event dictionaries (`{"type": …, "text": …}`) rather
than touching the scene. The presentation layer replays them, so tests and the
game exercise the same path. Keep `scripts/core/` free of `scripts/view/`
references, and avoid mutual typed references between core classes — GDScript
treats those as cyclic and refuses to parse.

## Godot gotchas that cost real time here

- **`class_name` globals need the class cache.** A fresh clone cannot run tests
  until `godot --headless --import` has built
  `.godot/global_script_class_cache.cfg`. `check.sh` does this first; without it
  every `class_name` reference is "not declared in the current scope".
- **Godot exits 0 while printing `SCRIPT ERROR` every frame.** Never trust the
  exit code alone — grep the output. `check.sh` and `shot.sh` both do.
- **A `SceneTree` script's `_init()` has no tree.** `Engine.get_main_loop()` is
  null and the root window is not live, so anything needing the scene tree
  silently does nothing. `run_tests.gd` therefore runs from `_process()`.
- **`--headless` does not render.** `get_viewport().get_texture()` is blank.
  Screenshots need a real windowed run, `await RenderingServer.frame_post_draw`
  before grabbing the image, and a self-quit or the process hangs.
- **`get_canvas_transform()` is a frame stale.** Reading it right after changing
  `zoom` returns the old value, which silently broke pinch-zoom anchoring.
  `CameraRig.screen_to_world` computes from `position`/`zoom` instead.
- **`TileSetAtlasSource` draws nothing without `create_tile()`** per atlas
  coordinate — no error, just empty tiles. Tiles taller than the cell (walls,
  doors) need `TileData.texture_origin` lifted or they sink into the floor.
- **Use `map_to_local`/`local_to_map`.** A hand-rolled isometric transform
  mixed with the TileMapLayer's own produces half-tile offsets.
- **Fog of war via paired lit/dim tile layers**, not an overlay — an overlay
  cannot dim the full height of a wall block. Unexplored cells get no tile.
- **Control nodes eat board taps.** Every HUD container is
  `MOUSE_FILTER_IGNORE`; only buttons are `STOP`. A full-rect panel with the
  default filter makes the board silently unresponsive.
- **`await` on a signal that already fired never returns.** Guard for empty
  paths and null views before awaiting an animation, or the game hangs with no
  error.
- **`.tres` reference their script by path**, not uid, so content resources
  load without the class cache. The cache is still needed for `class_name`
  references in code.
- **A `.png` is not loadable until Godot has imported it.** Writing sprite files
  is not enough; `--headless --import` has to run before `ResourceLoader.exists`
  sees them, which is why `tools/import-assets.sh` does both.
- **Sprite keys come from `Entity.art_id`, not `id`** — the protagonist saves as
  `player_01` but its art is `entities/player.png`. Mismatching the two fails
  silently to the procedural fallback.
- **Export presets have project-setting prerequisites** and report them as an
  empty error list. Web needed `vram_texture_compression/for_mobile=false`;
  Android needed `rendering/textures/vram_compression/import_etc2_astc=true`.
- **Godot reads the Android SDK/JDK from editor settings, not the
  environment** — `tools/ci-android-editor-settings.sh` writes them in CI.

## Art pipeline

Procedural art is the shipping default, not a stub: `ArtLibrary` looks for
`assets/sprites/<key>.png` and falls back per sprite, so a half-finished art set
renders correctly. Keys are derived from enum names, so adding a prop or enemy
automatically adds its expected filename to `--status`.

## Design notes

- Bosses hold a guard post (`Entity.guard_radius`) near their stairwell rather
  than hunting the floor, so sneaking past is a real option.
- The protagonist's hit point pool is larger than the spec's example stat block
  (`Roster.BASE_HP`); at 12 hp a lone student dies to two hits from any
  D&D-scaled encounter.
- Balance is punishing by design. The simple policy in `simulate.gd` reaches
  floor 2 on average; it does not use cover, doors or positioning.

## Commits

Conventional Commits, always: `<type>(<scope>): <subject>`, lowercase subject,
no trailing period. `.github/workflows/pr-title.yml` enforces the same list on
PR titles: `feat` `fix` `docs` `refactor` `perf` `test` `build` `ci` `chore`
`revert` `style`.

Never force push. Change pushed commits with a follow-up commit.
