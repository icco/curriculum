# GAME DESIGN SPECIFICATION & INSTRUCTIONS FOR CODING AGENT

## 1. PROJECT OVERVIEW
You are an expert game developer building a 2.5D Isometric, Turn-Based Tactical Roguelike RPG.
* **Theme:** High School Time-Loop Fantasy/Urban Magic. The player is a solo student repeating a 1-year time loop, fighting classmates and teachers to escape the school.
* **Perspective:** Isometric grid-based camera (2D matrix mapped to isometric screen projection).
* **Core Loop:** Procedurally generated school wings -> Turn-based tactical combat -> Permadeath/Failure -> Reset back to Day 1 (Losing gear, keeping learned magic/skills).

---

## 2. ENGINE & MOBILE SPECIFICATIONS (GODOT 4)

### Engine Framework
* Build the project using **Godot 4.x (GDScript)**.
* Use `TileMapLayer` with Isometric Projection settings for all map layers.
* Ensure the renderer is set to "Mobile" or "Compatibility" for optimal performance across devices.

### Mobile Input & UI Rules
1. **Touch Controls:**
   * **Single Tap:** Select unit / Select tile target / Open interactive object.
   * **Drag/Pan:** Pan the camera around the classroom/floor.
   * **Pinch-to-Zoom:** Zoom the camera in and out on the grid.
2. **Mobile UI Guidelines:**
   * High-contrast UI elements with large touch hitboxes (minimum 48x48dp targets for thumb-friendly play).
   * Auto-scaling CanvasLayers to accommodate various mobile aspect ratios (e.g., 16:9, 19.5:9, iPad 4:3).
3. **Turn Action Confirmation:**
   * Tap tile once to display target movement/attack range path.
   * Tap a second time (or tap a "Confirm" floating button) to commit the action, preventing accidental touch errors.

---

## 3. SYSTEM ARCHITECTURE & CORE MECHANICS

### A. D&D COMBAT MATH & ACTION ECONOMY
Implement a D&D 5e-inspired combat engine:

1. **Action Economy (Per Turn):**
   * **Movement:** Speed measured in feet/tiles (e.g., 30ft = 6 grid tiles).
   * **Action:** Attack, Cast Spell, Dash, Use Item.
   * **Bonus Action:** Minor spells, class features, quick items.
   * **Reaction:** Opportunity attacks when enemies leave adjacent tiles.

2. **Attack & Damage Formulas:**
   * **Melee/Ranged Roll:** Roll `d20 + Attribute Modifier + Proficiency Bonus`. Target hit if `Roll >= Target AC`.
   * **Natural 20:** Automatic hit & double damage dice (Critical Hit).
   * **Cover System:**
     * Half Cover (e.g., Desks, Chairs): +2 AC & +2 Dexterity Saves.
     * Three-Quarters Cover (e.g., Lockers, Pillars): +5 AC & +5 Dexterity Saves.

3. **Spellcasting & Saving Throws:**
   * **Spell Attack Roll:** `d20 + Casting Modifier + Proficiency`.
   * **Spell Save DC:** `DC = 8 + Proficiency Bonus + Casting Modifier`.
   * Target must roll `d20 + Stat Save Modifier >= Spell Save DC` to avoid or reduce spell effects.

---

### B. NETHACK-STYLE PROCEDURAL GENERATION
Implement a dungeon generator styled as a school floor layout:

1. **Grid Matrix:** Standard 2D array mapped to isometric view.
2. **Room Generation:** 
   * Randomly place non-overlapping rectangular rooms ("Classrooms", "Science Labs", "Libraries").
   * Connect rooms using 1-tile wide corridors ("Hallways").
3. **Object & Entity Spawning:**
   * **Obstacles:** Desks, Lockers, Chalkboards, Trash Cans (provide half/full cover and line-of-sight blockage).
   * **Interactivity:** Lockers (chests/loot), Hallway Doors (can be opened/closed/locked), Stairs (leads to next floor/month).
   * **Enemies:** Classmates (mobs/grunts), Hall Monitors (elites), Teachers (floor bosses).
   * **Fog of War:** Unexplored rooms and line-of-sight (Raycasting/Bresenham algorithm) masked in darkness.

---

### C. TIME-LOOP & PERSISTENCE ENGINE
Maintain two distinct data states:

1. **RunState** (Resets on death/loop failure):
   * Current HP, Temp Buffs, Current Floor, Equipped Physical Items/Gear, Consumables.

2. **GlobalState** (Persists across time loops):
   * Unlocked Magic Spells & Skill Tree Node progression.
   * Learned Passives and permanently increased Spell Slot capacity.
   * Story Flags & NPC Dialogue Progression tracker.

---

## 4. DATA STRUCTURES (JSON SCHEMAS)

### Player / Entity Schema
```json
{
  "id": "player_01",
  "name": "Protagonist",
  "level": 1,
  "stats": {
    "str": 10, "dex": 14, "con": 12, 
    "int": 16, "wis": 12, "cha": 10
  },
  "ac": 12,
  "current_hp": 12,
  "max_hp": 12,
  "speed_tiles": 6,
  "spell_slots": { "level_1": 2, "level_2": 0 },
  "unlocked_spells": ["magic_missile", "shield", "firebolt"],
  "equipped_gear": {}
}