# Brief: make Curriculum's examiner content fully generative

A self-contained task brief, written to be handed to an agent or a new contributor.
Everything needed to start is either here or linked from here.

Written 2026-08-01, against `main` at "fix: stop scaling Chill and Blot past their
ceiling (#22)". If the numbers below no longer reproduce, re-measure before trusting
them — every figure here came from `tools/simulate.gd` and is reproducible.

---

## Goal

Examiner **weak schools** and **decks** are authored in a static table and are
identical in every run. Make both generative per run, without regressing difficulty or
the quality of play.

Per-run **warded** schools already work — `scripts/core/Faculty.gd` rolls them from a
run seed. Extend that machinery; do not replace it.

Out of scope unless you finish early: per-run course choice (offering 2–3 of the
available nodes rather than all). If you do it, note that it needs its own reachability
invariant — `Catalog.validate()` checks the whole prerequisite graph, not a sampled
subset, and spec section 8.2's guarantee that a legal path always exists does not
survive naive sampling.

## Read these first

- [`docs/superpowers/specs/2026-07-31-curriculum-deckbuilder-design.md`](superpowers/specs/2026-07-31-curriculum-deckbuilder-design.md)
  — the design spec. Authoritative on intent **except** where noted below.
- [`assets/prompts/init.md`](../assets/prompts/init.md) — the original brief. Overrides
  the spec where the two differ.
- [`docs/audit-2026-08-01.md`](audit-2026-08-01.md) — a measured audit of this game,
  including the failed first attempt at this exact task (finding 5).
- `scripts/core/Faculty.gd` — per-run examiner variants. Its header documents why only
  wards are currently rolled, with the numbers.
- `tools/generate_enemies.gd` — the authored roster, and two tuning rules in its header
  that you must keep obeying.

## Two decisions already made — do not reopen

1. **Examiners never telegraph and never pre-commit their turn.** They resolve live and
   hidden. This supersedes spec section 3, which calls the face-up intent "the
   load-bearing one". The owner decided this explicitly. Do not add intent display.
2. **The three autoloads (`GameManager`, `DeckManager`, `GradeManager`) stay.** The
   brief requires them by name (section A). Do not collapse them.

## The hard part, and why the obvious approach fails

Randomising weak schools has already been tried and measured. Over 120 runs across 12
generated worlds, greedy bot:

| configuration | graduated | courses/run |
| --- | --- | --- |
| authored weak + authored ward | 17.5% | 10.4 |
| authored weak + random ward (current `main`) | 12.5% | 9.2 |
| random weak + authored ward | 6.7% | — |
| random weak + random ward | 3.3% | 6.9 |

The authored weaknesses are load-bearing for two reasons:

1. **They are an implicit tutorial.** The opening courses are weak to Cinder and Ink —
   exactly the starting deck (4x Spark/Cinder, 4x Guard/Ward, 2x Ink Blot/Ink) — and
   warded against Frost, which the player owns none of. That teaches the weakness
   mechanic while the deck is still tiny.
2. **The entire roster was tuned assuming those matchups.** Every examiner's hit points
   and deck were balanced against a specific weakness, so rolling it changes the
   difficulty of every fight at once.

Constraining the roll is **not sufficient on its own**: forcing every examiner to be
weak to a school the player already owns still only reached 7.5%.

**Therefore weaknesses and decks are one job, not two.** Both require retuning the
roster to be *school-agnostic*: no deck may be degenerate under any weak/ward
assignment, and no fight's difficulty may rest on the player's opening schools. Expect
a full roster pass as part of this, comparable in size to the one in PR #19.

## Constraints the generator must satisfy

**Never mutate shared Resources.** `EnemyData` and `CardData` are `.tres` singletons.
Per-run variation goes on duplicates (`Faculty` already does this). Writing a rolled
value onto a library resource leaks it into every later run in the session — spec
section 4 calls this the easiest bug to get wrong invisibly, and it is why card XP
lives on `CardInstance`, not `CardData`.

**Generation must be pure in `(roster, seed, ...)`.** `SaveGame` stores only
`content_seed` and rebuilds the faculty on load. If generation becomes impure, a
continued run gets a different world and every Bestiary entry silently becomes a lie.
Add a test that a save/load mid-run reproduces identical examiners.

**`enemy_name` must survive untouched** — it is the `Bestiary`'s key, and spec section
8 requires knowledge learned about a type to pay off when you meet it again.

**Weak != warded**, always (spec section 5).

**`Catalog.validate()` must keep passing** — every non-gate examiner appears in at
least two courses, and no honors node gates a required one. `tools/generate_courses.gd`
exits non-zero if not.

### Deck generation rules, learned the hard way

- **Damage density beats hit points.** A fight is lost to what lands per turn, not to
  how long it takes. Three Chill sources made one fight a 13.3-turn slog at a 0% loss
  rate — Chill cuts the **player's** damage, so every Chill lengthened the fight, which
  produced more Chill.
- **Watch the cost curve against the examiner's mana.** Regulars have 2 mana, gates and
  the final have 3. An all-1-cost deck at 2 mana plays **two** cards a turn: removing
  one 2-cost card from a deck to shorten fights made that course *worse*, a 37% to 53%
  loss. Keep at least one card the examiner cannot double up on.
- **Decay must stay rare.** It grows by 2 per tick and the player can never remove a
  stack — Block absorbs the damage, but nothing shrinks the stack. One Rot Seed left
  running seven turns is 4+6+8+10+12+14+16 = 70 damage. A Decay examiner must not also
  carry sustain, or it lengthens the fight its own win condition scales with.
- **A defensive examiner must never be warded against a school the player relies on.**
  Halving damage against a mostly-Block deck is not a hard fight, it is an unbreakable
  one — this measured a 43% loss over 11.1 turns. `Faculty._is_defensive()` already
  computes this from the deck; reuse it.
- **Chill saturates at 4 stacks, Blot at 3** (`Battle.saturation_stacks()`). Do not
  author past the ceiling; the generator already clamps.
- `tools/generate_content.gd` enforces `TURN_DAMAGE_CAP = 50` on cards.

## Measurement — the part most likely to go wrong

**Never trust an aggregate over generated content.** A generator producing half trivial
and half impossible worlds averages to a perfectly respectable number. The first
attempt at this task read as "20% to 3%" in aggregate but as **10 of 12 worlds at a
flat 0%** per world — only the second number diagnosed it.

```sh
./tools/check.sh                                                 # the gate; must stay green
godot --headless --path . --script tools/simulate.gd -- 120 12   # <runs> <worlds>
godot --headless --path . --script tools/policy_probe.gd -- 60
```

`simulate.gd` reports graduation **per world**, a per-course table (attempts, loss
rate, hit points in and out, turns), and the difficulty curve. Content seed and shuffle
seed vary independently — keep it that way, or a bad generator is indistinguishable
from bad luck.

`policy_probe.gd` answers whether skill still discriminates, by running deliberately
bad policies. When a probe policy reports a null result, **check its divergence counter
first** — a policy whose trigger never fires reads as a cleared exploit while having
tested nothing. That happened once already, and the null result was briefly published
as a cleared exploit before being caught.

**Run a control before concluding anything.** Keep your new plumbing in place but pin
the generated values to the authored ones. If the control does not reproduce baseline,
your plumbing is broken and the generator is not the story. This is exactly how the
weakness regression was correctly attributed rather than guessed at.

## Acceptance criteria

1. `./tools/check.sh` green. Current baseline: 28 suites, 3733 checks, 0 failures.
2. Greedy bot graduates **10–20%** of runs (`simulate.gd -- 120 12`). Current `main` is
   ~11%, at the low end, so there is room upward but not downward.
3. **No generated world is unwinnable.** Judge on the per-world spread, not the mean.
   Baseline spread on `main` is 0–30% across 12 worlds with a handful at 0%; a handful
   of 0% worlds at 10 runs each is consistent with noise, a majority is not.
4. Skill still discriminates in `policy_probe.gd`: `greedy` clearly ahead of
   `nodefence` on mean score and grade quality (currently 74.5 against 68.9, with about
   2.7x the A grades). If cheaper fights make never-defending fine again, you have
   undone the most important finding in the audit.
5. Save/load mid-run reproduces the identical faculty and decks, under test.
6. No shared `.tres` is mutated at runtime, under test.
7. Content generation stays in `scripts/core/` (runtime, per-run). `tools/generate_*.gd`
   remains build-time authoring — it writes the `.tres` files that seed generation.

## Working agreement

- Commit and push often; do not batch into one commit at the end.
- Branch from `main`; never force-push, amend, or rebase a pushed commit. Follow-up
  commits only.
- PR titles are conventional-commit format (a CI check enforces it). PR descriptions
  should be short and reviewer-focused: what changed, what to look at, what the risks
  are. No AI attribution footer.
- Comments explain *why*, especially where a value was chosen by measurement. Match the
  density and voice of the surrounding code, which is unusually well-commented and
  records the reasoning behind tuning decisions.
- If a measurement contradicts a claim in the audit or the spec, **say so and correct
  the document**. Several findings in that audit were wrong and were withdrawn on
  evidence; that is the expected standard, not a failure.
