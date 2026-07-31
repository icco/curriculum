# Curriculum — Roguelike Deckbuilder

Design spec, 2026-07-31. Supersedes the isometric tactical roguelike previously in
this repo. Source brief: [`assets/prompts/init.md`](../../../assets/prompts/init.md).

**Pillar:** *The only way to learn is by playing. The only way to win is by learning.*
Every mechanic below is judged against whether it makes that sentence a rule rather
than a slogan.

Godot 4.7.1, GDScript. Mobile portrait, 1080×1920. Genre: roguelike deckbuilder.
Theme: a dangerous magical academy.

---

## 1. The reset

This is a from-scratch rebuild in the existing repo. The previous game — a 2.5D
isometric turn-based tactical roguelike with D&D 5e-shaped combat — is deleted
entirely.

**Deleted:** `scripts/`, `scenes/`, `resources/`, `tests/`, `tools/`, `assets/`
(everything except `assets/prompts/init.md`), `project.godot`, `Dockerfile`,
`docker/`, `export_presets.cfg`, `icon.svg`, `icon.svg.import`, `AGENTS.md`,
`README.md`.

**Kept:** `.github/` (workflows, dependabot, funding), `.gitignore`,
`.yamllint.yml` — it is the config `reviewdog/action-yamllint` reads in
`yaml-json.yml`, so it is live, not leftover — `assets/prompts/init.md`, and git
history.

Nothing is carried over from the old game's code, content, or art. The 134MB of
previously generated Recraft art is dropped; the art direction in §9 is new and
incompatible with it.

### 1.1 Contracts the kept workflows depend on

`.github/` is retained unmodified, so the rebuild must recreate the interfaces its
workflows already call. These are requirements, not suggestions:

| Contract | Called by | Must do |
| --- | --- | --- |
| `tools/ci-install-godot.sh [--with-templates]` | `ci.yml`, `docker.yml`, `release.yml` | Install Godot `$GODOT_VERSION` to `~/godot-bin/godot`; with the flag, also export templates |
| `tools/check.sh` (honours `$GODOT`) | `ci.yml`, `release.yml` | Refresh the script-class cache, run the headless suite, fail on assertions **and** on `SCRIPT ERROR` in output |
| `tools/export-web.sh [--release]` (honours `$GODOT`) | `docker.yml` | Produce `build/web` |
| `tools/ci-android-editor-settings.sh` | `ci.yml` | Write Android SDK/JDK paths into Godot editor settings |
| `Dockerfile` + `docker/` | `docker.yml` | Serve `build/web` on `:8080` with `/healthz` and `application/wasm` for `.wasm` |
| `export_presets.cfg` | `ci.yml`, `docker.yml`, `release.yml` | Presets named exactly `Web`, `Linux`, `Android` |
| Linux export filename | `release.yml` | Must build as `curriculum.x86_64` |

`release.yml` also publishes the web build to GitHub Pages, so the Web preset must
work from a non-root subpath.

`GODOT_VERSION` is pinned to `4.7.1` in the workflows; the project targets that.

Also recreated for local development, not required by CI: `tools/shot.sh`
(windowed run + screenshot — the only way to check anything visual),
`tools/simulate.gd` (headless balance runs), `tools/recraft.py` (art generation),
`tools/generate_theme.gd`, `tools/import-assets.sh`.

---

## 2. Core loop

1. **Enroll** — pick an available course on the Course Catalog map.
2. **Attend** — a one-on-one card battle against that course's examiner.
3. **Learn** — cards gain XP as they are played and evolve mid-battle.
4. **Grade** — scored S/A/B/C/F on speed, survival, learning and discovery.
5. **Register** — rebuild your deck to its cap from your cards plus the cards you
   copied off the defeated examiner. Your grade decides how much of their deck you
   may take.
6. **Progress** — grades open map branches. A second F is expulsion: permadeath.

---

## 3. Combat

Turn-based, one player against one examiner. **Damage is deterministic — there are
no to-hit rolls.** A phone player needs to read the board at a glance, not audit a
dice log; all randomness lives in the shuffle.

- Player: **60 HP**, **3 mana** refilled at the start of every turn.
- Draw **5** cards at the start of your turn. Unplayed cards are discarded at end of
  turn. When the draw pile empties, the discard pile is shuffled into it.
- **Examiners play from decks too.** An examiner draws and plays from its own deck
  under the same mana rules. Its "intent" is simply the card it drew, shown face-up
  above it.

That last point is the load-bearing one. It makes the enemy legible (you are reading
a card, not a mystery icon), it makes the card draft in §7 diegetic (you copy the
spells you just watched them cast), and it costs almost no content — examiner decks
are built from the same `CardData` pool the player draws on.

### 3.1 Statuses

Five, deliberately. Each belongs to a school, so a status on the board tells you what
kind of deck you are facing.

| Status | School | Effect |
| --- | --- | --- |
| **Burn** | Cinder | Deals its value in damage at the start of the bearer's turn, then decrements by 1 |
| **Chill** | Frost | Reduces the bearer's next attack card's damage by 30% per stack; consumed on use |
| **Blot** | Ink | The bearer's next played card has its numbers reduced 40% per stack; consumed on use |
| **Decay** | Rot | Deals its value at end of the bearer's turn, then **grows by 2** |
| **Block** | Ward | Absorbs damage; expires at the start of the owner's next turn |

**Exhaust** is battle-scoped: an exhausted card leaves play for the rest of that
battle and returns to the deck afterwards. It is never destroyed — the only thing
that removes a card from a run is cutting it during Registration (§7).

Decay growing rather than decaying is what makes Rot a long-game school: it loses to
a short fight and wins a long one, which is a direct trade against the grade's speed
term.

### 3.2 Schools

Every card belongs to exactly one school. Schools are the axis the weakness system
in §5 resolves against, and each has a distinct job so a deck acquires an identity:

| School | Ink | Job |
| --- | --- | --- |
| **Cinder** | `#D45C3C` vermilion | Burst damage, Burn |
| **Frost** | `#498BAD` blue | Damage plus Chill; payoff cards that check for Chill |
| **Ink** | `#000000` black | Draw, mana, Blot |
| **Rot** | `#6E7B3F` moss | Decay that scales; often paid for in your own HP |
| **Ward** | `#E0A51F` saffron | Block, healing, retain |

---

## 4. Learning by playing

Playing a card grants it **1 XP**. At **5 XP** it evolves immediately, mid-battle,
into a strictly-better form. One evolution step only: 24 base cards, 24 evolved
forms, 48 `CardData` resources total.

**XP lives on a run-scoped `CardInstance`, never on the `CardData` resource.** Godot
resources are shared singletons: incrementing XP on a `.tres` would leak progress
across runs *and* across every copy of that card in one deck. So the deck is an array
of `CardInstance`, each holding its own XP and a pointer to a `CardData`. Evolution
is that instance swapping its pointer. This is the single most important
implementation constraint in the spec and the easiest to get wrong invisibly.

Evolved cards have `evolved_card == null` and stop gaining XP.

---

## 5. Winning by learning

Each examiner is secretly **weak** to one school and **warded** against another,
never the same one. The multiplier applies to **every number on a card of that
school** — ×1.5 when weak, ×0.5 when warded — not to damage alone.

That generalisation is deliberate. If the multiplier only touched damage, Ward could
never be a weakness, because Ward deals none: three of the ten examiners below would
have had a weakness no card could exploit. Applying it to the card's numbers keeps all
five schools symmetric, so weak-to-Ward means your Block and healing land 50% harder
against that examiner, and blind-guessing stays an honest 1 in 5.

The multiplier applies on the very first hit — the reveal is *information*, not the
reward. Once revealed, it is recorded in the **Bestiary** and holds against every
examiner of that type for the rest of the run. Hitting a warded school also reveals
that, so a wasted hit still buys knowledge.

Blind-guessing is 1 in 5, and the grade's discovery term (§6) pays you for probing,
so spending a turn on an unknown school is never a pure loss.

---

## 6. Grading

The brief specifies grading on "turns taken and damage received". Taken literally
that inverts the pillar: evolution needs cards played *repeatedly* and discovery
needs probing with wrong schools, and both cost turns and HP, so the optimal play
under a pure efficiency score is to never learn. The score therefore has four terms,
25 points each, out of 100.

| Term | Points | Formula |
| --- | --- | --- |
| **Efficiency** | 0–25 | `25 × clamp(par_turns / turns_taken, 0, 1)` |
| **Survival** | 0–25 | `25 × (hp_end / hp_start)` |
| **Learning** | 0–25 | `25 × clamp(xp_banked_this_battle / deck_cap, 0, 1)` — playing through your deck once is full marks |
| **Discovery** | 0–25 | `15` if the examiner's weak school is known by end of battle (revealed now *or* already in the Bestiary) `+ 10 × distinct_schools_played / 5` |

| Grade | Score |
| --- | --- |
| **S** | ≥ 90 |
| **A** | ≥ 75 |
| **B** | ≥ 60 |
| **C** | ≥ 40 |
| **F** | < 40, **or** the battle was lost |

`par_turns` is authored per course.

### 6.1 Dropping to 0 HP is an F, not death

There is exactly one death condition in this game, and it is the second F. Running
out of HP means you failed the exam: you take an F strike, your HP is restored, and
you continue. Permadeath comes only from accumulating **two F grades**, exactly as
the brief specifies.

This is worth stating plainly because it is a real design choice, not an oversight.
It gives the game a single failure axis instead of two competing ones, and it turns a
desperate fight into a gamble on your *grade* rather than on your run — which is the
more interesting bet, and the one the academy fiction wants.

---

## 7. Registration: the card draft

Deck size is capped. After each battle your deck is restored in full — nothing is
lost in combat — then it and the defeated examiner's deck are pooled, and you keep
exactly **`deck_cap`** cards.

| Tiers cleared | `deck_cap` |
| --- | --- |
| 0 (start) | 10 |
| 1 | 12 |
| 2 | 14 |
| 3 | 16 |

Your grade decides how much of the examiner's deck is unlocked in the pool:

| Grade | Cards available from their deck |
| --- | --- |
| S | all of it |
| A | 5 |
| B | 3 |
| C | 1 |
| F | none |

The course's **syllabus card** (`CourseData.guaranteed_card_drop`) is always in the
pool regardless of grade, so a course always teaches you something.

**Cutting a card destroys its earned XP.** That is the decision the screen exists to
pose: a Spark at 4/5 XP against a strictly better but untrained Frost Lance. It also
solves deck bloat — the failure mode of taking four random cards per fight is a
45-card deck by the final in which you never draw your good cards.

The starting deck is 10 cards: 4× Spark (Cinder), 4× Guard (Ward), 2× Ink Blot (Ink).

---

## 8. Progression: the Course Catalog

15 course nodes across 3 tiers plus a final. A course unlocks when every prerequisite
is passed at **C or better**. An **S or A** additionally reveals adjacent honors
nodes, which hold the strongest examiners and the richest decks.

| Tier | Courses |
| --- | --- |
| 1 | Basic Arcana 101, Cantrips 101, Wardcraft 101, *Tutorial 150* (honors), **Proctor's Inspection** (gate) |
| 2 | Pyromancy 201, Cryomancy 201, Necrology 201, Marginalia 201, *Fieldwork 250* (honors), **Midterm Review** (gate) |
| 3 | Thesis 301, Applied Wardcraft 301, *Viva Voce 350* (honors), **Comprehensive Exam** (final) |

A run is 8–10 battles, roughly 20–30 minutes. Passing the Comprehensive Exam breaks
the curriculum and wins the run.

**Ten examiners cover fifteen courses, so examiners repeat.** That is a requirement
rather than a shortcut: a Bestiary entry that grants knowledge "against every examiner
of that type for the rest of the run" is worthless if you never meet the type twice.
Each examiner type must appear in at least two courses, and no course pairs an
examiner with a course whose syllabus card is its own warded school.

### 8.1 The reachability constraint

Prerequisites at C-or-better plus two-F permadeath means the catalog must guarantee
a survivable path exists from any legal state. The generator (or, for a hand-authored
catalog, a content test) must assert that every tier has at least one course whose
prerequisites are satisfiable without an honors grade. Noted here as a requirement on
the content-integrity suite; not solved in this spec.

---

## 9. Art direction

Reference: [Helvetica Blanc, *Catch (Feelings) And Release*](https://merveilles.town/@helveticablanc/116999141342690920).

Mid-century modern screenprint — the Alexander Girard / Charley Harper lineage. Flat
bold shapes with no outlines and no shading, form carried entirely by silhouette. A
tiny palette of flat inks on a warm cream ground, with visible risograph/halftone
grain inside each ink and at its edges. Compositions sit on a large organic field
shape rather than bleeding to the edge, leaving a cream margin like a printed plate.
Small stippled celestial glyphs — a circle, a crescent, a five-pointed star — float
as texture against the flat inks. Title set small in a thin-ruled rectangle in one
corner.

### 9.1 Palette

Sampled from the reference's own PNG palette chunk:

| Role | Hex |
| --- | --- |
| Paper ground | `#F7EADD` |
| Black ink | `#000000` |
| Cinder | `#D45C3C` |
| Saffron / Ward | `#E0A51F` |
| Blue / Frost | `#498BAD` |
| Pale slate | `#A3B0AC` |
| Grain greys | `#999189`, `#6C6661` |
| Moss / Rot *(added)* | `#6E7B3F` |

The reference has no green, so one period-correct moss ink is added for Rot. Nothing
else is invented.

### 9.2 Dark subject, bright print

The brief calls the theme "Dark Fantasy" and asks for a "dark fantasy parchment"
aesthetic. This spec deliberately inverts the *value* while keeping the tone: the
academy is genuinely dangerous, but it is rendered in bright flat mid-century print
on cream, the way Charley Harper renders predation as cheerful geometry. The
`default_clear_color` and the whole `ui_theme.tres` go **light**, not dark.

This is the largest deviation from the brief in the document and it changes every
screen, so it is called out rather than buried.

### 9.3 What this borrows, and what it does not

The *register* is the reference: screenprint flatness, a limited ink palette, riso
grain, celestial stipple glyphs, the ruled title box. Not borrowed: the artist's
invented **Wormrōte** alphabet, or any of their specific compositions. Curriculum
gets its own decorative sigil set — used on card backs, warded-state markers and
ornament, never for text a player must read.

### 9.4 Pipeline

New `assets/prompts/manifest.json` and a new `tools/recraft.py`, same
single-source-of-truth arrangement as before: prompts live in the manifest, never in
the script.

| Subject group | Count |
| --- | --- |
| Base-card illustrations | 24 |
| Examiner portraits | 10 |
| School sigils | 5 |
| Tier backdrops | 3 |
| Course medallions | 3 |
| Ornament / card back / grain plates | ~4 |

~49 subjects at 4 variants ≈ **$7 of Recraft credit** (~35 credits ≈ $0.035 per
generation). Needs `RECRAFT_API_KEY`, which is present in the developer's
environment.

**Evolved cards reuse their base illustration** with a gold-rimmed frame and the
title box filled. That is cheaper and reads correctly: the same spell, now mastered.

Two pipeline simplifications fall out of this style. Because art is generated
directly onto the cream ground, **no background-removal step is needed** — the
generated ground *is* the card's ground. And because the style is flat with no
perspective, there is **no projection step** at all; the old isometric
diamond/block projection tooling has no successor.

Recraft prompting notes carried forward from the previous pipeline, which remain
true: `negative_prompt` is unsupported on V4 models, so say what a thing *is*, never
what it is not; styles/`style_id` are unsupported on V4, so cohesion rests entirely
on a shared style clause applied to every subject; and judge every asset at its real
on-screen size, not at 1024px.

### 9.5 Card layout

Portrait card, 2:3, ~200×300 at a 5-card fan on a 1080-wide screen. From the
reference: the illustration sits on a coloured field shape in the school's ink; the
card name goes in a thin-ruled box; cost is a single stippled circle glyph;
the school reads from ink colour plus its sigil. XP shows as up to five small ticks
along the bottom edge. Because the whole card is flat shapes and type, it stays
legible at fan size — which painterly art at 200px would not.

---

## 10. Technical architecture

### 10.1 Layout

```
scripts/core/   Run, Deck, CardInstance, Battle, Grading, Catalog, Bestiary, SaveGame
                pure logic, RefCounted, no scene nodes, no rendering
scripts/data/   CardData, EnemyData, CourseData, ContentLibrary   (Resource)
scripts/auto/   GameManager, DeckManager, GradeManager            (thin autoloads)
scripts/ui/     BattleScreen, HandFan, CardView, Registration, ReportCard,
                CourseCatalog, BestiaryScreen, MainMenu, GameOver, UIKit
scenes/         Main.tscn composition root, one .tscn per screen
resources/      cards/ enemies/ courses/ + content_library.tres + ui_theme.tres
tests/          one test_*.gd per area, plus TestCase.gd and run_tests.gd
tools/          the scripts in §1.1
assets/         prompts/ (manifest + init.md), source/ raw in, sprites/ processed out
```

`scripts/core/` must not reference `scripts/view` or `scripts/ui`, and core classes
must avoid mutual typed references — GDScript treats those as cyclic and refuses to
parse.

### 10.2 Event dictionaries

Core resolution functions return arrays of event dictionaries
(`{"type": …, "amount": …, "text": …}`) rather than touching the scene tree. The UI
replays them as animation. Tests and the running game therefore exercise the same
code path, which is the only way a 48-card × 10-examiner interaction surface stays
honest.

### 10.3 Autoloads

The brief asks for `GameManager`, `DeckManager` and `GradeManager` as autoload
singletons holding mutable run state. Stateful globals make headless testing
painful — every test must reset three singletons, and state leaks between tests.

So: all rules live in plain `RefCounted` classes a test can construct in isolation.
The three autoloads exist under the brief's names but hold only the *current
instance* and forward to it. Scene code still writes `GameManager.strikes`; tests
never touch a global.

```
autoload GameManager   holds the current Run,  forwards
autoload DeckManager   holds the current Deck, forwards
autoload GradeManager  stateless, calls Grading
```

### 10.4 Data resources

| Resource | Fields |
| --- | --- |
| `CardData` | `card_name`, `school`, `cost`, `effects`, `xp_to_evolve`, `evolved_card`, `art_id` |
| `CardInstance` *(not a Resource — run-scoped `RefCounted`)* | `data: CardData`, `xp: int` |
| `EnemyData` | `enemy_name`, `max_hp`, `mana_per_turn`, `deck: Array[CardData]`, `weak_school`, `warded_school`, `art_id` |
| `CourseData` | `course_name`, `tier`, `prerequisites: Array[CourseData]`, `examiner: EnemyData`, `par_turns`, `guaranteed_card_drop`, `is_honors` |

`.tres` files reference their script by path rather than uid so content loads without
the script-class cache.

### 10.5 Run state and persistence

The `Run` holds: HP, `Array[CardInstance]` deck, `deck_cap`, strikes, a
course→grade map, Bestiary reveals, and current position. Single-slot autosave to
`user://` on every return to the map; the save is deleted on expulsion. Save/load
must round-trip card XP — a `CardInstance` serialises as a `CardData` path plus an
integer.

### 10.6 Portrait setup

`display/window/size/viewport_width=1080`, `viewport_height=1920`,
`window/handheld/orientation="portrait"`, `stretch/mode="canvas_items"`,
`stretch/aspect="expand"`, mobile renderer with `gl_compatibility`.

UI containers are `MOUSE_FILTER_IGNORE` with only buttons set to `STOP`, or
full-rect panels silently eat every tap. Cards are dragged upward to play, per the
brief's drag-and-drop requirement, with a tap-to-inspect alternative.

---

## 11. Content inventory

24 base cards, each with one evolved form. Numbers are a starting point for
balance passes, not final.

### Cinder

| Card | Cost | Effect | Evolves to |
| --- | --- | --- | --- |
| Spark | 1 | 6 damage | Ember Lance — 10 damage |
| Kindle | 1 | 3 Burn | Conflagration — 6 Burn |
| Scorch Notes | 2 | 11 damage | Immolate Notes — 17 damage |
| Cinder Burst | 2 | 5 damage, 3 Burn | Pyre Burst — 8 damage, 5 Burn |
| Final Recitation | 3 | 20 damage, exhaust | Valedictory Blaze — 30 damage, exhaust |

### Frost

| Card | Cost | Effect | Evolves to |
| --- | --- | --- | --- |
| Frost Lance | 1 | 5 damage, 1 Chill | Rime Lance — 8 damage, 1 Chill |
| Hoarfrost | 1 | 2 Chill | Deep Hoarfrost — 3 Chill, 3 damage |
| Glass Shard | 2 | 9 damage, +4 if Chilled | Mirror Shard — 13 damage, +6 if Chilled |
| Numb the Hall | 2 | 2 Chill, 6 Block | Still the Hall — 3 Chill, 10 Block |
| Winter Term | 3 | 12 damage, 4 Chill | Long Winter — 18 damage, 5 Chill |

### Ink

| Card | Cost | Effect | Evolves to |
| --- | --- | --- | --- |
| Ink Blot | 1 | 1 Blot | Spilled Ledger — 2 Blot |
| Marginalia | 1 | Draw 2 | Copious Marginalia — 0 cost, draw 2 |
| Cite Source | 1 | 4 damage, draw 1 | Cite Chapter & Verse — 6 damage, draw 2 |
| Cram | 2 | +2 mana next turn | All-Nighter — 1 cost, +2 mana next turn |
| Thesis Statement | 3 | 8 damage, draw 3 | Defended Thesis — 2 cost, 12 damage, draw 3 |

### Rot

| Card | Cost | Effect | Evolves to |
| --- | --- | --- | --- |
| Rot Seed | 1 | 4 Decay | Blightseed — 6 Decay |
| Bitter Recall | 1 | Lose 3 HP, 12 damage | Bitter Mastery — lose 2 HP, 18 damage |
| Necrology Note | 2 | 5 damage, 5 Decay | Necrology Thesis — 8 damage, 8 Decay |
| Feed the Curriculum | 2 | Lose 5 HP, double all Decay | Feed the Faculty — lose 3 HP, double Decay, draw 1 |

### Ward

| Card | Cost | Effect | Evolves to |
| --- | --- | --- | --- |
| Guard | 1 | 6 Block | Bulwark — 10 Block |
| Rimeward | 1 | 5 Block, retain | Aegis Ward — 8 Block, retain |
| Study Break | 2 | Heal 8 | Restorative Study — heal 14 |
| Warded Bracers | 2 | 10 Block, +4 if a Ward card was already played this turn | Sigil Bracers — 14 Block, +6 |
| Honours Sigil | 3 | 18 Block, heal 6 | Valedictory Sigil — 24 Block, heal 10 |

### Examiners

Seven regular, three gates. Each weak to one school and warded against another;
gate decks contain **evolved** forms, so a boss visibly plays cards you do not have
yet.

| Examiner | Tier | Deck leans | Weak | Warded |
| --- | --- | --- | --- | --- |
| Novice | 1 | Ink | Cinder | Ink |
| Hall Monitor | 1 | Ward | Rot | Cinder |
| Ink Scribe | 1 | Ink | Ward | Ink |
| **Proctor** | 1 gate | Ward / Frost | Cinder | Ward |
| Drillmaster | 2 | Frost | Cinder | Frost |
| Glass Tutor | 2 | Frost | Cinder | Frost |
| Alchemy Master | 2 | Rot | Ward | Rot |
| Battle Chanter | 2 | Cinder | Frost | Cinder |
| **Vice-Chancellor** | 2 gate | Ink / Rot | Frost | Ink |
| **Rector** | 3 final | all five | Rot | Ward |

---

## 12. Testing

`tools/check.sh` is the gate and runs in CI unchanged. Suites, one `test_*.gd` each:

| Suite | Covers |
| --- | --- |
| `test_deck` | Draw, discard, reshuffle on empty, hand size, end-of-turn discard |
| `test_evolution` | XP accrual, threshold, pointer swap, XP does **not** touch `CardData`, evolved cards stop gaining |
| `test_battle` | Mana, card resolution, Block absorption, status ticks, win/loss |
| `test_schools` | ×1.5 / ×0.5 multipliers, reveal on first hit, Bestiary persistence across battles |
| `test_grading` | Each of the four terms in isolation, thresholds, loss ⇒ F |
| `test_draft` | Cap enforcement, pool gating by grade, syllabus card always present, XP destroyed on cut |
| `test_catalog` | Prerequisite gating, honors reveal on S/A, reachability assertion (§8.1), every examiner type used by ≥2 courses (§8) |
| `test_run` | Strikes, F on 0 HP with HP restored, expulsion on the second F |
| `test_save` | Round-trip including card XP and Bestiary state |
| `test_content` | Every `.tres` loads, every `evolved_card` resolves, no card is its own evolution, every examiner deck is legal and non-empty, every course's prerequisites exist |
| `test_ui` | Screen wiring, hand fan layout, mouse-filter correctness |
| `test_art` | Manifest/`art_id` agreement, procedural fallback for every missing sprite |
| `test_playthrough` | A full scripted 9-battle run to the Comprehensive Exam |

Godot exits 0 while printing `SCRIPT ERROR` every frame, so `check.sh` greps output
as well as checking the exit code. A fresh clone cannot run tests until
`godot --headless --import` has built `.godot/global_script_class_cache.cfg`;
`check.sh` does that first.

---

## 13. Deferred

Not in this build, recorded so they are not mistaken for oversights:

- Meta-progression across runs. The brief's roguelike loop is run-scoped; the
  Bestiary resets each run.
- Multi-enemy battles. One examiner per course.
- Relics, potions, gold, shops, rest sites.
- Localisation. Card text is English in the `.tres`.
- Audio.

---

## 14. Assumptions

Places the brief was silent and this spec chose:

1. Card XP persists for the whole run once earned, and evolution triggers mid-battle.
   The brief says both "evolving them during the battle" and "transforms … in the
   player's deck"; this reads them as the same event.
2. Damage is deterministic; the only randomness is the shuffle.
3. One evolution step per card, not a chain.
4. `par_turns` is authored per course rather than derived.
5. A course may be attempted only once per run, pass or fail.
6. Losing a battle costs an F and restores HP, rather than ending the run (§6.1).
7. The catalog is hand-authored rather than procedurally generated, so §8.1's
   reachability requirement is a content test rather than a generator constraint.
