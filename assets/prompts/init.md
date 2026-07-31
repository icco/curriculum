# Game Design Document: Curriculum

## 1. Meta & Overview
*   **Game Title:** Curriculum
*   **Engine:** Godot 4.x (GDScript)
*   **Platform:** Mobile (Targeting iOS/Android)
*   **Screen Orientation:** Portrait (1080x1920 or scalable equivalent)
*   **Genre:** Roguelike Deckbuilder RPG
*   **Theme:** Dark Fantasy / Dangerous Magical Academy
*   **Core Design Pillar:** *"The only way to learn is by playing. The only way to win is by learning."*

## 2. Core Gameplay Loop
1.  **Enroll:** Player selects a course from the "Course Catalog" map.
2.  **Attend (Combat):** Player fights exams/enemies using a deck of spell cards.
3.  **Learn (Mid-Combat):** Playing cards grants them XP, evolving them during the battle.
4.  **Grade:** Post-combat, the player is graded (S, A, B, C, F) based on performance.
5.  **Progress/Expulsion:** Grades dictate map branching. Two "F" grades result in permadeath (Game Over).

## 3. Progression: The Course Catalog Map
The overworld map is structured like a university syllabus or skill tree. 
*   **Prerequisites:** Players cannot enter Tier 2 courses (e.g., *Pyromancy 201*) without passing Tier 1 courses (e.g., *Basic Arcana 101*).
*   **The Grading System:**
    *   **S/A (Honors):** Unlocks hidden "Honors" branches on the map for high-tier loot.
    *   **B/C (Pass):** Unlocks standard sequential courses.
    *   **F (Fail):** Player receives an "Academic Probation" strike. 
*   **Expelled by Death:** Accumulating **two "F" grades** across a single run results in immediate, permanent death and a Game Over screen.

## 4. Combat & Deckbuilding Mechanics
Combat is turn-based, focusing on resource management and card evolution.
*   **Player Stats:** Health (HP) and Mana/Energy (replenished each turn).
*   **Hand & Drawing:** Player draws 5 cards per turn. Unplayed cards are discarded at the end of the turn.
*   **"Learn By Playing" (Card Evolution):** 
    *   Cards have hidden internal XP counters. 
    *   Every time a card is played in combat, it gains 1 XP. 
    *   Upon reaching an XP threshold (e.g., 5 XP), the card instantly transforms into its upgraded version (e.g., *Spark* -> *Lightning*) in the player's deck.
*   **"Win By Learning" (Enemy Bestiary):**
    *   Enemies have hidden wards or weaknesses. 
    *   Hitting an enemy with the correct element/card type permanently reveals that weakness in the "Student Bestiary," granting a permanent damage multiplier against that enemy type for the rest of the run.

## 5. Technical Architecture & Godot Agent Instructions
Agent, please structure the Godot project using the following guidelines:

### A. Core Systems & Singletons (Autoloads)
*   `GameManager.gd`: Tracks current run state, strikes (Fail count), and current floor.
*   `DeckManager.gd`: Manages the player's active deck, discard pile, draw pile, and handles the Card XP evolution logic.
*   `GradeManager.gd`: Calculates combat score (based on turns taken and damage received) to output an S, A, B, C, or F grade.

### B. Scene Structure
*   **Main Menu Scene:** Standard start/options.
*   **Map Scene (`CourseCatalog.tscn`):** 
    *   Use a `GraphEdit` node or a custom `Control` node with `Line2D` to visually represent branching course paths.
*   **Combat Scene (`Battle.tscn`):**
    *   **Top Half:** Enemy sprite, HP bar, and intent indicators (what attack they will do next).
    *   **Bottom Half:** Player HP/Mana UI, and a hand of cards.
    *   **Cards:** Instantiate cards dynamically as `TextureRect` or `Button` nodes. Must support drag-and-drop mechanics (using `_get_drag_data` and `_can_drop_data` or standard Input events).

### C. Data Structures (Custom Resources)
Use Godot `Resource` scripts for easy data management:
*   `CardData.gd`: Properties for `card_name`, `cost`, `base_damage`, `current_xp`, `xp_to_evolve`, and `evolved_card_resource` (points to the next tier card).
*   `EnemyData.gd`: Properties for `enemy_name`, `max_hp`, `attack_patterns`, and `hidden_weakness`.
*   `CourseData.gd`: Properties for `course_name`, `prerequisites` (array), and `guaranteed_card_drop`.

### D. UI/UX Focus for Mobile
*   Ensure all tap targets (buttons, map nodes) are large enough for thumb interactions.
*   Implement a curved card hand layout so cards fan out at the bottom of the screen.
*   Use standard Godot UI themes to easily swap out fonts and colors for a "dark fantasy parchment" aesthetic later.