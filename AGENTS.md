# AGENTS.md

Guidance for coding agents working on Curriculum.

## Project Overview

A roguelike deckbuilder game set in a magical academy, built with Godot 4.7.1 and GDScript for mobile portrait (1080×1920). Ships to Web, Linux, and Android.

## Commands & Testing

Godot on PATH (or set `GODOT=...`):
- `./tools/check.sh` — Run the headless test suite (gate for CI). Checks script-class cache and runs ~25 suites (~3450 checks). Fails on assertions AND engine/script errors.
- `godot --path .` — Run game in editor / windowed.
- `./tools/shot.sh out.png` — Windowed run with screenshot capture.

## Architecture & Layout

- `scripts/core/` — Pure game logic (`RefCounted` only; **no scene tree, no Node**). Holds `Battle`, `Deck`, `Run`, `Grading`, `Draft`, `Catalog`, `Bestiary`, `Statuses`, `Combatant`. Fully headless testable.
- `scripts/data/` — Resource schemas (`CardData`, `EnemyData`, `CourseData`, `ContentLibrary`).
- `scripts/ui/` — Screens and widgets that replay core logic decisions.
- `scripts/view/` — Procedural art generation (`ArtFactory`) and lookup (`ArtLibrary`).
- `scripts/auto/` — Autoload singletons.
- `scripts/Main.gd` — Composition root: owns the `Run` and swaps active screens.
- `tests/` — Headless test harness (`TestCase.gd`, `run_tests.gd`, `test_*.gd`).

## Conventions

- Keep core game logic in `scripts/core/` independent of the scene tree.
- PR titles and commits must follow Conventional Commits with lowercase subjects.
- Ensure `./tools/check.sh` passes completely before submitting PRs.
