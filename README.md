# KÖKLER — Godot 4 Prototype

**KÖKLER** is a dark, earthy, top-down roguelike prototype about descending into a buried underground city called **Kökaltı**.

This repository contains the first playable Godot 4 prototype.

This is not the full game.  
This is **Demo 0.1**, a small vertical slice built to test the core loop:

> Move → Fight → Find Key → Reach Exit → Victory

---

## Project Status

Current target:

**Demo 0.1 — First Playable Prototype**

The goal is to create a simple but playable foundation before adding advanced systems like bosses, item cards, meta-progression, multiple floors, save files, or polished art.

The first demo should feel rough but alive.

---

## Game Vision

KÖKLER is not a bright heroic fantasy game.

It should feel:

- quiet
- oppressive
- old
- underground
- mysterious
- fragile
- watchful

The player controls **Asha**, the daughter of a missing mapmaker.

Her father disappeared while searching for Kökaltı.  
He left behind an unfinished map and a warning:

> “Kökaltı gerçek. İnme. Geri dön.”

Asha enters anyway.

Kökaltı does not only try to kill the player.  
It tries to make the player forget, repeat, and lose direction.

---

## Demo 0.1 Features

Planned first playable features:

- Top-down 2D movement
- Dash with cooldown
- Basic melee attack
- Player health
- One enemy type: Blind Rat
- Small procedural room layout
- Key pickup
- Exit gate
- Death restart
- Victory message
- Simple UI
- One or two lore messages
- Placeholder visuals only

---

## Controls

Planned controls:

| Action | Input |
|---|---|
| Move | W / A / S / D |
| Dash | Space |
| Attack | J or Left Mouse Button |

---

## Core Gameplay Loop

1. Asha wakes in an underground room.
2. The player explores connected rooms.
3. Blind Rats chase and damage the player.
4. The player clears rooms using dash and melee attacks.
5. The player finds a key.
6. The key unlocks the exit.
7. The player reaches the exit and sees the victory message.

Victory message:

> “Şimdilik kaçtın. Ama Kökler seni hatırlıyor.”

---

## Lore Direction

The game should use short, sharp fragments instead of long exposition.

Example lore lines:

> “Kökaltı seni öldürmez. Seni sadeleştirir.”

> “Baban buradan geçmiş. Duvar bunu hatırlıyor.”

> “Haritalar yukarıdakiler içindir. Aşağıda yollar canlıdır.”

> “Toprak nefes almıyor. Dinliyor.”

For Demo 0.1, only one or two lore messages are needed.

---

## Visual Direction

The prototype uses placeholder visuals only.

No external assets.  
No sprite packs.  
No AI images.  
No audio yet.

Suggested visual mood:

| Element | Direction |
|---|---|
| Background | Very dark brown / near black |
| Floors | Muted soil brown |
| Walls | Dark stone brown |
| Player | Pale warm color |
| Blind Rats | Dark red / black |
| Key | Muted gold |
| Exit | Cold green / pale white |
| UI | Parchment-like off-white |

Even with rectangles and circles, the game should feel like an underground ruin, not a random debug room.

---

## Folder Structure

Expected project structure:

```text
kokler_godot/
├─ project.godot
├─ README.md
├─ CODEX_TASK.md
├─ scenes/
│  ├─ main.tscn
│  ├─ player.tscn
│  ├─ blind_rat.tscn
│  ├─ key_pickup.tscn
│  ├─ exit_gate.tscn
│  └─ ui.tscn
└─ scripts/
   ├─ player.gd
   ├─ blind_rat.gd
   ├─ game_manager.gd
   ├─ room_generator.gd
   ├─ key_pickup.gd
   ├─ exit_gate.gd
   └─ ui.gd