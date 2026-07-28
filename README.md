# Curriculum

A 2.5D isometric, turn-based tactical roguelike. You are one apprentice stuck in
a one-year time loop, fighting down through a procedurally generated arcane
academy to the cloister gate. Die and it is September again — you lose the gear,
you keep what you learned.

Built with Godot 4.7 and GDScript. Mobile-first: touch controls, tap-to-confirm
actions, thumb-sized buttons. No image assets — every texture and sprite is
painted at runtime.

## Play it

```sh
godot --path .                  # requires Godot 4.7+
```

Drag to pan, pinch or scroll to zoom. Tap a tile to preview the path, tap again
(or hit **Confirm**) to commit. Tap an enemy to see its effective AC before
attacking. Take the stairs to reach the next month.

In a browser, via the published image:

```sh
docker run --rm -p 8080:8080 ghcr.io/icco/curriculum:latest   # then open :8080
```

## How it works

**Combat** is D&D 5e-shaped: `d20 + ability modifier + proficiency` against AC,
natural 20 auto-hits and doubles the damage dice, natural 1 always misses.
Desks and chairs give half cover (+2 AC), lockers and bookshelves three-quarters
(+5). Spells either roll to hit, auto-hit, or force a save against
`DC 8 + proficiency + casting modifier`. Each turn gives you movement, an
action, a bonus action and a reaction — leaving an enemy's reach draws an
opportunity attack, in both directions.

**Floors** are NetHack-style: rectangular rooms (lecture_halls, labs, libraries,
gyms, locker bays) joined by one-tile hallways, furnished with cover and
lootable lockers, lit by Bresenham line-of-sight with the rest under fog.
A teacher guards each stairwell. They hold their post rather than chasing you
across the floor, so slipping past is a genuine option — one that costs you the
experience you would have earned.

**The loop** keeps two states. A run holds hit points, gear, consumables and the
current floor, and is thrown away when you die. The global state holds learned
spells, skill-tree nodes, permanent stat and spell-slot increases, and story
flags, and it never resets. Kills bank insight; insight buys nodes on the
between-loops screen. Twelve floors is one school year — get past the Principal
in August and the loop breaks.

**Content** lives in `resources/` as typed Resources — spells, enemies, loot and
skill nodes with enum fields, indexed by one `ContentLibrary`. Add a spell by
adding a `.tres` and listing it; nothing in the rules layer changes.

## Development

```sh
./tools/check.sh                                  # tests; run before committing
./tools/shot.sh /tmp/a.png 7 "wait:0.5,tap_far"   # drive the game, screenshot
godot --headless --path . --script tools/simulate.gd -- 12 6   # balance runs
./tools/import-assets.sh --status                 # what art is still missing
./tools/export-web.sh && docker build -t curriculum .          # browser build
```

`check.sh` refreshes Godot's script-class cache, runs the headless suite
(138 tests over dice, maps, generation, combat, turns, AI, camera, content
integrity, UI wiring, the asset pipeline, save/load and full twelve-floor
playthroughs) and fails on engine errors as well as
assertions. CI runs the same script, then exports Web, Linux and Android
builds; pushes to `main` publish a container image serving the web build.

See [AGENTS.md](AGENTS.md) for layout, conventions and the Godot-specific traps
this project ran into.

## Art

The game ships fully playable with procedural art — every texture and sprite is
painted at runtime. Illustrated art is optional and drops in per sprite: put a
file in `assets/source/`, run `./tools/import-assets.sh`, and that one sprite
switches over while everything else stays procedural.

Art is generated through the Recraft API from
[`assets/prompts/manifest.json`](assets/prompts/manifest.json) — see
[`assets/prompts/recraft.md`](assets/prompts/recraft.md) for the pipeline. Floor
tiles come from flat top-down textures that `tools/make_tile.gd` projects onto
the 2:1 diamond, so the grid geometry is derived rather than drawn; everything
else is generated as a cutout with an alpha channel.

## Deviations from the original spec

- **Hit points.** The spec's example stat block gives the protagonist 12 hp. A
  lone student dies to two hits from any D&D-scaled encounter at that value, so
  the base pool is larger (`Roster.BASE_HP`) and grows with in-run levels.
- **In-run levelling** is not in the spec, but the game needs it: enemies scale
  per floor and otherwise the player never does.
- **Spec section 4 is truncated mid-JSON.** The enemy, spell, loot and
  skill-tree schemas in `data/` were filled in by analogy to the player schema.
