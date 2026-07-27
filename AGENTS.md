# Working in this repo

## Commits and PR titles

Conventional Commits, always. `<type>(<optional scope>): <subject>` with a
lowercase subject and no trailing period. Allowed types — keep in sync with
`.github/workflows/pr-title.yml`, which enforces the same list on PR titles:

`feat` `fix` `docs` `refactor` `perf` `test` `build` `ci` `chore` `revert` `style`

```
feat(combat): add opportunity attacks when leaving a hostile's reach
fix(mapgen): recompute reachability after installing lockers
```

Never force push. Once a commit is pushed, change it with a follow-up commit.

## Verifying a change

`./tools/check.sh` is the gate: it refreshes Godot's script-class cache, runs
the headless suite, and fails on engine errors as well as failed assertions.
Run it before every commit. CI runs the same script.

`class_name` globals only resolve once the class cache exists, which is why the
import step comes first — a fresh clone will not run the tests without it.

`./tools/shot.sh <out.png> [seed] [script] [delay]` launches the game windowed,
optionally drives it through a scripted sequence, screenshots and quits. Use it
to check anything visual.

## Layout

| Path | What lives there |
| --- | --- |
| `scripts/core/` | Rules and simulation. No scene nodes, no rendering. |
| `scripts/view/` | Isometric rendering, sprites, camera. |
| `scripts/ui/` | HUD and screens. |
| `data/` | JSON content: spells, enemies, loot, skill tree. |
| `tests/` | Headless suites, one `test_*.gd` per area. |
| `tools/` | Dev and CI scripts. |

Rules code returns arrays of event dictionaries (`{"type": ..., "text": ...}`)
rather than touching the scene. The presentation layer replays those events, so
the same code path is exercised by tests and by the game.

Keep `scripts/core/` free of `scripts/view/` references, and avoid mutual typed
references between core classes — GDScript treats those as cyclic and refuses to
parse them.
