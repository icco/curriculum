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
- Produces: `Schools.School` enum with values `CINDER`, `FROST`, `INK`, `ROT`, `WARD`; `Schools.display_name(school: School) -> String`; `Schools.colour(school: School) -> Color`; `Schools.ALL: Array[School]`. `TestCase` base class with `check(condition: bool, message: String)`, `eq(actual, expected, message := "")`, `neq`, `almost(actual: float, expected: float, message := "")`, and `var failures: Array[String]`, `var checks: int`, `func suite_name() -> String`, `func run() -> void`. `tests/run_tests.gd` runs every suite listed in its `SUITES` constant.

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
run/main_scene="res://scenes/Main.tscn"
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

`run/main_scene` points at a scene that does not exist until Task 19. That is fine for headless tests, which never load it; do not create a placeholder.

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

## Headless suite runner. Add every new suite to SUITES.

const SUITES := [
	"res://tests/test_schools.gd",
]


func _process(_delta: float) -> bool:
	var total_checks := 0
	var total_failures := 0
	for path in SUITES:
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
		print("  %-16s %d checks, %d failures" % [suite.suite_name(), suite.checks, suite.failures.size()])
	print("%d checks, %d failures" % [total_checks, total_failures])
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

# class_name globals are unresolvable until this has run at least once.
"$GODOT" --headless --import --path . >/dev/null 2>&1

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

Expected: FAIL. Before `--import` has run, `Schools` and `TestCase` are undeclared. Run it a second time — it must then pass, which is the point of the `--import` line. If it still fails, read the error rather than re-running.

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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_tooling.gd"` to `SUITES` in `tests/run_tests.gd`, then:

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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_content.gd"` to `SUITES`, then run `./tools/check.sh`.
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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_evolution.gd"` to `SUITES`, run `./tools/check.sh`.
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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_deck.gd"` to `SUITES`, run `./tools/check.sh`.
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
