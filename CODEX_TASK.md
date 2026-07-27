> **LEGACY UYARISI:** Bu belge tarihsel Demo 0.1 (eski 2D prototip) şartnamesidir.
> Güncel uygulama planı olarak kullanılmamalıdır. Aktif akış `main_menu.tscn` üzerinden
> `main_2_5d.tscn` sahnesine açılan Godot 4.6 geliştirme yapısıdır.

# CODEX TASK — KÖKLER Demo 0.1

We are working inside an existing Godot 4 project folder.

Project root:
C:/Users/Berat Sağır/Documents/Projects/kokler_godot

Important:
- Do not create a nested project folder.
- Use the existing project.godot file.
- Use Godot 4.x and GDScript.
- Build a small playable 2D prototype, not the full game.
- Keep everything simple, readable, and easy to debug.
- No external assets.
- No audio.
- No advanced art.
- Do not overengineer the prototype.

---

# GAME VISION — KÖKLER

KÖKLER is a dark, earthy, top-down roguelike prototype about descending into a buried underground city called Kökaltı.

This is not a heroic fantasy game.
It should feel quiet, oppressive, old, and mysterious.

The world is not simply evil.
Kökaltı does not only try to kill the player.
It tries to make the player forget, repeat, and lose direction.

The first playable demo should communicate this mood with very simple tools:
- dark earth-colored backgrounds
- narrow rooms
- simple but readable shapes
- short lore messages
- locked paths
- rats, shadows, and underground silence
- a feeling of being watched by the level itself

## Core fantasy

The player controls Asha, the daughter of a missing mapmaker.

Her father disappeared while searching for Kökaltı.
He left behind an unfinished map and a warning:

“Kökaltı gerçek. İnme. Geri dön.”

Asha enters anyway.

Every run is a descent.
Every death means returning, but not empty-handed.
For Demo 0.1, there is no full meta-progression yet, but the mood should already suggest that death and memory are connected.

## Tone

The game should avoid:
- colorful arcade style
- comedy
- generic fantasy hero language
- bright magical effects
- over-explaining the story

The game should prefer:
- short sentences
- silence
- uncertainty
- old ruins
- underground pressure
- memory fragments
- strange warnings
- minimal UI
- earthy darkness

## Visual direction for placeholder art

Use simple placeholder visuals, but make them intentional.

Suggested colors:
- background: very dark brown / near black
- floors: muted soil brown
- walls: darker stone brown
- player: pale warm color
- enemies: dark red or black
- key: muted gold
- exit: cold green or pale white
- UI: parchment-like off-white text

Even if everything is made of rectangles and circles, it should feel like an underground ruin, not a test room.

## Gameplay feeling

The prototype should feel like this:

The player wakes in a small underground chamber.
There are several connected rooms.
Some rooms contain Blind Rats.
The player must clear rooms, find a key, and reach the exit.

The important feeling is:

“I am not clearing levels. I am going deeper into something that remembers me.”

## Player character: Asha

Asha should feel fragile but capable.

She is not a knight.
She is not a superhero.
She survives through movement, timing, and short violent decisions.

Gameplay identity:
- quick movement
- short-range melee attack
- dash to escape danger
- limited health
- vulnerable if surrounded

## Enemy: Blind Rat

Blind Rats are the first enemy type.

They are not just animals.
They are creatures adapted to Kökaltı.

Behavior:
- they move directly toward the player
- they are dangerous in groups
- they should pressure the player to move
- they do not need complex AI in Demo 0.1

Atmosphere:
Blind Rats should feel like the first sign that the underground city is not abandoned.

## Rooms

Rooms should feel like fragments of a buried place.

Possible room moods:
- collapsed root chamber
- old storage room
- broken map room
- narrow tunnel
- abandoned shrine-like space
- damp stone room

For Demo 0.1, these can all be simple rectangles, but use names/comments in code to preserve the design direction.

## Lore fragments

Use short, sharp lore lines.

Examples:
- “Kökaltı seni öldürmez. Seni sadeleştirir.”
- “Baban buradan geçmiş. Duvar bunu hatırlıyor.”
- “Haritalar yukarıdakiler içindir. Aşağıda yollar canlıdır.”
- “Bir kapı açıldı. Bir şey seni içeri saydı.”
- “Toprak nefes almıyor. Dinliyor.”

Only show one or two lore messages in Demo 0.1.
Do not create a full dialogue system yet.

---

# DEMO 0.1 GOAL

Build the first playable prototype.

The player should be able to:
1. Move through a small underground room layout.
2. Dash to avoid enemies.
3. Attack Blind Rats.
4. Take damage and die.
5. Clear rooms.
6. Find a key.
7. Use the key to reach the exit.
8. See a victory message.

The goal is not to make a beautiful game yet.
The goal is to make a playable underground heartbeat.

---

# REQUIRED FOLDERS

Create or update:

res://scenes/
res://scripts/

Do not move project.godot.
Do not create another Godot project inside this project.

---

# REQUIRED SCENES

Create these scenes:

res://scenes/main.tscn
res://scenes/player.tscn
res://scenes/blind_rat.tscn
res://scenes/key_pickup.tscn
res://scenes/exit_gate.tscn
res://scenes/ui.tscn

Use simple placeholder visuals only:
- ColorRect
- Polygon2D
- Sprite2D with simple generated shapes
- CollisionShape2D
- Area2D
- CharacterBody2D
- StaticBody2D
- Node2D
- CanvasLayer / Control for UI

No imported sprites.
No external textures.
No audio.

---

# REQUIRED SCRIPTS

Create these scripts:

res://scripts/player.gd
res://scripts/blind_rat.gd
res://scripts/game_manager.gd
res://scripts/room_generator.gd
res://scripts/key_pickup.gd
res://scripts/exit_gate.gd
res://scripts/ui.gd

Optional if useful:
res://scripts/camera_follow.gd

Keep each script focused.
Avoid putting all game logic into one giant file.

---

# MAIN SCENE

Create main.tscn as the playable scene.

Main should include:
- GameManager
- RoomGenerator
- Player
- UI
- Camera2D following the player if needed

If possible, set this as the project main scene:

res://scenes/main.tscn

The game should run when pressing Play in Godot.

---

# PLAYER

Create a Player scene using CharacterBody2D.

Player node requirements:
- Root node: CharacterBody2D
- CollisionShape2D
- Simple visible placeholder body
- AttackArea or temporary attack hitbox
- Camera2D can be inside Player or inside Main

Player features:
- WASD movement
- Dash with cooldown
- Basic melee attack
- Temporary Area2D hitbox for attack
- Health system
- Can take damage
- Dies when health reaches 0
- On death, restart the run

Controls:
- W / A / S / D: move
- Space: dash
- Left mouse button or J: attack

Movement:
- Movement should feel responsive.
- Dash should be short and fast.
- Dash should have a visible cooldown.
- Player should not dash infinitely.

Combat:
- Attack should create or activate a short-range hitbox.
- Attack should damage enemies inside the hitbox.
- Attack should have a short cooldown.
- The hitbox should disappear or deactivate after the attack.

Suggested starting stats:
- Player max HP: 5
- Move speed: 180
- Dash speed: 520
- Dash duration: 0.15 seconds
- Dash cooldown: 0.8 seconds
- Attack damage: 1
- Attack cooldown: 0.35 seconds

---

# ENEMY — BLIND RAT

Create one enemy type:

Blind Rat

Root node:
- CharacterBody2D

Required:
- CollisionShape2D
- Simple visible placeholder body
- Script: res://scripts/blind_rat.gd

Features:
- Follows player
- Has health
- Takes damage from player attack
- Damages player on contact
- Dies when health reaches 0

Keep AI simple:
- Move directly toward player.
- No pathfinding required for Demo 0.1.
- If the rat touches the player, damage the player with cooldown.

Suggested starting stats:
- HP: 2
- Move speed: 85
- Contact damage: 1
- Contact damage cooldown: 0.8 seconds

Atmosphere:
Blind Rats should be dark, fast enough to pressure the player, but not unfair.

---

# PROCEDURAL ROOM LAYOUT

Create a simple room generator.

Script:
res://scripts/room_generator.gd

Requirements:
- Generate 5 to 8 rectangular rooms.
- Use a simple grid layout.
- One start room.
- One key room.
- One exit room.
- Some combat rooms with Blind Rats.
- Use placeholder rectangles for floors and walls.
- Connect rooms with simple corridors, visible door gaps, or simple passage rectangles.

Do not overengineer this.
A readable, working room layout is more important than perfect procedural generation.

Acceptable simple implementation:
- Place rooms on grid coordinates.
- Use rectangles for floors.
- Use StaticBody2D walls or simple blocking rectangles.
- Connect neighboring rooms with corridor rectangles.
- Spawn player in the start room.
- Spawn key in the key room.
- Spawn exit in the exit room.
- Spawn 1 to 3 Blind Rats in combat rooms.

The room layout does not need to be beautiful.
It needs to be playable.

---

# ROOM CLEAR LOGIC

Each combat room should know how many enemies are alive.

When all enemies in the current room are dead:
- Open the way forward.
- Allow the player to continue.

For Demo 0.1, this can be simplified:
- Spawn enemies in rooms.
- Doors or blocking rectangles can disappear when enemies are defeated.
- If proper room-by-room locking is too complex, make a simpler version:
  - Rooms are connected.
  - Enemies exist.
  - Player can still complete the key and exit loop.

Priority:
1. Playable movement and combat.
2. Key and exit loop.
3. Basic room generation.
4. Door locking and room clear logic.

Do not break the playable prototype for the sake of a complex door system.

---

# KEY PICKUP

Create key_pickup.tscn.

Root can be Area2D.

Required behavior:
- Player can pick up the key.
- Key disappears after pickup.
- GameManager stores has_key = true.
- UI updates key status.

Visual:
- Muted gold rectangle, circle, or simple polygon.
- It should be visible and readable.

---

# EXIT GATE

Create exit_gate.tscn.

Root can be Area2D.

Required behavior:
- If player has key:
  - Trigger victory.
  - Show victory screen/message.
- If player does not have key:
  - Show temporary message:
    "Anahtar olmadan Kökaltı seni bırakmaz."

Victory message:
"Şimdilik kaçtın. Ama Kökler seni hatırlıyor."

Visual:
- Cold green or pale white doorway/rectangle.
- Should feel different from normal rooms.

---

# UI

Create ui.tscn.

Use CanvasLayer or Control.

Show:
- Player HP
- Key status
- Temporary messages
- Victory screen
- Death/restart message if needed

Suggested UI text:
- HP: 5/5
- Anahtar: Yok
- Anahtar: Alındı

Temporary messages:
- “Kökaltı seni öldürmez. Seni sadeleştirir.”
- “Anahtar olmadan Kökaltı seni bırakmaz.”
- “Şimdilik kaçtın. Ama Kökler seni hatırlıyor.”

UI should be simple and readable.
No fancy menu needed.

---

# GAME MANAGER

Create game_manager.gd.

Responsibilities:
- Track player HP if needed.
- Track has_key.
- Track victory state.
- Restart run on death.
- Tell UI when key status changes.
- Tell UI when messages should appear.

Keep the manager simple.
Do not build save files yet.
Do not implement meta-progression yet.

---

# LORE POPUP

Add one lore popup in a random or fixed room.

Message:

"Kökaltı seni öldürmez. Seni sadeleştirir."

Show it once when the player enters that area.

Do not create a full dialogue system.
Do not add branching dialogue.
Do not add NPCs.

---

# INPUT MAP

If needed, configure input actions in project.godot or through code-compatible setup.

Required actions:
- move_up
- move_down
- move_left
- move_right
- dash
- attack

Suggested keys:
- move_up: W
- move_down: S
- move_left: A
- move_right: D
- dash: Space
- attack: J and left mouse button

If editing project.godot input map is risky, use direct key checks in GDScript for Demo 0.1.

---

# CAMERA

Add a Camera2D that follows the player.

Acceptable:
- Camera2D as child of Player.
- Or Camera2D in Main with a simple follow script.

The player should remain visible at all times.

---

# PLACEHOLDER ART RULES

Use primitive visuals only.

Allowed:
- rectangles
- circles
- polygons
- simple lines
- generated shapes

Not allowed:
- external downloaded assets
- AI images
- sprite packs
- audio packs
- complex animations

The prototype should look like an intentional dark board-game map, not a random debug screen.

---

# DO NOT IMPLEMENT YET

Do not implement:
- Bosses
- Multiple floors
- Meta-progression
- Save system
- Item cards
- Inventory
- Complex procedural generation
- Advanced art
- Sound
- Full story system
- Dialogue trees
- Shop system
- Main menu
- Settings menu
- Steam integration

This is Demo 0.1 only.

---

# ACCEPTANCE CHECKLIST

The prototype is successful if:

1. Godot opens the project.
2. main.tscn runs.
3. Player appears.
4. Player can move with WASD.
5. Player can dash with Space.
6. Player can attack with J or left mouse button.
7. Blind Rats chase the player.
8. Blind Rats damage the player.
9. Blind Rats can be killed.
10. Player can take damage.
11. Player death restarts the run.
12. Rooms or room-like spaces exist.
13. Key appears in the level.
14. Player can pick up the key.
15. UI updates after key pickup.
16. Exit appears in the level.
17. Exit only triggers victory after the key is collected.
18. Victory message appears.
19. At least one lore message appears.
20. There are no broken script paths.
21. There are no missing node reference errors on startup.

---

# IMPLEMENTATION NOTES

Prefer simple working code over architectural perfection.

If a feature becomes too complex, simplify it but keep the playable loop:

Move → Fight → Find Key → Reach Exit → Victory

Use clear node names.
Use clear script names.
Use comments only where useful.

Do not silently skip important requirements.
If something cannot be implemented cleanly, add a TODO comment and explain it in the final summary.

---

# FINAL RESPONSE REQUIRED FROM CODEX

After implementation, provide:

1. A short summary of what was built.
2. A list of all created or changed files.
3. How to run the project in Godot.
4. Known limitations.
5. Any remaining TODOs.

Before finishing, check:
- broken script paths
- missing scene references
- missing node names
- main scene loading
- player spawning
- basic input
