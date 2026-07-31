# Curriculum Roguelike Deckbuilder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the isometric tactical roguelike in this repo with Curriculum, a mobile-portrait roguelike deckbuilder in which cards gain XP and evolve as you play them, examiners hide school weaknesses you must discover, and your grade decides how much of a defeated examiner's deck you may copy.

**Architecture:** All rules live in `scripts/core/` as plain `RefCounted` classes that take their inputs as arguments and return arrays of event dictionaries; nothing in core touches the scene tree, so every rule is exercisable headlessly. Three autoloads exist under the names the brief asks for but hold only the current instance and forward to it. Content is typed `Resource` `.tres` files indexed by one `ContentLibrary`. The UI layer replays core's event arrays as animation.

**Tech Stack:** Godot 4.7.1, GDScript. No external dependencies. Art generated through the Recraft HTTP API by a standalone Python 3 script. CI is the existing GitHub Actions workflows, unmodified.

**Spec:** [`docs/superpowers/specs/2026-07-31-curriculum-deckbuilder-design.md`](../specs/2026-07-31-curriculum-deckbuilder-design.md). Read it before Task 1. Where this plan and the spec disagree, the spec wins — report the discrepancy rather than guessing.

## Global Constraints

Every task's requirements implicitly include this section.

- **Engine:** Godot **4.7.1**. `project.godot` declares `config/features=PackedStringArray("4.7", "Mobile")`.
- **Resolution:** portrait **1080×1920**, `window/handheld/orientation="portrait"`, `stretch/mode="canvas_items"`, `stretch/aspect="expand"`.
- **Renderer:** `renderer/rendering_method="mobile"`, `renderer/rendering_method.mobile="gl_compatibility"`.
- **`scripts/core/` must not reference `scripts/ui/` or `scripts/view/`.** Core classes must not hold mutual typed references to each other — GDScript treats those as cyclic and refuses to parse. Where two core classes must know each other, one takes the other as an untyped parameter.
- **Card XP never touches `CardData`.** XP lives on a run-scoped `CardInstance`. Writing XP to a `.tres` leaks progress across runs and across copies; this is the single easiest defect to introduce invisibly.
- **The gate is `./tools/check.sh`.** It must pass before every commit. It fails on failed assertions **and** on `SCRIPT ERROR` / `Parse Error` appearing in output, because Godot exits 0 while printing script errors every frame.
- **A fresh clone cannot run tests** until `godot --headless --import` has built `.godot/global_script_class_cache.cfg`; without it every `class_name` reference reports "not declared in the current scope". `check.sh` does this first.
- **`.tres` files reference their script by `path`, not `uid`,** so content loads without the class cache.
- **Commits:** Conventional Commits, `<type>(<scope>): <subject>`, lowercase subject, no trailing period. `.github/workflows/pr-title.yml` enforces the same types on the PR title: `feat` `fix` `docs` `refactor` `perf` `test` `build` `ci` `chore` `revert` `style`.
- **Never force push.** Change pushed commits with a follow-up commit.
- **Palette (exact hex, from the reference's own PNG palette chunk):** paper `#F7EADD`, black `#000000`, Cinder `#D45C3C`, Ward/saffron `#E0A51F`, Frost/blue `#498BAD`, pale slate `#A3B0AC`, grain greys `#999189` `#6C6661`, Rot/moss `#6E7B3F`.
- **The UI is light, not dark.** `default_clear_color` is the paper colour. This is a deliberate inversion of the brief's "dark fantasy parchment"; do not "fix" it.
- **Branch:** all work lands on `docs/deckbuilder-spec`'s successor branch `feat/deckbuilder`, as a PR against `main`.

---

## File Structure

Created over the course of the plan. Each file has one responsibility.

### Rules — `scripts/core/`, pure logic, no scene nodes

| File | Responsibility |
| --- | --- |
| `Schools.gd` | The `School` enum and its display names/colours. Depended on by everything; depends on nothing. |
| `CardInstance.gd` | One card in a run: a `CardData` pointer plus its own XP. Owns evolution. |
| `Deck.gd` | Draw pile, hand, discard, exhaust. Draw, discard, reshuffle, end-of-turn. |
| `Statuses.gd` | The five statuses as a value object: apply, tick, consume, query. |
| `Combatant.gd` | HP, block, mana, statuses — the shared shape of player and examiner. |
| `Battle.gd` | Turn resolution. Returns event arrays. Owns the school multiplier lookup. |
| `Bestiary.gd` | Which examiner weaknesses/wards are known this run. |
| `Grading.gd` | The four score terms, the total, and the letter thresholds. |
| `Draft.gd` | Registration: the pool, grade gating, the cap, and cutting. |
| `Catalog.gd` | Course availability, prerequisites, honors reveal. |
| `Run.gd` | Run state: HP, deck, cap, strikes, grades, bestiary, position. Owns expulsion. |
| `SaveGame.gd` | Serialise/deserialise a `Run` to and from `user://`. |

### Content — `scripts/data/`, typed `Resource` classes

| File | Responsibility |
| --- | --- |
| `CardData.gd` | Static card definition, including `evolved_card`. |
| `EnemyData.gd` | Examiner definition: HP, mana, deck, weak/warded school. |
| `CourseData.gd` | Course definition: tier, prerequisites, examiner, pars, syllabus card. |
| `ContentLibrary.gd` | One indexed entry point to every card, examiner and course. |

### Autoloads — `scripts/auto/`, thin

| File | Responsibility |
| --- | --- |
| `GameManager.gd` | Holds the current `Run`; forwards. |
| `DeckManager.gd` | Holds the current `Deck`; forwards. |
| `GradeManager.gd` | Stateless; calls `Grading`. |

### Presentation — `scripts/ui/` and `scripts/view/`

| File | Responsibility |
| --- | --- |
| `view/ArtLibrary.gd` | Sprite lookup with per-key procedural fallback. |
| `view/ArtFactory.gd` | Paints the procedural fallbacks (card frames, sigils, figures). |
| `ui/UIKit.gd` | Shared widget constructors so screens stay declarative. |
| `ui/CardView.gd` | One card: art, name, cost, school, XP ticks. Drag to play. |
| `ui/HandFan.gd` | Curved fan layout and hit ordering for the hand. |
| `ui/BattleScreen.gd` | The battle: examiner, intent, player bars, hand, event replay. |
| `ui/ReportCard.gd` | Post-battle score breakdown and letter grade. |
| `ui/RegistrationScreen.gd` | The draft: pool, cap counter, cut/keep. |
| `ui/CourseCatalog.gd` | The map: nodes, `Line2D` prerequisite edges, availability. |
| `ui/BestiaryScreen.gd` | Known weaknesses and wards. |
| `ui/MainMenu.gd`, `ui/GameOver.gd` | Entry and expulsion. |
| `scripts/Main.gd` | Composition root. Owns the `Run` and swaps screens. |

### Tests — `tests/`

`TestCase.gd` (base), `run_tests.gd` (runner), and one `test_*.gd` per area: `deck`, `evolution`, `battle`, `schools`, `grading`, `draft`, `catalog`, `run`, `save`, `content`, `ui`, `art`, `playthrough`.

### Tooling — `tools/`

`check.sh` (the gate), `ci-install-godot.sh`, `export-web.sh`, `ci-android-editor-settings.sh`, `shot.sh`, `simulate.gd`, `recraft.py`, `import-assets.sh`, `import_assets.gd`, `generate_theme.gd`.

---

## Phase 0 — Reset and foundation

### Task 1: Reset the repo and stand up a testable Godot project

Nothing else in this plan can be verified until `./tools/check.sh` runs. This task deletes the old game and produces the smallest project where a test can fail and pass.

**Files:**
- Delete: `scripts/`, `scenes/`, `resources/`, `tests/`, `tools/`, `assets/source/`, `assets/sprites/`, `assets/prompts/init-prompt.md`, `assets/prompts/manifest.json`, `assets/prompts/recraft.md`, `assets/prompts/README.md`, `project.godot`, `Dockerfile`, `docker/`, `export_presets.cfg`, `icon.svg`, `icon.svg.import`, `AGENTS.md`, `README.md`
- Keep untouched: `.github/`, `.gitignore`, `.yamllint.yml`, `assets/prompts/init.md`, `docs/`
- Create: `project.godot`, `icon.svg`, `tests/TestCase.gd`, `tests/run_tests.gd`, `tests/test_schools.gd`, `scripts/core/Schools.gd`, `tools/check.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `Schools.School` enum with values `CINDER`, `FROST`, `INK`, `ROT`, `WARD`; `Schools.display_name(school: School) -> String`; `Schools.colour(school: School) -> Color`; `Schools.ALL: Array[School]`. `TestCase` base class with `check(condition: bool, message: String)`, `eq(actual, expected, message := "")`, `neq`, `almost(actual: float, expected: float, message := "")`, and `var failures: Array[String]`, `var checks: int`, `func suite_name() -> String`, `func run() -> void`. `tests/run_tests.gd` auto-discovers and runs every `tests/test_*.gd`, so a new suite needs no registration and concurrent branches never collide on a shared constant.

- [ ] **Step 1: Create the branch**

```bash
git checkout main
git pull --ff-only
git checkout -b feat/deckbuilder
git merge --no-ff --no-edit docs/deckbuilder-spec -m "docs: bring the deckbuilder spec onto the feature branch"
```

- [ ] **Step 2: Delete the old game**

Look at what you are about to remove first — `git rm -r` on the wrong path is the one irreversible step in this plan.

```bash
git rm -r -q scripts scenes resources tests tools docker
git rm -r -q assets/source assets/sprites
git rm -q assets/prompts/init-prompt.md assets/prompts/manifest.json \
            assets/prompts/recraft.md assets/prompts/README.md
git rm -q project.godot Dockerfile export_presets.cfg icon.svg icon.svg.import \
            AGENTS.md README.md
rm -rf .godot
git status --short
```

Expected: only deletions, plus the untouched `.github/`, `.gitignore`, `.yamllint.yml`, `assets/prompts/init.md`, `docs/`.

- [ ] **Step 3: Write `project.godot`**

```ini
; Engine configuration file.
config_version=5

[application]

config/name="Curriculum"
config/description="A roguelike deckbuilder set in a dangerous magical academy."
config/features=PackedStringArray("4.7", "Mobile")
config/icon="res://icon.svg"
boot_splash/show_image=false

[display]

window/size/viewport_width=1080
window/size/viewport_height=1920
window/handheld/orientation="portrait"
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[input_devices]

pointing/emulate_touch_from_mouse=true

[rendering]

renderer/rendering_method="mobile"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
textures/vram_compression/import_etc2_astc=true
environment/defaults/default_clear_color=Color(0.969, 0.918, 0.867, 1)
```

**`run/main_scene` is deliberately absent until Task 24 creates `scenes/Main.tscn`.** Declaring a scene that does not exist makes `--import` emit `Failed loading resource`, which `check.sh` treats as a failure — correctly, since the project would be lying about its entry point. Task 24 adds the key back. Do not create a placeholder scene instead.

`default_clear_color` is `#F7EADD` in linear floats. Keep it light.

- [ ] **Step 4: Write `icon.svg`**

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" fill="#F7EADD"/>
  <rect x="30" y="18" width="68" height="92" rx="6" fill="#498BAD"/>
  <circle cx="64" cy="52" r="18" fill="#E0A51F"/>
  <path d="M40 88h48v8H40z" fill="#000000"/>
</svg>
```

- [ ] **Step 5: Write `scripts/core/Schools.gd`**

```gdscript
class_name Schools
extends RefCounted

## The five schools of magic. Cards belong to exactly one; examiner weaknesses and
## wards resolve against them.
enum School { CINDER, FROST, INK, ROT, WARD }

const ALL: Array[School] = [School.CINDER, School.FROST, School.INK, School.ROT, School.WARD]

const _NAMES := {
	School.CINDER: "Cinder",
	School.FROST: "Frost",
	School.INK: "Ink",
	School.ROT: "Rot",
	School.WARD: "Ward",
}

const _COLOURS := {
	School.CINDER: Color("#D45C3C"),
	School.FROST: Color("#498BAD"),
	School.INK: Color("#000000"),
	School.ROT: Color("#6E7B3F"),
	School.WARD: Color("#E0A51F"),
}


static func display_name(school: School) -> String:
	return _NAMES.get(school, "?")


static func colour(school: School) -> Color:
	return _COLOURS.get(school, Color.MAGENTA)
```

- [ ] **Step 6: Write `tests/TestCase.gd`**

```gdscript
class_name TestCase
extends RefCounted

## Base for every suite. A suite overrides suite_name() and run(), and records
## outcomes through check()/eq() rather than asserting, so one failure does not
## hide the rest of the suite.

var failures: Array[String] = []
var checks := 0


func suite_name() -> String:
	return "unnamed"


func run() -> void:
	pass


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func eq(actual, expected, message := "") -> void:
	checks += 1
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])


func neq(actual, unexpected, message := "") -> void:
	checks += 1
	if actual == unexpected:
		failures.append("%s: expected anything but %s" % [message, unexpected])


func almost(actual: float, expected: float, message := "") -> void:
	checks += 1
	if absf(actual - expected) > 0.001:
		failures.append("%s: expected %f, got %f" % [message, expected, actual])
```

- [ ] **Step 7: Write `tests/run_tests.gd`**

A `SceneTree` script's `_init()` has no tree — `Engine.get_main_loop()` is null and nothing that needs the tree works. Run from `_process()` instead, and return `true` to quit.

```gdscript
extends SceneTree

## Headless suite runner. Discovers every tests/test_*.gd automatically — there is no
## list to keep in step, so a new suite cannot be silently left unregistered, and
## parallel branches adding suites never collide on a shared constant.
##
## A SceneTree script's _init() has no tree — Engine.get_main_loop() is null and the
## root window is not live — so everything runs from _process(), which quits by
## returning true.

const TESTS_DIR := "res://tests"


func _discover() -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		printerr("FAIL  cannot open %s" % TESTS_DIR)
		return found
	for file in dir.get_files():
		# .gd in a source checkout, .gdc once exported.
		var name := file.trim_suffix(".remap").trim_suffix("c")
		if name.begins_with("test_") and name.ends_with(".gd"):
			found.append("%s/%s" % [TESTS_DIR, name])
	found.sort()
	return found


func _process(_delta: float) -> bool:
	var suites := _discover()
	if suites.is_empty():
		printerr("FAIL  no test suites found in %s" % TESTS_DIR)
		quit(1)
		return true

	var total_checks := 0
	var total_failures := 0

	for path in suites:
		var script: GDScript = load(path)
		if script == null:
			printerr("FAIL  could not load suite %s" % path)
			total_failures += 1
			continue
		var suite: TestCase = script.new()
		suite.run()
		total_checks += suite.checks
		for failure in suite.failures:
			printerr("FAIL  %s: %s" % [suite.suite_name(), failure])
			total_failures += 1
		print(
			"  %-16s %d checks, %d failures"
			% [suite.suite_name(), suite.checks, suite.failures.size()]
		)

	print("%d suites, %d checks, %d failures" % [suites.size(), total_checks, total_failures])
	quit(1 if total_failures > 0 else 0)
	return true
```

- [ ] **Step 8: Write the failing test `tests/test_schools.gd`**

```gdscript
extends TestCase


func suite_name() -> String:
	return "schools"


func run() -> void:
	eq(Schools.ALL.size(), 5, "five schools")
	eq(Schools.display_name(Schools.School.ROT), "Rot", "rot name")
	eq(Schools.colour(Schools.School.CINDER), Color("#D45C3C"), "cinder ink")
	# Every school has a distinct name and colour, or the UI cannot tell them apart.
	var names := {}
	var colours := {}
	for school in Schools.ALL:
		names[Schools.display_name(school)] = true
		colours[Schools.colour(school)] = true
	eq(names.size(), 5, "distinct names")
	eq(colours.size(), 5, "distinct colours")
```

- [ ] **Step 9: Write `tools/check.sh`**

```bash
#!/usr/bin/env bash
# The gate. Refreshes Godot's script-class cache, runs the headless suite, and
# fails on engine errors as well as on failed assertions — Godot exits 0 while
# printing SCRIPT ERROR every frame, so the exit code alone proves nothing.
set -uo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "check: godot not found (set \$GODOT)" >&2
  exit 127
fi

# class_name globals are unresolvable until this has built
# .godot/global_script_class_cache.cfg at least once.
#
# The import output is checked, not discarded: Tasks 16-18 generate 72 .tres files, and a
# bad ext_resource path or an unparseable typed array is reported HERE. Swallowing it
# turns a broken resource into a null load and an assertion failure somewhere unrelated.
#
# Note the limit of this check: --import scans assets but does not eagerly load an
# unreferenced .tres, so an orphaned broken resource slips past it. test_content walks
# resources/ for exactly that reason.
import_output=$("$GODOT" --headless --import --path . 2>&1)
if grep -qE 'ERROR|Parse Error|Failed loading|Failed to load' <<<"$import_output"; then
  echo "$import_output" >&2
  echo "check: import reported errors" >&2
  exit 1
fi

output=$("$GODOT" --headless --path . --script tests/run_tests.gd 2>&1)
status=$?
echo "$output"

if grep -qE 'SCRIPT ERROR|Parse Error|Cannot open file|not declared in the current scope' <<<"$output"; then
  echo "check: engine reported script errors" >&2
  exit 1
fi

exit "$status"
```

- [ ] **Step 10: Run the test and watch it fail**

```bash
chmod +x tools/check.sh
./tools/check.sh
```

Expected: PASS. `check.sh` builds the class cache before running the suite, so a cold clone passes first time. Then prove the gate is not vacuous, which matters more than the green tick:

```bash
# A failed assertion must exit non-zero.
sed -i.bak 's/Schools.ALL.size(), 5/Schools.ALL.size(), 99/' tests/test_schools.gd
./tools/check.sh; echo "exit=$?"   # expect a FAIL line and exit=1
mv tests/test_schools.gd.bak tests/test_schools.gd

# A script error must also exit non-zero, even though Godot exits 0 while printing it.
printf '\nfunc broken() -> void:\n\tthis_is_not_a_function()\n' >> scripts/core/Schools.gd
./tools/check.sh >/dev/null 2>&1; echo "exit=$?"   # expect exit=1
# restore Schools.gd by removing the appended function before continuing
```

- [ ] **Step 11: Run the test and watch it pass**

```bash
./tools/check.sh
```

Expected: `schools 5 checks, 0 failures`, then `5 checks, 0 failures`, exit 0.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "feat: reset to a portrait godot project with a headless test gate"
```

---

### Task 2: Recreate the contracts the retained CI workflows call

`.github/` is kept unmodified and already calls five scripts that no longer exist. Until this task lands, CI fails on every push. Read `.github/workflows/ci.yml`, `docker.yml` and `release.yml` and match what they invoke exactly.

**Files:**
- Create: `tools/ci-install-godot.sh`, `tools/export-web.sh`, `tools/ci-android-editor-settings.sh`, `tools/shot.sh`, `export_presets.cfg`, `Dockerfile`, `docker/nginx.conf`, `docker/entrypoint.sh`
- Test: `tests/test_tooling.gd`

**Interfaces:**
- Consumes: `tools/check.sh` from Task 1.
- Produces: an `export_presets.cfg` with presets named exactly `Web`, `Linux`, `Android`; a Linux export named `curriculum.x86_64`; a container serving `build/web` on `:8080` with `/healthz`.

- [ ] **Step 1: Write the failing test `tests/test_tooling.gd`**

The contracts are shell and config, so the test asserts they exist and declare what CI expects. This catches a renamed preset, which otherwise surfaces as an export failure with an empty error list.

```gdscript
extends TestCase

## CI calls these by name. A missing script or a renamed export preset breaks the
## workflows in .github/, which this repo keeps unmodified.


func suite_name() -> String:
	return "tooling"


func _text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


func run() -> void:
	for script in [
		"res://tools/check.sh",
		"res://tools/ci-install-godot.sh",
		"res://tools/export-web.sh",
		"res://tools/ci-android-editor-settings.sh",
		"res://tools/shot.sh",
	]:
		check(FileAccess.file_exists(script), "%s exists" % script)

	var presets := _text("res://export_presets.cfg")
	for preset in ["Web", "Linux", "Android"]:
		check(presets.contains('name="%s"' % preset), "preset %s declared" % preset)
	# release.yml hardcodes this filename.
	check(presets.contains("curriculum.x86_64"), "linux binary named curriculum.x86_64")
	# Web export refuses to build without this, reporting an empty error list.
	check(
		presets.contains("vram_texture_compression/for_mobile=false"),
		"web preset disables mobile vram compression"
	)

	check(FileAccess.file_exists("res://Dockerfile"), "Dockerfile exists")
	check(_text("res://docker/nginx.conf").contains("healthz"), "nginx serves /healthz")
	check(_text("res://docker/nginx.conf").contains("application/wasm"), "nginx types wasm")
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers the new suite automatically. Then:

```bash
./tools/check.sh
```

Expected: FAIL — 9 or more failures naming the missing scripts and presets.

- [ ] **Step 3: Write `tools/ci-install-godot.sh`**

```bash
#!/usr/bin/env bash
# Installs Godot to ~/godot-bin/godot for CI. With --with-templates, also installs
# the export templates the Web/Linux/Android presets need.
set -euo pipefail

VERSION="${GODOT_VERSION:-4.7.1}"
WITH_TEMPLATES="${1:-}"
BASE="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"
DEST="$HOME/godot-bin"

mkdir -p "$DEST"
cd "$(mktemp -d)"

curl -fsSLO "$BASE/Godot_v${VERSION}-stable_linux.x86_64.zip"
unzip -q "Godot_v${VERSION}-stable_linux.x86_64.zip"
mv "Godot_v${VERSION}-stable_linux.x86_64" "$DEST/godot"
chmod +x "$DEST/godot"

if [ "$WITH_TEMPLATES" = "--with-templates" ]; then
  curl -fsSLO "$BASE/Godot_v${VERSION}-stable_export_templates.tpz"
  TEMPLATES="$HOME/.local/share/godot/export_templates/${VERSION}.stable"
  mkdir -p "$TEMPLATES"
  unzip -q "Godot_v${VERSION}-stable_export_templates.tpz"
  mv templates/* "$TEMPLATES/"
fi

"$DEST/godot" --version
```

- [ ] **Step 4: Write `export_presets.cfg`**

The Web preset needs `vram_texture_compression/for_mobile=false` or the export fails while reporting an empty error list. Android needs `import_etc2_astc=true`, already set in `project.godot`.

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
exclude_filter="assets/prompts/*, docs/*"
export_path="build/web/index.html"

[preset.0.options]

vram_texture_compression/for_desktop=false
vram_texture_compression/for_mobile=false
html/export_icon=true
progressive_web_app/enabled=false

[preset.1]

name="Linux"
platform="Linux"
runnable=true
export_filter="all_resources"
exclude_filter="assets/prompts/*, docs/*"
export_path="build/linux/curriculum.x86_64"

[preset.1.options]

binary_format/architecture="x86_64"
binary_format/embed_pck=true

[preset.2]

name="Android"
platform="Android"
runnable=true
export_filter="all_resources"
exclude_filter="assets/prompts/*, docs/*"
export_path="build/android/curriculum.apk"

[preset.2.options]

architectures/arm64-v8a=true
architectures/armeabi-v7a=false
screen/immersive_mode=true
screen/orientation=1
package/name="Curriculum"
package/unique_name="ai.laurel.curriculum"
```

`screen/orientation=1` is portrait.

- [ ] **Step 5: Write `tools/export-web.sh`**

```bash
#!/usr/bin/env bash
# Produces build/web, which the Docker image serves. --release exports release.
set -euo pipefail

GODOT="${GODOT:-godot}"
MODE="--export-debug"
[ "${1:-}" = "--release" ] && MODE="--export-release"

cd "$(dirname "$0")/.."
"$GODOT" --headless --import --path . 2>&1 | tail -3
mkdir -p build/web
"$GODOT" --headless --path . "$MODE" Web build/web/index.html
test -s build/web/index.html
test -s build/web/index.wasm
echo "exported build/web"
```

- [ ] **Step 6: Write `tools/ci-android-editor-settings.sh`**

Godot reads the Android SDK and JDK from editor settings, not from the environment, so CI has to write them into the settings file before exporting.

```bash
#!/usr/bin/env bash
# Points Godot at the Android SDK and JDK. Godot reads these from editor settings,
# not from $ANDROID_HOME, so an exported APK fails without this.
set -euo pipefail

SETTINGS_DIR="$HOME/.config/godot"
mkdir -p "$SETTINGS_DIR"
SETTINGS="$SETTINGS_DIR/editor_settings-4.tres"

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
JDK="${JAVA_HOME:-/usr/lib/jvm/temurin-17-jdk-amd64}"

cat > "$SETTINGS" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JDK"
EOF

echo "wrote $SETTINGS (sdk=$SDK jdk=$JDK)"
```

- [ ] **Step 7: Write `docker/nginx.conf`, `docker/entrypoint.sh` and `Dockerfile`**

`docker/nginx.conf`:

```nginx
worker_processes 1;
events { worker_connections 128; }

http {
  include /etc/nginx/mime.types;
  # Godot's Web export is a .wasm; the wrong Content-Type stops it instantiating.
  types { application/wasm wasm; }
  default_type application/octet-stream;
  sendfile on;
  gzip on;
  gzip_types application/javascript application/wasm text/html application/json;

  server {
    listen 8080;
    root /srv/web;
    index index.html;

    location = /healthz {
      access_log off;
      add_header Content-Type text/plain;
      return 200 "ok\n";
    }

    location / {
      try_files $uri $uri/ /index.html;
    }
  }
}
```

`docker/entrypoint.sh`:

```bash
#!/bin/sh
set -eu
test -s /srv/web/index.html || { echo "no web build at /srv/web" >&2; exit 1; }
exec nginx -g 'daemon off;'
```

`Dockerfile`:

```dockerfile
# Serves the Godot Web export produced by tools/export-web.sh. The build is made
# outside the image (docker.yml exports it once and shares the artifact), so this
# image only serves.
FROM nginx:1.27-alpine

COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/entrypoint.sh /entrypoint.sh
COPY build/web /srv/web

RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
```

- [ ] **Step 8: Write `tools/shot.sh`**

`--headless` does not render — `get_viewport().get_texture()` comes back blank. Screenshots need a real windowed run, an `await RenderingServer.frame_post_draw`, and a self-quit or the process hangs.

```bash
#!/usr/bin/env bash
# Launches the game windowed, screenshots it, quits. The only way to check
# anything visual: --headless does not render, so a headless screenshot is blank.
#   ./tools/shot.sh /tmp/a.png [seed] [screen]
set -euo pipefail

GODOT="${GODOT:-godot}"
OUT="${1:?usage: shot.sh <out.png> [seed] [screen]}"
SEED="${2:-0}"
SCREEN="${3:-}"

cd "$(dirname "$0")/.."
"$GODOT" --headless --import --path . >/dev/null 2>&1

output=$("$GODOT" --path . --resolution 540x960 \
  -- --shot "$OUT" --seed "$SEED" --screen "$SCREEN" 2>&1)
echo "$output"

if grep -qE 'SCRIPT ERROR|Parse Error' <<<"$output"; then
  echo "shot: engine reported script errors" >&2
  exit 1
fi
test -s "$OUT" || { echo "shot: no image written to $OUT" >&2; exit 1; }
echo "wrote $OUT"
```

The `--shot`/`--seed`/`--screen` arguments are consumed by `Main.gd` in Task 24. Until then `shot.sh` exists to satisfy the contract and will report no image; that is expected and is why `test_tooling` only checks for the file.

- [ ] **Step 9: Run the tests and watch them pass**

```bash
chmod +x tools/*.sh docker/entrypoint.sh
./tools/check.sh
```

Expected: PASS, including `tooling`.

- [ ] **Step 10: Verify the web export and container really build**

The test only reads config; this proves the presets work. Takes a few minutes on first run.

```bash
./tools/export-web.sh
docker build -t curriculum:local .
docker run -d --name curriculum-local -p 8080:8080 curriculum:local
sleep 3
curl -fsS http://127.0.0.1:8080/healthz
curl -fsSI http://127.0.0.1:8080/index.wasm | grep -i 'content-type: application/wasm'
docker rm -f curriculum-local
```

Expected: `ok`, then a matching `content-type: application/wasm` line. If the export fails with an empty error list, a required project setting is missing — check `vram_texture_compression/for_mobile`.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "build: recreate the export presets, docker image and ci scripts"
```

---

## Clarification: the examiner's turn

The spec says examiners "draw and play from their own deck under the same mana rules"
and that the intent is "the card it drew". Those two sentences do not fully determine
a turn structure, so this plan fixes one:

> **An examiner plays exactly one card per turn, chosen as the highest-cost card in its
> hand affordable with `mana_per_turn`, and revealed as intent at the end of the
> player's turn.**

One card per turn keeps the intent honest — the player is never hit by damage that was
not telegraphed — while `mana_per_turn` still does real work, because an examiner that
commits to an expensive card cannot also play a cheap one. If this conflicts with a
later reading of the spec, the spec wins; raise it rather than improvising a second
model.

---

## Phase 1 — Cards and the deck

### Task 3: `CardData` and the effect vocabulary

**Files:**
- Create: `scripts/data/CardData.gd`, `resources/cards/spark.tres`, `resources/cards/ember_lance.tres`
- Test: `tests/test_content.gd`

**Interfaces:**
- Consumes: `Schools` (Task 1).
- Produces: `CardData` with `card_name: String`, `school: Schools.School`, `cost: int`, `effects: Array[Dictionary]`, `xp_to_evolve: int`, `evolved_card: CardData`, `art_id: String`, `exhaust: bool`, `retain: bool`; the effect-kind constants `CardData.DAMAGE`, `BLOCK`, `HEAL`, `STATUS`, `DRAW`, `MANA_NEXT`, `SELF_DAMAGE`, `DOUBLE_DECAY`, `BONUS_IF_CHILLED`, `BONUS_IF_WARD_PLAYED`; and `CardData.is_fully_evolved() -> bool`.

- [ ] **Step 1: Write the failing test `tests/test_content.gd`**

```gdscript
extends TestCase

## Content integrity. Grows in Tasks 16-18 to cover the whole card, examiner and
## course set; starts by pinning the CardData contract.


func suite_name() -> String:
	return "content"


func run() -> void:
	var spark: CardData = load("res://resources/cards/spark.tres")
	check(spark != null, "spark loads")
	if spark == null:
		return
	eq(spark.card_name, "Spark", "spark name")
	eq(spark.school, Schools.School.CINDER, "spark is cinder")
	eq(spark.cost, 1, "spark costs 1")
	eq(spark.xp_to_evolve, 5, "spark evolves at 5")
	eq(spark.effects.size(), 1, "spark has one effect")
	eq(spark.effects[0]["kind"], CardData.DAMAGE, "spark deals damage")
	eq(spark.effects[0]["amount"], 6, "spark deals 6")
	check(not spark.is_fully_evolved(), "spark can evolve")

	var lance: CardData = spark.evolved_card
	check(lance != null, "spark points at ember lance")
	if lance == null:
		return
	eq(lance.card_name, "Ember Lance", "evolved name")
	eq(lance.effects[0]["amount"], 10, "ember lance deals 10")
	check(lance.is_fully_evolved(), "ember lance is terminal")
	# A card that evolves into itself is an infinite loop at play time.
	neq(lance, lance.evolved_card, "no self-evolution")
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `spark loads` fails because the resource does not exist.

- [ ] **Step 3: Write `scripts/data/CardData.gd`**

```gdscript
class_name CardData
extends Resource

## A card's static definition. Shared by every copy of the card in every run, so it
## is immutable at play time: per-copy XP lives on CardInstance, never here.

# Effect kinds. An effect is a Dictionary: {"kind": ..., "amount": int, ...}.
const DAMAGE := "damage"
const BLOCK := "block"
const HEAL := "heal"
const STATUS := "status"  # also carries "status": Statuses.Kind
const DRAW := "draw"
const MANA_NEXT := "mana_next"
const SELF_DAMAGE := "self_damage"
const DOUBLE_DECAY := "double_decay"
const BONUS_IF_CHILLED := "bonus_if_chilled"
const BONUS_IF_WARD_PLAYED := "bonus_if_ward_played"

@export var card_name: String = ""
@export var school: Schools.School = Schools.School.CINDER
@export var cost: int = 1
@export var effects: Array[Dictionary] = []
@export var xp_to_evolve: int = 5
## The next tier, or null when this card is already the evolved form. Self-reference
## on a Resource is legal; a mutual typed reference between two core classes is not.
@export var evolved_card: CardData
@export var art_id: String = ""
## Battle-scoped: an exhausted card leaves play until the battle ends.
@export var exhaust: bool = false
## Retained cards survive the end-of-turn discard.
@export var retain: bool = false


func is_fully_evolved() -> bool:
	return evolved_card == null
```

- [ ] **Step 4: Write the two card resources**

`resources/cards/ember_lance.tres` — write the evolved form first, because Spark
references it.

```ini
[gd_resource type="Resource" script_class="CardData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/CardData.gd" id="1"]

[resource]
script = ExtResource("1")
card_name = "Ember Lance"
school = 0
cost = 1
effects = [{"amount": 10, "kind": "damage"}]
xp_to_evolve = 5
evolved_card = null
art_id = "cards/spark"
exhaust = false
retain = false
```

`resources/cards/spark.tres`:

```ini
[gd_resource type="Resource" script_class="CardData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/CardData.gd" id="1"]
[ext_resource type="Resource" path="res://resources/cards/ember_lance.tres" id="2"]

[resource]
script = ExtResource("1")
card_name = "Spark"
school = 0
cost = 1
effects = [{"amount": 6, "kind": "damage"}]
xp_to_evolve = 5
evolved_card = ExtResource("2")
art_id = "cards/spark"
exhaust = false
retain = false
```

`school = 0` is `CINDER` — enums serialise as ints. The evolved card shares the base
card's `art_id` on purpose: evolution reuses the illustration with a gold-rimmed frame.

- [ ] **Step 5: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(cards): add the CardData resource and its effect vocabulary"
```

---

### Task 4: `CardInstance` — per-run XP and evolution

The most important task in the plan. If XP reaches `CardData`, progress leaks across
runs and across every copy of the card, and nothing else in the game will look wrong.

**Files:**
- Create: `scripts/core/CardInstance.gd`
- Test: `tests/test_evolution.gd`

**Interfaces:**
- Consumes: `CardData` (Task 3).
- Produces: `CardInstance.new(data: CardData, starting_xp := 0)`; `var data: CardData`; `var xp: int`; `gain_xp(amount := 1) -> bool` returning whether this call evolved the card; `can_evolve() -> bool`; `progress() -> String` for display, e.g. `"3/5"`.

- [ ] **Step 1: Write the failing test `tests/test_evolution.gd`**

```gdscript
extends TestCase

## Card XP is per-copy and per-run. The third test here is the one that matters:
## two instances sharing one CardData must not see each other's XP.


func suite_name() -> String:
	return "evolution"


func run() -> void:
	var spark: CardData = load("res://resources/cards/spark.tres")

	# Accrues one XP per play and does not evolve early.
	var card := CardInstance.new(spark)
	eq(card.xp, 0, "starts at zero")
	for i in 4:
		eq(card.gain_xp(), false, "no evolution at %d xp" % (i + 1))
	eq(card.xp, 4, "four xp banked")
	eq(card.data.card_name, "Spark", "still a spark")

	# The fifth play evolves it, in place, immediately.
	eq(card.gain_xp(), true, "fifth play evolves")
	eq(card.data.card_name, "Ember Lance", "became ember lance")
	eq(card.xp, 0, "xp resets on evolution")

	# Evolved cards are terminal and stop accruing.
	eq(card.can_evolve(), false, "terminal card cannot evolve")
	eq(card.gain_xp(), false, "terminal card does not evolve again")
	eq(card.xp, 0, "terminal card banks no xp")

	# THE CRITICAL CASE. Two copies of one card share a CardData; XP must not leak
	# through it, or a single play would advance every copy and persist across runs.
	var a := CardInstance.new(spark)
	var b := CardInstance.new(spark)
	a.gain_xp()
	a.gain_xp()
	eq(a.xp, 2, "a banked two")
	eq(b.xp, 0, "b is untouched")
	eq(spark.card_name, "Spark", "the shared resource is unchanged")
	check(not ("xp" in spark), "CardData has no xp property at all")

	# Reloading the resource must not show XP either.
	var reloaded: CardData = load("res://resources/cards/spark.tres")
	eq(reloaded.card_name, "Spark", "reloaded card is pristine")

	# Display helper.
	eq(CardInstance.new(spark, 3).progress(), "3/5", "progress reads x/y")
	var evolved := CardInstance.new(spark)
	for i in 5:
		evolved.gain_xp()
	eq(evolved.progress(), "mastered", "terminal card reads mastered")
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `CardInstance` is not declared.

- [ ] **Step 3: Write `scripts/core/CardInstance.gd`**

```gdscript
class_name CardInstance
extends RefCounted

## One copy of a card inside one run. Holds its own XP and a pointer to the shared
## CardData. Evolution swaps the pointer; the CardData is never written to.

var data: CardData
var xp: int = 0


func _init(card_data: CardData, starting_xp: int = 0) -> void:
	data = card_data
	xp = starting_xp


func can_evolve() -> bool:
	return data != null and not data.is_fully_evolved()


## Returns true when this call evolved the card.
func gain_xp(amount: int = 1) -> bool:
	if not can_evolve():
		return false
	xp += amount
	if xp < data.xp_to_evolve:
		return false
	data = data.evolved_card
	xp = 0
	return true


func progress() -> String:
	if not can_evolve():
		return "mastered"
	return "%d/%d" % [xp, data.xp_to_evolve]
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS, `evolution` reporting 19 checks.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(cards): add run-scoped card instances that evolve on xp"
```

---

### Task 5: `Deck` — piles, drawing and the end-of-turn discard

**Files:**
- Create: `scripts/core/Deck.gd`
- Test: `tests/test_deck.gd`

**Interfaces:**
- Consumes: `CardInstance` (Task 4), `CardData` (Task 3).
- Produces: `Deck.HAND_SIZE == 5`; `Deck.new(cards: Array, rng: RandomNumberGenerator = null)`; `var draw_pile`, `hand`, `discard_pile`, `exhausted: Array[CardInstance]`; `draw(count: int) -> Array`; `reshuffle() -> void`; `discard_hand() -> Array`; `play(card: CardInstance) -> void`; `total() -> int`.

The piles hold the *same* `CardInstance` objects as the run deck, so XP earned in
battle is already on the run's cards when the battle ends. Never duplicate instances
into a battle.

- [ ] **Step 1: Write the failing test `tests/test_deck.gd`**

```gdscript
extends TestCase

## Draw, reshuffle, retain and exhaust. Every test seeds its own RNG so shuffles
## are reproducible.


func suite_name() -> String:
	return "deck"


func _card(name: String, retain := false, exhaust := false) -> CardInstance:
	var data := CardData.new()
	data.card_name = name
	data.retain = retain
	data.exhaust = exhaust
	return CardInstance.new(data)


func _cards(n: int) -> Array:
	var out := []
	for i in n:
		out.append(_card("c%d" % i))
	return out


func _deck(cards: Array) -> Deck:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	return Deck.new(cards, rng)


func run() -> void:
	eq(Deck.HAND_SIZE, 5, "hand size is five")

	# Drawing moves cards from the draw pile to the hand and conserves the total.
	var deck := _deck(_cards(10))
	eq(deck.total(), 10, "ten cards in")
	eq(deck.draw(5).size(), 5, "drew five")
	eq(deck.hand.size(), 5, "five in hand")
	eq(deck.draw_pile.size(), 5, "five left to draw")
	eq(deck.total(), 10, "total conserved")

	# An empty draw pile reshuffles the discard rather than starving.
	var small := _deck(_cards(3))
	small.draw(3)
	small.discard_hand()
	eq(small.draw_pile.size(), 0, "draw pile empty before reshuffle")
	eq(small.discard_pile.size(), 3, "three discarded")
	var drawn := small.draw(2)
	eq(drawn.size(), 2, "reshuffled and drew two")
	eq(small.discard_pile.size(), 0, "discard consumed by reshuffle")
	eq(small.total(), 3, "reshuffle conserves cards")

	# Drawing more than exists stops rather than looping forever.
	var tiny := _deck(_cards(2))
	eq(tiny.draw(5).size(), 2, "draws only what exists")

	# Unplayed cards discard at end of turn; retained cards stay in hand.
	var mixed := _deck([_card("keep", true), _card("drop"), _card("drop2")])
	mixed.draw(3)
	var discarded := mixed.discard_hand()
	eq(discarded.size(), 2, "two discarded")
	eq(mixed.hand.size(), 1, "retained card stayed")
	eq(mixed.hand[0].data.card_name, "keep", "the retained one")

	# Playing a card discards it; an exhaust card leaves play for the battle.
	var play_deck := _deck([_card("normal"), _card("burner", false, true)])
	play_deck.draw(2)
	var normal: CardInstance = null
	var burner: CardInstance = null
	for card in play_deck.hand:
		if card.data.card_name == "normal":
			normal = card
		else:
			burner = card
	play_deck.play(normal)
	eq(play_deck.discard_pile.size(), 1, "played card discarded")
	play_deck.play(burner)
	eq(play_deck.exhausted.size(), 1, "exhaust card set aside")
	eq(play_deck.discard_pile.size(), 1, "exhaust did not reach the discard")
	play_deck.reshuffle()
	eq(play_deck.draw_pile.size(), 1, "exhausted card is not reshuffled")
	eq(play_deck.total(), 2, "exhausted cards still count toward the total")
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `Deck` is not declared.

- [ ] **Step 3: Write `scripts/core/Deck.gd`**

```gdscript
class_name Deck
extends RefCounted

## The four battle piles. Holds the same CardInstance objects as the run deck, so
## XP earned mid-battle is already banked on the run's cards when the battle ends.

const HAND_SIZE := 5

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhausted: Array[CardInstance] = []

var _rng: RandomNumberGenerator


func _init(cards: Array, rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	for card in cards:
		draw_pile.append(card)
	shuffle_draw_pile()


## Fisher-Yates against our own RNG, so a seeded test shuffles reproducibly.
func shuffle_draw_pile() -> void:
	for i in range(draw_pile.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = swap


func draw(count: int) -> Array:
	var drawn := []
	for _i in count:
		if draw_pile.is_empty():
			reshuffle()
		if draw_pile.is_empty():
			break  # nothing left anywhere; do not spin
		var card: CardInstance = draw_pile.pop_back()
		hand.append(card)
		drawn.append(card)
	return drawn


func reshuffle() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle_draw_pile()


## End of turn: unplayed cards go to the discard, retained cards stay in hand.
func discard_hand() -> Array:
	var discarded := []
	var kept: Array[CardInstance] = []
	for card in hand:
		if card.data.retain:
			kept.append(card)
		else:
			discard_pile.append(card)
			discarded.append(card)
	hand = kept
	return discarded


func play(card: CardInstance) -> void:
	hand.erase(card)
	if card.data.exhaust:
		exhausted.append(card)
	else:
		discard_pile.append(card)


func total() -> int:
	return draw_pile.size() + hand.size() + discard_pile.size() + exhausted.size()
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(deck): add draw, reshuffle, retain and exhaust piles"
```

---

## Phase 2 — Battle

### Task 6: `Statuses` — the five status effects

**Files:**
- Create: `scripts/core/Statuses.gd`
- Test: `tests/test_statuses.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `Statuses.Kind` enum with `BURN`, `CHILL`, `BLOT`, `DECAY`; `Statuses.new()`; `amount(kind) -> int`; `add(kind, n) -> void`; `consume(kind) -> int` (returns the stack and zeroes it); `clear_all() -> void`; `tick_start_of_turn() -> int` (Burn damage, then Burn decrements by 1); `tick_end_of_turn() -> int` (Decay damage, then Decay grows by 2); `double_decay() -> void`; `to_dict() -> Dictionary` / `Statuses.from_dict(d) -> Statuses` for saves.

Block is *not* here — it lives on `Combatant`, because it interacts with damage
application rather than with the tick cycle.

- [ ] **Step 1: Write the failing test `tests/test_statuses.gd`**

```gdscript
extends TestCase

## Burn decays, Decay grows. That asymmetry is the whole identity of the two
## damage-over-time schools, so it is pinned here.


func suite_name() -> String:
	return "statuses"


func run() -> void:
	var s := Statuses.new()
	eq(s.amount(Statuses.Kind.BURN), 0, "starts empty")

	# Burn: ticks at the start of the turn, then decrements.
	s.add(Statuses.Kind.BURN, 3)
	eq(s.tick_start_of_turn(), 3, "burn deals its value")
	eq(s.amount(Statuses.Kind.BURN), 2, "burn decremented")
	eq(s.tick_start_of_turn(), 2, "burn deals less")
	eq(s.tick_start_of_turn(), 1, "burn deals one")
	eq(s.tick_start_of_turn(), 0, "burn is spent")
	eq(s.amount(Statuses.Kind.BURN), 0, "burn cannot go negative")

	# Decay: ticks at the end of the turn, then GROWS by two.
	var d := Statuses.new()
	d.add(Statuses.Kind.DECAY, 4)
	eq(d.tick_end_of_turn(), 4, "decay deals its value")
	eq(d.amount(Statuses.Kind.DECAY), 6, "decay grew by two")
	eq(d.tick_end_of_turn(), 6, "decay deals more")
	eq(d.amount(Statuses.Kind.DECAY), 8, "decay grew again")

	# Doubling is what Feed the Curriculum does.
	d.double_decay()
	eq(d.amount(Statuses.Kind.DECAY), 16, "decay doubled")

	# Decay with no stacks does nothing and does not start growing from zero.
	var empty := Statuses.new()
	eq(empty.tick_end_of_turn(), 0, "no decay, no damage")
	eq(empty.amount(Statuses.Kind.DECAY), 0, "decay stays at zero")

	# Chill and Blot are consumed whole by the next card, not ticked.
	var c := Statuses.new()
	c.add(Statuses.Kind.CHILL, 2)
	eq(c.consume(Statuses.Kind.CHILL), 2, "consume returns the stack")
	eq(c.amount(Statuses.Kind.CHILL), 0, "consume zeroes it")
	eq(c.consume(Statuses.Kind.CHILL), 0, "consuming nothing is zero")
	eq(c.tick_start_of_turn(), 0, "chill is not burn")

	# Stacks accumulate.
	var stack := Statuses.new()
	stack.add(Statuses.Kind.BLOT, 1)
	stack.add(Statuses.Kind.BLOT, 2)
	eq(stack.amount(Statuses.Kind.BLOT), 3, "blot stacks")

	# Round-trips for the save file.
	var round := Statuses.from_dict(stack.to_dict())
	eq(round.amount(Statuses.Kind.BLOT), 3, "survives a round trip")
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `Statuses` is not declared.

- [ ] **Step 3: Write `scripts/core/Statuses.gd`**

```gdscript
class_name Statuses
extends RefCounted

## The four stacking statuses. Block is deliberately absent: it belongs to
## Combatant, because it modifies incoming damage rather than ticking.

enum Kind { BURN, CHILL, BLOT, DECAY }

## How much Decay grows each time it ticks. Growing rather than decaying is what
## makes Rot lose short fights and win long ones.
const DECAY_GROWTH := 2

var _stacks := {
	Kind.BURN: 0,
	Kind.CHILL: 0,
	Kind.BLOT: 0,
	Kind.DECAY: 0,
}


func amount(kind: Kind) -> int:
	return _stacks.get(kind, 0)


func add(kind: Kind, n: int) -> void:
	_stacks[kind] = maxi(0, amount(kind) + n)


## Returns the stack and zeroes it. Chill and Blot are spent whole by one card.
func consume(kind: Kind) -> int:
	var value := amount(kind)
	_stacks[kind] = 0
	return value


func clear_all() -> void:
	for kind in _stacks:
		_stacks[kind] = 0


## Burn damage, then Burn decrements. Returns the damage dealt.
func tick_start_of_turn() -> int:
	var burn := amount(Kind.BURN)
	if burn > 0:
		_stacks[Kind.BURN] = burn - 1
	return burn


## Decay damage, then Decay grows. Returns the damage dealt.
func tick_end_of_turn() -> int:
	var decay := amount(Kind.DECAY)
	if decay > 0:
		_stacks[Kind.DECAY] = decay + DECAY_GROWTH
	return decay


func double_decay() -> void:
	_stacks[Kind.DECAY] = amount(Kind.DECAY) * 2


func to_dict() -> Dictionary:
	return {
		"burn": amount(Kind.BURN),
		"chill": amount(Kind.CHILL),
		"blot": amount(Kind.BLOT),
		"decay": amount(Kind.DECAY),
	}


static func from_dict(d: Dictionary) -> Statuses:
	var s := Statuses.new()
	s.add(Kind.BURN, int(d.get("burn", 0)))
	s.add(Kind.CHILL, int(d.get("chill", 0)))
	s.add(Kind.BLOT, int(d.get("blot", 0)))
	s.add(Kind.DECAY, int(d.get("decay", 0)))
	return s
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 5: Commit and push**

```bash
git add -A
git commit -m "feat(battle): add the five status effects"
git push
```

---

### Task 7: `Combatant` and `EnemyData`

**Files:**
- Create: `scripts/core/Combatant.gd`, `scripts/data/EnemyData.gd`, `resources/enemies/novice.tres`
- Test: `tests/test_combatant.gd`

**Interfaces:**
- Consumes: `Statuses` (Task 6), `Schools` (Task 1), `CardData` (Task 3).
- Produces: `Combatant.new(display_name: String, max_hp: int, mana_per_turn: int)`; `var display_name, hp, max_hp, block, mana, mana_per_turn`; `var statuses: Statuses`; `take_damage(amount: int) -> int` returning HP actually lost; `gain_block(n: int) -> void`; `heal(n: int) -> void`; `spend_mana(n: int) -> bool`; `refill_mana(bonus := 0) -> void`; `is_down() -> bool`; `hp_fraction() -> float`. And `EnemyData` with `enemy_name: String`, `max_hp: int`, `mana_per_turn: int`, `deck: Array[CardData]`, `weak_school: Schools.School`, `warded_school: Schools.School`, `art_id: String`, plus `to_combatant() -> Combatant`.

- [ ] **Step 1: Write the failing test `tests/test_combatant.gd`**

```gdscript
extends TestCase


func suite_name() -> String:
	return "combatant"


func run() -> void:
	var c := Combatant.new("Student", 60, 3)
	eq(c.hp, 60, "starts at full")
	eq(c.mana, 0, "mana starts empty until refilled")
	c.refill_mana()
	eq(c.mana, 3, "refilled to per-turn")

	# Block absorbs damage before HP, and is consumed by it.
	c.gain_block(10)
	eq(c.take_damage(4), 0, "block ate it all")
	eq(c.block, 6, "block partly spent")
	eq(c.hp, 60, "hp untouched")
	eq(c.take_damage(10), 4, "overflow reaches hp")
	eq(c.block, 0, "block exhausted")
	eq(c.hp, 56, "lost the overflow only")

	# Healing cannot exceed max.
	c.heal(100)
	eq(c.hp, 60, "healing caps at max")

	# HP floors at zero and reports down.
	eq(c.is_down(), false, "not down at full")
	c.take_damage(999)
	eq(c.hp, 0, "hp floors at zero")
	eq(c.is_down(), true, "down at zero")
	almost(c.hp_fraction(), 0.0, "fraction is zero")

	# Mana spending refuses what it cannot afford.
	var m := Combatant.new("M", 10, 3)
	m.refill_mana()
	eq(m.spend_mana(2), true, "afforded two")
	eq(m.mana, 1, "one left")
	eq(m.spend_mana(2), false, "cannot afford two more")
	eq(m.mana, 1, "failed spend changed nothing")
	m.refill_mana(2)
	eq(m.mana, 5, "bonus mana added on refill")

	# EnemyData builds a combatant and declares its secrets.
	var novice: EnemyData = load("res://resources/enemies/novice.tres")
	check(novice != null, "novice loads")
	if novice == null:
		return
	eq(novice.enemy_name, "Novice", "name")
	eq(novice.weak_school, Schools.School.INK, "novice is weak to ink")
	eq(novice.warded_school, Schools.School.FROST, "novice wards frost")
	neq(novice.weak_school, novice.warded_school, "weak and warded differ")
	check(novice.deck.size() > 0, "novice has a deck")
	var body := novice.to_combatant()
	eq(body.hp, novice.max_hp, "combatant starts at full hp")
	eq(body.display_name, "Novice", "combatant carries the name")
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `Combatant` is not declared.

- [ ] **Step 3: Write `scripts/core/Combatant.gd`**

```gdscript
class_name Combatant
extends RefCounted

## The shared shape of the player and an examiner: hit points, block, mana and
## statuses. Knows nothing about cards or turns.

var display_name := ""
var hp := 0
var max_hp := 0
var block := 0
var mana := 0
var mana_per_turn := 0
var statuses: Statuses = Statuses.new()


func _init(name_in: String, max_hp_in: int, mana_per_turn_in: int) -> void:
	display_name = name_in
	max_hp = max_hp_in
	hp = max_hp_in
	mana_per_turn = mana_per_turn_in


## Block absorbs first. Returns the hit points actually lost.
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var absorbed := mini(block, amount)
	block -= absorbed
	var lost := mini(amount - absorbed, hp)
	hp -= lost
	return lost


func gain_block(n: int) -> void:
	block = maxi(0, block + n)


func heal(n: int) -> void:
	hp = clampi(hp + n, 0, max_hp)


## Self-damage from Rot cards bypasses block — you are paying, not being hit.
func pay_hp(n: int) -> void:
	hp = maxi(0, hp - n)


func spend_mana(n: int) -> bool:
	if n > mana:
		return false
	mana -= n
	return true


func refill_mana(bonus: int = 0) -> void:
	mana = mana_per_turn + bonus


## Block expires at the start of its owner's turn.
func expire_block() -> void:
	block = 0


func is_down() -> bool:
	return hp <= 0


func hp_fraction() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)
```

- [ ] **Step 4: Write `scripts/data/EnemyData.gd`**

```gdscript
class_name EnemyData
extends Resource

## An examiner. Its deck is drawn from the same CardData pool the player uses, which
## is what makes copying its cards after a win cost no extra content.

@export var enemy_name: String = ""
@export var max_hp: int = 30
@export var mana_per_turn: int = 2
@export var deck: Array[CardData] = []
@export var weak_school: Schools.School = Schools.School.CINDER
@export var warded_school: Schools.School = Schools.School.FROST
@export var art_id: String = ""
## Gates and the final are exempt from the "appears in >= 2 courses" rule.
@export var is_gate: bool = false


func to_combatant() -> Combatant:
	return Combatant.new(enemy_name, max_hp, mana_per_turn)
```

- [ ] **Step 5: Write `resources/enemies/novice.tres`**

The Novice leans Cinder, is weak to Ink and wards Frost, per the spec's roster. Its
deck is four Sparks for now; Task 17 authors the real lists.

```ini
[gd_resource type="Resource" script_class="EnemyData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/EnemyData.gd" id="1"]
[ext_resource type="Resource" path="res://resources/cards/spark.tres" id="2"]

[resource]
script = ExtResource("1")
enemy_name = "Novice"
max_hp = 28
mana_per_turn = 2
deck = [ExtResource("2"), ExtResource("2"), ExtResource("2"), ExtResource("2")]
weak_school = 2
warded_school = 1
art_id = "entities/novice"
is_gate = false
```

`weak_school = 2` is `INK`, `warded_school = 1` is `FROST` — the enum order is
`CINDER, FROST, INK, ROT, WARD`.

- [ ] **Step 6: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 7: Commit and push**

```bash
git add -A
git commit -m "feat(battle): add combatants and the examiner resource"
git push
```

---

### Task 8: `Bestiary` and the school multiplier

**Files:**
- Create: `scripts/core/Bestiary.gd`
- Test: `tests/test_schools_multiplier.gd`

**Interfaces:**
- Consumes: `Schools` (Task 1), `EnemyData` (Task 7).
- Produces: `Bestiary.WEAK_MULTIPLIER == 1.5`, `Bestiary.WARD_MULTIPLIER == 0.5`; `Bestiary.new()`; `multiplier(enemy: EnemyData, school) -> float`; `record_hit(enemy: EnemyData, school) -> String` returning `"weakness"`, `"ward"` or `""` when the hit revealed something new; `knows_weakness(enemy_name: String) -> bool`; `knows_ward(enemy_name: String) -> bool`; `to_dict()` / `Bestiary.from_dict(d)`.

The multiplier applies whether or not the weakness is known — the reveal is
information, not the reward.

- [ ] **Step 1: Write the failing test `tests/test_schools_multiplier.gd`**

```gdscript
extends TestCase

## The multiplier applies to a card's numbers, not to damage alone: that is what
## lets Ward be a weakness at all, since Ward deals no damage.


func suite_name() -> String:
	return "multiplier"


func run() -> void:
	var novice: EnemyData = load("res://resources/enemies/novice.tres")
	var b := Bestiary.new()

	# Weak to Ink, wards Frost, neutral to everything else.
	almost(b.multiplier(novice, Schools.School.INK), 1.5, "weak school hits harder")
	almost(b.multiplier(novice, Schools.School.FROST), 0.5, "warded school is halved")
	almost(b.multiplier(novice, Schools.School.CINDER), 1.0, "neutral school is plain")

	# The bonus applies before it is known. Knowledge is the second reward.
	eq(b.knows_weakness("Novice"), false, "nothing known yet")
	almost(b.multiplier(novice, Schools.School.INK), 1.5, "bonus applies unrevealed")

	# A hit with the weak school reveals it, once.
	eq(b.record_hit(novice, Schools.School.INK), "weakness", "revealed the weakness")
	eq(b.knows_weakness("Novice"), true, "weakness now known")
	eq(b.record_hit(novice, Schools.School.INK), "", "second hit reveals nothing new")

	# A wasted hit still buys knowledge.
	eq(b.record_hit(novice, Schools.School.FROST), "ward", "revealed the ward")
	eq(b.knows_ward("Novice"), true, "ward now known")

	# A neutral hit reveals nothing.
	eq(b.record_hit(novice, Schools.School.CINDER), "", "neutral hit teaches nothing")

	# Knowledge is keyed by examiner NAME, so it carries to the next course that
	# uses the same examiner. That is the whole point of the Bestiary.
	var second: EnemyData = load("res://resources/enemies/novice.tres")
	eq(b.knows_weakness(second.enemy_name), true, "known for the type, not the instance")

	# Round-trips for the save file.
	var round := Bestiary.from_dict(b.to_dict())
	eq(round.knows_weakness("Novice"), true, "weakness survives a round trip")
	eq(round.knows_ward("Novice"), true, "ward survives a round trip")
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `Bestiary` is not declared.

- [ ] **Step 3: Write `scripts/core/Bestiary.gd`**

```gdscript
class_name Bestiary
extends RefCounted

## What the student has learned about examiners this run. Keyed by examiner name, so
## a weakness learned in Cantrips 101 still pays in Marginalia 201.

const WEAK_MULTIPLIER := 1.5
const WARD_MULTIPLIER := 0.5

var _weaknesses_known := {}
var _wards_known := {}


## Scales every number on a card of this school. Applies whether or not the player
## has discovered the weakness: the reveal is information, not the reward.
func multiplier(enemy: EnemyData, school) -> float:
	if enemy == null:
		return 1.0
	if school == enemy.weak_school:
		return WEAK_MULTIPLIER
	if school == enemy.warded_school:
		return WARD_MULTIPLIER
	return 1.0


## Records what a hit taught. Returns "weakness", "ward", or "" for nothing new.
func record_hit(enemy: EnemyData, school) -> String:
	if enemy == null:
		return ""
	if school == enemy.weak_school and not _weaknesses_known.has(enemy.enemy_name):
		_weaknesses_known[enemy.enemy_name] = school
		return "weakness"
	if school == enemy.warded_school and not _wards_known.has(enemy.enemy_name):
		_wards_known[enemy.enemy_name] = school
		return "ward"
	return ""


func knows_weakness(enemy_name: String) -> bool:
	return _weaknesses_known.has(enemy_name)


func knows_ward(enemy_name: String) -> bool:
	return _wards_known.has(enemy_name)


func weakness_of(enemy_name: String):
	return _weaknesses_known.get(enemy_name, null)


func to_dict() -> Dictionary:
	return {"weaknesses": _weaknesses_known.duplicate(), "wards": _wards_known.duplicate()}


static func from_dict(d: Dictionary) -> Bestiary:
	var b := Bestiary.new()
	for name in d.get("weaknesses", {}):
		b._weaknesses_known[name] = d["weaknesses"][name]
	for name in d.get("wards", {}):
		b._wards_known[name] = d["wards"][name]
	return b
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 5: Commit and push**

```bash
git add -A
git commit -m "feat(battle): add the bestiary and school multipliers"
git push
```

---

### Task 9: `Battle` — turn resolution and the event log

The core of the game. Returns arrays of event dictionaries; the UI in Task 21 replays
them. Nothing here touches the scene tree.

**Files:**
- Create: `scripts/core/Battle.gd`
- Test: `tests/test_battle.gd`

**Interfaces:**
- Consumes: `Deck` (5), `Statuses` (6), `Combatant`/`EnemyData` (7), `Bestiary` (8), `CardData` (3), `CardInstance` (4).
- Produces: `Battle.new(player_cards: Array, enemy: EnemyData, bestiary, rng: RandomNumberGenerator = null)`; `var player: Combatant`, `examiner: Combatant`, `player_deck: Deck`, `examiner_intent: CardInstance`, `turns: int`, `xp_banked: int`, `finished: bool`, `player_won: bool`; `schools_played() -> int`; `start() -> Array`; `can_play(card) -> bool`; `play_card(card) -> Array`; `end_turn() -> Array`.

Event dictionaries always carry `type`, and `text` for the log. Types used:
`turn_start`, `draw`, `card_played`, `damage`, `block`, `heal`, `status`, `pay_hp`,
`evolved`, `revealed`, `intent`, `illegal`, `battle_end`.

**Resolution order**, fixed here so the tests and the UI agree:

1. `play_card` — mana check, then scale = school multiplier × Blot reduction; Chill is consumed once per card if the card deals any damage; effects apply in list order; then XP, then bestiary reveal, then the card leaves the hand.
2. `end_turn` — discard hand → player Decay ticks → examiner block expires, mana refills, examiner Burn ticks, examiner plays its intent, examiner Decay ticks, next intent is chosen → player block expires, mana refills (plus any banked bonus), player Burn ticks, draw 5, `turns += 1`.

- [ ] **Step 1: Write the failing test `tests/test_battle.gd`**

```gdscript
extends TestCase

## Turn resolution. Every test builds its cards inline so a content change cannot
## break the rules suite.


func suite_name() -> String:
	return "battle"


func _card(name: String, school, cost: int, effects: Array) -> CardData:
	var d := CardData.new()
	d.card_name = name
	d.school = school
	d.cost = cost
	var typed: Array[Dictionary] = []
	for e in effects:
		typed.append(e)
	d.effects = typed
	return d


func _enemy(hp: int, weak, warded, deck: Array) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name = "Dummy"
	e.max_hp = hp
	e.mana_per_turn = 2
	var typed: Array[CardData] = []
	for c in deck:
		typed.append(c)
	e.deck = typed
	e.weak_school = weak
	e.warded_school = warded
	return e


func _battle(player_cards: Array, enemy: EnemyData) -> Battle:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var instances := []
	for c in player_cards:
		instances.append(CardInstance.new(c))
	return Battle.new(instances, enemy, Bestiary.new(), rng)


func run() -> void:
	var S := Schools.School
	var strike := _card("Strike", S.CINDER, 1, [{"kind": CardData.DAMAGE, "amount": 10}])
	var guard := _card("Guard", S.WARD, 1, [{"kind": CardData.BLOCK, "amount": 6}])
	var poke := _card("Poke", S.INK, 0, [{"kind": CardData.DAMAGE, "amount": 1}])

	# A neutral card deals its face value.
	var b := _battle([strike, strike, strike, strike, strike], _enemy(100, S.ROT, S.FROST, [poke]))
	b.start()
	eq(b.player.hp, 60, "player starts at 60")
	eq(b.player.mana, 3, "three mana")
	eq(b.player_deck.hand.size(), 5, "drew five")
	var events := b.play_card(b.player_deck.hand[0])
	eq(b.examiner.hp, 90, "neutral card dealt 10")
	eq(b.player.mana, 2, "mana spent")
	check(events.size() > 0, "play produced events")

	# Mana is enforced.
	var broke := _battle([_card("Big", S.CINDER, 9, [{"kind": CardData.DAMAGE, "amount": 5}])], _enemy(50, S.ROT, S.FROST, [poke]))
	broke.start()
	eq(broke.can_play(broke.player_deck.hand[0]), false, "cannot afford it")
	var refused := broke.play_card(broke.player_deck.hand[0])
	eq(refused[0]["type"], "illegal", "refused as illegal")
	eq(broke.examiner.hp, 50, "no damage dealt")

	# The weak school multiplies by 1.5, the warded school halves — and the very
	# first hit already gets the bonus.
	var weak := _battle([strike], _enemy(100, S.CINDER, S.WARD, [poke]))
	weak.start()
	weak.play_card(weak.player_deck.hand[0])
	eq(weak.examiner.hp, 85, "weak school dealt 15")

	var warded := _battle([strike], _enemy(100, S.ROT, S.CINDER, [poke]))
	warded.start()
	warded.play_card(warded.player_deck.hand[0])
	eq(warded.examiner.hp, 95, "warded school dealt 5")

	# The multiplier scales non-damage numbers too, which is what lets Ward be a
	# weakness at all.
	var ward_weak := _battle([guard], _enemy(100, S.WARD, S.ROT, [poke]))
	ward_weak.start()
	ward_weak.play_card(ward_weak.player_deck.hand[0])
	eq(ward_weak.player.block, 9, "block scaled by the weakness")

	# Playing a card banks XP and evolves it in place at the threshold.
	var evo_base := _card("Seed", S.INK, 0, [{"kind": CardData.DAMAGE, "amount": 1}])
	var evo_top := _card("Bloom", S.INK, 0, [{"kind": CardData.DAMAGE, "amount": 9}])
	evo_base.evolved_card = evo_top
	evo_base.xp_to_evolve = 2
	var evo := _battle([evo_base, evo_base, evo_base], _enemy(100, S.ROT, S.FROST, [poke]))
	evo.start()
	var first: CardInstance = evo.player_deck.hand[0]
	evo.play_card(first)
	eq(evo.xp_banked, 1, "one xp banked")
	eq(first.data.card_name, "Seed", "not yet evolved")
	var second: CardInstance = evo.player_deck.hand[0]
	var evo_events := evo.play_card(second)
	eq(second.data.card_name, "Bloom", "evolved at the threshold")
	var saw_evolution := false
	for e in evo_events:
		if e["type"] == "evolved":
			saw_evolution = true
	eq(saw_evolution, true, "emitted an evolved event")

	# A hit with the weak school reveals it and says so.
	var reveal := _battle([strike], _enemy(100, S.CINDER, S.WARD, [poke]))
	reveal.start()
	var reveal_events := reveal.play_card(reveal.player_deck.hand[0])
	var saw_reveal := false
	for e in reveal_events:
		if e["type"] == "revealed":
			saw_reveal = true
	eq(saw_reveal, true, "reveal emitted")

	# Distinct schools played is what the Discovery term counts.
	var variety := _battle([strike, guard, poke], _enemy(100, S.ROT, S.FROST, [poke]))
	variety.start()
	for card in variety.player_deck.hand.duplicate():
		if variety.can_play(card):
			variety.play_card(card)
	check(variety.schools_played() >= 2, "counted distinct schools")

	# Ending the turn discards, runs the examiner, and comes back with a new hand.
	var turn := _battle([strike, strike, strike, strike, strike, strike, strike], _enemy(100, S.ROT, S.FROST, [_card("Jab", S.CINDER, 1, [{"kind": CardData.DAMAGE, "amount": 4}])]))
	turn.start()
	eq(turn.turns, 1, "first turn")
	check(turn.examiner_intent != null, "intent telegraphed before the player acts")
	turn.end_turn()
	eq(turn.player.hp, 56, "examiner hit for four")
	eq(turn.turns, 2, "second turn")
	eq(turn.player_deck.hand.size(), 5, "redrew five")
	eq(turn.player.mana, 3, "mana refilled")

	# Burn ticks at the start of the bearer's turn and decrements.
	var burn_card := _card("Kindle", S.CINDER, 1, [{"kind": CardData.STATUS, "status": Statuses.Kind.BURN, "amount": 3}])
	var burn := _battle([burn_card, strike, strike, strike, strike], _enemy(100, S.ROT, S.FROST, [poke]))
	burn.start()
	burn.play_card(burn.player_deck.hand[0])
	eq(burn.examiner.statuses.amount(Statuses.Kind.BURN), 3, "applied three burn")
	burn.end_turn()
	eq(burn.examiner.hp, 97, "burn ticked for three")
	eq(burn.examiner.statuses.amount(Statuses.Kind.BURN), 2, "burn decremented")

	# Rot pays in the player's own hit points, bypassing block.
	var bitter := _card("Bitter", S.ROT, 1, [{"kind": CardData.SELF_DAMAGE, "amount": 3}, {"kind": CardData.DAMAGE, "amount": 12}])
	var rot := _battle([bitter], _enemy(100, S.WARD, S.FROST, [poke]))
	rot.start()
	rot.player.gain_block(50)
	rot.play_card(rot.player_deck.hand[0])
	eq(rot.player.hp, 57, "paid three hp through block")
	eq(rot.examiner.hp, 88, "dealt twelve")

	# Killing the examiner ends the battle and reports a win.
	var kill := _battle([strike], _enemy(5, S.ROT, S.FROST, [poke]))
	kill.start()
	var end_events := kill.play_card(kill.player_deck.hand[0])
	eq(kill.finished, true, "battle over")
	eq(kill.player_won, true, "player won")
	var saw_end := false
	for e in end_events:
		if e["type"] == "battle_end":
			saw_end = true
	eq(saw_end, true, "emitted battle_end")
	eq(kill.play_card(kill.player_deck.hand[0] if kill.player_deck.hand.size() > 0 else null)[0]["type"], "illegal", "cannot play after the end")

	# Losing sets finished without a win. The F strike is Run's job, not Battle's.
	var doomed := _battle([guard], _enemy(100, S.ROT, S.FROST, [_card("Crush", S.CINDER, 1, [{"kind": CardData.DAMAGE, "amount": 999}])]))
	doomed.start()
	doomed.end_turn()
	eq(doomed.finished, true, "battle over")
	eq(doomed.player_won, false, "player lost")
	eq(doomed.player.is_down(), true, "player is down")
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `Battle` is not declared.

- [ ] **Step 3: Write `scripts/core/Battle.gd`**

```gdscript
class_name Battle
extends RefCounted

## One battle. Pure logic: every method returns an array of event dictionaries for
## the presentation layer to replay, and nothing here touches the scene tree.
##
## The examiner plays exactly one card per turn, telegraphed as `examiner_intent` at
## the end of the player's turn, so the player is never hit by untelegraphed damage.

const CHILL_REDUCTION := 0.3  # per stack, applied to damage
const BLOT_REDUCTION := 0.4  # per stack, applied to every number on the card

var player: Combatant
var examiner: Combatant
var player_deck: Deck
var examiner_deck: Deck
var examiner_intent: CardInstance = null
var turns := 0
var xp_banked := 0
var finished := false
var player_won := false

## Untyped: Bestiary and Battle referring to each other by type would be cyclic.
var _bestiary
var _enemy_data: EnemyData
var _schools_played := {}
var _mana_bonus_next := 0
var _ward_played_this_turn := false


func _init(
	player_cards: Array, enemy: EnemyData, bestiary, rng: RandomNumberGenerator = null
) -> void:
	_enemy_data = enemy
	_bestiary = bestiary
	player = Combatant.new("Student", 60, 3)
	examiner = enemy.to_combatant()
	player_deck = Deck.new(player_cards, rng)
	var examiner_instances := []
	for card in enemy.deck:
		examiner_instances.append(CardInstance.new(card))
	examiner_deck = Deck.new(examiner_instances, rng)


func schools_played() -> int:
	return _schools_played.size()


func start() -> Array:
	turns = 1
	player.refill_mana()
	var events: Array = [{"type": "turn_start", "turn": turns, "text": "Turn 1"}]
	for card in player_deck.draw(Deck.HAND_SIZE):
		events.append({"type": "draw", "card": card, "text": "Drew %s" % card.data.card_name})
	events.append_array(_choose_intent())
	return events


func can_play(card) -> bool:
	if finished or card == null:
		return false
	if not player_deck.hand.has(card):
		return false
	return card.data.cost <= player.mana


func play_card(card) -> Array:
	if not can_play(card):
		return [{"type": "illegal", "text": "That card cannot be played."}]

	player.spend_mana(card.data.cost)
	var events: Array = [
		{"type": "card_played", "card": card, "text": "Played %s" % card.data.card_name}
	]

	# One scale for the whole card: the school multiplier, reduced by Blot. Blot is
	# consumed once per card, not once per effect.
	var scale := float(_bestiary.multiplier(_enemy_data, card.data.school))
	var blot := player.statuses.consume(Statuses.Kind.BLOT)
	if blot > 0:
		scale *= maxf(0.0, 1.0 - BLOT_REDUCTION * float(blot))

	# Chill likewise: consumed once, and only if this card actually attacks.
	var chill_scale := 1.0
	if _deals_damage(card.data):
		var chill := player.statuses.consume(Statuses.Kind.CHILL)
		if chill > 0:
			chill_scale = maxf(0.0, 1.0 - CHILL_REDUCTION * float(chill))

	if card.data.school == Schools.School.WARD:
		_ward_played_this_turn = true

	for effect in card.data.effects:
		events.append_array(_apply(effect, scale, chill_scale, player, examiner))

	# Learning: XP is banked on the instance, never on the CardData.
	if card.gain_xp(1):
		events.append(
			{"type": "evolved", "card": card, "text": "%s evolved!" % card.data.card_name}
		)
	xp_banked += 1
	_schools_played[card.data.school] = true

	var revealed: String = _bestiary.record_hit(_enemy_data, card.data.school)
	if revealed != "":
		events.append(
			{
				"type": "revealed",
				"kind": revealed,
				"school": card.data.school,
				"text": (
					"%s is %s %s!"
					% [
						_enemy_data.enemy_name,
						"weak to" if revealed == "weakness" else "warded against",
						Schools.display_name(card.data.school),
					]
				),
			}
		)

	player_deck.play(card)
	events.append_array(_check_end())
	return events


func end_turn() -> Array:
	if finished:
		return [{"type": "illegal", "text": "The battle is over."}]

	var events: Array = []
	for card in player_deck.discard_hand():
		events.append({"type": "discard", "card": card, "text": ""})
	_ward_played_this_turn = false

	# Player's Decay resolves at the end of the player's turn.
	events.append_array(_tick_decay(player, "You"))
	events.append_array(_check_end())
	if finished:
		return events

	events.append_array(_examiner_turn())
	events.append_array(_check_end())
	if finished:
		return events

	# Back to the player.
	turns += 1
	player.expire_block()
	player.refill_mana(_mana_bonus_next)
	_mana_bonus_next = 0
	events.append({"type": "turn_start", "turn": turns, "text": "Turn %d" % turns})
	var burn := player.statuses.tick_start_of_turn()
	if burn > 0:
		player.take_damage(burn)
		events.append({"type": "damage", "target": "player", "amount": burn, "text": "Burn"})
	for card in player_deck.draw(Deck.HAND_SIZE):
		events.append({"type": "draw", "card": card, "text": ""})
	events.append_array(_check_end())
	return events


func _examiner_turn() -> Array:
	var events: Array = []
	examiner.expire_block()
	examiner.refill_mana()

	var burn := examiner.statuses.tick_start_of_turn()
	if burn > 0:
		examiner.take_damage(burn)
		events.append(
			{"type": "damage", "target": "examiner", "amount": burn, "text": "Burn"}
		)
	if examiner.is_down():
		return events

	if examiner_intent != null:
		var card: CardInstance = examiner_intent
		examiner.spend_mana(card.data.cost)
		events.append(
			{
				"type": "card_played",
				"card": card,
				"by": "examiner",
				"text": "%s casts %s" % [_enemy_data.enemy_name, card.data.card_name],
			}
		)
		var scale := 1.0
		var blot := examiner.statuses.consume(Statuses.Kind.BLOT)
		if blot > 0:
			scale *= maxf(0.0, 1.0 - BLOT_REDUCTION * float(blot))
		var chill_scale := 1.0
		if _deals_damage(card.data):
			var chill := examiner.statuses.consume(Statuses.Kind.CHILL)
			if chill > 0:
				chill_scale = maxf(0.0, 1.0 - CHILL_REDUCTION * float(chill))
		for effect in card.data.effects:
			events.append_array(_apply(effect, scale, chill_scale, examiner, player))
		examiner_deck.play(card)
		examiner_intent = null

	events.append_array(_tick_decay(examiner, _enemy_data.enemy_name))
	if not examiner.is_down():
		events.append_array(_choose_intent())
	return events


## Picks the most expensive card the examiner can afford, and telegraphs it.
func _choose_intent() -> Array:
	if examiner_deck.hand.size() < 3:
		examiner_deck.draw(3 - examiner_deck.hand.size())
	var best: CardInstance = null
	for card in examiner_deck.hand:
		if card.data.cost > examiner.mana_per_turn:
			continue
		if best == null or card.data.cost > best.data.cost:
			best = card
	examiner_intent = best
	if best == null:
		return [{"type": "intent", "card": null, "text": "%s hesitates." % _enemy_data.enemy_name}]
	return [
		{
			"type": "intent",
			"card": best,
			"text": "%s will cast %s" % [_enemy_data.enemy_name, best.data.card_name],
		}
	]


func _tick_decay(who: Combatant, label: String) -> Array:
	var decay := who.statuses.tick_end_of_turn()
	if decay <= 0:
		return []
	who.take_damage(decay)
	return [
		{
			"type": "damage",
			"target": "player" if who == player else "examiner",
			"amount": decay,
			"text": "%s take %d from Decay" % [label, decay],
		}
	]


func _deals_damage(data: CardData) -> bool:
	for effect in data.effects:
		if effect.get("kind", "") in [CardData.DAMAGE, CardData.BONUS_IF_CHILLED]:
			return true
	return false


## Applies one effect. `scale` covers the school multiplier and Blot; `chill_scale`
## applies to damage only.
func _apply(
	effect: Dictionary, scale: float, chill_scale: float, source: Combatant, target: Combatant
) -> Array:
	var kind: String = effect.get("kind", "")
	var raw: int = int(effect.get("amount", 0))
	var scaled := int(roundf(float(raw) * scale))
	var target_label := "player" if target == player else "examiner"

	match kind:
		CardData.DAMAGE:
			# One rounding over the combined product. Rounding `scaled` first and then
			# again after chill_scale double-rounds and drifts off the intended number.
			var dealt := int(roundf(float(raw) * scale * chill_scale))
			target.take_damage(dealt)
			return [
				{"type": "damage", "target": target_label, "amount": dealt, "text": "%d damage" % dealt}
			]
		CardData.BONUS_IF_CHILLED:
			if target.statuses.amount(Statuses.Kind.CHILL) <= 0:
				return []
			var bonus := int(roundf(float(raw) * scale * chill_scale))
			target.take_damage(bonus)
			return [
				{"type": "damage", "target": target_label, "amount": bonus, "text": "+%d, chilled" % bonus}
			]
		CardData.BLOCK:
			source.gain_block(scaled)
			return [{"type": "block", "amount": scaled, "text": "+%d block" % scaled}]
		CardData.BONUS_IF_WARD_PLAYED:
			if not _ward_played_this_turn:
				return []
			source.gain_block(scaled)
			return [{"type": "block", "amount": scaled, "text": "+%d block" % scaled}]
		CardData.HEAL:
			source.heal(scaled)
			return [{"type": "heal", "amount": scaled, "text": "Healed %d" % scaled}]
		CardData.SELF_DAMAGE:
			# Paying, not being hit: bypasses block.
			source.pay_hp(raw)
			return [{"type": "pay_hp", "amount": raw, "text": "Paid %d hp" % raw}]
		CardData.STATUS:
			var status_kind = effect.get("status", Statuses.Kind.BURN)
			target.statuses.add(status_kind, scaled)
			return [
				{
					"type": "status",
					"target": target_label,
					"status": status_kind,
					"amount": scaled,
					"text": "+%d" % scaled,
				}
			]
		CardData.DOUBLE_DECAY:
			target.statuses.double_decay()
			return [{"type": "status", "target": target_label, "text": "Decay doubled"}]
		CardData.DRAW:
			var events: Array = []
			var deck := player_deck if source == player else examiner_deck
			for card in deck.draw(raw):
				events.append({"type": "draw", "card": card, "text": ""})
			return events
		CardData.MANA_NEXT:
			if source == player:
				_mana_bonus_next += raw
			return [{"type": "mana", "amount": raw, "text": "+%d mana next turn" % raw}]
		_:
			return []


func _check_end() -> Array:
	if finished:
		return []
	if examiner.is_down():
		finished = true
		player_won = true
		return [{"type": "battle_end", "won": true, "text": "You pass the examination."}]
	if player.is_down():
		finished = true
		player_won = false
		return [{"type": "battle_end", "won": false, "text": "You fail the examination."}]
	return []
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS. If `warded school dealt 5` fails with 6, the rounding is wrong —
`10 × 0.5` must round to 5, so scale before rounding, never round per effect twice.

- [ ] **Step 5: Commit and push**

```bash
git add -A
git commit -m "feat(battle): add turn resolution and the event log"
git push
```

---

## Phase 3 — Grading, the draft, and the run

### Task 10: `Grading` — the four terms

**Files:**
- Create: `scripts/core/Grading.gd`
- Test: `tests/test_grading.gd`

**Interfaces:**
- Consumes: nothing (takes plain numbers).
- Produces: `Grading.Grade` enum `S`, `A`, `B`, `C`, `F`; `Grading.letter(grade) -> String`; `Grading.score(params: Dictionary) -> Dictionary` returning `{"efficiency": float, "survival": float, "learning": float, "discovery": float, "total": float, "grade": Grade}`; `Grading.grade_for(total: float) -> Grade`; `Grading.draft_allowance(grade) -> int` returning `-1` for "all of it", else 5/3/1/0.

`params` keys: `won: bool`, `turns_taken: int`, `par_turns: int`, `hp_end: int`,
`hp_start: int`, `xp_banked: int`, `xp_par: int`, `weakness_known: bool`,
`distinct_schools: int`. A loss is an F regardless of the terms.

- [ ] **Step 1: Write the failing test `tests/test_grading.gd`**

```gdscript
extends TestCase

## Each term in isolation, then the thresholds. Note that a passing suite here does
## NOT prove S is reachable in real play — that is what tools/simulate.gd is for.


func suite_name() -> String:
	return "grading"


func _params(overrides: Dictionary) -> Dictionary:
	var p := {
		"won": true,
		"turns_taken": 10,
		"par_turns": 5,
		"hp_end": 0,
		"hp_start": 60,
		"xp_banked": 0,
		"xp_par": 15,
		"weakness_known": false,
		"distinct_schools": 0,
	}
	for key in overrides:
		p[key] = overrides[key]
	return p


func run() -> void:
	# Efficiency: full marks at or under par, scaling down after.
	almost(Grading.score(_params({"turns_taken": 5, "par_turns": 5}))["efficiency"], 25.0, "at par")
	almost(Grading.score(_params({"turns_taken": 3, "par_turns": 5}))["efficiency"], 25.0, "under par caps")
	almost(Grading.score(_params({"turns_taken": 10, "par_turns": 5}))["efficiency"], 12.5, "double par is half")

	# Survival: proportional to hit points kept.
	almost(Grading.score(_params({"hp_end": 60}))["survival"], 25.0, "untouched")
	almost(Grading.score(_params({"hp_end": 30}))["survival"], 12.5, "half hp")
	almost(Grading.score(_params({"hp_end": 0}))["survival"], 0.0, "no hp")

	# Learning: scored against an authored par, NOT against deck size.
	almost(Grading.score(_params({"xp_banked": 15, "xp_par": 15}))["learning"], 25.0, "at xp par")
	almost(Grading.score(_params({"xp_banked": 30, "xp_par": 15}))["learning"], 25.0, "over par caps")
	almost(Grading.score(_params({"xp_banked": 3, "xp_par": 15}))["learning"], 5.0, "a fifth of par")

	# Discovery: 15 for knowing the weakness, 10 spread over the five schools.
	almost(Grading.score(_params({"weakness_known": true}))["discovery"], 15.0, "weakness alone")
	almost(Grading.score(_params({"distinct_schools": 5}))["discovery"], 10.0, "all schools alone")
	almost(
		Grading.score(_params({"weakness_known": true, "distinct_schools": 5}))["discovery"],
		25.0,
		"both is full marks"
	)

	# A perfect battle totals 100 and earns an S.
	var perfect := Grading.score(
		_params(
			{
				"turns_taken": 5,
				"par_turns": 5,
				"hp_end": 60,
				"xp_banked": 15,
				"xp_par": 15,
				"weakness_known": true,
				"distinct_schools": 5,
			}
		)
	)
	almost(perfect["total"], 100.0, "perfect total")
	eq(perfect["grade"], Grading.Grade.S, "perfect is an S")

	# Thresholds.
	eq(Grading.grade_for(90.0), Grading.Grade.S, "90 is S")
	eq(Grading.grade_for(89.9), Grading.Grade.A, "just under 90 is A")
	eq(Grading.grade_for(75.0), Grading.Grade.A, "75 is A")
	eq(Grading.grade_for(60.0), Grading.Grade.B, "60 is B")
	eq(Grading.grade_for(40.0), Grading.Grade.C, "40 is C")
	eq(Grading.grade_for(39.9), Grading.Grade.F, "under 40 is F")
	eq(Grading.grade_for(0.0), Grading.Grade.F, "zero is F")

	# Losing is an F however well it otherwise went.
	var lost := Grading.score(
		_params(
			{
				"won": false,
				"turns_taken": 5,
				"par_turns": 5,
				"hp_end": 0,
				"xp_banked": 15,
				"weakness_known": true,
				"distinct_schools": 5,
			}
		)
	)
	eq(lost["grade"], Grading.Grade.F, "a loss is an F")

	# Letters and the draft allowance the grade buys.
	eq(Grading.letter(Grading.Grade.S), "S", "S letter")
	eq(Grading.draft_allowance(Grading.Grade.S), -1, "S takes the whole deck")
	eq(Grading.draft_allowance(Grading.Grade.A), 5, "A takes five")
	eq(Grading.draft_allowance(Grading.Grade.B), 3, "B takes three")
	eq(Grading.draft_allowance(Grading.Grade.C), 1, "C takes one")
	eq(Grading.draft_allowance(Grading.Grade.F), 0, "F takes nothing")

	# Guards against division by zero in authored content.
	almost(Grading.score(_params({"par_turns": 0}))["efficiency"], 25.0, "zero par does not divide")
	almost(Grading.score(_params({"xp_par": 0}))["learning"], 25.0, "zero xp par does not divide")
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `Grading` is not declared.

- [ ] **Step 3: Write `scripts/core/Grading.gd`**

```gdscript
class_name Grading
extends RefCounted

## Four terms of 25 points each. Efficiency and Survival reward winning cleanly;
## Learning and Discovery reward the two mechanics the game is named for. Grading on
## efficiency alone would make never learning the optimal strategy.

enum Grade { S, A, B, C, F }

const TERM_MAX := 25.0
const DISCOVERY_WEAKNESS := 15.0
const DISCOVERY_SCHOOLS := 10.0
const SCHOOL_COUNT := 5.0

const _LETTERS := {Grade.S: "S", Grade.A: "A", Grade.B: "B", Grade.C: "C", Grade.F: "F"}

## -1 means "the whole deck".
const _ALLOWANCE := {Grade.S: -1, Grade.A: 5, Grade.B: 3, Grade.C: 1, Grade.F: 0}


static func letter(grade: Grade) -> String:
	return _LETTERS.get(grade, "?")


static func draft_allowance(grade: Grade) -> int:
	return _ALLOWANCE.get(grade, 0)


static func grade_for(total: float) -> Grade:
	if total >= 90.0:
		return Grade.S
	if total >= 75.0:
		return Grade.A
	if total >= 60.0:
		return Grade.B
	if total >= 40.0:
		return Grade.C
	return Grade.F


static func score(params: Dictionary) -> Dictionary:
	var turns_taken := maxi(1, int(params.get("turns_taken", 1)))
	var par_turns := int(params.get("par_turns", 0))
	var efficiency := TERM_MAX
	if par_turns > 0:
		efficiency = TERM_MAX * clampf(float(par_turns) / float(turns_taken), 0.0, 1.0)

	var hp_start := maxi(1, int(params.get("hp_start", 1)))
	var hp_end := clampi(int(params.get("hp_end", 0)), 0, hp_start)
	var survival := TERM_MAX * (float(hp_end) / float(hp_start))

	var xp_par := int(params.get("xp_par", 0))
	var learning := TERM_MAX
	if xp_par > 0:
		learning = TERM_MAX * clampf(
			float(int(params.get("xp_banked", 0))) / float(xp_par), 0.0, 1.0
		)

	var discovery := 0.0
	if bool(params.get("weakness_known", false)):
		discovery += DISCOVERY_WEAKNESS
	var distinct := clampi(int(params.get("distinct_schools", 0)), 0, int(SCHOOL_COUNT))
	discovery += DISCOVERY_SCHOOLS * (float(distinct) / SCHOOL_COUNT)

	var total := efficiency + survival + learning + discovery
	var grade := Grade.F if not bool(params.get("won", false)) else grade_for(total)

	return {
		"efficiency": efficiency,
		"survival": survival,
		"learning": learning,
		"discovery": discovery,
		"total": total,
		"grade": grade,
	}
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 5: Commit and push**

```bash
git add -A
git commit -m "feat(grading): score battles on speed, survival, learning and discovery"
git push
```

---

### Task 11: `Draft` — Registration and the deck cap

**Files:**
- Create: `scripts/core/Draft.gd`
- Test: `tests/test_draft.gd`

**Interfaces:**
- Consumes: `CardInstance` (4), `CardData` (3), `Grading` (10).
- Produces: `Draft.cap_for(courses_passed: int) -> int` implementing `min(10 + courses_passed, 16)`; `Draft.new(own: Array, examiner_deck: Array[CardData], syllabus_card: CardData, grade)`; `var own: Array` (CardInstance), `var offered: Array` (CardInstance, freshly created at XP 0); `cap: int` set by the caller; `keep(selection: Array) -> Array` returning the new run deck, or `[]` if the selection is not exactly `cap` cards drawn from `own + offered`.

The syllabus card is always offered, whatever the grade. Cutting a card discards its
`CardInstance`, and with it the XP — that is the decision the screen exists to pose.

- [ ] **Step 1: Write the failing test `tests/test_draft.gd`**

```gdscript
extends TestCase


func suite_name() -> String:
	return "draft"


func _data(name: String) -> CardData:
	var d := CardData.new()
	d.card_name = name
	return d


func _own(n: int) -> Array:
	var out := []
	for i in n:
		out.append(CardInstance.new(_data("own%d" % i)))
	return out


func _pool(n: int) -> Array[CardData]:
	var out: Array[CardData] = []
	for i in n:
		out.append(_data("theirs%d" % i))
	return out


func run() -> void:
	# The cap grows per COURSE, not per tier, so the very first Registration can
	# already add a card rather than only swapping.
	eq(Draft.cap_for(0), 10, "starting cap is ten")
	eq(Draft.cap_for(1), 11, "grows after one course")
	eq(Draft.cap_for(5), 15, "grows to fifteen")
	eq(Draft.cap_for(6), 16, "saturates at sixteen")
	eq(Draft.cap_for(99), 16, "never exceeds sixteen")

	# Grade gates how much of their deck is offered.
	var syllabus := _data("syllabus")
	var s_draft := Draft.new(_own(10), _pool(8), syllabus, Grading.Grade.S)
	eq(s_draft.offered.size(), 9, "S offers the whole deck plus the syllabus card")
	var a_draft := Draft.new(_own(10), _pool(8), syllabus, Grading.Grade.A)
	eq(a_draft.offered.size(), 6, "A offers five plus the syllabus card")
	var b_draft := Draft.new(_own(10), _pool(8), syllabus, Grading.Grade.B)
	eq(b_draft.offered.size(), 4, "B offers three plus the syllabus card")
	var c_draft := Draft.new(_own(10), _pool(8), syllabus, Grading.Grade.C)
	eq(c_draft.offered.size(), 2, "C offers one plus the syllabus card")
	var f_draft := Draft.new(_own(10), _pool(8), syllabus, Grading.Grade.F)
	eq(f_draft.offered.size(), 1, "F still offers the syllabus card")

	# An F offers only the syllabus card, and it is the syllabus card.
	eq(f_draft.offered[0].data.card_name, "syllabus", "the syllabus card is always there")

	# You cannot copy more cards than the examiner had, nor more copies of one card
	# than it owned. The shipped tier-1 decks are 4-5 cards with repeats, so this is
	# the real shape of the input, not an edge case.
	var dup := _data("dup")
	var thin := Draft.new(_own(10), [dup, dup, dup, _data("other")], syllabus, Grading.Grade.A)
	eq(thin.offered.size(), 5, "four of theirs plus the syllabus, not the full allowance")
	var dup_count := 0
	for card in thin.offered:
		if card.data.card_name == "dup":
			dup_count += 1
	eq(dup_count, 3, "offered exactly the three copies they owned")

	# Offered cards arrive untrained.
	eq(s_draft.offered[0].xp, 0, "copied cards start at zero xp")

	# Asking for a deck of exactly the cap succeeds.
	var draft := Draft.new(_own(10), _pool(4), syllabus, Grading.Grade.S)
	draft.cap = 11
	var selection := draft.own.duplicate()
	selection.append(draft.offered[0])
	var kept := draft.keep(selection)
	eq(kept.size(), 11, "kept eleven")

	# Too many or too few is refused rather than silently truncated.
	eq(draft.keep(draft.own.duplicate()).size(), 0, "ten is not eleven")
	var too_many := draft.own.duplicate()
	too_many.append_array(draft.offered)
	eq(draft.keep(too_many).size(), 0, "more than the cap is refused")

	# A card that came from neither list is refused.
	var smuggled := draft.own.duplicate()
	smuggled[0] = CardInstance.new(_data("smuggled"))
	eq(draft.keep(smuggled).size(), 0, "cards must come from the pool")

	# Cutting a trained card destroys its XP — the point of the whole screen.
	var trained := Draft.new(_own(2), _pool(1), syllabus, Grading.Grade.S)
	trained.cap = 2
	trained.own[0].gain_xp()
	trained.own[0].gain_xp()
	eq(trained.own[0].xp, 2, "trained to two")
	var cut := trained.keep([trained.own[1], trained.offered[0]])
	eq(cut.size(), 2, "kept two")
	for card in cut:
		neq(card.data.card_name, "own0", "the trained card is gone")

	# Kept cards keep their XP.
	var retained := Draft.new(_own(2), _pool(0), syllabus, Grading.Grade.F)
	retained.cap = 2
	retained.own[0].gain_xp()
	var kept_trained := retained.keep([retained.own[0], retained.own[1]])
	eq(kept_trained.size(), 2, "kept both")
	var found_xp := 0
	for card in kept_trained:
		found_xp += card.xp
	eq(found_xp, 1, "the earned xp survived")
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `Draft` is not declared.

- [ ] **Step 3: Write `scripts/core/Draft.gd`**

```gdscript
class_name Draft
extends RefCounted

## Registration. Pools the player's deck with what their grade lets them copy off the
## defeated examiner, then keeps exactly `cap` cards.

const BASE_CAP := 10
const MAX_CAP := 16

var own: Array = []  ## Array[CardInstance] — the surviving run deck
var offered: Array = []  ## Array[CardInstance] — fresh copies, XP 0
var cap := BASE_CAP


## Grows per course passed rather than per tier: a per-tier cap equals the starting
## deck when the first Registration opens, leaving nothing to do.
static func cap_for(courses_passed: int) -> int:
	return mini(BASE_CAP + maxi(0, courses_passed), MAX_CAP)


func _init(own_cards: Array, examiner_deck: Array, syllabus_card: CardData, grade) -> void:
	own = own_cards.duplicate()

	# The syllabus card is always available, so a course always teaches something.
	if syllabus_card != null:
		offered.append(CardInstance.new(syllabus_card))

	var allowance: int = Grading.draft_allowance(grade)
	if allowance == 0:
		return

	# Distinct cards first, so a generous allowance against a repetitive deck does not
	# spend itself on duplicates before the player sees the interesting card. Building
	# the order must PRESERVE THE MULTISET: appending the whole deck after the distinct
	# pass would let a 4-card deck offer 5 cards, including more copies of one card
	# than the examiner ever owned. Every tier-1 examiner has a 4-5 card deck, so that
	# bug fires on the first Registration screen of every run.
	var seen := {}
	var ordered: Array = []
	var duplicates: Array = []
	for card in examiner_deck:
		if seen.has(card):
			duplicates.append(card)
		else:
			seen[card] = true
			ordered.append(card)
	ordered.append_array(duplicates)

	var limit := ordered.size() if allowance < 0 else mini(allowance, ordered.size())
	for i in limit:
		offered.append(CardInstance.new(ordered[i]))


## Returns the new run deck, or an empty array if the selection is illegal.
func keep(selection: Array) -> Array:
	if selection.size() != cap:
		return []
	var legal := {}
	for card in own:
		legal[card] = true
	for card in offered:
		legal[card] = true
	var chosen := {}
	for card in selection:
		if not legal.has(card) or chosen.has(card):
			return []
		chosen[card] = true
	return selection.duplicate()
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 5: Commit and push**

```bash
git add -A
git commit -m "feat(draft): add registration with a per-course deck cap"
git push
```

---

### Task 12: `CourseData` and `Catalog`

**Files:**
- Create: `scripts/data/CourseData.gd`, `scripts/core/Catalog.gd`
- Test: `tests/test_catalog.gd`

**Interfaces:**
- Consumes: `EnemyData` (7), `CardData` (3), `Grading` (10).
- Produces: `CourseData` with `course_name: String`, `tier: int`, `prerequisites: Array[CourseData]`, `prerequisites_required: int` (0 means all), `examiner: EnemyData`, `par_turns: int`, `xp_par: int`, `guaranteed_card_drop: CardData`, `is_honors: bool`, `honors_of: CourseData`; and `Catalog.new(courses: Array)` with `available(grades: Dictionary) -> Array`, `is_available(course, grades) -> bool`, `is_passed(course, grades) -> bool`, `revealed(grades) -> Array`, `validate() -> Array` returning a list of problem strings.

`grades` maps course name → `Grading.Grade`. A course is passed at C or better.
`validate()` asserts the two structural rules: no honors node is a prerequisite of any
required node, and every non-gate examiner is used by at least two courses.

- [ ] **Step 1: Write the failing test `tests/test_catalog.gd`**

```gdscript
extends TestCase


func suite_name() -> String:
	return "catalog"


func _enemy(name: String, gate := false) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_name = name
	e.is_gate = gate
	return e


func _course(name: String, tier: int, examiner: EnemyData, prereqs: Array, required := 0, honors := false) -> CourseData:
	var c := CourseData.new()
	c.course_name = name
	c.tier = tier
	c.examiner = examiner
	var typed: Array[CourseData] = []
	for p in prereqs:
		typed.append(p)
	c.prerequisites = typed
	c.prerequisites_required = required
	c.is_honors = honors
	c.par_turns = 5
	c.xp_par = 15
	return c


func run() -> void:
	var novice := _enemy("Novice")
	var monitor := _enemy("Hall Monitor")
	var proctor := _enemy("Proctor", true)

	var arcana := _course("Basic Arcana 101", 1, novice, [])
	var wardcraft := _course("Wardcraft 101", 1, monitor, [])
	var tutorial := _course("Tutorial 150", 1, monitor, [arcana], 0, true)
	# "any two of" is what prerequisites_required expresses.
	var inspection := _course("Proctor's Inspection", 1, proctor, [arcana, wardcraft], 2)
	var thesis := _course("Thesis 301", 3, novice, [inspection])

	var catalog := Catalog.new([arcana, wardcraft, tutorial, inspection, thesis])

	# With no grades, only the courses with no prerequisites are open.
	var open := catalog.available({})
	eq(open.size(), 2, "two entry courses")

	# A C is a pass; an F is not.
	eq(catalog.is_passed(arcana, {"Basic Arcana 101": Grading.Grade.C}), true, "C passes")
	eq(catalog.is_passed(arcana, {"Basic Arcana 101": Grading.Grade.F}), false, "F does not pass")
	eq(catalog.is_passed(arcana, {}), false, "unattempted is not passed")

	# "Any two of" needs two, not one.
	var one_pass := {"Basic Arcana 101": Grading.Grade.C}
	eq(catalog.is_available(inspection, one_pass), false, "one pass is not enough")
	var two_pass := {"Basic Arcana 101": Grading.Grade.C, "Wardcraft 101": Grading.Grade.B}
	eq(catalog.is_available(inspection, two_pass), true, "two passes opens the gate")

	# An honors node needs an A or better on its parent, and stays hidden below that.
	eq(catalog.is_available(tutorial, {"Basic Arcana 101": Grading.Grade.B}), false, "B hides honors")
	eq(catalog.is_available(tutorial, {"Basic Arcana 101": Grading.Grade.A}), true, "A reveals honors")
	eq(catalog.is_available(tutorial, {"Basic Arcana 101": Grading.Grade.S}), true, "S reveals honors")
	var revealed := catalog.revealed({"Basic Arcana 101": Grading.Grade.S})
	var names := []
	for course in revealed:
		names.append(course.course_name)
	check(names.has("Tutorial 150"), "honors node revealed")

	# A course already attempted is not offered again, pass or fail.
	eq(catalog.is_available(arcana, {"Basic Arcana 101": Grading.Grade.F}), false, "no retakes")

	# validate() catches an honors node used as a required prerequisite, which would
	# make the run unwinnable for a player who never scores an A.
	var blocked := _course("Blocked 301", 3, novice, [tutorial])
	var bad := Catalog.new([arcana, wardcraft, tutorial, blocked])
	var problems := bad.validate()
	var found := false
	for problem in problems:
		if problem.contains("honors"):
			found = true
	eq(found, true, "flagged the honors prerequisite")

	# validate() also catches an examiner the player only ever meets once, which
	# makes its Bestiary entry worthless.
	var lonely := _enemy("Lonely")
	var only := _course("Only 101", 1, lonely, [])
	var thin := Catalog.new([only])
	var thin_problems := thin.validate()
	var saw_once := false
	for problem in thin_problems:
		if problem.contains("Lonely"):
			saw_once = true
	eq(saw_once, true, "flagged the single-use examiner")

	# Gates are exempt from the repeat rule.
	var gate_only := Catalog.new([_course("Gate", 1, proctor, [])])
	for problem in gate_only.validate():
		check(not problem.contains("Proctor"), "gates are exempt from the repeat rule")
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `CourseData` is not declared.

- [ ] **Step 3: Write `scripts/data/CourseData.gd`**

```gdscript
class_name CourseData
extends Resource

## One node on the Course Catalog. Self-referential via `prerequisites`, which is
## legal for a Resource.

@export var course_name: String = ""
@export var tier: int = 1
@export var prerequisites: Array[CourseData] = []
## How many prerequisites are needed. 0 means all of them.
@export var prerequisites_required: int = 0
@export var examiner: EnemyData
@export var par_turns: int = 5
## Cards a player can expect to play in a par-length battle; the Learning term
## scores against this rather than against deck size.
@export var xp_par: int = 15
@export var guaranteed_card_drop: CardData
@export var is_honors: bool = false
@export var is_final: bool = false
```

- [ ] **Step 4: Write `scripts/core/Catalog.gd`**

```gdscript
class_name Catalog
extends RefCounted

## Course availability. `grades` maps course name -> Grading.Grade.

var courses: Array = []


func _init(course_list: Array) -> void:
	courses = course_list.duplicate()


## A pass is a C or better. An F is an attempt, not a pass.
func is_passed(course, grades: Dictionary) -> bool:
	if course == null or not grades.has(course.course_name):
		return false
	return grades[course.course_name] != Grading.Grade.F


func is_attempted(course, grades: Dictionary) -> bool:
	return course != null and grades.has(course.course_name)


## Honors nodes need an A or better on a prerequisite; everything else needs a pass.
func is_available(course, grades: Dictionary) -> bool:
	if course == null or is_attempted(course, grades):
		return false
	if course.prerequisites.is_empty():
		return true

	var threshold: Array = (
		[Grading.Grade.S, Grading.Grade.A]
		if course.is_honors
		else [Grading.Grade.S, Grading.Grade.A, Grading.Grade.B, Grading.Grade.C]
	)
	var met := 0
	for prerequisite in course.prerequisites:
		if grades.has(prerequisite.course_name) and grades[prerequisite.course_name] in threshold:
			met += 1

	var required: int = course.prerequisites_required
	if required <= 0:
		required = course.prerequisites.size()
	return met >= required


func available(grades: Dictionary) -> Array:
	var out: Array = []
	for course in courses:
		if is_available(course, grades):
			out.append(course)
	return out


## Available courses plus already-attempted ones, for drawing the map.
func revealed(grades: Dictionary) -> Array:
	var out: Array = []
	for course in courses:
		if is_available(course, grades) or is_attempted(course, grades):
			out.append(course)
	return out


## Structural rules the content must satisfy. Returns a list of problems; an empty
## list means the catalog is sound.
func validate() -> Array:
	var problems: Array = []

	# Rule 1: no honors node may gate a required node, or a player who never scores
	# an A hits a dead end and two-F permadeath makes the run unwinnable.
	for course in courses:
		if course.is_honors:
			continue
		for prerequisite in course.prerequisites:
			if prerequisite.is_honors:
				problems.append(
					(
						"%s requires the honors course %s"
						% [course.course_name, prerequisite.course_name]
					)
				)

	# Rule 2: every non-gate examiner must appear at least twice, or its Bestiary
	# entry can never be cashed in.
	var uses := {}
	var gates := {}
	for course in courses:
		if course.examiner == null:
			problems.append("%s has no examiner" % course.course_name)
			continue
		var name: String = course.examiner.enemy_name
		uses[name] = int(uses.get(name, 0)) + 1
		if course.examiner.is_gate or course.is_final:
			gates[name] = true
	for name in uses:
		if gates.has(name):
			continue
		if int(uses[name]) < 2:
			problems.append(
				"examiner %s is used by only %d course(s)" % [name, int(uses[name])]
			)

	return problems
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 6: Commit and push**

```bash
git add -A
git commit -m "feat(catalog): add courses, prerequisites and structural validation"
git push
```

---

### Task 13: `Run` — strikes, the F-on-zero-HP rule, and expulsion

**Files:**
- Create: `scripts/core/Run.gd`
- Test: `tests/test_run.gd`

**Interfaces:**
- Consumes: `CardInstance` (4), `Bestiary` (8), `Grading` (10), `Draft` (11).
- Produces: `Run.STARTING_HP == 60`, `Run.MAX_STRIKES == 2`; `Run.new(starting_deck: Array)`; `var hp`, `max_hp`, `strikes`, `grades: Dictionary`, `deck: Array`, `bestiary: Bestiary`, `courses_passed: int`, `expelled: bool`, `won: bool`; `deck_cap() -> int`; `record_result(course, grade, hp_end: int) -> Dictionary`; `is_over() -> bool`.

`record_result` is where §6.1 lives: an F restores HP to full, because failing an exam
is not dying. Two Fs is expulsion.

- [ ] **Step 1: Write the failing test `tests/test_run.gd`**

```gdscript
extends TestCase


func suite_name() -> String:
	return "run"


func _course(name: String, final := false) -> CourseData:
	var c := CourseData.new()
	c.course_name = name
	c.is_final = final
	return c


func _deck(n: int) -> Array:
	var out := []
	for i in n:
		var d := CardData.new()
		d.card_name = "c%d" % i
		out.append(CardInstance.new(d))
	return out


func run() -> void:
	var r := Run.new(_deck(10))
	eq(r.hp, 60, "starts at sixty")
	eq(r.strikes, 0, "no strikes")
	eq(r.deck_cap(), 10, "starting cap")
	eq(r.is_over(), false, "not over")

	# Passing banks the grade, counts the course, and grows the cap.
	r.record_result(_course("Basic Arcana 101"), Grading.Grade.B, 45)
	eq(r.grades["Basic Arcana 101"], Grading.Grade.B, "grade recorded")
	eq(r.courses_passed, 1, "one course passed")
	eq(r.deck_cap(), 11, "cap grew")
	eq(r.hp, 45, "hp carried over from the battle")
	eq(r.strikes, 0, "a pass is not a strike")

	# An F is a strike, does NOT count as a pass, and restores hit points: failing an
	# exam is not dying, so the cap does not grow and the run continues.
	var first_f := r.record_result(_course("Cantrips 101"), Grading.Grade.F, 0)
	eq(r.strikes, 1, "one strike")
	eq(r.courses_passed, 1, "an F is not a pass")
	eq(r.deck_cap(), 11, "cap did not grow on a failure")
	eq(r.hp, 60, "hit points restored after a failure")
	eq(r.expelled, false, "one F is survivable")
	eq(r.is_over(), false, "run continues")
	eq(first_f["strike"], true, "reported the strike")
	eq(first_f["expelled"], false, "not expelled yet")

	# The second F is expulsion — the only death condition in the game.
	var second_f := r.record_result(_course("Wardcraft 101"), Grading.Grade.F, 0)
	eq(r.strikes, 2, "two strikes")
	eq(r.expelled, true, "expelled")
	eq(r.is_over(), true, "run over")
	eq(second_f["expelled"], true, "reported the expulsion")

	# Passing the final wins the run.
	var w := Run.new(_deck(10))
	w.record_result(_course("Comprehensive Exam", true), Grading.Grade.A, 20)
	eq(w.won, true, "passing the final wins")
	eq(w.is_over(), true, "run over on a win")

	# Failing the final is a strike like any other, not an automatic loss.
	var f := Run.new(_deck(10))
	f.record_result(_course("Comprehensive Exam", true), Grading.Grade.F, 0)
	eq(f.won, false, "failing the final does not win")
	eq(f.strikes, 1, "one strike")
	eq(f.is_over(), false, "and the run goes on")

	# The cap saturates at sixteen however many courses are passed.
	var long_run := Run.new(_deck(10))
	for i in 12:
		long_run.record_result(_course("Course %d" % i), Grading.Grade.C, 60)
	eq(long_run.deck_cap(), 16, "cap saturates")

	# The bestiary belongs to the run and survives between battles.
	eq(long_run.bestiary is Bestiary, true, "run owns a bestiary")
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `Run` is not declared.

- [ ] **Step 3: Write `scripts/core/Run.gd`**

```gdscript
class_name Run
extends RefCounted

## One attempt at the curriculum. Holds everything that dies with the run.

const STARTING_HP := 60
const MAX_STRIKES := 2

var hp := STARTING_HP
var max_hp := STARTING_HP
var strikes := 0
var courses_passed := 0
var grades := {}  ## course name -> Grading.Grade
var deck: Array = []  ## Array[CardInstance]
var bestiary: Bestiary = Bestiary.new()
var current_course = null
var expelled := false
var won := false


func _init(starting_deck: Array) -> void:
	deck = starting_deck.duplicate()


func deck_cap() -> int:
	return Draft.cap_for(courses_passed)


## Records a finished battle. Returns what the report card needs to say.
##
## Dropping to zero hit points is an F, not death: hit points are restored and the
## run continues. Permadeath is the second F and nothing else.
func record_result(course, grade, hp_end: int) -> Dictionary:
	grades[course.course_name] = grade
	var struck := grade == Grading.Grade.F

	if struck:
		strikes += 1
		hp = max_hp  # you failed the exam; you did not die
		if strikes >= MAX_STRIKES:
			expelled = true
	else:
		courses_passed += 1
		hp = clampi(hp_end, 1, max_hp)  # a win never leaves you at zero
		if course.is_final:
			won = true

	return {
		"grade": grade,
		"strike": struck,
		"strikes": strikes,
		"expelled": expelled,
		"won": won,
		"hp": hp,
	}


func is_over() -> bool:
	return expelled or won
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 5: Commit and push**

```bash
git add -A
git commit -m "feat(run): add strikes, hp restoration on failure and expulsion"
git push
```

---

### Task 14: `SaveGame` — a round trip that preserves card XP

**Files:**
- Create: `scripts/core/SaveGame.gd`
- Test: `tests/test_save.gd`

**Interfaces:**
- Consumes: `Run` (13), `CardInstance` (4), `Bestiary` (8).
- Produces: `SaveGame.PATH == "user://run.json"`; `SaveGame.save(run) -> bool`; `SaveGame.load_run() -> Run` (null when absent or unreadable); `SaveGame.has_save() -> bool`; `SaveGame.delete() -> void`.

A `CardInstance` serialises as its `CardData` resource path plus an integer XP. An
evolved card serialises as the evolved resource's path, so it reloads already evolved.

- [ ] **Step 1: Write the failing test `tests/test_save.gd`**

```gdscript
extends TestCase


func suite_name() -> String:
	return "save"


func run() -> void:
	SaveGame.delete()
	eq(SaveGame.has_save(), false, "no save to begin with")
	eq(SaveGame.load_run(), null, "loading nothing returns null")

	var spark: CardData = load("res://resources/cards/spark.tres")
	var r := Run.new([CardInstance.new(spark), CardInstance.new(spark)])
	r.deck[0].gain_xp()
	r.deck[0].gain_xp()
	r.deck[0].gain_xp()
	var course := CourseData.new()
	course.course_name = "Basic Arcana 101"
	r.record_result(course, Grading.Grade.A, 42)
	var novice: EnemyData = load("res://resources/enemies/novice.tres")
	r.bestiary.record_hit(novice, novice.weak_school)

	eq(SaveGame.save(r), true, "saved")
	eq(SaveGame.has_save(), true, "save exists")

	var back: Run = SaveGame.load_run()
	check(back != null, "loaded")
	if back == null:
		return
	eq(back.hp, 42, "hp restored")
	eq(back.strikes, 0, "strikes restored")
	eq(back.courses_passed, 1, "courses restored")
	eq(back.grades["Basic Arcana 101"], Grading.Grade.A, "grade restored")
	eq(back.deck.size(), 2, "deck size restored")
	eq(back.bestiary.knows_weakness("Novice"), true, "bestiary restored")

	# THE POINT OF THIS SUITE: per-card XP must survive, or a reload silently
	# un-trains the player's deck.
	var xp_total := 0
	for card in back.deck:
		xp_total += card.xp
	eq(xp_total, 3, "card xp survived the round trip")

	# An evolved card reloads already evolved rather than reverting to its base form.
	var evolved_run := Run.new([CardInstance.new(spark)])
	for i in 5:
		evolved_run.deck[0].gain_xp()
	eq(evolved_run.deck[0].data.card_name, "Ember Lance", "evolved before saving")
	SaveGame.save(evolved_run)
	var evolved_back: Run = SaveGame.load_run()
	eq(evolved_back.deck[0].data.card_name, "Ember Lance", "still evolved after loading")

	# Expulsion clears the save.
	SaveGame.delete()
	eq(SaveGame.has_save(), false, "delete removed it")

	# A corrupt file does not crash the game.
	var f := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	eq(SaveGame.load_run(), null, "corrupt save loads as null")
	SaveGame.delete()
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `SaveGame` is not declared.

- [ ] **Step 3: Write `scripts/core/SaveGame.gd`**

```gdscript
class_name SaveGame
extends RefCounted

## Single-slot autosave. A CardInstance serialises as a resource path plus its XP, so
## an evolved card reloads already evolved.

const PATH := "user://run.json"


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func delete() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		# globalize_path does not resolve user:// on every platform; try both.
		if FileAccess.file_exists(PATH):
			var dir := DirAccess.open("user://")
			if dir != null:
				dir.remove("run.json")


static func save(run) -> bool:
	var cards: Array = []
	for card in run.deck:
		cards.append({"path": card.data.resource_path, "xp": card.xp})

	var grades := {}
	for name in run.grades:
		grades[name] = int(run.grades[name])

	var payload := {
		"version": 1,
		"hp": run.hp,
		"max_hp": run.max_hp,
		"strikes": run.strikes,
		"courses_passed": run.courses_passed,
		"expelled": run.expelled,
		"won": run.won,
		"grades": grades,
		"deck": cards,
		"bestiary": run.bestiary.to_dict(),
	}

	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


static func load_run():
	if not has_save():
		return null
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return null

	var cards: Array = []
	for entry in parsed.get("deck", []):
		var path: String = str(entry.get("path", ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		var data: CardData = load(path)
		if data == null:
			continue
		cards.append(CardInstance.new(data, int(entry.get("xp", 0))))

	var run := Run.new(cards)
	run.hp = int(parsed.get("hp", Run.STARTING_HP))
	run.max_hp = int(parsed.get("max_hp", Run.STARTING_HP))
	run.strikes = int(parsed.get("strikes", 0))
	run.courses_passed = int(parsed.get("courses_passed", 0))
	run.expelled = bool(parsed.get("expelled", false))
	run.won = bool(parsed.get("won", false))
	for name in parsed.get("grades", {}):
		run.grades[name] = int(parsed["grades"][name])
	run.bestiary = Bestiary.from_dict(parsed.get("bestiary", {}))
	return run
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 5: Commit and push**

```bash
git add -A
git commit -m "feat(save): add a single-slot autosave that preserves card xp"
git push
```

---

### Task 15: `ContentLibrary` and the three thin autoloads

**Files:**
- Create: `scripts/data/ContentLibrary.gd`, `resources/content_library.tres`, `scripts/auto/GameManager.gd`, `scripts/auto/DeckManager.gd`, `scripts/auto/GradeManager.gd`
- Modify: `project.godot` — add the `[autoload]` section
- Test: `tests/test_autoloads.gd`

**Interfaces:**
- Consumes: everything in Phases 1–3.
- Produces: `ContentLibrary` with `@export var cards: Array[CardData]`, `enemies: Array[EnemyData]`, `courses: Array[CourseData]`, `starting_deck: Array[CardData]`, and `card_named(name) -> CardData`, `enemy_named(name) -> EnemyData`, `course_named(name) -> CourseData`, `catalog() -> Catalog`. Autoloads `GameManager` (`.run`, `start_new_run()`, `strikes`, `save()`, `load_existing()`, `abandon()`), `DeckManager` (`.deck`, `begin_battle(cards, rng)`), `GradeManager` (`score(params)`, `letter(grade)`).

The autoloads hold the current instance and forward. They contain no rules, so no test
needs to reset them.

- [ ] **Step 1: Write the failing test `tests/test_autoloads.gd`**

```gdscript
extends TestCase

## The autoloads exist under the names the brief asks for, but hold no rules. A test
## that needs a Run constructs one directly; nothing here resets a global.


func suite_name() -> String:
	return "autoloads"


func run() -> void:
	var library: ContentLibrary = load("res://resources/content_library.tres")
	check(library != null, "content library loads")
	if library == null:
		return
	check(library.cards.size() > 0, "library indexes cards")
	check(library.starting_deck.size() > 0, "library declares a starting deck")
	var spark := library.card_named("Spark")
	check(spark != null, "found spark by name")
	eq(library.card_named("Nonexistent"), null, "missing card is null")

	# GradeManager is stateless: it forwards to Grading and holds nothing.
	var scored: Dictionary = GradeManager.score(
		{
			"won": true,
			"turns_taken": 5,
			"par_turns": 5,
			"hp_end": 60,
			"hp_start": 60,
			"xp_banked": 15,
			"xp_par": 15,
			"weakness_known": true,
			"distinct_schools": 5,
		}
	)
	eq(scored["grade"], Grading.Grade.S, "forwarded to Grading")
	eq(GradeManager.letter(Grading.Grade.S), "S", "forwarded the letter")

	# GameManager holds the current Run and forwards to it.
	GameManager.abandon()
	eq(GameManager.run, null, "no run after abandoning")
	eq(GameManager.strikes(), 0, "strikes with no run is zero")
	GameManager.start_new_run(library)
	check(GameManager.run != null, "started a run")
	eq(GameManager.run.deck.size(), library.starting_deck.size(), "dealt the starting deck")
	eq(GameManager.strikes(), 0, "fresh run has no strikes")

	# DeckManager holds the current battle piles.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	DeckManager.begin_battle(GameManager.run.deck, rng)
	check(DeckManager.deck != null, "battle deck built")
	eq(DeckManager.deck.total(), GameManager.run.deck.size(), "all cards in the piles")
	GameManager.abandon()
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `ContentLibrary` and the autoloads do not exist.

- [ ] **Step 3: Write `scripts/data/ContentLibrary.gd`**

```gdscript
class_name ContentLibrary
extends Resource

## One index over all content. Adding a card means adding a .tres and listing it
## here; nothing in the rules layer changes.

@export var cards: Array[CardData] = []
@export var enemies: Array[EnemyData] = []
@export var courses: Array[CourseData] = []
@export var starting_deck: Array[CardData] = []


func card_named(name: String) -> CardData:
	for card in cards:
		if card != null and card.card_name == name:
			return card
	return null


func enemy_named(name: String) -> EnemyData:
	for enemy in enemies:
		if enemy != null and enemy.enemy_name == name:
			return enemy
	return null


func course_named(name: String) -> CourseData:
	for course in courses:
		if course != null and course.course_name == name:
			return course
	return null


func catalog() -> Catalog:
	return Catalog.new(courses)


## Fresh CardInstances for a new run.
func new_starting_deck() -> Array:
	var out: Array = []
	for card in starting_deck:
		out.append(CardInstance.new(card))
	return out
```

- [ ] **Step 4: Write the three autoloads**

`scripts/auto/GameManager.gd`:

```gdscript
extends Node

## Holds the current Run and forwards to it. No rules live here: keeping state out of
## the singletons is what lets every suite construct a Run directly.

var run: Run = null


func start_new_run(library: ContentLibrary) -> Run:
	run = Run.new(library.new_starting_deck())
	return run


func load_existing() -> Run:
	run = SaveGame.load_run()
	return run


func save() -> bool:
	if run == null:
		return false
	return SaveGame.save(run)


func abandon() -> void:
	run = null
	SaveGame.delete()


func strikes() -> int:
	return 0 if run == null else run.strikes


func deck_cap() -> int:
	return Draft.BASE_CAP if run == null else run.deck_cap()
```

`scripts/auto/DeckManager.gd`:

```gdscript
extends Node

## Holds the current battle's piles and forwards to them.

var deck: Deck = null


func begin_battle(cards: Array, rng: RandomNumberGenerator = null) -> Deck:
	deck = Deck.new(cards, rng)
	return deck


func end_battle() -> void:
	deck = null


func hand() -> Array:
	return [] if deck == null else deck.hand
```

`scripts/auto/GradeManager.gd`:

```gdscript
extends Node

## Stateless. Exists because the brief names it; forwards to Grading.


func score(params: Dictionary) -> Dictionary:
	return Grading.score(params)


func letter(grade) -> String:
	return Grading.letter(grade)


func draft_allowance(grade) -> int:
	return Grading.draft_allowance(grade)
```

- [ ] **Step 5: Register the autoloads in `project.godot`**

Add this section:

```ini
[autoload]

GameManager="*res://scripts/auto/GameManager.gd"
DeckManager="*res://scripts/auto/DeckManager.gd"
GradeManager="*res://scripts/auto/GradeManager.gd"
```

The leading `*` makes each a singleton. Autoloads are available to
`--script` runs, so the suite can call them.

- [ ] **Step 6: Write `resources/content_library.tres`**

Index only what exists so far — Task 16 rewrites this with the full set.

```ini
[gd_resource type="Resource" script_class="ContentLibrary" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/data/ContentLibrary.gd" id="1"]
[ext_resource type="Resource" path="res://resources/cards/spark.tres" id="2"]
[ext_resource type="Resource" path="res://resources/cards/ember_lance.tres" id="3"]

[resource]
script = ExtResource("1")
cards = [ExtResource("2"), ExtResource("3")]
enemies = []
courses = []
starting_deck = [ExtResource("2"), ExtResource("2"), ExtResource("2"), ExtResource("2")]
```

- [ ] **Step 7: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 8: Commit and push**

```bash
git add -A
git commit -m "feat(core): add the content library and three thin autoloads"
git push
```

---

## Phase 4 — Content

### Task 16: Generate the 48 cards from one table

Forty-eight hand-written `.tres` files drift. Instead one generator holds the table
from spec §11, writes the resources, and is re-runnable; the output is committed.

**Files:**
- Create: `tools/generate_content.gd`, `resources/cards/*.tres` (48, generated)
- Delete: `resources/cards/spark.tres`, `resources/cards/ember_lance.tres` (regenerated by the table)
- Modify: `resources/content_library.tres`, `tests/test_content.gd`

**Interfaces:**
- Consumes: `CardData` (3).
- Produces: 48 card resources at `resources/cards/<snake_case_name>.tres`; every base card's `evolved_card` resolves and every evolved card is terminal.

- [ ] **Step 1: Extend `tests/test_content.gd` to demand the whole set**

Replace the file with this. It keeps the Spark assertions and adds set-wide integrity.

```gdscript
extends TestCase

## Content integrity across the whole card set. These checks are what make it safe to
## add a card by adding a .tres.


func suite_name() -> String:
	return "content"


func _library() -> ContentLibrary:
	return load("res://resources/content_library.tres")


func run() -> void:
	var library := _library()
	check(library != null, "content library loads")
	if library == null:
		return

	eq(library.cards.size(), 48, "twenty-four base cards plus twenty-four evolutions")

	var base_count := 0
	var names := {}
	for card in library.cards:
		check(card != null, "no null card in the library")
		if card == null:
			continue
		check(card.card_name != "", "every card is named")
		check(not names.has(card.card_name), "card name %s is unique" % card.card_name)
		names[card.card_name] = true
		check(card.cost >= 0 and card.cost <= 3, "%s costs 0-3" % card.card_name)
		check(card.effects.size() > 0, "%s does something" % card.card_name)
		check(card.art_id != "", "%s declares an art id" % card.card_name)
		for effect in card.effects:
			check(effect.has("kind"), "%s effect declares a kind" % card.card_name)
		if not card.is_fully_evolved():
			base_count += 1
			neq(card.evolved_card, card, "%s does not evolve into itself" % card.card_name)
			check(
				card.evolved_card.is_fully_evolved(),
				"%s evolves into a terminal card" % card.card_name
			)
			eq(card.school, card.evolved_card.school, "%s keeps its school" % card.card_name)
			eq(
				card.art_id,
				card.evolved_card.art_id,
				"%s shares art with its evolution" % card.card_name
			)
	eq(base_count, 24, "exactly twenty-four cards can evolve")

	# Every .tres under resources/ must load, including any the library does not index.
	# `--import` scans assets but does not eagerly load an unreferenced .tres, so a
	# broken orphan is invisible to check.sh's import step and only this walk finds it.
	for dir_name in ["cards", "enemies", "courses"]:
		var dir := DirAccess.open("res://resources/%s" % dir_name)
		check(dir != null, "resources/%s exists" % dir_name)
		if dir == null:
			continue
		for file in dir.get_files():
			if not file.ends_with(".tres"):
				continue
			var path := "res://resources/%s/%s" % [dir_name, file]
			check(load(path) != null, "%s loads" % path)

	# Status effects must name a real Statuses.Kind. The generator hardcodes the enum
	# values as integers, so nothing else would notice them drifting out of order and
	# silently applying Chill where Burn was meant.
	var valid_kinds := Statuses.Kind.values()
	for card in library.cards:
		for effect in card.effects:
			if effect.get("kind", "") != CardData.STATUS:
				continue
			check(effect.has("status"), "%s status effect names a kind" % card.card_name)
			check(
				effect.get("status", -1) in valid_kinds,
				"%s status %s is a real Statuses.Kind" % [card.card_name, effect.get("status", -1)]
			)

	# Every school is represented, or a deck cannot be built in it.
	var by_school := {}
	for card in library.cards:
		by_school[card.school] = int(by_school.get(card.school, 0)) + 1
	eq(by_school.size(), 5, "all five schools have cards")

	# Spot-check the table against the spec.
	var spark := library.card_named("Spark")
	check(spark != null, "spark exists")
	if spark != null:
		eq(spark.cost, 1, "spark costs one")
		eq(spark.effects[0]["amount"], 6, "spark deals six")
		eq(spark.evolved_card.card_name, "Ember Lance", "spark evolves into ember lance")
		eq(spark.evolved_card.effects[0]["amount"], 10, "ember lance deals ten")

	# The starting deck is the ten cards the spec names.
	eq(library.starting_deck.size(), 10, "ten starting cards")
	var starting := {}
	for card in library.starting_deck:
		starting[card.card_name] = int(starting.get(card.card_name, 0)) + 1
	eq(starting.get("Spark", 0), 4, "four sparks")
	eq(starting.get("Guard", 0), 4, "four guards")
	eq(starting.get("Ink Blot", 0), 2, "two ink blots")
```

- [ ] **Step 2: Run it and watch it fail**

```bash
./tools/check.sh
```

Expected: FAIL — the library holds 2 cards, not 48.

- [ ] **Step 3: Write `tools/generate_content.gd`**

The table is spec §11 transcribed. `E()` builds one effect dictionary. Each row is
`[name, school, cost, effects, evolved_name, flags]`; the evolved row follows its base.

```gdscript
extends SceneTree

## Writes resources/cards/*.tres from the table below, which is spec section 11.
## Re-runnable: it overwrites. Run with
##   godot --headless --path . --script tools/generate_content.gd

const OUT_DIR := "res://resources/cards"

const CINDER := 0
const FROST := 1
const INK := 2
const ROT := 3
const WARD := 4

# Statuses.Kind: BURN 0, CHILL 1, BLOT 2, DECAY 3
const BURN := 0
const CHILL := 1
const BLOT := 2
const DECAY := 3


static func dmg(n: int) -> Dictionary:
	return {"kind": "damage", "amount": n}


static func blk(n: int) -> Dictionary:
	return {"kind": "block", "amount": n}


static func heal(n: int) -> Dictionary:
	return {"kind": "heal", "amount": n}


static func status(kind: int, n: int) -> Dictionary:
	return {"kind": "status", "status": kind, "amount": n}


static func draw(n: int) -> Dictionary:
	return {"kind": "draw", "amount": n}


static func mana(n: int) -> Dictionary:
	return {"kind": "mana_next", "amount": n}


static func pay(n: int) -> Dictionary:
	return {"kind": "self_damage", "amount": n}


static func chilled(n: int) -> Dictionary:
	return {"kind": "bonus_if_chilled", "amount": n}


static func warded(n: int) -> Dictionary:
	return {"kind": "bonus_if_ward_played", "amount": n}


static func doubling() -> Dictionary:
	return {"kind": "double_decay"}


## [base_name, evolved_name, school, art, base_cost, base_effects, evo_cost,
##  evo_effects, exhaust, retain]
func table() -> Array:
	return [
		# Cinder
		["Spark", "Ember Lance", CINDER, "spark", 1, [dmg(6)], 1, [dmg(10)], false, false],
		["Kindle", "Conflagration", CINDER, "kindle", 1, [status(BURN, 3)], 1, [status(BURN, 6)], false, false],
		["Scorch Notes", "Immolate Notes", CINDER, "scorch_notes", 2, [dmg(11)], 2, [dmg(17)], false, false],
		["Cinder Burst", "Pyre Burst", CINDER, "cinder_burst", 2, [dmg(5), status(BURN, 3)], 2, [dmg(8), status(BURN, 5)], false, false],
		["Final Recitation", "Valedictory Blaze", CINDER, "final_recitation", 3, [dmg(20)], 3, [dmg(30)], true, false],
		# Frost
		["Frost Lance", "Rime Lance", FROST, "frost_lance", 1, [dmg(5), status(CHILL, 1)], 1, [dmg(8), status(CHILL, 1)], false, false],
		["Hoarfrost", "Deep Hoarfrost", FROST, "hoarfrost", 1, [status(CHILL, 2)], 1, [status(CHILL, 3), dmg(3)], false, false],
		["Glass Shard", "Mirror Shard", FROST, "glass_shard", 2, [dmg(9), chilled(4)], 2, [dmg(13), chilled(6)], false, false],
		["Numb the Hall", "Still the Hall", FROST, "numb_the_hall", 2, [status(CHILL, 2), blk(6)], 2, [status(CHILL, 3), blk(10)], false, false],
		["Winter Term", "Long Winter", FROST, "winter_term", 3, [dmg(12), status(CHILL, 4)], 3, [dmg(18), status(CHILL, 5)], false, false],
		# Ink
		["Ink Blot", "Spilled Ledger", INK, "ink_blot", 1, [status(BLOT, 1)], 1, [status(BLOT, 2)], false, false],
		["Marginalia", "Copious Marginalia", INK, "marginalia", 1, [draw(2)], 0, [draw(2)], false, false],
		["Cite Source", "Cite Chapter & Verse", INK, "cite_source", 1, [dmg(4), draw(1)], 1, [dmg(6), draw(2)], false, false],
		["Cram", "All-Nighter", INK, "cram", 2, [mana(2)], 1, [mana(2)], false, false],
		["Thesis Statement", "Defended Thesis", INK, "thesis_statement", 3, [dmg(8), draw(3)], 2, [dmg(12), draw(3)], false, false],
		# Rot
		["Rot Seed", "Blightseed", ROT, "rot_seed", 1, [status(DECAY, 4)], 1, [status(DECAY, 6)], false, false],
		["Bitter Recall", "Bitter Mastery", ROT, "bitter_recall", 1, [pay(3), dmg(12)], 1, [pay(2), dmg(18)], false, false],
		["Necrology Note", "Necrology Thesis", ROT, "necrology_note", 2, [dmg(5), status(DECAY, 5)], 2, [dmg(8), status(DECAY, 8)], false, false],
		["Feed the Curriculum", "Feed the Faculty", ROT, "feed_the_curriculum", 2, [pay(5), doubling()], 2, [pay(3), doubling(), draw(1)], false, false],
		# Ward
		["Guard", "Bulwark", WARD, "guard", 1, [blk(6)], 1, [blk(10)], false, false],
		["Rimeward", "Aegis Ward", WARD, "rimeward", 1, [blk(5)], 1, [blk(8)], false, true],
		["Study Break", "Restorative Study", WARD, "study_break", 2, [heal(8)], 2, [heal(14)], false, false],
		["Warded Bracers", "Sigil Bracers", WARD, "warded_bracers", 2, [blk(10), warded(4)], 2, [blk(14), warded(6)], false, false],
		["Honours Sigil", "Valedictory Sigil", WARD, "honours_sigil", 3, [blk(18), heal(6)], 3, [blk(24), heal(10)], false, false],
	]


static func slug(name: String) -> String:
	var out := name.to_lower()
	out = out.replace("&", "and")
	out = out.replace("-", "_")
	var cleaned := ""
	for i in out.length():
		var c := out[i]
		if c.is_valid_identifier() or c == "_" or (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			cleaned += c
		elif c == " ":
			cleaned += "_"
	while cleaned.contains("__"):
		cleaned = cleaned.replace("__", "_")
	return cleaned


func make_card(name: String, school: int, cost: int, effects: Array, art: String, exhaust: bool, retain: bool) -> CardData:
	var card := CardData.new()
	card.card_name = name
	card.school = school
	card.cost = cost
	var typed: Array[Dictionary] = []
	for e in effects:
		typed.append(e)
	card.effects = typed
	card.art_id = "cards/%s" % art
	card.exhaust = exhaust
	card.retain = retain
	card.xp_to_evolve = 5
	return card


func _process(_delta: float) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var written := 0
	for row in table():
		var base_name: String = row[0]
		var evo_name: String = row[1]
		var school: int = row[2]
		var art: String = row[3]

		# The evolved form is written first, so the base card can reference it.
		var evolved := make_card(evo_name, school, row[6], row[7], art, row[8], row[9])
		var evo_path := "%s/%s.tres" % [OUT_DIR, slug(evo_name)]
		var evo_err := ResourceSaver.save(evolved, evo_path)
		if evo_err != OK:
			printerr("failed to write %s: %d" % [evo_path, evo_err])
			quit(1)
			return true
		written += 1

		var base := make_card(base_name, school, row[4], row[5], art, row[8], row[9])
		base.evolved_card = load(evo_path)
		var base_path := "%s/%s.tres" % [OUT_DIR, slug(base_name)]
		var base_err := ResourceSaver.save(base, base_path)
		if base_err != OK:
			printerr("failed to write %s: %d" % [base_path, base_err])
			quit(1)
			return true
		written += 1

	print("wrote %d card resources to %s" % [written, OUT_DIR])
	quit(0)
	return true
```

- [ ] **Step 4: Generate the cards**

```bash
rm -f resources/cards/spark.tres resources/cards/ember_lance.tres
godot --headless --path . --script tools/generate_content.gd
godot --headless --import --path . >/dev/null 2>&1
ls resources/cards | wc -l
```

Expected: `48`.

- [ ] **Step 5: Rewrite `resources/content_library.tres` to index all 48**

Writing 48 `ext_resource` lines by hand is error-prone. Add this to the end of
`tools/generate_content.gd`'s `_process`, before `quit(0)`, and re-run it:

```gdscript
	# Index everything just written, plus the starting deck the spec names.
	var library := ContentLibrary.new()
	var all: Array[CardData] = []
	for row in table():
		all.append(load("%s/%s.tres" % [OUT_DIR, slug(row[0])]))
		all.append(load("%s/%s.tres" % [OUT_DIR, slug(row[1])]))
	library.cards = all
	var start: Array[CardData] = []
	for i in 4:
		start.append(load("%s/spark.tres" % OUT_DIR))
	for i in 4:
		start.append(load("%s/guard.tres" % OUT_DIR))
	for i in 2:
		start.append(load("%s/ink_blot.tres" % OUT_DIR))
	library.starting_deck = start
	# Enemies and courses are filled in by Tasks 17 and 18; preserve them if present.
	var existing = load("res://resources/content_library.tres")
	if existing != null:
		library.enemies = existing.enemies
		library.courses = existing.courses
	ResourceSaver.save(library, "res://resources/content_library.tres")
	print("indexed %d cards, %d starting" % [library.cards.size(), library.starting_deck.size()])
```

Then:

```bash
godot --headless --path . --script tools/generate_content.gd
./tools/check.sh
```

- [ ] **Step 6: Fix `resources/enemies/novice.tres`**

It references the deleted `spark.tres` by the old path. The regenerated `spark.tres`
is at the same path, so it should still resolve — confirm with `./tools/check.sh` and
repoint it if the `combatant` suite fails to load the novice.

- [ ] **Step 7: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS, `content` reporting well over 200 checks.

- [ ] **Step 8: Commit and push**

```bash
git add -A
git commit -m "feat(content): generate the twenty-four cards and their evolutions"
git push
```

---

### Task 17: The nine examiners and their decks

**Files:**
- Create: `tools/generate_enemies.gd`, `resources/enemies/*.tres` (9, generated)
- Modify: `resources/content_library.tres`, `tests/test_content.gd`

**Interfaces:**
- Consumes: `EnemyData` (7), the card set (16).
- Produces: nine examiner resources — six regular, `Proctor` and `Vice-Chancellor` as gates, `Rector` as the final — with the weak/warded pairs from spec §11.

- [ ] **Step 1: Add examiner integrity checks to `tests/test_content.gd`**

Append to `run()`:

```gdscript
	# Examiners: six regular plus two gates plus the final.
	eq(library.enemies.size(), 9, "nine examiners")
	var gates := 0
	for enemy in library.enemies:
		check(enemy.enemy_name != "", "every examiner is named")
		check(enemy.max_hp > 0, "%s has hit points" % enemy.enemy_name)
		check(enemy.mana_per_turn > 0, "%s has mana" % enemy.enemy_name)
		check(enemy.deck.size() >= 3, "%s has a deck of at least three" % enemy.enemy_name)
		check(enemy.art_id != "", "%s declares art" % enemy.enemy_name)
		neq(enemy.weak_school, enemy.warded_school, "%s weak != warded" % enemy.enemy_name)
		for card in enemy.deck:
			check(card != null, "%s deck has no holes" % enemy.enemy_name)
			# An examiner must be able to afford at least one card, or it hesitates
			# forever and the battle cannot end.
		var affordable := false
		for card in enemy.deck:
			if card != null and card.cost <= enemy.mana_per_turn:
				affordable = true
		check(affordable, "%s can afford something in its own deck" % enemy.enemy_name)
		if enemy.is_gate:
			gates += 1
	eq(gates, 2, "two gate examiners")

	# Every school is somebody's weakness and somebody's ward, so no school is dead
	# weight and none is a universal answer.
	var weak_schools := {}
	var warded_schools := {}
	for enemy in library.enemies:
		weak_schools[enemy.weak_school] = true
		warded_schools[enemy.warded_school] = true
	eq(weak_schools.size(), 5, "all five schools are somebody's weakness")
	eq(warded_schools.size(), 5, "all five schools are somebody's ward")
```

- [ ] **Step 2: Run it and watch it fail**

```bash
./tools/check.sh
```

Expected: FAIL — the library indexes no examiners.

- [ ] **Step 3: Write `tools/generate_enemies.gd`**

```gdscript
extends SceneTree

## Writes resources/enemies/*.tres from spec section 11's roster. Gate and final decks
## hold EVOLVED cards, so a boss visibly plays cards the player does not have yet.

const OUT_DIR := "res://resources/enemies"
const CARDS := "res://resources/cards"

const CINDER := 0
const FROST := 1
const INK := 2
const ROT := 3
const WARD := 4


## [name, hp, mana, weak, warded, art, is_gate, deck card slugs]
func roster() -> Array:
	return [
		["Novice", 28, 2, INK, FROST, "novice", false,
			["spark", "spark", "kindle", "guard"]],
		["Glass Tutor", 34, 2, CINDER, INK, "glass_tutor", false,
			["ink_blot", "cite_source", "marginalia", "guard", "ink_blot"]],
		["Hall Monitor", 38, 2, ROT, WARD, "hall_monitor", false,
			["guard", "guard", "warded_bracers", "spark", "study_break"]],
		["Drillmaster", 42, 2, CINDER, FROST, "drillmaster", false,
			["frost_lance", "frost_lance", "hoarfrost", "glass_shard", "guard"]],
		["Alchemy Master", 46, 2, WARD, ROT, "alchemy_master", false,
			["rot_seed", "necrology_note", "rot_seed", "bitter_recall", "guard"]],
		["Battle Chanter", 44, 2, FROST, CINDER, "battle_chanter", false,
			["cinder_burst", "spark", "scorch_notes", "kindle", "guard"]],
		["Proctor", 60, 3, CINDER, WARD, "proctor", true,
			["bulwark", "aegis_ward", "rime_lance", "still_the_hall", "restorative_study"]],
		["Vice-Chancellor", 80, 3, FROST, INK, "vice_chancellor", true,
			["spilled_ledger", "blightseed", "necrology_thesis", "cite_chapter_and_verse", "bulwark"]],
		["Rector", 120, 3, ROT, WARD, "rector", true,
			["valedictory_blaze", "long_winter", "defended_thesis", "bitter_mastery",
			 "valedictory_sigil", "immolate_notes"]],
	]


func _process(_delta: float) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var enemies: Array[EnemyData] = []
	for row in roster():
		var enemy := EnemyData.new()
		enemy.enemy_name = row[0]
		enemy.max_hp = row[1]
		enemy.mana_per_turn = row[2]
		enemy.weak_school = row[3]
		enemy.warded_school = row[4]
		enemy.art_id = "entities/%s" % row[5]
		enemy.is_gate = row[6]
		var deck: Array[CardData] = []
		for slug in row[7]:
			var path := "%s/%s.tres" % [CARDS, slug]
			var card: CardData = load(path)
			if card == null:
				printerr("missing card %s for %s" % [path, enemy.enemy_name])
				quit(1)
				return true
			deck.append(card)
		enemy.deck = deck
		var out := "%s/%s.tres" % [OUT_DIR, row[5]]
		if ResourceSaver.save(enemy, out) != OK:
			printerr("failed to write %s" % out)
			quit(1)
			return true
		enemies.append(load(out))

	var library: ContentLibrary = load("res://resources/content_library.tres")
	library.enemies = enemies
	ResourceSaver.save(library, "res://resources/content_library.tres")
	print("wrote %d examiners" % enemies.size())
	quit(0)
	return true
```

- [ ] **Step 4: Generate and verify**

```bash
rm -f resources/enemies/novice.tres
godot --headless --path . --script tools/generate_enemies.gd
godot --headless --import --path . >/dev/null 2>&1
./tools/check.sh
```

Expected: PASS. If a `missing card` error names a slug, the slug does not match what
`generate_content.gd`'s `slug()` produced — run `ls resources/cards` and correct the
roster.

- [ ] **Step 5: Commit and push**

```bash
git add -A
git commit -m "feat(content): add the nine examiners and their decks"
git push
```

---

### Task 18: The fifteen courses, plus a headless full-run simulation

**Files:**
- Create: `tools/generate_courses.gd`, `resources/courses/*.tres` (15, generated), `tools/simulate.gd`, `tests/test_playthrough.gd`
- Modify: `resources/content_library.tres`, `tests/test_catalog.gd`

**Interfaces:**
- Consumes: `Catalog`/`CourseData` (12), examiners (17), `Battle` (9), `Grading` (10), `Run` (13), `Draft` (11).
- Produces: fifteen course resources matching spec §8.1 exactly, a `Catalog.validate()` that returns no problems for the shipped content, and `tools/simulate.gd` for balance work.

- [ ] **Step 1: Add a shipped-content assertion to `tests/test_catalog.gd`**

Append to `run()`:

```gdscript
	# The SHIPPED catalog must satisfy both structural rules. This is the assertion
	# that makes two-F permadeath fair.
	var library: ContentLibrary = load("res://resources/content_library.tres")
	eq(library.courses.size(), 15, "fifteen courses")
	var shipped := library.catalog()
	var shipped_problems := shipped.validate()
	for problem in shipped_problems:
		check(false, "shipped catalog problem: %s" % problem)
	eq(shipped_problems.size(), 0, "shipped catalog is structurally sound")

	# Three courses have no prerequisites, so a run always has somewhere to start.
	var entry := 0
	for course in library.courses:
		if course.prerequisites.is_empty():
			entry += 1
	eq(entry, 3, "three entry courses")

	# Exactly one final, and it is reachable at C throughout.
	var finals := 0
	for course in library.courses:
		if course.is_final:
			finals += 1
	eq(finals, 1, "one final")

	# Every course authors both pars, or grading divides by zero.
	for course in library.courses:
		check(course.par_turns > 0, "%s authors par_turns" % course.course_name)
		check(course.xp_par > 0, "%s authors xp_par" % course.course_name)
		check(course.examiner != null, "%s has an examiner" % course.course_name)
		if not course.is_final:
			check(
				course.guaranteed_card_drop != null,
				"%s has a syllabus card" % course.course_name
			)
```

- [ ] **Step 2: Run it and watch it fail**

```bash
./tools/check.sh
```

Expected: FAIL — no courses in the library.

- [ ] **Step 3: Write `tools/generate_courses.gd`**

The table is spec §8.1. `required` is 0 for "all of them" and 2 for "any two of".

```gdscript
extends SceneTree

## Writes resources/courses/*.tres from spec section 8.1. Prerequisites are written in
## dependency order so each course can load the ones before it.

const OUT_DIR := "res://resources/courses"
const CARDS := "res://resources/cards"
const ENEMIES := "res://resources/enemies"


## [slug, name, tier, examiner slug, par_turns, xp_par, syllabus slug,
##  prerequisite slugs, required, is_honors, is_final]
func table() -> Array:
	return [
		["basic_arcana_101", "Basic Arcana 101", 1, "novice", 5, 14, "spark", [], 0, false, false],
		["cantrips_101", "Cantrips 101", 1, "glass_tutor", 5, 14, "marginalia", [], 0, false, false],
		["wardcraft_101", "Wardcraft 101", 1, "hall_monitor", 6, 16, "guard", [], 0, false, false],
		["tutorial_150", "Tutorial 150", 1, "drillmaster", 6, 17, "hoarfrost",
			["basic_arcana_101", "cantrips_101", "wardcraft_101"], 1, true, false],
		["proctors_inspection", "Proctor's Inspection", 1, "proctor", 8, 22, "rimeward",
			["basic_arcana_101", "cantrips_101", "wardcraft_101"], 2, false, false],
		["pyromancy_201", "Pyromancy 201", 2, "battle_chanter", 7, 20, "cinder_burst",
			["proctors_inspection"], 0, false, false],
		["cryomancy_201", "Cryomancy 201", 2, "drillmaster", 7, 20, "frost_lance",
			["proctors_inspection"], 0, false, false],
		["necrology_201", "Necrology 201", 2, "alchemy_master", 8, 22, "rot_seed",
			["proctors_inspection"], 0, false, false],
		["marginalia_201", "Marginalia 201", 2, "glass_tutor", 7, 20, "ink_blot",
			["proctors_inspection"], 0, false, false],
		["fieldwork_250", "Fieldwork 250", 2, "battle_chanter", 8, 22, "final_recitation",
			["pyromancy_201", "cryomancy_201", "necrology_201", "marginalia_201"], 1, true, false],
		["midterm_review", "Midterm Review", 2, "vice_chancellor", 10, 28, "cram",
			["pyromancy_201", "cryomancy_201", "necrology_201", "marginalia_201"], 2, false, false],
		["thesis_301", "Thesis 301", 3, "alchemy_master", 9, 26, "thesis_statement",
			["midterm_review"], 0, false, false],
		["applied_wardcraft_301", "Applied Wardcraft 301", 3, "hall_monitor", 9, 26, "honours_sigil",
			["midterm_review"], 0, false, false],
		["viva_voce_350", "Viva Voce 350", 3, "novice", 9, 26, "winter_term",
			["thesis_301", "applied_wardcraft_301"], 1, true, false],
		["comprehensive_exam", "Comprehensive Exam", 3, "rector", 12, 34, "",
			["thesis_301", "applied_wardcraft_301"], 0, false, true],
	]


func _process(_delta: float) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# Two passes: write every course without prerequisites, then link them, because a
	# .tres cannot reference a file that does not exist yet.
	for row in table():
		var course := CourseData.new()
		course.course_name = row[1]
		course.tier = row[2]
		course.examiner = load("%s/%s.tres" % [ENEMIES, row[3]])
		course.par_turns = row[4]
		course.xp_par = row[5]
		if row[6] != "":
			course.guaranteed_card_drop = load("%s/%s.tres" % [CARDS, row[6]])
		course.prerequisites_required = row[8]
		course.is_honors = row[9]
		course.is_final = row[10]
		ResourceSaver.save(course, "%s/%s.tres" % [OUT_DIR, row[0]])

	var courses: Array[CourseData] = []
	for row in table():
		var path := "%s/%s.tres" % [OUT_DIR, row[0]]
		var course: CourseData = load(path)
		var prereqs: Array[CourseData] = []
		for slug in row[7]:
			prereqs.append(load("%s/%s.tres" % [OUT_DIR, slug]))
		course.prerequisites = prereqs
		ResourceSaver.save(course, path)
		courses.append(load(path))

	var library: ContentLibrary = load("res://resources/content_library.tres")
	library.courses = courses
	ResourceSaver.save(library, "res://resources/content_library.tres")

	var problems := Catalog.new(courses).validate()
	for problem in problems:
		printerr("catalog problem: %s" % problem)
	print("wrote %d courses, %d problems" % [courses.size(), problems.size()])
	quit(1 if problems.size() > 0 else 0)
	return true
```

- [ ] **Step 4: Generate the courses**

```bash
godot --headless --path . --script tools/generate_courses.gd
godot --headless --import --path . >/dev/null 2>&1
./tools/check.sh
```

Expected: `wrote 15 courses, 0 problems`, then PASS. A non-zero problem count means the
roster and the catalog disagree — fix the content, never the validator.

- [ ] **Step 5: Write `tests/test_playthrough.gd`**

Proves the whole loop runs headlessly end to end, which no unit suite does.

```gdscript
extends TestCase

## A full scripted run: pick an available course, fight it with a greedy policy,
## grade it, draft, repeat until the run ends. Catches integration breaks that every
## unit suite passes through.


func suite_name() -> String:
	return "playthrough"


func run() -> void:
	var library: ContentLibrary = load("res://resources/content_library.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var game := Run.new(library.new_starting_deck())
	var catalog := library.catalog()

	var battles := 0
	while not game.is_over() and battles < 30:
		var open := catalog.available(game.grades)
		if open.is_empty():
			break
		var course = open[0]
		var battle := Battle.new(game.deck, course.examiner, game.bestiary, rng)
		battle.start()

		# Greedy policy: play whatever is affordable, then end the turn.
		var guard := 0
		while not battle.finished and guard < 200:
			guard += 1
			var played := false
			for card in battle.player_deck.hand.duplicate():
				if battle.can_play(card):
					battle.play_card(card)
					played = true
					if battle.finished:
						break
			if battle.finished:
				break
			if not played or battle.player.mana <= 0:
				battle.end_turn()
		check(guard < 200, "battle terminated rather than looping")
		check(battle.finished, "battle reached an end state")

		var scored: Dictionary = Grading.score(
			{
				"won": battle.player_won,
				"turns_taken": battle.turns,
				"par_turns": course.par_turns,
				"hp_end": battle.player.hp,
				"hp_start": Run.STARTING_HP,
				"xp_banked": battle.xp_banked,
				"xp_par": course.xp_par,
				"weakness_known": game.bestiary.knows_weakness(course.examiner.enemy_name),
				"distinct_schools": battle.schools_played(),
			}
		)
		var result := game.record_result(course, scored["grade"], battle.player.hp)

		if not game.is_over() and battle.player_won:
			var draft := Draft.new(game.deck, course.examiner.deck, course.guaranteed_card_drop, scored["grade"])
			draft.cap = game.deck_cap()
			# Keep the cap's worth, preferring offered cards then own.
			var selection: Array = []
			for card in draft.offered:
				if selection.size() < draft.cap:
					selection.append(card)
			for card in draft.own:
				if selection.size() < draft.cap:
					selection.append(card)
			var kept := draft.keep(selection)
			check(kept.size() == draft.cap, "draft returned a legal deck of %d" % draft.cap)
			if kept.size() == draft.cap:
				game.deck = kept
		battles += 1

	check(battles > 0, "fought at least one battle")
	check(game.is_over() or catalog.available(game.grades).is_empty(), "run reached a terminal state")
	# The deck never exceeds its cap, however the run went.
	check(game.deck.size() <= 16, "deck stayed within the cap")
	print("    playthrough: %d battles, %d strikes, won=%s" % [battles, game.strikes, game.won])
```

- [ ] **Step 6: Run the suite and watch it pass**

Run `./tools/check.sh`; the runner finds the new suite automatically.
Expected: PASS. A hang means `Battle.end_turn` is not advancing — the `guard` counters
exist to fail rather than spin, so a `battle terminated` failure points at the bug.

- [ ] **Step 7: Write `tools/simulate.gd`**

```gdscript
extends SceneTree

## Plays N headless runs with the greedy policy and reports how far they got. Balance
## work only; the gate is check.sh.
##   godot --headless --path . --script tools/simulate.gd -- 20


func _process(_delta: float) -> bool:
	var args := OS.get_cmdline_user_args()
	var count := 10
	if args.size() > 0 and args[0].is_valid_int():
		count = args[0].to_int()

	var library: ContentLibrary = load("res://resources/content_library.tres")
	var wins := 0
	var total_courses := 0
	var grade_counts := {}

	for i in count:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var game := Run.new(library.new_starting_deck())
		var catalog := library.catalog()
		var guard := 0
		while not game.is_over() and guard < 30:
			guard += 1
			var open := catalog.available(game.grades)
			if open.is_empty():
				break
			var course = open[0]
			var battle := Battle.new(game.deck, course.examiner, game.bestiary, rng)
			battle.start()
			var turn_guard := 0
			while not battle.finished and turn_guard < 200:
				turn_guard += 1
				var played := false
				for card in battle.player_deck.hand.duplicate():
					if battle.can_play(card):
						battle.play_card(card)
						played = true
						if battle.finished:
							break
				if battle.finished:
					break
				if not played or battle.player.mana <= 0:
					battle.end_turn()
			var scored: Dictionary = Grading.score(
				{
					"won": battle.player_won,
					"turns_taken": battle.turns,
					"par_turns": course.par_turns,
					"hp_end": battle.player.hp,
					"hp_start": Run.STARTING_HP,
					"xp_banked": battle.xp_banked,
					"xp_par": course.xp_par,
					"weakness_known": game.bestiary.knows_weakness(course.examiner.enemy_name),
					"distinct_schools": battle.schools_played(),
				}
			)
			var letter := Grading.letter(scored["grade"])
			grade_counts[letter] = int(grade_counts.get(letter, 0)) + 1
			game.record_result(course, scored["grade"], battle.player.hp)
			if battle.player_won and not game.is_over():
				var draft := Draft.new(game.deck, course.examiner.deck, course.guaranteed_card_drop, scored["grade"])
				draft.cap = game.deck_cap()
				var selection: Array = []
				for card in draft.offered:
					if selection.size() < draft.cap:
						selection.append(card)
				for card in draft.own:
					if selection.size() < draft.cap:
						selection.append(card)
				var kept := draft.keep(selection)
				if kept.size() == draft.cap:
					game.deck = kept
		if game.won:
			wins += 1
		total_courses += game.courses_passed

	print("%d runs: %d wins, %.1f courses passed on average" % [count, wins, float(total_courses) / float(count)])
	print("grades: %s" % grade_counts)
	quit(0)
	return true
```

- [ ] **Step 8: Run a balance pass and record what it says**

```bash
godot --headless --path . --script tools/simulate.gd -- 20
```

Note the win rate and grade spread in the commit message. The greedy policy ignores
schools and weaknesses, so a low win rate is expected and not a bug — but if **no** run
passes a single course, or if S grades are impossible for every course, the numbers in
spec §6 need revisiting. Report that rather than silently retuning.

- [ ] **Step 9: Commit and push**

```bash
git add -A
git commit -m "feat(content): add the fifteen courses and a headless run simulation"
git push
```

---

## Phase 5 — Presentation

### Task 19: The theme and the procedural art fallback

Art lands in Task 26. Until then every sprite is painted at runtime, so the game is
playable from here on and a half-finished art set still renders.

**Files:**
- Create: `scripts/view/ArtFactory.gd`, `scripts/view/ArtLibrary.gd`, `tools/generate_theme.gd`, `resources/ui_theme.tres` (generated)
- Test: `tests/test_art.gd`

**Interfaces:**
- Consumes: `Schools` (1).
- Produces: `ArtLibrary.PAPER`, `INK`, `SLATE`, `GRAIN_A`, `GRAIN_B` colour constants; `ArtLibrary.texture(key: String, size: Vector2i) -> Texture2D` returning the imported sprite at `assets/sprites/<key>.png` when it exists and a painted fallback otherwise; `ArtLibrary.has_sprite(key) -> bool`; `ArtLibrary.missing_keys(keys: Array) -> Array`. `ArtFactory.card_face(school, size) -> ImageTexture`, `sigil(school, size)`, `figure(seed_text: String, size)`, `medallion(tier: int, size)`.

- [ ] **Step 1: Write the failing test `tests/test_art.gd`**

```gdscript
extends TestCase

## Art is optional per sprite. These checks are what let the game ship before any
## illustration exists, and what stop a typo'd art_id from silently falling back.


func suite_name() -> String:
	return "art"


func run() -> void:
	eq(ArtLibrary.PAPER, Color("#F7EADD"), "paper is the reference cream")
	eq(ArtLibrary.INK, Color("#000000"), "ink is black")

	# A key with no file still returns a usable texture.
	var missing := ArtLibrary.texture("cards/definitely_not_a_real_key", Vector2i(64, 96))
	check(missing != null, "fallback texture returned")
	eq(missing.get_width(), 64, "fallback respects the requested width")
	eq(missing.get_height(), 96, "fallback respects the requested height")
	eq(ArtLibrary.has_sprite("cards/definitely_not_a_real_key"), false, "reports no sprite")

	# Every school paints a distinct card face and sigil.
	var faces := {}
	for school in Schools.ALL:
		var face := ArtFactory.card_face(school, Vector2i(32, 48))
		check(face != null, "painted a face for %s" % Schools.display_name(school))
		faces[face.get_image().get_pixel(4, 4)] = true
		var sigil := ArtFactory.sigil(school, Vector2i(16, 16))
		check(sigil != null, "painted a sigil for %s" % Schools.display_name(school))
	eq(faces.size(), 5, "the five schools paint five distinct faces")

	# Figures are deterministic per name, so an examiner looks the same every battle.
	var a := ArtFactory.figure("Novice", Vector2i(24, 48))
	var b := ArtFactory.figure("Novice", Vector2i(24, 48))
	eq(a.get_image().get_pixel(12, 24), b.get_image().get_pixel(12, 24), "figures are stable")
	var c := ArtFactory.figure("Rector", Vector2i(24, 48))
	neq(a.get_image().get_pixel(12, 24), c.get_image().get_pixel(12, 24), "different names differ")

	# Every art_id the content declares is a key the library can serve, painted or not.
	var library: ContentLibrary = load("res://resources/content_library.tres")
	var keys := []
	for card in library.cards:
		keys.append(card.art_id)
	for enemy in library.enemies:
		keys.append(enemy.art_id)
	for key in keys:
		var texture := ArtLibrary.texture(key, Vector2i(16, 16))
		check(texture != null, "%s resolves to something drawable" % key)

	# The theme exists and is light, per spec 9.2.
	var theme: Theme = load("res://resources/ui_theme.tres")
	check(theme != null, "theme loads")
	if theme != null:
		check(theme.default_font_size >= 24, "font is thumb-legible at 1080 wide")

	# Reports what art is still procedural, which drives the manifest in Task 25.
	var still_missing := ArtLibrary.missing_keys(keys)
	print("    art: %d of %d keys still procedural" % [still_missing.size(), keys.size()])
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `ArtLibrary` is not declared.

- [ ] **Step 3: Write `scripts/view/ArtFactory.gd`**

The register is flat mid-century screenprint: flat inks, no gradients, no outlines,
plus grain. Paint grain as scattered single pixels of the grain greys — that reads as
risograph at small sizes and costs nothing.

```gdscript
class_name ArtFactory
extends RefCounted

## Paints the procedural fallbacks. Flat shapes and stipple grain, never gradients:
## the art direction is 1950s screenprint, and flat shapes read at card size.


static func _grain(image: Image, rng: RandomNumberGenerator, density := 0.06) -> void:
	var count := int(float(image.get_width() * image.get_height()) * density)
	for _i in count:
		var x := rng.randi_range(0, image.get_width() - 1)
		var y := rng.randi_range(0, image.get_height() - 1)
		var grey := ArtLibrary.GRAIN_A if rng.randf() < 0.5 else ArtLibrary.GRAIN_B
		image.set_pixel(x, y, image.get_pixel(x, y).lerp(grey, 0.35))


static func _rng_for(text: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	return rng


## A card's illustration area: the school's ink as a large organic field on paper.
static func card_face(school, size: Vector2i) -> ImageTexture:
	var image := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	image.fill(ArtLibrary.PAPER)
	var ink: Color = Schools.colour(school)
	var rng := _rng_for(Schools.display_name(school))

	# One big rounded field, inset like a printed plate rather than bleeding out.
	var inset := maxi(1, size.x / 8)
	var radius := float(size.x) * 0.34
	var centre := Vector2(float(size.x) * 0.5, float(size.y) * 0.45)
	for y in size.y:
		for x in size.x:
			if x < inset or x >= size.x - inset or y < inset:
				continue
			if Vector2(x, y).distance_to(centre) <= radius:
				image.set_pixel(x, y, ink)

	# A single stippled celestial glyph, as in the reference.
	var glyph := Vector2(float(size.x) * 0.72, float(size.y) * 0.22)
	var glyph_r := maxf(1.0, float(size.x) * 0.09)
	for y in size.y:
		for x in size.x:
			if Vector2(x, y).distance_to(glyph) <= glyph_r:
				image.set_pixel(x, y, ArtLibrary.GRAIN_A)

	_grain(image, rng)
	return ImageTexture.create_from_image(image)


## The school's mark: a small flat shape, distinct per school by silhouette as well as
## by colour, so it survives a colourblind player.
static func sigil(school, size: Vector2i) -> ImageTexture:
	var image := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ink: Color = Schools.colour(school)
	var w := size.x
	var h := size.y
	match school:
		Schools.School.CINDER:  # upward triangle
			for y in h:
				var half := int(float(y) / float(h) * float(w) * 0.5)
				for x in range(w / 2 - half, w / 2 + half + 1):
					if x >= 0 and x < w:
						image.set_pixel(x, h - 1 - y, ink)
		Schools.School.FROST:  # diamond
			for y in h:
				var d := absi(y - h / 2)
				var half := (h / 2 - d) * w / maxi(1, h)
				for x in range(w / 2 - half, w / 2 + half + 1):
					if x >= 0 and x < w:
						image.set_pixel(x, y, ink)
		Schools.School.INK:  # filled circle
			var r := float(mini(w, h)) * 0.45
			for y in h:
				for x in w:
					if Vector2(x, y).distance_to(Vector2(w, h) * 0.5) <= r:
						image.set_pixel(x, y, ink)
		Schools.School.ROT:  # downward triangle
			for y in h:
				var half := int(float(h - y) / float(h) * float(w) * 0.5)
				for x in range(w / 2 - half, w / 2 + half + 1):
					if x >= 0 and x < w:
						image.set_pixel(x, h - 1 - y, ink)
		Schools.School.WARD:  # square
			for y in range(h / 6, h - h / 6):
				for x in range(w / 6, w - w / 6):
					image.set_pixel(x, y, ink)
	return ImageTexture.create_from_image(image)


## A figure: a flat silhouette whose proportions come from the name, so an examiner
## looks the same in every battle.
static func figure(seed_text: String, size: Vector2i) -> ImageTexture:
	var image := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng := _rng_for(seed_text)
	var robe := [
		Color("#D45C3C"), Color("#E0A51F"), Color("#498BAD"), Color("#6E7B3F"), Color("#A3B0AC")
	][rng.randi_range(0, 4)]
	var w := size.x
	var h := size.y

	# Robe: a trapezium widening to the hem.
	var shoulder := int(float(w) * rng.randf_range(0.34, 0.46))
	for y in range(int(float(h) * 0.28), h):
		var t := float(y - int(float(h) * 0.28)) / maxf(1.0, float(h) * 0.72)
		var half := int(lerpf(float(shoulder), float(w) * 0.5, t))
		for x in range(w / 2 - half, w / 2 + half):
			if x >= 0 and x < w:
				image.set_pixel(x, y, robe)

	# Head: a black circle, the reference's flat-black treatment.
	var head_r := float(w) * 0.18
	var head_c := Vector2(float(w) * 0.5, float(h) * 0.18)
	for y in h:
		for x in w:
			if Vector2(x, y).distance_to(head_c) <= head_r:
				image.set_pixel(x, y, ArtLibrary.INK)

	_grain(image, rng, 0.05)
	return ImageTexture.create_from_image(image)


## A course medallion, one flat colour per tier.
static func medallion(tier: int, size: Vector2i) -> ImageTexture:
	var image := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ink := [Color("#498BAD"), Color("#E0A51F"), Color("#D45C3C")][clampi(tier - 1, 0, 2)]
	var r := float(mini(size.x, size.y)) * 0.46
	var c := Vector2(size.x, size.y) * 0.5
	for y in size.y:
		for x in size.x:
			var d := Vector2(x, y).distance_to(c)
			if d <= r:
				image.set_pixel(x, y, ink if d > r * 0.72 else ArtLibrary.PAPER)
	_grain(image, _rng_for("tier%d" % tier), 0.04)
	return ImageTexture.create_from_image(image)
```

- [ ] **Step 4: Write `scripts/view/ArtLibrary.gd`**

A `.png` is not loadable until Godot has imported it, so `ResourceLoader.exists` is the
right check, not `FileAccess.file_exists`.

```gdscript
class_name ArtLibrary
extends RefCounted

## Sprite lookup with a per-key procedural fallback, so a half-finished art set renders
## correctly and one illustration can drop in at a time.

const PAPER := Color("#F7EADD")
const INK := Color("#000000")
const SLATE := Color("#A3B0AC")
const GRAIN_A := Color("#999189")
const GRAIN_B := Color("#6C6661")

const SPRITE_DIR := "res://assets/sprites"

static var _cache := {}


static func _sprite_path(key: String) -> String:
	return "%s/%s.png" % [SPRITE_DIR, key]


## A .png is unusable until Godot has imported it — writing the file is not enough,
## which is why tools/import-assets.sh runs --import.
static func has_sprite(key: String) -> bool:
	return ResourceLoader.exists(_sprite_path(key))


static func texture(key: String, size: Vector2i) -> Texture2D:
	if has_sprite(key):
		var loaded: Texture2D = load(_sprite_path(key))
		if loaded != null:
			return loaded

	var cache_key := "%s@%dx%d" % [key, size.x, size.y]
	if _cache.has(cache_key):
		return _cache[cache_key]

	var painted: Texture2D = _paint(key, size)
	_cache[cache_key] = painted
	return painted


static func _paint(key: String, size: Vector2i) -> Texture2D:
	if key.begins_with("cards/"):
		return ArtFactory.card_face(_school_for(key), size)
	if key.begins_with("entities/"):
		return ArtFactory.figure(key, size)
	if key.begins_with("courses/"):
		return ArtFactory.medallion(1, size)
	return ArtFactory.figure(key, size)


## Cards fall back to a face in a school derived from the key, so two different cards
## do not paint identically.
static func _school_for(key: String):
	return Schools.ALL[absi(hash(key)) % Schools.ALL.size()]


## Which of these keys are still drawn procedurally. Drives the art manifest.
static func missing_keys(keys: Array) -> Array:
	var out: Array = []
	var seen := {}
	for key in keys:
		if seen.has(key):
			continue
		seen[key] = true
		if not has_sprite(key):
			out.append(key)
	return out
```

- [ ] **Step 5: Write `tools/generate_theme.gd` and generate the theme**

```gdscript
extends SceneTree

## Regenerates resources/ui_theme.tres. Light, per spec 9.2: paper ground, ink text,
## and 48px minimum tap targets for thumbs at 1080 wide.

const OUT := "res://resources/ui_theme.tres"
const MIN_TAP := 96  # 48dp at a 2x portrait scale


func _flat(colour: Color, border: Color, width := 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(16)
	return box


func _process(_delta: float) -> bool:
	var theme := Theme.new()
	theme.default_font_size = 32

	theme.set_stylebox("normal", "Button", _flat(ArtLibrary.PAPER, ArtLibrary.INK))
	theme.set_stylebox("hover", "Button", _flat(Color("#E0A51F"), ArtLibrary.INK))
	theme.set_stylebox("pressed", "Button", _flat(Color("#D45C3C"), ArtLibrary.INK))
	theme.set_stylebox("disabled", "Button", _flat(ArtLibrary.SLATE, ArtLibrary.GRAIN_B))
	theme.set_color("font_color", "Button", ArtLibrary.INK)
	theme.set_color("font_disabled_color", "Button", ArtLibrary.GRAIN_B)
	theme.set_constant("h_separation", "Button", 12)
	theme.set_color("font_color", "Label", ArtLibrary.INK)
	theme.set_stylebox("panel", "PanelContainer", _flat(ArtLibrary.PAPER, ArtLibrary.INK))
	theme.set_stylebox("background", "ProgressBar", _flat(ArtLibrary.SLATE, ArtLibrary.INK, 2))
	theme.set_stylebox("fill", "ProgressBar", _flat(Color("#D45C3C"), ArtLibrary.INK, 0))

	if ResourceSaver.save(theme, OUT) != OK:
		printerr("failed to write %s" % OUT)
		quit(1)
		return true
	print("wrote %s (min tap target %dpx)" % [OUT, MIN_TAP])
	quit(0)
	return true
```

Then:

```bash
godot --headless --path . --script tools/generate_theme.gd
godot --headless --import --path . >/dev/null 2>&1
```

- [ ] **Step 6: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS, with the `art:` line reporting every key still procedural.

- [ ] **Step 7: Commit and push**

```bash
git add -A
git commit -m "feat(view): add the procedural art fallback and the light theme"
git push
```

---

### Task 20: `CardView` and `HandFan`

**Files:**
- Create: `scripts/ui/UIKit.gd`, `scripts/ui/CardView.gd`, `scripts/ui/HandFan.gd`
- Test: `tests/test_ui.gd`

**Interfaces:**
- Consumes: `CardInstance` (4), `ArtLibrary`/`ArtFactory` (19), `Schools` (1).
- Produces: `UIKit.label(text, size) -> Label`, `UIKit.button(text) -> Button`, `UIKit.spacer() -> Control`, `UIKit.transparent(container)` setting `MOUSE_FILTER_IGNORE`. `CardView` (extends `Control`) with `setup(card: CardInstance)`, `signal play_requested(card)`, `signal inspect_requested(card)`, `var card`, `set_playable(bool)`. `HandFan` (extends `Control`) with `set_hand(cards: Array)`, `layout()`, `signal card_play_requested(card)`, and `static fan_transform(index: int, count: int, width: float) -> Dictionary` returning `{"position": Vector2, "rotation": float}`.

The fan maths is a pure static function so it is testable without a scene.

- [ ] **Step 1: Write the failing test `tests/test_ui.gd`**

```gdscript
extends TestCase

## Layout maths and the mouse-filter discipline. Control nodes eat board taps: every
## container must be MOUSE_FILTER_IGNORE with only buttons set to STOP, or the screen
## goes silently unresponsive.


func suite_name() -> String:
	return "ui"


func _card(name: String, cost := 1) -> CardInstance:
	var d := CardData.new()
	d.card_name = name
	d.cost = cost
	d.school = Schools.School.CINDER
	d.effects = [{"kind": CardData.DAMAGE, "amount": 6}] as Array[Dictionary]
	d.art_id = "cards/spark"
	return CardInstance.new(d)


func run() -> void:
	# A single card sits centred and upright.
	var solo := HandFan.fan_transform(0, 1, 1080.0)
	almost(solo["rotation"], 0.0, "one card is upright")
	almost(solo["position"].x, 540.0, "one card is centred")

	# Five cards fan symmetrically about the centre.
	var first := HandFan.fan_transform(0, 5, 1080.0)
	var last := HandFan.fan_transform(4, 5, 1080.0)
	var middle := HandFan.fan_transform(2, 5, 1080.0)
	check(first["position"].x < middle["position"].x, "cards run left to right")
	check(middle["position"].x < last["position"].x, "cards run left to right")
	almost(middle["rotation"], 0.0, "the middle card is upright")
	almost(first["rotation"], -last["rotation"], "the fan is symmetric")
	check(first["rotation"] < 0.0, "the left card tilts left")
	# Outer cards sit lower, which is what makes a fan read as a fan.
	check(first["position"].y > middle["position"].y, "outer cards hang lower")
	almost(first["position"].y, last["position"].y, "the fan is level")

	# The fan never runs off a 1080-wide screen, however many cards are held.
	for count in [1, 3, 5, 8, 12]:
		for i in count:
			var t := HandFan.fan_transform(i, count, 1080.0)
			check(t["position"].x >= 0.0, "card %d/%d is on screen" % [i, count])
			check(t["position"].x <= 1080.0, "card %d/%d is on screen" % [i, count])

	# A CardView reports the card it was given and its XP progress.
	var view := CardView.new()
	var card := _card("Spark")
	view.setup(card)
	eq(view.card, card, "view holds its card")
	check(view.get_child_count() > 0, "view built its children")
	view.set_playable(false)
	eq(view.modulate.a < 1.0, true, "unplayable cards are dimmed")
	view.set_playable(true)
	almost(view.modulate.a, 1.0, "playable cards are opaque")

	# Containers must not swallow taps.
	var fan := HandFan.new()
	fan.set_hand([_card("a"), _card("b")])
	eq(fan.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the fan itself ignores the mouse")
	eq(fan.get_child_count(), 2, "one view per card")

	var box := UIKit.transparent(VBoxContainer.new())
	eq(box.mouse_filter, Control.MOUSE_FILTER_IGNORE, "UIKit containers ignore the mouse")
	eq(UIKit.button("Tap").mouse_filter, Control.MOUSE_FILTER_STOP, "buttons stop it")
	# 48dp thumb targets at 1080 wide.
	check(UIKit.button("Tap").custom_minimum_size.y >= 96.0, "buttons are thumb-sized")

	view.free()
	fan.free()
	box.free()
```

- [ ] **Step 2: Run the suite and watch it fail**

The runner discovers `tests/test_*.gd` automatically, so there is nothing to register.

```bash
./tools/check.sh
```
Expected: FAIL — `HandFan` is not declared.

- [ ] **Step 3: Write `scripts/ui/UIKit.gd`**

```gdscript
class_name UIKit
extends RefCounted

## Shared widget constructors, so screens read as declarations. Also the single place
## the mouse-filter rule is applied.

const TAP_MIN := 96.0  # 48dp at portrait 2x


static func label(text: String, size := 32) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func button(text: String) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(TAP_MIN * 2.0, TAP_MIN)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	return node


## Containers must never intercept taps meant for the board beneath them.
static func transparent(container: Control) -> Control:
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return container


static func spacer() -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node
```

- [ ] **Step 4: Write `scripts/ui/CardView.gd`**

```gdscript
class_name CardView
extends Control

## One card. Dragged upward to play, tapped to inspect. Portrait 2:3, so it stays
## legible in a five-card fan on a 1080-wide screen.

signal play_requested(card)
signal inspect_requested(card)

const CARD_SIZE := Vector2(200, 300)
## How far up the card must be dragged before it counts as played.
const PLAY_THRESHOLD := 120.0

var card: CardInstance = null

var _dragging := false
var _drag_start := Vector2.ZERO
var _home := Vector2.ZERO
var _playable := true


func setup(instance: CardInstance) -> void:
	card = instance
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	if card == null:
		return

	var frame := TextureRect.new()
	frame.texture = ArtLibrary.texture(card.data.art_id, Vector2i(CARD_SIZE))
	frame.size = CARD_SIZE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	# Evolved cards get a gold rim: same illustration, now mastered.
	if not card.can_evolve():
		var rim := Panel.new()
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0)
		box.border_color = Color("#E0A51F")
		box.set_border_width_all(6)
		rim.add_theme_stylebox_override("panel", box)
		rim.size = CARD_SIZE
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rim)

	var name_box := UIKit.label(card.data.card_name, 24)
	name_box.position = Vector2(16, CARD_SIZE.y - 96)
	name_box.size = Vector2(CARD_SIZE.x - 32, 40)
	add_child(name_box)

	var cost := UIKit.label(str(card.data.cost), 30)
	cost.position = Vector2(12, 8)
	add_child(cost)

	var sigil := TextureRect.new()
	sigil.texture = ArtFactory.sigil(card.data.school, Vector2i(32, 32))
	sigil.position = Vector2(CARD_SIZE.x - 44, 8)
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sigil)

	# XP ticks along the bottom edge.
	if card.can_evolve():
		for i in card.data.xp_to_evolve:
			var tick := Panel.new()
			var style := StyleBoxFlat.new()
			style.bg_color = ArtLibrary.INK if i < card.xp else ArtLibrary.SLATE
			tick.add_theme_stylebox_override("panel", style)
			tick.size = Vector2(24, 8)
			tick.position = Vector2(16 + i * 30, CARD_SIZE.y - 24)
			tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tick)


func set_playable(value: bool) -> void:
	_playable = value
	modulate.a = 1.0 if value else 0.45


func remember_home() -> void:
	_home = position


func _gui_input(event: InputEvent) -> void:
	if card == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start = event.global_position
			_home = position
		else:
			var lifted := _drag_start.y - event.global_position.y
			_dragging = false
			if _playable and lifted >= PLAY_THRESHOLD:
				play_requested.emit(card)
			else:
				position = _home
				inspect_requested.emit(card)
	elif event is InputEventMouseMotion and _dragging:
		position += event.relative
```

- [ ] **Step 5: Write `scripts/ui/HandFan.gd`**

```gdscript
class_name HandFan
extends Control

## The curved hand. The layout maths is a static function so it can be tested without
## instantiating a scene.

signal card_play_requested(card)
signal card_inspect_requested(card)

const MAX_SPREAD := 420.0
const MAX_TILT := 0.22  # radians at the outermost card
const ARC_DROP := 46.0  # how far the outer cards hang below the middle


## Where card `index` of `count` sits across a screen `width` wide.
static func fan_transform(index: int, count: int, width: float) -> Dictionary:
	if count <= 1:
		return {"position": Vector2(width * 0.5, 0.0), "rotation": 0.0}

	# -1 at the far left, +1 at the far right.
	var t := (float(index) / float(count - 1)) * 2.0 - 1.0
	# Narrow the spread as the hand grows so it never leaves the screen.
	var spread := minf(MAX_SPREAD, width * 0.42)
	var x := width * 0.5 + t * spread
	var y := absf(t) * ARC_DROP
	return {"position": Vector2(clampf(x, 0.0, width), y), "rotation": t * MAX_TILT}


func _init() -> void:
	# The fan itself must not eat taps; only the CardViews inside it do.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hand(cards: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for card in cards:
		var view := CardView.new()
		view.setup(card)
		view.play_requested.connect(func(c): card_play_requested.emit(c))
		view.inspect_requested.connect(func(c): card_inspect_requested.emit(c))
		add_child(view)
	layout()


func layout() -> void:
	var width := size.x if size.x > 0.0 else 1080.0
	var views := get_children()
	for i in views.size():
		var view: CardView = views[i]
		var t := fan_transform(i, views.size(), width)
		view.position = t["position"] - CardView.CARD_SIZE * 0.5
		view.rotation = t["rotation"]
		view.remember_home()


func set_playable(predicate: Callable) -> void:
	for child in get_children():
		var view: CardView = child
		view.set_playable(predicate.call(view.card))
```

- [ ] **Step 6: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 7: Commit and push**

```bash
git add -A
git commit -m "feat(ui): add card views and the curved hand fan"
git push
```

---

### Task 21: `BattleScreen`

**Files:**
- Create: `scripts/ui/BattleScreen.gd`
- Modify: `tests/test_ui.gd`

**Interfaces:**
- Consumes: `Battle` (9), `HandFan`/`CardView`/`UIKit` (20), `ArtLibrary` (19).
- Produces: `BattleScreen` (extends `Control`) with `begin(battle: Battle)`, `signal battle_finished(battle)`, `refresh()`, and `replay(events: Array)` appending each event's `text` to the log. Node tree: a root `Control` holding `ExaminerPanel` (figure, HP bar, intent label), `PlayerPanel` (HP bar, mana pips, pile counts), `Log`, `HandFan`, and an `End Turn` button.

- [ ] **Step 1: Add battle-screen checks to `tests/test_ui.gd`**

Append to `run()`:

```gdscript
	# The battle screen wires a Battle to the fan and the end-turn button.
	var library: ContentLibrary = load("res://resources/content_library.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var deck := library.new_starting_deck()
	var fight := Battle.new(deck, library.enemies[0], Bestiary.new(), rng)
	var screen := BattleScreen.new()
	screen.size = Vector2(1080, 1920)
	screen.begin(fight)
	eq(screen.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the screen does not eat taps")
	check(screen.hand_fan != null, "built a hand fan")
	eq(screen.hand_fan.get_child_count(), 5, "showed the five drawn cards")
	check(screen.end_turn_button != null, "built an end-turn button")
	eq(screen.end_turn_button.mouse_filter, Control.MOUSE_FILTER_STOP, "the button takes taps")
	check(screen.intent_label.text.length() > 0, "telegraphed the examiner's intent")

	# Replaying events writes them to the log rather than touching core state.
	var before := fight.examiner.hp
	screen.replay([{"type": "damage", "target": "examiner", "amount": 3, "text": "3 damage"}])
	eq(fight.examiner.hp, before, "replaying does not mutate the battle")
	check(screen.log_label.text.contains("3 damage"), "logged the event")

	# Unaffordable cards are dimmed.
	fight.player.mana = 0
	screen.refresh()
	var any_dimmed := false
	for child in screen.hand_fan.get_children():
		if child.modulate.a < 1.0:
			any_dimmed = true
	eq(any_dimmed, true, "unaffordable cards dim with no mana")

	screen.free()
```

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL — `BattleScreen` is not declared.

- [ ] **Step 3: Write `scripts/ui/BattleScreen.gd`**

```gdscript
class_name BattleScreen
extends Control

## Top half examiner, bottom half player and hand, per the brief. Replays the event
## arrays Battle returns; never computes a rule itself.

signal battle_finished(battle)

var battle: Battle = null

var hand_fan: HandFan = null
var end_turn_button: Button = null
var intent_label: Label = null
var log_label: Label = null
var examiner_bar: ProgressBar = null
var player_bar: ProgressBar = null
var mana_label: Label = null
var piles_label: Label = null
var examiner_figure: TextureRect = null

var _log_lines: Array[String] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(fight: Battle) -> void:
	battle = fight
	_build()
	replay(battle.start() if battle.turns == 0 else [])
	refresh()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	var root := UIKit.transparent(VBoxContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# --- Top half: the examiner ---
	var top := UIKit.transparent(VBoxContainer.new())
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(top)

	examiner_figure = TextureRect.new()
	examiner_figure.custom_minimum_size = Vector2(360, 520)
	examiner_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	examiner_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	examiner_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(examiner_figure)

	top.add_child(UIKit.label(battle.examiner.display_name, 40))
	examiner_bar = ProgressBar.new()
	examiner_bar.custom_minimum_size = Vector2(600, 40)
	examiner_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(examiner_bar)

	intent_label = UIKit.label("", 28)
	top.add_child(intent_label)

	log_label = UIKit.label("", 24)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_child(log_label)

	# --- Bottom half: the player ---
	var bottom := UIKit.transparent(VBoxContainer.new())
	root.add_child(bottom)

	player_bar = ProgressBar.new()
	player_bar.custom_minimum_size = Vector2(600, 40)
	player_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(player_bar)

	var row := UIKit.transparent(HBoxContainer.new())
	bottom.add_child(row)
	mana_label = UIKit.label("", 32)
	row.add_child(mana_label)
	piles_label = UIKit.label("", 24)
	row.add_child(piles_label)

	hand_fan = HandFan.new()
	hand_fan.custom_minimum_size = Vector2(1080, 340)
	hand_fan.size = Vector2(1080, 340)
	hand_fan.card_play_requested.connect(_on_card_played)
	bottom.add_child(hand_fan)

	end_turn_button = UIKit.button("End Turn")
	end_turn_button.pressed.connect(_on_end_turn)
	bottom.add_child(end_turn_button)


func _on_card_played(card) -> void:
	if battle == null or battle.finished:
		return
	replay(battle.play_card(card))
	refresh()
	_check_finished()


func _on_end_turn() -> void:
	if battle == null or battle.finished:
		return
	replay(battle.end_turn())
	refresh()
	_check_finished()


func _check_finished() -> void:
	if battle != null and battle.finished:
		end_turn_button.disabled = true
		battle_finished.emit(battle)


## Appends each event's text. Never mutates the battle: core has already resolved it.
func replay(events: Array) -> void:
	for event in events:
		var text: String = str(event.get("text", ""))
		if text != "":
			_log_lines.append(text)
	while _log_lines.size() > 6:
		_log_lines.pop_front()
	if log_label != null:
		log_label.text = "\n".join(_log_lines)


func refresh() -> void:
	if battle == null:
		return
	examiner_bar.max_value = maxi(1, battle.examiner.max_hp)
	examiner_bar.value = battle.examiner.hp
	player_bar.max_value = maxi(1, battle.player.max_hp)
	player_bar.value = battle.player.hp

	examiner_figure.texture = ArtLibrary.texture(
		battle.examiner_art_id(), Vector2i(360, 520)
	)

	var block_text := "" if battle.player.block <= 0 else "  block %d" % battle.player.block
	mana_label.text = "%d/%d mana%s" % [battle.player.mana, battle.player.mana_per_turn, block_text]
	piles_label.text = (
		"draw %d  discard %d"
		% [battle.player_deck.draw_pile.size(), battle.player_deck.discard_pile.size()]
	)

	if battle.examiner_intent != null:
		intent_label.text = "Next: %s" % battle.examiner_intent.data.card_name
	else:
		intent_label.text = "Next: hesitating"

	hand_fan.set_hand(battle.player_deck.hand)
	hand_fan.set_playable(func(card): return battle.can_play(card))
```

- [ ] **Step 4: Add `examiner_art_id()` to `scripts/core/Battle.gd`**

`Battle` already holds the `EnemyData`; the screen should not reach into a private
field for it.

```gdscript
func examiner_art_id() -> String:
	return "" if _enemy_data == null else _enemy_data.art_id


func examiner_data() -> EnemyData:
	return _enemy_data
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 6: Commit and push**

```bash
git add -A
git commit -m "feat(ui): add the battle screen and event replay"
git push
```

---

### Task 22: `ReportCard` and `RegistrationScreen`

**Files:**
- Create: `scripts/ui/ReportCard.gd`, `scripts/ui/RegistrationScreen.gd`
- Modify: `tests/test_ui.gd`

**Interfaces:**
- Consumes: `Grading` (10), `Draft` (11), `CardView` (20).
- Produces: `ReportCard.show_result(scored: Dictionary, result: Dictionary, course)`, `signal continued`; `RegistrationScreen.begin(draft: Draft)`, `signal registration_complete(kept: Array)`, `toggle(card)`, `var selected: Array`, `can_confirm() -> bool`.

Registration is the screen that poses the plan's central decision, so it must show XP
on every card and refuse a selection that is not exactly the cap.

- [ ] **Step 1: Add checks to `tests/test_ui.gd`**

Append to `run()`:

```gdscript
	# The report card shows all four terms and the letter.
	var report := ReportCard.new()
	var course := CourseData.new()
	course.course_name = "Basic Arcana 101"
	var scored := Grading.score({
		"won": true, "turns_taken": 5, "par_turns": 5, "hp_end": 60, "hp_start": 60,
		"xp_banked": 15, "xp_par": 15, "weakness_known": true, "distinct_schools": 5,
	})
	report.show_result(scored, {"strike": false, "strikes": 0, "expelled": false}, course)
	var report_text := ""
	for child in report.find_children("*", "Label", true, false):
		report_text += child.text + " "
	check(report_text.contains("S"), "showed the letter grade")
	for term in ["Efficiency", "Survival", "Learning", "Discovery"]:
		check(report_text.contains(term), "showed the %s term" % term)
	report.free()

	# Registration enforces the cap and shows XP.
	var own: Array = []
	for i in 10:
		own.append(_card("own%d" % i))
	own[0].gain_xp()
	var pool: Array[CardData] = []
	for i in 4:
		var d := CardData.new()
		d.card_name = "theirs%d" % i
		d.art_id = "cards/spark"
		pool.append(d)
	var syllabus := CardData.new()
	syllabus.card_name = "syllabus"
	syllabus.art_id = "cards/spark"
	var draft := Draft.new(own, pool, syllabus, Grading.Grade.S)
	draft.cap = 11
	var registration := RegistrationScreen.new()
	registration.size = Vector2(1080, 1920)
	registration.begin(draft)
	eq(registration.selected.size(), 0, "nothing chosen yet")
	eq(registration.can_confirm(), false, "cannot confirm an empty selection")
	for card in draft.own:
		registration.toggle(card)
	eq(registration.selected.size(), 10, "chose ten")
	eq(registration.can_confirm(), false, "ten is not the cap of eleven")
	registration.toggle(draft.offered[0])
	eq(registration.selected.size(), 11, "chose eleven")
	eq(registration.can_confirm(), true, "eleven meets the cap")
	registration.toggle(draft.offered[0])
	eq(registration.selected.size(), 10, "toggling removes")
	registration.free()
```

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL — `ReportCard` is not declared.

- [ ] **Step 3: Write `scripts/ui/ReportCard.gd`**

```gdscript
class_name ReportCard
extends Control

## Post-battle breakdown. Shows all four terms, because the player needs to see that
## learning is what earned the grade.

signal continued

var _rows: VBoxContainer = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_result(scored: Dictionary, result: Dictionary, course) -> void:
	for child in get_children():
		child.queue_free()

	_rows = UIKit.transparent(VBoxContainer.new()) as VBoxContainer
	_rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rows)

	_rows.add_child(UIKit.label(course.course_name, 36))
	_rows.add_child(UIKit.label(Grading.letter(scored["grade"]), 120))

	for term in ["efficiency", "survival", "learning", "discovery"]:
		_rows.add_child(
			UIKit.label("%s  %.0f / 25" % [term.capitalize(), float(scored[term])], 28)
		)
	_rows.add_child(UIKit.label("Total  %.0f / 100" % float(scored["total"]), 32))

	var allowance: int = Grading.draft_allowance(scored["grade"])
	var allowance_text := (
		"You may copy their whole deck."
		if allowance < 0
		else "You may copy %d of their cards." % allowance
	)
	_rows.add_child(UIKit.label(allowance_text, 26))

	if bool(result.get("strike", false)):
		var strikes := int(result.get("strikes", 0))
		_rows.add_child(
			UIKit.label(
				"ACADEMIC PROBATION — strike %d of %d" % [strikes, Run.MAX_STRIKES], 28
			)
		)
		_rows.add_child(UIKit.label("Your hit points have been restored.", 24))

	var button := UIKit.button("Continue")
	button.pressed.connect(func(): continued.emit())
	_rows.add_child(button)
```

- [ ] **Step 4: Write `scripts/ui/RegistrationScreen.gd`**

```gdscript
class_name RegistrationScreen
extends Control

## The draft. Keeping exactly `cap` cards is the run's recurring decision, and cutting
## a card destroys its XP — which is why every card shows its progress.

signal registration_complete(kept)

var draft: Draft = null
var selected: Array = []

var _confirm: Button = null
var _counter: Label = null
var _grid: GridContainer = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(the_draft: Draft) -> void:
	draft = the_draft
	selected = []
	_build()
	_refresh()


func _build() -> void:
	for child in get_children():
		child.queue_free()

	var root := UIKit.transparent(VBoxContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	root.add_child(UIKit.label("Registration", 40))
	_counter = UIKit.label("", 30)
	root.add_child(_counter)
	root.add_child(UIKit.label("Cutting a card loses the experience it earned.", 22))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_grid)

	for card in draft.own:
		_grid.add_child(_entry(card, false))
	for card in draft.offered:
		_grid.add_child(_entry(card, true))

	_confirm = UIKit.button("Confirm")
	_confirm.pressed.connect(_on_confirm)
	root.add_child(_confirm)


func _entry(card, is_offered: bool) -> Control:
	var column := UIKit.transparent(VBoxContainer.new())
	var button := Button.new()
	button.custom_minimum_size = Vector2(240, 120)
	button.text = "%s\n%s%s" % [
		card.data.card_name,
		card.progress(),
		"  (theirs)" if is_offered else "",
	]
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(func(): toggle(card))
	button.set_meta("card", card)
	column.add_child(button)
	return column


func toggle(card) -> void:
	if selected.has(card):
		selected.erase(card)
	else:
		if selected.size() >= draft.cap:
			return  # the cap is the rule; refuse rather than silently swap
		selected.append(card)
	_refresh()


func can_confirm() -> bool:
	return draft != null and selected.size() == draft.cap


func _refresh() -> void:
	if _counter != null:
		_counter.text = "Keep %d of %d" % [selected.size(), draft.cap]
	if _confirm != null:
		_confirm.disabled = not can_confirm()
	if _grid == null:
		return
	for column in _grid.get_children():
		for child in column.get_children():
			if child is Button and child.has_meta("card"):
				child.modulate = (
					Color("#E0A51F") if selected.has(child.get_meta("card")) else Color.WHITE
				)


func _on_confirm() -> void:
	if not can_confirm():
		return
	var kept := draft.keep(selected)
	if kept.is_empty():
		return  # Draft refused it; leave the screen up rather than losing the deck
	registration_complete.emit(kept)
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 6: Commit and push**

```bash
git add -A
git commit -m "feat(ui): add the report card and registration screens"
git push
```

---

### Task 23: `CourseCatalog` and `BestiaryScreen`

**Files:**
- Create: `scripts/ui/CourseCatalog.gd`, `scripts/ui/BestiaryScreen.gd`
- Modify: `tests/test_ui.gd`

**Interfaces:**
- Consumes: `Catalog`/`CourseData` (12), `Bestiary` (8), `ArtFactory` (19).
- Produces: `CourseCatalog.show_catalog(catalog: Catalog, grades: Dictionary)`, `signal course_chosen(course)`, `var node_buttons: Dictionary`; `BestiaryScreen.show_bestiary(bestiary, enemies: Array)`, `signal closed`.

The map draws prerequisite edges with `Line2D` behind tier rows of medallion buttons.
Unavailable courses are visible but disabled; unrevealed honors nodes are absent.

- [ ] **Step 1: Add checks to `tests/test_ui.gd`**

Append to `run()`:

```gdscript
	# The map shows revealed courses, disables the unavailable ones, and hides honors
	# nodes until an A reveals them.
	var lib: ContentLibrary = load("res://resources/content_library.tres")
	var cat := lib.catalog()
	var map := CourseCatalog.new()
	map.size = Vector2(1080, 1920)
	map.show_catalog(cat, {})
	eq(map.node_buttons.size(), 3, "only the three entry courses at the start")
	for name in map.node_buttons:
		eq(map.node_buttons[name].disabled, false, "entry courses are enterable")

	# An S on an entry course reveals its honors branch.
	map.show_catalog(cat, {"Basic Arcana 101": Grading.Grade.S})
	check(map.node_buttons.has("Tutorial 150"), "an S revealed the honors node")
	check(not map.node_buttons.has("Comprehensive Exam"), "the final stays hidden")
	# An attempted course is shown but cannot be retaken.
	check(map.node_buttons.has("Basic Arcana 101"), "the passed course is still drawn")
	eq(map.node_buttons["Basic Arcana 101"].disabled, true, "no retakes")
	check(map.edge_count() > 0, "drew prerequisite edges")
	map.free()

	# The bestiary lists what has been learned and hides what has not.
	var known := Bestiary.new()
	known.record_hit(lib.enemies[0], lib.enemies[0].weak_school)
	var beast := BestiaryScreen.new()
	beast.show_bestiary(known, lib.enemies)
	var beast_text := ""
	for child in beast.find_children("*", "Label", true, false):
		beast_text += child.text + " "
	check(beast_text.contains(lib.enemies[0].enemy_name), "listed the known examiner")
	check(beast_text.contains("?"), "unknown weaknesses stay hidden")
	beast.free()
```

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL — `CourseCatalog` is not declared.

- [ ] **Step 3: Write `scripts/ui/CourseCatalog.gd`**

```gdscript
class_name CourseCatalog
extends Control

## The syllabus map: tier rows of medallion buttons with Line2D prerequisite edges
## behind them. Tap targets are thumb-sized per the brief.

signal course_chosen(course)

const NODE_SIZE := Vector2(200, 200)
const ROW_HEIGHT := 380.0

var node_buttons := {}  ## course name -> Button

var _edges: Node2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func edge_count() -> int:
	return 0 if _edges == null else _edges.get_child_count()


func show_catalog(catalog, grades: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	node_buttons = {}

	# Edges first so they sit behind the nodes.
	_edges = Node2D.new()
	add_child(_edges)

	var revealed: Array = catalog.revealed(grades)
	var by_tier := {}
	for course in revealed:
		if not by_tier.has(course.tier):
			by_tier[course.tier] = []
		by_tier[course.tier].append(course)

	var width := size.x if size.x > 0.0 else 1080.0
	var centres := {}
	var tiers := by_tier.keys()
	tiers.sort()
	for row in tiers.size():
		var tier: int = tiers[row]
		var courses: Array = by_tier[tier]
		for i in courses.size():
			var course = courses[i]
			var x := width * (float(i) + 1.0) / (float(courses.size()) + 1.0)
			var y := 220.0 + float(row) * ROW_HEIGHT
			var centre := Vector2(x, y)
			centres[course.course_name] = centre
			add_child(_node_button(course, centre, catalog.is_available(course, grades)))

	# Draw an edge for each prerequisite whose node is also on screen.
	for course in revealed:
		if not centres.has(course.course_name):
			continue
		for prerequisite in course.prerequisites:
			if not centres.has(prerequisite.course_name):
				continue
			var line := Line2D.new()
			line.width = 6.0
			line.default_color = ArtLibrary.SLATE
			line.points = [centres[prerequisite.course_name], centres[course.course_name]]
			_edges.add_child(line)


func _node_button(course, centre: Vector2, available: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = NODE_SIZE
	button.size = NODE_SIZE
	button.position = centre - NODE_SIZE * 0.5
	button.text = course.course_name
	button.icon = ArtFactory.medallion(course.tier, Vector2i(96, 96))
	button.disabled = not available
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(func(): course_chosen.emit(course))
	node_buttons[course.course_name] = button
	return button
```

- [ ] **Step 4: Write `scripts/ui/BestiaryScreen.gd`**

```gdscript
class_name BestiaryScreen
extends Control

## What the student has learned. Unknown entries show "?" rather than being omitted,
## so the player can see there is something left to discover.

signal closed


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_bestiary(bestiary, enemies: Array) -> void:
	for child in get_children():
		child.queue_free()

	var root := UIKit.transparent(VBoxContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UIKit.label("Student Bestiary", 40))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(scroll)

	var list := UIKit.transparent(VBoxContainer.new())
	scroll.add_child(list)

	for enemy in enemies:
		var weak := (
			Schools.display_name(enemy.weak_school)
			if bestiary.knows_weakness(enemy.enemy_name)
			else "?"
		)
		var ward := (
			Schools.display_name(enemy.warded_school)
			if bestiary.knows_ward(enemy.enemy_name)
			else "?"
		)
		list.add_child(
			UIKit.label("%s — weak: %s   warded: %s" % [enemy.enemy_name, weak, ward], 26)
		)

	var button := UIKit.button("Back")
	button.pressed.connect(func(): closed.emit())
	root.add_child(button)
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 6: Commit and push**

```bash
git add -A
git commit -m "feat(ui): add the course catalog map and the bestiary"
git push
```

---

### Task 24: `Main` — the composition root, menus, and a real screenshot

**Files:**
- Create: `scripts/Main.gd`, `scripts/ui/MainMenu.gd`, `scripts/ui/GameOver.gd`, `scenes/Main.tscn`
- Modify: `tests/test_ui.gd`

**Interfaces:**
- Consumes: everything.
- Produces: `Main` (extends `Node`) owning the `Run` and swapping screens; `MainMenu` with `signal new_run_requested`, `signal continue_requested`, `signal bestiary_requested`; `GameOver` with `show_outcome(run)`, `signal restarted`. `Main` parses `--shot <path>`, `--seed <n>` and `--screen <name>` from `OS.get_cmdline_user_args()` so `tools/shot.sh` works.

- [ ] **Step 1: Add composition-root checks to `tests/test_ui.gd`**

Append to `run()`:

```gdscript
	# The composition root wires screens without any of them knowing about each other.
	var main := Main.new()
	main.boot_headless()
	eq(main.current_screen_name(), "menu", "boots to the menu")
	main.start_new_run()
	eq(main.current_screen_name(), "catalog", "a new run opens the catalog")
	check(main.run != null, "root owns the run")
	eq(main.run.deck.size(), 10, "dealt the starting deck")

	# Choosing a course opens a battle.
	var lib2: ContentLibrary = load("res://resources/content_library.tres")
	main.enter_course(lib2.course_named("Basic Arcana 101"))
	eq(main.current_screen_name(), "battle", "entering a course opens the battle")
	check(main.battle != null, "root owns the battle")

	# Expulsion ends the run and clears the save.
	main.run.strikes = Run.MAX_STRIKES
	main.run.expelled = true
	main.finish_battle_headless(false)
	eq(main.current_screen_name(), "gameover", "expulsion ends the run")
	eq(SaveGame.has_save(), false, "expulsion cleared the save")
	main.free()
```

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL — `Main` is not declared.

- [ ] **Step 3: Write `scripts/ui/MainMenu.gd` and `scripts/ui/GameOver.gd`**

```gdscript
class_name MainMenu
extends Control

signal new_run_requested
signal continue_requested
signal bestiary_requested


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build(has_save: bool) -> void:
	for child in get_children():
		child.queue_free()
	var root := UIKit.transparent(VBoxContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UIKit.label("CURRICULUM", 72))
	root.add_child(UIKit.label("The only way to learn is by playing.", 26))

	if has_save:
		var resume := UIKit.button("Continue")
		resume.pressed.connect(func(): continue_requested.emit())
		root.add_child(resume)

	var fresh := UIKit.button("Enroll")
	fresh.pressed.connect(func(): new_run_requested.emit())
	root.add_child(fresh)

	var beast := UIKit.button("Bestiary")
	beast.pressed.connect(func(): bestiary_requested.emit())
	root.add_child(beast)
```

```gdscript
class_name GameOver
extends Control

signal restarted


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_outcome(run) -> void:
	for child in get_children():
		child.queue_free()
	var root := UIKit.transparent(VBoxContainer.new())
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	if run.won:
		root.add_child(UIKit.label("GRADUATED", 64))
		root.add_child(UIKit.label("You broke the curriculum.", 28))
	else:
		root.add_child(UIKit.label("EXPELLED", 64))
		root.add_child(UIKit.label("Two failures. Your enrolment is terminated.", 28))

	root.add_child(UIKit.label("Courses passed: %d" % run.courses_passed, 26))
	var again := UIKit.button("Enroll again")
	again.pressed.connect(func(): restarted.emit())
	root.add_child(again)
```

- [ ] **Step 4: Write `scripts/Main.gd`**

```gdscript
class_name Main
extends Node

## Composition root. Owns the Run and swaps screens; no screen knows about another.

var run: Run = null
var battle: Battle = null

var library: ContentLibrary = null
var catalog: Catalog = null

var _screen: Control = null
var _screen_name := ""
var _course = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	boot_headless()
	_handle_cmdline()


## Separated from _ready so tests can boot without a scene tree.
func boot_headless() -> void:
	library = load("res://resources/content_library.tres")
	catalog = library.catalog()
	_rng.randomize()
	_show_menu()


func current_screen_name() -> String:
	return _screen_name


func _swap(screen: Control, name: String) -> void:
	if _screen != null and _screen.get_parent() == self:
		remove_child(_screen)
		_screen.queue_free()
	_screen = screen
	_screen_name = name
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)


func _show_menu() -> void:
	var menu := MainMenu.new()
	menu.build(SaveGame.has_save())
	menu.new_run_requested.connect(start_new_run)
	menu.continue_requested.connect(_continue_run)
	menu.bestiary_requested.connect(_show_bestiary)
	_swap(menu, "menu")


func start_new_run() -> void:
	run = Run.new(library.new_starting_deck())
	GameManager.run = run
	SaveGame.save(run)
	_show_catalog()


func _continue_run() -> void:
	run = SaveGame.load_run()
	if run == null:
		start_new_run()
		return
	GameManager.run = run
	_show_catalog()


func _show_catalog() -> void:
	var map := CourseCatalog.new()
	map.course_chosen.connect(enter_course)
	_swap(map, "catalog")
	map.show_catalog(catalog, run.grades)


func _show_bestiary() -> void:
	var screen := BestiaryScreen.new()
	screen.closed.connect(_show_menu if run == null else _show_catalog)
	_swap(screen, "bestiary")
	screen.show_bestiary(
		run.bestiary if run != null else Bestiary.new(), library.enemies
	)


func enter_course(course) -> void:
	_course = course
	battle = Battle.new(run.deck, course.examiner, run.bestiary, _rng)
	DeckManager.deck = battle.player_deck
	var screen := BattleScreen.new()
	screen.battle_finished.connect(func(_b): _on_battle_finished())
	_swap(screen, "battle")
	screen.begin(battle)


func _on_battle_finished() -> void:
	finish_battle_headless(battle.player_won)


## Grades the finished battle, records it, and moves on. Exposed for tests.
func finish_battle_headless(_won: bool) -> void:
	var scored: Dictionary = GradeManager.score(
		{
			"won": battle.player_won,
			"turns_taken": battle.turns,
			"par_turns": _course.par_turns,
			"hp_end": battle.player.hp,
			"hp_start": run.max_hp,
			"xp_banked": battle.xp_banked,
			"xp_par": _course.xp_par,
			"weakness_known": run.bestiary.knows_weakness(_course.examiner.enemy_name),
			"distinct_schools": battle.schools_played(),
		}
	)
	var result := run.record_result(_course, scored["grade"], battle.player.hp)

	if run.is_over():
		SaveGame.delete()
		var over := GameOver.new()
		over.restarted.connect(start_new_run)
		_swap(over, "gameover")
		over.show_outcome(run)
		return

	var report := ReportCard.new()
	report.continued.connect(func(): _show_registration(scored))
	_swap(report, "report")
	report.show_result(scored, result, _course)


func _show_registration(scored: Dictionary) -> void:
	if not battle.player_won:
		SaveGame.save(run)
		_show_catalog()
		return
	var draft := Draft.new(
		run.deck, _course.examiner.deck, _course.guaranteed_card_drop, scored["grade"]
	)
	draft.cap = run.deck_cap()
	var screen := RegistrationScreen.new()
	screen.registration_complete.connect(
		func(kept):
			run.deck = kept
			SaveGame.save(run)
			_show_catalog()
	)
	_swap(screen, "registration")
	screen.begin(draft)


## tools/shot.sh passes --shot/--seed/--screen after a bare --.
func _handle_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ""
	var wanted := ""
	for i in args.size():
		if args[i] == "--shot" and i + 1 < args.size():
			out = args[i + 1]
		elif args[i] == "--seed" and i + 1 < args.size():
			_rng.seed = args[i + 1].to_int()
		elif args[i] == "--screen" and i + 1 < args.size():
			wanted = args[i + 1]
	if out == "":
		return

	match wanted:
		"catalog":
			start_new_run()
		"battle":
			start_new_run()
			enter_course(library.course_named("Basic Arcana 101"))
		"bestiary":
			_show_bestiary()
		_:
			pass
	_screenshot(out)


func _screenshot(path: String) -> void:
	# --headless does not render, so this only works from a windowed run, and the
	# frame must be drawn before the viewport texture holds anything.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("wrote %s" % path)
	get_tree().quit()  # or the process hangs forever
```

- [ ] **Step 5: Build `scenes/Main.tscn` and declare it as the entry point**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
```

Now that the scene exists, add the key Task 1 deliberately left out — into the
`[application]` section of `project.godot`, directly after `config/description`:

```ini
run/main_scene="res://scenes/Main.tscn"
```

Then confirm the gate still passes from a cold cache, since `check.sh` fails on the
`Failed loading resource` that a wrong path here would produce:

```bash
rm -rf .godot && ./tools/check.sh
```

- [ ] **Step 6: Run the tests and watch them pass**

```bash
./tools/check.sh
```

Expected: PASS.

- [ ] **Step 7: Take a real screenshot of each screen**

This is the first time anything visual has been verified.

```bash
./tools/shot.sh /tmp/catalog.png 7 catalog
./tools/shot.sh /tmp/battle.png 7 battle
```

Open both. Check the specific things that go wrong: the hand fans across the bottom
without leaving the screen, the examiner and its intent are readable, tap targets look
thumb-sized, and the whole thing is on cream rather than dark. If the board does not
respond to taps, a container is missing `MOUSE_FILTER_IGNORE`.

- [ ] **Step 8: Commit and push**

```bash
git add -A
git commit -m "feat(ui): add the composition root, menus and screenshot support"
git push
```

---

## Phase 6 — Art

### Task 25: The Recraft manifest and generator

**Files:**
- Create: `assets/prompts/manifest.json`, `assets/prompts/recraft.md`, `assets/prompts/README.md`, `tools/recraft.py`, `tools/import-assets.sh`, `tools/import_assets.gd`
- Modify: `tests/test_art.gd`

**Interfaces:**
- Consumes: the content `art_id` values (16, 17).
- Produces: `python3 tools/recraft.py list|card <slug>|figure <slug>|ornament <slug> [--n 4]` writing into `assets/source/`; `./tools/import-assets.sh [--status]` processing `assets/source` into `assets/sprites` and re-importing.

Two simplifications fall out of the flat print style: art is generated **onto the cream
ground**, so no background removal is needed, and there is no perspective, so there is
no projection step.

- [ ] **Step 1: Add a manifest-agreement check to `tests/test_art.gd`**

Append to `run()`:

```gdscript
	# Every art_id the content declares must have a manifest entry, or an asset can
	# never be generated for it. A typo'd art_id otherwise falls back silently.
	var file := FileAccess.open("res://assets/prompts/manifest.json", FileAccess.READ)
	check(file != null, "manifest loads")
	if file == null:
		return
	var manifest = JSON.parse_string(file.get_as_text())
	file.close()
	check(typeof(manifest) == TYPE_DICTIONARY, "manifest is a json object")
	if typeof(manifest) != TYPE_DICTIONARY:
		return
	check(manifest.has("style"), "manifest declares the shared style clause")
	check(manifest.has("model"), "manifest names the model")

	var subjects := {}
	for group in ["cards", "figures", "ornament"]:
		for name in manifest.get(group, {}):
			subjects["%s/%s" % [group, name]] = true

	for card in library.cards:
		# Evolved cards share their base card's art, so only base ids need a subject.
		if card.is_fully_evolved():
			continue
		var slug: String = card.art_id.trim_prefix("cards/")
		check(subjects.has("cards/%s" % slug), "manifest has a subject for %s" % card.art_id)
	for enemy in library.enemies:
		var slug: String = enemy.art_id.trim_prefix("entities/")
		check(subjects.has("figures/%s" % slug), "manifest has a subject for %s" % enemy.art_id)
```

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL — no manifest.

- [ ] **Step 3: Write `assets/prompts/manifest.json`**

One `style` clause carries cohesion, because Recraft V4 does not support `style_id`.
The `cards` keys are the 24 base-card art slugs, `figures` the 9 examiners.

```json
{
  "model": "recraftv4_1",
  "style": "Mid-century modern screenprint illustration, in the manner of 1950s poster art: completely flat shapes with no outlines, no shading, no gradients and no rendering, form carried entirely by silhouette. A tiny palette of flat inks on a warm cream paper ground, with visible risograph halftone grain inside each ink and along its edges. Bold, simple, confident shapes.",
  "palette": "Cream paper #F7EADD, black #000000, vermilion #D45C3C, saffron #E0A51F, blue #498BAD, pale slate #A3B0AC, moss #6E7B3F. Use no more than three inks in any one image.",
  "card_rules": "Composed for a small portrait card, shown about 200 pixels wide, so use only three or four large shapes across the whole frame and no fine detail. The subject sits on a single large organic field shape in the school's ink, inset from the edge so a cream margin frames it like a printed plate. One small stippled grey celestial glyph — a circle, crescent or five-pointed star — floats alongside. Flat cream ground behind everything, no scenery, no horizon, no text, no letters, no border rule.",
  "figure_rules": "A single full-body figure standing and facing three-quarters toward the viewer, alone on a flat cream ground. Completely flat robe shapes in one or two inks with a flat black head and no facial features, in the manner of mid-century poster figures. Strong silhouette that still reads at 120 pixels tall. No scenery, no shadow, no text.",
  "card_size": "1024x1024",
  "figure_size": "768x1536",
  "ornament_size": "1024x1024",
  "cards": {
    "spark": "A single sharp vermilion lightning bolt striking downward",
    "kindle": "A small vermilion flame rising from a black wick",
    "scorch_notes": "A sheet of paper curling as vermilion fire eats one corner",
    "cinder_burst": "A vermilion starburst of angular shards flying outward",
    "final_recitation": "A tall column of vermilion flame rising from an open black book",
    "frost_lance": "A long blue icicle angled like a spear",
    "hoarfrost": "A flat blue six-pointed frost crystal",
    "glass_shard": "Three angular blue glass fragments, one catching pale slate light",
    "numb_the_hall": "A blue arch of frost closing across a doorway",
    "winter_term": "A bare black tree under a large flat blue circle",
    "ink_blot": "A single spreading black ink blot with one trailing drip",
    "marginalia": "A black quill nib beside three short marginal strokes",
    "cite_source": "An open black book with one page turned, a slate ribbon marker",
    "cram": "A tall stack of black books with a small saffron lamp at the top",
    "thesis_statement": "A rolled black scroll bound with a saffron cord",
    "rot_seed": "A single moss-green seed splitting open with a dark tendril",
    "bitter_recall": "A moss-green hand offering a small dark fruit",
    "necrology_note": "A moss-green skull resting on a folded page",
    "feed_the_curriculum": "A moss-green vine coiling tightly around a black book",
    "guard": "A plain saffron kite shield, flat and unadorned",
    "rimeward": "A saffron shield with a pale slate frost edge",
    "study_break": "A saffron cup with a curl of steam above it",
    "warded_bracers": "A pair of saffron forearm bracers seen straight on",
    "honours_sigil": "A saffron laurel ring enclosing a small black star"
  },
  "figures": {
    "novice": "A nervous young apprentice in a plain undyed cream robe clutching an oversized black book",
    "glass_tutor": "A tutor in a pale slate robe with three blue glass shards orbiting one raised hand",
    "hall_monitor": "A brisk hall monitor in a saffron uniform robe with a rolled timetable under one arm",
    "drillmaster": "A broad-shouldered drillmaster in blue training robes with a bound weight on a cord",
    "alchemy_master": "An alchemy master in a stained moss-green robe with a bandolier of flasks",
    "battle_chanter": "A battle chanter in reinforced vermilion robes with a shield strapped to one arm",
    "proctor": "A stern proctor in a saffron and slate robe holding a brass badge and a ledger",
    "vice_chancellor": "An imposing vice-chancellor in a heavy black ceremonial robe carrying a great ledger",
    "rector": "The Rector, a towering figure in a deep black and saffron robe beneath a ring of floating marks"
  },
  "ornament": {
    "card_back": "A flat cream card back with a single centred saffron ring and fine halftone grain",
    "paper_grain": "A flat even field of warm cream paper with visible risograph halftone grain and nothing else on it",
    "tier_1": "A flat blue circular medallion with a plain cream centre",
    "tier_2": "A flat saffron circular medallion with a plain cream centre",
    "tier_3": "A flat vermilion circular medallion with a plain cream centre"
  }
}
```

- [ ] **Step 4: Write `tools/recraft.py`**

```python
#!/usr/bin/env python3
"""Generates game art through the Recraft API.

    tools/recraft.py list
    tools/recraft.py card spark --n 4
    tools/recraft.py figure novice --n 4
    tools/recraft.py ornament card_back --n 2

Prompts live in assets/prompts/manifest.json, never here, so the asset set has one
source of truth. The flat screenprint style is generated straight onto the cream
ground, so there is no background-removal or projection step.

Needs RECRAFT_API_KEY. A generation is roughly 35 credits (about $0.035).
"""

import argparse
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

API = "https://external.api.recraft.ai/v1"
ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets" / "prompts" / "manifest.json"
SOURCE = ROOT / "assets" / "source"

# Recraft serves WebP whatever the URL says, and Godot picks its loader from the
# extension, so files must be named for what they actually are.
MAGIC = {b"\x89PNG": ".png", b"RIFF": ".webp", b"\xff\xd8\xff": ".jpg"}

# Which manifest group maps to which sprite directory and size/rules keys.
GROUPS = {
    "card": ("cards", "cards", "card_rules", "card_size"),
    "figure": ("figures", "entities", "figure_rules", "figure_size"),
    "ornament": ("ornament", "ornament", "card_rules", "ornament_size"),
}


def die(message):
    sys.exit("recraft: " + message)


def load_manifest():
    with open(MANIFEST) as f:
        return json.load(f)


def post(path, body):
    key = os.environ.get("RECRAFT_API_KEY")
    if not key:
        die("RECRAFT_API_KEY is not set")
    request = urllib.request.Request(
        API + path,
        data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except urllib.error.HTTPError as e:
        die("%s -> HTTP %d: %s" % (path, e.code, e.read().decode()[:400]))


def download(url, stem):
    """Saves an image, naming it for its real format. Returns the path."""
    # The CDN rejects urllib's default user agent.
    request = urllib.request.Request(url, headers={"User-Agent": "curriculum-assets"})
    with urllib.request.urlopen(request) as response:
        data = response.read()
    suffix = next((s for magic, s in MAGIC.items() if data.startswith(magic)), ".bin")
    path = stem.with_suffix(suffix)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def generate(kind, name, n):
    manifest = load_manifest()
    group, out_dir, rules_key, size_key = GROUPS[kind]
    subjects = manifest.get(group, {})
    if name not in subjects:
        die("no subject %r in manifest group %r" % (name, group))

    # Subject first, then the shared clauses. Colour belongs to the subject line: in
    # the shared style clause it overrides every subject's own colour.
    prompt = ". ".join(
        [
            subjects[name],
            manifest[rules_key],
            manifest["style"],
            manifest["palette"],
        ]
    )
    result = post(
        "/images/generations",
        {
            "prompt": prompt,
            "model": manifest["model"],
            "size": manifest[size_key],
            "n": n,
        },
    )
    urls = [item["url"] for item in result.get("data", [])]
    if not urls:
        die("no images returned")

    written = []
    for i, url in enumerate(urls, start=1):
        stem = SOURCE / out_dir / ("%s-%d" % (name, i) if len(urls) > 1 else name)
        written.append(download(url, stem))
    for path in written:
        print(path.relative_to(ROOT))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list")
    for kind in GROUPS:
        p = sub.add_parser(kind)
        p.add_argument("name")
        p.add_argument("--n", type=int, default=4, help="1-6 variants")

    args = parser.parse_args()
    if args.command == "list":
        manifest = load_manifest()
        for kind, (group, _out, _rules, _size) in GROUPS.items():
            for name in sorted(manifest.get(group, {})):
                print("%-9s %s" % (kind, name))
        return
    if not 1 <= args.n <= 6:
        die("--n must be between 1 and 6")
    generate(args.command, args.name, args.n)


if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Write `tools/import_assets.gd` and `tools/import-assets.sh`**

```gdscript
extends SceneTree

## Copies chosen art from assets/source into assets/sprites as .png at its final size,
## then reports what is still procedural. --status only reports.

const SOURCE := "res://assets/source"
const SPRITES := "res://assets/sprites"

const SIZES := {"cards": Vector2i(400, 400), "entities": Vector2i(360, 720), "ornament": Vector2i(256, 256)}


func _process(_delta: float) -> bool:
	var status_only := OS.get_cmdline_user_args().has("--status")

	if not status_only:
		for group in SIZES:
			var in_dir := "%s/%s" % [SOURCE, group]
			var out_group := "cards" if group == "cards" else group
			var dir := DirAccess.open(in_dir)
			if dir == null:
				continue
			DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path("%s/%s" % [SPRITES, out_group])
			)
			for file in dir.get_files():
				# Variants are named name-1, name-2; only the bare name is accepted.
				var base := file.get_basename()
				if base.contains("-"):
					continue
				var image := Image.load_from_file("%s/%s" % [ProjectSettings.globalize_path(in_dir), file])
				if image == null:
					continue
				image.resize(SIZES[group].x, SIZES[group].y, Image.INTERPOLATE_LANCZOS)
				var out := "%s/%s/%s.png" % [ProjectSettings.globalize_path(SPRITES), out_group, base]
				image.save_png(out)
				print("wrote %s" % out)

	var library: ContentLibrary = load("res://resources/content_library.tres")
	var keys: Array = []
	for card in library.cards:
		keys.append(card.art_id)
	for enemy in library.enemies:
		keys.append(enemy.art_id)
	var missing := ArtLibrary.missing_keys(keys)
	print("%d of %d art keys still procedural:" % [missing.size(), keys.size()])
	for key in missing:
		print("  %s" % key)
	quit(0)
	return true
```

```bash
#!/usr/bin/env bash
# Processes assets/source into assets/sprites and re-imports, because a .png is not
# loadable until Godot has imported it. --status only reports what is still procedural.
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

"$GODOT" --headless --path . --script tools/import_assets.gd -- "${1:-}"
"$GODOT" --headless --import --path . >/dev/null 2>&1
"$GODOT" --headless --path . --script tools/import_assets.gd -- --status
```

- [ ] **Step 6: Write `assets/prompts/recraft.md` and `assets/prompts/README.md`**

`recraft.md` documents the pipeline and how to judge output. Cover, in your own words:
the two shapes of asset (cards and figures), that no background removal or projection
is needed because the style is flat on cream, that `negative_prompt` and `style_id` are
unsupported on V4 so cohesion rests on the shared `style` clause, that colour belongs
in the subject line rather than the shared clause, and that a card must be judged at
200px wide rather than at 1024.

`README.md` is a three-row table pointing at `init.md`, `manifest.json` and
`recraft.md`, noting that `export_presets.cfg` excludes this directory from builds.

- [ ] **Step 7: Run the tests and watch them pass**

```bash
chmod +x tools/recraft.py tools/import-assets.sh
python3 tools/recraft.py list
./tools/check.sh
```

Expected: `list` prints 24 cards, 9 figures and 5 ornaments; `check.sh` PASSES.

- [ ] **Step 8: Commit and push**

```bash
git add -A
git commit -m "feat(art): add the recraft manifest, generator and import pipeline"
git push
```

---

### Task 26: Generate the art set

Costs real money — roughly $7 at 4 variants across 38 subjects. Generate a small batch
first and look at it before committing to the whole set.

**Files:**
- Create: `assets/source/**`, `assets/sprites/**`
- Modify: `.gitignore`

- [ ] **Step 1: Add the raw-output ignore rules to `.gitignore`**

Variants are large and only the accepted one matters.

```gitignore
# Raw generator output. Only the accepted variant is promoted into assets/sprites,
# and the bare-named source file beside it is what gets committed.
/assets/source/**/*-[1-9].webp
/assets/source/**/*-[1-9].png
/assets/source/**/*-[1-9].jpg
```

- [ ] **Step 2: Generate one card and one figure, and look at them**

```bash
python3 tools/recraft.py card spark --n 4
python3 tools/recraft.py figure novice --n 4
ls assets/source/cards assets/source/entities
```

Open the eight files. Judge them at the size they will be shown, not at 1024:

- A card is ~200px wide. Three or four large shapes, no fine detail, strong silhouette.
- Cream ground, not white and not dark. Three inks at most.
- Visible halftone grain, no gradients or soft shading.
- If a subject came back with scenery, a horizon or text, tighten the *shared* rules
  clause and regenerate rather than patching one subject.

- [ ] **Step 3: Promote the variants you chose**

Rename the chosen variant to the bare subject name, which is what
`import_assets.gd` accepts:

```bash
mv assets/source/cards/spark-2.webp assets/source/cards/spark.webp
mv assets/source/entities/novice-3.webp assets/source/entities/novice.webp
./tools/import-assets.sh
```

Expected: the status list shrinks by two keys.

- [ ] **Step 4: Verify the real card renders**

```bash
./tools/shot.sh /tmp/art.png 7 battle
```

The Spark in hand should now be the generated illustration while every other card is
still procedural — that per-sprite fallback is the whole point of the design.

- [ ] **Step 5: Generate the rest**

```bash
for name in $(python3 tools/recraft.py list | awk '$1=="card"{print $2}'); do
  python3 tools/recraft.py card "$name" --n 4
done
for name in $(python3 tools/recraft.py list | awk '$1=="figure"{print $2}'); do
  python3 tools/recraft.py figure "$name" --n 4
done
for name in $(python3 tools/recraft.py list | awk '$1=="ornament"{print $2}'); do
  python3 tools/recraft.py ornament "$name" --n 2
done
```

Promote one variant per subject, then `./tools/import-assets.sh`.

- [ ] **Step 6: Confirm the set is coherent and the suite still passes**

```bash
./tools/import-assets.sh --status
./tools/check.sh
./tools/shot.sh /tmp/final-battle.png 7 battle
./tools/shot.sh /tmp/final-catalog.png 7 catalog
```

Expected: `0 of N art keys still procedural`, PASS, and two screenshots that read as one
coherent set. If the set drifts, tighten the shared `style` clause and regenerate the
outliers rather than accepting a mixed look.

- [ ] **Step 7: Commit and push**

```bash
git add -A
git commit -m "feat(art): generate the mid-century screenprint art set"
git push
```

---

## Phase 7 — Documentation

### Task 27: Rewrite `README.md` and `AGENTS.md`

Both files currently describe a game that no longer exists.

**Files:**
- Create: `README.md`, `AGENTS.md`

- [ ] **Step 1: Write `README.md`**

Cover, in your own words and matching what the code actually does: what the game is
(mobile portrait roguelike deckbuilder set in a dangerous magical academy); the three
mechanics that make it distinct (cards gain XP and evolve mid-battle; examiners hide a
school weakness worth ×1.5 that the Bestiary remembers for the run; your grade decides
how much of a defeated examiner's deck you may copy, kept to a deck cap that grows one
card per course); that dropping to 0 HP is an F rather than death and the second F is
expulsion; how to run it (`godot --path .`, and the published container); the art
direction and its reference; and the development commands table. State the deviations
from `assets/prompts/init.md`: the four-term grade instead of turns-and-damage, the
light mid-century palette instead of dark parchment, and plain classes behind thin
autoloads instead of stateful singletons.

- [ ] **Step 2: Write `AGENTS.md`**

Cover: the commands table (`check.sh`, `shot.sh`, `simulate.gd`, the three content
generators, `generate_theme.gd`, `recraft.py`, `import-assets.sh`, `export-web.sh`); the
directory layout; the event-dictionary convention and the rule that `scripts/core/`
never references the view or UI layers; and the Godot traps this build actually hit —
the class-cache requirement before a fresh clone can test, Godot exiting 0 while
printing `SCRIPT ERROR`, `--headless` not rendering so screenshots need a windowed run
and `frame_post_draw`, containers eating taps unless they are `MOUSE_FILTER_IGNORE`, a
`.png` being unloadable until imported, `SceneTree._init()` having no tree, and card XP
belonging on `CardInstance` rather than `CardData`. Close with the Conventional Commits
rule and the never-force-push rule.

- [ ] **Step 3: Verify every command in both files actually runs**

Documentation that lies is worse than none. Run each one.

```bash
./tools/check.sh
godot --headless --path . --script tools/simulate.gd -- 5
./tools/import-assets.sh --status
python3 tools/recraft.py list
./tools/export-web.sh
```

- [ ] **Step 4: Commit, push, and open the PR**

```bash
git add -A
git commit -m "docs: rewrite the readme and agent guide for the deckbuilder"
git push
gh pr create --title "feat: rebuild curriculum as a roguelike deckbuilder" --body "$(cat <<'BODY'
Replaces the isometric tactical roguelike with the deckbuilder in
`assets/prompts/init.md`. Spec and plan are in `docs/superpowers/`.

**Where to look**
- `scripts/core/` — all rules, headlessly testable, event-dictionary returns
- `scripts/core/CardInstance.gd` — XP is per-copy and per-run; it must never reach `CardData`
- `scripts/core/Grading.gd` — four terms, so learning is scored rather than punished
- `scripts/core/Draft.gd` — the deck cap grows per course, not per tier
- `scripts/core/Catalog.gd` — `validate()` is what makes two-F permadeath fair

**Risks**
- Balance is unproven beyond `tools/simulate.gd`'s greedy policy.
- `.github/` was kept unmodified, so the five tool contracts in `tools/` must keep their names.
- Art is generated; per-sprite procedural fallback covers anything missing.
BODY
)"
```

---

## Self-Review

Checked after writing, against the spec.

**Spec coverage.** §1 reset → Task 1. §1.1 CI contracts → Task 2. §2 loop → Tasks 21–24.
§3 combat → Tasks 5–9. §3.1 statuses → Task 6. §3.2 schools → Task 1. §4 evolution →
Task 4. §5 weakness → Task 8. §6 grading → Task 10. §6.1 F-not-death → Task 13. §7 draft
→ Task 11. §8/§8.1/§8.2 catalog → Tasks 12, 18. §9 art direction → Tasks 19, 25, 26.
§9.1 palette → Global Constraints, Task 19. §9.5 card layout → Task 20. §10.1 layout →
File Structure. §10.2 events → Task 9. §10.3 autoloads → Task 15. §10.4 data → Tasks 3,
7, 12. §10.5 persistence → Task 14. §10.6 portrait → Task 1. §11 content → Tasks 16–18.
§12 testing → every task. §13 deferred → not built, correctly. §14 assumptions → carried
into the tasks that depend on them.

Two spec test suites were renamed for clarity: `test_schools` covers the enum and
`test_schools_multiplier` the ×1.5/×0.5 behaviour, and `Combatant` got its own
`test_combatant` rather than living in `test_battle`. `test_tooling` and `test_autoloads`
are additions the spec does not list.

**One spec gap, resolved in the plan and flagged to the user:** the examiner's turn
structure. See "Clarification: the examiner's turn" above.

**Type consistency.** `Schools.School` throughout; `CardData.DAMAGE`-style string
constants for effect kinds; `Statuses.Kind`; `Grading.Grade`. `Bestiary.multiplier` and
`record_hit` take `(enemy, school)` in that order everywhere. `Draft.keep` returns `[]`
on an illegal selection in every caller. `Battle` exposes `examiner_art_id()` and
`examiner_data()` rather than letting the UI read `_enemy_data`.
