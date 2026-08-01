# Curriculum

A roguelike deckbuilder set in a dangerous magical academy.

> The only way to learn is by playing. The only way to win is by learning.

You enrol in courses, sit their examinations as one-on-one card battles, and are
graded S through F on how fast, how safe, how much you learned and how much you
discovered. Your grade decides how much of the defeated examiner's deck you may copy
into your own. Cards gain XP as you play them and evolve mid-battle through five
levels. A second F is expulsion — that is the only death condition.

Godot 4.7.1, GDScript, mobile portrait (1080×1920). Ships to Web, Linux and Android.

---

## Running it

```sh
godot --path .                 # play it
./tools/shot.sh out.png        # windowed run + screenshot (see "Looking at it")
```

Godot is expected on `PATH`. Every script honours a `GODOT` environment variable if
yours lives elsewhere:

```sh
GODOT=~/godot-bin/godot ./tools/check.sh
```

## Tests

`tools/check.sh` is the gate, and it is what CI runs. It refreshes Godot's
script-class cache, runs the headless suite, and fails on engine errors as well as on
failed assertions — Godot will happily exit 0 while printing `SCRIPT ERROR` every
frame, so the exit code alone proves nothing.

```sh
./tools/check.sh                      # 25 suites, ~3450 checks
```

The suite is a small hand-rolled harness (`tests/TestCase.gd`, `tests/run_tests.gd`)
rather than a dependency like GUT — no plugin to install. Each `tests/test_*.gd` is
one suite; `run_tests.gd` discovers them.

Because `scripts/core` is pure `RefCounted` logic that returns event dictionaries and
never touches the scene tree, nearly all of the game — including whole simulated
playthroughs — is testable headlessly.

## Layout

```
scripts/core/     Pure game logic. No scene tree, no Node. Battle, Deck, Run,
                  Grading, Draft, Catalog, Bestiary, Statuses, Combatant.
scripts/data/     Resource schemas: CardData, EnemyData, CourseData, ContentLibrary.
scripts/ui/       Screens and widgets. Replays what core already decided.
scripts/view/     Procedural art generation (ArtFactory) and lookup (ArtLibrary).
scripts/auto/     Autoload singletons.
scripts/Main.gd   Composition root: owns the Run, swaps screens.

scenes/Main.tscn  The only scene. Every screen is built in code.
resources/        Generated .tres content — see "Content" below.
tools/            Content generation, balance simulation, CI helpers.
tests/            Headless suite.
docs/             Design spec, implementation plan, and the audit.
```

The rule the layering enforces: `scripts/core` never imports from `scripts/ui`.
`Battle` returns an array of event dictionaries and `BattleScreen` replays them. A
screen never computes a rule.

## Content

All game content is generated into `resources/` by scripts, not hand-authored as
`.tres`. Editing a card means editing the table in `tools/generate_content.gd` and
re-running it.

**Order matters** — courses reference enemies, which reference cards:

```sh
godot --headless --path . --script tools/generate_content.gd   # 120 cards
godot --headless --path . --script tools/generate_enemies.gd   #   9 examiners
godot --headless --path . --script tools/generate_courses.gd   #  15 courses
```

Each writes its own `.tres` files and updates `resources/content_library.tres`, the
single index the game loads. `generate_courses.gd` also runs `Catalog.validate()` and
exits non-zero if the syllabus graph is unsound (for example, an honors course gating
a required one, which two-F permadeath would make unwinnable).

Only the five card names and the level 1–2 stat lines are hand-authored; levels 3–5
are derived. There is no art to import — `scripts/view/ArtFactory.gd` paints every
card face, examiner figure and sigil procedurally, so the game renders complete with
no image assets in the repo.

`tools/generate_theme.gd` regenerates `resources/ui_theme.tres`.

## Balance

Two headless harnesses. Neither is part of the CI gate; both are seeded, so runs are
reproducible.

```sh
godot --headless --path . --script tools/simulate.gd     -- 100
godot --headless --path . --script tools/policy_probe.gd -- 60
```

`simulate.gd` plays N runs with a greedy bot and reports graduations, the grade
distribution, and a per-course table: attempts, loss rate, and the hit points the
player walks in and out with. Since hit points carry between courses, *where* a run
dies matters much less than what it arrived with — a course losing 60% of its
attempts but only ever entered at 20 hp is a symptom of the two courses before it.

`policy_probe.gd` plays the same runs under several deliberately different policies
(never defend, waste your mana, only defend, throw a fight to bank the F's full heal)
and compares them. It answers a different question: *does playing well matter?* If a
policy that throws away a real resource scores the same as the greedy one, that
resource is not a decision.

A policy that never actually engages will report a near-greedy score and read as a
cleared exploit, so check any divergence counter it prints before trusting a null
result.

The single global difficulty dial is `Grading._RECOVERY` — how much passing a course
heals. It moves every course at once, where an examiner's stats move one or two.

## Looking at it

`--headless` does not render, so a headless screenshot comes back blank. Use:

```sh
./tools/shot.sh out.png [seed] [screen]      # screen: catalog | battle | bestiary
```

It launches windowed at 540×960, screenshots, and quits — failing if the engine
printed any script errors on the way.

## Exports

Presets are named `Web`, `Linux` and `Android` in `export_presets.cfg`; CI builds all
three on every push and uploads them as artifacts.

```sh
./tools/export-web.sh [--release]      # -> build/web
```

`Dockerfile` and `docker/` serve `build/web` on `:8080` with a `/healthz` endpoint.
Releases publish the web build to GitHub Pages, so the Web preset must work from a
non-root subpath.

## Docs

- [`docs/superpowers/specs/2026-07-31-curriculum-deckbuilder-design.md`](docs/superpowers/specs/2026-07-31-curriculum-deckbuilder-design.md)
  — the design spec: mechanics, schools, grading formulas, the full syllabus, art
  direction. The authority on intent.
- [`docs/audit-2026-08-01.md`](docs/audit-2026-08-01.md) — audit of Godot practice
  and gameplay, with measurements. Start here for known problems and where the game
  has drifted from the spec.
- [`docs/superpowers/plans/2026-07-31-curriculum-deckbuilder.md`](docs/superpowers/plans/2026-07-31-curriculum-deckbuilder.md)
  — the implementation plan the build followed.
