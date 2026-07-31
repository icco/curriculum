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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_statuses.gd"` to `SUITES`, run `./tools/check.sh`.
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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_combatant.gd"` to `SUITES`, run `./tools/check.sh`.
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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_schools_multiplier.gd"` to `SUITES`, run `./tools/check.sh`.
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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_battle.gd"` to `SUITES`, run `./tools/check.sh`.
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
			var dealt := int(roundf(float(scaled) * chill_scale))
			target.take_damage(dealt)
			return [
				{"type": "damage", "target": target_label, "amount": dealt, "text": "%d damage" % dealt}
			]
		CardData.BONUS_IF_CHILLED:
			if target.statuses.amount(Statuses.Kind.CHILL) <= 0:
				return []
			var bonus := int(roundf(float(scaled) * chill_scale))
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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_grading.gd"` to `SUITES`, run `./tools/check.sh`.
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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_draft.gd"` to `SUITES`, run `./tools/check.sh`.
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

	# Distinct cards first, so a deck of four identical cards does not consume the
	# whole allowance on duplicates.
	var seen := {}
	var ordered: Array = []
	for card in examiner_deck:
		if not seen.has(card):
			seen[card] = true
			ordered.append(card)
	for card in examiner_deck:
		ordered.append(card)

	var taken := 0
	for card in ordered:
		if allowance >= 0 and taken >= allowance:
			break
		offered.append(CardInstance.new(card))
		taken += 1
		if allowance < 0 and taken >= examiner_deck.size():
			break


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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_catalog.gd"` to `SUITES`, run `./tools/check.sh`.
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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_run.gd"` to `SUITES`, run `./tools/check.sh`.
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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_save.gd"` to `SUITES`, run `./tools/check.sh`.
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

- [ ] **Step 2: Register the suite and watch it fail**

Add `"res://tests/test_autoloads.gd"` to `SUITES`, run `./tools/check.sh`.
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
